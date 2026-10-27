import os
import sys
import pytest
from fastapi.testclient import TestClient

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.main import app
from app.db.session import SessionLocal
from app.models.entities import Organization, User, Membership

@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c

@pytest.fixture(scope="session")
def db_session():
    db = SessionLocal()
    yield db
    db.close()

@pytest.fixture(scope="session")
def apex_org(db_session):
    return db_session.query(Organization).filter(Organization.slug == "apex-engineering").first()

@pytest.fixture(scope="session")
def swift_org(db_session):
    return db_session.query(Organization).filter(Organization.slug == "swift-logistics").first()

@pytest.fixture(scope="session")
def student_token(client, apex_org):
    res = client.post("/api/v1/auth/login", json={
        "email": "student.apex@complaintsystem.org",
        "password": "DemoPass@123",
        "organization_id": apex_org.id
    })
    assert res.status_code == 200, res.text
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def staff_token(client, apex_org):
    res = client.post("/api/v1/auth/login", json={
        "email": "staff.apex@complaintsystem.org",
        "password": "DemoPass@123",
        "organization_id": apex_org.id
    })
    assert res.status_code == 200, res.text
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def manager_token(client, apex_org):
    res = client.post("/api/v1/auth/login", json={
        "email": "manager.apex@complaintsystem.org",
        "password": "DemoPass@123",
        "organization_id": apex_org.id
    })
    assert res.status_code == 200, res.text
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def org_admin_token(client, apex_org):
    res = client.post("/api/v1/auth/login", json={
        "email": "orgadmin.apex@complaintsystem.org",
        "password": "DemoPass@123",
        "organization_id": apex_org.id
    })
    assert res.status_code == 200, res.text
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def platform_admin_token(client):
    res = client.post("/api/v1/auth/login", json={
        "email": "admin@complaintsystem.org",
        "password": "Admin@12345"
    })
    assert res.status_code == 200, res.text
    return res.json()["access_token"]
