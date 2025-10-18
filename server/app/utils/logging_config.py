"""
Centralized logging configuration for the SniffTest API
Provides consistent logging setup across all modules with clean console output
"""

import logging
import sys
import os
from typing import Optional
from app.core.config import settings


class CleanFormatter(logging.Formatter):
    """Clean formatter with minimal noise and clear structure"""
    
    # Color codes for different environments
    COLORS = {
        'DEBUG': '\033[36m',    # Cyan
        'INFO': '\033[32m',     # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',    # Red
        'CRITICAL': '\033[35m', # Magenta
        'RESET': '\033[0m'      # Reset
    }
    
    def format(self, record):
        # Clean up module names for better readability
        if hasattr(record, 'name'):
            # Shorten common module paths
            name = record.name
            if name.startswith('app.routers.'):
                name = name.replace('app.routers.', '')
            elif name.startswith('app.services.'):
                name = name.replace('app.services.', '')
            elif name.startswith('app.middleware.'):
                name = name.replace('app.middleware.', '')
            elif name == '__main__':
                name = 'main'
            record.name = name
        
        # Add color to the level name in development
        if settings.environment != "production" and record.levelname in self.COLORS:
            record.levelname = f"{self.COLORS[record.levelname]}{record.levelname}{self.COLORS['RESET']}"
        
        return super().format(record)


def setup_logging(log_level: Optional[str] = None) -> None:
    """
    Set up centralized logging configuration with clean console output
    Production: Only log ERROR and CRITICAL to reduce Railway rate limits
    
    Args:
        log_level: Override log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    # Determine log level - Use settings or parameter
    if log_level:
        level = getattr(logging, log_level.upper(), logging.ERROR)
    else:
        # Production and Railway deployment: ERROR only to avoid Railway rate limits
        # Development: INFO for debugging, but reduce verbosity
        if settings.environment == "production":
            level = logging.ERROR
        elif settings.environment in ["staging", "production"] or "railway" in os.environ.get("RAILWAY_PROJECT_ID", ""):
            # Railway deployment - be more aggressive about log reduction
            level = logging.ERROR
        elif settings.verbose_logging and settings.environment == "development":
            level = logging.DEBUG
        else:
            level = logging.WARNING  # Default to WARNING to reduce noise
    
    # Create formatters based on environment
    if settings.environment == "production":
        # Production: Clean format, no colors, structured for log aggregation
        formatter = logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(name)-15s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
    else:
        # Development: Clean format with colors and shorter timestamps
        formatter = CleanFormatter(
            "%(asctime)s | %(levelname)-8s | %(name)-15s | %(message)s",
            datefmt="%H:%M:%S"
        )
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # Remove existing handlers to avoid duplicates
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Console handler with clean output
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # Suppress noisy third-party loggers
    _suppress_noisy_loggers()
    
    # Set up audit logging (separate from main logging)
    _setup_audit_logging()


def _suppress_noisy_loggers() -> None:
    """
    Suppress noisy third-party loggers to reduce console clutter
    In production: Only log CRITICAL errors to avoid Railway rate limits
    """
    # In production and Railway, suppress almost all third-party logging
    if settings.environment == "production" or settings.environment in ["staging", "production"] or "railway" in os.environ.get("RAILWAY_PROJECT_ID", ""):
        noisy_loggers = {
            "uvicorn.access": logging.CRITICAL,     # Disable access logs completely
            "uvicorn.error": logging.CRITICAL,      # Disable uvicorn errors completely
            "httpx": logging.CRITICAL,              # Disable HTTP client logs
            "httpcore": logging.CRITICAL,           # Disable HTTP core logs
            "supabase": logging.CRITICAL,           # Disable Supabase logs completely
            "urllib3": logging.CRITICAL,            # Disable urllib3 logs
            "asyncio": logging.CRITICAL,            # Disable asyncio logs
            "multipart": logging.CRITICAL,          # Disable multipart logs
            "fastapi": logging.CRITICAL,            # Disable FastAPI logs completely
            "starlette": logging.CRITICAL,          # Disable Starlette logs completely
        }
    else:
        # Development: Show warnings and above
        noisy_loggers = {
            "uvicorn.access": logging.WARNING,      # Only show access errors
            "uvicorn.error": logging.INFO,          # Show uvicorn errors
            "httpx": logging.WARNING,               # Only show HTTP client errors
            "httpcore": logging.WARNING,            # Only show HTTP core errors
            "supabase": logging.WARNING,            # Only show Supabase errors
            "urllib3": logging.WARNING,             # Only show urllib3 errors
            "asyncio": logging.WARNING,             # Only show asyncio errors
            "multipart": logging.WARNING,           # Only show multipart errors
        }
    
    for logger_name, level in noisy_loggers.items():
        logging.getLogger(logger_name).setLevel(level)


def _setup_audit_logging() -> None:
    """
    Set up separate audit logging for security events
    In production: Only log to file, not console, to avoid Railway rate limits
    """
    import os
    from app.core.config import settings
    
    # Only enable audit logging if explicitly enabled and not in production
    # In production, use external monitoring services instead
    if not settings.enable_audit_logging or settings.environment == "production":
        return
    
    # Ensure logs directory exists (development only)
    os.makedirs("logs", exist_ok=True)
    
    audit_logger = logging.getLogger("audit")
    audit_logger.setLevel(logging.WARNING)  # Only warnings and above
    audit_logger.propagate = False  # Don't propagate to root logger
    
    if not audit_logger.handlers:
        audit_handler = logging.FileHandler("logs/audit.log")
        audit_formatter = logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        audit_handler.setFormatter(audit_formatter)
        audit_logger.addHandler(audit_handler)


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with consistent configuration
    
    Args:
        name: Logger name (usually __name__)
        
    Returns:
        Configured logger instance
    """
    return logging.getLogger(name)


