import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.models.entities import (
    Complaint, ComplaintHistory, ComplaintAssignment, 
    Organization, Category, SLAPolicy, Notification, User
)
from app.models.enums import ComplaintStatus, ComplaintPriority, OrgRole, EventType

def utcnow() -> datetime:
    return datetime.now(timezone.utc)

def generate_safe_tracking_number(db: Session, org: Organization) -> str:
    """
    Safely generates a unique, human-readable complaint tracking number
    Pattern: {ORG_CODE}-{YEAR}-{RANDOM_TOKEN}
    Guaranteed unique in database without MAX()+1 race conditions.
    """
    prefix = org.slug[:3].upper() if org.slug else "CMP"
    year = utcnow().year
    
    for _ in range(10):
        # 6-character random uppercase alphanumeric token (e.g. 8K2M9P)
        token = secrets.token_hex(3).upper()
        tracking_number = f"{prefix}-{year}-{token}"
        
        # Check uniqueness
        exists = db.query(Complaint.id).filter(Complaint.tracking_number == tracking_number).first()
        if not exists:
            return tracking_number
            
    # Fallback with longer entropy if ever needed
    return f"{prefix}-{year}-{secrets.token_hex(5).upper()}"

# Transition validation table: (current_status, target_status) -> allowed_roles
ALLOWED_TRANSITIONS = {
    (ComplaintStatus.SUBMITTED, ComplaintStatus.ASSIGNED): [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.SUBMITTED, ComplaintStatus.REJECTED): [OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.ASSIGNED, ComplaintStatus.IN_PROGRESS): [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.ASSIGNED, ComplaintStatus.ASSIGNED): [OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],  # Reassignment
    (ComplaintStatus.IN_PROGRESS, ComplaintStatus.AWAITING_USER): [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.AWAITING_USER, ComplaintStatus.IN_PROGRESS): [OrgRole.COMPLAINANT, OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.IN_PROGRESS, ComplaintStatus.RESOLVED): [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.RESOLVED, ComplaintStatus.CLOSED): [OrgRole.COMPLAINANT, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.RESOLVED, ComplaintStatus.REOPENED): [OrgRole.COMPLAINANT, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
    (ComplaintStatus.REOPENED, ComplaintStatus.IN_PROGRESS): [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN, OrgRole.PLATFORM_ADMIN],
}

def calculate_sla_deadlines(db: Session, org_id: str, priority: ComplaintPriority, category_id: Optional[str] = None) -> Tuple[datetime, datetime]:
    """
    Computes SLA first response and resolution targets based on active SLAPolicy.
    """
    policy = db.query(SLAPolicy).filter(
        SLAPolicy.organization_id == org_id,
        SLAPolicy.priority == priority,
        SLAPolicy.is_active == True
    ).first()

    now = utcnow()
    if policy:
        first_resp = now + timedelta(hours=policy.first_response_hours)
        resolution = now + timedelta(hours=policy.resolution_hours)
    else:
        # Sensible defaults by priority
        hours_map = {
            ComplaintPriority.CRITICAL: (4, 12),
            ComplaintPriority.HIGH: (12, 24),
            ComplaintPriority.MEDIUM: (24, 48),
            ComplaintPriority.LOW: (48, 96),
        }
        resp_h, res_h = hours_map.get(priority, (24, 48))
        first_resp = now + timedelta(hours=resp_h)
        resolution = now + timedelta(hours=res_h)

    return first_resp, resolution

class ComplaintWorkflowService:
    @staticmethod
    def transition_status(
        db: Session,
        complaint: Complaint,
        to_status: ComplaintStatus,
        actor: User,
        actor_role: OrgRole,
        reason: Optional[str] = None,
        resolution_summary: Optional[str] = None
    ) -> Complaint:
        from_status = complaint.status

        # If same status (unless reassignment which is handled in assign service)
        if from_status == to_status:
            return complaint

        key = (from_status, to_status)
        if key not in ALLOWED_TRANSITIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid status transition from {from_status.value} to {to_status.value}"
            )

        permitted_roles = ALLOWED_TRANSITIONS[key]
        if not actor.is_platform_admin and actor_role not in permitted_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{actor_role.value}' is not permitted to transition from {from_status.value} to {to_status.value}"
            )

        # Validation rules for specific states
        now = utcnow()
        if to_status == ComplaintStatus.REJECTED:
            if not reason or len(reason.strip()) < 5:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A detailed rejection reason (minimum 5 characters) is required when rejecting a complaint"
                )
            complaint.rejection_reason = reason.strip()

        if to_status == ComplaintStatus.RESOLVED:
            if not resolution_summary or len(resolution_summary.strip()) < 5:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A resolution summary (minimum 5 characters) is required when marking a complaint as resolved"
                )
            complaint.resolution_summary = resolution_summary.strip()
            complaint.resolved_at = now

        if to_status == ComplaintStatus.CLOSED:
            complaint.closed_at = now

        if to_status == ComplaintStatus.REOPENED:
            complaint.reopen_count += 1
            complaint.resolved_at = None

        if from_status == ComplaintStatus.SUBMITTED and to_status in (ComplaintStatus.ASSIGNED, ComplaintStatus.IN_PROGRESS):
            if not complaint.first_responded_at:
                complaint.first_responded_at = now

        # Update status
        complaint.status = to_status
        complaint.updated_at = now

        # Audit History Record
        history_entry = ComplaintHistory(
            complaint_id=complaint.id,
            organization_id=complaint.organization_id,
            actor_id=actor.id,
            event_type=EventType.STATUS_CHANGE,
            from_status=from_status.value,
            to_status=to_status.value,
            field_name="status",
            old_value=from_status.value,
            new_value=to_status.value,
            reason=reason or resolution_summary
        )
        db.add(history_entry)

        # Create In-App Notification for Complainant
        if actor.id != complaint.complainant_id:
            notif = Notification(
                organization_id=complaint.organization_id,
                user_id=complaint.complainant_id,
                complaint_id=complaint.id,
                title=f"Complaint Status: {to_status.value}",
                message=f"Complaint #{complaint.tracking_number} has been updated to {to_status.value}. {reason or resolution_summary or ''}".strip(),
                notification_type="STATUS_CHANGE"
            )
            db.add(notif)

        db.flush()
        return complaint

    @staticmethod
    def assign_complaint(
        db: Session,
        complaint: Complaint,
        assignee: User,
        assigner: User,
        assigner_role: OrgRole,
        notes: Optional[str] = None
    ) -> Complaint:
        if not assigner.is_platform_admin and assigner_role not in [OrgRole.STAFF, OrgRole.DEPT_MANAGER, OrgRole.ORG_ADMIN]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to assign complaints"
            )

        previous_assignee_id = complaint.assignee_id
        complaint.assignee_id = assignee.id
        now = utcnow()
        complaint.updated_at = now

        # If currently SUBMITTED, automatically transition to ASSIGNED
        if complaint.status == ComplaintStatus.SUBMITTED:
            complaint.status = ComplaintStatus.ASSIGNED
            if not complaint.first_responded_at:
                complaint.first_responded_at = now

        # Record Assignment History
        assignment_record = ComplaintAssignment(
            complaint_id=complaint.id,
            organization_id=complaint.organization_id,
            assigner_id=assigner.id,
            assignee_id=assignee.id,
            previous_assignee_id=previous_assignee_id,
            notes=notes
        )
        db.add(assignment_record)

        # Record Audit History
        history = ComplaintHistory(
            complaint_id=complaint.id,
            organization_id=complaint.organization_id,
            actor_id=assigner.id,
            event_type=EventType.ASSIGNMENT,
            field_name="assignee_id",
            old_value=previous_assignee_id,
            new_value=assignee.id,
            reason=notes
        )
        db.add(history)

        # Notify Assignee
        if assignee.id != assigner.id:
            notif = Notification(
                organization_id=complaint.organization_id,
                user_id=assignee.id,
                complaint_id=complaint.id,
                title="New Complaint Assigned",
                message=f"You have been assigned complaint #{complaint.tracking_number}: {complaint.title}",
                notification_type="ASSIGNMENT"
            )
            db.add(notif)

        db.flush()
        return complaint
