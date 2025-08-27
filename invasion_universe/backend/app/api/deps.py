from __future__ import annotations
from fastapi import Depends, HTTPException, Header, status
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from app.db import get_db
from app.utils.errors import err
from app.config import settings
from app.models.user import User

def get_current_user_bearer(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    if not authorization.startswith("Bearer "):
        raise err("AUTH_MISSING_BEARER", status.HTTP_401_UNAUTHORIZED)
    token = authorization.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise err("AUTH_INVALID_TOKEN", status.HTTP_401_UNAUTHORIZED)
    except JWTError:
        raise err("AUTH_INVALID_TOKEN", status.HTTP_401_UNAUTHORIZED)
    user = db.get(User, int(sub))
    if not user:
        raise err("USER_NOT_FOUND", status.HTTP_401_UNAUTHORIZED)
    return user

def require_admin(user: User = Depends(get_current_user_bearer)) -> User:
    if user.role != "admin":
        raise err("ADMIN_ONLY", status.HTTP_403_FORBIDDEN)
    return user
