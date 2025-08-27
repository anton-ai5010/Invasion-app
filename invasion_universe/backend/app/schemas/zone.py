from __future__ import annotations
from pydantic import BaseModel, Field

class ZoneCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    code: str = Field(min_length=1, max_length=64)

class ZoneRead(BaseModel):
    id: int
    name: str
    code: str
    class Config:
        from_attributes = True
