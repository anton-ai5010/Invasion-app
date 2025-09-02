from __future__ import annotations
import os, time
from typing import Optional
import redis

_redis: Optional[redis.Redis] = None

def get_redis() -> redis.Redis:
    global _redis
    if _redis is None:
        url = os.getenv("REDIS_URL", "redis://redis:6379/0")
        _redis = redis.from_url(url, decode_responses=True)
    return _redis

def seat_lock_key(seat_id: int, start_iso: str, end_iso: str) -> str:
    return f"lock:seat:{seat_id}:{start_iso}->{end_iso}"

def acquire_lock(key: str, ttl_seconds: int = 300) -> bool:
    # SET NX EX — атомарная попытка захвата
    try:
        return bool(get_redis().set(key, "1", nx=True, ex=ttl_seconds))
    except:
        # Fallback when Redis is not available - always allow
        return True

def release_lock(key: str) -> None:
    try:
        get_redis().delete(key)
    except Exception:
        pass