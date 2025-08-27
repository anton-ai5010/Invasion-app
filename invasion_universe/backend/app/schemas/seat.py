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
