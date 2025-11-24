"""
Authentication router for user management
"""

from fastapi import APIRouter, HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.user import UserCreate, UserResponse, UserUpdate, UserLogin
from app.core.config import settings
from app.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger
from app.core.validation.input_validator import InputValidator
from app.core.security.jwt_handler import security, get_current_user

async def get_merged_user_data(user_id: str, auth_metadata: dict) -> UserResponse:
    """
    Merge data from auth.users and public.users tables into a single UserResponse
    
    Args:
        user_id: The user's ID
        auth_metadata: The user metadata from auth.users table
        
    Returns:
        UserResponse with merged data from both tables
    """
    from supabase import create_client
    
    # Create service role client to fetch data from public.users table
    service_supabase = create_client(
        settings.supabase_url,
        settings.supabase_service_role_key
    )
    
    # Get data from public.users table
    try:
        user_data_response = service_supabase.table("users").select("onboarded, image_url").eq("id", user_id).execute()
        
        onboarded_status = False
        image_url = None
        if user_data_response.data:
            onboarded_status = user_data_response.data[0].get("onboarded", False)
            image_url = user_data_response.data[0].get("image_url")
        else:
            # If user doesn't exist in public.users, create them
            try:
                create_response = service_supabase.table("users").insert({
                    "id": user_id,
                    "onboarded": False,
                    "image_url": None
                }).execute()
                
                if create_response.data:
                else:
                    logger.warning(f"Failed to create user {user_id} in public.users")
            except Exception as create_error:
                logger.error(f"Error creating user in public.users: {create_error}")
    
    except Exception as e:
        logger.error(f"Error fetching user data from public.users: {e}")
        onboarded_status = False
        image_url = None
    
    # Merge the data
    merged_data = {
        "id": user_id,
        "email": auth_metadata.get("email"),
        "username": auth_metadata.get("user_metadata", {}).get("username"),
        "first_name": auth_metadata.get("user_metadata", {}).get("first_name"),
        "last_name": auth_metadata.get("user_metadata", {}).get("last_name"),
        "role": auth_metadata.get("user_metadata", {}).get("role", "free"),
        "onboarded": onboarded_status,
        "image_url": image_url,
        "created_at": auth_metadata.get("created_at"),
        "updated_at": auth_metadata.get("updated_at")
    }
    
    return UserResponse(**merged_data)

router = APIRouter()
logger = get_logger(__name__)

