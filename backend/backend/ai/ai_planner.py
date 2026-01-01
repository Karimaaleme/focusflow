# finalbackend/ai/ai_planner.py
from __future__ import annotations

import json
import os
import re
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

# NOTE:
# - We DO NOT create OpenAI client at import time (prevents uvicorn crash if key missing).
# - If no OPENAI_API_KEY is set, we fallback to a simple "non-AI" scheduler (still works).

def _get_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        from openai import OpenAI  # openai>=1.x
        return OpenAI(api_key=api_key)
    except Exception:
        return None


def _clean_hhmm(s: str, default: str = "09:00") -> str:
    if not s:
        return default
    s = s.strip()
    # allow "9:00" -> "09:00"
    m = re.match(r"^(\d{1,2}):(\d{2})$", s)
    if not m:
        return default
    hh = int(m.group(1))
    mm = int(m.group(2))
    if hh < 0 or hh > 23 or mm < 0 or mm > 59:
        return default
    return f"{hh:02d}:{mm:02d}"


def _parse_minutes(v: Any, default: int = 30) -> int:
    try:
        n = int(v)
        return max(5, min(n, 24 * 60))
    except Exception:
        return default


def _dt_from_day_start(day: datetime, hhmm: str) -> datetime:
    hh, mm = hhmm.split(":")
    return datetime(day.year, day.month, day.day, int(hh), int(mm))


def _round_to_5(dt: datetime) -> datetime:
    # round DOWN to 5-min
    minutes = (dt.minute // 5) * 5
    return dt.replace(minute=minutes, second=0, microsecond=0)


def _fallback_schedule(
    tasks: List[Dict[str, Any]],
    day_start: str,
    planned_minutes: int,
) -> Dict[str, Any]:
    """
    Simple non-AI fallback:
    - sort by priority (high > medium > low)
    - schedule sequentially from day_start
    - each task duration = min(estimated_minutes, remaining)
    """
    today = datetime.now()
    cursor = _dt_from_day_start(today, _clean_hhmm(day_start))
    cursor = _round_to_5(cursor)

    priority_rank = {"high": 3, "medium": 2, "low": 1}
    def rank(t: Dict[str, Any]) -> Tuple[int, int]:
        pr = str(t.get("priority", "medium")).lower()
        return (priority_rank.get(pr, 2), _parse_minutes(t.get("estimated_minutes", 30), 30))

    sorted_tasks = sorted(tasks, key=rank, reverse=True)

    remaining = planned_minutes
    items = []
    for t in sorted_tasks:
        if remaining <= 0:
            break
        est = _parse_minutes(t.get("estimated_minutes", 30), 30)
        dur = min(est, remaining)

        start = cursor
        end = cursor + timedelta(minutes=dur)

        items.append({
            "task_id": t.get("id"),
            "title": t.get("title", "Task"),
            "start_time": start.strftime("%H:%M"),
            "end_time": end.strftime("%H:%M"),
            "minutes": dur,
            "reason": "Scheduled by fallback (no OpenAI key configured).",
        })

        cursor = end
        remaining -= dur

    return {
        "planned_minutes": planned_minutes,
        "day_start": _clean_hhmm(day_start),
        "ai_used": False,
        "items": items,
    }


def _safe_json_extract(text: str) -> Optional[Dict[str, Any]]:
    """
    Tries to extract a JSON object from a model output.
    """
    text = text.strip()

    # If it's already pure JSON
    if text.startswith("{") and text.endswith("}"):
        try:
            return json.loads(text)
        except Exception:
            pass

    # Try to find the first {...} block
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        chunk = text[start:end + 1]
        try:
            return json.loads(chunk)
        except Exception:
            return None

    return None


def generate_daily_plan(
    tasks: List[Dict[str, Any]],
    day_start: str = "09:00",
    planned_minutes: int = 30,
) -> Dict[str, Any]:
    """
    Returns:
      {
        "planned_minutes": int,
        "day_start": "HH:MM",
        "ai_used": bool,
        "items": [
          {
            "task_id": int | null,
            "title": str,
            "start_time": "HH:MM",
            "end_time": "HH:MM",
            "minutes": int,
            "reason": str
          }
        ]
      }
    """
    day_start = _clean_hhmm(day_start, "09:00")
    planned_minutes = _parse_minutes(planned_minutes, 30)

    client = _get_openai_client()
    if client is None:
        return _fallback_schedule(tasks, day_start, planned_minutes)

    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    # Keep prompt non-personalized: only tasks list + time window.
    # We explicitly tell it to not reference private/user data.
    sys = (
        "You are a scheduling assistant. "
        "Create a realistic focused study plan for today from the provided tasks. "
        "Do NOT use personal data. Do NOT mention any private info. "
        "Return STRICT JSON only (no markdown, no extra text)."
    )

    user = {
        "day_start": day_start,
        "planned_minutes": planned_minutes,
        "tasks": [
            {
                "id": t.get("id"),
                "title": t.get("title"),
                "priority": t.get("priority"),
                "estimated_minutes": t.get("estimated_minutes"),
                "due_datetime": t.get("due_datetime"),
            }
            for t in tasks
        ],
        "output_schema": {
            "planned_minutes": "int",
            "day_start": "HH:MM",
            "items": [
                {
                    "task_id": "int|null",
                    "title": "string",
                    "start_time": "HH:MM",
                    "end_time": "HH:MM",
                    "minutes": "int",
                    "reason": "string"
                }
            ]
        }
    }

    try:
        # openai>=1.x chat.completions
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": sys},
                {"role": "user", "content": json.dumps(user)},
            ],
            temperature=0.3,
        )
        text = resp.choices[0].message.content or ""
        data = _safe_json_extract(text)
        if not data or "items" not in data:
            return _fallback_schedule(tasks, day_start, planned_minutes)

        # Normalize + safety
        data["planned_minutes"] = _parse_minutes(data.get("planned_minutes", planned_minutes), planned_minutes)
        data["day_start"] = _clean_hhmm(data.get("day_start", day_start), day_start)
        data["ai_used"] = True

        clean_items = []
        for it in data.get("items", []):
            clean_items.append({
                "task_id": it.get("task_id"),
                "title": str(it.get("title", "Task")),
                "start_time": _clean_hhmm(str(it.get("start_time", day_start)), day_start),
                "end_time": _clean_hhmm(str(it.get("end_time", day_start)), day_start),
                "minutes": _parse_minutes(it.get("minutes", 25), 25),
                "reason": str(it.get("reason", "Scheduled by AI.")),
            })
        data["items"] = clean_items

        return data
    except Exception:
        # Never crash the API if OpenAI fails
        return _fallback_schedule(tasks, day_start, planned_minutes)
