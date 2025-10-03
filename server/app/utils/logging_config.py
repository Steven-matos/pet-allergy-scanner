"""
Centralized logging configuration for the Pet Allergy Scanner API
Provides consistent logging setup across all modules
"""

import logging
import sys
from typing import Optional
from app.core.config import settings


class ColoredFormatter(logging.Formatter):
    """Custom formatter with colors for different log levels"""
    
    # Color codes
    COLORS = {
        'DEBUG': '\033[36m',    # Cyan
        'INFO': '\033[32m',     # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',    # Red
        'CRITICAL': '\033[35m', # Magenta
        'RESET': '\033[0m'      # Reset
    }
    
    def format(self, record):
        # Add color to the level name
        if record.levelname in self.COLORS:
            record.levelname = f"{self.COLORS[record.levelname]}{record.levelname}{self.COLORS['RESET']}"
        return super().format(record)


def setup_logging(log_level: Optional[str] = None) -> None:
    """
    Set up centralized logging configuration
    
    Args:
        log_level: Override log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    # Determine log level
    if log_level:
        level = getattr(logging, log_level.upper(), logging.INFO)
    else:
        level = logging.DEBUG if settings.debug else logging.INFO
    
    # Create formatters
    if settings.environment == "production":
        # Production: Simple format, no colors
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
    else:
        # Development: Colored format with more details
        formatter = ColoredFormatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%H:%M:%S"
        )
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # Set specific logger levels to reduce noise
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("supabase").setLevel(logging.WARNING)
    
    # Audit logger (separate from main logging)
    audit_logger = logging.getLogger("audit")
    audit_logger.setLevel(logging.INFO)
    audit_logger.propagate = False  # Don't propagate to root logger
    
    if not audit_logger.handlers:
        audit_handler = logging.FileHandler("audit.log")
        audit_formatter = logging.Formatter(
            "%(asctime)s - %(levelname)s - %(message)s",
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


def log_function_call(logger: logging.Logger, func_name: str, **kwargs) -> None:
    """
    Log function call with parameters (for debug purposes)
    
    Args:
        logger: Logger instance
        func_name: Function name
        **kwargs: Function parameters to log
    """
    if logger.isEnabledFor(logging.DEBUG):
        params = ", ".join([f"{k}={v}" for k, v in kwargs.items()])
        logger.debug(f"Calling {func_name}({params})")


def log_database_operation(logger: logging.Logger, operation: str, table: str, 
                          record_id: Optional[str] = None, success: bool = True) -> None:
    """
    Log database operations consistently
    
    Args:
        logger: Logger instance
        operation: Operation type (CREATE, READ, UPDATE, DELETE)
        table: Database table name
        record_id: Record ID if available
        success: Whether operation was successful
    """
    if success:
        if record_id:
            logger.info(f"Database {operation} on {table} for ID {record_id}")
        else:
            logger.info(f"Database {operation} on {table}")
    else:
        logger.error(f"Database {operation} failed on {table}")


def log_api_request(logger: logging.Logger, method: str, path: str, 
                   status_code: int, processing_time: float) -> None:
    """
    Log API requests consistently
    
    Args:
        logger: Logger instance
        method: HTTP method
        path: Request path
        status_code: Response status code
        processing_time: Request processing time in seconds
    """
    if status_code >= 400:
        logger.warning(f"{method} {path} - {status_code} ({processing_time:.3f}s)")
    else:
        logger.info(f"{method} {path} - {status_code} ({processing_time:.3f}s)")


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
        logger.warning(f"Security event: {event_type} - {details} (User: {user_id})")
    else:
        logger.warning(f"Security event: {event_type} - {details}")
