from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db import get_db
from app.api.deps import require_admin
from app.models.booking import Booking
from app.utils.errors import err

router = APIRouter(prefix="/admin", tags=["admin"])

def _get(db: Session, booking_id: int) -> Booking:
    b = db.get(Booking, booking_id)
    if not b:
        raise err("BOOKING_NOT_FOUND", 404)
    return b

@router.post("/bookings/{booking_id}/mark_paid")
def mark_paid(booking_id: int, _: object = Depends(require_admin), db: Session = Depends(get_db)):
    b = _get(db, booking_id)
    if b.status not in ("pending",):
        raise err("CANNOT_CANCEL", 409)
    b.status = "paid"
    db.add(b); db.commit(); db.refresh(b)
    return {"id": b.id, "status": b.status}

@router.post("/bookings/{booking_id}/complete")
def complete(booking_id: int, _: object = Depends(require_admin), db: Session = Depends(get_db)):
    b = _get(db, booking_id)
    if b.status not in ("paid", "pending"):
        raise err("CANNOT_CANCEL", 409)
    b.status = "completed"
    db.add(b); db.commit(); db.refresh(b)
    return {"id": b.id, "status": b.status}

@router.post("/bookings/{booking_id}/no_show")
def no_show(booking_id: int, _: object = Depends(require_admin), db: Session = Depends(get_db)):
    b = _get(db, booking_id)
    if b.status not in ("pending",):
        raise err("CANNOT_CANCEL", 409)
    b.status = "no_show"
    db.add(b); db.commit(); db.refresh(b)
    return {"id": b.id, "status": b.status}

# ===== Seat seeding for a zone (grid) =====
from pydantic import BaseModel, Field
from sqlalchemy import select
from app.models.seat import Seat

class SeedSeatsRequest(BaseModel):
    rows: int = Field(ge=1, le=26, description="Количество рядов, максимум 26 (A..Z)")
    cols: int = Field(ge=1, le=100, description="Количество мест в ряду")
    start_row_letter: str = Field(default="A", min_length=1, max_length=1)
    vip_rows: list[str] = Field(default=[], description="Список букв рядов, которые будут VIP (например [\"A\",\"B\"])")
    standard_price_rub: int = Field(default=300, ge=0)
    vip_price_rub: int = Field(default=500, ge=0)
    overwrite_prices: bool = False  # если True, обновляет цену для уже существующих мест с таким label

def _letters(start: str, count: int) -> list[str]:
    a = start.upper()
    base = ord(a)
    return [chr(base + i) for i in range(count)]

@router.post("/zones/{zone_id}/seed_seats")
def seed_seats(
    zone_id: int,
    payload: SeedSeatsRequest,
    _: object = Depends(require_admin),
    db: Session = Depends(get_db)
):
    created = 0
    updated = 0
    skipped = 0

    vip = {x.upper() for x in payload.vip_rows}
    rows = _letters(payload.start_row_letter, payload.rows)

    # Получим уже существующие лейблы для зоны, чтобы не вставлять дубликаты
    existing = set(db.scalars(select(Seat.label).where(Seat.zone_id == zone_id)).all())

    for r in rows:
        for c in range(1, payload.cols + 1):
            label = f"{r}{c}"
            is_vip = r in vip
            price_cents = (payload.vip_price_rub if is_vip else payload.standard_price_rub) * 100
            seat_type = "vip" if is_vip else "standard"

            if label in existing:
                if payload.overwrite_prices:
                    s = db.scalar(select(Seat).where(Seat.zone_id == zone_id, Seat.label == label))
                    if s:
                        s.seat_type = seat_type
                        s.hourly_price_cents = price_cents
                        db.add(s)
                        updated += 1
                else:
                    skipped += 1
                continue

            s = Seat(
                zone_id=zone_id, label=label,
                seat_type=seat_type, hourly_price_cents=price_cents, is_active=True
            )
            db.add(s)
            created += 1

    db.commit()
    return {"zone_id": zone_id, "created": created, "updated": updated, "skipped": skipped}

# ===== Today's bookings =====
from datetime import datetime, timezone, timedelta
from sqlalchemy import select, and_
from app.models.user import User

@router.get("/bookings/today")
def bookings_today(zone_id: int | None = None, _: object = Depends(require_admin), db: Session = Depends(get_db)):
    # считаем «сегодня» по UTC (для MVP; позже можно сдвигать таймзоной клуба)
    now = datetime.now(timezone.utc)
    start = datetime(year=now.year, month=now.month, day=now.day, tzinfo=timezone.utc)
    end = start + timedelta(days=1)

    stmt = (
        select(
            Booking.id, Booking.status, Booking.start_time, Booking.end_time,
            Booking.price_cents, Booking.penalty_cents,
            Seat.label, Seat.zone_id, User.email
        )
        .join(Seat, Seat.id == Booking.seat_id)
        .join(User, User.id == Booking.user_id)
        .where(and_(Booking.start_time >= start, Booking.start_time < end))
        .order_by(Booking.start_time.asc())
    )
    if zone_id:
        stmt = stmt.where(Seat.zone_id == zone_id)

    rows = db.execute(stmt).all()
    items = []
    for r in rows:
        items.append({
            "id": r.id,
            "status": r.status,
            "start_time": r.start_time.isoformat(),
            "end_time": r.end_time.isoformat(),
            "price_cents": r.price_cents,
            "penalty_cents": r.penalty_cents,
            "seat_label": r.label,
            "zone_id": r.zone_id,
            "user_email": r.email,
        })
    return {"items": items}

# ===== Bulk price update by row =====
import re

ROW_RE = re.compile(r"^([A-Za-z]+)(\d+)$")

class RowPriceRequest(BaseModel):
    hourly_price_rub: int | None = Field(default=None, ge=0)
    seat_type: str | None = Field(default=None, pattern="^(standard|vip)$")
    is_active: bool | None = None

@router.post("/zones/{zone_id}/rows/{row}/price")
def update_row_price(
    zone_id: int,
    row: str,
    payload: RowPriceRequest,
    _: object = Depends(require_admin),
    db: Session = Depends(get_db)
):
    q = select(Seat).where(Seat.zone_id == zone_id)
    seats = list(db.scalars(q).all())
    updated = 0
    target = row.upper()
    for s in seats:
        m = ROW_RE.match(s.label or "")
        r = m.group(1).upper() if m else None
        if r != target:
            continue
        if payload.hourly_price_rub is not None:
            s.hourly_price_cents = payload.hourly_price_rub * 100
        if payload.seat_type is not None:
            s.seat_type = payload.seat_type
        if payload.is_active is not None:
            s.is_active = payload.is_active
        db.add(s)
        updated += 1
    db.commit()
    return {"zone_id": zone_id, "row": target, "updated": updated}