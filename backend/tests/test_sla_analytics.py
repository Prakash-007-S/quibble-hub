import pytest
from datetime import datetime, timezone, timedelta
from app.models.entities import Complaint
from app.models.enums import ComplaintStatus
from app.workers.sla_worker import check_sla_breaches_and_escalate

def test_sla_escalation_worker_marks_overdue_complaints(db_session, apex_org):
    # Create an artificially overdue complaint
    now = datetime.now(timezone.utc)
    c_overdue = Complaint(
        tracking_number=f"APX-OVERDUE-{int(now.timestamp())}",
        organization_id=apex_org.id,
        category_id=apex_org.categories[0].id,
        department_id=apex_org.departments[0].id,
        complainant_id=apex_org.memberships[0].user_id,
        title="Emergency Generator Oil Leak",
        description="Overdue resolution test case.",
        status=ComplaintStatus.IN_PROGRESS,
        is_escalated=False,
        sla_resolution_due=now - timedelta(hours=5)
    )
    db_session.add(c_overdue)
    db_session.commit()

    # Run SLA worker
    escalated_count = check_sla_breaches_and_escalate(db_session)
    assert escalated_count >= 1

    db_session.refresh(c_overdue)
    assert c_overdue.is_escalated is True

    # Idempotency: Running worker again should not re-escalate already escalated complaints
    repeat_count = check_sla_breaches_and_escalate(db_session)
    # The count of newly escalated should be 0 unless other unescalated overdue cases exist
    assert repeat_count == 0

def test_dashboard_metrics_for_admin_and_complainant(client, student_token, org_admin_token, apex_org):
    # 1. Complainant view
    comp_res = client.get(
        "/api/v1/analytics/dashboard",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id}
    )
    assert comp_res.status_code == 200
    comp_data = comp_res.json()
    assert comp_data["role"] == "COMPLAINANT"
    assert "total_complaints" in comp_data["metrics"]
    assert comp_data["metrics"]["total_complaints"] >= 0

    # 2. Org Admin view
    admin_res = client.get(
        "/api/v1/analytics/dashboard",
        headers={"Authorization": f"Bearer {org_admin_token}", "X-Organization-ID": apex_org.id}
    )
    assert admin_res.status_code == 200
    admin_data = admin_res.json()
    assert admin_data["role"] == "ORG_ADMIN"
    assert "department_distribution" in admin_data["metrics"]
    assert "category_distribution" in admin_data["metrics"]
    assert admin_data["metrics"]["total_complaints"] >= 0
    assert admin_data["metrics"]["open_complaints"] >= 0
