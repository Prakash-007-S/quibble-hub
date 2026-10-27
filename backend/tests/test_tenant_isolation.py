import pytest
from app.models.entities import Complaint, Category, Department

def test_cross_tenant_complaint_access_blocked(client, student_token, swift_org, db_session):
    """
    Alex Rivera (Apex Student) attempts to access SwiftLogistics with his Apex token.
    Must be rejected with 403 Forbidden.
    """
    res = client.get(
        "/api/v1/complaints",
        headers={
            "Authorization": f"Bearer {student_token}",
            "X-Organization-ID": swift_org.id
        }
    )
    assert res.status_code == 403
    assert "not an active member of this organization" in res.json()["detail"]

def test_complainant_cannot_view_other_users_complaint_in_same_org(client, apex_org, db_session):
    """
    A complainant cannot view another student's complaint details even in the same tenant.
    """
    # Create another student
    login_res = client.post("/api/v1/auth/register", json={
        "email": "other.student@apex.edu",
        "full_name": "Other Student",
        "password": "Password@123",
        "organization_id": apex_org.id
    })
    login_tok_res = client.post("/api/v1/auth/login", json={
        "email": "other.student@apex.edu",
        "password": "Password@123",
        "organization_id": apex_org.id
    })
    other_token = login_tok_res.json()["access_token"]

    # Target a complaint submitted by student.apex (or create one for isolation test)
    complaint = db_session.query(Complaint).filter(Complaint.organization_id == apex_org.id).first()
    if not complaint:
        from app.models.entities import User
        from app.models.enums import ComplaintStatus, ComplaintPriority
        student = db_session.query(User).filter(User.email == "student.apex@complaintsystem.org").first()
        complaint = Complaint(
            tracking_number="TEST-APX-ISO-1",
            organization_id=apex_org.id,
            category_id=apex_org.categories[0].id,
            department_id=apex_org.departments[0].id,
            complainant_id=student.id,
            title="Isolation Test Complaint",
            description="Testing authorization boundary between students",
            status=ComplaintStatus.SUBMITTED,
            priority=ComplaintPriority.LOW
        )
        db_session.add(complaint)
        db_session.commit()

    # Attempt to view
    res = client.get(
        f"/api/v1/complaints/{complaint.id}",
        headers={
            "Authorization": f"Bearer {other_token}",
            "X-Organization-ID": apex_org.id
        }
    )
    assert res.status_code == 403
    assert "Access denied" in res.json()["detail"]

def test_cannot_create_complaint_with_cross_tenant_category(client, student_token, apex_org, swift_org, db_session):
    """
    Submitting a complaint in Apex with a Category ID belonging to SwiftLogistics
    must fail with 400 Bad Request.
    """
    swift_cat = db_session.query(Category).filter(Category.organization_id == swift_org.id).first()
    assert swift_cat is not None

    res = client.post(
        "/api/v1/complaints",
        headers={
            "Authorization": f"Bearer {student_token}",
            "X-Organization-ID": apex_org.id
        },
        json={
            "title": "Cross Tenant Exploit Attempt",
            "description": "Attempting to inject a foreign organization category.",
            "category_id": swift_cat.id
        }
    )
    assert res.status_code == 400
    assert "Category not found or does not belong to active organization" in res.json()["detail"]

def test_missing_organization_header_rejected(client, student_token):
    """Calling tenant-scoped endpoints without X-Organization-ID must return 400."""
    res = client.get(
        "/api/v1/complaints",
        headers={"Authorization": f"Bearer {student_token}"}
    )
    assert res.status_code == 400
    assert "Missing required X-Organization-ID header" in res.json()["detail"]
