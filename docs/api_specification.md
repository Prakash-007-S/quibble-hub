# REST API Specification & Endpoint Catalog
## Universal Complaint Management System (`/api/v1`)

---

## 1. Global Request & Response Conventions

### Base URL
- Local Backend: `http://localhost:8000/api/v1`
- Android Emulator Host: `http://10.0.2.2:8000/api/v1`
- OpenAPI Documentation: `http://localhost:8000/docs`
- Raw OpenAPI JSON: `http://localhost:8000/api/v1/openapi.json`

### Authentication & Tenant Headers
All protected endpoints require:
1. `Authorization: Bearer <jwt_access_token>`
2. `X-Organization-Id: <uuid_of_active_tenant>` (Required for all tenant-scoped resources)

### Standard Error Envelope
All client and server errors conform to:
```json
{
  "detail": "Descriptive human-readable explanation of error"
}
```

---

## 2. Authentication Router (`/api/v1/auth`)

| Method | Endpoint | Access | Description |
|---|---|---|---|
| `POST` | `/auth/register` | Public | Registers a new user account and creates an initial organization or membership. |
| `POST` | `/auth/login` | Public | Validates credentials, issues JWT access token and refresh token session. |
| `POST` | `/auth/refresh` | Public | Exchanges a valid refresh token for a new short-lived access token. |
| `POST` | `/auth/logout` | Authenticated | Revokes the current refresh session. |
| `GET` | `/auth/me` | Authenticated | Returns authenticated user profile, platform admin status, and list of memberships. |

#### Login Request Sample
```json
{
  "email": "student.apex@complaintsystem.org",
  "password": "DemoPass@123"
}
```

#### Login Response Sample
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "c1f7a2d4-3456-4abc-9def-0123456789ab",
    "email": "student.apex@complaintsystem.org",
    "full_name": "Alex Rivera",
    "is_platform_admin": false
  },
  "organizations": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "name": "Sengunthar Engineering College",
      "slug": "apex-engineering",
      "org_type": "COLLEGE",
      "role": "COMPLAINANT"
    }
  ]
}
```

---

## 3. Organizations Router (`/api/v1/organizations`)

| Method | Endpoint | Required Role | Description |
|---|---|---|---|
| `GET` | `/organizations` | Authenticated | Lists all organizations the caller has active membership in. |
| `GET` | `/organizations/{id}` | Member | Returns detailed settings and metadata for the specified organization. |
| `POST` | `/organizations` | Platform Admin | Creates a new tenant organization. |
| `GET` | `/organizations/{id}/members` | Admin / Manager | Lists organization members and their roles. |
| `POST` | `/organizations/{id}/members` | Admin | Adds a user membership to the organization. |

---

## 4. Departments & Categories Routers

### Departments (`/api/v1/departments`)
| Method | Endpoint | Required Role | Description |
|---|---|---|---|
| `GET` | `/departments` | Member | Returns all active departments in caller's active organization. |
| `POST` | `/departments` | Admin | Creates a new department within the tenant. |
| `GET` | `/departments/{id}/members` | Admin / Manager | Lists staff members belonging to a department. |

### Categories (`/api/v1/categories`)
| Method | Endpoint | Required Role | Description |
|---|---|---|---|
| `GET` | `/categories` | Member | Returns all active complaint categories with default routing settings. |
| `POST` | `/categories` | Admin | Creates a new taxonomy category. |

---

## 5. Complaints Router (`/api/v1/complaints`)

| Method | Endpoint | Required Role | Description |
|---|---|---|---|
| `GET` | `/complaints` | Member | Lists complaints filtered by status, priority, department, or search query. |
| `POST` | `/complaints` | Member | Creates a new complaint. Generates unique tracking ID `ORG-YYYY-XXXX`. |
| `GET` | `/complaints/{id}` | Authorized | Fetches complete complaint details, assignees, and permissions. |
| `POST` | `/complaints/{id}/status` | Permitted | Executes a validated state machine transition with audit logging. |
| `POST` | `/complaints/{id}/assign` | Manager / Admin | Assigns or reassigns complaint to a specific department or staff member. |
| `GET` | `/complaints/{id}/comments` | Authorized | Returns conversation trail. Hides internal notes from complainants. |
| `POST` | `/complaints/{id}/comments` | Authorized | Posts public comment or staff internal note. |
| `POST` | `/complaints/{id}/feedback` | Complainant | Records resolution rating (1-5 stars) and user feedback. |
| `POST` | `/complaints/{id}/attachments` | Authorized | Uploads an evidential attachment (MIME & extension validated). |
| `GET` | `/complaints/{id}/attachments/{aid}/download` | Authorized | Securely downloads an authorized attachment. |

#### Create Complaint Request
```json
{
  "title": "Air Conditioner Leaking Water in Room 304",
  "description": "The split unit has been dripping continuously since last night, damaging study desks.",
  "category_id": "99999999-1111-2222-3333-444444444444",
  "department_id": "88888888-1111-2222-3333-444444444444",
  "priority": "HIGH",
  "location_context": "Hostel Block B, Floor 3"
}
```

---

## 6. AI-Assisted Intelligence Router (`/api/v1/ai`)

| Method | Endpoint | Access | Description |
|---|---|---|---|
| `POST` | `/ai/classify` | Member | Analyzes complaint text; returns suggested category, department, priority, and confidence. |
| `POST` | `/ai/duplicates` | Member | Vectorizes complaint title/description; returns similar open cases with cosine similarity scores. |
| `POST` | `/ai/summarize` | Staff / Admin | Generates executive structured summary of complex complaint histories. |

#### AI Classify Response
```json
{
  "suggested_category_id": "99999999-1111-2222-3333-444444444444",
  "suggested_category_name": "Hostel & Facilities",
  "suggested_department_id": "88888888-1111-2222-3333-444444444444",
  "suggested_department_name": "Campus Facilities & Maintenance",
  "suggested_priority": "HIGH",
  "confidence": 0.88,
  "explanation": "Matched key facilities tokens ('leaking', 'air conditioner', 'water').",
  "provider": "local_fallback"
}
```

---

## 7. Analytics & Dashboards Router (`/api/v1/analytics`)

| Method | Endpoint | Required Role | Description |
|---|---|---|---|
| `GET` | `/analytics/dashboard` | Member | Returns role-scoped real-time metrics computed directly from PostgreSQL. |

#### Complainant Metrics Shape:
```json
{
  "total_complaints": 3,
  "submitted": 1,
  "in_progress": 1,
  "awaiting_user": 0,
  "resolved": 1,
  "closed": 0
}
```

#### Org Admin & Manager Metrics Shape:
```json
{
  "total_complaints": 24,
  "open_complaints": 18,
  "resolved_complaints": 6,
  "sla_breaches": 2,
  "average_resolution_hours": 14.5,
  "department_distribution": {
    "Campus IT & Lab Services": 12,
    "Campus Facilities & Maintenance": 8,
    "Academic Affairs": 4
  },
  "priority_distribution": {
    "CRITICAL": 2,
    "HIGH": 7,
    "MEDIUM": 12,
    "LOW": 3
  }
}
```
