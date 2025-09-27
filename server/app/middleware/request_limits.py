"""
Request size and rate limiting middleware
"""

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging
from typing import Dict, Optional
from collections import defaultdict, deque
from app.core.config import settings

logger = logging.getLogger(__name__)

class RequestSizeMiddleware(BaseHTTPMiddleware):
    """
    Middleware to limit request size and prevent DoS attacks
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.max_request_size = settings.max_request_size_mb * 1024 * 1024  # Convert MB to bytes
    
    async def dispatch(self, request: Request, call_next):
        """Check request size before processing"""
        # Check content length
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                size = int(content_length)
                if size > self.max_request_size:
                    logger.warning(f"Request too large: {size} bytes from {request.client.host}")
                    return Response(
                        content="Request too large",
                        status_code=413,
                        headers={"Content-Type": "text/plain"}
                    )
            except ValueError:
                logger.warning(f"Invalid content-length header: {content_length}")
        
        # Process request
        response = await call_next(request)
        
        # Add size limit headers
        response.headers["X-Max-Request-Size"] = f"{settings.max_request_size_mb}MB"
        
        return response

class APIVersionMiddleware(BaseHTTPMiddleware):
    """
    Middleware to handle API versioning
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.supported_versions = ["v1"]
        self.default_version = "v1"
    
    async def dispatch(self, request: Request, call_next):
        """Handle API versioning"""
        # Extract version from path
        path_parts = request.url.path.split("/")
        if len(path_parts) >= 3 and path_parts[1] == "api":
            version = path_parts[2]
            
            # Check if version is supported
            if version not in self.supported_versions:
                return Response(
                    content=f"Unsupported API version: {version}",
                    status_code=400,
                    headers={"Content-Type": "text/plain"}
                )
            
            # Add version to request state
            request.state.api_version = version
        else:
            # Default version
            request.state.api_version = self.default_version
        
        # Process request
        response = await call_next(request)
        
        # Add version headers
        response.headers["X-API-Version"] = request.state.api_version
        response.headers["X-Supported-Versions"] = ",".join(self.supported_versions)
        
        return response

class RequestTimeoutMiddleware(BaseHTTPMiddleware):
    """
    Middleware to handle request timeouts
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.timeout_seconds = 30  # 30 second timeout
    
    async def dispatch(self, request: Request, call_next):
        """Handle request timeouts"""
        import asyncio
        
        try:
            # Process request with timeout
            response = await asyncio.wait_for(
                call_next(request),
                timeout=self.timeout_seconds
            )
            
            # Add timeout headers
            response.headers["X-Request-Timeout"] = f"{self.timeout_seconds}s"
            
            return response
            
        except asyncio.TimeoutError:
            logger.warning(f"Request timeout for {request.url.path} from {request.client.host}")
            return Response(
                content="Request timeout",
                status_code=408,
                headers={"Content-Type": "text/plain"}
            )
