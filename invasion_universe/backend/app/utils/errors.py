from __future__ import annotations
from fastapi import HTTPException
from starlette.status import HTTP_400_BAD_REQUEST
from app.i18n import translate
from app.i18n.middleware import current_locale

def err(code: str, status_code: int = HTTP_400_BAD_REQUEST, **kwargs) -> HTTPException:
    loc = current_locale.get()
    message = translate(loc, code, **kwargs)
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})
