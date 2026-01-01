# models.py
from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Boolean,
    Enum,
    ForeignKey,
    Text,
    JSON,
    func,
)
from sqlalchemy.orm import relationship
import enum

from database import Base


# ===========================
#          USER MODEL
# ===========================
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    # NEW: full name (optional)
    name = Column(String, nullable=True)

    email = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    tasks = relationship("Task", back_populates="owner")
    profile = relationship("UserProfile", back_populates="user", uselist=False)


# ===========================
#       USER PROFILE MODEL
# ===========================
class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    user_type = Column(String, default="")
    goals = Column(Text, default="[]")  # stored as JSON string
    image_base64 = Column(Text, nullable=True)

    user = relationship("User", back_populates="profile")
    focus_style = Column(String, nullable=True)
    main_struggle = Column(String, nullable=True)
    best_time_of_day = Column(String, nullable=True)
    motivation = Column(String, nullable=True)
    theme = Column(String, nullable=True)  # Deprecated in favor of theme_mode? Or re-use?

    # ✅ NEW FIELDS
    theme_mode = Column(String, default="system")  # light, dark, system
    accent_color = Column(String, nullable=True)   # hex code
    layout_density = Column(String, default="comfortable") # compact, comfortable

# ===========================
#         TASK MODEL
# ===========================
class TaskPriority(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)

    priority = Column(Enum(TaskPriority), nullable=False, default=TaskPriority.medium)

    due_datetime = Column(DateTime(timezone=True), nullable=True)
    reminder_datetime = Column(DateTime(timezone=True), nullable=True)
    is_recurring = Column(Boolean, default=False)
    recurrence = Column(String, nullable=True)
    recurrence_interval = Column(Integer, nullable=True)

    is_completed = Column(Boolean, default=False)

    # estimated duration for scheduling (in minutes)
    estimated_minutes = Column(Integer, nullable=True, default=30)
    actual_minutes = Column(Integer, nullable=True, default=0)

    # Kanban status
    status = Column(String, default="todo", nullable=False)

    order_index = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    subtasks = Column(JSON, default=list)

    owner = relationship("User", back_populates="tasks")
from datetime import datetime

class FocusSession(Base):
    __tablename__ = "focus_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=True)

    planned_minutes = Column(Integer, nullable=False)
    focused_minutes = Column(Integer, nullable=False)

    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=False)

    user = relationship("User")

