import pytest
from app.models.entities import Complaint

def test_ai_classification_returns_validated_schema(client, student_token, apex_org):
    res = client.post(
        "/api/v1/ai/classify",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={
            "title": "Severe Water Pipe Burst in Block A",
            "description": "The main bathroom pipe has ruptured and is flooding the corridor rapidly."
        }
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert "category_name" in data
    assert "department_name" in data
    assert data["recommended_priority"] in ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    assert data["confidence"] >= 0.5
    assert len(data["explanation"]) > 10
    assert data["is_fallback"] is True
    assert data["provider"] == "local_fallback"

def test_ai_duplicate_detection_finds_similar_complaints(client, student_token, apex_org, db_session):
    existing = db_session.query(Complaint).filter(
        Complaint.organization_id == apex_org.id,
        Complaint.tracking_number == "TEST-APX-DUP-1"
    ).first()
    if not existing:
        from app.models.entities import User
        from app.models.enums import ComplaintStatus, ComplaintPriority
        student = db_session.query(User).filter(User.email == "student.apex@complaintsystem.org").first()
        existing = Complaint(
            tracking_number="TEST-APX-DUP-1",
            organization_id=apex_org.id,
            category_id=apex_org.categories[0].id,
            department_id=apex_org.departments[0].id,
            complainant_id=student.id,
            title="Hostel Block B 3rd Floor Wi-Fi Down for 48 Hours",
            description="The access point on Block B 3rd floor is showing a solid red LED. Students unable to submit work.",
            status=ComplaintStatus.SUBMITTED,
            priority=ComplaintPriority.HIGH
        )
        db_session.add(existing)
        db_session.commit()

    res = client.post(
        "/api/v1/ai/duplicate-check",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={
            "title": "Block B 3rd floor Wi-Fi access point offline",
            "description": "Students in hostel block B cannot connect to the Wi-Fi. Access point red light."
        }
    )
    assert res.status_code == 200, res.text
    data = res.json()
    candidates = data["candidate_duplicates"]
    assert len(candidates) > 0
    top_match = candidates[0]
    assert top_match["tracking_number"] == existing.tracking_number
    assert top_match["similarity_score"] > 0.40

def test_ai_summarization_for_staff(client, staff_token, apex_org, db_session):
    complaint = db_session.query(Complaint).filter(Complaint.organization_id == apex_org.id).first()
    if not complaint:
        from app.models.entities import User, ComplaintComment
        from app.models.enums import ComplaintStatus, ComplaintPriority
        student = db_session.query(User).filter(User.email == "student.apex@complaintsystem.org").first()
        staff = db_session.query(User).filter(User.email == "staff.apex@complaintsystem.org").first()
        complaint = Complaint(
            tracking_number="TEST-APX-SUM-1",
            organization_id=apex_org.id,
            category_id=apex_org.categories[0].id,
            department_id=apex_org.departments[0].id,
            complainant_id=student.id,
            assignee_id=staff.id,
            title="Water Pipe Leakage in Room 204 Bathroom Causing Flooding",
            description="Main valve under washbasin has cracked. Water is leaking into the main hallway.",
            status=ComplaintStatus.IN_PROGRESS,
            priority=ComplaintPriority.CRITICAL
        )
        db_session.add(complaint)
        db_session.flush()
        db_session.add(ComplaintComment(
            complaint_id=complaint.id, organization_id=apex_org.id, user_id=staff.id,
            comment_text="Plumbing vendor contacted. Work order #4492 issued.", is_internal_note=False
        ))
        db_session.commit()

    res = client.get(
        f"/api/v1/ai/complaints/{complaint.id}/summary",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id}
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert "reported_problem" in data
    assert "actions_already_taken" in data
    assert "outstanding_questions" in data
    assert "possible_next_steps" in data
    assert isinstance(data["actions_already_taken"], list)
    assert data["is_fallback"] is True
