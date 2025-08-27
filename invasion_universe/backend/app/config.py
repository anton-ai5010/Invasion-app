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
