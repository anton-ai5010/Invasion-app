from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.db import get_db
from app.api.deps import require_admin
from app.models.zone import Zone
from app.models.seat import Seat
from app.models.user import User
from app.schemas.zone import ZoneCreate, ZoneRead
from app.schemas.seat import SeatCreate, SeatRead
from app.utils.errors import err

router = APIRouter(prefix="/zones", tags=["zones"])

@router.get("", response_model=list[ZoneRead])
def list_zones(db: Session = Depends(get_db)):
    return list(db.scalars(select(Zone).where(Zone.is_active == True).order_by(Zone.id)).all())  # noqa

@router.post("", response_model=ZoneRead, status_code=201)
def create_zone(data: ZoneCreate, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    if db.scalar(select(Zone).where(Zone.code == data.code)):
        raise err("ZONE_CODE_EXISTS", 409)
    z = Zone(name=data.name, code=data.code, is_active=True)
    db.add(z); db.commit(); db.refresh(z)
    return z

@router.get("/{zone_id}/seats", response_model=list[SeatRead])
def list_seats(zone_id: int, db: Session = Depends(get_db)):
    return list(db.scalars(select(Seat).where(Seat.zone_id == zone_id, Seat.is_active == True).order_by(Seat.id)).all())  # noqa

@router.post("/{zone_id}/seats", response_model=SeatRead, status_code=201)
def create_seat(zone_id: int, data: SeatCreate, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    z = db.get(Zone, zone_id)
    if not z or not z.is_active:
        raise err("ZONE_NOT_FOUND", 404)
    price_cents = (data.hourly_price_rub or 300) * 100
    s = Seat(zone_id=zone_id, label=data.label, seat_type=data.seat_type, hourly_price_cents=price_cents, is_active=True)
    db.add(s); db.commit(); db.refresh(s)
    return s

# ===== Layout grouped by row letters (A..Z) =====
import re
ROW_RE = re.compile(r"^([A-Za-z]+)(\d+)$")

@router.get("/{zone_id}/layout")
def zone_layout(zone_id: int, db: Session = Depends(get_db)):
    seats = list(db.scalars(select(Seat).where(Seat.zone_id == zone_id, Seat.is_active == True)).all())  # noqa
    rows: dict[str, list[dict]] = {}

    for s in seats:
        m = ROW_RE.match(s.label)
        row = m.group(1).upper() if m else "?"
        col = int(m.group(2)) if (m and m.group(2).isdigit()) else 0
        rows.setdefault(row, []).append({
            "id": s.id,
            "label": s.label,
            "col": col,
            "seat_type": s.seat_type,
            "hourly_price_cents": s.hourly_price_cents
        })

    # сортируем ряды по алфавиту, а внутри — по номеру места
    result = []
    for row_letter in sorted(rows.keys()):
        result.append({
            "row": row_letter,
            "seats": sorted(rows[row_letter], key=lambda x: x["col"])
        })
    return {"zone_id": zone_id, "rows": result}
