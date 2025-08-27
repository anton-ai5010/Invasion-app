from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from app.db import get_db
from app.api.deps import get_current_user_bearer
from app.models.device import Device
from app.schemas.device import DeviceRegister, DeviceRead
from app.utils.errors import err
from datetime import datetime, timezone

router = APIRouter(prefix="/devices", tags=["devices"])

MAX_DEVICES_PER_USER = 10

@router.post("/register", response_model=DeviceRead, status_code=201)
def register_device(payload: DeviceRegister, current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    # ограничим кол-во устройств
    n = db.scalar(select(func.count()).select_from(Device).where(Device.user_id == current.id)) or 0
    if n >= MAX_DEVICES_PER_USER:
        raise err("CANNOT_CANCEL", 429, reason="too many devices")  # переиспользуем код, сообщение — общее

    # upsert по токену
    d = db.scalar(select(Device).where(Device.token == payload.token))
    if d:
        d.user_id = current.id
        d.platform = payload.platform
        d.locale = payload.locale
        d.app_version = payload.app_version
        d.last_seen_at = datetime.now(timezone.utc)
    else:
        d = Device(
            user_id=current.id, platform=payload.platform, token=payload.token,
            locale=payload.locale, app_version=payload.app_version
        )
        db.add(d)
    db.commit(); db.refresh(d)
    return d

@router.get("/me", response_model=list[DeviceRead])
def my_devices(current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    return list(db.scalars(select(Device).where(Device.user_id == current.id)).all())

@router.delete("/{device_id}")
def delete_device(device_id: int, current=Depends(get_current_user_bearer), db: Session = Depends(get_db)):
    d = db.get(Device, device_id)
    if not d or d.user_id != current.id:
        raise err("USER_NOT_FOUND", 404)
    db.delete(d); db.commit()
    return {"ok": True}