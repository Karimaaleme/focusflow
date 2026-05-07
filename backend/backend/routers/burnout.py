from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta, timezone

from database import get_db
from models import User, Task, FocusSession
from auth import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


def to_naive_utc(dt):
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def compute_burnout(user: User, db: Session) -> dict:
    now = datetime.utcnow()
    week_ago = now - timedelta(days=7)
    two_weeks_ago = now - timedelta(days=14)

    tasks = db.query(Task).filter(Task.user_id == user.id).all()

    recent_tasks = [
        t for t in tasks
        if t.created_at and to_naive_utc(t.created_at) >= week_ago
    ]

    total_recent = len(recent_tasks)
    completed_recent = sum(1 for t in recent_tasks if t.is_completed)
    completion_rate = (completed_recent / total_recent) if total_recent > 0 else 1.0

    overdue_count = sum(
        1 for t in tasks
        if not t.is_completed
        and t.due_datetime
        and to_naive_utc(t.due_datetime) < now
    )

    all_sessions = db.query(FocusSession).filter(
        FocusSession.user_id == user.id
    ).all()

    current_week_sessions = [
        s for s in all_sessions
        if s.started_at and to_naive_utc(s.started_at) >= week_ago
    ]

    prev_week_sessions = [
        s for s in all_sessions
        if s.started_at
        and two_weeks_ago <= to_naive_utc(s.started_at) < week_ago
    ]

    current_week_focus = sum(s.focused_minutes or 0 for s in current_week_sessions)
    prev_week_focus = sum(s.focused_minutes or 0 for s in prev_week_sessions)

    focus_trend = 0.0
    if prev_week_focus > 0:
        focus_trend = (current_week_focus - prev_week_focus) / prev_week_focus

    avg_daily_focus = current_week_focus / 7
    overload_score = min(1.0, avg_daily_focus / 300)

    score = 0

    if completion_rate < 0.5:
        score += 35
    elif completion_rate < 0.7:
        score += 20
    elif completion_rate < 0.85:
        score += 10

    if overdue_count > 5:
        score += 25
    elif overdue_count > 2:
        score += 15
    elif overdue_count > 0:
        score += 8

    if focus_trend < -0.3:
        score += 20
    elif focus_trend < -0.1:
        score += 10

    if overload_score > 0.8:
        score += 20
    elif overload_score > 0.6:
        score += 10

    score = min(100, score)

    if score >= 65:
        risk_level = "high"
        recommendation = (
            "You're showing clear signs of burnout. Try reducing your task load today, "
            "take a proper break, and avoid scheduling anything non-critical."
        )
    elif score >= 35:
        risk_level = "moderate"
        recommendation = (
            "Moderate stress detected. Clear a couple of overdue items and schedule "
            "one short focus session — momentum helps."
        )
    else:
        risk_level = "low"
        recommendation = (
            "You're in good shape. Keep your current rhythm — consistency compounds over time."
        )

    return {
        "score": score,
        "risk_level": risk_level,
        "recommendation": recommendation,
        "factors": {
            "completion_rate_pct": round(completion_rate * 100, 1),
            "overdue_tasks": overdue_count,
            "focus_trend_pct": round(focus_trend * 100, 1),
            "avg_daily_focus_minutes": round(avg_daily_focus, 1),
            "total_tasks_this_week": total_recent,
            "current_week_focus_minutes": current_week_focus,
        },
    }


@router.get("/burnout")
def get_burnout_score(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return compute_burnout(current_user, db)