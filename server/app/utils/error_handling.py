"""
Enhanced error handling and logging utilities
"""

import logging
import traceback
from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.core.config import settings

logger = logging.getLogger(__name__)

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
    return create_error_response(exc, request, include_details=True)

def handle_http_exception(request: Request, exc: HTTPException) -> JSONResponse:
    """Handle HTTP exceptions"""
    return create_error_response(exc, request)

def handle_generic_exception(request: Request, exc: Exception) -> JSONResponse:
    """Handle generic exceptions"""
    return create_error_response(exc, request, include_details=settings.debug)

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
