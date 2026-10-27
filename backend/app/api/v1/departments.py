from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.entities import Department
from app.models.enums import OrgRole
from app.schemas import DepartmentCreate, DepartmentResponse
from app.api.deps import get_tenant_context, TenantContext, require_roles

router = APIRouter(prefix="/departments", tags=["Departments"])

@router.get("", response_model=List[DepartmentResponse])
def list_departments(
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """List all active departments for the active organization"""
    depts = db.query(Department).filter(
        Department.organization_id == ctx.org_id,
        Department.is_active == True
    ).order_by(Department.name).all()
    return depts

@router.post("", response_model=DepartmentResponse)
def create_department(
    request: DepartmentCreate,
    ctx: TenantContext = Depends(require_roles([OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """Org Admin creates a department in the organization"""
    existing = db.query(Department).filter(
        Department.organization_id == ctx.org_id,
        Department.code == request.code.upper()
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department with code '{request.code}' already exists in this organization"
        )

    dept = Department(
        organization_id=ctx.org_id,
        name=request.name,
        code=request.code.upper(),
        description=request.description
    )
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept
