import hashlib
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.entities import (
    Complaint, Category, Department, AISuggestion, User
)
from app.models.enums import AISuggestionType, OrgRole
from app.api.deps import get_tenant_context, TenantContext, require_roles
from app.ai.provider import get_ai_provider
from app.ai.duplicate_detection import find_duplicate_candidates

router = APIRouter(prefix="/ai", tags=["AI-Assisted Features"])

class ClassificationRequest(BaseModel):
    title: str
    description: str

class DuplicateCheckRequest(BaseModel):
    title: str
    description: str
    exclude_complaint_id: Optional[str] = None

class ApplySuggestionRequest(BaseModel):
    is_applied: bool

@router.post("/classify")
def classify_complaint_endpoint(
    request: ClassificationRequest,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """
    Suggests category, department routing, and recommended priority with uncertainty indicator
    based on the organization's existing categories and departments.
    """
    categories = db.query(Category).filter(
        Category.organization_id == ctx.org_id,
        Category.is_active == True
    ).all()
    departments = db.query(Department).filter(
        Department.organization_id == ctx.org_id,
        Department.is_active == True
    ).all()

    cats_payload = [{"id": c.id, "name": c.name, "department_id": c.department_id} for c in categories]
    depts_payload = [{"id": d.id, "name": d.name} for d in departments]

    provider = get_ai_provider()
    result = provider.classify_complaint(
        title=request.title,
        description=request.description,
        categories=cats_payload,
        departments=depts_payload
    )

    return result

@router.post("/duplicate-check")
def duplicate_check_endpoint(
    request: DuplicateCheckRequest,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """
    Compares the complaint against existing complaints in the same organization
    and returns similarity scores.
    """
    query = db.query(Complaint).filter(Complaint.organization_id == ctx.org_id)
    if request.exclude_complaint_id:
        query = query.filter(Complaint.id != request.exclude_complaint_id)

    existing = query.limit(100).all()
    corpus = [
        {
            "id": c.id,
            "tracking_number": c.tracking_number,
            "title": c.title,
            "description": c.description,
            "status": c.status.value
        }
        for c in existing
    ]

    candidates = find_duplicate_candidates(
        target_title=request.title,
        target_description=request.description,
        existing_complaints=corpus,
        similarity_threshold=0.25,
        top_k=5
    )

    return {
        "candidate_duplicates": candidates,
        "total_matches": len(candidates),
        "method": "tf_idf_cosine_similarity"
    }

@router.get("/complaints/{complaint_id}/summary")
def summarize_complaint_endpoint(
    complaint_id: str,
    ctx: TenantContext = Depends(require_roles([OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN])),
    db: Session = Depends(get_db)
):
    """
    Generates a structured, concise summary for authorized staff
    including reported problem, updates, actions taken, and next steps.
    """
    complaint = db.query(Complaint).filter(
        Complaint.id == complaint_id,
        Complaint.organization_id == ctx.org_id
    ).first()

    if not complaint:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint not found")

    comments_payload = [
        {"comment_text": c.comment_text, "is_internal_note": c.is_internal_note, "user_name": c.user.full_name if c.user else "User"}
        for c in complaint.comments
    ]
    history_payload = [
        {"event_type": h.event_type.value, "to_status": h.to_status, "actor_name": h.actor.full_name if h.actor else "Actor"}
        for h in complaint.history
    ]

    provider = get_ai_provider()
    summary = provider.summarize_complaint(
        title=complaint.title,
        description=complaint.description,
        comments=comments_payload,
        history=history_payload
    )

    # Persist as AISuggestion
    prompt_hash = hashlib.sha256(f"{complaint.id}:{len(complaint.comments)}".encode("utf-8")).hexdigest()
    suggestion = AISuggestion(
        organization_id=ctx.org_id,
        complaint_id=complaint.id,
        suggestion_type=AISuggestionType.SUMMARIZATION,
        provider=summary.get("provider", "local_fallback"),
        model_version=summary.get("model_version", "heuristic-nlp-v1"),
        raw_prompt_hash=prompt_hash,
        payload=summary
    )
    db.add(suggestion)
    db.commit()

    return summary

@router.get("/complaints/{complaint_id}/suggestions")
def get_complaint_ai_suggestions(
    complaint_id: str,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Lists saved AI suggestions for a complaint"""
    suggestions = db.query(AISuggestion).filter(
        AISuggestion.complaint_id == complaint_id,
        AISuggestion.organization_id == ctx.org_id
    ).order_by(AISuggestion.created_at.desc()).all()

    return suggestions
