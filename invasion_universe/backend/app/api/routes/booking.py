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
