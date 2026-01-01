# schemas.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# =======================
# TASK SCHEMAS
# =======================
# =======================
# TASK SCHEMAS
# =======================
class SubTask(BaseModel):
    title: str
    is_completed: bool = False

class TaskBase(BaseModel):
    title: str
    description: Optional[str] = ""
    category: Optional[str] = "general"
    priority: str = "medium"
    due_datetime: Optional[datetime] = None
    reminder_datetime: Optional[datetime] = None
    is_recurring: bool = False
    recurrence: Optional[str] = None
    recurrence_interval: Optional[int] = None
    status: str = "todo"
    estimated_minutes: Optional[int] = 30
    actual_minutes: Optional[int] = 0
    subtasks: List[SubTask] = []


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    due_datetime: Optional[datetime] = None
    reminder_datetime: Optional[datetime] = None
    is_recurring: Optional[bool] = None
    recurrence: Optional[str] = None
    recurrence_interval: Optional[int] = None
    is_completed: Optional[bool] = None
    status: Optional[str] = None
    estimated_minutes: Optional[int] = None
    actual_minutes: Optional[int] = None
    subtasks: Optional[List[SubTask]] = None


class TaskRead(TaskBase):
    id: int
    is_completed: bool
    status: str
    order_index: int
    created_at: datetime

    class Config:
        from_attributes = True


# =======================
# USER PROFILE SCHEMAS
# =======================
class ProfileUpdate(BaseModel):
    user_type: str
    goals: List[str]
    image_base64: Optional[str] = None

    # ✅ NEW FIELDS
    focus_style: Optional[str] = None
    main_struggle: Optional[str] = None
    best_time_of_day: Optional[str] = None
    motivation: Optional[str] = None
    theme: Optional[str] = None
    
    theme_mode: Optional[str] = "system"
    accent_color: Optional[str] = None
    layout_density: Optional[str] = "comfortable"


class ProfileResponse(BaseModel):
    email: str
    user_type: str
    goals: List[str]
    image_base64: Optional[str] = None

    focus_style: Optional[str] = None
    main_struggle: Optional[str] = None
    best_time_of_day: Optional[str] = None
    motivation: Optional[str] = None
    theme: Optional[str] = None

    theme_mode: Optional[str] = "system"
    accent_color: Optional[str] = None
    layout_density: Optional[str] = "comfortable"




# =======================
# AUTH SCHEMAS
# =======================
class UserCreate(BaseModel):
    email: str
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class PasswordChange(BaseModel):
    current_password: str
    new_password: str


class UserRead(BaseModel):
    id: int
    email: str
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str


# =======================
# AI PLANNER SCHEMAS
# =======================
class AIPlanItem(BaseModel):
    # Flutter allows null taskId for breaks (optional)
    task_id: Optional[int] = None
    title: str
    start_time: datetime
    end_time: datetime

    # Flutter expects these exact names:
    reason: str
    estimated_minutes: int

    # extra fields (safe to keep; Flutter will ignore)
    priority: Optional[str] = None


class AIPlanResponse(BaseModel):
    items: List[AIPlanItem]
    total_minutes: int
    overloaded: bool
    message: str
    
class FocusSessionCreate(BaseModel):
    task_id: Optional[int]
    planned_minutes: int
    focused_minutes: int
    started_at: datetime
    ended_at: datetime


class FocusSessionRead(FocusSessionCreate):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True