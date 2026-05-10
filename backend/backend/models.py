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
    # name = Column(String, nullable=True)
    username = Column(String, unique=True, index=True, nullable=True)
    bio = Column(String, nullable=True) # NEW: Public bio
    is_focusing = Column(Boolean, default=False) # NEW: Track live focus status

    email = Column(String, unique=True, index=True, nullable=False)
    fcm_token = Column(String, nullable=True)
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

    # ✅ GAMIFICATION FIELDS
    coins = Column(Integer, default=0)
    xp = Column(Integer, default=0)
    focus_score = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    longest_streak = Column(Integer, default=0)
    last_focus_date = Column(DateTime(timezone=True), nullable=True)
    achievements = Column(JSON, default=list)
    forest_settings = Column(JSON, default=lambda: {"enabled": True, "sound": True, "strict": False})

    notifications_push = Column(Boolean, default=False)
    notifications_email = Column(Boolean, default=False)
    notifications_summary = Column(Boolean, default=False)

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
    group_id = Column(Integer, ForeignKey("focus_groups.id"), nullable=True) # NEW for Analytics

    # Gamification: Focus Plant
    plant_type = Column(String, nullable=True, default="oak") # e.g. oak, pine, bonsai
    is_successful = Column(Boolean, default=False)


    user = relationship("User")
    group = relationship("FocusGroup")


# ===========================
#      STUDY TOGETHER
# ===========================

class FocusGroup(Base):
    __tablename__ = "focus_groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    description = Column(String, nullable=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    owner = relationship("User", backref="owned_groups")
    members = relationship("GroupMember", back_populates="group", cascade="all, delete-orphan")


class GroupMember(Base):
    __tablename__ = "group_members"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("focus_groups.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    role = Column(String, default="member") # admin, member
    joined_at = Column(DateTime(timezone=True), server_default=func.now())

    group = relationship("FocusGroup", back_populates="members")
    user = relationship("User")


class Invitation(Base):
    __tablename__ = "invitations"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    group_id = Column(Integer, ForeignKey("focus_groups.id"), nullable=False)
    status = Column(String, default="pending") # pending, accepted, declined
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])
    group = relationship("FocusGroup")


# ===========================
#    IN-APP NOTIFICATIONS
# ===========================
class AppNotification(Base):
    __tablename__ = "app_notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    type = Column(String, nullable=False, default="system")  # invitation, system, task
    title = Column(String, nullable=False)
    body = Column(String, nullable=False)
    is_read = Column(Boolean, default=False)
    related_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")


