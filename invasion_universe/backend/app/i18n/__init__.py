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
