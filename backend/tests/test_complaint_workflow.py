import pytest
from app.models.entities import Complaint, Category, User
from app.models.enums import ComplaintStatus, ComplaintPriority

def test_complaint_creation_and_tracking_id(client, student_token, apex_org, db_session):
    cat = db_session.query(Category).filter(
        Category.organization_id == apex_org.id,
        Category.name == "Exam Schedule Conflict"
    ).first()

    res = client.post(
        "/api/v1/complaints",
        headers={
            "Authorization": f"Bearer {student_token}",
            "X-Organization-ID": apex_org.id
        },
        json={
            "title": "Timetable Overlap for Final Semester Core Paper",
            "description": "The lab practical exam overlaps with the theoretical assessment on Wednesday morning.",
            "category_id": cat.id,
            "location_context": "Engineering Block Exam Hall 2"
        }
    )
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["tracking_number"].startswith("APE-")
    assert data["status"] == "SUBMITTED"
    assert data["department_name"] == "Academic Affairs"
    assert data["sla_first_response_due"] is not None
    assert data["sla_resolution_due"] is not None

def test_permitted_and_forbidden_lifecycle_transitions(client, student_token, staff_token, manager_token, apex_org, db_session):
    # 1. Create a fresh complaint in ITLab department (where staff.apex is a member)
    cat = db_session.query(Category).filter(
        Category.organization_id == apex_org.id,
        Category.name == "Campus Wi-Fi & Network Outage"
    ).first()
    res = client.post(
        "/api/v1/complaints",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={
            "title": "Air Quality Sensor Failure in Clean Room Lab",
            "description": "Sensor reporting null values preventing safe entry into semiconductor packaging lab.",
            "category_id": cat.id
        }
    )
    assert res.status_code == 201
    cid = res.json()["id"]

    # 2. Forbidden: Complainant cannot directly mark as RESOLVED or CLOSED from SUBMITTED
    res_bad = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "RESOLVED", "resolution_summary": "Resolved myself"}
    )
    assert res_bad.status_code == 400

    # 3. Forbidden: Complainant cannot REJECT a complaint
    res_bad_reject = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "REJECTED", "reason": "No reason"}
    )
    assert res_bad_reject.status_code == 403

    # 4. Valid: Staff transitions SUBMITTED -> ASSIGNED
    res_assigned = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "ASSIGNED", "reason": "Assigned to lab maintenance team"}
    )
    assert res_assigned.status_code == 200
    assert res_assigned.json()["status"] == "ASSIGNED"

    # 5. Valid: Staff transitions ASSIGNED -> IN_PROGRESS
    res_prog = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "IN_PROGRESS", "reason": "Technician disassembling sensor unit"}
    )
    assert res_prog.status_code == 200
    assert res_prog.json()["status"] == "IN_PROGRESS"

    # 6. Rejection of RESOLVED without resolution_summary
    res_no_summary = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "RESOLVED"}
    )
    assert res_no_summary.status_code == 400
    assert "resolution summary" in res_no_summary.json()["detail"].lower()

    # 7. Valid: Staff transitions IN_PROGRESS -> RESOLVED with summary
    res_resolved = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "RESOLVED", "resolution_summary": "Replaced faulty optical sensor diode #82; recalibrated to baseline."}
    )
    assert res_resolved.status_code == 200
    assert res_resolved.json()["status"] == "RESOLVED"
    assert res_resolved.json()["resolved_at"] is not None

    # 8. Valid: Complainant confirms resolution -> CLOSED
    res_closed = client.post(
        f"/api/v1/complaints/{cid}/transition",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        json={"to_status": "CLOSED"}
    )
    assert res_closed.status_code == 200
    assert res_closed.json()["status"] == "CLOSED"

