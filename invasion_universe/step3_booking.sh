set -euo pipefail

mkdir -p backend/app/{api/routes,schemas,services,utils,config} || true

# ====== MODELS ======
cat > backend/app/models/zone.py <<'PY'
from __future__ import annotations
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Boolean
from .base import Base

class Zone(Base):
    __tablename__ = "zones"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    seats: Mapped[list["Seat"]] = relationship(back_populates="zone", cascade="all, delete-orphan")
PY

cat > backend/app/models/seat.py <<'PY'
from __future__ import annotations
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Boolean, ForeignKey, Integer
from .base import Base

class Seat(Base):
    __tablename__ = "seats"
    id: Mapped[int] = mapped_column(primary_key=True)
    zone_id: Mapped[int] = mapped_column(ForeignKey("zones.id", ondelete="CASCADE"), index=True)
    label: Mapped[str] = mapped_column(String(32), index=True)  # напр. A1, A2
    seat_type: Mapped[str] = mapped_column(String(32), default="standard")  # standard|vip
    hourly_price_cents: Mapped[int] = mapped_column(Integer, default=30000)  # 300 руб = 30000 коп.
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    zone: Mapped["Zone"] = relationship(back_populates="seats")
PY

cat > backend/app/models/booking.py <<'PY'
from __future__ import annotations
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, DateTime, ForeignKey, Integer
from datetime import datetime
from .base import Base

class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(index=True)
    seat_id: Mapped[int] = mapped_column(ForeignKey("seats.id", ondelete="RESTRICT"), index=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(String(16), default="pending")  # pending|paid|cancelled|completed|no_show
    price_cents: Mapped[int] = mapped_column(Integer, default=0)
    penalty_cents: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    seat: Mapped["Seat"] = relationship()
PY

# ====== SCHEMAS ======
cat > backend/app/schemas/zone.py <<'PY'
from __future__ import annotations
from pydantic import BaseModel, Field

class ZoneCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    code: str = Field(min_length=1, max_length=64)

class ZoneRead(BaseModel):
    id: int
    name: str
    code: str
    class Config:
        from_attributes = True
PY

cat > backend/app/schemas/seat.py <<'PY'
from __future__ import annotations
from pydantic import BaseModel, Field

class SeatCreate(BaseModel):
    label: str = Field(min_length=1, max_length=32)
    seat_type: str = Field(default="standard")
    hourly_price_rub: int | None = None  # для удобства ввода в тестах, переведём в копейки

class SeatRead(BaseModel):
    id: int
    label: str
    seat_type: str
    hourly_price_cents: int
    class Config:
        from_attributes = True
PY

cat > backend/app/schemas/booking.py <<'PY'
from __future__ import annotations
from pydantic import BaseModel, Field
from datetime import datetime, date

class BookingCreate(BaseModel):
    seat_id: int
    start_time: datetime  # ISO с таймзоной (MVP: UTC)
    hours: int = Field(ge=1, le=24)

class BookingRead(BaseModel):
    id: int
    seat_id: int
    start_time: datetime
    end_time: datetime
    status: str
    price_cents: int
    penalty_cents: int
    class Config:
        from_attributes = True

class AvailabilitySlot(BaseModel):
    start_time: datetime
    end_time: datetime
    is_free: bool

class SeatAvailability(BaseModel):
    seat_id: int
    label: str
    slots: list[AvailabilitySlot]

class AvailabilityResponse(BaseModel):
    date: date
    ZoneId: int | None = None
    SeatId: int | None = None
    items: list[SeatAvailability]
PY

# ====== UTILS: Penalty calculation ======
cat > backend/app/utils/penalty.py <<'PY'
from __future__ import annotations
import json, os
from datetime import datetime, timezone

DEFAULT_POLICY = {
    "tiers": [
        {"threshold_hours": 24, "penalty_percent": 0},
        {"threshold_hours": 2, "penalty_percent": 50},
        {"threshold_hours": 0, "penalty_percent": 100}
    ],
    "loyalty_modifiers": {
        "New": 0
    }
}

def load_policy() -> dict:
    path = os.getenv("CANCELLATION_POLICY_JSON", "/app/app/config/cancellation_policy.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return DEFAULT_POLICY

def compute_penalty_cents(start_time, price_cents, loyalty_level: str = "New") -> int:
    now = datetime.now(timezone.utc)
    hours_left = max(0, (start_time - now).total_seconds() / 3600.0)
    policy = load_policy()
    percent = 0
    # tiers предполагаются отсортированными по threshold_hours убыванию
    for tier in sorted(policy.get("tiers", []), key=lambda t: t["threshold_hours"], reverse=True):
        if hours_left >= tier["threshold_hours"]:
            percent = tier["penalty_percent"]
            break
    # если мы «поздно» (< самого маленького порога)
    if hours_left < min((t["threshold_hours"] for t in policy.get("tiers", [])), default=0):
        percent = policy["tiers"][-1]["penalty_percent"]
    percent += policy.get("loyalty_modifiers", {}).get(loyalty_level, 0)
    percent = max(0, min(100, int(round(percent))))
    return int(round(price_cents * percent / 100))
PY

# ====== SERVICES: booking logic ======
cat > backend/app/services/booking.py <<'PY'
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, and_, or_
from app.models.booking import Booking
from app.models.seat import Seat
from app.utils.penalty import compute_penalty_cents

BOOKING_ACTIVE_STATUSES = ("pending", "paid", "completed")

def _ceil_to_hour(dt: datetime) -> datetime:
    if dt.minute == 0 and dt.second == 0 and dt.microsecond == 0:
        return dt
    return dt.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)

def _validate_alignment(start: datetime):
    if any([start.minute, start.second, start.microsecond]):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="start_time must be aligned to full hour")

