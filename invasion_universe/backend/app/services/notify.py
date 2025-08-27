from __future__ import annotations
import os, json, logging
import httpx

log = logging.getLogger("notify")

FCM_URL = "https://fcm.googleapis.com/fcm/send"

def _fcm_key() -> str | None:
    return os.getenv("FCM_SERVER_KEY") or None

async def send_push_fcm(token: str, title: str, body: str, data: dict | None = None) -> bool:
    key = _fcm_key()
    if not key:
        log.info("[PUSH:DRY] %s | %s - %s | data=%s", token[:12], title, body, data)
        return False
    payload = {
        "to": token,
        "notification": {"title": title, "body": body, "sound": "default"},
        "data": data or {}
    }
    headers = {"Authorization": f"key={key}", "Content-Type": "application/json"}
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post(FCM_URL, headers=headers, content=json.dumps(payload))
    ok = r.status_code < 300
    if not ok:
        log.warning("FCM error %s: %s", r.status_code, r.text)
    return ok