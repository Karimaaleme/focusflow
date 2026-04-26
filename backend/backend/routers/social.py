from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from typing import List
from datetime import datetime, timedelta, timezone

from database import get_db
from models import User, UserProfile, FocusGroup, GroupMember, Invitation, Task, FocusSession
import schemas
from auth import get_current_user

router = APIRouter(prefix="/social", tags=["Social"])
def to_naive_utc(dt):
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt

# --------------------------
# USER DISCOVERY & PROFILE
# --------------------------

@router.post("/username", response_model=schemas.UserRead)
def set_username(
    username_data: schemas.SetUsernameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
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
    current_user: User = Depends(get_current_user),  # noqa: ARG001
):
    if len(q) < 2:
        return []

    users = db.query(User).filter(
        or_(
            User.username.ilike(f"%{q}%"),
            User.email.ilike(f"%{q}%"),
        )
    ).limit(20).all()

    return [
        schemas.UserSearch(
            id=u.id,
            username=u.username or f"User_{u.id}",
            name=None,
            profile_image=u.profile.image_base64 if u.profile else None,
        )
        for u in users
    ]


@router.get("/profile/{username}", response_model=schemas.PublicProfile)
def get_public_profile(username: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    profile_type = user.profile.user_type if user.profile else "user"

    return schemas.PublicProfile(
        id=user.id,
        username=user.username or f"User_{user.id}",
        name=None,
        bio=user.bio,
        user_type=profile_type,
        is_focusing=user.is_focusing or False,
        completed_tasks_count=0,
        total_focus_minutes=0,
    )


@router.get("/members/{user_id}/stats", response_model=schemas.MemberStats)
def get_member_stats(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),  # noqa: ARG001
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    total_focus = (
        db.query(func.sum(FocusSession.focused_minutes))
        .filter(FocusSession.user_id == user_id)
        .scalar() or 0
    )
    session_count = (
        db.query(func.count(FocusSession.id))
        .filter(FocusSession.user_id == user_id)
        .scalar() or 0
    )
    completed_tasks = (
        db.query(func.count(Task.id))
        .filter(Task.user_id == user_id, Task.is_completed == True)
        .scalar() or 0
    )
    avg_session = round(total_focus / session_count, 1) if session_count > 0 else 0.0
    profile_type = user.profile.user_type if user.profile else None

    return schemas.MemberStats(
        user_id=user.id,
        username=user.username or f"User_{user.id}",
        bio=user.bio,
        user_type=profile_type,
        is_focusing=user.is_focusing or False,
        total_focus_minutes=total_focus,
        completed_tasks=completed_tasks,
        focus_sessions_count=session_count,
        avg_session_minutes=avg_session,
    )


# --------------------------
# GROUPS
# --------------------------

@router.post("/groups", response_model=schemas.FocusGroupRead)
def create_group(
    group_data: schemas.FocusGroupCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    new_group = FocusGroup(
        name=group_data.name,
        description=group_data.description,
        owner_id=current_user.id,
    )
    db.add(new_group)
    db.commit()
    db.refresh(new_group)

    member = GroupMember(group_id=new_group.id, user_id=current_user.id, role="admin")
    db.add(member)
    db.commit()
    db.refresh(new_group)   # refresh so members relationship is populated
    return new_group


@router.get("/groups", response_model=List[schemas.FocusGroupRead])
def get_my_groups(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memberships = db.query(GroupMember).filter(GroupMember.user_id == current_user.id).all()
    return [m.group for m in memberships]


@router.post("/groups/{group_id}/invite", response_model=schemas.InvitationRead)
def invite_user(
    group_id: int,
    username: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member of this group")

    target = db.query(User).filter(User.username == username).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    already = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == target.id,
    ).first()
    if already:
        raise HTTPException(status_code=400, detail="User already in group")

    pending = db.query(Invitation).filter(
        Invitation.group_id == group_id,
        Invitation.receiver_id == target.id,
        Invitation.status == "pending",
    ).first()
    if pending:
        raise HTTPException(status_code=400, detail="Invitation already pending")

    invite = Invitation(
        sender_id=current_user.id,
        receiver_id=target.id,
        group_id=group_id,
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)

    return schemas.InvitationRead(
        id=invite.id,
        group_id=invite.group_id,
        group_name=invite.group.name,
        sender_id=invite.sender_id,
        sender_name=current_user.username or f"User_{current_user.id}",
        status=invite.status,
        created_at=invite.created_at,
    )


@router.get("/invites", response_model=List[schemas.InvitationRead])
def get_my_invitations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    invites = db.query(Invitation).filter(
        Invitation.receiver_id == current_user.id,
        Invitation.status == "pending",
    ).all()

    return [
        schemas.InvitationRead(
            id=inv.id,
            group_id=inv.group_id,
            group_name=inv.group.name,
            sender_id=inv.sender_id,
            sender_name=inv.sender.username or f"User_{inv.sender.id}",
            status=inv.status,
            created_at=inv.created_at,
        )
        for inv in invites
    ]


@router.post("/invites/{invite_id}/{action}")
def respond_to_invite(
    invite_id: int,
    action: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if action not in ["accept", "decline"]:
        raise HTTPException(status_code=400, detail="Invalid action. Use 'accept' or 'decline'")

    invite = db.query(Invitation).filter(
        Invitation.id == invite_id,
        Invitation.receiver_id == current_user.id,
    ).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invite.status != "pending":
        raise HTTPException(status_code=400, detail="Invitation already processed")

    if action == "accept":
        invite.status = "accepted"
        member = GroupMember(
            group_id=invite.group_id,
            user_id=current_user.id,
            role="member",
        )
        db.add(member)
    else:
        invite.status = "declined"

    db.commit()
    return {"message": f"Invitation {action}d"}


@router.get("/groups/{group_id}")
def get_group_details(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member of this group")

    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    members_data = [
        {
            "user_id": m.user.id,
            "role": m.role,
            "joined_at": m.joined_at,
            "user": {
                "id": m.user.id,
                "username": m.user.username or f"User_{m.user.id}",
                "is_focusing": m.user.is_focusing,
            },
        }
        for m in db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
    ]

    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "owner_id": group.owner_id,
        "created_at": group.created_at,
        "members": members_data,
    }


@router.post("/groups/{group_id}/alert")
def send_group_alert(
    group_id: int,
    alert: schemas.GroupAlertCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member of this group")

    sender_name = current_user.username or f"User_{current_user.id}"
    return {
        "group_id": group_id,
        "sender": sender_name,
        "message": alert.message,
        "sent_at": datetime.utcnow().isoformat(),
    }


@router.get("/groups/{group_id}/analytics", response_model=schemas.GroupAnalytics)
def get_group_analytics(
    group_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=403, detail="Not a member")

    total_mins = (
        db.query(func.sum(FocusSession.focused_minutes))
        .filter(FocusSession.group_id == group_id)
        .scalar() or 0
    )

    active_count = db.query(GroupMember).filter(
        GroupMember.group_id == group_id
    ).count()

    # Leaderboard
    lb_data = (
        db.query(
            FocusSession.user_id,
            func.sum(FocusSession.focused_minutes).label("total")
        )
        .filter(FocusSession.group_id == group_id)
        .group_by(FocusSession.user_id)
        .order_by(func.sum(FocusSession.focused_minutes).desc())
        .all()
    )

    leaderboard = []
    for rank, (uid, mins) in enumerate(lb_data, 1):
        u = db.query(User).filter(User.id == uid).first()
        if u:
            leaderboard.append(
                schemas.LeaderboardEntry(
                    user_id=uid,
                    username=u.username or f"User_{u.id}",
                    minutes=mins,
                    rank=rank,
                    is_focusing=u.is_focusing,
                )
            )

    # Weekly activity (FIXED SAFE VERSION)
    today = datetime.utcnow().date()
    seven_days_ago = today - timedelta(days=6)

    weekly_map = {
        (seven_days_ago + timedelta(days=i)).strftime("%Y-%m-%d"): 0
        for i in range(7)
    }

    group_sessions = (
        db.query(FocusSession)
        .filter(FocusSession.group_id == group_id)
        .all()
    )

    for session in group_sessions:
        started = to_naive_utc(session.started_at)
        if not started:
            continue

        session_date = started.date()
        if session_date >= seven_days_ago:
            d_str = session_date.strftime("%Y-%m-%d")
            if d_str in weekly_map:
                weekly_map[d_str] += session.focused_minutes or 0

    weekly_activity = [
        schemas.DailyFocusStat(date=d, minutes=m)
        for d, m in sorted(weekly_map.items())
    ]

    # Recent sessions
    recent_data = (
        db.query(FocusSession)
        .filter(FocusSession.group_id == group_id)
        .order_by(FocusSession.ended_at.desc())
        .limit(10)
        .all()
    )

    recent_sessions = []
    for s in recent_data:
        u = db.query(User).filter(User.id == s.user_id).first()
        recent_sessions.append(
            schemas.RecentSession(
                user_id=s.user_id,
                username=(u.username or f"User_{u.id}") if u else "Unknown",
                minutes=s.focused_minutes,
                ended_at=s.ended_at,
            )
        )

    return schemas.GroupAnalytics(
        group_id=group_id,
        total_minutes=total_mins,
        active_members=active_count,
        leaderboard=leaderboard,
        weekly_activity=weekly_activity,
        recent_sessions=recent_sessions,
    )


@router.delete("/groups/{group_id}/members/{user_id}")
def remove_group_member(
    group_id: int,
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    requester = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not requester:
        raise HTTPException(status_code=403, detail="You are not a member of this group")

    if current_user.id != user_id and requester.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to remove this member")

    target = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == user_id,
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail="Member not found")

    db.delete(target)
    db.commit()
    return {"message": "Member removed successfully"}


@router.put("/groups/{group_id}", response_model=schemas.FocusGroupRead)
def update_group(
    group_id: int,
    group_update: schemas.FocusGroupUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership or membership.role != "admin":
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
    db: Session = Depends(get_db),
):
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    membership = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id,
    ).first()
    if not membership or membership.role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can delete the group")

    db.query(GroupMember).filter(GroupMember.group_id == group_id).delete()
    db.delete(group)
    db.commit()
    return {"message": "Group deleted successfully"}
