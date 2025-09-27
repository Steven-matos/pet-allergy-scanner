"""
Security utility functions for input validation and sanitization
"""

import re
import html
import bleach
import logging
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)

class SecurityValidator:
    """Security validation and sanitization utilities"""
    
    # Common dangerous patterns
    DANGEROUS_PATTERNS = [
        r'<script[^>]*>.*?</script>',
        r'javascript:',
        r'vbscript:',
        r'onload\s*=',
        r'onerror\s*=',
        r'onclick\s*=',
        r'eval\s*\(',
        r'expression\s*\(',
        r'url\s*\(',
        r'@import',
        r'behavior\s*:',
        r'-moz-binding',
        r'<iframe[^>]*>',
        r'<object[^>]*>',
        r'<embed[^>]*>',
        r'<link[^>]*>',
        r'<meta[^>]*>',
        r'<style[^>]*>',
        r'<form[^>]*>',
        r'<input[^>]*>',
        r'<textarea[^>]*>',
        r'<select[^>]*>',
        r'<button[^>]*>',
        r'<a[^>]*>',
        r'<img[^>]*>',
        r'<video[^>]*>',
        r'<audio[^>]*>',
        r'<source[^>]*>',
        r'<track[^>]*>',
        r'<canvas[^>]*>',
        r'<svg[^>]*>',
        r'<math[^>]*>',
        r'<applet[^>]*>',
        r'<param[^>]*>',
        r'<base[^>]*>',
        r'<area[^>]*>',
        r'<map[^>]*>',
        r'<frame[^>]*>',
        r'<frameset[^>]*>',
        r'<noframes[^>]*>',
        r'<noscript[^>]*>',
        r'<details[^>]*>',
        r'<summary[^>]*>',
        r'<dialog[^>]*>',
        r'<menu[^>]*>',
        r'<menuitem[^>]*>',
        r'<command[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<datalist[^>]*>',
        r'<optgroup[^>]*>',
        r'<option[^>]*>',
        r'<fieldset[^>]*>',
        r'<legend[^>]*>',
        r'<label[^>]*>',
        r'<datalist[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<details[^>]*>',
        r'<summary[^>]*>',
        r'<dialog[^>]*>',
        r'<menu[^>]*>',
        r'<menuitem[^>]*>',
        r'<command[^>]*>',
        r'<keygen[^>]*>',
        r'<output[^>]*>',
        r'<progress[^>]*>',
        r'<meter[^>]*>',
        r'<datalist[^>]*>',
        r'<optgroup[^>]*>',
        r'<option[^>]*>',
        r'<fieldset[^>]*>',
        r'<legend[^>]*>',
        r'<label[^>]*>'
    ]
    
    # SQL injection patterns
    SQL_INJECTION_PATTERNS = [
        r'union\s+select',
        r'select\s+.*\s+from',
        r'insert\s+into',
        r'update\s+.*\s+set',
        r'delete\s+from',
        r'drop\s+table',
        r'create\s+table',
        r'alter\s+table',
        r'exec\s*\(',
        r'execute\s*\(',
        r'sp_',
        r'xp_',
        r'--',
        r'/\*.*\*/',
        r'waitfor\s+delay',
        r'benchmark\s*\(',
        r'sleep\s*\(',
        r'pg_sleep\s*\(',
        r'load_file\s*\(',
        r'into\s+outfile',
        r'into\s+dumpfile',
        r'load\s+data\s+infile',
        r'\.\./',
        r'\.\.\\',
        r'char\s*\(',
        r'ascii\s*\(',
        r'ord\s*\(',
        r'chr\s*\(',
        r'concat\s*\(',
        r'substring\s*\(',
        r'substr\s*\(',
        r'mid\s*\(',
        r'left\s*\(',
        r'right\s*\(',
        r'length\s*\(',
        r'len\s*\(',
        r'count\s*\(',
        r'sum\s*\(',
        r'avg\s*\(',
        r'min\s*\(',
        r'max\s*\(',
        r'group\s+by',
        r'order\s+by',
        r'having\s+',
        r'where\s+',
        r'and\s+',
        r'or\s+',
        r'not\s+',
        r'like\s+',
        r'in\s*\(',
        r'between\s+',
        r'is\s+null',
        r'is\s+not\s+null',
        r'exists\s*\(',
        r'in\s+\(.*select',
        r'not\s+in\s+\(.*select',
        r'exists\s*\(.*select',
        r'not\s+exists\s*\(.*select',
        r'any\s*\(.*select',
        r'all\s*\(.*select',
        r'some\s*\(.*select',
        r'case\s+when',
        r'if\s*\(',
        r'ifnull\s*\(',
        r'coalesce\s*\(',
        r'nullif\s*\(',
        r'cast\s*\(',
        r'convert\s*\(',
        r'str_to_date\s*\(',
        r'date_format\s*\(',
        r'now\s*\(',
        r'curdate\s*\(',
        r'curtime\s*\(',
        r'year\s*\(',
        r'month\s*\(',
        r'day\s*\(',
        r'hour\s*\(',
        r'minute\s*\(',
        r'second\s*\(',
        r'week\s*\(',
        r'dayofweek\s*\(',
        r'dayofyear\s*\(',
        r'weekday\s*\(',
        r'quarter\s*\(',
        r'last_day\s*\(',
        r'makedate\s*\(',
        r'maketime\s*\(',
        r'period_add\s*\(',
        r'period_diff\s*\(',
        r'to_days\s*\(',
        r'to_seconds\s*\(',
        r'from_days\s*\(',
        r'from_unixtime\s*\(',
        r'unix_timestamp\s*\(',
        r'utc_date\s*\(',
        r'utc_time\s*\(',
        r'utc_timestamp\s*\(',
        r'time_to_sec\s*\(',
        r'sec_to_time\s*\(',
        r'time_format\s*\(',
        r'get_format\s*\(',
        r'date_add\s*\(',
        r'date_sub\s*\(',
        r'adddate\s*\(',
        r'subdate\s*\(',
        r'addtime\s*\(',
        r'subtime\s*\(',
        r'datediff\s*\(',
        r'timediff\s*\(',
        r'from_unixtime\s*\(',
        r'unix_timestamp\s*\(',
        r'utc_date\s*\(',
        r'utc_time\s*\(',
        r'utc_timestamp\s*\(',
        r'time_to_sec\s*\(',
        r'sec_to_time\s*\(',
        r'time_format\s*\(',
        r'get_format\s*\(',
        r'date_add\s*\(',
        r'date_sub\s*\(',
        r'adddate\s*\(',
        r'subdate\s*\(',
        r'addtime\s*\(',
        r'subtime\s*\(',
        r'datediff\s*\(',
        r'timediff\s*\('
    ]
    
    @classmethod
    def sanitize_text(cls, text: str, max_length: Optional[int] = None) -> str:
        """
        Sanitize text input by removing dangerous content
        
        Args:
            text: Input text to sanitize
            max_length: Maximum allowed length
            
        Returns:
            Sanitized text
            
        Raises:
            HTTPException: If text contains dangerous content
        """
        if not text:
            return ""
        
        # Check for dangerous patterns
        text_lower = text.lower()
        for pattern in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.warning(f"Dangerous pattern detected in text: {pattern}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Input contains potentially dangerous content"
                )
        
        # Check for SQL injection patterns
        for pattern in cls.SQL_INJECTION_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.warning(f"SQL injection pattern detected: {pattern}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Input contains potentially malicious content"
                )
        
        # HTML escape
        sanitized = html.escape(text)
        
        # Remove HTML tags
        sanitized = bleach.clean(sanitized, tags=[], strip=True)
        
        # Limit length
        if max_length and len(sanitized) > max_length:
            sanitized = sanitized[:max_length]
        
        return sanitized.strip()
    
    @classmethod
    def validate_email(cls, email: str) -> str:
        """
        Validate and sanitize email address
        
        Args:
            email: Email address to validate
            
        Returns:
            Sanitized email address
            
        Raises:
            HTTPException: If email is invalid
        """
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        
        # Basic email validation
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid email format"
            )
        
        # Sanitize email
        sanitized_email = cls.sanitize_text(email.lower(), max_length=254)
        
        return sanitized_email
    
    @classmethod
    def validate_password(cls, password: str) -> str:
        """
        Validate password strength
        
        Args:
            password: Password to validate
            
        Returns:
            Validated password
            
        Raises:
            HTTPException: If password doesn't meet requirements
        """
        if not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password is required"
            )
        
        if len(password) < 8:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be at least 8 characters long"
            )
        
        if len(password) > 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be less than 128 characters"
            )
        
        # Check for common weak passwords
        weak_passwords = [
            "password", "123456", "123456789", "qwerty", "abc123",
            "password123", "admin", "letmein", "welcome", "monkey"
        ]
        
        if password.lower() in weak_passwords:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password is too common. Please choose a stronger password"
            )
        
        # Check for at least one uppercase, lowercase, digit, and special character
        if not re.search(r'[A-Z]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one uppercase letter"
            )
        
        if not re.search(r'[a-z]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one lowercase letter"
            )
        
        if not re.search(r'\d', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one digit"
            )
        
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must contain at least one special character"
            )
        
        return password
    
    @classmethod
    def validate_phone_number(cls, phone: str) -> str:
        """
        Validate and sanitize phone number
        
        Args:
            phone: Phone number to validate
            
        Returns:
            Sanitized phone number
            
        Raises:
            HTTPException: If phone number is invalid
        """
        if not phone:
            return ""
        
        # Remove all non-digit characters
        digits_only = re.sub(r'\D', '', phone)
        
        # Validate length (7-15 digits is standard)
        if len(digits_only) < 7 or len(digits_only) > 15:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid phone number format"
            )
        
        return digits_only
    
    @classmethod
    def validate_file_upload(cls, filename: str, content_type: str, size: int) -> bool:
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
    
    @classmethod
    def validate_json_input(cls, data: Dict[str, Any], max_depth: int = 10) -> Dict[str, Any]:
        """
        Validate JSON input for security
        
        Args:
            data: JSON data to validate
            max_depth: Maximum nesting depth
            
        Returns:
            Validated data
            
        Raises:
            HTTPException: If data is invalid
        """
        def check_depth(obj, current_depth=0):
            if current_depth > max_depth:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="JSON structure too deep"
                )
            
            if isinstance(obj, dict):
                for key, value in obj.items():
                    # Sanitize keys
                    if not isinstance(key, str):
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Invalid JSON key type"
                        )
                    
                    # Check key length
                    if len(key) > 100:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="JSON key too long"
                        )
                    
                    check_depth(value, current_depth + 1)
            elif isinstance(obj, list):
                if len(obj) > 1000:  # Limit array size
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Array too large"
                    )
                
                for item in obj:
                    check_depth(item, current_depth + 1)
            elif isinstance(obj, str):
                # Sanitize string values
                if len(obj) > 10000:  # Limit string length
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="String too long"
                    )
        
        check_depth(data)
        return data
