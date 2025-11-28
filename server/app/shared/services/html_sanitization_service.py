"""
HTML Sanitization Service for user-generated content

Provides comprehensive HTML sanitization to prevent XSS attacks and ensure
safe storage and display of user-generated content.

Follows SOLID principles with single responsibility for HTML sanitization.
Implements DRY by centralizing sanitization logic.
Follows KISS by providing simple, clear API.
"""

import bleach
import logging
from typing import Optional, List
from enum import Enum

logger = logging.getLogger(__name__)


class SanitizationLevel(str, Enum):
    """Sanitization strictness levels"""
    STRICT = "strict"  # Remove all HTML tags
    MODERATE = "moderate"  # Allow safe formatting tags only
    PERMISSIVE = "permissive"  # Allow more formatting but still safe


class HTMLSanitizationService:
    """
    Centralized HTML sanitization service
    
    Provides different levels of sanitization based on use case:
    - STRICT: For notes, descriptions, titles (no HTML allowed)
    - MODERATE: For rich text fields (basic formatting allowed)
    - PERMISSIVE: For content that needs more formatting (still safe)
    """
    
    # Safe HTML tags for moderate sanitization (basic formatting)
    MODERATE_ALLOWED_TAGS = [
        'p', 'br', 'strong', 'em', 'u', 'b', 'i', 'ul', 'ol', 'li'
    ]
    
    # Safe HTML tags for permissive sanitization (more formatting)
    PERMISSIVE_ALLOWED_TAGS = [
        'p', 'br', 'strong', 'em', 'u', 'b', 'i', 'ul', 'ol', 'li',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'code', 'pre'
    ]
    
    # Safe HTML attributes (for tags that support them)
    ALLOWED_ATTRIBUTES = {
        'a': ['href', 'title'],
        'img': ['src', 'alt', 'title'],
    }
    
    # Allowed URL schemes
    ALLOWED_SCHEMES = ['http', 'https', 'mailto']
    
    @staticmethod
    def sanitize(
        text: Optional[str],
        level: SanitizationLevel = SanitizationLevel.STRICT,
        max_length: Optional[int] = None
    ) -> Optional[str]:
        """
        Sanitize HTML content based on specified level
        
        Args:
            text: Text content to sanitize (can be None)
            level: Sanitization strictness level
            max_length: Optional maximum length to truncate
            
        Returns:
            Sanitized text or None if input was None
        """
        if text is None:
            return None
        
        if not isinstance(text, str):
            # Convert to string if not already
            text = str(text)
        
        # Empty string handling
        if not text.strip():
            return text.strip()
        
        try:
            if level == SanitizationLevel.STRICT:
                # Remove all HTML tags - most secure
                sanitized = bleach.clean(text, tags=[], strip=True)
            elif level == SanitizationLevel.MODERATE:
                # Allow basic formatting tags
                sanitized = bleach.clean(
                    text,
                    tags=HTMLSanitizationService.MODERATE_ALLOWED_TAGS,
                    attributes=HTMLSanitizationService.ALLOWED_ATTRIBUTES,
                    protocols=HTMLSanitizationService.ALLOWED_SCHEMES,
                    strip=True
                )
            elif level == SanitizationLevel.PERMISSIVE:
                # Allow more formatting tags
                sanitized = bleach.clean(
                    text,
                    tags=HTMLSanitizationService.PERMISSIVE_ALLOWED_TAGS,
                    attributes=HTMLSanitizationService.ALLOWED_ATTRIBUTES,
                    protocols=HTMLSanitizationService.ALLOWED_SCHEMES,
                    strip=True
                )
            else:
                # Default to strict
                sanitized = bleach.clean(text, tags=[], strip=True)
            
            # Apply length limit if specified
            if max_length and len(sanitized) > max_length:
                sanitized = sanitized[:max_length]
                logger.warning(f"Sanitized text truncated to {max_length} characters")
            
            return sanitized.strip()
            
        except Exception as e:
            logger.error(f"Error sanitizing HTML content: {e}")
            # On error, fall back to strict sanitization
            return bleach.clean(text, tags=[], strip=True)
    
    @staticmethod
    def sanitize_notes(text: Optional[str], max_length: Optional[int] = None) -> Optional[str]:
        """
        Sanitize notes field (strict - no HTML allowed)
        
        Args:
            text: Notes text to sanitize
            max_length: Optional maximum length
            
        Returns:
            Sanitized notes
        """
        return HTMLSanitizationService.sanitize(
            text,
            level=SanitizationLevel.STRICT,
            max_length=max_length
        )
    
    @staticmethod
    def sanitize_description(text: Optional[str], max_length: Optional[int] = None) -> Optional[str]:
        """
        Sanitize description field (strict - no HTML allowed)
        
        Args:
            text: Description text to sanitize
            max_length: Optional maximum length
            
        Returns:
            Sanitized description
        """
        return HTMLSanitizationService.sanitize(
            text,
            level=SanitizationLevel.STRICT,
            max_length=max_length
        )
    
    @staticmethod
    def sanitize_title(text: Optional[str], max_length: Optional[int] = None) -> Optional[str]:
        """
        Sanitize title field (strict - no HTML allowed)
        
        Args:
            text: Title text to sanitize
            max_length: Optional maximum length
            
        Returns:
            Sanitized title
        """
        return HTMLSanitizationService.sanitize(
            text,
            level=SanitizationLevel.STRICT,
            max_length=max_length
        )
    
    @staticmethod
    def sanitize_message(text: Optional[str], max_length: Optional[int] = None) -> Optional[str]:
        """
        Sanitize message field (strict - no HTML allowed)
        
        Args:
            text: Message text to sanitize
            max_length: Optional maximum length
            
        Returns:
            Sanitized message
        """
        return HTMLSanitizationService.sanitize(
            text,
            level=SanitizationLevel.STRICT,
            max_length=max_length
        )
    
    @staticmethod
    def sanitize_rich_text(text: Optional[str], max_length: Optional[int] = None) -> Optional[str]:
        """
        Sanitize rich text field (moderate - basic formatting allowed)
        
        Args:
            text: Rich text to sanitize
            max_length: Optional maximum length
            
        Returns:
            Sanitized rich text
        """
        return HTMLSanitizationService.sanitize(
            text,
            level=SanitizationLevel.MODERATE,
            max_length=max_length
        )

