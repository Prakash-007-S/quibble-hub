import os
import hashlib
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc

from app.db.session import get_db
from app.core.config import settings
from app.models.entities import (
    Complaint, Category, Department, User, Membership,
    ComplaintComment, ComplaintAttachment, ComplaintHistory,
    ComplaintFeedback, DepartmentMember
)
from app.models.enums import OrgRole, ComplaintStatus, ComplaintPriority, EventType
from app.schemas import (
    ComplaintCreate, ComplaintResponse, ComplaintDetailResponse,
    ComplaintListResponse, ComplaintAssignRequest, ComplaintTransitionRequest,
    ComplaintCommentCreate, ComplaintCommentResponse, ComplaintAttachmentResponse,
    ComplaintHistoryResponse, ComplaintFeedbackCreate, ComplaintFeedbackResponse
)
from app.api.deps import get_tenant_context, TenantContext, require_roles
from app.services.complaint_workflow import (
    ComplaintWorkflowService, generate_safe_tracking_number,
    calculate_sla_deadlines, utcnow
)

router = APIRouter(prefix="/complaints", tags=["Complaints"])

def can_access_complaint(complaint: Complaint, ctx: TenantContext, db: Session) -> bool:
    """Verifies that user has permission to view this specific complaint within the tenant"""
    if complaint.organization_id != ctx.org_id:
        return False
    if ctx.user.is_platform_admin or ctx.role == OrgRole.ORG_ADMIN:
        return True
    if complaint.complainant_id == ctx.user_id:
        return True
    if complaint.assignee_id == ctx.user_id:
        return True
    if ctx.role in [OrgRole.DEPT_MANAGER, OrgRole.STAFF]:
        # Check if staff member belongs to complaint's department
        dept_mem = db.query(DepartmentMember).filter(
            DepartmentMember.department_id == complaint.department_id,
            DepartmentMember.user_id == ctx.user_id
        ).first()
        if dept_mem or ctx.role == OrgRole.DEPT_MANAGER:
            return True
    return False

def build_complaint_response(c: Complaint) -> ComplaintResponse:
    feedback_resp = None
    if c.feedback:
        feedback_resp = ComplaintFeedbackResponse(
            id=c.feedback.id,
            rating=c.feedback.rating,
            comments=c.feedback.comments,
            resolution_satisfactory=c.feedback.resolution_satisfactory,
            created_at=c.feedback.created_at
        )

    return ComplaintResponse(
        id=c.id,
        tracking_number=c.tracking_number,
        organization_id=c.organization_id,
        category_id=c.category_id,
        category_name=c.category.name if c.category else "General",
        department_id=c.department_id,
        department_name=c.department.name if c.department else "Unassigned",
        complainant_id=c.complainant_id,
        complainant_name=c.complainant.full_name if c.complainant else "Unknown",
        assignee_id=c.assignee_id,
        assignee_name=c.assignee.full_name if c.assignee else None,
        title=c.title,
        description=c.description,
        location_context=c.location_context,
        status=c.status,
        priority=c.priority,
        sla_first_response_due=c.sla_first_response_due,
        sla_resolution_due=c.sla_resolution_due,
        first_responded_at=c.first_responded_at,
        resolved_at=c.resolved_at,
        closed_at=c.closed_at,
        resolution_summary=c.resolution_summary,
        rejection_reason=c.rejection_reason,
        reopen_count=c.reopen_count,
        is_escalated=c.is_escalated,
        created_at=c.created_at,
        updated_at=c.updated_at,
        comments_count=len(c.comments) if c.comments else 0,
        attachments_count=len(c.attachments) if c.attachments else 0,
        feedback=feedback_resp
    )

