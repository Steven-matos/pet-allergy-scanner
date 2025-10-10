"""
Security middleware for enhanced protection
"""

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging
from typing import Dict, Optional
from collections import defaultdict, deque
import asyncio
from app.core.config import settings

logger = logging.getLogger(__name__)

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add security headers to all responses
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        # Different CSP policies for docs vs API endpoints
        self.api_csp = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'"
        self.docs_csp = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
            "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
            "img-src 'self' data: https://fastapi.tiangolo.com; "
            "font-src 'self' https://cdn.jsdelivr.net; "
            "connect-src 'self'"
        )
        
        self.security_headers = {
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
            "Referrer-Policy": "strict-origin-when-cross-origin",
            "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
            "Cross-Origin-Embedder-Policy": "require-corp",
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Resource-Policy": "same-origin"
        }
    
    async def dispatch(self, request: Request, call_next):
        """Add security headers to response"""
        response = await call_next(request)
        
        # Add security headers
        for header, value in self.security_headers.items():
            response.headers[header] = value
        
        # Apply appropriate CSP based on path
        if request.url.path in ["/docs", "/redoc", "/openapi.json"]:
            response.headers["Content-Security-Policy"] = self.docs_csp
        else:
            response.headers["Content-Security-Policy"] = self.api_csp
        
        # Add custom headers
        response.headers["X-API-Version"] = settings.api_version
        response.headers["X-Environment"] = settings.environment
        
        return response

class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware with different limits for different endpoints
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.rate_limits: Dict[str, deque] = defaultdict(lambda: deque())
        self.auth_limits: Dict[str, deque] = defaultdict(lambda: deque())
        self.cleanup_interval = 60  # Clean up old entries every 60 seconds
        self.last_cleanup = time.time()
    
    def _get_client_ip(self, request: Request) -> str:
        """Get client IP address"""
        # Check for forwarded headers first
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        return request.client.host if request.client else "unknown"
    
    def _is_auth_endpoint(self, path: str) -> bool:
        """Check if the endpoint is an authentication endpoint"""
        auth_paths = ["/api/v1/auth/login", "/api/v1/auth/register", "/api/v1/auth/forgot-password"]
        return any(path.startswith(auth_path) for auth_path in auth_paths)
    
    def _cleanup_old_entries(self):
        """Clean up old rate limit entries"""
        current_time = time.time()
        cutoff_time = current_time - 60  # Remove entries older than 1 minute
        
        # Clean up general rate limits
        for ip in list(self.rate_limits.keys()):
            while self.rate_limits[ip] and self.rate_limits[ip][0] < cutoff_time:
                self.rate_limits[ip].popleft()
            if not self.rate_limits[ip]:
                del self.rate_limits[ip]
        
        # Clean up auth rate limits
        for ip in list(self.auth_limits.keys()):
            while self.auth_limits[ip] and self.auth_limits[ip][0] < cutoff_time:
                self.auth_limits[ip].popleft()
            if not self.auth_limits[ip]:
                del self.auth_limits[ip]
    
    async def dispatch(self, request: Request, call_next):
        """Apply rate limiting"""
        client_ip = self._get_client_ip(request)
        current_time = time.time()
        
        # Cleanup old entries periodically
        if current_time - self.last_cleanup > self.cleanup_interval:
            self._cleanup_old_entries()
            self.last_cleanup = current_time
        
        # Determine rate limit based on endpoint
        if self._is_auth_endpoint(request.url.path):
            # Auth endpoints have stricter limits
            limit = settings.auth_rate_limit_per_minute
            rate_queue = self.auth_limits[client_ip]
        else:
            # General API endpoints
            limit = settings.rate_limit_per_minute
            rate_queue = self.rate_limits[client_ip]
        
        # Check rate limit
        cutoff_time = current_time - 60  # 1 minute window
        
        # Remove old entries
        while rate_queue and rate_queue[0] < cutoff_time:
            rate_queue.popleft()
        
        # Check if limit exceeded
        if len(rate_queue) >= limit:
            # Only log rate limit errors in development to avoid Railway rate limits
            if settings.environment != "production":
                logger.warning(f"Rate limit exceeded for IP: {client_ip}, Path: {request.url.path}")
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Rate limit exceeded. Please try again later.",
                    "retry_after": 60
                },
                headers={
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(int(current_time + 60))
                }
            )
        
        # Add current request
        rate_queue.append(current_time)
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        remaining = max(0, limit - len(rate_queue))
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(int(current_time + 60))
        
        return response
