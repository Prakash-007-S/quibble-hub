from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.db.session import get_db
from app.models.entities import Notification
from app.schemas import NotificationResponse
from app.api.deps import get_tenant_context, TenantContext

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("", response_model=List[NotificationResponse])
def get_notifications(
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    """Fetches user notifications within the active organization"""
    notifs = db.query(Notification).filter(
        Notification.organization_id == ctx.org_id,
        Notification.user_id == ctx.user_id
    ).order_by(desc(Notification.created_at)).limit(50).all()
    return notifs

@router.patch("/{notif_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notif_id: str,
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    notif = db.query(Notification).filter(
        Notification.id == notif_id,
        Notification.organization_id == ctx.org_id,
        Notification.user_id == ctx.user_id
    ).first()

    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif

@router.post("/read-all")
def mark_all_notifications_read(
    ctx: TenantContext = Depends(get_tenant_context),
    db: Session = Depends(get_db)
):
    db.query(Notification).filter(
        Notification.organization_id == ctx.org_id,
        Notification.user_id == ctx.user_id,
        Notification.is_read == False
    ).update({"is_read": True})
    db.commit()
    return {"detail": "All notifications marked as read"}
