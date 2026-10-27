from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.db.session import SessionLocal
from app.models.entities import Complaint, ComplaintHistory, Notification, DepartmentMember
from app.models.enums import ComplaintStatus, EventType, OrgRole
from app.core.logging import logger

def check_sla_breaches_and_escalate(db: Session) -> int:
    """
    Idempotent background job:
    1. Finds non-closed complaints past resolution deadline where is_escalated is False.
    2. Marks is_escalated = True.
    3. Creates ComplaintHistory event.
    4. Notifies department leads and managers.
    """
    now = datetime.now(timezone.utc)

    overdue_complaints = db.query(Complaint).filter(
        Complaint.is_escalated == False,
        Complaint.sla_resolution_due < now,
        Complaint.status.notin_([ComplaintStatus.RESOLVED, ComplaintStatus.CLOSED, ComplaintStatus.REJECTED])
    ).all()

    escalated_count = 0
    for complaint in overdue_complaints:
        complaint.is_escalated = True
        complaint.updated_at = now

        # Add history record
        history = ComplaintHistory(
            complaint_id=complaint.id,
            organization_id=complaint.organization_id,
            actor_id=complaint.assignee_id or complaint.complainant_id,
            event_type=EventType.ESCALATION,
            field_name="is_escalated",
            old_value="False",
            new_value="True",
            reason=f"SLA resolution target elapsed ({complaint.sla_resolution_due.isoformat()}). Automatic escalation triggered."
        )
        db.add(history)

        # Find department managers or leads to notify
        dept_leads = db.query(DepartmentMember).filter(
            DepartmentMember.department_id == complaint.department_id,
            DepartmentMember.is_lead == True
        ).all()

        recipient_ids = [dl.user_id for dl in dept_leads]
        if complaint.assignee_id and complaint.assignee_id not in recipient_ids:
            recipient_ids.append(complaint.assignee_id)

        for recipient_id in recipient_ids:
            notif = Notification(
                organization_id=complaint.organization_id,
                user_id=recipient_id,
                complaint_id=complaint.id,
                title=f"ESCALATION ALERT: #{complaint.tracking_number}",
                message=f"Complaint #{complaint.tracking_number} ({complaint.title}) has breached its resolution SLA.",
                notification_type="SLA_BREACH"
            )
            db.add(notif)

        escalated_count += 1

    if overdue_complaints:
        db.commit()
        logger.info(f"[SLA Worker] Escalated {escalated_count} overdue complaints.")

    return escalated_count

if __name__ == "__main__":
    db = SessionLocal()
    try:
        count = check_sla_breaches_and_escalate(db)
        print(f"[+] SLA check completed. Escalated {count} complaints.")
    finally:
        db.close()
