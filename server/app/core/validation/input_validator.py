"""
Input validation and sanitization utilities

Extracted from app.utils.security.SecurityValidator
Follows Single Responsibility Principle: Input validation only
"""

import re
import html
import bleach
import logging
from typing import Optional, Dict, Any
from fastapi import HTTPException, status

from .security_patterns import (
    DANGEROUS_PATTERNS,
    SQL_INJECTION_PATTERNS,
    INAPPROPRIATE_WORDS,
    RESERVED_USERNAMES,
    WEAK_PASSWORDS,
    OBFUSCATION_PATTERNS
)

logger = logging.getLogger(__name__)


class InputValidator:
    """Input validation and sanitization utilities"""
    
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
        for pattern in DANGEROUS_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                logger.warning(f"Dangerous pattern detected in text: {pattern}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Input contains potentially dangerous content"
                )
        
        # Check for SQL injection patterns
        for pattern in SQL_INJECTION_PATTERNS:
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
        if password.lower() in WEAK_PASSWORDS:
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
    def validate_username(cls, username: str) -> str:
        """
        Validate and sanitize username with profanity filtering
        
        Args:
            username: Username to validate
            
        Returns:
            Sanitized username
            
        Raises:
            HTTPException: If username is invalid or contains inappropriate content
        """
        if not username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username is required"
            )
        
        # Check length
        if len(username) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must be at least 3 characters long"
            )
        
        if len(username) > 30:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must be less than 30 characters"
            )
        
        # Check for valid characters (alphanumeric, underscore, hyphen)
        if not re.match(r'^[a-zA-Z0-9_-]+$', username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username can only contain letters, numbers, underscores, and hyphens"
            )
        
        # Check if starts with letter or number
        if not re.match(r'^[a-zA-Z0-9]', username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username must start with a letter or number"
            )
        
        # Check for profanity and inappropriate content
        if cls._contains_inappropriate_content(username):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username contains inappropriate content. Please choose a different username."
            )
        
        # Check for reserved usernames
        if username.lower() in RESERVED_USERNAMES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This username is reserved and cannot be used"
            )
        
        # Sanitize username
        sanitized_username = cls.sanitize_text(username.lower(), max_length=30)
        
        return sanitized_username
    
    @classmethod
    def _contains_inappropriate_content(cls, text: str) -> bool:
        """
        Check if text contains profanity or inappropriate content
        
        Args:
            text: Text to check
            
        Returns:
            True if inappropriate content is found
        """
        text_lower = text.lower()
        
        # Check for exact matches
        for word in INAPPROPRIATE_WORDS:
            if word in text_lower:
                return True
        
        # Check for obfuscated patterns
        normalized_text = text_lower
        for pattern, replacement in OBFUSCATION_PATTERNS:
            normalized_text = re.sub(pattern, replacement, normalized_text)
        
        # Check normalized text
        for word in INAPPROPRIATE_WORDS:
            if word in normalized_text:
                return True
        
        # Check for repeated characters
        repeated_pattern = r'(.)\1{2,}'
        if re.search(repeated_pattern, text_lower):
            for word in INAPPROPRIATE_WORDS:
                if len(word) > 2:
                    repeated_word = ''.join([char + '{1,}' for char in word])
                    if re.search(repeated_word, text_lower):
                        return True
        
        return False
    
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
                if len(obj) > 1000:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Array too large"
                    )
                
                for item in obj:
                    check_depth(item, current_depth + 1)
            elif isinstance(obj, str):
                if len(obj) > 10000:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="String too long"
                    )
        
        check_depth(data)
        return data
    
    @classmethod
    def validate_user_login(cls, login_data) -> Dict[str, Any]:
        """
        Validate user login data (email only)
        
        Args:
            login_data: Login data to validate
            
        Returns:
            Validation result with is_valid flag and errors list
        """
        errors = []
        
        # Validate email (login only accepts email, not username)
        try:
            cls.validate_email(login_data.email_or_username)
        except HTTPException as e:
            errors.append(f"Email: {e.detail}")
        
        # Validate password (basic check, not full strength validation for login)
        if not login_data.password:
            errors.append("Password is required")
        elif len(login_data.password) < 1:
            errors.append("Password cannot be empty")
        
        return {
            "is_valid": len(errors) == 0,
            "errors": errors
        }
    
    @classmethod
    def validate_user_create(cls, user_data) -> Dict[str, Any]:
        """
        Validate user creation data
        
        Args:
            user_data: User creation data to validate
            
        Returns:
            Validation result with is_valid flag and errors list
        """
        errors = []
        
        # Validate email
        try:
            cls.validate_email(user_data.email)
        except HTTPException as e:
            errors.append(f"Email: {e.detail}")
        
        # Validate password
        try:
            cls.validate_password(user_data.password)
        except HTTPException as e:
            errors.append(f"Password: {e.detail}")
        
        # Validate username if provided
        if hasattr(user_data, 'username') and user_data.username:
            try:
                cls.validate_username(user_data.username)
            except HTTPException as e:
                errors.append(f"Username: {e.detail}")
        
        return {
            "is_valid": len(errors) == 0,
            "errors": errors
        }
    
    @classmethod
    def validate_user_update(cls, user_update) -> Dict[str, Any]:
        """
        Validate user update data
        
        Args:
            user_update: User update data to validate
            
        Returns:
            Validation result with is_valid flag and errors list
        """
        errors = []
        
        # Validate email if provided
        if hasattr(user_update, 'email') and user_update.email:
            try:
                cls.validate_email(user_update.email)
            except HTTPException as e:
                errors.append(f"Email: {e.detail}")
        
        # Validate username if provided
        if hasattr(user_update, 'username') and user_update.username:
            try:
                cls.validate_username(user_update.username)
            except HTTPException as e:
                errors.append(f"Username: {e.detail}")
        
        # Validate phone if provided
        if hasattr(user_update, 'phone') and user_update.phone:
            try:
                cls.validate_phone_number(user_update.phone)
            except HTTPException as e:
                errors.append(f"Phone: {e.detail}")
        
        return {
            "is_valid": len(errors) == 0,
            "errors": errors
        }


# Backward compatibility alias
SecurityValidator = InputValidator
