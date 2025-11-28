"""
GDPR compliance service for data export and deletion
"""

from app.utils.logging_config import get_logger
import json
import zipfile
import io
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from app.shared.services.datetime_service import DateTimeService
from fastapi import HTTPException, status
from app.core.config import settings
from app.database import get_supabase_client
from app.database import get_supabase_service_role_client
from app.shared.services.database_operation_service import DatabaseOperationService

logger = get_logger(__name__)

class GDPRService:
    """Service for GDPR compliance operations"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
        # Use centralized service role client for admin operations
        try:
            self.service_supabase = get_supabase_service_role_client()
        except Exception as e:
            logger.error(f"Failed to get service role client: {e}")
            # Fallback to regular client if service role fails
            self.service_supabase = self.supabase
    
    def export_user_data(self, user_id: str) -> bytes:
        """
        Export all user data in GDPR-compliant format
        
        Args:
            user_id: User ID
            
        Returns:
            ZIP file containing user data
            
        Raises:
            HTTPException: If export fails
        """
        try:
            # Create in-memory ZIP file
            zip_buffer = io.BytesIO()
            
            with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
                # Export user profile
                user_data = self._export_user_profile(user_id)
                zip_file.writestr("user_profile.json", json.dumps(user_data, indent=2))
                
                # Export pets
                pets_data = self._export_pets(user_id)
                zip_file.writestr("pets.json", json.dumps(pets_data, indent=2))
                
                # Export scans
                scans_data = self._export_scans(user_id)
                zip_file.writestr("scans.json", json.dumps(scans_data, indent=2))
                
                # Export favorites
                favorites_data = self._export_favorites(user_id)
                zip_file.writestr("favorites.json", json.dumps(favorites_data, indent=2))
                
                # Export audit logs
                audit_data = self._export_audit_logs(user_id)
                zip_file.writestr("audit_logs.json", json.dumps(audit_data, indent=2))
                
                # Create manifest
                manifest = {
                    "export_date": DateTimeService.now_iso(),
                    "user_id": user_id,
                    "data_retention_days": settings.data_retention_days,
                    "files": [
                        "user_profile.json",
                        "pets.json", 
                        "scans.json",
                        "favorites.json",
                        "audit_logs.json"
                    ],
                    "gdpr_compliance": {
                        "data_subject": user_id,
                        "data_controller": "SniffTest",
                        "legal_basis": "Consent",
                        "purpose": "Pet food ingredient analysis and allergy management"
                    }
                }
                zip_file.writestr("manifest.json", json.dumps(manifest, indent=2))
            
            zip_buffer.seek(0)
            return zip_buffer.getvalue()
            
        except Exception as e:
            logger.error(f"Failed to export user data for {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to export user data"
            )
    
    def delete_user_data(self, user_id: str) -> bool:
        """
        Delete all user data (Right to be Forgotten)
        
        Args:
            user_id: User ID
            
        Returns:
            True if deletion successful
            
        Raises:
            HTTPException: If deletion fails
        """
        try:
            # Log deletion request
            self._log_deletion_request(user_id)
            
            # Get user and pet data before deletion for image cleanup
            user_data = self.supabase.table("users").select("image_url").eq("id", user_id).execute()
            pets_data = self.supabase.table("pets").select("image_url").eq("user_id", user_id).execute()
            
            # Delete user data in order (respecting foreign key constraints)
            # 1. Delete scans
            self.supabase.table("scans").delete().eq("user_id", user_id).execute()
            
            # 2. Delete favorites
            self.supabase.table("favorites").delete().eq("user_id", user_id).execute()
            
            # 3. Delete pets
            self.supabase.table("pets").delete().eq("user_id", user_id).execute()
            
            # 4. Delete user profile
            self.supabase.table("users").delete().eq("id", user_id).execute()
            
            # 5. Delete audit logs
            self.supabase.table("user_activities").delete().eq("user_id", user_id).execute()
            
            # 6. Delete security events
            self.supabase.table("security_events").delete().eq("user_id", user_id).execute()
            
            # 7. Delete from Supabase Auth
            self.service_supabase.auth.admin.delete_user(user_id)
            
            # 8. Delete user and pet images from storage
            self._delete_user_images_from_storage(user_data.data, pets_data.data)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to delete user data for {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete user data"
            )
    
    def anonymize_user_data(self, user_id: str) -> bool:
        """
        Anonymize user data while preserving functionality
        
        Args:
            user_id: User ID
            
        Returns:
            True if anonymization successful
            
        Raises:
            HTTPException: If anonymization fails
        """
        try:
            # Generate anonymous ID
            anonymous_id = f"anon_{user_id[:8]}_{DateTimeService.now().strftime('%Y%m%d')}"
            
            # Anonymize user profile using centralized service
            db_service = DatabaseOperationService(self.supabase)
            await db_service.update_with_timestamp(
                "users",
                user_id,
                {
                    "email": f"anonymous_{anonymous_id}@deleted.local",
                    "first_name": "Anonymous",
                    "last_name": "User"
                }
            )
            
            # Anonymize pets - need to get pet IDs first
            pets_response = self.supabase.table("pets").select("id").eq("user_id", user_id).execute()
            if pets_response.data:
                for pet in pets_response.data:
                    await db_service.update_with_timestamp(
                        "pets",
                        pet["id"],
                        {
                            "name": "Anonymous Pet",
                            "vet_name": None,
                            "vet_phone": None
                        }
                    )
            
            # Anonymize scans - need to get scan IDs first
            scans_response = self.supabase.table("scans").select("id").eq("user_id", user_id).execute()
            if scans_response.data:
                for scan in scans_response.data:
                    await db_service.update_with_timestamp(
                        "scans",
                        scan["id"],
                        {"raw_text": "[ANONYMIZED]"}
                    )
            
            # Anonymize favorites - need to get favorite IDs first
            favorites_response = self.supabase.table("favorites").select("id").eq("user_id", user_id).execute()
            if favorites_response.data:
                for favorite in favorites_response.data:
                    await db_service.update_with_timestamp(
                        "favorites",
                        favorite["id"],
                        {
                            "product_name": "[ANONYMIZED]",
                            "brand": "[ANONYMIZED]",
                            "notes": None
                        }
                    )
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to anonymize user data for {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to anonymize user data"
            )
    
    def get_data_retention_info(self, user_id: str) -> Dict[str, Any]:
        """
        Get data retention information for a user
        
        Args:
            user_id: User ID
            
        Returns:
            Data retention information
            
        Raises:
            HTTPException: If retrieval fails
        """
        try:
            # First try to get user from public.users table
            user_response = self.supabase.table("users").select("created_at").eq("id", user_id).execute()
            
            if not user_response.data:
                # If user doesn't exist in public.users, try to get from auth.users
                try:
                    # Add timeout and retry logic for auth operations
                    import time
                    max_auth_retries = 3
                    auth_user = None
                    
                    for attempt in range(max_auth_retries):
                        try:
                            auth_user = self.service_supabase.auth.admin.get_user_by_id(user_id)
                            break
                        except Exception as auth_retry_error:
                            if "handshake operation timed out" in str(auth_retry_error).lower():
                                logger.warning(f"Auth handshake timeout on attempt {attempt + 1}, retrying...")
                                if attempt < max_auth_retries - 1:
                                    time.sleep(2 ** attempt)  # Exponential backoff
                                    continue
                            raise auth_retry_error
                    
                    if auth_user and auth_user.user:
                        # Convert datetime to ISO string for database insertion
                        created_at_str = auth_user.user.created_at.isoformat() if hasattr(auth_user.user.created_at, 'isoformat') else str(auth_user.user.created_at)
                        
                        # Upsert user record in public.users using centralized service
                        user_data = {
                            "id": user_id,
                            "email": auth_user.user.email,
                            "first_name": auth_user.user.user_metadata.get("first_name"),
                            "last_name": auth_user.user.user_metadata.get("last_name"),
                            "username": auth_user.user.user_metadata.get("username"),
                            "role": auth_user.user.user_metadata.get("role", "free"),
                            "created_at": created_at_str,
                            "onboarded": False,
                            "image_url": None
                        }
                        db_service = DatabaseOperationService(self.service_supabase)
                        await db_service.upsert_with_timestamps("users", user_data, conflict_column="id", include_created_at=False)
                        created_at = datetime.fromisoformat(created_at_str.replace('Z', '+00:00'))
                    else:
                        raise HTTPException(
                            status_code=status.HTTP_404_NOT_FOUND,
                            detail="User not found"
                        )
                except Exception as auth_error:
                    logger.error(f"Failed to get user from auth: {auth_error}")
                    # If it's a duplicate key error, try to fetch the existing user
                    if "duplicate key" in str(auth_error).lower():
                        try:
                            existing_user = self.supabase.table("users").select("created_at").eq("id", user_id).execute()
                            if existing_user.data:
                                created_at = datetime.fromisoformat(existing_user.data[0]["created_at"])
                            else:
                                raise HTTPException(
                                    status_code=status.HTTP_404_NOT_FOUND,
                                    detail="User not found"
                                )
                        except Exception as fetch_error:
                            logger.error(f"Failed to fetch existing user: {fetch_error}")
                            raise HTTPException(
                                status_code=status.HTTP_404_NOT_FOUND,
                                detail="User not found"
                            )
                    # If it's a timeout or SSL error, try to create a minimal user record
                    elif any(error_type in str(auth_error).lower() for error_type in ["timeout", "handshake", "ssl", "connection"]):
                        logger.warning("Auth service unavailable, creating minimal user record with current timestamp")
                        try:
                            # Create a minimal user record with current timestamp using centralized service
                            user_data = {
                                "id": user_id,
                                "email": f"user_{user_id[:8]}@temp.local",
                                "first_name": "Unknown",
                                "last_name": "User",
                                "username": f"user_{user_id[:8]}",
                                "role": "free",
                                "onboarded": False,
                                "image_url": None
                            }
                            db_service = DatabaseOperationService(self.service_supabase)
                            await db_service.upsert_with_timestamps("users", user_data, conflict_column="id")
                            created_at = DateTimeService.now()
                        except Exception as create_error:
                            logger.error(f"Failed to create minimal user record: {create_error}")
                            raise HTTPException(
                                status_code=status.HTTP_404_NOT_FOUND,
                                detail="User not found and unable to create user record"
                            )
                    else:
                        raise HTTPException(
                            status_code=status.HTTP_404_NOT_FOUND,
                            detail="User not found"
                        )
            else:
                created_at = datetime.fromisoformat(user_response.data[0]["created_at"])
            
            retention_date = created_at + timedelta(days=settings.data_retention_days)
            
            # Check if data should be deleted (ensure both datetimes are timezone-aware)
            current_time = DateTimeService.now().replace(tzinfo=None)  # Make timezone-naive
            retention_date_naive = retention_date.replace(tzinfo=None) if retention_date.tzinfo else retention_date
            should_delete = current_time > retention_date_naive
            
            retention_info = {
                "user_id": user_id,
                "created_at": created_at.isoformat(),
                "retention_days": settings.data_retention_days,
                "retention_date": retention_date.isoformat(),
                "should_delete": should_delete,
                "days_until_deletion": max(0, (retention_date_naive - current_time).days),
                "legal_basis": "Consent",
                "purpose": "Pet food ingredient analysis and allergy management",
                "data_categories": [
                    "Personal information (name, email)",
                    "Pet profiles and medical information",
                    "Scan results and analysis",
                    "Usage patterns and preferences"
                ],
                # iOS-compatible fields
                "data_types": [
                    "Personal information (name, email)",
                    "Pet profiles and medical information", 
                    "Scan results and analysis",
                    "Usage patterns and preferences"
                ],
                "last_updated": current_time.isoformat(),
                "policy_version": "1.0"
            }
            
            return retention_info
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to get retention info for {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get retention information"
            )
    
    def _export_user_profile(self, user_id: str) -> Dict[str, Any]:
        """Export user profile data"""
        try:
            response = self.supabase.table("users").select("*").eq("id", user_id).execute()
            return response.data[0] if response.data else {}
        except Exception as e:
            logger.error(f"Failed to export user profile for {user_id}: {e}")
            return {}
    
    def _export_pets(self, user_id: str) -> List[Dict[str, Any]]:
        """Export pets data"""
        try:
            response = self.supabase.table("pets").select("*").eq("user_id", user_id).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Failed to export pets for {user_id}: {e}")
            return []
    
    def _export_scans(self, user_id: str) -> List[Dict[str, Any]]:
        """Export scans data"""
        try:
            response = self.supabase.table("scans").select("*").eq("user_id", user_id).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Failed to export scans for {user_id}: {e}")
            return []
    
    def _export_favorites(self, user_id: str) -> List[Dict[str, Any]]:
        """Export favorites data"""
        try:
            response = self.supabase.table("favorites").select("*").eq("user_id", user_id).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Failed to export favorites for {user_id}: {e}")
            return []
    
    def _export_audit_logs(self, user_id: str) -> List[Dict[str, Any]]:
        """Export audit logs"""
        try:
            response = self.supabase.table("user_activities").select("*").eq("user_id", user_id).execute()
            return response.data or []
        except Exception as e:
            logger.error(f"Failed to export audit logs for {user_id}: {e}")
            return []
    
    def _log_deletion_request(self, user_id: str):
        """Log data deletion request"""
        try:
            deletion_log = {
                "timestamp": DateTimeService.now_iso(),
                "user_id": user_id,
                "action": "data_deletion_request",
                "legal_basis": "GDPR Article 17 - Right to erasure",
                "status": "initiated"
            }
            
            db_service = DatabaseOperationService(self.supabase)
            await db_service.insert_with_timestamps("gdpr_requests", deletion_log)
            
        except Exception as e:
            logger.error(f"Failed to log deletion request for {user_id}: {e}")
    
    def _delete_user_images_from_storage(self, user_data: list, pets_data: list):
        """
        Delete user and pet images from Supabase Storage
        
        Args:
            user_data: List of user data with image URLs
            pets_data: List of pet data with image URLs
        """
        try:
            # Delete user profile images
            for user in user_data:
                if user.get("image_url"):
                    image_url = user["image_url"]
                    if "storage/v1/object/public/user-images/" in image_url:
                        # Extract the storage path from the full URL
                        storage_path = image_url.split("/storage/v1/object/public/user-images/")[-1]
                        try:
                            self.supabase.storage.from_("user-images").remove([storage_path])
                        except Exception as e:
                            logger.warning(f"Failed to delete user image {storage_path}: {e}")
            
            # Delete pet images
            for pet in pets_data:
                if pet.get("image_url"):
                    image_url = pet["image_url"]
                    if "storage/v1/object/public/pet-images/" in image_url:
                        # Extract the storage path from the full URL
                        storage_path = image_url.split("/storage/v1/object/public/pet-images/")[-1]
                        try:
                            self.supabase.storage.from_("pet-images").remove([storage_path])
                        except Exception as e:
                            logger.warning(f"Failed to delete pet image {storage_path}: {e}")
                            
        except Exception as e:
            logger.error(f"Failed to delete images from storage: {e}")
    
    def cleanup_expired_data(self):
        """
        Clean up data that has exceeded retention period
        
        This should be run as a scheduled task
        """
        try:
            cutoff_date = DateTimeService.now() - timedelta(days=settings.data_retention_days)
            
            # Find users with expired data
            expired_users = self.supabase.table("users").select("id").lt("created_at", cutoff_date.isoformat()).execute()
            
            for user in expired_users.data:
                user_id = user["id"]
                
                # Anonymize instead of delete for research purposes
                self.anonymize_user_data(user_id)
            
            
        except Exception as e:
            logger.error(f"Failed to cleanup expired data: {e}")
