# schemas.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


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
    username: Optional[str] = None
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
    username: Optional[str] = None
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
    username: Optional[str] = None
    is_focusing: bool = False # NEW
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str


# =======================
# AI PLANNER SCHEMAS
# =======================

class AIPlanRequest(BaseModel):
    day_start: str = "09:00"
    planned_minutes: int = 30
    focus_categories: Optional[List[str]] = None # Match this name
    enable_google: Optional[bool] = True
    enable_outlook: Optional[bool] = False

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



class CalendarEvent(BaseModel):
    title: str
    start: datetime
    end: datetime
    source: str = "google" # google, outlook

class WorkloadAnalysis(BaseModel):
    status: str # "heavy", "balanced", "light"
    summary: str
    recommendation: str

class AIPlanResponse(BaseModel):
    items: List[AIPlanItem]
    total_minutes: int
    overloaded: bool
    workload: Optional[WorkloadAnalysis] = None
    external_events: List[CalendarEvent] = []
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


# =======================
#      STUDY TOGETHER
# =======================

class SetUsernameRequest(BaseModel):
    username: str
    bio: Optional[str] = None

class UserSearch(BaseModel):
    id: int
    username: str
    name: Optional[str] = None
    profile_image: Optional[str] = None 
    is_rest: bool = False

    class Config:
        from_attributes = True

class PublicProfile(BaseModel):
    id: int
    username: str
    name: Optional[str] = None
    bio: Optional[str] = None
    user_type: Optional[str] = None
    is_focusing: bool = False
    completed_tasks_count: int = 0
    total_focus_minutes: int = 0
    
    class Config:
        from_attributes = True

class UserSimple(BaseModel):
    id: int
    username: Optional[str] = None
    is_focusing: bool = False # NEW
    email: str

    class Config:
        from_attributes = True

class FocusGroupCreate(BaseModel):
    name: str
    description: Optional[str] = None

class FocusGroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None

class GroupMemberRead(BaseModel):
    id: int
    user_id: int
    role: str
    joined_at: datetime
    user: Optional[UserSimple] = None

    class Config:
        from_attributes = True

class FocusGroupRead(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    owner_id: int
    created_at: datetime
    members: List[GroupMemberRead] = []

    class Config:
        from_attributes = True

class InvitationCreate(BaseModel):
    receiver_username: str

class InvitationRead(BaseModel):
    id: int
    group_id: int
    group_name: str
    sender_id: int
    sender_name: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class LeaderboardEntry(BaseModel):
    user_id: int
    username: str
    minutes: int
    rank: int
    is_focusing: bool = False

class DailyFocusStat(BaseModel):
    date: str # YYYY-MM-DD
    minutes: int

class RecentSession(BaseModel):
    user_id: int
    username: str
    minutes: int
    ended_at: datetime
    avatar_color_seed: Optional[str] = None # For frontend avatar generation if needed

class GroupAnalytics(BaseModel):
    group_id: int
    total_minutes: int
    active_members: int
    leaderboard: List[LeaderboardEntry] = []
    weekly_activity: List[DailyFocusStat] = []
    recent_sessions: List[RecentSession] = []


# =======================
# MEMBER STATS
# =======================

class MemberStats(BaseModel):
    user_id: int
    username: str
    bio: Optional[str] = None
    user_type: Optional[str] = None
    is_focusing: bool = False
    total_focus_minutes: int = 0
    completed_tasks: int = 0
    focus_sessions_count: int = 0
    avg_session_minutes: float = 0.0


# =======================
# GROUP ALERT
# =======================

class GroupAlertCreate(BaseModel):
    message: str