from __future__ import annotations
import json, os
from datetime import datetime, timezone

DEFAULT_POLICY = {
    "tiers": [
        {"threshold_hours": 24, "penalty_percent": 0},
        {"threshold_hours": 2, "penalty_percent": 50},
        {"threshold_hours": 0, "penalty_percent": 100}
    ],
    "loyalty_modifiers": {
        "New": 0
    }
}

def load_policy() -> dict:
    path = os.getenv("CANCELLATION_POLICY_JSON", "/app/app/config/cancellation_policy.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return DEFAULT_POLICY

def compute_penalty_cents(start_time, price_cents, loyalty_level: str = "New") -> int:
    now = datetime.now(timezone.utc)
    hours_left = max(0, (start_time - now).total_seconds() / 3600.0)
    policy = load_policy()
    percent = 0
    # tiers предполагаются отсортированными по threshold_hours убыванию
    for tier in sorted(policy.get("tiers", []), key=lambda t: t["threshold_hours"], reverse=True):
        if hours_left >= tier["threshold_hours"]:
            percent = tier["penalty_percent"]
            break
    # если мы «поздно» (< самого маленького порога)
    if hours_left < min((t["threshold_hours"] for t in policy.get("tiers", [])), default=0):
        percent = policy["tiers"][-1]["penalty_percent"]
    percent += policy.get("loyalty_modifiers", {}).get(loyalty_level, 0)
    percent = max(0, min(100, int(round(percent))))
    return int(round(price_cents * percent / 100))
