from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from typing import List

from database import get_db
from models import User, UserProfile, FocusGroup, GroupMember, Invitation
import schemas
from auth import get_current_user

router = APIRouter(prefix="/social", tags=["Social"])

# --------------------------
# USER DISCOVERY & PROFILE
# --------------------------

@router.post("/username", response_model=schemas.UserRead)
def set_username(
    username_data: schemas.SetUsernameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if username exists
    existing = db.query(User).filter(User.username == username_data.username).first()
    if existing and existing.id != current_user.id:
        raise HTTPException(status_code=400, detail="Username already taken")
    
    current_user.username = username_data.username
    if username_data.bio:
        current_user.bio = username_data.bio
    
    db.commit()
    db.refresh(current_user)
    return current_user

@router.get("/search", response_model=List[schemas.UserSearch])
def search_users(
    q: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if len(q) < 3:
        return []
        
    users = db.query(User).filter(
        or_(
            User.username.ilike(f"%{q}%"),
            User.email.ilike(f"%{q}%") 
        )
    ).limit(20).all()
    
    results = []
    for u in users:
        # Mini profile image
        img = u.profile.image_base64 if u.profile else None
        results.append(schemas.UserSearch(
            id=u.id, 
            username=u.username or "Unknown", 
            name=u.name,
            profile_image=img
        ))
    return results

@router.get("/profile/{username}", response_model=schemas.PublicProfile)
def get_public_profile(username: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Calc Stats (Basic)
    # For now, just dummy or query aggregates
    # completed_count = db.query(Task).filter(Task.user_id == user.id, Task.is_completed == True).count()
    completed_count = 0 
    
    profile_type = user.profile.user_type if user.profile else "user"
    
    return schemas.PublicProfile(
        id=user.id,
        username=user.username,
        name=user.name,
        bio=user.bio,
        user_type=profile_type,
        is_focusing=user.is_focusing or False,
        completed_tasks_count=completed_count,
        total_focus_minutes=0
    )

# --------------------------
# GROUPS
# --------------------------

@router.post("/groups", response_model=schemas.FocusGroupRead)
def create_group(
    group_data: schemas.FocusGroupCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    new_group = FocusGroup(
        name=group_data.name,
        description=group_data.description,
        owner_id=current_user.id
    )
    db.add(new_group)
    db.commit()
    db.refresh(new_group)
    
    # Add creator as admin member
    member = GroupMember(
        group_id=new_group.id, 
        user_id=current_user.id, 
        role="admin"
    )
    db.add(member)
    db.commit()
    
    return schemas.FocusGroupRead(
        id=new_group.id,
        name=new_group.name,
        description=new_group.description,
        owner_id=new_group.owner_id,
        created_at=new_group.created_at,
        member_count=1
    )

@router.get("/groups", response_model=List[schemas.FocusGroupRead])
def get_my_groups(
    current_user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    # Join GroupMember
    memberships = db.query(GroupMember).filter(GroupMember.user_id == current_user.id).all()
    results = []
    for m in memberships:
        g = m.group
        count = db.query(GroupMember).filter(GroupMember.group_id == g.id).count()
        results.append(schemas.FocusGroupRead(
            id=g.id,
            name=g.name,
            description=g.description,
            owner_id=g.owner_id,
            created_at=g.created_at,
            member_count=count
        ))
    return results

@router.post("/groups/{group_id}/invite", response_model=schemas.InvitationRead)
def invite_user(
    group_id: int,
    username: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check permissions (must be member or admin?)
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id, 
        GroupMember.user_id == current_user.id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member of this group")
        
    target_user = db.query(User).filter(User.username == username).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Check if already member
    exists = db.query(GroupMember).filter(GroupMember.group_id==group_id, GroupMember.user_id==target_user.id).first()
    if exists:
        raise HTTPException(status_code=400, detail="User already in group")

    # Invite
    invite = Invitation(
        sender_id=current_user.id,
        receiver_id=target_user.id,
        group_id=group_id
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    
    return schemas.InvitationRead(
        id=invite.id,
        group_id=invite.group_id,
        sender_id=invite.sender_id,
        group_name=invite.group.name,
        sender_name=current_user.username or "User",
        status=invite.status,
        created_at=invite.created_at
    )

@router.get("/invites", response_model=List[schemas.InvitationRead])
def get_my_invitations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    invites = db.query(Invitation).filter(
        Invitation.receiver_id == current_user.id,
        Invitation.status == "pending"
    ).all()
    
    results = []
    for inv in invites:
        results.append(schemas.InvitationRead(
            id=inv.id,
            group_id=inv.group_id,
            sender_id=inv.sender_id,
            group_name=inv.group.name,
            sender_name=inv.sender.username or "User",
            status=inv.status,
            created_at=inv.created_at
        ))
    return results

@router.post("/invites/{invite_id}/{action}")
def respond_to_invite(
    invite_id: int,
    action: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if action not in ["accept", "decline"]:
        raise HTTPException(status_code=400, detail="Invalid action")
        
    invite = db.query(Invitation).filter(
        Invitation.id == invite_id,
        Invitation.receiver_id == current_user.id
    ).first()
    
    if not invite:
        raise HTTPException(status_code=404, detail="Invitation not found")
        
    if invite.status != "pending":
        raise HTTPException(status_code=400, detail="Invitation already processed")
        
    if action == "accept":
        invite.status = "accepted"
        # Add to group
        member = GroupMember(
            group_id=invite.group_id,
            user_id=current_user.id,
            role="member"
        )
        db.add(member)
    else:
        invite.status = "declined"
        
    db.commit()
    return {"message": f"Invitation {action}ed"}

@router.get("/groups/{group_id}")
def get_group_details(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # check membership
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member of this group")
        
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
         raise HTTPException(status_code=404, detail="Group not found")
         
    # Get members
    members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
    
    members_data = []
    for m in members:
        u = m.user
        members_data.append({
            "user_id": u.id,
            "role": m.role,
            "joined_at": m.joined_at,
            "user": {
                "id": u.id,
                "username": u.username,
                "email": u.email,
                "is_focusing": u.is_focusing, # Critical for Live Status
                # "profile_image": u.profile.image_base64 if u.profile else None 
            }
        })
        
    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "owner_id": group.owner_id,
        "created_at": group.created_at,
        "members": members_data
    }


@router.get("/groups/{group_id}/analytics", response_model=schemas.GroupAnalytics)
def get_group_analytics(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check membership
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member")

    # 1. Total Minutes for group
    # Sum of duration_minutes where group_id = id
    # Note: FocusSession needs 'group_id' populated.
    # If not populated for older sessions, they won't count.
    from models import FocusSession
    # 1. Total Minutes for group
    from models import FocusSession
    total_mins = db.query(func.sum(FocusSession.focused_minutes)).filter(
        FocusSession.group_id == group_id
    ).scalar() or 0

    # 2. Active Members
    active_count = db.query(GroupMember).filter(GroupMember.group_id == group_id).count()

    # 3. Leaderboard
    lb_data = db.query(
        FocusSession.user_id,
        func.sum(FocusSession.focused_minutes).label("total")
    ).filter(
        FocusSession.group_id == group_id
    ).group_by(FocusSession.user_id).order_by(func.sum(FocusSession.focused_minutes).desc()).all()

    leaderboard = []
    for rank, (uid, mins) in enumerate(lb_data, 1):
        # Fetch user details
        u = db.query(User).filter(User.id == uid).first()
        if u:
            leaderboard.append(schemas.LeaderboardEntry(
                user_id=uid,
                username=u.username or "Unknown",
                minutes=mins,
                rank=rank,
                is_focusing=u.is_focusing
            ))

    # 4. Weekly Activity (Last 7 Days)
    from datetime import datetime, timedelta
    today = datetime.utcnow().date()
    seven_days_ago = today - timedelta(days=6)
    
    # Initialize dictionary for last 7 days with 0
    weekly_map = {(seven_days_ago + timedelta(days=i)).strftime("%Y-%m-%d"): 0 for i in range(7)}

    weekly_data = db.query(
        func.date(FocusSession.started_at),
        func.sum(FocusSession.focused_minutes)
    ).filter(
        FocusSession.group_id == group_id,
        FocusSession.started_at >= seven_days_ago
    ).group_by(func.date(FocusSession.started_at)).all()

    for date_obj, mins in weekly_data:
        d_str = str(date_obj) # might be date object or string depending on driver
        if d_str in weekly_map:
            weekly_map[d_str] = mins
    
    weekly_activity = [
        schemas.DailyFocusStat(date=d, minutes=m) 
        for d, m in sorted(weekly_map.items())
    ]

    # 5. Recent Sessions (Last 10)
    recent_data = db.query(FocusSession).filter(
        FocusSession.group_id == group_id
    ).order_by(FocusSession.ended_at.desc()).limit(10).all()

    recent_sessions = []
    for s in recent_data:
        u = db.query(User).filter(User.id == s.user_id).first()
        recent_sessions.append(schemas.RecentSession(
            user_id=s.user_id,
            username=u.username if u else "Unknown",
            minutes=s.focused_minutes,
            ended_at=s.ended_at
        ))

    return schemas.GroupAnalytics(
        group_id=group_id,
        total_minutes=total_mins,
        active_members=active_count,
        leaderboard=leaderboard,
        weekly_activity=weekly_activity,
        recent_sessions=recent_sessions
    )

@router.delete("/groups/{group_id}/members/{user_id}")
def remove_group_member(
    group_id: int,
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if group exists
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
         raise HTTPException(status_code=404, detail="Group not found")

    # Check requester's membership
    requester_membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()

    if not requester_membership:
        raise HTTPException(status_code=403, detail="You are not a member of this group")

    # Determine if authorized
    # 1. User leaving themselves
    if current_user.id == user_id:
        # Check if owner is leaving (might need to transfer ownership or delete group)
        if group.owner_id == current_user.id:
            # If owner leaves, for now let's just allow it, maybe delete/archive group logic later
            # Or prevent if last member?
            pass
    # 2. Admin kicking someone
    elif requester_membership.role == 'admin':
        # Admin kicking user
        pass
    else:
        raise HTTPException(status_code=403, detail="Not authorized to remove this member")

    # Find the member to remove
    member_to_remove = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == user_id
    ).first()

    if not member_to_remove:
        raise HTTPException(status_code=404, detail="Member not found")

    db.delete(member_to_remove)
    db.commit()
    return {"message": "Member removed successfully"}


@router.put("/groups/{group_id}", response_model=schemas.FocusGroupRead)
def update_group(
    group_id: int,
    group_update: schemas.FocusGroupUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    # Check if admin
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()

    if not membership or membership.role != 'admin':
        raise HTTPException(status_code=403, detail="Only admins can update group details")

    if group_update.name is not None:
        group.name = group_update.name
    if group_update.description is not None:
        group.description = group_update.description
    
    db.commit()
    db.refresh(group)
    return group

@router.delete("/groups/{group_id}")
def delete_group(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
         raise HTTPException(status_code=404, detail="Group not found")

    # Check if admin/owner
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()

    if not membership or membership.role != 'admin':
         raise HTTPException(status_code=403, detail="Only admins can delete the group")

    # Delete members first (cascade usually handles but let's be safe if no cascade)
    db.query(GroupMember).filter(GroupMember.group_id == group_id).delete()
    
    # Delete group
    db.delete(group)
    db.commit()
    return {"message": "Group deleted successfully"}
