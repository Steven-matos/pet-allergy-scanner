"""
Centralized date/time service

This is the SINGLE SOURCE OF TRUTH for:
1. Current timestamp generation
2. Date/time formatting
3. Timezone handling

All date/time operations should use this service for consistency.
"""

from datetime import datetime, timezone
from typing import Optional


class DateTimeService:
    """
    Centralized service for date/time operations
    
    This ensures:
    - Consistent timestamp format across the application
    - Single place to change date format if needed
    - Proper timezone handling
    """
    
    @staticmethod
    def now_iso() -> str:
        """
        Get current UTC timestamp in ISO format
        
        This is the standard format used throughout the application.
        If we need to change the format, we only change it here.
        
        Returns:
            ISO format timestamp string (e.g., "2025-01-23T10:30:00.123456+00:00")
        """
        return datetime.now(timezone.utc).isoformat()
    
    @staticmethod
    def now() -> datetime:
        """
        Get current UTC datetime object
        
        Returns:
            Current UTC datetime
        """
        return datetime.now(timezone.utc)
    
    @staticmethod
    def to_iso(dt: datetime) -> str:
        """
        Convert datetime to ISO format string
        
        Args:
            dt: Datetime object to convert
            
        Returns:
            ISO format string
        """
        if dt.tzinfo is None:
            # Assume UTC if no timezone info
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.isoformat()
    
    @staticmethod
    def from_iso(iso_string: str) -> datetime:
        """
        Parse ISO format string to datetime
        
        Args:
            iso_string: ISO format timestamp string
            
        Returns:
            Datetime object
        """
        return datetime.fromisoformat(iso_string.replace('Z', '+00:00'))

