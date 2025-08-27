from __future__ import annotations
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, DateTime, Integer
from datetime import datetime, timezone
from .base import Base

class Device(Base):
    __tablename__ = "devices"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(index=True)
    platform: Mapped[str] = mapped_column(String(16))  # ios|android
    token: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    locale: Mapped[str] = mapped_column(String(8), default="ru")
    app_version: Mapped[str] = mapped_column(String(32), default="dev")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    badge: Mapped[int] = mapped_column(Integer, default=0)