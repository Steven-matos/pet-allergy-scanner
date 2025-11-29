"""
Audit logging middleware for security and compliance
"""

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging
import json
from typing import Dict, Any, Optional
from app.core.config import settings
from app.utils.logging_config import get_logger

logger = get_logger(__name__)

class AuditLogMiddleware(BaseHTTPMiddleware):
    """
    Middleware for audit logging of security-relevant events
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        import os
        
        # Ensure logs directory exists
        os.makedirs("logs", exist_ok=True)
        
        self.audit_logger = logging.getLogger("audit")
        self.audit_logger.setLevel(logging.INFO)
        
        # Create audit log handler
        if not self.audit_logger.handlers:
            handler = logging.FileHandler("logs/audit.log")
            formatter = logging.Formatter(
                "%(asctime)s - %(levelname)s - %(message)s"
            )
            handler.setFormatter(formatter)
            self.audit_logger.addHandler(handler)
    
    def _get_client_ip(self, request: Request) -> str:
        """Get client IP address"""
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        return request.client.host if request.client else "unknown"
    
    def _get_user_agent(self, request: Request) -> str:
        """Get user agent string"""
        return request.headers.get("User-Agent", "unknown")
    
    def _is_sensitive_endpoint(self, path: str) -> bool:
        """Check if endpoint handles sensitive data"""
        sensitive_paths = [
            "/api/v1/auth/",
            "/api/v1/pets/",
            "/api/v1/scans/",
            "/api/v1/users/"
        ]
        return any(path.startswith(sensitive_path) for sensitive_path in sensitive_paths)
    
    def _should_log_request(self, path: str, method: str, status_code: int) -> bool:
        """
        Determine if request should be logged based on path and status
        In production: Only log errors and critical operations to avoid Railway rate limits
        """
        # In production, be extremely selective
        if settings.environment == "production":
            # Only log server errors (500+) and auth failures (401, 403)
            if status_code >= 500:
                return True
            if status_code in [401, 403]:
                return True
            # Only log critical data modifications (user creation, deletions)
            if method in ["DELETE"] and "/users/" in path:
                return True
            return False
        
        # Development/staging: More verbose logging
        # Always log errors
        if status_code >= 400:
            return True
        
        # Log data modification operations
        if method in ["POST", "PUT", "DELETE"]:
            return True
        
        # Skip frequent health checks and monitoring endpoints
        skip_paths = ["/health", "/metrics", "/status", "/docs", "/redoc", "/openapi.json"]
        if any(path.endswith(skip_path) for skip_path in skip_paths):
            return False
        
        # Log only every 50th successful GET request to reduce noise
        if method == "GET" and status_code == 200:
            return hash(path) % 50 == 0
        
        return False
    
    def _log_audit_event(self, event_type: str, request: Request, response: Response, 
                        user_id: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        """
        Log audit event
        In production: Disabled completely to avoid Railway rate limits
        Use external monitoring services (e.g., Sentry, DataDog) instead
        """
        # Disable audit logging in production to avoid Railway rate limits
        if not settings.enable_audit_logging or settings.environment == "production":
            return
        
        audit_data = {
            "timestamp": time.time(),
            "event_type": event_type,
            "method": request.method,
            "path": request.url.path,
            "query_params": str(request.query_params),
            "client_ip": self._get_client_ip(request),
            "user_agent": self._get_user_agent(request),
            "status_code": response.status_code,
            "user_id": user_id,
            "details": details or {}
        }
        
        # Only log to file, not console
        self.audit_logger.info(json.dumps(audit_data))
    
    async def dispatch(self, request: Request, call_next):
        """Process request and log audit events"""
        start_time = time.time()
        
        # Process request
        response = await call_next(request)
        
        # Calculate processing time
        processing_time = time.time() - start_time
        
        # Get user ID from request if available
        user_id = None
        if hasattr(request.state, "user_id"):
            user_id = request.state.user_id
        
        # Log different types of events
        if self._is_sensitive_endpoint(request.url.path):
            # Check if we should log this request
            if not self._should_log_request(request.url.path, request.method, response.status_code):
                return response
                
            if response.status_code >= 400:
                # Log security events (errors, failures)
                self._log_audit_event(
                    "security_event",
                    request,
                    response,
                    user_id,
                    {
                        "processing_time": processing_time,
                        "error_type": "http_error"
                    }
                )
            elif request.method in ["POST", "PUT", "DELETE"]:
                # Log data modification events
                self._log_audit_event(
                    "data_modification",
                    request,
                    response,
                    user_id,
                    {
                        "processing_time": processing_time,
                        "operation": request.method
                    }
                )
            else:
                # Log data access events
                self._log_audit_event(
                    "data_access",
                    request,
                    response,
                    user_id,
                    {
                        "processing_time": processing_time
                    }
                )
        
        return response
