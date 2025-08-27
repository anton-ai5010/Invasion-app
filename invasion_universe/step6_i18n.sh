set -euo pipefail

mkdir -p backend/app/i18n backend/app/utils

# ── сообщения ────────────────────────────────────────────────────────────────
cat > backend/app/i18n/messages_en.json <<'JSON'
{
  "EMAIL_EXISTS": "Email already registered",
  "INVALID_CREDENTIALS": "Invalid credentials",
  "AUTH_MISSING_BEARER": "Missing bearer token",
  "AUTH_INVALID_TOKEN": "Invalid token",
  "USER_NOT_FOUND": "User not found",
  "ADMIN_ONLY": "Admin only",
  "ZONE_CODE_EXISTS": "Zone code already exists",
  "ZONE_NOT_FOUND": "Zone not found",
  "SEAT_NOT_FOUND": "Seat not found",
  "START_ALIGN": "start_time must be aligned to full hour",
  "HOURS_MIN": "hours must be >= 1",
  "SLOT_CONFLICT": "Time slot is already booked",
  "TEMP_LOCKED": "Seat/time is temporarily locked, try again",
  "CANNOT_CANCEL": "Cannot cancel in current status",
  "BOOKING_NOT_FOUND": "Booking not found"
}
JSON

cat > backend/app/i18n/messages_ru.json <<'JSON'
{
  "EMAIL_EXISTS": "Почта уже зарегистрирована",
  "INVALID_CREDENTIALS": "Неверный логин или пароль",
  "AUTH_MISSING_BEARER": "Отсутствует Bearer токен",
  "AUTH_INVALID_TOKEN": "Некорректный токен",
  "USER_NOT_FOUND": "Пользователь не найден",
  "ADMIN_ONLY": "Доступно только администратору",
  "ZONE_CODE_EXISTS": "Код зоны уже существует",
  "ZONE_NOT_FOUND": "Зона не найдена",
  "SEAT_NOT_FOUND": "Место не найдено",
  "START_ALIGN": "start_time должен быть на целый час",
  "HOURS_MIN": "hours должен быть ≥ 1",
  "SLOT_CONFLICT": "Временной слот уже занят",
  "TEMP_LOCKED": "Место/время временно заблокировано, попробуйте ещё раз",
  "CANNOT_CANCEL": "Нельзя отменить в текущем статусе",
  "BOOKING_NOT_FOUND": "Бронь не найдена"
}
JSON

# ── i18n init + middleware ──────────────────────────────────────────────────
cat > backend/app/i18n/__init__.py <<'PY'
from __future__ import annotations
import json, os
from functools import lru_cache
from typing import Dict

SUPPORTED = ("ru", "en")

@lru_cache(maxsize=8)
def _load(locale: str) -> Dict[str, str]:
    loc = locale if locale in SUPPORTED else "ru"
    base = os.path.dirname(__file__)
    path = os.path.join(base, f"messages_{loc}.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def translate(locale: str, code: str, **kwargs) -> str:
    msg = _load(locale).get(code) or _load("en").get(code) or code
    try:
        return msg.format(**kwargs)
    except Exception:
        return msg
PY

cat > backend/app/i18n/middleware.py <<'PY'
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
PY

# ── единый helper ошибок ────────────────────────────────────────────────────
cat > backend/app/utils/errors.py <<'PY'
from __future__ import annotations
from fastapi import HTTPException
from starlette.status import HTTP_400_BAD_REQUEST
from app.i18n import translate
from app.i18n.middleware import current_locale

def err(code: str, status_code: int = HTTP_400_BAD_REQUEST, **kwargs) -> HTTPException:
    loc = current_locale.get()
    message = translate(loc, code, **kwargs)
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})
PY

# ── main.py: подключаем i18n middleware ─────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")
needle = "from app.api.routes.auth import router as auth_router"
if "from app.i18n.middleware import locale_middleware" not in txt:
    txt = txt.replace(
        needle,
        needle + "\nfrom app.i18n.middleware import locale_middleware"
    )
if "app.add_middleware(" not in txt or "locale_middleware" not in txt:
    # вставим кастомный middleware чуть выше CORS
    txt = txt.replace(
        "app = FastAPI(title=settings.APP_NAME)\n\napp.add_middleware(",
        "app = FastAPI(title=settings.APP_NAME)\n\napp.middleware('http')(locale_middleware)\n\napp.add_middleware("
    )
p.write_text(txt, encoding="utf-8")
PY

# ── deps.py: ошибки через err() ─────────────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/api/deps.py")
txt = p.read_text(encoding="utf-8")
if "from app.utils.errors import err" not in txt:
    txt = txt.replace(
        "from app.db import get_db",
        "from app.db import get_db\nfrom app.utils.errors import err"
    )
