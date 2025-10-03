"""
Multi-Factor Authentication (MFA) service
"""

import pyotp
import qrcode
import io
import base64
from app.utils.logging_config import get_logger
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from app.core.config import settings
from app.database import get_supabase_client

logger = get_logger(__name__)

class MFAService:
    """Multi-Factor Authentication service using TOTP"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
    
    def generate_secret(self, user_id: str) -> str:
        """
        Generate a new TOTP secret for a user
        
        Args:
            user_id: User ID
            
        Returns:
            TOTP secret
        """
        try:
            # Generate a new secret
            secret = pyotp.random_base32()
            
            # Store the secret in user metadata (encrypted in production)
            self.supabase.auth.update_user({
                "data": {
                    "mfa_secret": secret,
                    "mfa_enabled": False
                }
            })
            
            logger.info(f"MFA secret generated for user: {user_id}")
            return secret
            
        except Exception as e:
            logger.error(f"Failed to generate MFA secret for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to generate MFA secret"
            )
    
    def generate_qr_code(self, user_id: str, user_email: str, secret: str) -> str:
        """
        Generate QR code for MFA setup
        
        Args:
            user_id: User ID
            user_email: User email
            secret: TOTP secret
            
        Returns:
            Base64 encoded QR code image
        """
        try:
            # Create TOTP URI
            totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
                name=user_email,
                issuer_name="SniffTest"
            )
            
            # Generate QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(totp_uri)
            qr.make(fit=True)
            
            # Create image
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Convert to base64
            buffer = io.BytesIO()
            img.save(buffer, format='PNG')
            buffer.seek(0)
            
            qr_code_base64 = base64.b64encode(buffer.getvalue()).decode()
            
            logger.info(f"QR code generated for user: {user_id}")
            return qr_code_base64
            
        except Exception as e:
            logger.error(f"Failed to generate QR code for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to generate QR code"
            )
    
    def verify_totp(self, user_id: str, token: str) -> bool:
        """
        Verify TOTP token
        
        Args:
            user_id: User ID
            token: TOTP token
            
        Returns:
            True if token is valid
            
        Raises:
            HTTPException: If verification fails
        """
        try:
            # Get user's MFA secret
            user_response = self.supabase.auth.get_user()
            if not user_response.user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="User not found"
                )
            
            mfa_secret = user_response.user.user_metadata.get("mfa_secret")
            if not mfa_secret:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="MFA not set up for this user"
                )
            
            # Verify token
            totp = pyotp.TOTP(mfa_secret)
            is_valid = totp.verify(token, valid_window=1)  # Allow 1 time step tolerance
            
            if is_valid:
                logger.info(f"MFA token verified for user: {user_id}")
                return True
            else:
                logger.warning(f"Invalid MFA token for user: {user_id}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid MFA token"
                )
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to verify MFA token for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to verify MFA token"
            )
    
    def enable_mfa(self, user_id: str, token: str) -> bool:
        """
        Enable MFA for a user after verifying setup token
        
        Args:
            user_id: User ID
            token: TOTP token for verification
            
        Returns:
            True if MFA is enabled
            
        Raises:
            HTTPException: If enabling fails
        """
        try:
            # Verify the token first
            if not self.verify_totp(user_id, token):
                return False
            
            # Enable MFA
            self.supabase.auth.update_user({
                "data": {
                    "mfa_enabled": True
                }
            })
            
            logger.info(f"MFA enabled for user: {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to enable MFA for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to enable MFA"
            )
    
    def disable_mfa(self, user_id: str, token: str) -> bool:
        """
        Disable MFA for a user
        
        Args:
            user_id: User ID
            token: TOTP token for verification
            
        Returns:
            True if MFA is disabled
            
        Raises:
            HTTPException: If disabling fails
        """
        try:
            # Verify the token first
            if not self.verify_totp(user_id, token):
                return False
            
            # Disable MFA and remove secret
            self.supabase.auth.update_user({
                "data": {
                    "mfa_enabled": False,
                    "mfa_secret": None
                }
            })
            
            logger.info(f"MFA disabled for user: {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to disable MFA for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to disable MFA"
            )
    
    def is_mfa_enabled(self, user_id: str) -> bool:
        """
        Check if MFA is enabled for a user
        
        Args:
            user_id: User ID
            
        Returns:
            True if MFA is enabled
        """
        try:
            user_response = self.supabase.auth.get_user()
            if not user_response.user:
                return False
            
            return user_response.user.user_metadata.get("mfa_enabled", False)
            
        except Exception as e:
            logger.error(f"Failed to check MFA status for user {user_id}: {e}")
            return False
    
    def generate_backup_codes(self, user_id: str) -> list:
        """
        Generate backup codes for MFA
        
        Args:
            user_id: User ID
            
        Returns:
            List of backup codes
            
        Raises:
            HTTPException: If generation fails
        """
        try:
            import secrets
            import string
            
            # Generate 10 backup codes
            backup_codes = []
            for _ in range(10):
                code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
                backup_codes.append(code)
            
            # Store backup codes (encrypted in production)
            self.supabase.auth.update_user({
                "data": {
                    "mfa_backup_codes": backup_codes
                }
            })
            
            logger.info(f"Backup codes generated for user: {user_id}")
            return backup_codes
            
        except Exception as e:
            logger.error(f"Failed to generate backup codes for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to generate backup codes"
            )
    
    def verify_backup_code(self, user_id: str, code: str) -> bool:
        """
        Verify backup code
        
        Args:
            user_id: User ID
            code: Backup code
            
        Returns:
            True if code is valid
            
        Raises:
            HTTPException: If verification fails
        """
        try:
            # Get user's backup codes
            user_response = self.supabase.auth.get_user()
            if not user_response.user:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="User not found"
                )
            
            backup_codes = user_response.user.user_metadata.get("mfa_backup_codes", [])
            if not backup_codes:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No backup codes available"
                )
            
            # Check if code is valid
            if code.upper() in backup_codes:
                # Remove used code
                backup_codes.remove(code.upper())
                self.supabase.auth.update_user({
                    "data": {
                        "mfa_backup_codes": backup_codes
                    }
                })
                
                logger.info(f"Backup code verified for user: {user_id}")
                return True
            else:
                logger.warning(f"Invalid backup code for user: {user_id}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid backup code"
                )
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to verify backup code for user {user_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to verify backup code"
            )
