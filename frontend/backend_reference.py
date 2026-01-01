# backend_reference.py
# ------------------------------------------------------------------------------
# REFERENCE BACKEND IMPLEMENTATION (FastAPI)
# Use this logic to ensure your backend handles updates correctly.
# ------------------------------------------------------------------------------

from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

app = FastAPI()

# MOCK DATABASE
tasks_db = {}

# ------------------------------------------------------------------------------
# MODELS
# ------------------------------------------------------------------------------

class SubTask(BaseModel):
    title: str
    is_completed: bool = False

class TaskCreate(BaseModel):
    title: str
    description: str = ""
    category: str = "general"
    priority: str = "medium"
    status: str = "todo"
    estimated_minutes: int = 30
    actual_minutes: int = 0
    due_datetime: Optional[datetime] = None
    reminder_datetime: Optional[datetime] = None
    is_recurring: bool = False
    recurrence: Optional[str] = None
    recurrence_interval: Optional[int] = None
    subtasks: List[SubTask] = []

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    estimated_minutes: Optional[int] = None
    actual_minutes: Optional[int] = None
    due_datetime: Optional[datetime] = None
    reminder_datetime: Optional[datetime] = None
    is_recurring: Optional[bool] = None
    recurrence: Optional[str] = None
    recurrence_interval: Optional[int] = None
    subtasks: Optional[List[SubTask]] = None

class Task(TaskCreate):
    id: int
    created_at: datetime
    is_completed: bool  # Computed field

# ------------------------------------------------------------------------------
# ENDPOINTS
# ------------------------------------------------------------------------------


# RECURRENCE LOGIC
def _handle_recurrence(task: Task):
    """
    Checks if a task is completed and recurring. If so, creates the next instance.
    """
    if not task.is_completed or not task.is_recurring:
        return

    # 1. Parse current due date
    if not task.due_datetime:
        return # Cannot recur without a base date

    # 2. Calculate next date
    from datetime import timedelta
    next_due = task.due_datetime
    interval = task.recurrence_interval or 1
    
    if task.recurrence == 'daily':
        next_due += timedelta(days=interval)
    elif task.recurrence == 'weekly':
        next_due += timedelta(weeks=interval)
    elif task.recurrence == 'monthly':
        # Simple approx for monthly
        next_due += timedelta(days=30 * interval)
    else:
        # Default fallback
        next_due += timedelta(days=1)

    # 3. Create new task
    new_id = len(tasks_db) + 1
    new_task = task.copy()
    new_task.id = new_id
    new_task.created_at = datetime.now()
    new_task.due_datetime = next_due
    new_task.status = 'todo'
    new_task.is_completed = False
    new_task.actual_minutes = 0 # Reset actuals
    # Note: Subtasks might be reset too depending on preference, identifying this as a clone
    new_task.subtasks = [s.copy(update={'is_completed': False}) for s in task.subtasks] 

    tasks_db[new_id] = new_task
    print(f"RECURRENCE: Created new task {new_id} due {next_due}")

@app.put("/tasks/{task_id}", response_model=Task)
def update_task_full(task_id: int, update: TaskUpdate):
    """
    Update a task.
    CRITICAL: 
    1. If 'status' becomes 'done', automatically set is_completed = True.
    2. If 'status' becomes 'todo'/'in_progress', set is_completed = False.
    3. Ensure persistence of all fields.
    """
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")

    existing_task = tasks_db[task_id]
    
    # Update fields only if provided (Partial Update logic supported by Pydantic)
    update_data = update.dict(exclude_unset=True)
    
    # Apply updates
    updated_values = existing_task.copy(update=update_data)
    
    # SYNC LOGIC: Status -> IsCompleted
    if updated_values.status == "done":
        updated_values.is_completed = True
    else:
        updated_values.is_completed = False

    # Save to DB
    tasks_db[task_id] = updated_values
    
    # Check Recurrence
    _handle_recurrence(updated_values)

    return updated_values

@app.patch("/tasks/{task_id}/status/{status}", response_model=Task)
def update_task_status(task_id: int, status: str):
    """
    Dedicated endpoint for Kanban drag-and-drop.
    """
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
        
    task = tasks_db[task_id]
    task.status = status
    
    # Sync is_completed
    task.is_completed = (status == "done")
    
    tasks_db[task_id] = task
    
    # Check Recurrence
    _handle_recurrence(task)
    
    return task

@app.post("/tasks", response_model=Task)
def create_task(task: TaskCreate):
    """
    Create a new task.
    """
    new_id = len(tasks_db) + 1
    
    # Calculate created_at
    now = datetime.now()
    
    # Convert TaskCreate to Task
    # Note: Pydantic's copy or dict methods help here
    
    new_task = Task(
        id=new_id,
        created_at=now,
        is_completed=task.status == 'done',
        **task.dict()
    )
    
    tasks_db[new_id] = new_task
    return new_task

@app.get("/tasks", response_model=List[Task])
def get_tasks():
    return list(tasks_db.values())

# ------------------------------------------------------------------------------
# FOCUS ENDPOINTS (Added for Analytics Sync)
# ------------------------------------------------------------------------------

class FocusSession(BaseModel):
    task_id: Optional[int]
    planned_minutes: Optional[int]
    focused_minutes: int
    started_at: datetime
    ended_at: datetime

@app.post("/focus/session")
def log_focus_session(session: FocusSession):
    """
    Log a focus session and update the related task's actual_minutes.
    """
    # 1. Update task if exists
    if session.task_id and session.task_id in tasks_db:
        task = tasks_db[session.task_id]
        task.actual_minutes += session.focused_minutes
        tasks_db[session.task_id] = task
        print(f"Updated task {session.task_id}: +{session.focused_minutes} min")

    # 2. (Optional) Save session to a sessions_db if you have one
    # sessions_db.append(session)
    
    return {"status": "logged", "focused_minutes": session.focused_minutes}

@app.get("/focus/sessions")
def get_focus_sessions():
    # Return mock sessions or empty if not implemented
    return []