txt = txt.replace(
    'raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")',
    'raise err("AUTH_MISSING_BEARER", status.HTTP_401_UNAUTHORIZED)'
)
txt = txt.replace(
    'raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")',
    'raise err("AUTH_INVALID_TOKEN", status.HTTP_401_UNAUTHORIZED)'
)
txt = txt.replace(
    'raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")',
    'raise err("USER_NOT_FOUND", status.HTTP_401_UNAUTHORIZED)'
)
if "def require_admin" not in txt:
    txt += '\n\ndef require_admin(user: User = Depends(get_current_user_bearer)) -> User:\n' \
           '    if user.role != "admin":\n' \
           '        from fastapi import status as _st\n' \
           '        raise err("ADMIN_ONLY", _st.HTTP_403_FORBIDDEN)\n' \
           '    return user\n'
p.write_text(txt, encoding="utf-8")
PY

# ── auth service: ошибки через err() ────────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/services/auth.py")
txt = p.read_text(encoding="utf-8")
if "from app.utils.errors import err" not in txt:
    txt = txt.replace(
        "from app.schemas.user import UserCreate",
        "from app.schemas.user import UserCreate\nfrom app.utils.errors import err"
    )
txt = txt.replace(
    'raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")',
    'raise err("EMAIL_EXISTS", status.HTTP_409_CONFLICT)'
)
txt = txt.replace(
    'raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")',
    'raise err("INVALID_CREDENTIALS", status.HTTP_401_UNAUTHORIZED)'
)
Path("backend/app/services/auth.py").write_text(txt, encoding="utf-8")
PY

# ── zones routes: err() ─────────────────────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/api/routes/zones.py")
txt = p.read_text(encoding="utf-8")
if "from app.utils.errors import err" not in txt:
    txt = txt.replace(
        "from app.schemas.seat import SeatCreate, SeatRead",
        "from app.schemas.seat import SeatCreate, SeatRead\nfrom app.utils.errors import err"
    )
txt = txt.replace(
    'raise HTTPException(status_code=409, detail="zone code already exists")',
    'raise err("ZONE_CODE_EXISTS", 409)'
)
txt = txt.replace(
    'raise HTTPException(status_code=404, detail="zone not found")',
    'raise err("ZONE_NOT_FOUND", 404)'
)
p.write_text(txt, encoding="utf-8")
PY

# ── booking service: err() ──────────────────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/services/booking.py")
txt = p.read_text(encoding="utf-8")
if "from app.utils.errors import err" not in txt:
    txt = txt.replace(
        "from app.models.seat import Seat",
        "from app.models.seat import Seat\nfrom app.utils.errors import err"
    )
txt = txt.replace(
    'raise HTTPException(status_code=422, detail="start_time must include timezone (UTC for MVP)")',
    'raise err("START_ALIGN", 422)'  # переиспользуем START_ALIGN
)
txt = txt.replace(
    'raise HTTPException(status_code=422, detail="start_time must be aligned to full hour")',
    'raise err("START_ALIGN", 422)'
)
txt = txt.replace(
    'raise HTTPException(status_code=422, detail="hours must be >= 1")',
    'raise err("HOURS_MIN", 422)'
)
txt = txt.replace(
    'raise HTTPException(status_code=404, detail="seat not found")',
    'raise err("SEAT_NOT_FOUND", 404)'
)
txt = txt.replace(
    'raise HTTPException(status_code=409, detail="time slot is already booked")',
    'raise err("SLOT_CONFLICT", 409)'
)
txt = txt.replace(
    'raise HTTPException(status_code=409, detail="cannot cancel in current status")',
    'raise err("CANNOT_CANCEL", 409)'
)
txt = txt.replace(
    'raise HTTPException(status_code=404, detail="booking not found")',
    'raise err("BOOKING_NOT_FOUND", 404)'
)
p.write_text(txt, encoding="utf-8")
PY

# ── admin routes: err() ─────────────────────────────────────────────────────
python3 - <<'PY'
from pathlib import Path
p = Path("backend/app/api/routes/admin.py")
txt = p.read_text(encoding="utf-8")
if "from app.utils.errors import err" not in txt:
    txt = txt.replace(
        "from app.models.booking import Booking",
        "from app.models.booking import Booking\nfrom app.utils.errors import err"
    )
txt = txt.replace(
    'raise HTTPException(status_code=404, detail="booking not found")',
    'raise err("BOOKING_NOT_FOUND", 404)'
)
txt = txt.replace(
    'raise HTTPException(status_code=409, detail=f"cannot mark_paid from {b.status}")',
    'raise err("CANNOT_CANCEL", 409)'
)
txt = txt.replace(
    'raise HTTPException(status_code=409, detail=f"cannot complete from {b.status}")',
    'raise err("CANNOT_CANCEL", 409)'
)
txt = txt.replace(
    'raise HTTPException(status_code=409, detail=f"cannot no_show from {b.status}")',
    'raise err("CANNOT_CANCEL", 409)'
)
p.write_text(txt, encoding="utf-8")
PY

echo "Step 6 i18n patch applied."