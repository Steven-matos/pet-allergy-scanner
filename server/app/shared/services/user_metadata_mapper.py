"""
User metadata mapper service

Centralizes user metadata extraction and mapping.
Eliminates code duplication across authentication flows.

Follows DRY principle: Single source of truth for user metadata handling
"""

from typing import Dict, Any, Optional
from datetime import datetime


class UserMetadataMapper:
    """
    User metadata mapping utilities
    
    Provides consistent methods for extracting and mapping user metadata
    from Supabase auth responses to application user models.
    """
    
    @staticmethod
    def extract_auth_metadata(user_response: Any) -> Dict[str, Any]:
        """
        Extract metadata from Supabase auth user response
        
        Args:
            user_response: Supabase auth user object
            
        Returns:
            Dictionary with standardized user metadata
            
        Example:
            >>> auth_metadata = UserMetadataMapper.extract_auth_metadata(response.user)
            >>> user_data = await get_merged_user_data(user.id, auth_metadata)
        """
        return {
            "email": user_response.email,
            "username": user_response.user_metadata.get("username"),
            "first_name": user_response.user_metadata.get("first_name"),
            "last_name": user_response.user_metadata.get("last_name"),
            "role": user_response.user_metadata.get("role", "free"),
            "created_at": user_response.created_at,
            "updated_at": user_response.updated_at
        }
    
    @staticmethod
    def prepare_user_insert_data(user_response: Any) -> Dict[str, Any]:
        """
        Prepare user data for insertion into public.users table
        
        Args:
            user_response: Supabase auth user object
            
        Returns:
            Dictionary ready for database insertion
        """
        return {
            "id": user_response.id,
            "email": user_response.email,
            "username": user_response.user_metadata.get("username"),
            "first_name": user_response.user_metadata.get("first_name"),
            "last_name": user_response.user_metadata.get("last_name"),
            "role": user_response.user_metadata.get("role", "free")
        }
    
    @staticmethod
    def prepare_metadata_update(
        username: Optional[str] = None,
        first_name: Optional[str] = None,
        last_name: Optional[str] = None,
        role: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Prepare user metadata for update operations
        
        Only includes fields that are not None, allowing partial updates.
        
        Args:
            username: Optional new username
            first_name: Optional new first name
            last_name: Optional new last name
            role: Optional new role
            
        Returns:
            Dictionary with only non-None update fields
            
        Example:
            >>> update_data = UserMetadataMapper.prepare_metadata_update(
            ...     first_name="John",
            ...     last_name="Doe"
            ... )
            >>> # Only includes first_name and last_name
        """
        update_data = {}
        
        if username is not None:
            update_data["username"] = username
        if first_name is not None:
            update_data["first_name"] = first_name
        if last_name is not None:
            update_data["last_name"] = last_name
        if role is not None:
            update_data["role"] = role
        
        return update_data
    
    @staticmethod
    def merge_auth_and_public_data(
        auth_metadata: Dict[str, Any],
        public_data: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Merge data from auth.users and public.users tables
        
        Args:
            auth_metadata: Metadata from auth.users
            public_data: Data from public.users table
            
        Returns:
            Merged user data dictionary
        """
        merged = auth_metadata.copy()
        
        if public_data:
            merged["onboarded"] = public_data.get("onboarded", False)
            merged["image_url"] = public_data.get("image_url")
            # Override role from public.users if available (source of truth)
            if "role" in public_data:
                merged["role"] = public_data["role"]
        else:
            merged["onboarded"] = False
            merged["image_url"] = None
        
        return merged
    
    @staticmethod
    def format_full_name(
        first_name: Optional[str], 
        last_name: Optional[str]
    ) -> str:
        """
        Format full name from first and last names
        
        Args:
            first_name: User's first name
            last_name: User's last name
            
        Returns:
            Formatted full name, or empty string if both are None
        """
        parts = []
        if first_name:
            parts.append(first_name)
        if last_name:
            parts.append(last_name)
        return " ".join(parts)