def log_startup(logger: logging.Logger, service_name: str) -> None:
    """
    Log service startup with clean formatting
    Only logs in development to reduce production noise
    """
    if settings.environment != "production":
        logger.info(f"🚀 Starting {service_name}")


def log_shutdown(logger: logging.Logger, service_name: str) -> None:
    """
    Log service shutdown with clean formatting
    Only logs in development to reduce production noise
    """
    if settings.environment != "production":
        logger.info(f"🛑 Shutting down {service_name}")


def log_database_operation(logger: logging.Logger, operation: str, table: str, 
                          record_id: Optional[str] = None, success: bool = True) -> None:
    """
    Log database operations consistently - only log errors and important operations
    
    Args:
        logger: Logger instance
        operation: Operation type (CREATE, READ, UPDATE, DELETE)
        table: Database table name
        record_id: Record ID if available
        success: Whether operation was successful
    """
    if not success:
        # Always log database errors
        logger.error(f"DB {operation} failed on {table}")
    elif operation in ["CREATE", "DELETE"] and record_id:
        # Only log important operations (CREATE/DELETE) with record IDs
        logger.info(f"DB {operation} on {table} for ID {record_id}")
    # Skip logging for READ operations and simple operations to reduce noise


def log_api_request(logger: logging.Logger, method: str, path: str, 
                   status_code: int, processing_time: float) -> None:
    """
    Log API requests consistently - only log errors, slow requests, and important endpoints
    
    Args:
        logger: Logger instance
        method: HTTP method
        path: Request path
        status_code: Response status code
        processing_time: Request processing time in seconds
    """
    if status_code >= 400:
        # Always log errors
        logger.warning(f"API {method} {path} → {status_code} ({processing_time:.3f}s)")
    elif processing_time > 1.0:
        # Log slow requests
        logger.warning(f"⏱️  Slow API {method} {path} → {status_code} ({processing_time:.3f}s)")
    elif path in ["/health", "/api/v1/auth/login", "/api/v1/auth/register"]:
        # Only log important endpoints
        logger.info(f"API {method} {path} → {status_code} ({processing_time:.3f}s)")
    # Skip logging for routine GET requests to reduce noise


def log_security_event(logger: logging.Logger, event_type: str, details: str, 
                      user_id: Optional[str] = None) -> None:
    """
    Log security events consistently
    
    Args:
        logger: Logger instance
        event_type: Type of security event
        details: Event details
        user_id: User ID if available
    """
    if user_id:
        logger.warning(f"🔒 Security: {event_type} - {details} (User: {user_id})")
    else:
        logger.warning(f"🔒 Security: {event_type} - {details}")


def log_performance(logger: logging.Logger, operation: str, duration: float, 
                   threshold: float = 1.0) -> None:
    """
    Log performance metrics for operations that take longer than threshold
    
    Args:
        logger: Logger instance
        operation: Operation name
        duration: Duration in seconds
        threshold: Warning threshold in seconds
    """
    if duration > threshold:
        logger.warning(f"⏱️  Slow operation: {operation} took {duration:.3f}s")
    # Skip logging for fast operations to reduce noise
