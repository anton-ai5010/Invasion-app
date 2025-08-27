set -euo pipefail

# ── Структура ────────────────────────────────────────────────────────────────
mkdir -p backend/app/{api/routes,models,schemas,services,utils} \
         backend/alembic/versions

# ── requirements.txt ─────────────────────────────────────────────────────────
cat > backend/requirements.txt <<'EOF'
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.8.2
pydantic-settings==2.4.0
SQLAlchemy==2.0.32
alembic==1.13.2
psycopg2-binary==2.9.9
passlib[bcrypt]==1.7.4
python-jose[cryptography]==3.3.0
email-validator==2.2.0
redis==5.0.7
python-multipart==0.0.9
httpx==0.27.2
EOF

# ── Dockerfile ───────────────────────────────────────────────────────────────
cat > backend/Dockerfile <<'EOF'
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY app ./app
COPY alembic.ini ./alembic.ini
COPY alembic ./alembic

ENV PORT=8000
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# ── docker-compose.yml (корень проекта) ──────────────────────────────────────
cat > docker-compose.yml <<'EOF'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: iu
      POSTGRES_PASSWORD: iu_password
      POSTGRES_DB: iu_db
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U iu"]
      interval: 5s
      timeout: 5s
      retries: 10

  backend:
    build:
      context: ./backend
    env_file:
      - ./backend/.env
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "8000:8000"
    command: >
      bash -lc "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"

volumes:
  db_data:
EOF

# ── .env для backend ─────────────────────────────────────────────────────────
cat > backend/.env <<'EOF'
APP_NAME=Invasion Universe API
ENV=dev
DATABASE_URL=postgresql+psycopg2://iu:iu_password@db:5432/iu_db
JWT_SECRET=change_me_super_secret
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRES_MIN=60
CORS_ORIGINS=http://localhost:5173,http://localhost:3000,http://localhost:8080
EOF

# ── alembic.ini ──────────────────────────────────────────────────────────────
cat > backend/alembic.ini <<'EOF'
[alembic]
script_location = alembic
sqlalchemy.url = %(DATABASE_URL)s

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers = console
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers = console
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
EOF

# ── alembic/env.py ───────────────────────────────────────────────────────────
cat > backend/alembic/env.py <<'EOF'
from __future__ import annotations
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

from app.models.base import Base  # noqa: E402
target_metadata = Base.metadata

def get_url():
    return os.getenv("DATABASE_URL")

def run_migrations_offline():
    url = get_url()
    context.configure(
        url=url, target_metadata=target_metadata, literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    configuration = config.get_section(config.config_ini_section) or {}
    connectable = engine_from_config(
        configuration, prefix="sqlalchemy.", poolclass=pool.NullPool, url=get_url(),
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

# ── первая миграция ──────────────────────────────────────────────────────────
cat > backend/alembic/versions/20250827_0001_init.py <<'EOF'
from __future__ import annotations
from alembic import op
import sqlalchemy as sa

revision = "20250827_0001"
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("email", sa.String(320), unique=True, nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("locale", sa.String(8), nullable=False, server_default="ru"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

def downgrade() -> None:
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
EOF

# ── app/config.py ────────────────────────────────────────────────────────────
cat > backend/app/config.py <<'EOF'
from __future__ import annotations
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Invasion Universe API"
    ENV: str = "dev"
    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRES_MIN: int = 60
    CORS_ORIGINS: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        if not self.CORS_ORIGINS:
            return []
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

settings = Settings()
EOF

# ── app/db.py ────────────────────────────────────────────────────────────────
cat > backend/app/db.py <<'EOF'
from __future__ import annotations
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .config import settings

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

# ── app/models/base.py ───────────────────────────────────────────────────────
cat > backend/app/models/base.py <<'EOF'
from __future__ import annotations
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
EOF

# ── app/models/user.py ───────────────────────────────────────────────────────
cat > backend/app/models/user.py <<'EOF'
from __future__ import annotations
from sqlalchemy import String, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime
from .base import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    locale: Mapped[str] = mapped_column(String(8), default="ru")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
EOF

# ── app/schemas/user.py ──────────────────────────────────────────────────────
cat > backend/app/schemas/user.py <<'EOF'
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

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
EOF

# ── app/utils/security.py ────────────────────────────────────────────────────
cat > backend/app/utils/security.py <<'EOF'
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from jose import jwt
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

def create_access_token(subject: str, expires_minutes: Optional[int] = None) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes or settings.ACCESS_TOKEN_EXPIRES_MIN)
    to_encode: dict[str, Any] = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
EOF

# ── app/services/auth.py ─────────────────────────────────────────────────────
cat > backend/app/services/auth.py <<'EOF'
from __future__ import annotations
from sqlalchemy.orm import Session
from sqlalchemy import select
from fastapi import HTTPException, status
from app.models.user import User
from app.schemas.user import UserCreate
from app.utils.security import hash_password, verify_password, create_access_token

def register_user(db: Session, data: UserCreate) -> User:
    if db.scalar(select(User).where(User.email == data.email)):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    user = User(email=data.email, password_hash=hash_password(data.password), locale=data.locale or "ru")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def authenticate(db: Session, email: str, password: str) -> str:
    user = db.scalar(select(User).where(User.email == email))
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token(subject=str(user.id))
    return token
EOF

# ── app/api/routes/health.py ─────────────────────────────────────────────────
cat > backend/app/api/routes/health.py <<'EOF'
from __future__ import annotations
from fastapi import APIRouter
router = APIRouter(tags=["health"])

@router.get("/healthz")
def healthz():
    return {"status": "ok"}
EOF

# ── app/api/routes/auth.py ───────────────────────────────────────────────────
cat > backend/app/api/routes/auth.py <<'EOF'
from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status, Header
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from sqlalchemy import select
from app.db import get_db
from app.schemas.user import UserCreate, UserRead, Token
from app.services.auth import register_user, authenticate
from app.config import settings
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserRead, status_code=201)
def register(data: UserCreate, db: Session = Depends(get_db)):
    user = register_user(db, data)
    return user

@router.post("/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    token = authenticate(db, email=form.username, password=form.password)
    return Token(access_token=token)

def get_current_user_bearer(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.get(User, int(sub))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user

@router.get("/me", response_model=UserRead)
def me(current: User = Depends(get_current_user_bearer)):
    return current
EOF

# ── app/main.py ──────────────────────────────────────────────────────────────
cat > backend/app/main.py <<'EOF'
from __future__ import annotations
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.api.routes.health import router as health_router
from app.api.routes.auth import router as auth_router

app = FastAPI(title=settings.APP_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(auth_router)

@app.get("/")
def root():
    return {"service": settings.APP_NAME, "env": settings.ENV}
EOF

# ── .gitignore + README ──────────────────────────────────────────────────────
cat > .gitignore <<'EOF'
# macOS
.DS_Store

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.env
.venv
venv/

# Node
node_modules/

# Editors
.vscode/
.idea/
EOF

cat > README.md <<'EOF'
# Invasion Universe — Backend (MVP)
FastAPI + Postgres + Alembic + JWT. Run:

docker compose up --build
# API: http://localhost:8000  (docs: http://localhost:8000/docs)
EOF

echo "Bootstrap done."
