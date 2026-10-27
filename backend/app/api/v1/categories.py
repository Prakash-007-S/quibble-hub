from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.entities import Category, Department
from app.models.enums import OrgRole
from app.schemas import CategoryCreate, CategoryResponse
from app.api.deps import get_tenant_context, TenantContext, require_roles

router = APIRouter(prefix="/categories", tags=["Categories"])

@router.get("", response_model=List[CategoryResponse])
def list_categories(
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """List all active complaint categories for the active organization"""
    cats = db.query(Category).filter(
        Category.organization_id == ctx.org_id,
        Category.is_active == True
    ).order_by(Category.name).all()

    result = []
    for c in cats:
        result.append(CategoryResponse(
            id=c.id,
            organization_id=c.organization_id,
            department_id=c.department_id,
            department_name=c.department.name if c.department else None,
            name=c.name,
            description=c.description,
            default_priority=c.default_priority,
            is_active=c.is_active
        ))
    return result

@router.post("", response_model=CategoryResponse)
def create_category(
    request: CategoryCreate,
    ctx: TenantContext = Depends(require_roles([OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """Org Admin creates a complaint category with default department routing"""
    dept = db.query(Department).filter(
        Department.id == request.department_id,
        Department.organization_id == ctx.org_id
    ).first()

    if not dept:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Department does not belong to this organization"
        )

    existing = db.query(Category).filter(
        Category.organization_id == ctx.org_id,
        Category.name == request.name
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Category '{request.name}' already exists in this organization"
        )

    cat = Category(
        organization_id=ctx.org_id,
        department_id=dept.id,
        name=request.name,
        description=request.description,
        default_priority=request.default_priority
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)

    return CategoryResponse(
        id=cat.id,
        organization_id=cat.organization_id,
        department_id=cat.department_id,
        department_name=dept.name,
        name=cat.name,
        description=cat.description,
        default_priority=cat.default_priority,
        is_active=cat.is_active
    )
