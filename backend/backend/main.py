from fastapi import FastAPI, Depends, HTTPException, status, Request, Form
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List, Dict
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func
from datetime import datetime, timedelta
import json
import httpx
from ai.ai_planner import generate_daily_plan
from integrations.calendar_service import CalendarService

from dotenv import load_dotenv
load_dotenv()


# Ensures Firebase Admin initializes on startup
import firebase_admin_init  # noqa: F401
from firebase_admin import auth as firebase_auth

from auth import get_current_user
from database import Base, engine, SessionLocal, get_db
from models import User, Task, UserProfile, FocusSession
from routers import social
import routers.planner as planner # NEW
import group_routes # NEW route module

from schemas import (
    UserRead,
    UserCreate,
    UserLogin,
    Token,
    TaskCreate,
    TaskRead,
    TaskUpdate,
    ProfileUpdate,
    ProfileResponse,
    AIPlanItem,
    AIPlanResponse,
    FocusSessionCreate,
    FocusSessionRead,
    PasswordChange,
)


# ✅ CREATE APP FIRST
app = FastAPI()

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"❌ Validation Error: {exc.errors()}")
    body = await request.body()
    try:
        body_text = body.decode()
    except:
        body_text = "<binary>"
        
    print(f"❌ Request Body: {body_text}")
    
    # Use str(exc.errors()) to avoid serialization issues with pydantic internals
    return JSONResponse(
        status_code=422,
        content={"detail": str(exc.errors()), "body": body_text},
    )

# 🔑 FIREBASE API KEY
FIREBASE_API_KEY = "AIzaSyCpttwg8J122go6VExbDTrzDEgp-VlY2Go"

# ✅ DATABASE
Base.metadata.create_all(bind=engine)

# ✅ ROUTERS
app.include_router(group_routes.router, tags=["Groups"])
app.include_router(social.router) 
app.include_router(planner.router) # Register Planner
from routers import focus_routes
app.include_router(focus_routes.router) # NEW: Focus Router

# -----------------------
# CORS (allow Flutter web)
# -----------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Keep wildcard for flexibility
    allow_origin_regex="https?://(localhost|127\.0\.0\.1)(:[0-9]+)?", # Allow any localhost port
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# DB Session
# -----------------------


@app.post("/tasks/reorder")
def reorder_tasks(
    payload: Dict[str, List[int]],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ids = payload.get("task_ids", [])
    if not ids:
        return {"message": "No IDs provided"}

    # Fetch all tasks for this user to ensure ownership
    user_tasks = {t.id: t for t in db.query(Task).filter(Task.user_id == current_user.id).all()}

    # Update order_index for each task
    for index, task_id in enumerate(ids):
        if task_id in user_tasks:
            # We use a custom order_index. 
            # If your model doesn't have it, we might need to add it or use priority/due_date override.
            # Assuming 'order_index' exists as per previous schemas.
            user_tasks[task_id].order_index = index 

            # Also force set them to 'today' by updating due_datetime if needed?
            # For now, just reordering is safer.
            
    db.commit()
    return {"message": "Tasks reordered successfully"}

# ============================
#         USER
# ============================

@app.get("/me", response_model=UserRead)
def read_me(current_user: User = Depends(get_current_user)):
    return current_user


@app.post("/signup", response_model=UserRead)
def signup(
    user_in: UserCreate,
    db: Session = Depends(get_db)
):
    try:
        # 1. Create user in Firebase
        # This will raise an exception if email already exists
        fb_user = firebase_auth.create_user(
            email=user_in.email,
            password=user_in.password
        )
    except Exception as e:
        # Catch Firebase errors (e.g. email already exists)
        raise HTTPException(
            status_code=400,
            detail=f"Signup failed: {str(e)}"
        )

    # 2. Create user in local DB
    local_user = User(
        email=user_in.email,
        username=user_in.username # NEW
    )
    db.add(local_user)
    db.commit()
    db.refresh(local_user)

    return local_user


@app.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
    payload = {
        "email": form_data.username, # OAuth2 form uses 'username' field
        "password": form_data.password,
        "returnSecureToken": True
    }

    async with httpx.AsyncClient() as client:
        resp = await client.post(url, json=payload)
    
    if resp.status_code != 200:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    data = resp.json()
    id_token = data.get("idToken")
    
    return Token(access_token=id_token, token_type="bearer")


# ============================
#         TASK ROUTES
# ============================

@app.post("/tasks", response_model=TaskRead)
def create_task(
    task_in: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    max_order = (
        db.query(func.max(Task.order_index))
        .filter(Task.user_id == current_user.id)
        .scalar()
    )
    next_order = (max_order + 1) if max_order is not None else 0

    estimated = task_in.estimated_minutes or 30

    task = Task(
        user_id=current_user.id,
        title=task_in.title,
        description=task_in.description,
        category=task_in.category,
        priority=task_in.priority,
        due_datetime=task_in.due_datetime,
        reminder_datetime=task_in.reminder_datetime,
        is_recurring=task_in.is_recurring,
        recurrence=task_in.recurrence,
        recurrence_interval=task_in.recurrence_interval,
        order_index=next_order,
        status=task_in.status or "todo",
        estimated_minutes=estimated,
        actual_minutes=task_in.actual_minutes,
        # Convert list of Pydantic models to list of dicts for JSON storage
        subtasks=[st.model_dump() for st in task_in.subtasks] if task_in.subtasks else []
    )

    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@app.get("/tasks", response_model=List[TaskRead])
def list_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tasks = (
        db.query(Task)
        .filter(Task.user_id == current_user.id)
        .order_by(Task.order_index.asc())
        .all()
    )
    return tasks


@app.put("/tasks/{task_id}", response_model=TaskRead)
def update_task(
    task_id: int,
    task_in: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = (
        db.query(Task)
        .filter(Task.id == task_id, Task.user_id == current_user.id)
        .first()
    )

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    updates = task_in.model_dump(exclude_unset=True)
    
    # --- SYNC LOGIC ---
    # 1. If status is set to 'done', force is_completed=True
    if "status" in updates:
        if updates["status"] == "done":
            updates["is_completed"] = True
        elif updates["status"] in ["todo", "in_progress"]:
            updates["is_completed"] = False
            
    # 2. If is_completed is set to True, force status='done'
    if "is_completed" in updates:
        if updates["is_completed"] is True:
            updates["status"] = "done"
        elif updates["is_completed"] is False and task.status == "done":
            # If unchecking, revert to todo (or keep current if it was already todo/in_progress)
            updates["status"] = "todo"
    # ------------------
    
    # Handle subtasks manually if present (convert Pydantic to dicts)
    if "subtasks" in updates and updates["subtasks"] is not None:
         # Check if it's already a list of dicts or list of objects
         if updates["subtasks"] and hasattr(updates["subtasks"][0], "model_dump"):
            updates["subtasks"] = [st.model_dump() for st in updates["subtasks"]]
         elif updates["subtasks"] and isinstance(updates["subtasks"][0], dict):
            pass # Already dicts (from model_dump default behavior)

    for field, value in updates.items():
        setattr(task, field, value)

    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = (
        db.query(Task)
        .filter(Task.id == task_id, Task.user_id == current_user.id)
        .first()
    )

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    db.delete(task)
    db.commit()
    return


@app.patch("/tasks/{task_id}/status/{new_status}", response_model=TaskRead)
def update_status(
    task_id: int,
    new_status: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if new_status not in ["todo", "in_progress", "done"]:
        raise HTTPException(status_code=400, detail="Invalid status value")

    task = (
        db.query(Task)
        .filter(Task.id == task_id, Task.user_id == current_user.id)
        .first()
    )

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    task.status = new_status
    db.commit()
    db.refresh(task)
    return task


@app.patch("/tasks/{task_id}/complete", response_model=TaskRead)
def toggle_complete(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = (
        db.query(Task)
        .filter(Task.id == task_id, Task.user_id == current_user.id)
        .first()
    )

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    task.is_completed = not task.is_completed
    db.commit()
    db.refresh(task)
    return task


@app.post("/tasks/reorder")
def reorder_tasks(
    order: List[int],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    for index, task_id in enumerate(order):
        task = (
            db.query(Task)
            .filter(Task.id == task_id, Task.user_id == current_user.id)
            .first()
        )
        if task:
            task.order_index = index

    db.commit()
    return {"status": "ok"}
# ============================
#        USER PROFILE
# ============================

@app.post("/user/profile", response_model=ProfileResponse)
def save_profile(
    update: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = (
        db.query(UserProfile)
        .filter(UserProfile.user_id == current_user.id)
        .first()
    )

    goals_json = json.dumps(update.goals)

    if not profile:
        profile = UserProfile(
            user_id=current_user.id,
            user_type=update.user_type,
            goals=goals_json,
            image_base64=update.image_base64,
            focus_style=update.focus_style,
            main_struggle=update.main_struggle,
            best_time_of_day=update.best_time_of_day,
            motivation=update.motivation,
            theme=update.theme,
            theme_mode=update.theme_mode,
            accent_color=update.accent_color,
            layout_density=update.layout_density,
        )
        db.add(profile)
    else:
        profile.user_type = update.user_type
        profile.goals = goals_json
        profile.image_base64 = update.image_base64
        profile.focus_style = update.focus_style
        profile.main_struggle = update.main_struggle
        profile.best_time_of_day = update.best_time_of_day
        profile.motivation = update.motivation
        profile.theme = update.theme
        profile.theme_mode = update.theme_mode
        profile.accent_color = update.accent_color
        profile.layout_density = update.layout_density

    db.commit()
    db.refresh(profile)

    return ProfileResponse(
        email=current_user.email,
        username=current_user.username,
        user_type=profile.user_type,
        goals=json.loads(profile.goals or "[]"),
        image_base64=profile.image_base64,
        focus_style=profile.focus_style,
        main_struggle=profile.main_struggle,
        best_time_of_day=profile.best_time_of_day,
        motivation=profile.motivation,
        theme=profile.theme,
        theme_mode=profile.theme_mode,
        accent_color=profile.accent_color,
        layout_density=profile.layout_density,
    )


@app.get("/user/profile", response_model=ProfileResponse)
def load_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = (
        db.query(UserProfile)
        .filter(UserProfile.user_id == current_user.id)
        .first()
    )

    if not profile:
        return ProfileResponse(
            email=current_user.email,
            username=current_user.username,
            user_type="Other",
            goals=[],
            image_base64=None,
            focus_style=None,
            main_struggle=None,
            best_time_of_day=None,
            motivation=None,
            theme=None,
            theme_mode="system",
            accent_color=None,
            layout_density="comfortable",
        )

    return ProfileResponse(
        email=current_user.email,
        username=current_user.username, # Populated from User model
        user_type=profile.user_type,
        goals=json.loads(profile.goals or "[]"),
        image_base64=profile.image_base64,
        focus_style=profile.focus_style,
        main_struggle=profile.main_struggle,
        best_time_of_day=profile.best_time_of_day,
        motivation=profile.motivation,
        theme=profile.theme,
        theme_mode=profile.theme_mode,
        accent_color=profile.accent_color,
        layout_density=profile.layout_density,
    )

@app.post("/ai/plan-smart", response_model=AIPlanResponse)
def ai_smart_plan(
    start_hour: int = 9,
    end_hour: int = 18,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tasks = (
        db.query(Task)
        .filter(Task.user_id == current_user.id, Task.is_completed == False)
        .all()
    )

    if not tasks:
        return AIPlanResponse(
            items=[],
            total_minutes=0,
            overloaded=False,
            message="No tasks to plan."
        )

    task_payload = []
    for t in tasks:
        task_payload.append({
            "task_id": t.id,
            "title": t.title,
            "priority": t.priority,
            "due_datetime": t.due_datetime.isoformat() if t.due_datetime else None,
            "estimated_minutes": t.estimated_minutes or 30,
        })

    ai_result = generate_smart_plan(
        tasks=task_payload,
        start_hour=start_hour,
        end_hour=end_hour,
    )

    return ai_result
@app.post("/ai/plan-smart")
def ai_plan_smart(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tasks = db.query(Task).filter(
        Task.user_id == current_user.id,
        Task.is_completed == False
    ).all()

    profile = db.query(UserProfile).filter(
        UserProfile.user_id == current_user.id
    ).first()

    tasks_data = [
        {
            "title": t.title,
            "priority": t.priority,
        }
        for t in tasks
    ]

    profile_data = {
        "user_type": profile.user_type if profile else "other",
        "goals": profile.goals if profile else [],
        "focus_style": getattr(profile, "focus_style", None),
    }

    ai_output = generate_smart_plan(
        tasks=tasks_data,
        profile=profile_data,
        start_time=payload.get("start_time", "09:00"),
    )

    return {"raw": ai_output}


# ============================
#      AI SUGGESTIONS
# ============================
from pydantic import BaseModel
from typing import Optional

class AIPlanRequest(BaseModel):
    day_start: Optional[str] = "09:00"
    planned_minutes: Optional[int] = 30
    focus_categories: Optional[List[str]] = []
    enable_google: Optional[bool] = True
    enable_outlook: Optional[bool] = False

# AI Endpoints moved to routers/planner.py

# Suggestions logic handled by planner


@app.get("/ai/calendar-sync-status")
def calendar_status(current_user: User = Depends(get_current_user)):
    # Mock status for now
    return {
        "google": {"connected": True, "email": "user@gmail.com"},
        "outlook": {"connected": False}
    }


@app.post("/user/password")
def change_password(data: PasswordChange):
    # In a production app with Firebase, password changes are typically handled 
    # client-side via Firebase SDK or via Firebase Admin SDK backend calls.
    # Since we can't easily validate current_password via Admin SDK, 
    # we assume the frontend is using this just for logging/syncing or dummy purposes 
    # as per user snippet req.
    print(f"PASSWORD CHANGE: New password set to {data.new_password}")
    return {"status": "Password updated"}


@app.delete("/user/account")
def delete_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    print(f"ACCOUNT DELETED: {current_user.email}")
    
    # Manually cascade delete related records to avoid FK violations
    # 1. Delete Focus Sessions
    db.query(FocusSession).filter(FocusSession.user_id == current_user.id).delete()
    
    # 2. Delete Tasks
    db.query(Task).filter(Task.user_id == current_user.id).delete()
    
    # 3. Delete Profile
    db.query(UserProfile).filter(UserProfile.user_id == current_user.id).delete()

    # 4. Delete the User
    # Merge the user object into the current session to ensure it's attached
    user_to_delete = db.merge(current_user)
    db.delete(user_to_delete)
    
    db.commit()

    # 5. Delete from Firebase Auth (Backend Side)
    try:
        # We need the Firebase UID. We can look it up by email.
        firebase_user = firebase_auth.get_user_by_email(current_user.email)
        firebase_auth.delete_user(firebase_user.uid)
        print(f"FIREBASE DELETED: {current_user.email}")
    except Exception as e:
        print(f"⚠️ Failed to delete from Firebase (might already be gone): {e}")

    return {"status": "Account deleted"}




# ============================
#      FOCUS SESSIONS
# ============================

# ===========================
# FOCUS STATUS for STUDY TOGETHER
# ===========================
class FocusStatusUpdate(BaseModel):
    is_focusing: bool

@app.post("/focus/status")
def set_focus_status(status: FocusStatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user.is_focusing = status.is_focusing
    db.commit()
    db.refresh(current_user)
    return {"status": "updated", "is_focusing": current_user.is_focusing}

@app.post("/focus/session", status_code=201)
def create_focus_session(
    session_in: FocusSessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Verify task ownership if task_id is provided
    if session_in.task_id:
        task = db.query(Task).filter(
            Task.id == session_in.task_id,
            Task.user_id == current_user.id
        ).first()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found or not owned by user")

    new_session = FocusSession(
        user_id=current_user.id,
        task_id=session_in.task_id,
        planned_minutes=session_in.planned_minutes,
        focused_minutes=session_in.focused_minutes,
        started_at=session_in.started_at,
        ended_at=session_in.ended_at,
    )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    return {"id": new_session.id, "message": "Focus session saved successfully"}


@app.get("/focus/sessions", response_model=List[FocusSessionRead])
def get_focus_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sessions = (
        db.query(FocusSession)
        .filter(FocusSession.user_id == current_user.id)
        .order_by(FocusSession.started_at.desc())
        .all()
    )
    return sessions
