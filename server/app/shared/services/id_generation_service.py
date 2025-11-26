"""
Centralized ID generation service

This is the SINGLE SOURCE OF TRUTH for:
1. Consistent ID generation across the application
2. Standardized UUID generation format

All ID generation should use this service for consistency and future flexibility.
"""

import uuid
from typing import Optional


class IDGenerationService:
    """
    Centralized service for ID generation
    
    This ensures:
    - Consistent ID format across the application
    - Single place to change ID generation strategy if needed
    - Standardized UUID generation
    """
    
    @staticmethod
    def generate_uuid() -> str:
        """
        Generate a new UUID as string
        
        This is the standard ID format used throughout the application.
        If we need to change the ID generation strategy, we only change it here.
        
        Returns:
            UUID string (e.g., "123e4567-e89b-12d3-a456-426614174000")
        """
        return str(uuid.uuid4())
    
    @staticmethod
    def generate_uuid4() -> uuid.UUID:
        """
        Generate a new UUID4 object
        
        Returns:
            UUID4 object
        """
        return uuid.uuid4()

