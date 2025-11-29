"""
JWT token handling and user authentication

Extracted from app.utils.security.get_current_user
Follows Single Responsibility Principle: Authentication only

Security Note: Migrated from python-jose to PyJWT to eliminate ecdsa dependency
vulnerable to Minerva timing attack (CVE-2024-23342, GHSA-wj6h-64fc-37mp)
"""

import logging
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt.exceptions import InvalidTokenError

from app.core.config import settings
from app.core.database import get_supabase_client
from app.models.core.user import User
from app.core.security.auth_enhancements import (
    AuthSecurityService,
    AuthEventTracker
)

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)  # Don't auto-raise on missing header

# Debug: Log HTTPBearer configuration


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    Get current authenticated user from JWT token
    
    This function validates JWT tokens from both Supabase and our own server.
    It first attempts Supabase JWT validation, then falls back to server JWT.
    
    Args:
        credentials: HTTP Bearer token credentials
        
    Returns:
        Current authenticated user
        
    Raises:
        HTTPException: If token is invalid or user not found
        
    Example:
        >>> @router.get("/protected")
        >>> async def protected_route(current_user: User = Depends(get_current_user)):
        >>>     return {"user_id": current_user.id}
    """
    # Check if credentials were provided
    if credentials is None:
        logger.error("No Authorization header found in request")
        AuthEventTracker.track_auth_failure("missing_credentials")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if token is blacklisted (revoked)
    if not AuthSecurityService.validate_token_not_blacklisted(credentials.credentials):
        logger.warning("Attempted use of blacklisted/revoked token")
        AuthEventTracker.track_auth_failure("blacklisted_token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Validate Supabase JWT with full security checks
        # This enforces expiration, audience, and issuer validation per 2025 security best practices
        expected_issuer = f"{settings.supabase_url}/auth/v1"
        
        payload = jwt.decode(
            credentials.credentials, 
            settings.supabase_jwt_secret, 
            algorithms=["HS256"],
            audience="authenticated",
            issuer=expected_issuer,
            options={
                "verify_signature": True,
                "verify_exp": True,      # Enforce token expiration
                "verify_aud": True,      # Enforce audience validation
                "verify_iss": True       # Enforce issuer validation
            }
        )
        user_id: str = payload.get("sub")
        
        if user_id is None:
            logger.error("No user ID found in JWT payload")
            raise credentials_exception
        
    except jwt.ExpiredSignatureError:
        logger.warning("Token has expired")
        # Extract user_id from expired token if possible (for tracking)
        try:
            expired_payload = jwt.decode(
                credentials.credentials,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={"verify_signature": False, "verify_exp": False}
            )
            user_id = expired_payload.get("sub")
            AuthEventTracker.track_auth_failure("expired_token", user_id=user_id)
        except Exception:
            AuthEventTracker.track_auth_failure("expired_token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidAudienceError:
        logger.warning("Invalid token audience")
        raise credentials_exception
    except jwt.InvalidIssuerError:
        logger.warning("Invalid token issuer")
        raise credentials_exception
    except InvalidTokenError as e:
        logger.warning(f"JWT validation failed: {type(e).__name__}")
        
        # Fallback to server secret validation (without logging token details)
        try:
            payload = jwt.decode(
                credentials.credentials, 
                settings.secret_key, 
                algorithms=[settings.algorithm],
                options={
                    "verify_signature": True,
                    "verify_exp": True
                }
            )
            user_id: str = payload.get("sub")
            
            if user_id is None:
                logger.error("No user ID found in server JWT payload")
                raise credentials_exception
            
        except InvalidTokenError as e2:
            logger.error(f"All JWT validation attempts failed: {type(e).__name__}, {type(e2).__name__}")
            raise credentials_exception
    
    # Get user from database using centralized service
    try:
        from app.shared.services.user_data_service import UserDataService
        import asyncio
        
        user_service = UserDataService()
        # Use async method in sync context since get_current_user is not async
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        user_data = loop.run_until_complete(
            user_service.get_user_by_id_sync(user_id)
        )
        
        if not user_data:
            # User not found - create using async method in sync context
            user = loop.run_until_complete(
                user_service.create_user(user_id, auth_metadata=payload)
            )
            return user
        
        return User(**user_data)
        
    except Exception as e:
        logger.error(f"Database error: {type(e).__name__}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Database error",
            headers={"WWW-Authenticate": "Bearer"},
        )


# Export for backward compatibility
__all__ = ['get_current_user', 'security']
