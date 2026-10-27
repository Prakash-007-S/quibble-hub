# Universal Complaint Management System — Backend API

FastAPI + PostgreSQL + SQLAlchemy backend engine designed for multi-tenant institutional complaint tracking, automated status lifecycle workflows, and SLA metrics.

---

## 1. Architecture & Technology Stack

- **Framework:** FastAPI (Python 3.12 / 3.14 compatible)
- **Database:** PostgreSQL (with `.postgres_data` cluster or standard service)
- **ORM:** SQLAlchemy 2.x
- **Migrations:** Alembic
- **Validation:** Pydantic v2 & Pydantic-Settings
- **Security:** Bcrypt password hashing + PyJWT Bearer Tokens (HS256)
- **Interactive Documentation:** Swagger UI (`/docs`) and ReDoc (`/redoc`)
- **Automated Testing:** Pytest + HTTPX

---

## 2. Directory Structure

```
backend/
├── app/
│   ├── main.py                     # FastAPI application factory & router mounting
│   ├── core/                       # Configuration, logging, and security utilities
│   │   ├── config.py
│   │   ├── security.py             # Bcrypt hashing & JWT token generators
│   │   └── logging.py
│   ├── db/                         # SQLAlchemy session factory
│   │   └── session.py
│   ├── models/                     # Relational database models (17 entities)
│   │   ├── entities.py
│   │   └── enums.py
│   ├── schemas/                    # Pydantic request & response validation schemas
│   ├── api/                        # Versioned REST API endpoints
│   │   ├── deps.py                 # Tenant isolation & RBAC dependency injection
│   │   └── v1/
│   │       ├── auth.py             # Login, register, refresh, me, logout
│   │       ├── complaints.py       # Submit, list, detail, transitions, comments
│   │       ├── organizations.py    # Public tenant listings
│   │       ├── departments.py      # Department directory
│   │       ├── categories.py       # Category catalogs & SLA defaults
│   │       ├── notifications.py    # Real-time user alert queues
│   │       ├── analytics.py        # Dashboards and operational KPIs
│   │       └── ai.py               # AI triage and duplicate detection
│   ├── services/                   # Business logic & workflow state machines
│   │   └── complaint_workflow.py
│   └── workers/                    # SLA escalation background workers
│       └── sla_worker.py
├── alembic/                        # Database migration scripts
├── tests/                          # Automated Pytest test suite (21 unit/integration tests)
├── create_admin.py                 # Dedicated CLI tool to create/reset administrator
├── seed.py                         # Demonstration fixtures (organizations, accounts, catalogs)
├── requirements.txt                # Python dependencies
├── .env.example                    # Template environment variables
└── README.md                       # This guide
```

---

## 3. Quick Start (Windows Setup)

### Step 1: Set Up Python Virtual Environment
Open PowerShell in the `backend` directory:
```powershell
cd d:\complaint_management_app\backend
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Step 2: Configure Environment Variables
Copy `.env.example` to `.env`:
```powershell
Copy-Item .env.example .env
```
Ensure your database connection string in `.env`:
```ini
DATABASE_URL="postgresql+psycopg2://postgres@localhost:5434/complaint_db"
SECRET_KEY="super-secret-key-change-this-in-production"
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=7
```

### Step 3: Start PostgreSQL & Apply Migrations
Start the local PostgreSQL server:
```powershell
python ..\scripts\run_postgres.py --daemon
```
Apply the database migrations:
```powershell
python -m alembic upgrade head
```

### Step 4: Create Administrator Account
Run the dedicated administrator creation script:
```powershell
# Interactive prompt:
python create_admin.py

# Or via command line arguments:
python create_admin.py --email admin@complaintsystem.org --name "System Platform Admin" --password "Admin@12345"
```

### Step 5: Start the FastAPI Server
```powershell
python ..\scripts\run_backend.py
```
Or directly with Uvicorn:
```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
- **API Health:** `http://localhost:8000/api/v1/health`
- **Swagger Documentation:** `http://localhost:8000/docs`
- **ReDoc:** `http://localhost:8000/redoc`

---

## 4. Connecting Android Devices

### USB Connection (via ADB Reverse)
When testing on a physical phone connected over USB:
```cmd
adb reverse tcp:8000 tcp:8000
```
The mobile app connects directly to `http://127.0.0.1:8000/api/v1`.

### Wi-Fi / LAN Connection (Sharing with Other Phones)
1. Ensure the FastAPI server is running with `--host 0.0.0.0`.
2. Find your PC's local Wi-Fi IP address in PowerShell:
   ```powershell
   ipconfig
   ```
   Look for `IPv4 Address` (e.g., `192.168.1.15`).
3. Allow incoming connections through Windows Firewall:
   ```powershell
   New-NetFirewallRule -DisplayName "FastAPI Port 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```
4. On your friend's phone:
   - Tap the **Server** icon in the app header (or tap the offline notification banner).
   - Enter `http://192.168.1.15:8000/api/v1`.
   - Tap **Test Connection** -> **Save & Apply**.

---

## 5. Running Automated Tests

Run the full automated test suite:
```powershell
cd d:\complaint_management_app\backend
python -m pytest -v
```
All 21 unit and integration tests verify:
- Safe registration and exclusion of public admin escalation
- Password hash security (bcrypt)
- Multi-tenant tenant boundary isolation
- Complainant cross-access protection (cannot view or alter other users' records)
- Validated lifecycle transitions (Submitted -> Assigned -> In Progress -> Resolved -> Closed)
- SLA escalation engine and KPI analytics calculations
- AI NLP classification and TF-IDF duplicate detection
