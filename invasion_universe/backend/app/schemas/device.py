from __future__ import annotations
from pydantic import BaseModel, Field

class DeviceRegister(BaseModel):
    platform: str = Field(pattern="^(ios|android)$")
    token: str = Field(min_length=10, max_length=500)
    locale: str = "ru"
    app_version: str = "dev"

class DeviceRead(BaseModel):
    id: int
    platform: str
    token: str
    locale: str
    app_version: str
    class Config:
        from_attributes = True