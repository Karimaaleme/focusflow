from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from slowapi import Limiter
from slowapi.util import get_remote_address
from database import get_db
from auth import get_current_user
from models import User, Task, UserProfile
from schemas import AIPlanRequest, AIPlanResponse, AIPlanItem, TaskCreate
from ai.ai_planner import generate_daily_plan
from integrations.calendar_service import CalendarService

router = APIRouter(
    prefix="/planner",
    tags=["Planner"]
)
limiter = Limiter(key_func=get_remote_address)

@router.post("/generate", response_model=AIPlanResponse)
@limiter.limit("10/minute")
def generate_plan(
    request: Request,  # noqa: ARG001 — required by slowapi limiter
    payload: AIPlanRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generates a daily plan based on user tasks, preferences, and external events.
    """
    print(f"DEBUG: Generating plan for {current_user.email}")
    try:
        # 1. Fetch Candidates: Tasks that are NOT completed
        tasks = (
            db.query(Task)
            .filter(Task.user_id == current_user.id, Task.is_completed == False)
            .all()
        )
        print(f"DEBUG: Found {len(tasks)} tasks")

        # 2. Fetch User Profile for habits/preferences
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        profile_data = {}
        if profile:
            profile_data = {
                "best_time_of_day": profile.best_time_of_day,
                "focus_style": profile.focus_style,
                "main_struggle": profile.main_struggle
            }

        # 3. Fetch External Calendar Events (if enabled)
        events = []
        try:
            cal_service = CalendarService()
            now = datetime.now()
            events = cal_service.fetch_events(
                now, 
                now.replace(hour=23, minute=59), # End of today
                enable_google=payload.enable_google,
                enable_outlook=payload.enable_outlook
            )
            print(f"DEBUG: Fetched {len(events)} calendar events")
        except Exception as e:
            print(f"WARNING: Calendar fetch failed (ignoring): {e}")

        # 4. Prepare Task Data
        task_dicts = []
        for t in tasks:
            task_dicts.append({
                "id": t.id,
                "title": t.title,
                "priority": str(t.priority.value if hasattr(t.priority, 'value') else t.priority), 
                "category": t.category,
                "estimated_minutes": t.estimated_minutes,
                "due_datetime": t.due_datetime.isoformat() if t.due_datetime else None
            })

        # 5. Call AI (or Fallback) Planner
        plan = generate_daily_plan(
            tasks=task_dicts,
            day_start=payload.day_start, # e.g. "09:00"
            planned_minutes=payload.planned_minutes,
            external_events=events,
            user_profile=profile_data,
            focus_categories=payload.focus_categories
        )
        
        return plan

    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Planner Error: {str(e)}")


@router.post("/apply")
def apply_plan(
    items: List[AIPlanItem],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Applies the accepted plan:
    - Updates existing tasks with new 'due_datetime' (used as start time here) and statuses.
    - Creates NEW tasks for suggestions that didn't exist before.
    """
    applied_count = 0
    created_count = 0

    for item in items:
        # If it has a task_id, update the existing task
        if item.task_id:
            task = db.query(Task).filter(Task.id == item.task_id, Task.user_id == current_user.id).first()
            if task:
                # Update schedule
                # We use 'due_datetime' to represent the PROPOSED START TIME in the plan 
                # (since we don't have a separate 'planned_start' field yet, leveraging due_datetime is a common pattern, 
                # or strictly we should add a field, but let's stick to existing schema constraints for now).
                # Actually, better: Let's assume due_datetime is the deadline. 
                # Does Task have a planned start? No. 
                # So we will set 'due_datetime' to the END of the slot to ensure it's "due" by then? 
                # Or we can just update the status to 'in_progress' / 'todo' with a high priority?
                # User request: "Reflected in the Task List... Added to Calendar"
                
                # Let's set the due_datetime to the plan's end_time, so it shows up in "Today" views correctly.
                task.due_datetime = item.end_time
                
                # Update status to indicate it's active/planned
                # task.status = "todo" # Keep as todo, but maybe prioritized?
                
                # Update priority if the plan deemed it important? 
                # Let's keep original priority to avoid overriding user intent too much.
                
                applied_count += 1
        
        # If no task_id, it's a new suggestion (e.g. "Review Notes")
        else:
            # Create a new task
            new_task = Task(
                user_id=current_user.id,
                title=item.title,
                description=item.reason or "Added via Smart Planner",
                category="general", # Could infer from title but default safe
                priority="medium",
                status="todo",
                estimated_minutes=item.estimated_minutes,
                due_datetime=item.end_time, # Plan it for today
                is_recurring=False
            )
            db.add(new_task)
            created_count += 1

    db.commit()

    return {
        "message": "Plan applied successfully",
        "updated": applied_count,
        "created": created_count
    }
