from typing import Optional, List
from fastapi import Depends, HTTPException, Header, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.security import decode_token
from app.models.entities import User, Organization, Membership, RefreshSession
from app.models.enums import OrgRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class TenantContext:
    def __init__(self, user: User, organization: Organization, role: OrgRole, membership: Optional[Membership] = None):
        self.user = user
        self.organization = organization
        self.role = role
        self.membership = membership

    @property
    def org_id(self) -> str:
        return self.organization.id

    @property
    def user_id(self) -> str:
        return self.user.id

def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(oauth2_scheme)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_token(token)
    user_id: Optional[str] = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not user.is_active:
        raise credentials_exception
    return user

def get_current_platform_admin(
    current_user: User = Depends(get_current_user)
) -> User:
    if not current_user.is_platform_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Platform administrator privileges required"
        )
    return current_user

def get_tenant_context(
    x_organization_id: Optional[str] = Header(None, alias="X-Organization-ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> TenantContext:
    if not x_organization_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing required X-Organization-ID header"
        )

    org = db.query(Organization).filter(Organization.id == x_organization_id, Organization.is_active == True).first()
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found or inactive"
        )

    # If platform admin, allow access with synthetic PLATFORM_ADMIN role
    if current_user.is_platform_admin:
        # Check if user has an explicit membership
        membership = db.query(Membership).filter(
            Membership.user_id == current_user.id,
            Membership.organization_id == org.id,
            Membership.is_active == True
        ).first()
        role = membership.role if membership else OrgRole.PLATFORM_ADMIN
        return TenantContext(user=current_user, organization=org, role=role, membership=membership)

    # Standard user membership check
    membership = db.query(Membership).filter(
        Membership.user_id == current_user.id,
        Membership.organization_id == org.id,
        Membership.is_active == True
    ).first()

    if not membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is not an active member of this organization"
        )

    return TenantContext(user=current_user, organization=org, role=membership.role, membership=membership)

def require_roles(allowed_roles: List[OrgRole]):
    def role_checker(ctx: TenantContext = Depends(get_tenant_context)) -> TenantContext:
        if ctx.user.is_platform_admin:
            return ctx
        if ctx.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Action requires one of roles: {[r.value for r in allowed_roles]}. Current role: {ctx.role.value}"
            )
        return ctx
    return role_checker
