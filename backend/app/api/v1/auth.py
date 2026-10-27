import hashlib
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.config import settings
from app.core.security import (
    verify_password, get_password_hash, create_access_token, 
    create_refresh_token, decode_token
)
from app.models.entities import User, Membership, Organization, RefreshSession
from app.models.enums import OrgRole, OrgType
from app.schemas import (
    LoginRequest, RegisterRequest, RefreshTokenRequest, 
    Token, UserResponse, MembershipResponse
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

@router.post("/login", response_model=Token)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email.lower()).first()
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )

    claims = {"email": user.email, "is_platform_admin": user.is_platform_admin}
    if request.organization_id:
        membership = db.query(Membership).filter(
            Membership.user_id == user.id,
            Membership.organization_id == request.organization_id,
            Membership.is_active == True
        ).first()
        if membership:
            claims["org_id"] = membership.organization_id
            claims["role"] = membership.role.value

    access_token = create_access_token(subject=user.id, claims=claims)
    raw_refresh = create_refresh_token()
    token_hash = hash_refresh_token(raw_refresh)

    # Persist revocable refresh session
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    session_record = RefreshSession(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=expires_at
    )
    db.add(session_record)
    db.commit()

    return Token(
        access_token=access_token,
        refresh_token=raw_refresh,
        token_type="bearer"
    )

@router.post("/register", response_model=UserResponse)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == request.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists"
        )

    user = User(
        email=request.email.lower(),
        full_name=request.full_name,
        hashed_password=get_password_hash(request.password),
        is_platform_admin=False
    )
    db.add(user)
    db.flush()

    # If organization specified, create membership
    if request.organization_id:
        org = db.query(Organization).filter(Organization.id == request.organization_id, Organization.is_active == True).first()
        if not org:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Specified organization not found"
            )
        # Enforce that public self-registration can never grant administrative privileges
        assigned_role = OrgRole.COMPLAINANT
        if request.role and request.role == OrgRole.COMPLAINANT:
            assigned_role = OrgRole.COMPLAINANT

        membership = Membership(
            user_id=user.id,
            organization_id=org.id,
            role=assigned_role
        )
        db.add(membership)

    db.commit()
    db.refresh(user)

    # Prepare response
    memberships = []
    for m in user.memberships:
        memberships.append(MembershipResponse(
            id=m.id,
            organization_id=m.organization.id,
            organization_name=m.organization.name,
            org_slug=m.organization.slug,
            org_type=m.organization.org_type,
            role=m.role,
            is_active=m.is_active
        ))

    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_platform_admin=user.is_platform_admin,
        memberships=memberships
    )

@router.post("/refresh", response_model=Token)
def refresh_token(request: RefreshTokenRequest, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(request.refresh_token)
    session_record = db.query(RefreshSession).filter(
        RefreshSession.token_hash == token_hash,
        RefreshSession.is_revoked == False
    ).first()

    now = datetime.now(timezone.utc)
    if not session_record or session_record.expires_at < now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is invalid or expired"
        )

    user = db.query(User).filter(User.id == session_record.user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )

    # Revoke old session and issue new pair (rotation)
    session_record.is_revoked = True

    new_raw_refresh = create_refresh_token()
    new_token_hash = hash_refresh_token(new_raw_refresh)
    new_expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    new_session = RefreshSession(
        user_id=user.id,
        token_hash=new_token_hash,
        expires_at=new_expires_at
    )
    db.add(new_session)

    access_token = create_access_token(
        subject=user.id,
        claims={"email": user.email, "is_platform_admin": user.is_platform_admin}
    )
    db.commit()

    return Token(
        access_token=access_token,
        refresh_token=new_raw_refresh,
        token_type="bearer"
    )

@router.post("/logout")
def logout(request: RefreshTokenRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(request.refresh_token)
    session_record = db.query(RefreshSession).filter(
        RefreshSession.token_hash == token_hash,
        RefreshSession.user_id == current_user.id
    ).first()

    if session_record:
        session_record.is_revoked = True
        db.commit()

    return {"detail": "Successfully logged out and session revoked"}

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    memberships = []
    for m in current_user.memberships:
        if m.is_active and m.organization.is_active:
            memberships.append(MembershipResponse(
                id=m.id,
                organization_id=m.organization.id,
                organization_name=m.organization.name,
                org_slug=m.organization.slug,
                org_type=m.organization.org_type,
                role=m.role,
                is_active=m.is_active
            ))

    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        is_platform_admin=current_user.is_platform_admin,
        memberships=memberships
    )
