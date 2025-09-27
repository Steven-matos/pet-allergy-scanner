"""
Multi-Factor Authentication (MFA) router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import List, Optional
from app.routers.auth import get_current_user
from app.services.mfa_service import MFAService
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

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
        qr_code = mfa_service.generate_qr_code(
            current_user.id, 
            current_user.email, 
            secret
        )
        
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
        logger.error(f"Failed to setup MFA for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to setup MFA"
        )

@router.post("/enable")
async def enable_mfa(
    request: MFAVerifyRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Enable MFA after verifying setup token
    
    Verifies the TOTP token and enables MFA for the user
    """
    try:
        mfa_service = MFAService()
        
        # Enable MFA
        success = mfa_service.enable_mfa(current_user.id, request.token)
        
        if success:
            return {"message": "MFA enabled successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to enable MFA"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to enable MFA for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to enable MFA"
        )

@router.post("/disable")
async def disable_mfa(
    request: MFAVerifyRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Disable MFA for the current user
    
    Verifies the TOTP token and disables MFA
    """
    try:
        mfa_service = MFAService()
        
        # Disable MFA
        success = mfa_service.disable_mfa(current_user.id, request.token)
        
        if success:
            return {"message": "MFA disabled successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to disable MFA"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to disable MFA for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to disable MFA"
        )

@router.post("/verify")
async def verify_mfa(
    request: MFAVerifyRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Verify MFA token
    
    Verifies a TOTP token for the current user
    """
    try:
        mfa_service = MFAService()
        
        # Verify token
        success = mfa_service.verify_totp(current_user.id, request.token)
        
        if success:
            return {"message": "MFA token verified successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid MFA token"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to verify MFA token for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify MFA token"
        )

@router.post("/verify-backup")
async def verify_backup_code(
    request: MFABackupCodeRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Verify MFA backup code
    
    Verifies a backup code for the current user
    """
    try:
        mfa_service = MFAService()
        
        # Verify backup code
        success = mfa_service.verify_backup_code(current_user.id, request.code)
        
        if success:
            return {"message": "Backup code verified successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid backup code"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to verify backup code for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify backup code"
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
        
        return {
            "mfa_enabled": is_enabled,
            "user_id": current_user.id
        }
        
    except Exception as e:
        logger.error(f"Failed to get MFA status for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get MFA status"
        )

@router.post("/regenerate-backup-codes")
async def regenerate_backup_codes(current_user: dict = Depends(get_current_user)):
    """
    Regenerate backup codes for the current user
    
    Generates new backup codes and invalidates old ones
    """
    try:
        mfa_service = MFAService()
        
        # Check if MFA is enabled
        if not mfa_service.is_mfa_enabled(current_user.id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="MFA is not enabled for this user"
            )
        
        # Generate new backup codes
        backup_codes = mfa_service.generate_backup_codes(current_user.id)
        
        return {
            "message": "Backup codes regenerated successfully",
            "backup_codes": backup_codes
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to regenerate backup codes for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to regenerate backup codes"
        )
