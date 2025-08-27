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
