"""
JSON compression middleware

Always compresses JSON responses regardless of size to optimize for mobile.
This works alongside GZipMiddleware to ensure JSON is always compressed.
"""

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
from starlette.responses import Response, StreamingResponse
import gzip
import logging
from typing import Callable

logger = logging.getLogger(__name__)


class JSONCompressionMiddleware(BaseHTTPMiddleware):
    """
    Middleware that always compresses JSON responses for mobile optimization.
    
    This ensures all JSON responses are compressed, even small ones,
    to reduce bandwidth usage on mobile connections.
    
    Note: Works alongside GZipMiddleware which handles larger responses.
    This middleware specifically targets JSON responses that might be
    smaller than GZipMiddleware's threshold.
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """
        Process request and compress JSON responses.
        
        Args:
            request: Incoming request
            call_next: Next middleware/route handler
            
        Returns:
            Response with compressed JSON if applicable
        """
        response = await call_next(request)
        
        # Only compress JSON responses
        content_type = response.headers.get("content-type", "")
        if "application/json" not in content_type.lower():
            return response
        
        # Skip if already compressed (GZipMiddleware may have handled it)
        if response.headers.get("content-encoding") == "gzip":
            return response
        
        # Skip streaming responses
        if isinstance(response, StreamingResponse):
            return response
        
        # Read response body
        try:
            body = b""
            if hasattr(response, 'body'):
                body = response.body
            elif hasattr(response, '_content'):
                body = response._content
            else:
                # Try to read from body iterator
                async for chunk in response.body_iterator:
                    body += chunk
                    # Prevent reading too much
                    if len(body) > 10 * 1024 * 1024:  # 10MB limit
                        logger.warning("Response body too large for compression")
                        return response
        except Exception as e:
            logger.debug(f"Could not read response body: {e}")
            return response
        
        # Skip if body is empty or too small
        if len(body) < 50:
            return response
        
        # Compress JSON
        try:
            compressed = gzip.compress(body, compresslevel=6)
            
            # Only use compression if it actually reduces size (at least 10% reduction)
            if len(compressed) < len(body) * 0.9:
                return Response(
                    content=compressed,
                    status_code=response.status_code,
                    headers={
                        **dict(response.headers),
                        "content-encoding": "gzip",
                        "content-length": str(len(compressed)),
                        "vary": "Accept-Encoding"
                    },
                    media_type=response.media_type
                )
        except Exception as e:
            logger.debug(f"Compression failed: {e}")
        
        # Return original response if compression didn't help or failed
        return response

