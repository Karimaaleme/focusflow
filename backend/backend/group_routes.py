from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_
from typing import List

from database import SessionLocal, get_db
from auth import get_current_user
from models import User, FocusGroup, GroupMember, Invitation
from schemas import (
    UserSimple,
    FocusGroupCreate,
    FocusGroupRead,
    InvitationCreate,
    InvitationRead,
    GroupMemberRead
)

router = APIRouter()

# ===========================
#        USER SEARCH
# ===========================
@router.get("/users/search", response_model=List[UserSimple])
def search_users(
    query: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if len(query) < 2:
        return []
    
    users = db.query(User).filter(
        or_(
            User.username.ilike(f"%{query}%"),
            User.email.ilike(f"%{query}%")
        ),
        User.id != current_user.id 
    ).limit(10).all()
    
    return users

@router.put("/users/username", response_model=UserSimple)
def update_username(
    username: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check uniqueness
    existing = db.query(User).filter(User.username == username).first()
    if existing and existing.id != current_user.id:
        raise HTTPException(
            status_code=400,
            detail="Username already taken"
        )
    
    current_user.username = username
    db.commit()
    db.refresh(current_user)
    return current_user

# ===========================
#          GROUPS
# ===========================
@router.post("/groups", response_model=FocusGroupRead)
def create_group(
    group_in: FocusGroupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Create Group
    new_group = FocusGroup(
        name=group_in.name,
        description=group_in.description,
        owner_id=current_user.id
    )
    db.add(new_group)
    db.commit()
    db.refresh(new_group)

    # Add owner as admin member
    member = GroupMember(
        group_id=new_group.id,
        user_id=current_user.id,
        role="admin"
    )
    db.add(member)
    db.commit()
    
    # Reload with members for response
    # We might need to query it again to load relationships if lazy loading
    return new_group

@router.get("/groups", response_model=List[FocusGroupRead])
def list_my_groups(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Find groups where user is a member
    memberships = db.query(GroupMember).filter(GroupMember.user_id == current_user.id).all()
    group_ids = [m.group_id for m in memberships]
    
    groups = db.query(FocusGroup).filter(FocusGroup.id.in_(group_ids)).options(joinedload(FocusGroup.members).joinedload(GroupMember.user)).all()
    return groups

@router.get("/groups/{group_id}", response_model=FocusGroupRead)
def get_group_details(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check membership
    is_member = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()
    
    if not is_member:
        raise HTTPException(status_code=403, detail="Not a member of this group")

    group = db.query(FocusGroup).filter(FocusGroup.id == group_id).options(joinedload(FocusGroup.members).joinedload(GroupMember.user)).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
        
    return group

@router.post("/groups/{group_id}/leave")
def leave_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()
    
    if not member:
        raise HTTPException(status_code=404, detail="Not a member")
    
    # Optional logic: if owner leaves -> delete group or reassign?
    # For now simple leave
    db.delete(member)
    db.commit()
    return {"message": "Left group"}

# ===========================
#        INVITATIONS
# ===========================
@router.post("/groups/{group_id}/invite", response_model=InvitationRead)
def invite_user(
    group_id: int,
    invite_in: InvitationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1. Check if sender is member of group
    sender_member = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == current_user.id
    ).first()
    if not sender_member:
        raise HTTPException(status_code=403, detail="You must be a member to invite others")

    # 2. Find receiver (By Username OR Email)
    receiver = db.query(User).filter(
        or_(
            User.username == invite_in.receiver_username,
            User.email == invite_in.receiver_username
        )
    ).first()
    
    if not receiver:
        raise HTTPException(status_code=404, detail="User not found (Check username or email)")
    
    # 3. Check if already member
    existing_member = db.query(GroupMember).filter(
        GroupMember.group_id == group_id,
        GroupMember.user_id == receiver.id
    ).first()
    if existing_member:
        raise HTTPException(status_code=400, detail="User is already a member")

    # 4. Check if pending invitation exists
    existing_invite = db.query(Invitation).filter(
        Invitation.group_id == group_id,
        Invitation.receiver_id == receiver.id,
        Invitation.status == "pending"
    ).first()
    if existing_invite:
        raise HTTPException(status_code=400, detail="Invitation already sent")

    # 5. Create Invitation
    new_invite = Invitation(
        sender_id=current_user.id,
        receiver_id=receiver.id,
        group_id=group_id,
        status="pending"
    )
    db.add(new_invite)
    db.commit()
    db.refresh(new_invite)
    
    return new_invite

@router.get("/invitations", response_model=List[InvitationRead])
def get_my_invitations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invites = db.query(Invitation).filter(
        Invitation.receiver_id == current_user.id, 
        Invitation.status == "pending"
    ).options(joinedload(Invitation.sender), joinedload(Invitation.group)).all()
    return invites

@router.post("/invitations/{invite_id}/{action}")
def respond_invitation(
    invite_id: int,
    action: str, # accept, decline
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invite = db.query(Invitation).filter(
        Invitation.id == invite_id,
        Invitation.receiver_id == current_user.id
    ).first()
    
    if not invite:
        raise HTTPException(status_code=404, detail="Invitation not found")
        
    if action == "accept":
        invite.status = "accepted"
        # Add to group
        new_member = GroupMember(
            group_id=invite.group_id,
            user_id=current_user.id,
            role="member"
        )
        db.add(new_member)
    elif action == "decline":
        invite.status = "declined"
    else:
        raise HTTPException(status_code=400, detail="Invalid action")
        
    db.commit()
    return {"message": f"Invitation {action}ed"}
