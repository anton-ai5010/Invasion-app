from __future__ import annotations
from sqlalchemy.orm import Session
from sqlalchemy import select
from fastapi import HTTPException, status
from app.models.user import User
from app.schemas.user import UserCreate
from app.utils.errors import err
from app.utils.security import hash_password, verify_password, create_access_token

def register_user(db: Session, data: UserCreate) -> User:
    if db.scalar(select(User).where(User.email == data.email)):
        raise err("EMAIL_EXISTS", status.HTTP_409_CONFLICT)
    user = User(email=data.email, password_hash=hash_password(data.password), locale=data.locale or "ru")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def authenticate(db: Session, email: str, password: str) -> str:
    user = db.scalar(select(User).where(User.email == email))
    if not user or not verify_password(password, user.password_hash):
        raise err("INVALID_CREDENTIALS", status.HTTP_401_UNAUTHORIZED)
    token = create_access_token(subject=str(user.id))
    return token
