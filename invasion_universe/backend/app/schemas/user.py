from __future__ import annotations
from pydantic import BaseModel, EmailStr, Field

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    locale: str | None = "ru"

class UserRead(BaseModel):
    id: int
    email: EmailStr
    locale: str
    role: str | None = None

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
