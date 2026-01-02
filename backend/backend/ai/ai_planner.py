# finalbackend/ai/ai_planner.py
from __future__ import annotations

import json
import os
import re
import random
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
    external_events: List[Dict[str, Any]] = [],
    focus_categories: List[str] = [],
) -> Dict[str, Any]:
    """
    Non-AI fallback with Smart Prioritization & Basic Suggestions.
    """
    today = datetime.now()
    cursor = _dt_from_day_start(today, _clean_hhmm(day_start))
    cursor = _round_to_5(cursor)

    # 1. Generate Mock Suggestions based on categories
    suggestions = []
    
    # Rich activity database for "Simulated AI"
    activity_db = {
        "health": ["HIIT Workout", "Yoga & Stretching", "Meal Prep for the Week", "Afternoon Walk", "Meditation Session", "Drink 1L Water"],
        "work": ["Clear Email Inbox", "Deep Work: Project Planning", "Documentation Review", "Team Sync Prep", "Code Refactoring"],
        "study": ["Read Chapter & Summarize", "Flashcards Review", "Watch Educational Video", "Practice Problems", "Research Topic"],
        "finance": ["Review Weekly Expenses", "Pay Pending Bills", "Adjust Monthly Budget", "Check Investment Portfolio"],
        "personal": ["Journaling Session", "Call a Friend/Family", "Read a Book", "Tidy Up Workspace", "Hobby Time"],
        "general": ["Plan Tomorrow", "Review Goals", "Declutter Room"]
    }

    if focus_categories:
        for cat in focus_categories:
            lower_cat = cat.lower()
            
            # Find best matching key
            matched_key = "general"
            for key in activity_db:
                if key in lower_cat:
                    matched_key = key
                    break
            
            # Pick a random unique task
            possible_tasks = activity_db.get(matched_key, activity_db["general"])
            topic = random.choice(possible_tasks)
            
            # Format: "[Health] HIIT Workout"
            display_title = f"[{cat.capitalize()}] {topic}"
            
            suggestions.append({"title": display_title, "cat": cat, "min": 30}) # Default 30 min for suggestions

    # Add suggestions to the task pool as 'high' priority for now, to ensure they get scheduled
    # We treat them as dicts similar to tasks
    mock_id_counter = -1
    for s in suggestions:
        tasks.append({
            "id": mock_id_counter, 
            "title": s["title"],
            "priority": "high",
            "estimated_minutes": s["min"],
            "due_datetime": datetime.now().isoformat(), # Treat as due today
            "category": s["cat"]
        })
        mock_id_counter -= 1

    priority_rank = {"high": 3, "medium": 2, "low": 1}

    def get_sort_key(t: Dict[str, Any]):
        # ... (same sort logic as before) ...
        # Parse Due Date
        due_str = t.get("due_datetime")
        due_dt = None
        if due_str:
            try:
                if isinstance(due_str, datetime): due_dt = due_str
                else: due_dt = datetime.fromisoformat(due_str)
            except ValueError:
                pass
        
        # Priority Value
        p_val = priority_rank.get(str(t.get("priority", "medium")).lower(), 2)
        
        # Boost if category matches focus
        cat_boost = 0
        t_cat = t.get("category", "")
        if t_cat and focus_categories and t_cat in focus_categories:
             cat_boost = 5 # Huge boost
        
        # Calculate Category
        # 0: Overdue or Due Today (Most Urgent)
        # 1: Future Due Date
        # 2: No Due Date
        
        category = 2
        sort_date = datetime.max # For valid comparison
        
        if due_dt:
            # Check if overdue or today
            if due_dt.date() <= today.date():
                category = 0
            else:
                category = 1
                sort_date = due_dt
        
        if category == 0:
            return (0, -cat_boost, -p_val, 0) 
        elif category == 1:
            return (1, -cat_boost, sort_date.timestamp(), -p_val) 
        else:
            return (2, -cat_boost, 0, -p_val) 

    sorted_tasks = sorted(tasks, key=get_sort_key)

    remaining = planned_minutes
    items = []
    
    used_ids = set()

    # Convert events to datetime objects for collision detection
    busy_slots = []
    for evt in external_events:
        try:
            # handle both string and datetime
            s = evt["start"] 
            e = evt["end"]
            if isinstance(s, str): s = datetime.fromisoformat(s)
            if isinstance(e, str): e = datetime.fromisoformat(e)
            busy_slots.append((s, e))
        except:
            pass
            
    busy_slots.sort(key=lambda x: x[0])

    def is_busy(start, end):
        for b_start, b_end in busy_slots:
            # Overlap logic
            if max(start, b_start) < min(end, b_end):
                return True
        return False

    total_minutes = 0
    
    for t in sorted_tasks:
        tid = t.get("id")
        if tid in used_ids: 
            continue
            
        if remaining <= 10: 
            break
            
        est = _parse_minutes(t.get("estimated_minutes", 30), 30)
        est = min(est, 90) 
        
        dur = min(est, remaining)
        
        # Find next available slot
        found_slot = False
        search_cursor = cursor
        for _ in range(24): # Try harder (2 hours search window)
            proposed_end = search_cursor + timedelta(minutes=dur)
            if not is_busy(search_cursor, proposed_end):
                cursor = search_cursor
                found_slot = True
                break
            search_cursor += timedelta(minutes=5)
            
        if not found_slot:
            continue

        start = cursor
        end = cursor + timedelta(minutes=dur)
        
        # Handle mock IDs (negative) -> return null task_id for frontend
        final_tid = tid if (isinstance(tid, int) and tid > 0) else None
        
        reason = "Scheduled by Smart Fallback."
        if final_tid is None:
            reason = "suggested based on category."

        items.append({
            "task_id": final_tid,
            "title": t.get("title", "Task"),
            "start_time": start, # Return datetime object, not string
            "end_time": end,     # Return datetime object
            "estimated_minutes": dur, # MATCH SCHEMA KEY
            "reason": reason,
            "priority": t.get("priority", "medium"),
        })

        used_ids.add(tid)
        cursor = end
        remaining -= dur
        total_minutes += dur

    return {
        "items": items,
        "total_minutes": total_minutes,
        "overloaded": False,
        "message": "AI planner fallback used with category suggestions.",
        "workload": {
            "status": "balanced",
            "summary": "Generated using fallback logic + suggestions.",
            "recommendation": "Review suggestions."
        },
        "external_events": external_events
    }


