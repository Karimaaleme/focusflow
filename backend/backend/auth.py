from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

import firebase_admin_init  # MUST be first
from firebase_admin import auth as firebase_auth

from database import SessionLocal, get_db
from models import User

security = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    token = credentials.credentials

    try:
        decoded = firebase_auth.verify_id_token(token)
        email = decoded.get("email")

        if not email:
            raise HTTPException(status_code=401, detail="No email in token")

        user = db.query(User).filter(User.email == email).first()
        if not user:
            user = User(email=email)
            db.add(user)
            db.commit()
            db.refresh(user)

        return user

    except Exception as e:
        print(f"❌ FIREBASE VERIFY ERROR: {str(e)}")
        print(f"❌ Token received: {token[:10]}... (len={len(token)})")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase token: {str(e)}",
        )
    
