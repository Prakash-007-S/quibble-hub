import uuid
import pytest

def test_login_success(client, apex_org):
    res = client.post("/api/v1/auth/login", json={
        "email": "student.apex@complaintsystem.org",
        "password": "DemoPass@123",
        "organization_id": apex_org.id
    })
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"

def test_login_invalid_password(client):
    res = client.post("/api/v1/auth/login", json={
        "email": "student.apex@complaintsystem.org",
        "password": "WrongPassword!999"
    })
    assert res.status_code == 401
    assert "Incorrect email or password" in res.json()["detail"]

def test_register_and_refresh_flow(client, apex_org):
    unique_email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    # 1. Register
    reg_res = client.post("/api/v1/auth/register", json={
        "email": unique_email,
        "full_name": "Test Fresh User",
        "password": "Password@123",
        "organization_id": apex_org.id
    })
    assert reg_res.status_code == 200
    user_data = reg_res.json()
    assert user_data["email"] == unique_email
    assert len(user_data["memberships"]) == 1

    # 2. Login
    login_res = client.post("/api/v1/auth/login", json={
        "email": unique_email,
        "password": "Password@123",
        "organization_id": apex_org.id
    })
    assert login_res.status_code == 200
    tokens = login_res.json()
    refresh_token = tokens["refresh_token"]

    # 3. Refresh Token
    refresh_res = client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token
    })
    assert refresh_res.status_code == 200
    new_tokens = refresh_res.json()
    assert "access_token" in new_tokens
    new_refresh = new_tokens["refresh_token"]

    # 4. Old refresh token should now be revoked
    old_res = client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token
    })
    assert old_res.status_code == 401

    # 5. Logout
    logout_res = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {new_tokens['access_token']}"},
        json={"refresh_token": new_refresh}
    )
    assert logout_res.status_code == 200

    # 6. New refresh token is now revoked
    revoked_res = client.post("/api/v1/auth/refresh", json={
        "refresh_token": new_refresh
    })
    assert revoked_res.status_code == 401

def test_multi_organization_user_me(client):
    login_res = client.post("/api/v1/auth/login", json={
        "email": "multi.user@complaintsystem.org",
        "password": "DemoPass@123"
    })
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    me_res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 200
    me = me_res.json()
    # Must have memberships in both Apex (STAFF) and NovaTech (COMPLAINANT)
    assert len(me["memberships"]) >= 2
    org_slugs = [m["org_slug"] for m in me["memberships"]]
    assert "apex-engineering" in org_slugs
    assert "novatech-corp" in org_slugs

def test_register_cannot_escalate_to_admin(client, apex_org):
    unique_email = f"attacker_{uuid.uuid4().hex[:8]}@example.com"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": unique_email,
        "full_name": "Privilege Escalation Attempt",
        "password": "Password@123",
        "organization_id": apex_org.id,
        "role": "ORG_ADMIN"
    })
    assert reg_res.status_code == 200
    user_data = reg_res.json()
    assert user_data["is_platform_admin"] is False
    assert user_data["memberships"][0]["role"] == "COMPLAINANT"

def test_unauthenticated_access_rejected(client):
    res = client.get("/api/v1/auth/me")
    assert res.status_code == 401
    assert "Not authenticated" in res.json().get("detail", "")

def test_password_stored_as_hash_never_plaintext(client, apex_org, db_session):
    from app.models.entities import User
    unique_email = f"hashcheck_{uuid.uuid4().hex[:8]}@example.com"
    plain_password = "SecretPlaintextPassword!123"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": unique_email,
        "full_name": "Hash Check User",
        "password": plain_password,
        "organization_id": apex_org.id
    })
    assert reg_res.status_code == 200

    db_user = db_session.query(User).filter(User.email == unique_email).first()
    assert db_user is not None
    assert db_user.hashed_password != plain_password
    assert db_user.hashed_password.startswith("$2b$") or len(db_user.hashed_password) > 30