def _safe_json_extract(text: str) -> Optional[Dict[str, Any]]:
    """
    Tries to extract a JSON object from a model output.
    """
    text = text.strip()

    if text.startswith("{") and text.endswith("}"):
        try:
            return json.loads(text)
        except Exception:
            pass

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
    external_events: List[Dict[str, Any]] = [],
    user_profile: Dict[str, Any] = {},
    focus_categories: List[str] = [],
) -> Dict[str, Any]:
    
    day_start = _clean_hhmm(day_start, "09:00")
    planned_minutes = _parse_minutes(planned_minutes, 30)

    # If no AI key, use fallback
    client = _get_openai_client()
    if client is None:
        return _fallback_schedule(tasks, day_start, planned_minutes, external_events, focus_categories)


    model = os.getenv("OPENAI_MODEL", "gpt-4o")

    sys = (
        "You are a smart Personal Executive Assistant. "
        "Your goal is to organize the user's daily schedule efficiently. "
        "1. STRICTLY prioritize tasks by Importance (Priority: High > Medium > Low) and Urgency (Due Date). High priority tasks MUST be scheduled first. "
        "2. RESPECT EXTERNAL EVENTS. Do NOT schedule tasks during 'external_events' time ranges. "
        "3. Incorporate user habits/preferences if provided. "
        "4. **CRITICAL**: If 'focus_categories' are provided, you MUST ensure the schedule includes activities for them. "
        "   - First, schedule existing user tasks that match these categories. "
        "   - **THEN, GENEROUSLY SUGGEST NEW TASKS** (with null task_id) to fill the plan, specifically related to these categories. "
        "   - Examples: If 'Health' is selected, schedule '15 min Workout' or 'Meal Prep'. If 'Study' is selected, schedule 'Review Notes'. "
        "   - The user WANTS you to suggest these new activities."
        "5. Provide a 'workload_analysis' object with status (heavy/balanced/light), summary, and recommendations. "
        "6. Return STRICT JSON only."
    )

    user = {
        "day_start": day_start,
        "planned_minutes": planned_minutes,
        "focus_categories": focus_categories,
        "tasks": [
            {
                "id": t.get("id"),
                "title": t.get("title"),
                "priority": t.get("priority"),
                "category": t.get("category"),
                "estimated_minutes": t.get("estimated_minutes"),
                "due_datetime": t.get("due_datetime"),
            }
            for t in tasks
        ],
        "external_events": external_events,
        "user_profile": user_profile,
        "output_schema": {
            "planned_minutes": "int",
            "day_start": "HH:MM",
            "workload": {
                "status": "heavy | balanced | light",
                "summary": "string",
                "recommendation": "string"
            },
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
            return _fallback_schedule(tasks, day_start, planned_minutes, external_events)

        # Normalize data
        # data["planned_minutes"] = ... (Use total_minutes from items instead)
        data["day_start"] = _clean_hhmm(data.get("day_start", day_start), day_start)
        data["ai_used"] = True
        data["external_events"] = external_events # Pass back to frontend

        clean_items = []
        total_ai_mins = 0
        
        # Helper to convert HH:MM to datetime on the target day
        # We assume day_start is "HH:MM". We use today's date + that time as base, 
        # but really we just want the AI's provided time on "today".
        today_date = datetime.now().date()
        
        def to_dt(hhmm_str: str) -> datetime:
            cleaned = _clean_hhmm(str(hhmm_str), day_start)
            hh, mm = cleaned.split(":")
            return datetime(today_date.year, today_date.month, today_date.day, int(hh), int(mm))

        for it in data.get("items", []):
            mins = _parse_minutes(it.get("minutes", 25), 25)
            s_dt = to_dt(it.get("start_time", day_start))
            e_dt = to_dt(it.get("end_time", day_start))
            
            clean_items.append({
                "task_id": it.get("task_id"),
                "title": str(it.get("title", "Task")),
                "start_time": s_dt,
                "end_time": e_dt,
                "estimated_minutes": mins,
                "reason": str(it.get("reason", "Scheduled by AI.")),
                "priority": "medium", # AI might not return priority, safe default
            })
            total_ai_mins += mins
            
        # Ensure workload matches schema even if AI misses it
        workload = data.get("workload")
        if not workload or not isinstance(workload, dict):
            workload = {
                "status": "balanced",
                "summary": "AI generated plan.",
                "recommendation": "Review strictly."
            }

        return {
            "items": clean_items,
            "total_minutes": total_ai_mins,
            "overloaded": total_ai_mins > planned_minutes,
            "message": "AI generated plan.",
            "workload": workload,
            "external_events": external_events
        }
        
    except Exception:
        return _fallback_schedule(tasks, day_start, planned_minutes, external_events)
