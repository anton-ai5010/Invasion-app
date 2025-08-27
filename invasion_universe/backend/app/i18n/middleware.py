from __future__ import annotations
import re
from contextvars import ContextVar
from fastapi import Request

current_locale: ContextVar[str] = ContextVar("current_locale", default="ru")

_lang_re = re.compile(r"^[a-zA-Z-]+$")

def pick_locale(request: Request) -> str:
    hdr = request.headers.get("accept-language", "").split(",")[0].strip().lower()
    if hdr and _lang_re.match(hdr):
        primary = hdr.split("-", 1)[0]
        if primary in ("ru", "en"):
            return primary
    return "ru"

async def locale_middleware(request: Request, call_next):
    loc = pick_locale(request)
    token = current_locale.set(loc)
    try:
        resp = await call_next(request)
    finally:
        current_locale.reset(token)
    return resp
