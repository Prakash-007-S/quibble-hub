# Technical Architecture Specification
## Universal Complaint Management System

---

## 1. Executive Architecture Summary

The **Universal Complaint Management System** is engineered as a high-integrity, multi-tenant grievance management platform designed to cater to four distinct institutional domains:
1. **Colleges & Universities** (`COLLEGE`) — Campus labs, academics, hostels, examinations.
2. **Commercial & Customer-Facing Enterprises** (`BUSINESS`) — Delivery, logistics, refunds, product quality.
3. **Municipalities & Public Service Authorities** (`PUBLIC_SERVICE`) — Roads, sanitation, electricity, water boards.
4. **Corporate Workplaces** (`CORPORATE`) — IT support, facilities, HR workplace ethics, security.

### Core Architectural Pillars
- **Zero-Trust Multi-Tenancy:** Isolation enforced via composite foreign keys, tenant context dependencies (`X-Organization-Id`), and strict organization boundary checks.
- **Strict State Machine Workflow:** Deterministic lifecycle with 8 valid statuses, explicit forbidden transitions, transaction-isolated audit logging, and automated SLA breach escalation.
- **Dual AI Engine:** Pluggable AI architecture supporting Google Gemini / OpenAI with an honest, zero-dependency local NLP fallback (TF-IDF cosine similarity and pattern heuristic classifiers).
- **Modern Mobile & Desktop Frontend:** Feature-first Flutter client adhering to Material 3 design tokens, platform-adaptive networking (Android emulator `10.0.2.2`, physical LAN, or `127.0.0.1` web/desktop), and role-tailored reactive dashboards.

---

## 2. System Architecture Diagram

```mermaid
graph TB
    subgraph ClientLayer ["Client Presentation Tier (Flutter 3.x)"]
        UI_Complainant["Complainant Portal\n(Filing, Tracking, Feedback)"]
        UI_Staff["Staff Queue\n(Investigation, Internal Notes, Resolution)"]
        UI_Manager["Dept Manager & Org Admin\n(Routing, SLAs, Real-time Analytics)"]
        UI_Platform["Platform Admin\n(Cross-Org Governance)"]
    end

    subgraph NetworkLayer ["Networking & Ingress"]
        APIClient["Typed API Client\n(Token Refresh, Error Handler, Tenant Header)"]
    end

    subgraph APILayer ["FastAPI Monolith Backend (Port 8000)"]
        RouterAuth["/api/v1/auth\n(JWT, Refresh Sessions)"]
        RouterOrgs["/api/v1/organizations\n(Tenants & Memberships)"]
        RouterDepts["/api/v1/departments\n(Queues & Staff)"]
        RouterCats["/api/v1/categories\n(Taxonomy & Routing)"]
        RouterComplaints["/api/v1/complaints\n(CRUD, Transitions, Comments)"]
        RouterNotifications["/api/v1/notifications\n(In-app feeds)"]
        RouterAnalytics["/api/v1/analytics\n(PostgreSQL Aggregates)"]
        RouterAI["/api/v1/ai\n(Classification, Duplicates, Summaries)"]

        subgraph MiddlewarePipeline ["Security & Tenant Guards"]
            AuthGuard["Bearer Token JWT Decoder"]
            TenantGuard["Tenant Membership & Role Validator\n(X-Organization-Id)"]
        end
    end

    subgraph BusinessLogic ["Core Engines & Services"]
        WorkflowEngine["Complaint Workflow Service\n(Atomic State Transitions, Audit Logger)"]
        TrackingGenerator["Safe Concurrency ID Engine\n(ORG-YYYY-XXXX)"]
        SLAWorker["SLA Monitoring & Escalation Daemon\n(Breach Detection, Urgency Escalation)"]
        AIEngine["AI Provider Abstraction\n(Gemini 1.5 / OpenAI / Local NLP)"]
        DuplicateDetector["TF-IDF Cosine Similarity Engine\n(scikit-learn vectorizer)"]
    end

    subgraph DataStorage ["Data & Storage Tier"]
        PostgreSQL[("PostgreSQL 14+\n17 Relational Entities\nComposite Tenant Constraints")]
        FileStore[("Private Attachment Storage\n(MIME validated, non-executable)")]
    end

    UI_Complainant --> APIClient
    UI_Staff --> APIClient
    UI_Manager --> APIClient
    UI_Platform --> APIClient

    APIClient --> AuthGuard
    AuthGuard --> TenantGuard
    TenantGuard --> APILayer

    APILayer --> BusinessLogic
    BusinessLogic --> PostgreSQL
    BusinessLogic --> FileStore
```

