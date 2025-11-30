"""
SniffTest Backend API
Main FastAPI application with Supabase integration and enhanced security
"""

from fastapi import FastAPI, HTTPException, Depends, status, Request, Response
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

from app.core.database import init_db
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
from app.api.v1.advanced_nutrition import router as advanced_nutrition_router
from app.api.v1.nutrition import router as nutrition_router
from app.api.v1.data_quality import router as data_quality_router
from app.api.v1.health_events.router import router as health_events_router
from app.api.v1.waitlist.router import router as waitlist_router
from app.api.v1.subscriptions.revenuecat_webhook import router as revenuecat_webhook_router
from app.core.config import settings
from app.core.middleware import (
    SecurityHeadersMiddleware,
    RedisRateLimitMiddleware,
    AuditLogMiddleware,
    RangeHeaderValidationMiddleware,
    RequestSizeMiddleware,
    APIVersionMiddleware,
    RequestTimeoutMiddleware,
    QueryMonitoringMiddleware,
)

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

# Add request logging middleware first to catch all requests
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log all incoming requests for debugging"""
    async def dispatch(self, request, call_next):
        # Log ALL requests to verify middleware is working
        import sys
        path = request.url.path
        
        # Always log health-events requests with maximum visibility
        if "health-events" in path:
            logger.info(f"🌐 [REQUEST_LOG] {request.method} {path}")
            logger.info(f"   Query params: {dict(request.query_params)}")
            logger.info(f"   Headers: Authorization={'present' if 'authorization' in request.headers else 'missing'}")
            print(f"🌐 [REQUEST_LOG] {request.method} {path}", file=sys.stderr, flush=True)
            print(f"   Query params: {dict(request.query_params)}", file=sys.stderr, flush=True)
            print(f"🌐 [REQUEST_LOG] {request.method} {path}", flush=True)
            print(f"   Query params: {dict(request.query_params)}", flush=True)
        
        response = await call_next(request)
        
        if "health-events" in path:
            logger.info(f"🌐 [REQUEST_LOG] Response: {response.status_code}")
            print(f"🌐 [REQUEST_LOG] Response: {response.status_code}", file=sys.stderr, flush=True)
            print(f"🌐 [REQUEST_LOG] Response: {response.status_code}", flush=True)
        
        return response

app.add_middleware(RequestLoggingMiddleware)
# Add security middleware (order matters!)
# Note: Audit middleware disabled in production to avoid Railway rate limits
app.add_middleware(SecurityHeadersMiddleware)
if settings.environment != "production":
    app.add_middleware(AuditLogMiddleware)  # Only in dev/staging
# Use Redis-backed rate limiting (falls back to in-memory if Redis unavailable)
app.add_middleware(RedisRateLimitMiddleware)
# Range header validation mitigates CVE-2025-62727 (Starlette ReDoS)
# Must be early in stack to intercept before Starlette parsing
app.add_middleware(RangeHeaderValidationMiddleware)
app.add_middleware(RequestSizeMiddleware)
app.add_middleware(APIVersionMiddleware)
app.add_middleware(RequestTimeoutMiddleware)
# Query performance monitoring (only in non-production to avoid overhead)
if settings.environment != "production":
    app.add_middleware(QueryMonitoringMiddleware)

# Configure CORS with security
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Content-Type",
        "Authorization",
        "X-Requested-With",
        "Accept",
        "Origin",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers",
        "X-API-Version",
        "X-Client-Version"
    ],
    expose_headers=[
        "X-RateLimit-Limit",
        "X-RateLimit-Remaining",
        "X-RateLimit-Reset",
        "X-API-Version",
        "X-Response-Size",
        "Content-Encoding"
    ]
)

# Add trusted host middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.allowed_hosts
)

# Add compression middleware (lower threshold for mobile optimization)
app.add_middleware(GZipMiddleware, minimum_size=200)  # Compress responses >200 bytes
# Add JSON compression middleware (always compresses JSON for mobile)
from app.core.middleware import JSONCompressionMiddleware
app.add_middleware(JSONCompressionMiddleware)  # Always compress JSON responses

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
app.include_router(waitlist_router, prefix="/api/v1/waitlist", tags=["waitlist"])
app.include_router(
    revenuecat_webhook_router,
    prefix="/api/v1/subscriptions/revenuecat",
    tags=["subscriptions"]
)

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "SniffTest API is running", "version": "1.0.0"}

@app.get("/health")
async def health_check(check_db: bool = False) -> dict[str, str]:
    """
    Health check endpoint for Railway deployment
    
    Args:
        check_db: Optional flag to include database connectivity check (default: False)
                  Set to True for more thorough health checks.
                  When True, performs a quick database query with 5s timeout.
    
    Returns:
        Health status with optional database connectivity information
    """
    health_status = {
        "status": "healthy",
        "version": "1.0.0",
        "service": "SniffTest API"
    }
    
    # Optional database connectivity check with timeout
    if check_db:
        try:
            import asyncio
            from app.database import get_supabase_client, get_connection_stats
            
            # Perform quick database connectivity check with timeout
            async def check_db_connectivity():
                supabase = get_supabase_client()
                # Simple query to verify connectivity
                await asyncio.wait_for(
                    asyncio.to_thread(
                        lambda: supabase.table("users").select("id").limit(1).execute()
                    ),
                    timeout=5.0  # 5 second timeout for health check
                )
                return True
            
            # Try database connectivity check
            try:
                await check_db_connectivity()
                # Get connection stats if connectivity check passes
                db_stats = await get_connection_stats()
                health_status["database"] = {
                    **db_stats,
                    "connectivity": "ok"
                }
            except asyncio.TimeoutError:
                health_status["database"] = {
                    "status": "timeout",
                    "connectivity": "timeout",
                    "error": "Database connectivity check timed out after 5s"
                }
                health_status["status"] = "degraded"
            except Exception as db_error:
                health_status["database"] = {
                    "status": "error",
                    "connectivity": "error",
                    "error": "Database connectivity check failed"
                }
                health_status["status"] = "degraded"
                logger.warning(f"Database health check failed: {db_error}")
        except Exception as e:
            logger.warning(f"Database health check setup failed: {e}")
            health_status["database"] = {
                "status": "error",
                "connectivity": "error",
                "error": "Connection check failed"
            }
            health_status["status"] = "degraded"
    
    return health_status

@app.head("/health")
async def health_check_head() -> Response:
    """Minimal HEAD responder for Railway health probes"""
    return Response(status_code=status.HTTP_200_OK)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