@router.post("/register/", response_model=UserResponse)
async def register_user(user_data: UserCreate):
    """
    Register a new user with Supabase Auth
    
    Args:
        user_data: User registration data
        
    Returns:
        UserResponse with user details
        
    Raises:
        HTTPException: If registration fails
    """
    try:
        # Validate input
        validator = InputValidator()
        validation_result = validator.validate_user_create(user_data)
        if not validation_result["is_valid"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Validation failed: {', '.join(validation_result['errors'])}"
            )
        
        supabase = get_supabase_client()
        
        # Create user with Supabase Auth
        auth_response = supabase.auth.sign_up({
            "email": user_data.email,
            "password": user_data.password,
            "options": {
                "data": {
                    "username": user_data.username,
                    "first_name": user_data.first_name,
                    "last_name": user_data.last_name,
                    "role": user_data.role
                }
            }
        })
        
        if not auth_response.user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create user account"
            )
        
        # Get the created user data
        user_id = auth_response.user.id
        user_metadata = auth_response.user.user_metadata or {}
        
        # Create user record in public.users table using service role to bypass RLS
        try:
            from app.database import get_supabase_service_role_client
            service_supabase = get_supabase_service_role_client()
            user_record_response = service_supabase.table("users").insert({
                "id": user_id,
                "email": user_data.email,
                "username": user_data.username,
                "first_name": user_data.first_name,
                "last_name": user_data.last_name,
                "role": user_data.role,
                "onboarded": False,
                "image_url": None
            }).execute()
            
            if not user_record_response.data:
                logger.warning(f"Failed to create user record for {user_id}")
        
        except Exception as e:
            logger.error(f"Error creating user record: {e}")
            # Continue with registration flow even if user record creation fails
            # The auth user was created successfully, which is the primary concern
        
        # Return merged user data
        return await get_merged_user_data(user_id, {
            "email": user_data.email,
            "user_metadata": user_metadata,
            "created_at": auth_response.user.created_at,
            "updated_at": auth_response.user.updated_at
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during registration"
        )

@router.post("/login/", response_model=dict)
async def login_user(login_data: UserLogin):
    """
    Login user with email and password
    
    Args:
        login_data: User login credentials
        
    Returns:
        Dictionary with access token and user data
        
    Raises:
        HTTPException: If login fails
    """
    try:
        # Validate input
        validator = InputValidator()
        validation_result = validator.validate_user_login(login_data)
        if not validation_result["is_valid"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Validation failed: {', '.join(validation_result['errors'])}"
            )
        
        supabase = get_supabase_client()
        
        # Authenticate with Supabase
        try:
            auth_response = supabase.auth.sign_in_with_password({
                "email": login_data.email_or_username,
                "password": login_data.password
            })
        except Exception as auth_error:
            # Check if this is an email verification error
            error_str = str(auth_error).lower()
            error_type = type(auth_error).__name__
            
            # Check for email not confirmed/verified errors
            if "email" in error_str and ("not confirmed" in error_str or "not verified" in error_str or "confirmation" in error_str):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Please verify your email address before signing in. Check your email for the verification link."
                )
            # Check for invalid credentials
            if "invalid" in error_str or "credentials" in error_str or "password" in error_str or "auth" in error_type.lower():
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid email or password"
                )
            # Re-raise other auth errors with more context
            logger.error(f"Supabase auth error: {auth_error} (type: {error_type})")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication failed. Please check your credentials."
            )
        
        # Check if user exists but no session (email not verified)
        if auth_response.user and not auth_response.session:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email address before signing in. Check your email for the verification link."
            )
        
        # Check if user or session is missing
        if not auth_response.user or not auth_response.session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Additional check for email verification status if available
        try:
            if hasattr(auth_response.user, 'email_confirmed_at') and auth_response.user.email_confirmed_at is None:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Please verify your email address before signing in. Check your email for the verification link."
                )
        except HTTPException:
            raise
        except Exception:
            # If we can't check email_confirmed_at, continue (session check above should catch it)
            pass
        
        # Get user data
        user_id = auth_response.user.id
        user_metadata = auth_response.user.user_metadata or {}
        
        # Return merged user data with session
        user_data = await get_merged_user_data(user_id, {
            "email": auth_response.user.email,
            "user_metadata": user_metadata,
            "created_at": auth_response.user.created_at,
            "updated_at": auth_response.user.updated_at
        })
        
        return {
            "access_token": auth_response.session.access_token,
            "refresh_token": auth_response.session.refresh_token,
            "token_type": "Bearer",
            "expires_in": auth_response.session.expires_in,
            "user": user_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during login"
        )

@router.post("/logout/")
async def logout_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """
    Logout user and invalidate session
    
    Args:
        credentials: JWT token credentials
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If logout fails
    """
    try:
        if not credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No authentication token provided"
            )
        
        supabase = get_supabase_client()
        
        # Set the session for the current request
        supabase.auth.set_session(credentials.credentials, "")
        
        # Sign out the user
        supabase.auth.sign_out()
        
        return {"message": "Successfully logged out"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Logout error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during logout"
        )

@router.get("/me/", response_model=UserResponse)
async def get_current_user_profile(current_user: UserResponse = Depends(get_current_user)):
    """
    Get current user profile
    
    Args:
        current_user: Current authenticated user from JWT validation
        
    Returns:
        Current user profile data
        
    Raises:
        HTTPException: If user not found or token invalid
    """
    try:
        # Return the current user data directly since it's already validated
        return current_user
        
    except Exception as e:
        logger.error(f"Get profile error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error getting user profile"
        )