---

## 3. Database Entity-Relationship Model (17 Entities)

```mermaid
erDiagram
    ORGANIZATION ||--o{ USER_MEMBERSHIP : "has members"
    ORGANIZATION ||--o{ DEPARTMENT : "defines"
    ORGANIZATION ||--o{ CATEGORY : "defines"
    ORGANIZATION ||--o{ COMPLAINT : "owns"
    ORGANIZATION ||--o{ SLA_POLICY : "configures"
    ORGANIZATION ||--o{ NOTIFICATION : "scopes"

    USER ||--o{ USER_MEMBERSHIP : "holds"
    USER ||--o{ COMPLAINT : "files as complainant"
    USER ||--o{ COMPLAINT_ASSIGNMENT : "receives assignment"
    USER ||--o{ COMPLAINT_COMMENT : "authors"
    USER ||--o{ COMPLAINT_HISTORY : "triggers change"
    USER ||--o{ REFRESH_SESSION : "owns session"
    USER ||--o{ NOTIFICATION : "receives"

    DEPARTMENT ||--o{ DEPARTMENT_MEMBER : "contains"
    DEPARTMENT ||--o{ COMPLAINT : "routed to"
    DEPARTMENT ||--o{ CATEGORY : "default handler for"

    COMPLAINT ||--o{ COMPLAINT_ASSIGNMENT : "tracks assignees"
    COMPLAINT ||--o{ COMPLAINT_COMMENT : "conversation trail"
    COMPLAINT ||--o{ COMPLAINT_ATTACHMENT : "evidential files"
    COMPLAINT ||--o{ COMPLAINT_HISTORY : "immutable audit trail"
    COMPLAINT ||--o{ COMPLAINT_FEEDBACK : "satisfaction rating"
    COMPLAINT ||--o{ AI_SUGGESTION : "ML suggestions"

    ORGANIZATION {
        uuid id PK
        string name
        string slug UK
        enum org_type
        jsonb settings
        boolean is_active
        timestamp created_at
    }

    USER {
        uuid id PK
        string email UK
        string hashed_password
        string full_name
        boolean is_platform_admin
        boolean is_active
        timestamp created_at
    }

    USER_MEMBERSHIP {
        uuid id PK
        uuid organization_id FK
        uuid user_id FK
        enum role
        boolean is_active
    }

    DEPARTMENT {
        uuid id PK
        uuid organization_id FK
        string name
        string code
    }

    CATEGORY {
        uuid id PK
        uuid organization_id FK
        uuid default_department_id FK
        string name
        enum default_priority
    }

    COMPLAINT {
        uuid id PK
        uuid organization_id FK
        string tracking_number UK
        string title
        text description
        enum status
        enum priority
        uuid complainant_id FK
        uuid department_id FK
        uuid assignee_id FK
        uuid category_id FK
        timestamp first_response_deadline
        timestamp resolution_deadline
        boolean is_sla_breached
    }

    COMPLAINT_HISTORY {
        uuid id PK
        uuid complaint_id FK
        uuid actor_id FK
        enum event_type
        enum old_status
        enum new_status
        text notes
        timestamp created_at
    }

    SLA_POLICY {
        uuid id PK
        uuid organization_id FK
        enum priority
        int first_response_hours
        int resolution_hours
        boolean business_hours_only
    }
```

---

## 4. Complaint State Machine

