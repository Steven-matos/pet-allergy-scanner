"""
Multi-Factor Authentication (MFA) router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import List, Optional
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
from app.services.mfa_service import MFAService
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

class MFASetupResponse(BaseModel):
    """MFA setup response model"""
    secret: str
    qr_code: str
    backup_codes: List[str]

class MFAVerifyRequest(BaseModel):
    """MFA verification request model"""
    token: str

class MFABackupCodeRequest(BaseModel):
    """MFA backup code request model"""
    code: str

@router.post("/setup", response_model=MFASetupResponse)
async def setup_mfa(current_user: dict = Depends(get_current_user)):
    """
    Set up MFA for the current user
    
    Generates a new TOTP secret, QR code, and backup codes
    """
    try:
        mfa_service = MFAService()
        
        # Check if MFA is already enabled
        if mfa_service.is_mfa_enabled(current_user.id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="MFA is already enabled for this user"
            )
        
        # Generate secret
        secret = mfa_service.generate_secret(current_user.id)
        
        # Generate QR code
        qr_code = mfa_service.generate_qr_code(secret, current_user.email)
        
        # Generate backup codes
        backup_codes = mfa_service.generate_backup_codes(current_user.id)
        
        return MFASetupResponse(
            secret=secret,
            qr_code=qr_code,
            backup_codes=backup_codes
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error setting up MFA: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error setting up MFA"
        )

@router.post("/verify")
async def verify_mfa(
    request: MFAVerifyRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Verify MFA token
    
    Verifies the TOTP token and enables MFA if not already enabled
    """
    try:
        mfa_service = MFAService()
        
        # Verify token
        if not mfa_service.verify_token(current_user.id, request.token):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid MFA token"
            )
        
        # Enable MFA if not already enabled
        if not mfa_service.is_mfa_enabled(current_user.id):
            mfa_service.enable_mfa(current_user.id)
        
        return {"message": "MFA verified successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error verifying MFA: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error verifying MFA"
        )

@router.post("/backup-verify")
async def verify_backup_code(
    request: MFABackupCodeRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Verify MFA backup code
    
    Verifies a backup code for MFA authentication
    """
    try:
        mfa_service = MFAService()
        
        # Verify backup code
        if not mfa_service.verify_backup_code(current_user.id, request.code):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid backup code"
            )
        
        return {"message": "Backup code verified successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error verifying backup code: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error verifying backup code"
        )

@router.delete("/disable")
async def disable_mfa(current_user: dict = Depends(get_current_user)):
    """
    Disable MFA for the current user
    
    Disables MFA and removes all associated data
    """
    try:
        mfa_service = MFAService()
        
        # Check if MFA is enabled
        if not mfa_service.is_mfa_enabled(current_user.id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="MFA is not enabled for this user"
            )
        
        # Disable MFA
        mfa_service.disable_mfa(current_user.id)
        
        return {"message": "MFA disabled successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error disabling MFA: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error disabling MFA"
        )

@router.get("/status")
async def get_mfa_status(current_user: dict = Depends(get_current_user)):
    """
    Get MFA status for the current user
    
    Returns whether MFA is enabled and other status information
    """
    try:
        mfa_service = MFAService()
        
        is_enabled = mfa_service.is_mfa_enabled(current_user.id)
        backup_codes_count = mfa_service.get_backup_codes_count(current_user.id)
        
        return {
            "mfa_enabled": is_enabled,
            "backup_codes_remaining": backup_codes_count
        }
        
    except Exception as e:
        logger.error(f"Error getting MFA status: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error getting MFA status"
        )