@router.post("", response_model=ComplaintResponse, status_code=status.HTTP_201_CREATED)
def create_complaint(
    request: ComplaintCreate,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """
    Submits a new complaint in the active organization.
    Automatically assigns default department from category and computes SLA deadlines.
    """
    category = db.query(Category).filter(
        Category.id == request.category_id,
        Category.organization_id == ctx.org_id,
        Category.is_active == True
    ).first()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category not found or does not belong to active organization"
        )

    # Determine priority: if user supplies priority (and is staff/manager/admin) use it, else category default
    priority = category.default_priority
    if request.priority and (ctx.role in [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN] or ctx.user.is_platform_admin):
        priority = request.priority

    # Generate safe unique tracking number
    tracking_number = generate_safe_tracking_number(db, ctx.organization)

    # Compute SLA deadlines
    first_resp_due, res_due = calculate_sla_deadlines(db, ctx.org_id, priority, category.id)

    complaint = Complaint(
        tracking_number=tracking_number,
        organization_id=ctx.org_id,
        category_id=category.id,
        department_id=category.department_id,
        complainant_id=ctx.user_id,
        title=request.title.strip(),
        description=request.description.strip(),
        location_context=request.location_context.strip() if request.location_context else None,
        status=ComplaintStatus.SUBMITTED,
        priority=priority,
        sla_first_response_due=first_resp_due,
        sla_resolution_due=res_due
    )
    db.add(complaint)
    db.flush()

    # Initial Audit History
    history = ComplaintHistory(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        actor_id=ctx.user_id,
        event_type=EventType.STATUS_CHANGE,
        to_status=ComplaintStatus.SUBMITTED.value,
        field_name="status",
        new_value=ComplaintStatus.SUBMITTED.value,
        reason="Initial complaint submission"
    )
    db.add(history)
    db.commit()
    db.refresh(complaint)

    return build_complaint_response(complaint)

@router.get("", response_model=ComplaintListResponse)
def list_complaints(
    status_filter: Optional[ComplaintStatus] = Query(None, alias="status"),
    priority_filter: Optional[ComplaintPriority] = Query(None, alias="priority"),
    department_id: Optional[str] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """
    Lists complaints scoped strictly to tenant and role permissions with filtering and pagination.
    """
    query = db.query(Complaint).filter(Complaint.organization_id == ctx.org_id)

    # Role-based scoping
    if ctx.role == OrgRole.COMPLAINANT:
        query = query.filter(Complaint.complainant_id == ctx.user_id)
    elif ctx.role == OrgRole.STAFF:
        # Staff sees complaints assigned to them OR in departments they are members of
        staff_dept_ids = [
            dm.department_id for dm in db.query(DepartmentMember).filter(DepartmentMember.user_id == ctx.user_id).all()
        ]
        query = query.filter(
            or_(
                Complaint.assignee_id == ctx.user_id,
                Complaint.department_id.in_(staff_dept_ids) if staff_dept_ids else False
            )
        )
    elif ctx.role == OrgRole.DEPT_MANAGER:
        # Dept Manager sees complaints in their departments
        mgr_dept_ids = [
            dm.department_id for dm in db.query(DepartmentMember).filter(DepartmentMember.user_id == ctx.user_id).all()
        ]
        if mgr_dept_ids:
            query = query.filter(Complaint.department_id.in_(mgr_dept_ids))
    # ORG_ADMIN and PLATFORM_ADMIN see all complaints in tenant

    # Filters
    if status_filter:
        query = query.filter(Complaint.status == status_filter)
    if priority_filter:
        query = query.filter(Complaint.priority == priority_filter)
    if department_id:
        query = query.filter(Complaint.department_id == department_id)
    if search:
        search_pattern = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Complaint.title.ilike(search_pattern),
                Complaint.description.ilike(search_pattern),
                Complaint.tracking_number.ilike(search_pattern)
            )
        )

    total = query.count()
    items = query.order_by(desc(Complaint.created_at)).offset((page - 1) * size).limit(size).all()

    return ComplaintListResponse(
        total=total,
        page=page,
        size=size,
        items=[build_complaint_response(c) for c in items]
    )

