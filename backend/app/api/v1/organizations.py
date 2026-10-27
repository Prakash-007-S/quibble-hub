from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.entities import Organization, Membership, User
from app.models.enums import OrgRole, OrgType
from app.schemas import OrganizationCreate, OrganizationResponse, MembershipResponse
from app.api.deps import get_current_user, get_current_platform_admin, get_tenant_context, TenantContext, require_roles

router = APIRouter(prefix="/organizations", tags=["Organizations"])

class AddMemberRequest(BaseModel):
    email: str = Field(..., min_length=3)
    role: OrgRole

@router.get("", response_model=List[OrganizationResponse])
def list_organizations(db: Session = Depends(get_db)):
    """Public list of active organizations for user onboarding and switching"""
    orgs = db.query(Organization).filter(Organization.is_active == True).order_by(Organization.name).all()
    return orgs

@router.post("", response_model=OrganizationResponse)
def create_organization(
    request: OrganizationCreate,
    current_admin: User = Depends(get_current_platform_admin),
    db: Session = Depends(get_db)
):
    """Platform administrator onboards a new organization"""
    existing = db.query(Organization).filter(Organization.slug == request.slug).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Organization slug '{request.slug}' already exists"
        )

    org = Organization(
        name=request.name,
        slug=request.slug,
        org_type=request.org_type,
        settings=request.settings or {}
    )
    db.add(org)
    db.commit()
    db.refresh(org)
    return org

@router.get("/{org_id}", response_model=OrganizationResponse)
def get_organization(org_id: str, db: Session = Depends(get_db)):
    org = db.query(Organization).filter(Organization.id == org_id, Organization.is_active == True).first()
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found"
        )
    return org

@router.get("/{org_id}/memberships", response_model=List[MembershipResponse])
def list_org_members(
    org_id: str,
    ctx: TenantContext = Depends(require_roles([OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """Org Admin views all members in this organization"""
    if ctx.org_id != org_id and not ctx.user.is_platform_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cross-tenant access forbidden")

    memberships = db.query(Membership).filter(
        Membership.organization_id == org_id,
        Membership.is_active == True
    ).all()

    result = []
    for m in memberships:
        result.append(MembershipResponse(
            id=m.id,
            organization_id=m.organization.id,
            organization_name=m.organization.name,
            org_slug=m.organization.slug,
            org_type=m.organization.org_type,
            role=m.role,
            is_active=m.is_active
        ))
    return result

@router.post("/{org_id}/memberships", response_model=MembershipResponse)
def add_or_update_member(
    org_id: str,
    request: AddMemberRequest,
    ctx: TenantContext = Depends(require_roles([OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """Org Admin adds or updates an organization member's role"""
    if ctx.org_id != org_id and not ctx.user.is_platform_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cross-tenant access forbidden")

    target_user = db.query(User).filter(User.email == request.email.lower()).first()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User with this email does not exist")

    membership = db.query(Membership).filter(
        Membership.organization_id == org_id,
        Membership.user_id == target_user.id
    ).first()

    if membership:
        membership.role = request.role
        membership.is_active = True
    else:
        membership = Membership(
            organization_id=org_id,
            user_id=target_user.id,
            role=request.role,
            is_active=True
        )
        db.add(membership)

    db.commit()
    db.refresh(membership)

    return MembershipResponse(
        id=membership.id,
        organization_id=membership.organization.id,
        organization_name=membership.organization.name,
        org_slug=membership.organization.slug,
        org_type=membership.organization.org_type,
        role=membership.role,
        is_active=membership.is_active
    )
