import os
import sys
from datetime import datetime, timedelta, timezone

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(__file__))

from app.db.session import SessionLocal
from app.core.security import get_password_hash
from app.models.enums import (
    OrgType, OrgRole, ComplaintStatus, ComplaintPriority,
    EventType, AISuggestionType
)
from app.models.entities import (
    Organization, User, Membership, Department, DepartmentMember,
    Category, Complaint, ComplaintAssignment, ComplaintComment,
    ComplaintHistory, SLAPolicy, Notification, ComplaintFeedback,
    AISuggestion
)

def utcnow():
    return datetime.now(timezone.utc)

def seed():
    db = SessionLocal()
    print("[*] Starting database seed...")

    try:
        # Check if already seeded
        existing_org = db.query(Organization).filter(Organization.slug == "apex-engineering").first()
        if existing_org:
            print("[+] Seed data already present. Skipping.")
            return

        # 1. Create Users
        default_pwd_hash = get_password_hash("DemoPass@123")
        admin_pwd_hash = get_password_hash("Admin@12345")

        users_data = [
            {"email": "admin@complaintsystem.org", "full_name": "System Platform Admin", "pwd": admin_pwd_hash, "is_admin": True},
            {"email": "orgadmin.apex@complaintsystem.org", "full_name": "Dr. Sarah Jenkins (Apex Admin)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "manager.apex@complaintsystem.org", "full_name": "Prof. David Miller (Apex Dept Mgr)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "staff.apex@complaintsystem.org", "full_name": "Emily Watson (Apex IT & Hostel Staff)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "student.apex@complaintsystem.org", "full_name": "Alex Rivera (Apex Student)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "multi.user@complaintsystem.org", "full_name": "Marcus Chen (Dual Org Member)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "orgadmin.swift@complaintsystem.org", "full_name": "Rachel Zane (SwiftLogistics Admin)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "staff.swift@complaintsystem.org", "full_name": "Carlos Gomez (Swift Handler)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "customer.swift@complaintsystem.org", "full_name": "Priya Sharma (Retail Customer)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "orgadmin.metro@complaintsystem.org", "full_name": "Commissioner Robert Vance (Metro Admin)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "staff.metro@complaintsystem.org", "full_name": "Inspector Harold Finch (Metro Field Staff)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "citizen.metro@complaintsystem.org", "full_name": "Michael Scott (Local Resident)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "orgadmin.nova@complaintsystem.org", "full_name": "Elena Rostova (NovaTech VP Ops)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "staff.nova@complaintsystem.org", "full_name": "Vikram Patel (NovaTech Helpdesk)", "pwd": default_pwd_hash, "is_admin": False},
            {"email": "employee.nova@complaintsystem.org", "full_name": "Samantha Reed (NovaTech Staff)", "pwd": default_pwd_hash, "is_admin": False},
        ]

        users = {}
        for u in users_data:
            user = User(
                email=u["email"],
                full_name=u["full_name"],
                hashed_password=u["pwd"],
                is_platform_admin=u["is_admin"]
            )
            db.add(user)
            users[u["email"]] = user
        db.flush()

        # 2. Create 4 Organizations
        orgs_data = [
            {
                "name": "Sengunthar Engineering College",
                "slug": "apex-engineering",
                "org_type": OrgType.COLLEGE,
                "settings": {"ai_enabled": True, "auto_assign": True, "domain": "sengunthar.edu"}
            },
            {
                "name": "SwiftLogistics Express Deliveries",
                "slug": "swift-logistics",
                "org_type": OrgType.BUSINESS,
                "settings": {"ai_enabled": True, "auto_assign": False, "support_phone": "+1-800-555-0199"}
            },
            {
                "name": "Metro Municipal Water & Sanitation Authority",
                "slug": "metro-water",
                "org_type": OrgType.PUBLIC_SERVICE,
                "settings": {"ai_enabled": True, "public_portal": True, "emergency_hotline": "1916"}
            },
            {
                "name": "NovaTech Enterprise Solutions Inc.",
                "slug": "novatech-corp",
                "org_type": OrgType.CORPORATE,
                "settings": {"ai_enabled": True, "confidential_grievance": True}
            }
        ]

        orgs = {}
        for o in orgs_data:
            org = Organization(
                name=o["name"],
                slug=o["slug"],
                org_type=o["org_type"],
                settings=o["settings"]
            )
            db.add(org)
            orgs[o["slug"]] = org
        db.flush()

        # 3. Create Memberships
        memberships_data = [
            # Apex Members
            (users["orgadmin.apex@complaintsystem.org"].id, orgs["apex-engineering"].id, OrgRole.ORG_ADMIN),
            (users["manager.apex@complaintsystem.org"].id, orgs["apex-engineering"].id, OrgRole.DEPT_MANAGER),
            (users["staff.apex@complaintsystem.org"].id, orgs["apex-engineering"].id, OrgRole.STAFF),
            (users["student.apex@complaintsystem.org"].id, orgs["apex-engineering"].id, OrgRole.COMPLAINANT),
            (users["multi.user@complaintsystem.org"].id, orgs["apex-engineering"].id, OrgRole.STAFF),
            # SwiftLogistics Members
            (users["orgadmin.swift@complaintsystem.org"].id, orgs["swift-logistics"].id, OrgRole.ORG_ADMIN),
            (users["staff.swift@complaintsystem.org"].id, orgs["swift-logistics"].id, OrgRole.STAFF),
            (users["customer.swift@complaintsystem.org"].id, orgs["swift-logistics"].id, OrgRole.COMPLAINANT),
            # Metro Water Members
            (users["orgadmin.metro@complaintsystem.org"].id, orgs["metro-water"].id, OrgRole.ORG_ADMIN),
            (users["staff.metro@complaintsystem.org"].id, orgs["metro-water"].id, OrgRole.STAFF),
            (users["citizen.metro@complaintsystem.org"].id, orgs["metro-water"].id, OrgRole.COMPLAINANT),
            # NovaTech Members
            (users["orgadmin.nova@complaintsystem.org"].id, orgs["novatech-corp"].id, OrgRole.ORG_ADMIN),
            (users["staff.nova@complaintsystem.org"].id, orgs["novatech-corp"].id, OrgRole.STAFF),
            (users["employee.nova@complaintsystem.org"].id, orgs["novatech-corp"].id, OrgRole.COMPLAINANT),
            (users["multi.user@complaintsystem.org"].id, orgs["novatech-corp"].id, OrgRole.COMPLAINANT),
        ]

        for uid, oid, role in memberships_data:
            mem = Membership(user_id=uid, organization_id=oid, role=role)
            db.add(mem)
        db.flush()

        # 4. Create Departments
        depts_data = [
            # Apex
            (orgs["apex-engineering"].id, "Academic Affairs", "ACAD", "Curriculum, exams, evaluations, grading queries"),
            (orgs["apex-engineering"].id, "Hostel & Facilities", "HOST", "Dormitory maintenance, plumbing, mess, power"),
            (orgs["apex-engineering"].id, "IT & Computer Labs", "ITLAB", "Campus Wi-Fi, lab equipment, portal access"),
            (orgs["apex-engineering"].id, "Finance & Scholarships", "FIN", "Fee payments, receipts, scholarship aid"),
            # SwiftLogistics
            (orgs["swift-logistics"].id, "Customer Delivery & Dispatch", "DELV", "Shipment delays, tracking, courier dispatch"),
            (orgs["swift-logistics"].id, "Billing & Refund Disputes", "BILL", "Overcharges, refunds, tax invoices"),
            # Metro Water
            (orgs["metro-water"].id, "Pipeline Maintenance & Leakage", "PIPE", "Burst pipes, low pressure, municipal line fixes"),
            (orgs["metro-water"].id, "Water Quality & Sanitation", "QUAL", "Turbidity, chlorination, contamination reports"),
            # NovaTech
            (orgs["novatech-corp"].id, "Enterprise IT Helpdesk", "ITSP", "Laptops, VPN, cloud credentials, security tokens"),
            (orgs["novatech-corp"].id, "HR & Workplace Operations", "HRWR", "Benefits, workplace policy, grievance redressal"),
        ]

        depts = {}
        for oid, name, code, desc in depts_data:
            d = Department(organization_id=oid, name=name, code=code, description=desc)
            db.add(d)
            depts[f"{oid}_{code}"] = d
        db.flush()

        # Link Department Members
        # Emily Watson is member of Hostel and ITLab at Apex
        db.add(DepartmentMember(department_id=depts[f"{orgs['apex-engineering'].id}_ACAD"].id, user_id=users["manager.apex@complaintsystem.org"].id, is_lead=True))
        db.add(DepartmentMember(department_id=depts[f"{orgs['apex-engineering'].id}_ITLAB"].id, user_id=users["staff.apex@complaintsystem.org"].id, is_lead=False))
        db.add(DepartmentMember(department_id=depts[f"{orgs['apex-engineering'].id}_HOST"].id, user_id=users["staff.apex@complaintsystem.org"].id, is_lead=False))
        db.add(DepartmentMember(department_id=depts[f"{orgs['swift-logistics'].id}_DELV"].id, user_id=users["staff.swift@complaintsystem.org"].id, is_lead=False))
        db.add(DepartmentMember(department_id=depts[f"{orgs['metro-water'].id}_PIPE"].id, user_id=users["staff.metro@complaintsystem.org"].id, is_lead=False))
        db.add(DepartmentMember(department_id=depts[f"{orgs['novatech-corp'].id}_ITSP"].id, user_id=users["staff.nova@complaintsystem.org"].id, is_lead=False))
        db.flush()

        # 5. Create Categories
        cats_data = [
            # Apex
            (orgs["apex-engineering"].id, depts[f"{orgs['apex-engineering'].id}_ACAD"].id, "Exam Schedule Conflict", "Overlap of semester end exams", ComplaintPriority.HIGH),
            (orgs["apex-engineering"].id, depts[f"{orgs['apex-engineering'].id}_HOST"].id, "Hostel Plumbing / Water Shortage", "Leakage or supply cut in hostel blocks", ComplaintPriority.HIGH),
            (orgs["apex-engineering"].id, depts[f"{orgs['apex-engineering'].id}_ITLAB"].id, "Campus Wi-Fi & Network Outage", "Dorm or classroom Wi-Fi connectivity", ComplaintPriority.MEDIUM),
            (orgs["apex-engineering"].id, depts[f"{orgs['apex-engineering'].id}_FIN"].id, "Tuition Fee Reconciliation", "Payment deducted but receipt not issued", ComplaintPriority.MEDIUM),
            # Swift
            (orgs["swift-logistics"].id, depts[f"{orgs['swift-logistics'].id}_DELV"].id, "Delayed Delivery / Stuck in Transit", "Package not moving past hub", ComplaintPriority.MEDIUM),
            (orgs["swift-logistics"].id, depts[f"{orgs['swift-logistics'].id}_DELV"].id, "Damaged or Tampered Consignment", "Broken seal or crushed contents", ComplaintPriority.HIGH),
            # Metro
            (orgs["metro-water"].id, depts[f"{orgs['metro-water'].id}_PIPE"].id, "Severe Pipeline Leak / Road Flooding", "Water main pipe ruptured on public street", ComplaintPriority.CRITICAL),
            (orgs["metro-water"].id, depts[f"{orgs['metro-water'].id}_QUAL"].id, "Discolored / Contaminated Tap Water", "Muddy or smelling municipal water supply", ComplaintPriority.CRITICAL),
            # NovaTech
            (orgs["novatech-corp"].id, depts[f"{orgs['novatech-corp'].id}_ITSP"].id, "Developer Workstation Hardware Failure", "Blue screen or battery failure on dev laptop", ComplaintPriority.HIGH),
            (orgs["novatech-corp"].id, depts[f"{orgs['novatech-corp'].id}_HRWR"].id, "Ergonomic & Facility Grievance", "Workspace lighting, desk, or ventilation", ComplaintPriority.LOW),
        ]

        cats = {}
        for oid, did, name, desc, pri in cats_data:
            c = Category(organization_id=oid, department_id=did, name=name, description=desc, default_priority=pri)
            db.add(c)
            cats[f"{oid}_{name}"] = c
        db.flush()

        # 6. Create SLA Policies
        for oid in [orgs["apex-engineering"].id, orgs["swift-logistics"].id, orgs["metro-water"].id, orgs["novatech-corp"].id]:
            db.add(SLAPolicy(organization_id=oid, priority=ComplaintPriority.CRITICAL, first_response_hours=4, resolution_hours=12, escalation_threshold_hours=8))
            db.add(SLAPolicy(organization_id=oid, priority=ComplaintPriority.HIGH, first_response_hours=12, resolution_hours=24, escalation_threshold_hours=18))
            db.add(SLAPolicy(organization_id=oid, priority=ComplaintPriority.MEDIUM, first_response_hours=24, resolution_hours=48, escalation_threshold_hours=36))
            db.add(SLAPolicy(organization_id=oid, priority=ComplaintPriority.LOW, first_response_hours=48, resolution_hours=96, escalation_threshold_hours=72))
        db.flush()

        db.commit()
        print("[+] Database seeding completed successfully with 4 organizations, 15 users, 10 departments, 10 categories, and SLA policies (Zero sample complaints).")

    except Exception as e:
        db.rollback()
        print(f"[!] Error seeding database: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed()
