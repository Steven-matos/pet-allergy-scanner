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
from app.database import get_supabase_client
from app.models.user import User

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
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authenticated",
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
    
    # Get user from database
    try:
        # Use service role client to bypass RLS policies
        from supabase import create_client
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key
        )
        
        response = supabase.table("users").select("*").eq("id", user_id).execute()
        
        if not response.data:
            logger.warning(f"User not found in database, attempting to create")
            # Try to create the user in the database using JWT payload data
            try:
                # Extract user data from the JWT payload we already decoded
                user_metadata = payload.get("user_metadata", {})
                create_data = {
                    "id": user_id,
                    "email": payload.get("email"),
                    "username": user_metadata.get("username"),
                    "first_name": user_metadata.get("first_name"),
                    "last_name": user_metadata.get("last_name"),
                    "role": user_metadata.get("role", "free"),
                    "onboarded": False
                }
                
                create_response = supabase.table("users").insert(create_data).execute()
                
                if create_response.data:
                    user_data = create_response.data[0]
                    return User(**user_data)
                else:
                    logger.error("User creation failed: No data returned")
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="User creation failed",
                        headers={"WWW-Authenticate": "Bearer"},
                    )
            except Exception as create_error:
                logger.error(f"User creation error: {type(create_error).__name__}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="User creation failed",
                    headers={"WWW-Authenticate": "Bearer"},
                )
        
        user_data = response.data[0]
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
