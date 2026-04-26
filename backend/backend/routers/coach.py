from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import os
import json

from slowapi import Limiter
from slowapi.util import get_remote_address

from database import get_db
from models import User, Task, FocusSession, UserProfile
from auth import get_current_user
from routers.burnout import compute_burnout

router = APIRouter(prefix="/coach", tags=["Coach"])
limiter = Limiter(key_func=get_remote_address)


def _openai_client():
    key = os.getenv("OPENAI_API_KEY")
    if not key:
        return None
    try:
        from openai import OpenAI
        return OpenAI(api_key=key)
    except Exception:
        return None


def detect_personality(user: User, db: Session) -> str:
    now = datetime.utcnow()
    week_ago = now - timedelta(days=7)

    tasks = db.query(Task).filter(Task.user_id == user.id).all()
    recent = [t for t in tasks if t.created_at and t.created_at >= week_ago]
    overdue = sum(1 for t in tasks if not t.is_completed and t.due_datetime and t.due_datetime < now)
    completed_r = sum(1 for t in recent if t.is_completed)
    rate = completed_r / len(recent) if recent else 1.0

    sessions = db.query(FocusSession).filter(
        FocusSession.user_id == user.id,
        FocusSession.started_at >= week_ago,
    ).all()
    avg_focus = sum(s.focused_minutes for s in sessions) / len(sessions) if sessions else 0

    if overdue > 3 or rate < 0.4:
        return "procrastinator"
    if avg_focus > 120 or (rate > 0.9 and len(sessions) > 5):
        return "overachiever"
    if len(sessions) < 2 and len(recent) > 2:
        return "distracted"
    if rate > 0.8 and len(sessions) >= 3:
        return "consistent"
    return "balanced"


def _fallback_insight(username: str, personality: str, burnout: dict, completed: int, focus_min: int) -> dict:
    templates = {
        "procrastinator": {
            "greeting": f"Hey {username}, let's get moving today 💪",
            "summary": f"You've completed {completed} tasks and logged {focus_min} focus minutes this week.",
            "main_insight": "Breaking tasks into smaller pieces makes it much easier to start.",
            "suggestion": "Pick your most overdue task and spend just 10 minutes on it right now.",
            "encouragement": "Starting is always the hardest part — you've got this!",
        },
        "consistent": {
            "greeting": f"Great to see you, {username} — you're on a roll 🔥",
            "summary": f"Impressive: {completed} tasks done and {focus_min} focus minutes this week.",
            "main_insight": "Your consistency is your superpower — keep building that streak.",
            "suggestion": "Try one task slightly outside your comfort zone today.",
            "encouragement": "Steady progress separates high performers from everyone else!",
        },
        "distracted": {
            "greeting": f"Hi {username}, let's refocus together 🧠",
            "summary": f"You've set up {completed} tasks but focus sessions have been light this week.",
            "main_insight": "Creating tasks is great — now execute them with focused sessions.",
            "suggestion": "Start one 25-minute focus session on your highest priority task.",
            "encouragement": "Small focused bursts build real momentum over time!",
        },
        "overachiever": {
            "greeting": f"Hey {username}, you're crushing it — but let's check in 🌟",
            "summary": f"You've been incredibly productive: {completed} tasks and {focus_min} minutes focused.",
            "main_insight": "Sustainable pace matters more than maximum output.",
            "suggestion": "Schedule a proper break today — rest is part of peak performance.",
            "encouragement": "True champions know when to recharge. You deserve it!",
        },
        "balanced": {
            "greeting": f"Hey {username}, you're in a great place ✨",
            "summary": f"Solid week: {completed} tasks done and {focus_min} focus minutes logged.",
            "main_insight": "You're maintaining a healthy balance between tasks and focused work.",
            "suggestion": "Plan tomorrow's top 3 tasks tonight to keep the momentum.",
            "encouragement": "Balance is the secret to long-term success — keep it up!",
        },
    }
    data = dict(templates.get(personality, templates["balanced"]))
    data["personality_label"] = personality
    data["burnout_score"] = burnout["score"]
    data["burnout_risk"] = burnout["risk_level"]
    data["personality"] = personality
    return data


@router.get("/daily-insight")
@limiter.limit("10/minute")
def get_daily_insight(
    request: Request,  # noqa: ARG001
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    week_ago = now - timedelta(days=7)

    tasks = db.query(Task).filter(Task.user_id == current_user.id).all()
    sessions = db.query(FocusSession).filter(
        FocusSession.user_id == current_user.id,
        FocusSession.started_at >= week_ago,
    ).all()
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()

    completed = [t for t in tasks if t.is_completed]
    pending = [t for t in tasks if not t.is_completed]
    overdue = [t for t in pending if t.due_datetime and t.due_datetime < now]
    total_focus = sum(s.focused_minutes for s in sessions)

    personality = detect_personality(current_user, db)
    burnout = compute_burnout(current_user, db)
    username = current_user.username or f"User_{current_user.id}"

    client = _openai_client()
    if client:
        context = (
            f"User: {username}\n"
            f"Personality type: {personality}\n"
            f"Tasks this week: {len(tasks)} total, {len(completed)} completed, {len(overdue)} overdue\n"
            f"Focus sessions: {len(sessions)} sessions, {total_focus} total minutes\n"
            f"Burnout risk: {burnout['risk_level']} (score: {burnout['score']}/100)\n"
            f"Main struggle: {profile.main_struggle if profile else 'unknown'}\n"
            f"Motivation style: {profile.motivation if profile else 'unknown'}"
        )
        try:
            resp = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o"),
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are FocusFlow's AI Productivity Coach. Respond with warm, concise, personalized insights.\n"
                            "Return ONLY valid JSON (no markdown) with keys:\n"
                            "greeting, summary, main_insight, suggestion, encouragement, personality_label"
                        ),
                    },
                    {"role": "user", "content": f"Give me my daily coaching insight.\n\n{context}"},
                ],
                temperature=0.7,
                max_tokens=400,
            )
            raw = resp.choices[0].message.content.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            result = json.loads(raw)
            result["burnout_score"] = burnout["score"]
            result["burnout_risk"] = burnout["risk_level"]
            result["personality"] = personality
            return result
        except Exception as e:
            print(f"Coach AI error: {e}")

    return _fallback_insight(username, personality, burnout, len(completed), total_focus)
