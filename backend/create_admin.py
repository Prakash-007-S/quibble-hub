import os
import sys
import argparse
import getpass
from pathlib import Path

# Ensure backend root is on sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.db.session import SessionLocal
from app.models.entities import User, Organization, Membership
from app.models.enums import OrgRole
from app.core.security import get_password_hash

def create_or_update_admin(email: str, full_name: str, password: str, org_slug: str = None):
    db = SessionLocal()
    try:
        clean_email = email.strip().lower()
        if not clean_email or "@" not in clean_email:
            print("[!] Error: A valid email address is required.")
            sys.exit(1)

        if not password or len(password) < 8:
            print("[!] Error: Password must be at least 8 characters long.")
            sys.exit(1)

        hashed = get_password_hash(password)
        user = db.query(User).filter(User.email == clean_email).first()

        if user:
            print(f"[*] User '{clean_email}' already exists. Updating password and granting admin rights...")
            user.hashed_password = hashed
            user.is_platform_admin = True
            user.full_name = full_name or user.full_name
            user.is_active = True
        else:
            print(f"[*] Creating new platform administrator '{clean_email}'...")
            user = User(
                email=clean_email,
                full_name=full_name or "System Administrator",
                hashed_password=hashed,
                is_platform_admin=True,
                is_active=True
            )
            db.add(user)
            db.flush()

        # Link to organization if specified or available
        if org_slug:
            org = db.query(Organization).filter(Organization.slug == org_slug).first()
            if org:
                mem = db.query(Membership).filter(
                    Membership.user_id == user.id,
                    Membership.organization_id == org.id
                ).first()
                if not mem:
                    mem = Membership(
                        user_id=user.id,
                        organization_id=org.id,
                        role=OrgRole.ORG_ADMIN,
                        is_active=True
                    )
                    db.add(mem)
                    print(f"[+] Assigned ORG_ADMIN role in organization '{org.name}'.")

        db.commit()
        print(f"[+] Administrator '{clean_email}' configured successfully!")
        print(f"[+] Platform Admin: True")
        print(f"[+] Password securely hashed with bcrypt.")
    except Exception as e:
        db.rollback()
        print(f"[!] Database error: {e}")
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create or update administrator account for Complaint Management System")
    parser.add_argument("--email", help="Administrator email address")
    parser.add_argument("--name", help="Administrator full name")
    parser.add_argument("--password", help="Administrator password (optional, prompted interactively if omitted)")
    parser.add_argument("--org", help="Optional organization slug to link (e.g. apex-engineering)")

    args = parser.parse_args()

    email = args.email or os.environ.get("ADMIN_EMAIL")
    if not email:
        email = input("Enter Administrator Email: ").strip()

    name = args.name or os.environ.get("ADMIN_NAME")
    if not name:
        name = input("Enter Administrator Full Name [System Administrator]: ").strip() or "System Administrator"

    password = args.password or os.environ.get("ADMIN_PASSWORD")
    if not password:
        password = getpass.getpass("Enter Administrator Password (min 8 chars): ")
        password_confirm = getpass.getpass("Confirm Administrator Password: ")
        if password != password_confirm:
            print("[!] Error: Passwords do not match.")
            sys.exit(1)

    create_or_update_admin(email, name, password, args.org)
