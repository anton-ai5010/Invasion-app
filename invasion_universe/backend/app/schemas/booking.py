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
