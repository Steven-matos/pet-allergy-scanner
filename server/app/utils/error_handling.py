"""
Enhanced error handling and logging utilities
"""

import logging
import traceback
import re
from datetime import datetime
from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.core.config import settings

logger = logging.getLogger(__name__)


def _extract_user_id_from_request(request: Request) -> Optional[str]:
    """
    Extract user ID from JWT token in request headers for error logging
    
    Args:
        request: FastAPI request object
        
    Returns:
        User ID if token is valid and contains user_id, None otherwise
    """
    try:
        # Get authorization header
        auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return None
        
        # Extract token
        token = auth_header.replace("Bearer ", "").strip()
        if not token:
            return None
        
        # Decode JWT token (without verification for error logging only)
        import jwt
        from app.core.config import settings
        
        try:
            # Try to decode without verification first (faster for error logging)
            # Note: We skip signature verification and expiration checks for error logging only
            payload = jwt.decode(
                token,
                options={
                    "verify_signature": False,  # Skip verification for logging
                    "verify_exp": False,        # Allow expired tokens for logging
                    "verify_aud": False,        # Skip audience check for logging
                    "verify_iss": False         # Skip issuer check for logging
                }
            )
            user_id = payload.get("sub")
            return str(user_id) if user_id else None
        except Exception as decode_error:
            # If decoding fails, return None (fail silently for error logging)
            logger.debug(f"Failed to extract user_id from token: {type(decode_error).__name__}")
            return None
            
    except Exception:
        # If anything fails, return None (fail silently for error logging)
        return None

class SecurityError(Exception):
    """Custom security-related error"""
    pass

class ValidationError(Exception):
    """Custom validation error"""
    pass

class DatabaseError(Exception):
    """Custom database error"""
    pass

class APIError(Exception):
    """Custom API error"""
    def __init__(self, message: str, status_code: int = 500, details: Optional[Dict[str, Any]] = None):
        self.message = message
        self.status_code = status_code
        self.details = details or {}
        super().__init__(self.message)

def log_error(error: Exception, request: Request, user_id: Optional[str] = None):
    """
    Log error with context information
    
    Args:
        error: The exception that occurred
        request: The FastAPI request object
        user_id: Optional user ID for context
    """
    error_context = {
        "error_type": type(error).__name__,
        "error_message": str(error),
        "request_method": request.method,
        "request_url": str(request.url),
        "request_headers": dict(request.headers),
        "user_id": user_id,
        "traceback": traceback.format_exc()
    }
    
    # Log based on error type
    if isinstance(error, SecurityError):
        logger.critical(f"Security error: {error_context}")
    elif isinstance(error, (ValidationError, RequestValidationError)):
        logger.warning(f"Validation error: {error_context}")
    elif isinstance(error, DatabaseError):
        logger.error(f"Database error: {error_context}")
    elif isinstance(error, APIError):
        logger.error(f"API error: {error_context}")
    elif isinstance(error, (HTTPException, StarletteHTTPException)):
        # HTTP exceptions are expected client/server errors
        # Log 4xx as warnings (client errors), 5xx as errors (server errors)
        status_code = getattr(error, 'status_code', 500)
        if 400 <= status_code < 500:
            # Client errors (4xx) - log as warning, not error
            logger.warning(f"Client error ({status_code}): {error_context}")
        else:
            # Server errors (5xx) - log as error
            logger.error(f"Server error ({status_code}): {error_context}")
    else:
        logger.error(f"Unexpected error: {error_context}")

def create_error_response(
    error: Exception, 
    request: Request, 
    user_id: Optional[str] = None,
    include_details: bool = False
) -> JSONResponse:
    """
    Create standardized error response
    
    Args:
        error: The exception that occurred
        request: The FastAPI request object
        user_id: Optional user ID for context
        include_details: Whether to include error details in response
        
    Returns:
        JSONResponse with error information
    """
    # Log the error
    log_error(error, request, user_id)
    
    # Determine status code and message
    if isinstance(error, SecurityError):
        status_code = status.HTTP_403_FORBIDDEN
        message = "Access denied"
        details = {"error_type": "security_error"}
    elif isinstance(error, ValidationError):
        status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
        message = "Validation error"
        details = {"error_type": "validation_error", "details": str(error)}
    elif isinstance(error, RequestValidationError):
        status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
        message = "Invalid request data"
        details = {"error_type": "validation_error", "errors": error.errors()}
    elif isinstance(error, DatabaseError):
        status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
        message = "Database error occurred"
        details = {"error_type": "database_error"}
    elif isinstance(error, APIError):
        status_code = error.status_code
        message = error.message
        details = {"error_type": "api_error", "details": error.details}
    elif isinstance(error, HTTPException):
        status_code = error.status_code
        message = error.detail
        details = {"error_type": "http_error"}
    elif isinstance(error, StarletteHTTPException):
        status_code = error.status_code
        message = error.detail
        details = {"error_type": "http_error"}
    else:
        status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
        message = "Internal server error"
        details = {"error_type": "internal_error"}
    
    # Add request ID for tracking
    request_id = getattr(request.state, "request_id", None)
    if request_id:
        details["request_id"] = request_id
    
    # Include error details in development
    if include_details and settings.environment == "development":
        details["traceback"] = traceback.format_exc()
    
    return JSONResponse(
        status_code=status_code,
        content={
            "error": message,
            "details": details,
            "timestamp": str(datetime.utcnow()),
            "path": request.url.path
        }
    )

def handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Handle Pydantic validation errors"""
    import json
    user_id = _extract_user_id_from_request(request)
    
    # Log detailed validation errors
    error_details = exc.errors()
    logger.error(f"Validation error on {request.method} {request.url.path}")
    logger.error(f"Validation errors: {json.dumps(error_details, indent=2, default=str)}")
    
    # Try to log request body if available
    try:
        body = getattr(request, '_body', None)
        if body:
            logger.debug(f"Request body: {body.decode('utf-8') if isinstance(body, bytes) else body}")
    except Exception:
        pass
    
    return create_error_response(exc, request, user_id=user_id, include_details=True)

def handle_http_exception(request: Request, exc: HTTPException) -> JSONResponse:
    """Handle HTTP exceptions"""
    user_id = _extract_user_id_from_request(request)
    return create_error_response(exc, request, user_id=user_id)

def handle_generic_exception(request: Request, exc: Exception) -> JSONResponse:
    """Handle generic exceptions"""
    user_id = _extract_user_id_from_request(request)
    return create_error_response(exc, request, user_id=user_id, include_details=settings.debug)

def validate_request_size(request: Request) -> None:
    """
    Validate request size to prevent DoS attacks
    
    Args:
        request: The FastAPI request object
        
    Raises:
        HTTPException: If request is too large
    """
    content_length = request.headers.get("content-length")
    if content_length:
        size = int(content_length)
        max_size = settings.max_request_size_mb * 1024 * 1024  # Convert MB to bytes
        
        if size > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Request size exceeds maximum allowed size of {settings.max_request_size_mb}MB"
            )

def sanitize_error_message(message: str) -> str:
    """
    Sanitize error messages to prevent information leakage
    
    Args:
        message: Original error message
        
    Returns:
        Sanitized error message
    """
    # Remove sensitive information
    sensitive_patterns = [
        r'password',
        r'token',
        r'key',
        r'secret',
        r'credential',
        r'auth',
        r'login',
        r'session',
        r'cookie',
        r'header',
        r'bearer',
        r'jwt',
        r'api_key',
        r'access_token',
        r'refresh_token',
        r'private_key',
        r'public_key',
        r'certificate',
        r'ssl',
        r'tls',
        r'encryption',
        r'hash',
        r'salt',
        r'iv',
        r'nonce',
        r'signature',
        r'mac',
        r'hmac',
        r'rsa',
        r'aes',
        r'des',
        r'3des',
        r'blowfish',
        r'twofish',
        r'cast',
        r'idea',
        r'rc4',
        r'rc5',
        r'rc6',
        r'serpent',
        r'camellia',
        r'seed',
        r'aria',
        r'gost',
        r'kalyna',
        r'kuznyechik',
        r'magma',
        r'present',
        r'prince',
        r'princep',
        r'princep2',
        r'princep3',
        r'princep4',
        r'princep5',
        r'princep6',
        r'princep7',
        r'princep8',
        r'princep9',
        r'princep10',
        r'princep11',
        r'princep12',
        r'princep13',
        r'princep14',
        r'princep15',
        r'princep16',
        r'princep17',
        r'princep18',
        r'princep19',
        r'princep20'
    ]
    
    sanitized = message
    for pattern in sensitive_patterns:
        sanitized = re.sub(pattern, "[REDACTED]", sanitized, flags=re.IGNORECASE)
    
    return sanitized

def create_success_response(data: Any, message: str = "Success") -> Dict[str, Any]:
    """
    Create standardized success response
    
    Args:
        data: Response data
        message: Success message
        
    Returns:
        Dictionary with success response
    """
    return {
        "success": True,
        "message": message,
        "data": data,
        "timestamp": str(datetime.utcnow())
    }