def test_internal_notes_hidden_from_complainant(client, student_token, staff_token, apex_org, db_session):
    from app.models.entities import User, ComplaintComment, DepartmentMember
    staff = db_session.query(User).filter(User.email == "staff.apex@complaintsystem.org").first()
    student = db_session.query(User).filter(User.email == "student.apex@complaintsystem.org").first()
    staff_dept_ids = [dm.department_id for dm in db_session.query(DepartmentMember).filter(DepartmentMember.user_id == staff.id).all()]

    complaint = db_session.query(Complaint).filter(
        Complaint.organization_id == apex_org.id,
        Complaint.department_id.in_(staff_dept_ids)
    ).first()

    if not complaint:
        complaint = Complaint(
            tracking_number="TEST-APX-NOTE-1",
            organization_id=apex_org.id,
            category_id=apex_org.categories[0].id,
            department_id=staff_dept_ids[0],
            complainant_id=student.id,
            assignee_id=staff.id,
            title="Internal Note Test Complaint",
            description="Testing internal note visibility",
            status=ComplaintStatus.IN_PROGRESS,
            priority=ComplaintPriority.MEDIUM
        )
        db_session.add(complaint)
        db_session.flush()

    # Ensure comments exist: one public, one internal
    public_comm = db_session.query(ComplaintComment).filter(ComplaintComment.complaint_id == complaint.id, ComplaintComment.is_internal_note == False).first()
    if not public_comm:
        db_session.add(ComplaintComment(complaint_id=complaint.id, organization_id=apex_org.id, user_id=staff.id, comment_text="Public update for user.", is_internal_note=False))
    internal_comm = db_session.query(ComplaintComment).filter(ComplaintComment.complaint_id == complaint.id, ComplaintComment.is_internal_note == True).first()
    if not internal_comm:
        db_session.add(ComplaintComment(complaint_id=complaint.id, organization_id=apex_org.id, user_id=staff.id, comment_text="Confidential internal note.", is_internal_note=True))
    db_session.commit()

    # 1. Staff views complaint details -> sees both public comment and internal note ($85 invoice note)
    staff_view = client.get(
        f"/api/v1/complaints/{complaint.id}",
        headers={"Authorization": f"Bearer {staff_token}", "X-Organization-ID": apex_org.id}
    )
    assert staff_view.status_code == 200
    staff_comments = staff_view.json()["comments"]
    internal_notes = [c for c in staff_comments if c["is_internal_note"]]
    assert len(internal_notes) > 0

    # 2. Complainant views complaint details -> internal notes MUST BE STRIPPED
    student_view = client.get(
        f"/api/v1/complaints/{complaint.id}",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id}
    )
    assert student_view.status_code == 200
    student_comments = student_view.json()["comments"]
    student_internal_notes = [c for c in student_comments if c["is_internal_note"]]
    assert len(student_internal_notes) == 0

def test_invalid_file_upload_rejected(client, student_token, apex_org, db_session):
    complaint = db_session.query(Complaint).filter(Complaint.organization_id == apex_org.id).first()
    if not complaint:
        from app.models.entities import User
        from app.models.enums import ComplaintStatus, ComplaintPriority
        student = db_session.query(User).filter(User.email == "student.apex@complaintsystem.org").first()
        complaint = Complaint(
            tracking_number="TEST-APX-FILE-1",
            organization_id=apex_org.id,
            category_id=apex_org.categories[0].id,
            department_id=apex_org.departments[0].id,
            complainant_id=student.id,
            title="File Upload Test Complaint",
            description="Testing invalid attachment rejection",
            status=ComplaintStatus.SUBMITTED,
            priority=ComplaintPriority.LOW
        )
        db_session.add(complaint)
        db_session.commit()

    # Upload unauthorized .exe file
    res = client.post(
        f"/api/v1/complaints/{complaint.id}/attachments",
        headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
        files={"file": ("malicious_payload.exe", b"MZbinarycontent", "application/x-msdownload")}
    )
    assert res.status_code == 400
    assert "not permitted" in res.json()["detail"].lower()

def test_concurrent_submissions_unique_tracking_ids(client, student_token, apex_org, db_session):
    import concurrent.futures
    cat = db_session.query(Category).filter(Category.organization_id == apex_org.id).first()

    def submit_one(i):
        return client.post(
            "/api/v1/complaints",
            headers={"Authorization": f"Bearer {student_token}", "X-Organization-ID": apex_org.id},
            json={
                "title": f"Concurrent Load Test Complaint #{i}",
                "description": f"Testing concurrent safe unique identifier generation index #{i}",
                "category_id": cat.id
            }
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        responses = list(executor.map(submit_one, range(10)))

    tracking_numbers = set()
    for r in responses:
        assert r.status_code == 201
        data = r.json()
        assert data["tracking_number"] not in tracking_numbers
        tracking_numbers.add(data["tracking_number"])

    assert len(tracking_numbers) == 10