@router.put("/me/", response_model=UserResponse)
async def update_user_profile(
    user_update: UserUpdate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update current user profile
    
    Args:
        user_update: Updated user data
        current_user: Current authenticated user from JWT validation
        
    Returns:
        Updated user profile data
        
    Raises:
        HTTPException: If update fails
    """
    try:
        # Validate input
        validator = InputValidator()
        validation_result = validator.validate_user_update(user_update)
        if not validation_result["is_valid"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Validation failed: {', '.join(validation_result['errors'])}"
            )
        
        # Use service role client to bypass RLS policies
        from supabase import create_client
        from app.core.config import settings
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key
        )
        
        # Get current user from our validated JWT
        user_id = current_user.id
        
        # Update user metadata
        update_data = user_update.dict(exclude_unset=True)
        
        # Update the users table directly with service role
        if update_data:
            # Convert field names to match database schema
            db_update = {}
            if "first_name" in update_data:
                db_update["first_name"] = update_data["first_name"]
            if "last_name" in update_data:
                db_update["last_name"] = update_data["last_name"]
            if "username" in update_data:
                db_update["username"] = update_data["username"]
            if "role" in update_data:
                db_update["role"] = update_data["role"]
            if "onboarded" in update_data:
                db_update["onboarded"] = update_data["onboarded"]
            if "image_url" in update_data:
                db_update["image_url"] = update_data["image_url"]
            
            if db_update:
                response = supabase.table("users").update(db_update).eq("id", user_id).execute()
                
                if not response.data:
                    logger.error(f"Failed to update user {user_id}: {response}")
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Failed to update user profile"
                    )
        
        # Get updated user data
        updated_response = supabase.table("users").select("*").eq("id", user_id).execute()
        
        if not updated_response.data:
            logger.error(f"Failed to fetch updated user {user_id}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to fetch updated user profile"
            )
        
        updated_user_data = updated_response.data[0]
        
        # Return the updated user data
        return UserResponse(**updated_user_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update profile error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error updating user profile"
        )

@router.post("/refresh/")
async def refresh_token(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Refresh authentication token using refresh token
    
    Accepts refresh token either in:
    1. Request body as JSON: {"refresh_token": "..."}
    2. Authorization header as Bearer token (fallback)
    
    This allows refreshing even when access token is expired.
    
    Args:
        request: FastAPI request object to read body
        credentials: Optional JWT token credentials from header
        
    Returns:
        New access token and user data
        
    Raises:
        HTTPException: If refresh fails
    """
    refresh_token_value = None
    
    try:
        # Try to get refresh token from request body first
        try:
            body = await request.json()
            refresh_token_value = body.get("refresh_token")
        except Exception:
            pass
        
        # Fallback: try to use refresh token from Authorization header
        if not refresh_token_value and credentials:
            refresh_token_value = credentials.credentials
        
        if not refresh_token_value:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No refresh token provided. Provide refresh_token in request body or Authorization header."
            )
        
        # Use Supabase to exchange refresh token for new session
        # This works even when access token is expired
        from supabase import create_client
        
        try:
            # Create a client instance with anon key
            supabase = create_client(
                settings.supabase_url,
                settings.supabase_key  # Fixed: use supabase_key (not supabase_anon_key)
            )
            
            # Set session with refresh token (access token can be empty when expired)
            # Supabase will use the refresh token to get new tokens
            supabase.auth.set_session("", refresh_token_value)
            
            # Refresh the session to get new access and refresh tokens
            response = supabase.auth.refresh_session()
            
            if not response or not hasattr(response, 'session') or not response.session:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Refresh token expired or invalid"
                )
            
            session = response
            
        except HTTPException:
            raise
        except Exception as refresh_error:
            logger.error(f"Token refresh failed: {refresh_error}")
            # Check if it's a token expiration issue
            error_str = str(refresh_error).lower()
            if "expired" in error_str or "invalid" in error_str or "401" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Refresh token expired or invalid. Please login again."
                )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error refreshing token"
            )
        
        # Get user data
        user = session.user
        user_metadata = user.user_metadata or {}
        
        # Return merged user data with new session
        user_data = await get_merged_user_data(user.id, {
            "email": user.email,
            "user_metadata": user_metadata,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        })
        
        return {
            "access_token": session.session.access_token,
            "refresh_token": session.session.refresh_token,
            "token_type": "Bearer",
            "expires_in": session.session.expires_in,
            "user": user_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Refresh token error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error refreshing token"
        )