@router.get("/{complaint_id}", response_model=ComplaintDetailResponse)
def get_complaint_detail(
    complaint_id: str,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """
    Fetches full complaint details including comments, attachments, history, and feedback.
    Enforces tenant and role authorization.
    """
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    if not can_access_complaint(complaint, ctx, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this complaint")

    base_resp = build_complaint_response(complaint)

    # Filter internal notes for complainants
    comments = []
    for comm in complaint.comments:
        if comm.is_internal_note and ctx.role == OrgRole.COMPLAINANT:
            continue
        comments.append(ComplaintCommentResponse(
            id=comm.id,
            user_id=comm.user_id,
            user_name=comm.user.full_name if comm.user else "Unknown",
            comment_text=comm.comment_text,
            is_internal_note=comm.is_internal_note,
            created_at=comm.created_at
        ))

    attachments = []
    for att in complaint.attachments:
        attachments.append(ComplaintAttachmentResponse(
            id=att.id,
            filename=att.filename,
            file_size=att.file_size,
            content_type=att.content_type,
            uploader_id=att.uploader_id,
            uploader_name=att.uploader.full_name if att.uploader else "Unknown",
            created_at=att.created_at
        ))

    history_list = []
    for h in complaint.history:
        history_list.append(ComplaintHistoryResponse(
            id=h.id,
            actor_id=h.actor_id,
            actor_name=h.actor.full_name if h.actor else "System",
            event_type=h.event_type,
            from_status=h.from_status,
            to_status=h.to_status,
            field_name=h.field_name,
            old_value=h.old_value,
            new_value=h.new_value,
            reason=h.reason,
            created_at=h.created_at
        ))

    return ComplaintDetailResponse(
        **base_resp.model_dump(),
        comments=comments,
        attachments=attachments,
        history=history_list
    )

@router.post("/{complaint_id}/assign", response_model=ComplaintResponse)
def assign_complaint(
    complaint_id: str,
    request: ComplaintAssignRequest,
    ctx: TenantContext = Depends(require_roles([OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """Assign or reassign a complaint to a staff member"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    assignee = db.query(User).filter(User.id == request.assignee_id, User.is_active == True).first()
    if not assignee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignee user not found")

    # Verify assignee is member of organization
    mem = db.query(Membership).filter(
        Membership.user_id == assignee.id,
        Membership.organization_id == ctx.org_id,
        Membership.is_active == True
    ).first()
    if not mem:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Assignee is not a member of this organization")

    updated = ComplaintWorkflowService.assign_complaint(
        db=db,
        complaint=complaint,
        assignee=assignee,
        assigner=ctx.user,
        assigner_role=ctx.role,
        notes=request.notes
    )
    db.commit()
    db.refresh(updated)
    return build_complaint_response(updated)

@router.post("/{complaint_id}/transition", response_model=ComplaintResponse)
def transition_complaint_status(
    complaint_id: str,
    request: ComplaintTransitionRequest,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Executes a validated lifecycle status transition"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    if not can_access_complaint(complaint, ctx, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this complaint")

    updated = ComplaintWorkflowService.transition_status(
        db=db,
        complaint=complaint,
        to_status=request.to_status,
        actor=ctx.user,
        actor_role=ctx.role,
        reason=request.reason,
        resolution_summary=request.resolution_summary
    )
    db.commit()
    db.refresh(updated)
    return build_complaint_response(updated)

@router.post("/{complaint_id}/comments", response_model=ComplaintCommentResponse)
def add_comment(
    complaint_id: str,
    request: ComplaintCommentCreate,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Posts a public response or internal note to a complaint"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    if not can_access_complaint(complaint, ctx, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this complaint")

    # Complainants cannot post internal notes
    is_internal = request.is_internal_note
    if ctx.role == OrgRole.COMPLAINANT:
        is_internal = False

    comment = ComplaintComment(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        user_id=ctx.user_id,
        comment_text=request.comment_text.strip(),
        is_internal_note=is_internal
    )
    db.add(comment)

    # If complaint was AWAITING_USER and complainant responds, transition back to IN_PROGRESS
    if complaint.status == ComplaintStatus.AWAITING_USER and ctx.user_id == complaint.complainant_id:
        ComplaintWorkflowService.transition_status(
            db=db,
            complaint=complaint,
            to_status=ComplaintStatus.IN_PROGRESS,
            actor=ctx.user,
            actor_role=ctx.role,
            reason="Complainant provided requested information in comment"
        )

    db.commit()
    db.refresh(comment)

    return ComplaintCommentResponse(
        id=comment.id,
        user_id=comment.user_id,
        user_name=ctx.user.full_name,
        comment_text=comment.comment_text,
        is_internal_note=comment.is_internal_note,
        created_at=comment.created_at
    )

@router.post("/{complaint_id}/attachments", response_model=ComplaintAttachmentResponse)
async def upload_attachment(
    complaint_id: str,
    file: UploadFile = File(...),
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Securely uploads an attachment for a complaint"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    if not can_access_complaint(complaint, ctx, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    # Validate file extension
    ext = file.filename.split(".")[-1].lower() if "." in file.filename else ""
    if ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File extension '.{ext}' is not permitted. Allowed: {list(settings.ALLOWED_EXTENSIONS)}"
        )

    # Read bytes and validate size
    content = await file.read()
    file_size = len(content)
    max_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    if file_size > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds maximum size of {settings.MAX_UPLOAD_SIZE_MB}MB"
        )

    # Safe filename on disk: hash + org_id
    checksum = hashlib.sha256(content).hexdigest()
    storage_dir = os.path.join(settings.UPLOAD_DIR, ctx.org_id)
    os.makedirs(storage_dir, exist_ok=True)

    safe_filename = f"{checksum[:16]}_{os.path.basename(file.filename)}"
    storage_path = os.path.join(storage_dir, safe_filename)

    with open(storage_path, "wb") as f:
        f.write(content)

    attachment = ComplaintAttachment(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        uploader_id=ctx.user_id,
        filename=os.path.basename(file.filename),
        storage_path=storage_path,
        file_size=file_size,
        content_type=file.content_type or "application/octet-stream",
        checksum=checksum
    )
    db.add(attachment)

    # Audit history
    db.add(ComplaintHistory(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        actor_id=ctx.user_id,
        event_type=EventType.ATTACHMENT_ADDED,
        field_name="attachment",
        new_value=file.filename,
        reason=f"Uploaded evidence ({file_size} bytes)"
    ))

    db.commit()
    db.refresh(attachment)

    return ComplaintAttachmentResponse(
        id=attachment.id,
        filename=attachment.filename,
        file_size=attachment.file_size,
        content_type=attachment.content_type,
        uploader_id=attachment.uploader_id,
        uploader_name=ctx.user.full_name,
        created_at=attachment.created_at
    )

@router.get("/{complaint_id}/attachments/{attachment_id}/download")
def download_attachment(
    complaint_id: str,
    attachment_id: str,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Authorized download of an attachment file"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint or not can_access_complaint(complaint, ctx, db):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment or complaint not found")

    attachment = db.query(ComplaintAttachment).filter(
        ComplaintAttachment.id == attachment_id,
        ComplaintAttachment.complaint_id == complaint.id,
        ComplaintAttachment.organization_id == ctx.org_id
    ).first()

    if not attachment or not os.path.exists(attachment.storage_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment file not found on storage")

    return FileResponse(
        path=attachment.storage_path,
        filename=attachment.filename,
        media_type=attachment.content_type
    )

@router.post("/{complaint_id}/feedback", response_model=ComplaintFeedbackResponse)
def submit_feedback(
    complaint_id: str,
    request: ComplaintFeedbackCreate,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Complainant records resolution feedback and rating"""
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    if complaint.complainant_id != ctx.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the complainant can submit feedback")

    if complaint.status not in [ComplaintStatus.RESOLVED, ComplaintStatus.CLOSED]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Feedback can only be submitted for resolved or closed complaints")

    existing_feedback = db.query(ComplaintFeedback).filter(ComplaintFeedback.complaint_id == complaint.id).first()
    if existing_feedback:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Feedback has already been submitted for this complaint")

    fb = ComplaintFeedback(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        complainant_id=ctx.user_id,
        rating=request.rating,
        comments=request.comments,
        resolution_satisfactory=request.resolution_satisfactory
    )
    db.add(fb)

    # Audit history
    db.add(ComplaintHistory(
        complaint_id=complaint.id,
        organization_id=ctx.org_id,
        actor_id=ctx.user_id,
        event_type=EventType.FEEDBACK_SUBMITTED,
        new_value=f"Rating: {request.rating}/5, Satisfactory: {request.resolution_satisfactory}",
        reason=request.comments
    ))

    db.commit()
    db.refresh(fb)

    return ComplaintFeedbackResponse(
        id=fb.id,
        rating=fb.rating,
        comments=fb.comments,
        resolution_satisfactory=fb.resolution_satisfactory,
        created_at=fb.created_at
    )
