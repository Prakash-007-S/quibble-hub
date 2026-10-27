from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from app.models.enums import OrgType, OrgRole, ComplaintStatus, ComplaintPriority, EventType

# Auth & User Schemas
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    email: str = Field(..., min_length=3)
    password: str
    organization_id: Optional[str] = None

class RegisterRequest(BaseModel):
    email: str = Field(..., min_length=3)
    full_name: str
    password: str = Field(..., min_length=6)
    organization_id: Optional[str] = None
    role: Optional[OrgRole] = OrgRole.COMPLAINANT

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class MembershipResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    organization_id: str
    organization_name: str
    org_slug: str
    org_type: OrgType
    role: OrgRole
    is_active: bool

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    full_name: str
    is_platform_admin: bool
    memberships: List[MembershipResponse] = []

# Organization Schemas
class OrganizationCreate(BaseModel):
    name: str
    slug: str
    org_type: OrgType = OrgType.COLLEGE
    settings: Optional[Dict[str, Any]] = None

class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
    org_type: OrgType
    settings: Dict[str, Any] = {}
    is_active: bool
    created_at: datetime

# Department Schemas
class DepartmentCreate(BaseModel):
    name: str
    code: str
    description: Optional[str] = None

class DepartmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    organization_id: str
    name: str
    code: str
    description: Optional[str] = None
    is_active: bool

# Category Schemas
class CategoryCreate(BaseModel):
    department_id: str
    name: str
    description: Optional[str] = None
    default_priority: ComplaintPriority = ComplaintPriority.MEDIUM

class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    organization_id: str
    department_id: str
    department_name: Optional[str] = None
    name: str
    description: Optional[str] = None
    default_priority: ComplaintPriority
    is_active: bool

# Complaint Schemas
class ComplaintCreate(BaseModel):
    title: str = Field(..., min_length=5, max_length=255)
    description: str = Field(..., min_length=10)
    category_id: str
    location_context: Optional[str] = None
    priority: Optional[ComplaintPriority] = None

class ComplaintAssignRequest(BaseModel):
    assignee_id: str
    notes: Optional[str] = None

class ComplaintTransitionRequest(BaseModel):
    to_status: ComplaintStatus
    reason: Optional[str] = None
    resolution_summary: Optional[str] = None

class ComplaintCommentCreate(BaseModel):
    comment_text: str = Field(..., min_length=1)
    is_internal_note: bool = False

class ComplaintCommentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    user_name: str
    comment_text: str
    is_internal_note: bool
    created_at: datetime

class ComplaintAttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    filename: str
    file_size: int
    content_type: str
    uploader_id: str
    uploader_name: str
    created_at: datetime

class ComplaintHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    actor_id: str
    actor_name: str
    event_type: EventType
    from_status: Optional[str] = None
    to_status: Optional[str] = None
    field_name: Optional[str] = None
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    reason: Optional[str] = None
    created_at: datetime

class ComplaintFeedbackCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comments: Optional[str] = None
    resolution_satisfactory: bool = True

class ComplaintFeedbackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    rating: int
    comments: Optional[str] = None
    resolution_satisfactory: bool
    created_at: datetime

class ComplaintResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tracking_number: str
    organization_id: str
    category_id: str
    category_name: str
    department_id: str
    department_name: str
    complainant_id: str
    complainant_name: str
    assignee_id: Optional[str] = None
    assignee_name: Optional[str] = None
    title: str
    description: str
    location_context: Optional[str] = None
    status: ComplaintStatus
    priority: ComplaintPriority
    sla_first_response_due: Optional[datetime] = None
    sla_resolution_due: Optional[datetime] = None
    first_responded_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    closed_at: Optional[datetime] = None
    resolution_summary: Optional[str] = None
    rejection_reason: Optional[str] = None
    reopen_count: int
    is_escalated: bool
    created_at: datetime
    updated_at: datetime
    comments_count: int = 0
    attachments_count: int = 0
    feedback: Optional[ComplaintFeedbackResponse] = None

class ComplaintDetailResponse(ComplaintResponse):
    comments: List[ComplaintCommentResponse] = []
    attachments: List[ComplaintAttachmentResponse] = []
    history: List[ComplaintHistoryResponse] = []

class ComplaintListResponse(BaseModel):
    total: int
    page: int
    size: int
    items: List[ComplaintResponse]

# Notification Schemas
class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    message: str
    notification_type: str
    is_read: bool
    complaint_id: Optional[str] = None
    created_at: datetime

# Analytics Schemas
class ComplainantMetrics(BaseModel):
    total_complaints: int
    submitted_count: int
    in_progress_count: int
    awaiting_user_count: int
    resolved_closed_count: int
    recent_activity_count: int

class StaffMetrics(BaseModel):
    assigned_count: int
    unassigned_dept_queue: int
    high_critical_count: int
    overdue_count: int
    awaiting_user_count: int

class OrgAdminMetrics(BaseModel):
    total_complaints: int
    open_complaints: int
    resolved_complaints: int
    department_distribution: Dict[str, int]
    category_distribution: Dict[str, int]
    avg_first_response_hours: float
    avg_resolution_hours: float
    sla_breaches_count: int
    feedback_avg_rating: float
