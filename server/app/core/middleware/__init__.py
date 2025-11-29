"""
Core Middleware Module

Provides FastAPI middleware for security, rate limiting, monitoring, and request handling.
"""

from .security import SecurityHeadersMiddleware
from .rate_limit_redis import RedisRateLimitMiddleware
from .audit import AuditLogMiddleware
from .request_limits import (
    RangeHeaderValidationMiddleware,
    RequestSizeMiddleware,
    APIVersionMiddleware,
    RequestTimeoutMiddleware,
)
from .query_monitoring import QueryMonitoringMiddleware
from .json_compression import JSONCompressionMiddleware

__all__ = [
    'SecurityHeadersMiddleware',
    'RedisRateLimitMiddleware',
    'AuditLogMiddleware',
    'RangeHeaderValidationMiddleware',
    'RequestSizeMiddleware',
    'APIVersionMiddleware',
    'RequestTimeoutMiddleware',
    'QueryMonitoringMiddleware',
    'JSONCompressionMiddleware',
]
