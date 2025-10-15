"""
JWT token handling and user authentication

Extracted from app.utils.security.get_current_user
Follows Single Responsibility Principle: Authentication only

Security Note: Migrated from python-jose to PyJWT to eliminate ecdsa dependency
vulnerable to Minerva timing attack (CVE-2024-23342, GHSA-wj6h-64fc-37mp)
"""

import logging
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt.exceptions import InvalidTokenError

from app.core.config import settings
from app.database import get_supabase_client
from app.models.user import User

logger = logging.getLogger(__name__)
security = HTTPBearer()


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
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # First try to decode as Supabase JWT token
        payload = jwt.decode(
            credentials.credentials, 
            settings.supabase_jwt_secret, 
            algorithms=["HS256"],
            audience="authenticated",
            issuer=f"{settings.supabase_url}/auth/v1",
            options={"verify_signature": True}
        )
        user_id: str = payload.get("sub")
        logger.info(f"Supabase JWT payload: {payload}")
        if user_id is None:
            logger.error("Supabase JWT validation failed: no user ID in payload")
            raise credentials_exception
            
    except InvalidTokenError as e:
        logger.warning(f"Supabase JWT validation failed: {e}, trying server secret key")
        # If Supabase JWT fails, try with our own secret key
        try:
            payload = jwt.decode(
                credentials.credentials, 
                settings.secret_key, 
                algorithms=[settings.algorithm],
                options={"verify_signature": True}
            )
            user_id: str = payload.get("sub")
            logger.info(f"Server JWT payload: {payload}")
            if user_id is None:
                logger.error("Server JWT validation failed: no user ID in payload")
                raise credentials_exception
        except InvalidTokenError as e2:
            logger.error(f"Server JWT validation also failed: {e2}")
            raise credentials_exception
    
    # Get user from database
    try:
        supabase = get_supabase_client()
        logger.info(f"Looking up user with ID: {user_id}")
        response = supabase.table("users").select("*").eq("id", user_id).execute()
        
        if not response.data:
            logger.error(f"User not found in database with ID: {user_id}")
            raise credentials_exception
        
        user_data = response.data[0]
        logger.info(f"User found: {user_data.get('email', 'unknown')}")
        return User(**user_data)
        
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        raise credentials_exception


# Export for backward compatibility
__all__ = ['get_current_user', 'security']
