"""
User-Friendly Error Messages Service

Provides user-friendly, actionable error messages instead of technical error messages.
Follows best practices for error messaging: clear, helpful, and actionable.

Follows SOLID principles with single responsibility for error message translation.
Implements DRY by centralizing error message logic.
Follows KISS by providing simple, clear API.
"""

from typing import Optional, Dict, Any
import logging

logger = logging.getLogger(__name__)


class UserFriendlyErrorMessages:
    """
    Service for converting technical error messages to user-friendly ones
    
    Provides context-aware error messages that are:
    - Clear and easy to understand
    - Actionable (tell users what they can do)
    - Helpful (provide guidance)
    - Non-technical (avoid jargon)
    """
    
    # Common error message mappings
    ERROR_MESSAGES: Dict[str, str] = {
        # Authentication & Authorization
        "access denied": "You don't have permission to perform this action. Please contact support if you believe this is an error.",
        "authentication required": "Please sign in to continue.",
        "invalid token": "Your session has expired. Please sign in again.",
        "token expired": "Your session has expired. Please sign in again.",
        "unauthorized": "Please sign in to access this feature.",
        "forbidden": "You don't have permission to access this resource.",
        
        # Validation Errors
        "validation error": "Please check your input and try again.",
        "invalid request data": "The information you provided is invalid. Please check and try again.",
        "invalid input provided": "Please check your input and make sure all required fields are filled correctly.",
        "required field missing": "Please fill in all required fields.",
        "invalid format": "The format is incorrect. Please check and try again.",
        
        # Not Found Errors
        "not found": "The item you're looking for doesn't exist or has been removed.",
        "scan not found": "This scan could not be found. It may have been deleted.",
        "pet not found": "This pet profile could not be found.",
        "user not found": "This user account could not be found.",
        "health event not found": "This health event could not be found.",
        "medication reminder not found": "This medication reminder could not be found.",
        "subscription not found": "No subscription found for your account.",
        
        # Subscription Errors
        "failed to verify subscription": "We couldn't verify your subscription. Please try again or contact support.",
        "failed to fetch subscription status": "We couldn't check your subscription status. Please try again in a moment.",
        "failed to restore purchases": "We couldn't restore your purchases. Please try again or contact support.",
        "only admin users can set bypass subscription flags": "This action requires administrator privileges.",
        "failed to set bypass subscription flag": "We couldn't update the subscription settings. Please try again.",
        
        # Database Errors
        "database error": "We're experiencing technical difficulties. Please try again in a moment.",
        "connection error": "We couldn't connect to our servers. Please check your internet connection and try again.",
        
        # Network/Server Errors
        "internal server error": "Something went wrong on our end. Please try again in a moment.",
        "service unavailable": "This service is temporarily unavailable. Please try again later.",
        "timeout": "The request took too long. Please try again.",
        "request timeout": "Your request took too long to process. Please try again.",
        
        # File/Upload Errors
        "file too large": "The file is too large. Please choose a smaller file.",
        "invalid file type": "This file type is not supported. Please choose a different file.",
        "upload failed": "We couldn't upload your file. Please try again.",
        
        # Rate Limiting
        "rate limit exceeded": "You've made too many requests. Please wait a moment and try again.",
        "too many requests": "You're making requests too quickly. Please slow down and try again.",
        
        # Generic Errors
        "an unexpected error occurred": "Something unexpected happened. Please try again, and if the problem persists, contact support.",
        "operation failed": "The operation couldn't be completed. Please try again.",
        "failed": "The operation failed. Please try again.",
    }
    
    # Context-specific error messages
    CONTEXT_MESSAGES: Dict[str, Dict[str, str]] = {
        "subscription": {
            "verify": "We couldn't verify your subscription. Please check your payment method or contact support.",
            "status": "We couldn't check your subscription status. Please try again in a moment.",
            "restore": "We couldn't restore your purchases. Please make sure you're signed in with the correct account.",
        },
        "scan": {
            "not_found": "This scan could not be found. It may have been deleted or you may not have access to it.",
            "processing": "Your scan is still being processed. Please wait a moment and try again.",
            "failed": "We couldn't process your scan. Please try scanning again.",
        },
        "pet": {
            "not_found": "This pet profile could not be found. It may have been deleted.",
            "create": "We couldn't create the pet profile. Please check your information and try again.",
            "update": "We couldn't update the pet profile. Please try again.",
        },
        "health_event": {
            "not_found": "This health event could not be found. It may have been deleted.",
            "create": "We couldn't create the health event. Please check your information and try again.",
            "update": "We couldn't update the health event. Please try again.",
        },
        "medication": {
            "not_found": "This medication reminder could not be found. It may have been deleted.",
            "create": "We couldn't create the medication reminder. Please check your information and try again.",
            "update": "We couldn't update the medication reminder. Please try again.",
        },
    }
    
    @classmethod
    def get_user_friendly_message(
        cls,
        error_message: str,
        context: Optional[str] = None,
        action: Optional[str] = None
    ) -> str:
        """
        Convert technical error message to user-friendly message
        
        Args:
            error_message: Original technical error message
            context: Optional context (e.g., "subscription", "scan", "pet")
            action: Optional action (e.g., "create", "update", "verify")
            
        Returns:
            User-friendly error message
        """
        if not error_message:
            return "An unexpected error occurred. Please try again."
        
        # Normalize error message (lowercase, strip)
        normalized = error_message.lower().strip()
        
        # Try context-specific message first
        if context and action:
            context_key = f"{context}.{action}"
            if context in cls.CONTEXT_MESSAGES:
                if action in cls.CONTEXT_MESSAGES[context]:
                    return cls.CONTEXT_MESSAGES[context][action]
        
        # Try exact match
        if normalized in cls.ERROR_MESSAGES:
            return cls.ERROR_MESSAGES[normalized]
        
        # Try partial match (check if any key is contained in the message)
        for key, friendly_message in cls.ERROR_MESSAGES.items():
            if key in normalized:
                return friendly_message
        
        # Try context-specific partial match
        if context:
            if context in cls.CONTEXT_MESSAGES:
                for action_key, friendly_message in cls.CONTEXT_MESSAGES[context].items():
                    if action_key in normalized:
                        return friendly_message
        
        # Default: return original message if no match found
        # In production, we might want to return a generic message instead
        logger.debug(f"No user-friendly message found for: {error_message}")
        return error_message
    
    @classmethod
    def enhance_validation_error(
        cls,
        field_name: str,
        error_type: str,
        provided_value: Optional[Any] = None
    ) -> str:
        """
        Create user-friendly validation error message
        
        Args:
            field_name: Name of the field with error
            error_type: Type of validation error
            provided_value: Optional value that was provided
            
        Returns:
            User-friendly validation error message
        """
        # Human-readable field names
        field_display_names: Dict[str, str] = {
            "email": "email address",
            "password": "password",
            "username": "username",
            "pet_id": "pet",
            "user_id": "user",
            "weight_kg": "weight",
            "birthday": "birthday",
            "name": "name",
            "title": "title",
            "notes": "notes",
            "description": "description",
        }
        
        display_name = field_display_names.get(field_name, field_name.replace("_", " "))
        
        # Error type mappings
        if "required" in error_type.lower() or "missing" in error_type.lower():
            return f"Please provide a {display_name}."
        
        if "invalid" in error_type.lower():
            return f"The {display_name} you provided is invalid. Please check and try again."
        
        if "too_long" in error_type.lower() or "max_length" in error_type.lower():
            return f"The {display_name} is too long. Please shorten it and try again."
        
        if "too_short" in error_type.lower() or "min_length" in error_type.lower():
            return f"The {display_name} is too short. Please make it longer and try again."
        
        if "not_found" in error_type.lower():
            return f"The {display_name} could not be found."
        
        if "already_exists" in error_type.lower() or "duplicate" in error_type.lower():
            return f"This {display_name} already exists. Please choose a different one."
        
        # Generic validation error
        return f"Please check the {display_name} and make sure it's correct."

