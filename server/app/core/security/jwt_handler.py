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


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    request: Request = None
) -> User:
    """
    Get current authenticated user from JWT token
    
    This function validates JWT tokens from both Supabase and our own server.
    It first attempts Supabase JWT validation, then falls back to server JWT.
    
    Args:
        credentials: HTTP Bearer token credentials
        request: FastAPI request object
        
    Returns:
        Current authenticated user
        
    Raises:
        HTTPException: If token is invalid or user not found
        
    Example:
        >>> @router.get("/protected")
        >>> async def protected_route(current_user: User = Depends(get_current_user)):
        >>>     return {"user_id": current_user.id}
    """
    # Debug: Log all request headers
    if request:
        logger.info(f"🔍 Request headers: {dict(request.headers)}")
    
    # Check if credentials were provided
    if credentials is None:
        logger.error("❌ No Authorization header found in request")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    logger.info(f"🔍 JWT Handler called with credentials: {credentials.credentials[:50]}...")
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Debug: Log the JWT secret being used
        logger.info(f"🔍 Starting JWT validation for user: {credentials.credentials[:50]}...")
        logger.info(f"Using JWT secret: {settings.supabase_jwt_secret[:20]}...")
        logger.info(f"Expected issuer: {settings.supabase_url}/auth/v1")
        
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
            # Log detailed error information for debugging
            logger.error(f"Supabase JWT Secret (first 10 chars): {settings.supabase_jwt_secret[:10]}...")
            logger.error(f"Supabase URL: {settings.supabase_url}")
            logger.error(f"Expected issuer: {settings.supabase_url}/auth/v1")
            logger.error(f"Token (first 50 chars): {credentials.credentials[:50]}...")
            raise credentials_exception
    
    # Get user from database
    try:
        # Use service role client to bypass RLS policies
        from supabase import create_client
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key
        )
        logger.info(f"Looking up user with ID: {user_id}")
        logger.info(f"Supabase service client created successfully")
        
        response = supabase.table("users").select("*").eq("id", user_id).execute()
        logger.info(f"Database query response: {response}")
        logger.info(f"Response data: {response.data}")
        logger.info(f"Response count: {response.count if hasattr(response, 'count') else 'N/A'}")
        
        if not response.data:
            logger.warning(f"User not found in database with ID: {user_id}")
            # Let's check if there are any users in the database at all
            try:
                all_users_response = supabase.table("users").select("id, email").limit(5).execute()
                logger.info(f"Sample users in database: {all_users_response.data}")
            except Exception as e:
                logger.error(f"Failed to query all users: {e}")
            
            logger.warning(f"Attempting to create user with ID: {user_id}")
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
                
                logger.info(f"Creating user with data: {create_data}")
                create_response = supabase.table("users").insert(create_data).execute()
                
                logger.info(f"Create response: {create_response}")
                logger.info(f"Create response data: {create_response.data}")
                logger.info(f"Create response error: {getattr(create_response, 'error', None)}")
                
                if create_response.data:
                    logger.info(f"Successfully created user: {user_id}")
                    user_data = create_response.data[0]
                    return User(**user_data)
                else:
                    logger.error(f"Failed to create user: {create_response}")
                    raise credentials_exception
            except Exception as create_error:
                logger.error(f"Failed to create user: {create_error}")
                raise credentials_exception
        
        user_data = response.data[0]
        logger.info(f"User found: {user_data.get('email', 'unknown')}")
        return User(**user_data)
        
    except Exception as e:
        logger.error(f"Error fetching user: {e}")
        raise credentials_exception


# Export for backward compatibility
__all__ = ['get_current_user', 'security']
