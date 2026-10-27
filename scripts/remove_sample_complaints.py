import os
import sys
from pathlib import Path

# Set backend root
BACKEND_DIR = Path(__file__).resolve().parent.parent / "backend"
sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal
from app.models.entities import (
    Complaint, ComplaintHistory, ComplaintComment, ComplaintAssignment,
    ComplaintFeedback, ComplaintAttachment, Notification, AISuggestion
)

def remove_sample_complaints(include_user_test_submission=True):
    db = SessionLocal()
    print("[*] Inspecting database for sample, demo, and test complaints...")

    try:
        # Identify sample, demo, and test complaints
        all_complaints = db.query(Complaint).all()
        to_delete = []

        for c in all_complaints:
            # 1. Standard seed complaints
            if c.tracking_number.startswith("APX-2026-000"):
                to_delete.append(c)
            # 2. Automated test suite complaints
            elif (
                c.tracking_number.startswith("APX-OVERDUE-")
                or c.tracking_number.startswith("TEST-")
                or "Concurrent Load Test" in (c.title or "")
                or "Timetable Overlap" in (c.title or "")
                or "Air Quality Sensor" in (c.title or "")
                or "Emergency Generator Oil Leak" in (c.title or "")
            ):
                to_delete.append(c)
            # 3. Test typing keystrokes (e.g. 'heuwheheh')
            elif include_user_test_submission and (c.title == "heuwheheh" or c.tracking_number == "APE-2026-B8487A"):
                to_delete.append(c)

        print(f"[*] Found {len(to_delete)} sample/demo/test complaint records to clean up.")

        deleted_ids = [c.id for c in to_delete]
        if not deleted_ids:
            print("[+] No sample complaints found. Database is already clean.")
            return

        # Delete associated child records safely
        hist_count = db.query(ComplaintHistory).filter(ComplaintHistory.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        comm_count = db.query(ComplaintComment).filter(ComplaintComment.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        asgn_count = db.query(ComplaintAssignment).filter(ComplaintAssignment.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        fb_count = db.query(ComplaintFeedback).filter(ComplaintFeedback.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        att_count = db.query(ComplaintAttachment).filter(ComplaintAttachment.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        notif_count = db.query(Notification).filter(Notification.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)
        ai_count = db.query(AISuggestion).filter(AISuggestion.complaint_id.in_(deleted_ids)).delete(synchronize_session=False)

        # Delete complaint records
        comp_count = db.query(Complaint).filter(Complaint.id.in_(deleted_ids)).delete(synchronize_session=False)

        db.commit()

        print(f"[+] Successfully removed {comp_count} sample/demo complaints from PostgreSQL.")
        print(f"    - Child records deleted: {hist_count} history, {comm_count} comments, {asgn_count} assignments, {fb_count} feedback, {notif_count} notifications, {ai_count} AI suggestions.")
        print("[+] User accounts, organizations, departments, categories, and SLA policies remain 100% intact.")

    except Exception as e:
        db.rollback()
        print(f"[!] Error during complaint cleanup: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    remove_sample_complaints()
