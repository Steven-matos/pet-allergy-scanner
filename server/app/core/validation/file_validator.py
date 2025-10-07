"""
File upload validation utilities

Extracted from app.utils.security.SecurityValidator
Follows Single Responsibility Principle: File validation only
"""

from fastapi import HTTPException, status
from app.core.config import settings


class FileValidator:
    """File upload validation utilities"""
    
    @classmethod
    def validate_file_upload(
        cls, 
        filename: str, 
        content_type: str, 
        size: int
    ) -> bool:
        """
        Validate file upload
        
        Args:
            filename: Name of the file
            content_type: MIME type of the file
            size: File size in bytes
            
        Returns:
            True if valid
            
        Raises:
            HTTPException: If file is invalid
        """
        # Check file size
        max_size = settings.max_file_size_mb * 1024 * 1024  # Convert MB to bytes
        if size > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size exceeds maximum allowed size of {settings.max_file_size_mb}MB"
            )
        
        # Check file extension
        allowed_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        file_ext = filename.lower().split('.')[-1] if '.' in filename else ''
        
        if f'.{file_ext}' not in allowed_extensions:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Only image files are allowed"
            )
        
        # Check MIME type
        allowed_mime_types = [
            'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 
            'image/bmp', 'image/webp'
        ]
        
        if content_type not in allowed_mime_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Only image files are allowed"
            )
        
        return True

