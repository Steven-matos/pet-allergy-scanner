"""
Storage service for handling file uploads to Supabase Storage
Manages uploads for user images, pet images, and scan images
"""

from typing import Optional, Tuple
from fastapi import UploadFile, HTTPException, status
from app.database import get_supabase_client
from app.services.image_optimizer import ImageOptimizerService
from app.utils.logging_config import get_logger
import uuid
from datetime import datetime

logger = get_logger(__name__)


class StorageService:
    """Service for managing file uploads to Supabase Storage"""
    
    # Bucket configurations
    BUCKETS = {
        "user_images": {
            "name": "user-images",
            "max_size": 5_242_880,  # 5MB
            "allowed_types": ["image/jpeg", "image/jpg", "image/png", "image/webp"]
        },
        "pet_images": {
            "name": "pet-images",
            "max_size": 5_242_880,  # 5MB
            "allowed_types": ["image/jpeg", "image/jpg", "image/png", "image/webp"]
        },
        "scan_images": {
            "name": "scan-images",
            "max_size": 10_485_760,  # 10MB (larger for OCR scans)
            "allowed_types": ["image/jpeg", "image/jpg", "image/png", "image/webp"]
        }
    }
    
    @classmethod
    async def upload_scan_image(
        cls,
        image_data: bytes,
        user_id: str,
        scan_id: str,
        optimize: bool = True
    ) -> str:
        """
        Upload scan image to storage (only for OCR scans)
        
        Args:
            image_data: Raw image bytes
            user_id: User ID for folder structure
            scan_id: Scan ID for unique filename
            optimize: Whether to optimize image before upload
            
        Returns:
            Public URL of uploaded image
            
        Raises:
            HTTPException: If upload fails or validation fails
        """
        try:
            bucket_config = cls.BUCKETS["scan_images"]
            
            # Validate file size
            if len(image_data) > bucket_config["max_size"]:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Image exceeds maximum size of {bucket_config['max_size'] / 1_048_576:.1f}MB"
                )
            
            # Validate image
            if not ImageOptimizerService.validate_image(image_data):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid image file"
                )
            
            # Optimize image if requested
            upload_data = image_data
            if optimize:
                try:
                    optimized_data, metadata = ImageOptimizerService.optimize_image(
                        image_data,
                        target_size=2_097_152  # 2MB target
                    )
                    upload_data = optimized_data
                    logger.info(f"Scan image optimized: {metadata['size_reduction_percent']}% reduction")
                except Exception as e:
                    logger.warning(f"Image optimization failed, uploading original: {e}")
                    upload_data = image_data
            
            # Generate unique file path
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            file_path = f"{user_id}/scans/{scan_id}_{timestamp}.jpg"
            
            # Upload to Supabase Storage
            supabase = get_supabase_client()
            response = supabase.storage.from_(bucket_config["name"]).upload(
                path=file_path,
                file=upload_data,
                file_options={
                    "content-type": "image/jpeg",
                    "cache-control": "3600",
                    "upsert": "false"
                }
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to upload image to storage"
                )
            
            # Get public URL
            public_url = supabase.storage.from_(bucket_config["name"]).get_public_url(file_path)
            
            logger.info(f"Scan image uploaded successfully: {file_path}")
            return public_url
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Scan image upload failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to upload scan image: {str(e)}"
            )
    
    @classmethod
    async def upload_user_image(
        cls,
        image_data: bytes,
        user_id: str,
        optimize: bool = True
    ) -> str:
        """
        Upload user profile image to storage
        
        Args:
            image_data: Raw image bytes
            user_id: User ID for folder structure
            optimize: Whether to optimize image before upload
            
        Returns:
            Public URL of uploaded image
        """
        try:
            bucket_config = cls.BUCKETS["user_images"]
            
            if len(image_data) > bucket_config["max_size"]:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Image exceeds maximum size of {bucket_config['max_size'] / 1_048_576:.1f}MB"
                )
            
            if not ImageOptimizerService.validate_image(image_data):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid image file"
                )
            
            upload_data = image_data
            if optimize:
                try:
                    optimized_data, _ = ImageOptimizerService.optimize_image(image_data)
                    upload_data = optimized_data
                except Exception as e:
                    logger.warning(f"Image optimization failed: {e}")
            
            file_path = f"{user_id}/profile.jpg"
            
            supabase = get_supabase_client()
            response = supabase.storage.from_(bucket_config["name"]).upload(
                path=file_path,
                file=upload_data,
                file_options={
                    "content-type": "image/jpeg",
                    "cache-control": "3600",
                    "upsert": "true"  # Allow overwriting profile images
                }
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to upload image to storage"
                )
            
            public_url = supabase.storage.from_(bucket_config["name"]).get_public_url(file_path)
            logger.info(f"User image uploaded successfully: {file_path}")
            return public_url
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"User image upload failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to upload user image: {str(e)}"
            )
    
    @classmethod
    async def upload_pet_image(
        cls,
        image_data: bytes,
        user_id: str,
        pet_id: str,
        optimize: bool = True
    ) -> str:
        """
        Upload pet image to storage
        
        Args:
            image_data: Raw image bytes
            user_id: User ID for folder structure
            pet_id: Pet ID for unique filename
            optimize: Whether to optimize image before upload
            
        Returns:
            Public URL of uploaded image
        """
        try:
            bucket_config = cls.BUCKETS["pet_images"]
            
            if len(image_data) > bucket_config["max_size"]:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Image exceeds maximum size of {bucket_config['max_size'] / 1_048_576:.1f}MB"
                )
            
            if not ImageOptimizerService.validate_image(image_data):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid image file"
                )
            
            upload_data = image_data
            if optimize:
                try:
                    optimized_data, _ = ImageOptimizerService.optimize_image(image_data)
                    upload_data = optimized_data
                except Exception as e:
                    logger.warning(f"Image optimization failed: {e}")
            
            file_path = f"{user_id}/pets/{pet_id}.jpg"
            
            supabase = get_supabase_client()
            response = supabase.storage.from_(bucket_config["name"]).upload(
                path=file_path,
                file=upload_data,
                file_options={
                    "content-type": "image/jpeg",
                    "cache-control": "3600",
                    "upsert": "true"  # Allow overwriting pet images
                }
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to upload image to storage"
                )
            
            public_url = supabase.storage.from_(bucket_config["name"]).get_public_url(file_path)
            logger.info(f"Pet image uploaded successfully: {file_path}")
            return public_url
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Pet image upload failed: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to upload pet image: {str(e)}"
            )
    
    @classmethod
    async def delete_scan_image(cls, user_id: str, image_url: str) -> bool:
        """
        Delete scan image from storage
        
        Args:
            user_id: User ID for validation
            image_url: Public URL of image to delete
            
        Returns:
            True if deleted successfully
        """
        try:
            # Extract file path from URL
            file_path = cls._extract_file_path(image_url, "scan-images")
            
            # Verify user owns this file
            if not file_path.startswith(f"{user_id}/"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Unauthorized to delete this image"
                )
            
            supabase = get_supabase_client()
            response = supabase.storage.from_("scan-images").remove([file_path])
            
            logger.info(f"Scan image deleted: {file_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to delete scan image: {str(e)}")
            return False
    
    @staticmethod
    def _extract_file_path(public_url: str, bucket_name: str) -> str:
        """
        Extract file path from Supabase public URL
        
        Args:
            public_url: Full public URL from Supabase
            bucket_name: Bucket name to extract path from
            
        Returns:
            File path within bucket
        """
        # URL format: https://{project}.supabase.co/storage/v1/object/public/{bucket}/{path}
        try:
            parts = public_url.split(f"/object/public/{bucket_name}/")
            if len(parts) != 2:
                raise ValueError("Invalid public URL format")
            return parts[1]
        except Exception:
            raise ValueError(f"Could not extract file path from URL: {public_url}")
    
    @classmethod
    async def upload_from_fastapi_file(
        cls,
        file: UploadFile,
        user_id: str,
        upload_type: str,
        resource_id: Optional[str] = None
    ) -> str:
        """
        Upload file from FastAPI UploadFile object
        
        Args:
            file: FastAPI UploadFile object
            user_id: User ID for folder structure
            upload_type: Type of upload ('user', 'pet', 'scan')
            resource_id: Resource ID (pet_id or scan_id)
            
        Returns:
            Public URL of uploaded image
        """
        # Read file data
        image_data = await file.read()
        
        # Route to appropriate upload method
        if upload_type == "user":
            return await cls.upload_user_image(image_data, user_id)
        elif upload_type == "pet":
            if not resource_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="pet_id required for pet image upload"
                )
            return await cls.upload_pet_image(image_data, user_id, resource_id)
        elif upload_type == "scan":
            if not resource_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="scan_id required for scan image upload"
                )
            return await cls.upload_scan_image(image_data, user_id, resource_id)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid upload type: {upload_type}"
            )