def check_conflict(db: Session, seat_id: int, start: datetime, end: datetime) -> bool:
    # Конфликт, если есть брони этого места с активным статусом, пересекающие интервал
    stmt = select(Booking.id).where(
        Booking.seat_id == seat_id,
        Booking.status.in_(BOOKING_ACTIVE_STATUSES),
        ~or_(Booking.end_time <= start, Booking.start_time >= end)
    ).limit(1)
    return db.scalar(stmt) is not None

def create_booking(db: Session, user_id: int, seat_id: int, start: datetime, hours: int) -> Booking:
    if start.tzinfo is None:
        raise HTTPException(status_code=422, detail="start_time must include timezone (UTC for MVP)")
    _validate_alignment(start)
    end = start + timedelta(hours=hours)
    if end <= start:
        raise HTTPException(status_code=422, detail="hours must be >= 1")

    seat = db.get(Seat, seat_id)
    if not seat or not seat.is_active:
        raise HTTPException(status_code=404, detail="seat not found")
    if check_conflict(db, seat_id, start, end):
        raise HTTPException(status_code=409, detail="time slot is already booked")

    price_cents = seat.hourly_price_cents * hours
    booking = Booking(
        user_id=user_id, seat_id=seat_id,
        start_time=start, end_time=end,
        status="pending", price_cents=price_cents, penalty_cents=0
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking

def cancel_booking(db: Session, user_id: int, booking_id: int) -> Booking:
    booking = db.get(Booking, booking_id)
    if not booking or booking.user_id != user_id:
        raise HTTPException(status_code=404, detail="booking not found")
    if booking.status not in ("pending", "paid"):
        raise HTTPException(status_code=409, detail="cannot cancel in current status")
    penalty = compute_penalty_cents(booking.start_time, booking.price_cents, loyalty_level="New")
    booking.status = "cancelled"
    booking.penalty_cents = penalty
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return booking

def seat_availability(db: Session, date_utc: datetime, zone_id: int | None = None, seat_id: int | None = None):
    # строим 24 одночасовых слота в пределах даты (UTC)
    day_start = date_utc.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    # выбор мест
    from app.models.seat import Seat
    from app.models.zone import Zone
    q = select(Seat).join(Zone).where(Seat.is_active == True, Zone.is_active == True)  # noqa
    if zone_id:
        q = q.where(Seat.zone_id == zone_id)
    if seat_id:
        q = q.where(Seat.id == seat_id)
    seats = db.scalars(q).all()

    # вытягиваем брони по всем выбранным местам за день
    bq = select(Booking).where(
        Booking.seat_id.in_([s.id for s in seats] or [0]),
        ~or_(Booking.end_time <= day_start, Booking.start_time >= day_end),
        Booking.status.in_(BOOKING_ACTIVE_STATUSES)
    )
    bookings = db.scalars(bq).all()
    bookings_by_seat: dict[int, list[Booking]] = {}
    for b in bookings:
        bookings_by_seat.setdefault(b.seat_id, []).append(b)

    items = []
    for s in seats:
        slots = []
        t = day_start
        while t < day_end:
            t2 = t + timedelta(hours=1)
            # пересечение с любой бронью?
            conflict = False
            for b in bookings_by_seat.get(s.id, []):
                if not (b.end_time <= t or b.start_time >= t2):
                    conflict = True
                    break
            slots.append({
                "start_time": t.isoformat(),
                "end_time": t2.isoformat(),
                "is_free": not conflict
            })
            t = t2
        items.append({"seat_id": s.id, "label": s.label, "slots": slots})
    return items
PY

# ====== API DEPS (общая зависимость "current user") ======
cat > backend/app/api/deps.py <<'PY'
from __future__ import annotations
from fastapi import Depends, HTTPException, Header, status
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from app.db import get_db
from app.config import settings
from app.models.user import User

def get_current_user_bearer(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.get(User, int(sub))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
PY

# ====== ROUTES: zones & seats ======
cat > backend/app/api/routes/zones.py <<'PY'
from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.db import get_db
from app.models.zone import Zone
from app.models.seat import Seat
from app.schemas.zone import ZoneCreate, ZoneRead
from app.schemas.seat import SeatCreate, SeatRead

router = APIRouter(prefix="/zones", tags=["zones"])

@router.get("", response_model=list[ZoneRead])
def list_zones(db: Session = Depends(get_db)):
    return list(db.scalars(select(Zone).where(Zone.is_active == True).order_by(Zone.id)).all())  # noqa

@router.post("", response_model=ZoneRead, status_code=201)
def create_zone(data: ZoneCreate, db: Session = Depends(get_db)):
    if db.scalar(select(Zone).where(Zone.code == data.code)):
        raise HTTPException(status_code=409, detail="zone code already exists")
    z = Zone(name=data.name, code=data.code, is_active=True)
    db.add(z); db.commit(); db.refresh(z)
    return z

@router.get("/{zone_id}/seats", response_model=list[SeatRead])
def list_seats(zone_id: int, db: Session = Depends(get_db)):
    return list(db.scalars(select(Seat).where(Seat.zone_id == zone_id, Seat.is_active == True).order_by(Seat.id)).all())  # noqa

@router.post("/{zone_id}/seats", response_model=SeatRead, status_code=201)
def create_seat(zone_id: int, data: SeatCreate, db: Session = Depends(get_db)):
    z = db.get(Zone, zone_id)
    if not z or not z.is_active:
        raise HTTPException(status_code=404, detail="zone not found")
    price_cents = (data.hourly_price_rub or 300) * 100
    s = Seat(zone_id=zone_id, label=data.label, seat_type=data.seat_type, hourly_price_cents=price_cents, is_active=True)
    db.add(s); db.commit(); db.refresh(s)
    return s
PY

# ====== ROUTES: bookings & availability ======
cat > backend/app/api/routes/booking.py <<'PY'
from __future__ import annotations
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import datetime, date, timezone
from app.db import get_db
from app.api.deps import get_current_user_bearer
from app.models.booking import Booking
from app.services.booking import create_booking, cancel_booking, seat_availability
from app.schemas.booking import BookingCreate, BookingRead, AvailabilityResponse, SeatAvailability

router = APIRouter(prefix="/bookings", tags=["bookings"])

@router.get("/availability", response_model=AvailabilityResponse)
def get_availability(
    date_str: str = Query(..., description="YYYY-MM-DD (UTC)"),
    zone_id: int | None = None,
    seat_id: int | None = None,
    db: Session = Depends(get_db)
):
    d = date.fromisoformat(date_str)
    d_utc = datetime(d.year, d.month, d.day, tzinfo=timezone.utc)
    items = seat_availability(db, d_utc, zone_id=zone_id, seat_id=seat_id)
    return {"date": d, "ZoneId": zone_id, "SeatId": seat_id, "items": items}

@router.post("", response_model=BookingRead, status_code=201)
def create(data: BookingCreate, current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    b = create_booking(db, user_id=current.id, seat_id=data.seat_id, start=data.start_time, hours=data.hours)
    return b

@router.get("/me", response_model=list[BookingRead])
def my_bookings(current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    q = db.query(Booking).filter(Booking.user_id == current.id).order_by(Booking.start_time.desc())
    return list(q.all())

@router.delete("/{booking_id}", response_model=BookingRead)
def cancel(booking_id: int, current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    b = cancel_booking(db, user_id=current.id, booking_id=booking_id)
    return b
PY

# ====== main.py: подключаем роуты ======
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")
if "from app.api.routes.zones" not in txt:
    txt = txt.replace(
        "from app.api.routes.auth import router as auth_router",
        "from app.api.routes.auth import router as auth_router\nfrom app.api.routes.zones import router as zones_router\nfrom app.api.routes.booking import router as booking_router"
    )
    txt = txt.replace(
        "app.include_router(auth_router)",
        "app.include_router(auth_router)\napp.include_router(zones_router)\napp.include_router(booking_router)"
    )
    p.write_text(txt, encoding="utf-8")
PY

# ====== cancellation policy JSON ======
mkdir -p backend/app/config || true
cat > backend/app/config/cancellation_policy.json <<'JSON'
{
  "tiers": [
    { "threshold_hours": 24, "penalty_percent": 0 },
    { "threshold_hours": 2,  "penalty_percent": 50 },
    { "threshold_hours": 0,  "penalty_percent": 100 }
  ],
  "loyalty_modifiers": {
    "New": 0
  }
}
JSON

# ====== Alembic migration ======
cat > backend/alembic/versions/20250827_0002_booking.py <<'PY'
from __future__ import annotations
from alembic import op
import sqlalchemy as sa

revision = "20250827_0002"
down_revision = "20250827_0001"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "zones",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("code", sa.String(64), nullable=False, unique=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true"))
    )
    op.create_index("ix_zones_code", "zones", ["code"], unique=True)

    op.create_table(
        "seats",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("zone_id", sa.BigInteger, sa.ForeignKey("zones.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("label", sa.String(32), nullable=False, index=True),
        sa.Column("seat_type", sa.String(32), nullable=False, server_default="standard"),
        sa.Column("hourly_price_cents", sa.Integer, nullable=False, server_default="30000"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true"))
    )

    op.create_table(
        "bookings",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("user_id", sa.BigInteger, nullable=False, index=True),
        sa.Column("seat_id", sa.BigInteger, sa.ForeignKey("seats.id", ondelete="RESTRICT"), nullable=False, index=True),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("price_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("penalty_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )
    op.create_index("ix_bookings_seat_time", "bookings", ["seat_id", "start_time", "end_time"])
    op.create_index("ix_seats_zone", "seats", ["zone_id"])

def downgrade() -> None:
    op.drop_index("ix_bookings_seat_time", table_name="bookings")
    op.drop_table("bookings")
    op.drop_index("ix_seats_zone", table_name="seats")
    op.drop_table("seats")
    op.drop_index("ix_zones_code", table_name="zones")
    op.drop_table("zones")
PY

echo "Step 3 files created."
