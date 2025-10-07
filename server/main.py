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
from app.routers import auth, pets, ingredients, scans, mfa, monitoring, gdpr, notifications, nutritional_analysis, advanced_nutrition, food_management
from app.api.v1.nutrition import router as nutrition_router
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
    """Application lifespan manager for startup and shutdown events"""
    # Startup
    log_startup(logger, "SniffTest API")
    db_initialized = await init_db()
    if db_initialized:
        logger.info("✅ Database connection established")
    else:
        logger.warning("⚠️  Database initialization failed, but application will continue")
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
    openapi_url="/openapi.json" if settings.debug else None
)

# Add security middleware (order matters!)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(AuditLogMiddleware)
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
app.include_router(auth.router, prefix="/api/v1/auth", tags=["authentication"])
app.include_router(mfa.router, prefix="/api/v1/mfa", tags=["mfa"])
app.include_router(pets.router, prefix="/api/v1/pets", tags=["pets"])
app.include_router(ingredients.router, prefix="/api/v1/ingredients", tags=["ingredients"])
app.include_router(scans.router, prefix="/api/v1/scans", tags=["scans"])
app.include_router(monitoring.router, prefix="/api/v1/monitoring", tags=["monitoring"])
app.include_router(gdpr.router, prefix="/api/v1/gdpr", tags=["gdpr"])
app.include_router(notifications.router, prefix="/api/v1", tags=["notifications"])
app.include_router(nutritional_analysis.router, prefix="/api/v1", tags=["nutritional-analysis"])
app.include_router(nutrition_router, prefix="/api/v1", tags=["nutrition"])
app.include_router(advanced_nutrition.router, prefix="/api/v1", tags=["advanced-nutrition"])
app.include_router(food_management.router, prefix="/api/v1", tags=["food-management"])

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "SniffTest API is running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """Detailed health check endpoint"""
    from app.database import get_connection_stats
    
    db_stats = get_connection_stats()
    
    return {
        "status": "healthy" if db_stats.get("status") == "connected" else "degraded",
        "database": db_stats,
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
