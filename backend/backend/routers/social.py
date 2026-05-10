from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, func
from typing import List
from datetime import datetime, timedelta, timezone

from database import get_db, SessionLocal
from models import User, UserProfile, FocusGroup, GroupMember, Invitation, Task, FocusSession, AppNotification
import schemas
from auth import get_current_user
from ws_manager import ws_manager

router = APIRouter(prefix="/social", tags=["Social"])


def _email_prefix(email: str) -> str:
    """Return the part of the email before '@' as a display-safe fallback."""
    if email and '@' in email:
        return email.split('@')[0]
    return email or 'user'


def _display_name(user: User) -> str:
    """Best available display name for a user — never exposes full email."""
    return user.username or _email_prefix(user.email or '')


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
            username=_display_name(u),
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

    total_focus = (
        db.query(func.sum(FocusSession.focused_minutes))
        .filter(FocusSession.user_id == user.id)
        .scalar() or 0
    )
    completed_tasks = (
        db.query(func.count(Task.id))
        .filter(Task.user_id == user.id, Task.is_completed == True)
        .scalar() or 0
    )

    return schemas.PublicProfile(
        id=user.id,
        username=_display_name(user),
        name=None,
        bio=user.bio,
        user_type=profile_type,
        is_focusing=user.is_focusing or False,
        completed_tasks_count=completed_tasks,
        total_focus_minutes=total_focus,
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
        username=_display_name(user),
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

@router.post("/notify-dm")
async def notify_dm(
    payload: schemas.DmNotifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Push an in-app notification to the recipient of a private message."""
    print(f"[notify-dm] from user_id={current_user.id} to email={payload.recipient_email}")
    recipient = db.query(User).filter(
        func.lower(User.email) == payload.recipient_email.lower()
    ).first()
    if not recipient:
        print(f"[notify-dm] recipient not found for email: {payload.recipient_email}")
        return {"ok": False, "reason": "recipient not found"}

    print(f"[notify-dm] recipient found: user_id={recipient.id}")
    receiver_profile = db.query(UserProfile).filter(UserProfile.user_id == recipient.id).first()
    push_enabled = not receiver_profile or receiver_profile.notifications_push
    if not push_enabled:
        print(f"[notify-dm] notifications disabled for user_id={recipient.id}")
        return {"ok": False, "reason": "notifications disabled"}

    sender_name = payload.sender_name or current_user.username or current_user.email
    # Encode sender email as a hidden prefix so the client can navigate to the DM screen
    notif_body = f"__from:{current_user.email}__|{sender_name}: {payload.preview}"

    db_notif = AppNotification(
        user_id=recipient.id,
        type="message",
        title=sender_name,
        body=notif_body,
    )
    db.add(db_notif)
    db.commit()
    db.refresh(db_notif)

    delivered = await ws_manager.send(recipient.id, {
        "id": db_notif.id,
        "type": db_notif.type,
        "title": db_notif.title,
        "body": db_notif.body,
        "is_read": False,
        "related_id": None,
        "created_at": db_notif.created_at.isoformat(),
    })
    print(f"[notify-dm] notification saved (id={db_notif.id}), ws_delivered={delivered}")
    return {"ok": True, "ws_delivered": delivered}


@router.post("/groups/{group_id}/notify-message")
async def notify_group_message(
    group_id: int,
    payload: schemas.GroupMessageNotifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Push an in-app notification to all group members except the sender."""
    members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    group_name = group.name if group else "Group"
    sender_name = payload.sender_name or current_user.username or current_user.email

    sent = 0
    for m in members:
        if m.user_id == current_user.id:
            continue  # don't notify the sender

        profile = db.query(UserProfile).filter(UserProfile.user_id == m.user_id).first()
        push_enabled = not profile or profile.notifications_push
        if not push_enabled:
            continue

        notif_body = f"{sender_name}: {payload.preview}"
        db_notif = AppNotification(
            user_id=m.user_id,
            type="message",
            title=group_name,
            body=notif_body,
            related_id=group_id,
        )
        db.add(db_notif)
        db.commit()
        db.refresh(db_notif)

        await ws_manager.send(m.user_id, {
            "id": db_notif.id,
            "type": db_notif.type,
            "title": db_notif.title,
            "body": db_notif.body,
            "is_read": False,
            "related_id": group_id,
            "created_at": db_notif.created_at.isoformat(),
        })
        sent += 1

    return {"ok": True, "sent": sent}


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
    db.refresh(new_group)
    return new_group


@router.get("/groups", response_model=List[schemas.FocusGroupRead])
def get_my_groups(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    memberships = db.query(GroupMember).filter(GroupMember.user_id == current_user.id).all()
    return [m.group for m in memberships]


@router.post("/groups/{group_id}/invite", response_model=schemas.InvitationRead)
async def invite_user(
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

    # Search by username OR email prefix
    target = db.query(User).filter(
        or_(User.username == username, User.email.ilike(f"{username}@%"))
    ).first()
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

    # Load receiver profile for notification preferences
    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).first()
    group_name = group.name if group else "a group"
    sender_name = current_user.username or current_user.email

    receiver_profile = db.query(UserProfile).filter(UserProfile.user_id == target.id).first()
    push_enabled = not receiver_profile or receiver_profile.notifications_push

    # In-app bell + WebSocket + FCM — only if recipient has push notifications enabled
    if push_enabled:
        notif_body = f"{sender_name} invited you to join {group_name}"
        db_notif = AppNotification(
            user_id=target.id,
            type="invitation",
            title="New Study Invitation 📚",
            body=notif_body,
            related_id=invite.id,
        )
        db.add(db_notif)
        db.commit()
        db.refresh(db_notif)

        # Live WebSocket push
        await ws_manager.send(target.id, {
            "id": db_notif.id,
            "type": db_notif.type,
            "title": db_notif.title,
            "body": db_notif.body,
            "is_read": False,
            "related_id": invite.id,
            "created_at": db_notif.created_at.isoformat(),
        })

        # FCM device push
        if target.fcm_token:
            try:
                from push_service import send_push
                send_push(
                    token=target.fcm_token,
                    title="New Study Invitation 📚",
                    body=f"{sender_name} invited you to join {group_name}",
                )
            except Exception as e:
                print(f"[FCM] invite push failed: {e}")

    # Invitation email — always sent regardless of notification preferences
    try:
        import asyncio, threading
        from email_utils import send_email
        _email_body = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#f4f6f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:40px 0;">
    <tr><td align="center">
      <table width="520" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#6c3eb5 0%,#4a2d8a 100%);padding:36px 40px;text-align:center;">
            <div style="font-size:28px;font-weight:900;color:#ffffff;letter-spacing:-0.5px;">⚡ FocusFlow</div>
            <div style="color:rgba(255,255,255,0.75);font-size:13px;margin-top:6px;letter-spacing:0.5px;">STUDY GROUP INVITATION</div>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:36px 40px;">
            <h2 style="margin:0 0 8px;font-size:22px;font-weight:700;color:#1a1a2e;">You've been invited! 📚</h2>
            <p style="margin:0 0 24px;color:#555;font-size:15px;line-height:1.6;">
              <strong style="color:#6c3eb5;">{sender_name}</strong> has invited you to join their study group on FocusFlow.
            </p>

            <!-- Group Card -->
            <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8f5ff;border-radius:12px;border:1.5px solid #e0d5f5;margin-bottom:28px;">
              <tr>
                <td style="padding:20px 24px;">
                  <div style="font-size:11px;font-weight:700;color:#9b7fd4;letter-spacing:1px;text-transform:uppercase;margin-bottom:6px;">Study Group</div>
                  <div style="font-size:20px;font-weight:800;color:#1a1a2e;">{group_name}</div>
                  <div style="margin-top:10px;font-size:13px;color:#777;">Invited by <strong>{sender_name}</strong></div>
                </td>
              </tr>
            </table>

            <p style="margin:0 0 28px;color:#555;font-size:14px;line-height:1.6;">
              Open FocusFlow and check your <strong>invitations</strong> to accept or decline. Collaborate, stay focused, and reach your goals together.
            </p>

            <!-- CTA -->
            <table cellpadding="0" cellspacing="0" style="margin:0 auto 12px;">
              <tr>
                <td style="background:linear-gradient(135deg,#6c3eb5,#4a2d8a);border-radius:10px;padding:14px 36px;text-align:center;">
                  <span style="color:#ffffff;font-size:15px;font-weight:700;letter-spacing:0.3px;">Open FocusFlow →</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#fafafa;border-top:1px solid #eee;padding:20px 40px;text-align:center;">
            <p style="margin:0;color:#aaa;font-size:12px;line-height:1.6;">
              You received this because <strong>{sender_name}</strong> invited you to a study group.<br>
              If you don't have a FocusFlow account, you can ignore this email.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>
"""
        def _send():
            asyncio.run(send_email(
                subject=f"📚 {sender_name} invited you to join \"{group_name}\" on FocusFlow",
                email_to=target.email,
                body=_email_body,
            ))
        threading.Thread(target=_send, daemon=True).start()
    except Exception as e:
        print(f"[Email] invite email failed: {e}")

    return schemas.InvitationRead(
        id=invite.id,
        group_id=invite.group_id,
        group_name=invite.group.name,
        sender_id=invite.sender_id,
        sender_name=_display_name(current_user),
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
            sender_name=_display_name(inv.sender),
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
                "username": _display_name(m.user),
                "email": m.user.email,          # needed by frontend to identify current user
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
        "current_user_id": current_user.id,   # convenience field — avoid client-side matching
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

    return {
        "group_id": group_id,
        "sender": _display_name(current_user),
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
                    username=_display_name(u),
                    minutes=mins,
                    rank=rank,
                    is_focusing=u.is_focusing,
                )
            )

    # Weekly activity
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
                username=_display_name(u) if u else "Unknown",
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
