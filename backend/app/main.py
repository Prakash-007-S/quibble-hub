from datetime import datetime, timezone
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.config import settings
from app.core.logging import setup_logging
from app.db.session import get_db
from app.api.v1.auth import router as auth_router
from app.api.v1.organizations import router as orgs_router
from app.api.v1.departments import router as depts_router
from app.api.v1.categories import router as cats_router
from app.api.v1.complaints import router as complaints_router
from app.api.v1.notifications import router as notifs_router
from app.api.v1.analytics import router as analytics_router
from app.api.v1.ai import router as ai_router

setup_logging()

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Universal Complaint Management System with AI-assisted classification, intelligent routing, and resolution tracking.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/api/v1/openapi.json"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API Routers
api_v1 = settings.API_V1_STR
app.include_router(auth_router, prefix=api_v1)
app.include_router(orgs_router, prefix=api_v1)
app.include_router(depts_router, prefix=api_v1)
app.include_router(cats_router, prefix=api_v1)
app.include_router(complaints_router, prefix=api_v1)
app.include_router(notifs_router, prefix=api_v1)
app.include_router(analytics_router, prefix=api_v1)
app.include_router(ai_router, prefix=api_v1)

@app.get("/health", tags=["Health"])
@app.get(f"{api_v1}/health", tags=["Health"])
def health_check(db: Session = Depends(get_db)):
    db_status = "connected"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "database": db_status,
        "ai_provider": settings.AI_PROVIDER,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
