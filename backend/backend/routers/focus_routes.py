from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel

from database import get_db
from models import User, FocusSession
from auth import get_current_user
import schemas

router = APIRouter(prefix="/focus", tags=["Focus"])

class StartFocusRequest(BaseModel):
    duration_minutes: int
    group_id: Optional[int] = None
    task_id: Optional[int] = None

class EndFocusRequest(BaseModel):
    session_id: int
    completed: bool = True

@router.post("/start", response_model=schemas.FocusSessionRead)
def start_focus_session(
    payload: StartFocusRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Update User Status
    current_user.is_focusing = True
    
    # 2. Create Session Record
    # Note: ended_at is not nullable in model, so we set it to start_time initially
    now = datetime.utcnow()
    new_session = FocusSession(
        user_id=current_user.id,
        started_at=now,
        ended_at=now, # Temporary
        planned_minutes=payload.duration_minutes,
        focused_minutes=0,
        group_id=payload.group_id 
    )
    
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    db.refresh(current_user)
    
    return schemas.FocusSessionRead(
        id=new_session.id,
        user_id=new_session.user_id,
        started_at=new_session.started_at,
        ended_at=new_session.ended_at,
        planned_minutes=new_session.planned_minutes,
        focused_minutes=new_session.focused_minutes,
        task_id=new_session.task_id
    )

@router.post("/end", response_model=schemas.FocusSessionRead)
def end_focus_session(
    payload: EndFocusRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Update User Status
    current_user.is_focusing = False
    
    # 2. Update Session
    session = db.query(FocusSession).filter(FocusSession.id == payload.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
        
    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your session")
        
    now = datetime.utcnow()
    session.ended_at = now
    
    # Calculate actual minutes focused
    duration = (session.ended_at - session.started_at).total_seconds() / 60
    session.focused_minutes = int(max(1, duration)) # Minimum 1 minute if completed
    
    db.commit()
    db.refresh(session)
    db.refresh(current_user)
    
    return schemas.FocusSessionRead(
        id=session.id,
        user_id=session.user_id,
        started_at=session.started_at,
        ended_at=session.ended_at,
        planned_minutes=session.planned_minutes,
        focused_minutes=session.focused_minutes,
        task_id=session.task_id
    )
