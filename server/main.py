"""
SniffTest Backend API
Main FastAPI application with Supabase integration and enhanced security
"""

from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from contextlib import asynccontextmanager
import os
import time
import logging
from dotenv import load_dotenv

from app.database import init_db
from app.api.v1.auth.router import router as auth_router
from app.api.v1.pets.router import router as pets_router
from app.api.v1.ingredients.router import router as ingredients_router
from app.api.v1.scanning.router import router as scans_router
from app.api.v1.food_management.router import router as food_management_router
from app.api.v1.mfa.router import router as mfa_router
from app.api.v1.monitoring.router import router as monitoring_router
from app.api.v1.gdpr.router import router as gdpr_router
from app.api.v1.notifications.router import router as notifications_router
from app.api.v1.nutritional_analysis.router import router as nutritional_analysis_router
from app.api.v1.advanced_nutrition.router import router as advanced_nutrition_router
from app.api.v1.nutrition import router as nutrition_router
from app.api.v1.data_quality import router as data_quality_router
from app.api.v1.health_events.router import router as health_events_router
from app.core.config import settings
from app.middleware.security import SecurityHeadersMiddleware, RateLimitMiddleware
from app.middleware.audit import AuditLogMiddleware
from app.middleware.request_limits import RequestSizeMiddleware, APIVersionMiddleware, RequestTimeoutMiddleware

# Load environment variables
load_dotenv()

# Configure centralized logging
from app.utils.logging_config import setup_logging, get_logger, log_startup, log_shutdown
setup_logging()
logger = get_logger(__name__)

# Security scheme
security = HTTPBearer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager for startup and shutdown events
    
    Gracefully handles startup failures to ensure health checks can respond
    even if database connection fails
    """
    # Startup
    log_startup(logger, "SniffTest API")
    try:
        db_initialized = await init_db()
        if db_initialized:
            logger.info("✅ Database connection established")
        else:
            logger.warning("⚠️  Database initialization failed, API will run in limited mode")
    except Exception as e:
        logger.error(f"⚠️  Startup error: {e}")
        logger.warning("Application starting in degraded mode - health check will respond but features may be limited")
    
    yield
    
    # Shutdown
    log_shutdown(logger, "SniffTest API")

# Initialize FastAPI app
app = FastAPI(
    title="SniffTest API",
    description="Backend API for pet food ingredient scanning and analysis with enhanced security",
    version=settings.api_version,
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    openapi_url="/openapi.json" if settings.debug else None,
    redirect_slashes=False  # Prevent 307 redirects that can cause Authorization header loss
)

# Add security middleware (order matters!)
# Note: Audit middleware disabled in production to avoid Railway rate limits
app.add_middleware(SecurityHeadersMiddleware)
if settings.environment != "production":
    app.add_middleware(AuditLogMiddleware)  # Only in dev/staging
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestSizeMiddleware)
app.add_middleware(APIVersionMiddleware)
app.add_middleware(RequestTimeoutMiddleware)

# Configure CORS with security
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"]
)

# Add trusted host middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.allowed_hosts
)

# Add compression middleware
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Add error handlers
from app.utils.error_handling import (
    handle_validation_error, 
    handle_http_exception, 
    handle_generic_exception
)

app.add_exception_handler(RequestValidationError, handle_validation_error)
app.add_exception_handler(HTTPException, handle_http_exception)
app.add_exception_handler(Exception, handle_generic_exception)

# Include routers
app.include_router(auth_router, prefix="/api/v1/auth", tags=["authentication"])
app.include_router(mfa_router, prefix="/api/v1/mfa", tags=["mfa"])
app.include_router(pets_router, prefix="/api/v1/pets", tags=["pets"])
app.include_router(ingredients_router, prefix="/api/v1/ingredients", tags=["ingredients"])
app.include_router(scans_router, prefix="/api/v1/scanning", tags=["scanning"])
app.include_router(monitoring_router, prefix="/api/v1/monitoring", tags=["monitoring"])
app.include_router(gdpr_router, prefix="/api/v1/gdpr", tags=["gdpr"])
app.include_router(notifications_router, prefix="/api/v1", tags=["notifications"])
app.include_router(nutritional_analysis_router, prefix="/api/v1", tags=["nutritional-analysis"])
app.include_router(nutrition_router, prefix="/api/v1", tags=["nutrition"])
app.include_router(advanced_nutrition_router, prefix="/api/v1", tags=["advanced-nutrition"])
app.include_router(food_management_router, prefix="/api/v1", tags=["food-management"])
app.include_router(data_quality_router, prefix="/api/v1/data-quality", tags=["data-quality"])
app.include_router(health_events_router, prefix="/api/v1", tags=["health-events"])

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "SniffTest API is running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """
    Simple health check endpoint for Railway deployment
    
    Returns basic health status without database dependency to ensure
    health checks pass during initial deployment startup
    """
    return {
        "status": "healthy",
        "version": "1.0.0",
        "service": "SniffTest API"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
