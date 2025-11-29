"""
Core Database Module

Provides database client initialization and management.
"""

from .client import (
    init_db,
    get_supabase_client,
    get_supabase_service_role_client,
    get_db,
    close_db,
    get_connection_stats,
)

__all__ = [
    'init_db',
    'get_supabase_client',
    'get_supabase_service_role_client',
    'get_db',
    'close_db',
    'get_connection_stats',
]
