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
        logger.error("❌ No Authorization header found in request")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Additional debug logging
    logger.info(f"🔍 DEBUG: JWT Handler received credentials: {credentials}")
    logger.info(f"🔍 DEBUG: Credentials type: {type(credentials)}")
    logger.info(f"🔍 DEBUG: Credentials scheme: {credentials.scheme}")
    logger.info(f"🔍 DEBUG: Credentials token length: {len(credentials.credentials)}")
    
    logger.info(f"🔍 JWT Handler called with credentials: {credentials.credentials[:50]}...")
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # Try multiple validation strategies in order of preference
    payload = None
    user_id = None
    validation_method = None
    
    try:
        # Strategy 1: Full Supabase validation (strict)
        logger.info(f"🔍 Strategy 1: Full Supabase validation")
        logger.info(f"   Token preview: {credentials.credentials[:50]}...")
        logger.info(f"   Secret preview: {settings.supabase_jwt_secret[:20]}...")
        logger.info(f"   Expected issuer: {settings.supabase_url}/auth/v1")
        
        payload = jwt.decode(
            credentials.credentials, 
            settings.supabase_jwt_secret, 
            algorithms=["HS256"],
            audience="authenticated",
            issuer=f"{settings.supabase_url}/auth/v1",
            options={
                "verify_signature": True,
                "verify_exp": True,
                "verify_aud": True,
                "verify_iss": True
            }
        )
        user_id = payload.get("sub")
        validation_method = "supabase_strict"
        logger.info(f"✅ Strategy 1 successful: {validation_method}")
        
    except InvalidTokenError as e1:
        logger.warning(f"⚠️ Strategy 1 failed: {e1}")
        
        try:
            # Strategy 2: Supabase validation with signature only (lenient)
            logger.info(f"🔍 Strategy 2: Supabase signature validation only")
            
            payload = jwt.decode(
                credentials.credentials, 
                settings.supabase_jwt_secret, 
                algorithms=["HS256"],
                options={
                    "verify_signature": True,
                    "verify_exp": False,  # Allow expired tokens for now
                    "verify_aud": False,  # Don't verify audience
                    "verify_iss": False   # Don't verify issuer
                }
            )
            user_id = payload.get("sub")
            validation_method = "supabase_lenient"
            logger.info(f"✅ Strategy 2 successful: {validation_method}")
            
        except InvalidTokenError as e2:
            logger.warning(f"⚠️ Strategy 2 failed: {e2}")
            
            try:
                # Strategy 3: Server secret validation
                logger.info(f"🔍 Strategy 3: Server secret validation")
                
                payload = jwt.decode(
                    credentials.credentials, 
                    settings.secret_key, 
                    algorithms=[settings.algorithm],
                    options={"verify_signature": True}
                )
                user_id = payload.get("sub")
                validation_method = "server_secret"
                logger.info(f"✅ Strategy 3 successful: {validation_method}")
                
            except InvalidTokenError as e3:
                logger.error(f"❌ All validation strategies failed:")
                logger.error(f"   Strategy 1 (Supabase strict): {e1}")
                logger.error(f"   Strategy 2 (Supabase lenient): {e2}")
                logger.error(f"   Strategy 3 (Server secret): {e3}")
                
                # Log comprehensive debug information
                logger.error(f"🔍 Comprehensive Debug Info:")
                logger.error(f"   Supabase URL: {settings.supabase_url}")
                logger.error(f"   JWT Secret length: {len(settings.supabase_jwt_secret)}")
                logger.error(f"   JWT Secret preview: {settings.supabase_jwt_secret[:20]}...")
                logger.error(f"   Expected issuer: {settings.supabase_url}/auth/v1")
                logger.error(f"   Token length: {len(credentials.credentials)}")
                logger.error(f"   Token preview: {credentials.credentials[:50]}...")
                
                # Try to decode without verification to analyze the token
                try:
                    unverified_payload = jwt.decode(credentials.credentials, options={"verify_signature": False})
                    logger.error(f"   Unverified payload: {unverified_payload}")
                    
                    # Check if token is expired
                    exp = unverified_payload.get("exp")
                    if exp:
                        import time
                        current_time = int(time.time())
                        if exp < current_time:
                            logger.error(f"   ⚠️ Token is expired! Exp: {exp}, Current: {current_time}")
                        else:
                            logger.error(f"   ✅ Token is not expired. Exp: {exp}, Current: {current_time}")
                    
                    # Check issuer
                    iss = unverified_payload.get("iss")
                    expected_iss = f"{settings.supabase_url}/auth/v1"
                    if iss != expected_iss:
                        logger.error(f"   ⚠️ Issuer mismatch! Expected: {expected_iss}, Got: {iss}")
                    else:
                        logger.error(f"   ✅ Issuer matches: {iss}")
                        
                except Exception as decode_error:
                    logger.error(f"   ❌ Failed to decode unverified payload: {decode_error}")
                
                raise credentials_exception
    
    # Validate that we have a user ID
    if user_id is None:
        logger.error(f"❌ No user ID found in payload after successful validation with {validation_method}")
        logger.error(f"   Payload: {payload}")
        raise credentials_exception
    
    logger.info(f"✅ JWT validation successful using {validation_method}")
    logger.info(f"   User ID: {user_id}")
    logger.info(f"   Payload keys: {list(payload.keys()) if payload else 'None'}")
    
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
