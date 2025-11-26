"""
Shared decorators for common patterns

This module provides decorators for:
- Error handling
- Performance monitoring
- Caching
- Validation
"""

from app.shared.decorators.error_handler import (
    handle_errors,
    handle_errors_with_custom_message
)

__all__ = [
    'handle_errors',
    'handle_errors_with_custom_message'
]