The complaint workflow enforces an immutable state machine where illegal transitions are rejected with HTTP 400 and logged to the security audit trail.

```mermaid
stateDiagram-v2
    [*] --> SUBMITTED : User Submits Complaint

    SUBMITTED --> ASSIGNED : Manager / Auto assigns to Staff
    SUBMITTED --> REJECTED : Admin rejects with reason

    ASSIGNED --> IN_PROGRESS : Handler accepts case
    ASSIGNED --> REJECTED : Out of scope / Invalid policy

    IN_PROGRESS --> AWAITING_USER : Staff requests additional info
    AWAITING_USER --> IN_PROGRESS : User responds with clarification

    IN_PROGRESS --> RESOLVED : Staff logs resolution summary

    RESOLVED --> CLOSED : Complainant confirms or 7-day auto-close
    RESOLVED --> REOPENED : Complainant dissents with valid reason

    REOPENED --> IN_PROGRESS : Staff re-examines grievance

    CLOSED --> [*]
    REJECTED --> [*]
```

### State Transition Validation Matrix
| From Status | Permitted Target Statuses | Authorized Roles | Mandatory Requirements |
|---|---|---|---|
| `SUBMITTED` | `ASSIGNED`, `REJECTED` | `ADMIN`, `MANAGER` | `REJECTED` requires explanation notes. |
| `ASSIGNED` | `IN_PROGRESS`, `ASSIGNED`, `REJECTED` | `STAFF`, `MANAGER`, `ADMIN` | Staff can accept or reassign. |
| `IN_PROGRESS` | `AWAITING_USER`, `RESOLVED`, `ASSIGNED` | `STAFF`, `MANAGER`, `ADMIN` | `RESOLVED` requires resolution summary. |
| `AWAITING_USER` | `IN_PROGRESS` | `COMPLAINANT`, `STAFF`, `ADMIN` | Transition triggered by user clarification. |
| `RESOLVED` | `CLOSED`, `REOPENED` | `COMPLAINANT`, `ADMIN` | `REOPENED` requires user dissatisfaction notes. |
| `REOPENED` | `IN_PROGRESS`, `ASSIGNED` | `STAFF`, `MANAGER`, `ADMIN` | Restarts resolution investigation. |

---

## 5. Multi-Tenant Boundary Enforcement

Isolation is enforced through 3 redundant safety tiers:
1. **Request Ingress Verification:** The `get_current_tenant_membership` FastAPI dependency extracts the `X-Organization-Id` header and asserts that the authenticated user holds an active membership record in that organization.
2. **Repository Composite Scoping:** Every SQL query explicitly scopes queries with `.filter(Entity.organization_id == membership.organization_id)`.
3. **Cross-Tenant Constraint Checks:** When creating a complaint, the backend ensures the selected `category_id` and `department_id` strictly belong to the active tenant. Attempting to mix resources results in HTTP 400 Bad Request.

---

## 6. Dual AI Architecture (Gemini / OpenAI with Offline NLP Fallback)

The AI provider abstraction (`app.ai.provider.AIProvider`) dynamically adapts to configuration:
- **Cloud Mode (`gemini` / `openai`):** When `AI_API_KEY` is provided, requests stream structured JSON prompts to Google Gemini or OpenAI with strict schema validation.
- **Honest Local Fallback Mode (`local_fallback`):** When external keys are absent, the system activates a zero-dependency NLP engine:
  - **Classification:** Uses weighted domain keyword analysis mapped against organization categories and departments.
  - **Duplicate Detection:** Employs `scikit-learn`'s `TfidfVectorizer` to compute pairwise cosine similarity scores against existing complaints in the tenant.
  - **Summarization:** Extracts structured sections (Reported Issue, Evidence, Actions, Outstanding Questions) directly from complaint metadata and comment history.
- **Fail-Safe Guarantee:** All AI operations run defensively. If an external API timeout or rate-limit occurs, the complaint submission succeeds unconditionally with fallback heuristics.
