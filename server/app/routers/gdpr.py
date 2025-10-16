"""
GDPR compliance router
"""

from fastapi import APIRouter, HTTPException, Depends, status, Response
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
from app.services.gdpr_service import GDPRService
from app.core.config import settings
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

@router.get("/export")
async def export_user_data(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Export all user data (GDPR Article 20 - Right to data portability)
    
    Returns a ZIP file containing all user data in JSON format
    """
    try:
        gdpr_service = GDPRService()
        
        # Check if data export is enabled
        if not settings.enable_data_export:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Data export is currently disabled"
            )
        
        # Export user data
        zip_data = gdpr_service.export_user_data(current_user.id)
        
        # Return ZIP file
        return Response(
            content=zip_data,
            media_type="application/zip",
            headers={
                "Content-Disposition": f"attachment; filename=user_data_{current_user.id}.zip",
                "Content-Type": "application/zip"
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to export data for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to export user data"
        )

@router.delete("/delete")
async def delete_user_data(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete all user data (GDPR Article 17 - Right to erasure)
    
    Permanently deletes all user data and account
    """
    try:
        gdpr_service = GDPRService()
        
        # Check if data deletion is enabled
        if not settings.enable_data_deletion:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Data deletion is currently disabled"
            )
        
        # Delete user data
        success = gdpr_service.delete_user_data(current_user.id)
        
        if success:
            return {"message": "User data deleted successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete user data"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete data for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete user data"
        )

@router.post("/anonymize")
async def anonymize_user_data(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Anonymize user data while preserving functionality
    
    Removes personal information but keeps data for research purposes
    """
    try:
        gdpr_service = GDPRService()
        
        # Anonymize user data
        success = gdpr_service.anonymize_user_data(current_user.id)
        
        if success:
            return {"message": "User data anonymized successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to anonymize user data"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to anonymize data for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to anonymize user data"
        )

@router.get("/retention")
async def get_data_retention_info(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get data retention information (GDPR Article 13/14 - Information to be provided)
    
    Returns information about data retention, legal basis, and purposes
    """
    try:
        gdpr_service = GDPRService()
        
        retention_info = gdpr_service.get_data_retention_info(current_user.id)
        
        return retention_info
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get retention info for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get retention information"
        )

@router.get("/rights")
async def get_data_subject_rights():
    """
    Get information about data subject rights under GDPR
    
    Returns information about user rights and how to exercise them
    """
    try:
        rights_info = {
            "data_subject_rights": {
                "right_of_access": {
                    "article": "GDPR Article 15",
                    "description": "Right to obtain confirmation of personal data processing and access to personal data",
                    "how_to_exercise": "Use the /export endpoint to download your data"
                },
                "right_to_rectification": {
                    "article": "GDPR Article 16", 
                    "description": "Right to have inaccurate personal data corrected",
                    "how_to_exercise": "Update your profile information through the API"
                },
                "right_to_erasure": {
                    "article": "GDPR Article 17",
                    "description": "Right to have personal data deleted (Right to be Forgotten)",
                    "how_to_exercise": "Use the /delete endpoint to permanently delete your data"
                },
                "right_to_restrict_processing": {
                    "article": "GDPR Article 18",
                    "description": "Right to restrict processing of personal data",
                    "how_to_exercise": "Contact support to request processing restrictions"
                },
                "right_to_data_portability": {
                    "article": "GDPR Article 20",
                    "description": "Right to receive personal data in a structured format",
                    "how_to_exercise": "Use the /export endpoint to download your data"
                },
                "right_to_object": {
                    "article": "GDPR Article 21",
                    "description": "Right to object to processing of personal data",
                    "how_to_exercise": "Contact support to object to data processing"
                }
            },
            "data_controller": {
                "name": "SniffTest",
                "contact": "privacy@petallergyscanner.com",
                "legal_basis": "Consent (GDPR Article 6(1)(a))",
                "purpose": "Pet food ingredient analysis and allergy management"
            },
            "data_retention": {
                "period": f"{settings.data_retention_days} days",
                "criteria": "Data is retained for the duration of the service relationship and as required by law"
            },
            "contact_information": {
                "data_protection_officer": "dpo@petallergyscanner.com",
                "privacy_policy": "https://petallergyscanner.com/privacy",
                "terms_of_service": "https://petallergyscanner.com/terms"
            }
        }
        
        return rights_info
        
    except Exception as e:
        logger.error(f"Failed to get data subject rights info: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get data subject rights information"
        )
