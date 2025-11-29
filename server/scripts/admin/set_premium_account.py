"""
Script to set a user account to premium status
Usage: python scripts/admin/set_premium_account.py <user_email>
"""

import sys
import os
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from supabase import create_client, Client
from app.core.config import settings
from datetime import datetime, timezone
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_supabase_client() -> Client:
    """
    Get Supabase client with service role key for admin operations
    """
    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key
    )


def set_user_to_premium(user_email: str) -> bool:
    """
    Set a user account to premium status
    
    Args:
        user_email: Email address of the user to upgrade
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Initialize Supabase client with service role key for admin operations
        supabase = get_supabase_client()
        
        # Find user by email
        user_response = supabase.table("users").select("id, email, role").eq("email", user_email).execute()
        
        if not user_response.data:
            logger.error(f"❌ User with email {user_email} not found")
            return False
        
        user = user_response.data[0]
        user_id = user["id"]
        current_role = user.get("role", "free")
        
        if current_role == "premium":
            logger.info(f"✅ User {user_email} is already premium")
            return True
        
        # Update user role to premium
        update_response = supabase.table("users").update({
            "role": "premium",
            "updated_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", user_id).execute()
        
        # Verify the update
        verify_response = supabase.table("users").select("role").eq("id", user_id).execute()
        
        if verify_response.data and verify_response.data[0].get("role") == "premium":
            logger.info(f"✅ Successfully set user {user_email} (ID: {user_id}) to premium")
            logger.info(f"🛡️ This account is now protected from RevenueCat downgrades (premium without active subscription)")
            return True
        else:
            logger.error(f"❌ Failed to verify premium status for user {user_email}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error setting user to premium: {str(e)}", exc_info=True)
        return False


def set_user_by_id_to_premium(user_id: str) -> bool:
    """
    Set a user account to premium status by user ID
    
    Args:
        user_id: UUID of the user to upgrade
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Initialize Supabase client with service role key for admin operations
        supabase = get_supabase_client()
        
        # Check if user exists
        user_response = supabase.table("users").select("id, email, role").eq("id", user_id).execute()
        
        if not user_response.data:
            logger.error(f"❌ User with ID {user_id} not found")
            return False
        
        user = user_response.data[0]
        user_email = user.get("email", "unknown")
        current_role = user.get("role", "free")
        
        if current_role == "premium":
            logger.info(f"✅ User {user_email} (ID: {user_id}) is already premium")
            return True
        
        # Update user role to premium
        update_response = supabase.table("users").update({
            "role": "premium",
            "updated_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", user_id).execute()
        
        # Verify the update
        verify_response = supabase.table("users").select("role").eq("id", user_id).execute()
        
        if verify_response.data and verify_response.data[0].get("role") == "premium":
            logger.info(f"✅ Successfully set user {user_email} (ID: {user_id}) to premium")
            logger.info(f"🛡️ This account is now protected from RevenueCat downgrades (premium without active subscription)")
            return True
        else:
            logger.error(f"❌ Failed to verify premium status for user {user_id}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error setting user to premium: {str(e)}", exc_info=True)
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/admin/set_premium_account.py <user_email_or_id>")
        print("Example: python scripts/admin/set_premium_account.py user@example.com")
        print("Example: python scripts/admin/set_premium_account.py 123e4567-e89b-12d3-a456-426614174000")
        sys.exit(1)
    
    identifier = sys.argv[1]
    
    # Check if it looks like a UUID (contains hyphens and is long)
    if len(identifier) > 30 and "-" in identifier:
        success = set_user_by_id_to_premium(identifier)
    else:
        success = set_user_to_premium(identifier)
    
    sys.exit(0 if success else 1)

