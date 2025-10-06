"""
Test logging utilities for cleaner test output
Provides structured logging for test files to reduce console clutter
"""

import logging
import sys
from typing import Optional


class TestFormatter(logging.Formatter):
    """Clean formatter for test output with minimal noise"""
    
    def format(self, record):
        # Clean up test module names
        if hasattr(record, 'name'):
            name = record.name
            if name.startswith('tests.'):
                name = name.replace('tests.', '')
            elif name == '__main__':
                name = 'test'
            record.name = name
        
        return super().format(record)


def setup_test_logging(level: str = "INFO") -> logging.Logger:
    """
    Set up clean logging for test files
    
    Args:
        level: Log level for tests
        
    Returns:
        Configured logger for tests
    """
    # Create test logger
    logger = logging.getLogger("test")
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    
    # Remove existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Console handler with clean format
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, level.upper(), logging.INFO))
    console_handler.setFormatter(TestFormatter(
        "%(asctime)s | %(levelname)-8s | %(name)-10s | %(message)s",
        datefmt="%H:%M:%S"
    ))
    logger.addHandler(console_handler)
    
    # Suppress noisy loggers during tests
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("supabase").setLevel(logging.WARNING)
    
    return logger


def test_log_step(logger: logging.Logger, step: str, description: str) -> None:
    """Log test step with clean formatting"""
    logger.info(f"🧪 {step}: {description}")


def test_log_success(logger: logging.Logger, message: str) -> None:
    """Log test success with clean formatting"""
    logger.info(f"✅ {message}")


def test_log_error(logger: logging.Logger, message: str) -> None:
    """Log test error with clean formatting"""
    logger.error(f"❌ {message}")


def test_log_warning(logger: logging.Logger, message: str) -> None:
    """Log test warning with clean formatting"""
    logger.warning(f"⚠️  {message}")


def test_log_info(logger: logging.Logger, message: str) -> None:
    """Log test info with clean formatting"""
    logger.info(f"ℹ️  {message}")
