from __future__ import annotations
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, and_, or_
from app.models.booking import Booking
from app.models.seat import Seat
from app.utils.errors import err
from app.utils.penalty import compute_penalty_cents
from app.utils.locks import acquire_lock, release_lock, seat_lock_key

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
        raise err("START_ALIGN", 422)
    _validate_alignment(start)
    end = start + timedelta(hours=hours)
    if end <= start:
        raise err("HOURS_MIN", 422)

    lock_key = seat_lock_key(seat_id, start.isoformat(), end.isoformat())
    if not acquire_lock(lock_key, ttl_seconds=300):
        raise err("TEMP_LOCKED", 409)

    try:
        seat = db.get(Seat, seat_id)
        if not seat or not seat.is_active:
            raise err("SEAT_NOT_FOUND", 404)
        if check_conflict(db, seat_id, start, end):
            raise err("SLOT_CONFLICT", 409)

        price_cents = seat.hourly_price_cents * hours
        booking = Booking(
            user_id=user_id, seat_id=seat_id,
            start_time=start, end_time=end,
            status="pending", price_cents=price_cents, penalty_cents=0
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)
        
        # уведомление о создании (fire-and-forget)
        try:
            from app.services.notify import send_push_fcm
            from sqlalchemy import select
            from app.models.device import Device
            tokens = db.scalars(select(Device.token).where(Device.user_id == user_id)).all()
            for t in tokens:
                # не await — это синхронный код; можно игнорировать
                import asyncio
                asyncio.create_task(send_push_fcm(
                    t, "Бронь создана", f"Место #{seat_id}, старт {start.isoformat()}",
                    {"type": "booking_created", "booking_id": str(booking.id)}
                ))
        except Exception:
            pass
        
        return booking
    finally:
        release_lock(lock_key)

def cancel_booking(db: Session, user_id: int, booking_id: int) -> Booking:
    booking = db.get(Booking, booking_id)
    if not booking or booking.user_id != user_id:
        raise err("BOOKING_NOT_FOUND", 404)
    if booking.status not in ("pending", "paid"):
        raise err("CANNOT_CANCEL", 409)
    penalty = compute_penalty_cents(booking.start_time, booking.price_cents, loyalty_level="New")
    booking.status = "cancelled"
    booking.penalty_cents = penalty
    db.add(booking)
    db.commit()
    db.refresh(booking)
    
    try:
        from app.services.notify import send_push_fcm
        from sqlalchemy import select
        from app.models.device import Device
        tokens = db.scalars(select(Device.token).where(Device.user_id == user_id)).all()
        import asyncio
        for t in tokens:
            asyncio.create_task(send_push_fcm(
                t, "Бронь отменена", f"Штраф: {penalty/100:.0f} ₽",
                {"type": "booking_cancelled", "booking_id": str(booking.id)}
            ))
    except Exception:
        pass
    
    return booking

def seat_availability(db: Session, date_utc: datetime, zone_id: int | None = None, seat_id: int | None = None):
    # строим 24 одночасовых слота в пределах даты (UTC)
    day_start = date_utc.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    # выбор мест
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
