from __future__ import annotations
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.api.routes.health import router as health_router
from app.api.routes.auth import router as auth_router
from app.i18n.middleware import locale_middleware
from app.api.routes.zones import router as zones_router
from app.api.routes.booking import router as booking_router
from app.api.routes.admin import router as admin_router
from app.api.routes.devices import router as devices_router

app = FastAPI(title=settings.APP_NAME)

app.middleware('http')(locale_middleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(zones_router)
app.include_router(booking_router)
app.include_router(admin_router)
app.include_router(devices_router)

@app.get("/")
def root():
    return {"service": settings.APP_NAME, "env": settings.ENV}
