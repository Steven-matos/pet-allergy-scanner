"""
Authentication router for user management
"""

from fastapi import APIRouter, HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.core.user import UserCreate, UserResponse, UserUpdate, UserLogin
from app.core.config import settings
from app.core.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger
from app.core.validation.input_validator import InputValidator
from app.core.security.jwt_handler import security, get_current_user
from app.core.security.auth_enhancements import AuthSecurityService, AuthEventTracker

async def get_merged_user_data(user_id: str, auth_metadata: dict) -> UserResponse:
    """
    Merge data from auth.users and public.users tables into a single UserResponse
    
    Uses centralized UserDataService for consistency.
    
    Args:
        user_id: The user's ID
        auth_metadata: The user metadata from auth.users table
        
    Returns:
        UserResponse with merged data from both tables
    """
    from app.shared.services.user_data_service import UserDataService
    
    user_service = UserDataService()
    return await user_service.get_merged_user_data(user_id, auth_metadata)

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
        
        # Create user record in public.users table using centralized service
        try:
            from app.shared.services.user_data_service import UserDataService
            
            user_service = UserDataService()
            await user_service.create_user(
                user_id,
                auth_metadata={
                    "email": user_data.email,
                    "user_metadata": {
                        "username": user_data.username,
                        "first_name": user_data.first_name,
                        "last_name": user_data.last_name,
                        "role": user_data.role.value if hasattr(user_data.role, 'value') else user_data.role
                    }
                },
                additional_data={
                    "email": user_data.email,
                    "username": user_data.username,
                    "first_name": user_data.first_name,
                    "last_name": user_data.last_name,
                    "role": user_data.role.value if hasattr(user_data.role, 'value') else user_data.role
                }
            )
        
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
        auth_response = None
        try:
            auth_response = supabase.auth.sign_in_with_password({
                "email": login_data.email_or_username,
                "password": login_data.password
            })
        except Exception as auth_error:
            # Log the full error for debugging
            error_str = str(auth_error).lower()
            error_type = type(auth_error).__name__
            
            # Try to extract more details from the error
            error_details = {
                "error_type": error_type,
                "error_message": str(auth_error),
                "error_repr": repr(auth_error)
            }
            
            # Check if error has attributes that might contain more info
            if hasattr(auth_error, 'message'):
                error_details["error_message_attr"] = str(auth_error.message)
            if hasattr(auth_error, 'status_code'):
                error_details["status_code"] = auth_error.status_code
            if hasattr(auth_error, 'args') and auth_error.args:
                error_details["error_args"] = str(auth_error.args)
            
            logger.error(f"Supabase auth error details: {error_details}", exc_info=True)
            
            # Check for email not confirmed/verified errors
            if "email" in error_str and ("not confirmed" in error_str or "not verified" in error_str or "confirmation" in error_str):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Please verify your email address before signing in. Check your email for the verification link."
                )
            # Check for database errors (common cause of "Database error granting user")
            # This is a database schema issue, not related to rate limiting
            # The fix script should be run in Supabase SQL Editor
            if "database error" in error_str or "granting user" in error_str:
                logger.error(f"Database error during authentication for email: {login_data.email_or_username}")
                logger.error("This usually means the user exists in auth.users but not in public.users, or there's a constraint violation.")
                logger.error("Run the fix_auth_user_grant_error.sql script in Supabase SQL Editor to diagnose and fix.")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Database error during authentication. This is a database configuration issue. Please contact support or run the fix script in Supabase SQL Editor."
                )
            
            # Check for invalid credentials
            if "invalid" in error_str or "credentials" in error_str or "password" in error_str or "auth" in error_type.lower():
                logger.warning(f"Invalid credentials for email: {login_data.email_or_username}")
                
                # Track failed login attempt
                ip_address = None
                try:
                    from fastapi import Request
                    # Try to get IP from request if available
                    # Note: This might not work if called from a dependency
                    pass
                except Exception:
                    pass
                
                AuthSecurityService.record_failed_attempt(
                    login_data.email_or_username,
                    user_id=None
                )
                AuthEventTracker.track_auth_failure(
                    "invalid_credentials",
                    user_id=None,
                    method="login"
                )
                
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid email or password"
                )
            # Re-raise other auth errors with more context
            # But only if auth_response wasn't set by auto-fix retry
            if auth_response is None:
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
        
        # Track successful login
        ip_address = None
        try:
            from fastapi import Request
            # IP tracking would be done via request if available
            pass
        except Exception:
            pass
        
        AuthSecurityService.clear_failed_attempts(login_data.email_or_username)
        AuthEventTracker.track_auth_success(
            user_data.id,
            method="login",
            ip_address=ip_address
        )
        
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


@router.post("/apple/", response_model=dict)
async def sign_in_with_apple(request: Request):
    """
    Sign in with Apple using the identity token from iOS
    
    Exchanges the Apple ID token for a Supabase session.
    This endpoint handles both new user registration and existing user login.
    
    Args:
        request: FastAPI request containing:
            - id_token: The identity token from Apple Sign-In (JWT)
            - nonce: The nonce used during Apple Sign-In (unhashed)
            - email: Optional user email (only on first sign-in)
            - first_name: Optional user's first name (only on first sign-in, required for new users)
            - last_name: Optional user's last name (only on first sign-in)
            - username: Optional username (only on first sign-in)
        
    Returns:
        Dictionary with access token, refresh token, and user data
        
    Raises:
        HTTPException: If authentication fails
    """
    try:
        # Parse request body
        body = await request.json()
        id_token = body.get("id_token")
        nonce = body.get("nonce")
        email = body.get("email")
        first_name = body.get("first_name")
        last_name = body.get("last_name")
        username = body.get("username")
        
        if not id_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Apple ID token is required"
            )
        
        if not nonce:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nonce is required for Apple Sign-In"
            )
        
        supabase = get_supabase_client()
        
        try:
            # Use Supabase's sign_in_with_id_token for Apple authentication
            # This method verifies the Apple ID token and creates/retrieves the user
            auth_response = supabase.auth.sign_in_with_id_token({
                "provider": "apple",
                "token": id_token,
                "nonce": nonce
            })
        except Exception as auth_error:
            error_str = str(auth_error).lower()
            logger.error(f"Apple Sign-In auth error: {auth_error}")
            
            # Check for specific Apple auth errors
            if "invalid" in error_str or "token" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid Apple ID token. Please try signing in again."
                )
            if "nonce" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid nonce. Please try signing in again."
                )
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Apple Sign-In failed. Please try again."
            )
        
        # Validate auth response
        if not auth_response.user or not auth_response.session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Apple Sign-In failed - no session returned"
            )
        
        user = auth_response.user
        session = auth_response.session
        user_metadata = user.user_metadata or {}
        
        # Prepare user data from request (prioritize request values over metadata)
        # This ensures we capture the name data that's only available on first sign-in
        user_first_name = first_name or user_metadata.get("first_name")
        user_last_name = last_name or user_metadata.get("last_name")
        user_username = username or user_metadata.get("username")
        
        # Ensure user exists in public.users table with all provided data
        # This must happen BEFORE any update operations
        try:
            from app.shared.services.user_data_service import UserDataService
            from app.shared.services.supabase_auth_service import SupabaseAuthService
            
            user_service = UserDataService()
            service_supabase = SupabaseAuthService.create_service_role_client()
            
            # Check if user already exists in public.users
            from app.shared.utils.async_supabase import execute_async
            existing_user_response = await execute_async(
                lambda: service_supabase.table("users")
                    .select("id, first_name, last_name, username")
                    .eq("id", user.id)
                    .execute()
            )
            
            user_exists = existing_user_response.data and len(existing_user_response.data) > 0
            
            if user_exists:
                # User exists - update with any new data provided in the request
                # Only update fields that were explicitly provided in the request body
                update_data = {}
                if first_name is not None:  # Explicitly provided in request
                    update_data["first_name"] = first_name
                if last_name is not None:  # Explicitly provided in request (could be empty string)
                    update_data["last_name"] = last_name
                if username is not None:  # Explicitly provided in request (could be empty string)
                    update_data["username"] = username
                
                if update_data:
                    await execute_async(
                        lambda: service_supabase.table("users")
                            .update(update_data)
                            .eq("id", user.id)
                            .execute()
                    )
                    logger.info(f"Updated Apple user {user.id} with: {list(update_data.keys())}")
            else:
                # User doesn't exist - create with all provided data
                # Use create_user which will properly handle the data
                await user_service.create_user(
                    user.id,
                    auth_metadata={
                        "email": user.email or email or "",
                        "user_metadata": {
                            "first_name": user_first_name,
                            "last_name": user_last_name,
                            "username": user_username,
                            "apple_user": True
                        }
                    },
                    additional_data={
                        "email": user.email or email or "",
                        "first_name": user_first_name,
                        "last_name": user_last_name,
                        "username": user_username
                    }
                )
                logger.info(f"Created Apple user {user.id} with first_name={user_first_name}, last_name={user_last_name}, username={user_username}")
                
        except Exception as user_error:
            # Log but don't fail - user creation/update errors shouldn't block sign-in
            logger.error(f"Failed to create/update Apple user in public.users: {user_error}", exc_info=True)
        
        # Get merged user data
        user_data = await get_merged_user_data(user.id, {
            "email": user.email,
            "user_metadata": user_metadata,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        })
        
        # Track successful Apple Sign-In
        ip_address = request.client.host if hasattr(request, 'client') and request.client else None
        AuthSecurityService.clear_failed_attempts(user.email or user.id)
        AuthEventTracker.track_auth_success(
            user_data.id,
            method="apple_sign_in",
            ip_address=ip_address
        )
        
        logger.info(f"Apple Sign-In successful for user: {user.id}")
        
        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "Bearer",
            "expires_in": session.expires_in,
            "user": user_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Apple Sign-In error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during Apple Sign-In"
        )


@router.post("/logout/")
async def logout_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Logout user and invalidate session
    
    Invalidates the user's session, blacklists the token, and tracks the logout event.
    
    Args:
        request: FastAPI request object (for IP tracking)
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
        
        # Use authenticated client for logout
        from app.shared.services.supabase_auth_service import SupabaseAuthService
        from app.core.security.auth_enhancements import TokenBlacklist, AuthEventTracker
        
        supabase = SupabaseAuthService.create_authenticated_client(
            access_token=credentials.credentials,
            refresh_token=None  # Not needed for logout
        )
        
        # Get user ID before logout (for tracking)
        user_id = None
        try:
            session = supabase.auth.get_session()
            if session and hasattr(session, 'user') and session.user:
                user_id = session.user.id
        except Exception:
            pass
        
        # Sign out the user
        supabase.auth.sign_out()
        
        # Blacklist the token to prevent reuse after logout
        TokenBlacklist.add_token(credentials.credentials)
        
        # Track logout event
        ip_address = request.client.host if hasattr(request, 'client') and request.client else None
        if user_id:
            AuthEventTracker.track_logout(user_id, ip_address)
        
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
        # Use centralized service to avoid code duplication
        from app.shared.services.supabase_auth_service import SupabaseAuthService
        
        supabase = SupabaseAuthService.create_service_role_client()
        
        # Get current user from our validated JWT
        user_id = current_user.id
        
        # Update user metadata
        # This endpoint is used by:
        # 1. Apple Sign-In users during onboarding (when they complete profile setup)
        # 2. Regular email sign-up users (if they edit their profile later)
        # Both scenarios use the same updateProfile() method, so we handle both here.
        
        # Use model_dump with exclude_unset to only get fields that were explicitly provided in the request
        # This is important because Optional fields default to None, but we only want to update fields that were set
        update_data = user_update.model_dump(exclude_unset=True, exclude_none=False)
        
        # Log received update data for debugging
        logger.info(f"[UPDATE_PROFILE] Received update_data: {update_data}")
        logger.info(f"[UPDATE_PROFILE] UserUpdate model fields: first_name={user_update.first_name}, last_name={user_update.last_name}, username={user_update.username}")
        logger.info(f"[UPDATE_PROFILE] User ID: {user_id}")
        
        # Update the users table directly with service role
        # Build db_update dict with only fields that were explicitly provided and are not None
        # This prevents clearing existing fields and ensures we only update what was sent
        db_update = {}
        if "first_name" in update_data and update_data["first_name"] is not None:
            db_update["first_name"] = update_data["first_name"]
        if "last_name" in update_data and update_data["last_name"] is not None:
            db_update["last_name"] = update_data["last_name"]
        if "username" in update_data and update_data["username"] is not None:
            db_update["username"] = update_data["username"]
        
        logger.info(f"[UPDATE_PROFILE] Prepared db_update from update_data: {db_update}")
        logger.info(f"[UPDATE_PROFILE] db_update keys: {list(db_update.keys())}")
        logger.info(f"[UPDATE_PROFILE] db_update values: {db_update}")
        
        # Role updates must go through centralized role manager
        if "role" in update_data and update_data["role"] is not None:
            from app.shared.services.user_role_manager import UserRoleManager
            role_manager = UserRoleManager(supabase)
            new_role = UserRole(update_data["role"]) if isinstance(update_data["role"], str) else update_data["role"]
            await role_manager.update_user_role(
                user_id, 
                new_role, 
                "User profile update"
            )
        if "onboarded" in update_data and update_data["onboarded"] is not None:
            db_update["onboarded"] = update_data["onboarded"]
        if "image_url" in update_data and update_data["image_url"] is not None:
            db_update["image_url"] = update_data["image_url"]
        
        if db_update:
            # Use DatabaseOperationService for non-role user updates
            from app.shared.services.database_operation_service import DatabaseOperationService
            
            logger.info(f"[UPDATE_PROFILE] Calling update_with_timestamp with: {db_update}")
            db_service = DatabaseOperationService(supabase)
            result = await db_service.update_with_timestamp("users", user_id, db_update)
            logger.info(f"[UPDATE_PROFILE] Update result: {result}")
        else:
            logger.warning(f"[UPDATE_PROFILE] db_update is empty, no fields to update")
        
        # Get updated user data
        from app.shared.utils.async_supabase import execute_async
        updated_response = await execute_async(
            lambda: supabase.table("users").select("*").eq("id", user_id).execute()
        )
        
        if not updated_response.data:
            logger.error(f"Failed to fetch updated user {user_id}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to fetch updated user profile"
            )
        
        updated_user_data = updated_response.data[0]
        
        # Return the updated user data using response model service
        from app.shared.services.response_model_service import ResponseModelService
        return ResponseModelService.convert_to_model(updated_user_data, UserResponse)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update profile error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error updating user profile"
        )

@router.post("/reset-password/")
async def reset_password(request: Request):
    """
    Send password reset email to user
    
    Args:
        request: FastAPI request object containing email
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If reset fails
    """
    try:
        # Parse request body
        body = await request.json()
        email = body.get("email")
        
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        
        # Validate and sanitize email (raises HTTPException if invalid)
        email = InputValidator.validate_email(email)
        
        supabase = get_supabase_client()
        
        # Send password reset email via Supabase Auth
        # Note: Supabase will handle the case where email doesn't exist
        # (it won't reveal whether an account exists for security)
        try:
            # Use SniffTest URL scheme for iOS app deep linking
            supabase.auth.reset_password_email(
                email,
                options={
                    "redirect_to": "SniffTest://auth/callback?type=recovery"
                }
            )
        except Exception as reset_error:
            error_str = str(reset_error).lower()
            logger.error(f"Password reset error: {reset_error}")
            
            # Check for rate limit
            if "rate limit" in error_str or "429" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many reset attempts. Please try again later.",
                    headers={"Retry-After": "60"}
                )
            
            # For security, don't reveal if email exists or not
            # Just return success message
            pass
        
        # Always return success to prevent email enumeration attacks
        return {"message": "If an account exists with this email, a password reset link has been sent."}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Password reset error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during password reset"
        )


@router.post("/update-password/")
async def update_password(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Update password for authenticated user (after password reset flow)
    
    Requires valid access token from password reset email link.
    
    Args:
        request: FastAPI request object containing new password
        credentials: JWT token from password reset link
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If update fails
    """
    try:
        if not credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )
        
        # Parse request body
        body = await request.json()
        new_password = body.get("password")
        
        if not new_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password is required"
            )
        
        # Validate password strength
        validator = InputValidator()
        try:
            validator.validate_password(new_password)
        except HTTPException as e:
            raise e
        
        # Use authenticated client to update password
        from app.shared.services.supabase_auth_service import SupabaseAuthService
        
        supabase = SupabaseAuthService.create_authenticated_client(
            access_token=credentials.credentials,
            refresh_token=None
        )
        
        # Update the user's password via Supabase Auth
        try:
            supabase.auth.update_user({"password": new_password})
        except Exception as update_error:
            error_str = str(update_error).lower()
            logger.error(f"Password update error: {update_error}")
            
            # Check for same password error
            if "same" in error_str or "different" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="New password must be different from your current password."
                )
            
            if "weak" in error_str or "strength" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Password does not meet strength requirements"
                )
            
            if "expired" in error_str or "invalid" in error_str:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Password reset link has expired. Please request a new one."
                )
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update password. Please try again."
            )
        
        logger.info("Password updated successfully")
        return {"message": "Password updated successfully. Please log in with your new password."}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Password update error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during password update"
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
            from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=UserFriendlyErrorMessages.get_user_friendly_message("authentication required")
            )
        
        # Use Supabase to exchange refresh token for new session
        # This works even when access token is expired
        # According to Supabase Python 2.9.1 documentation
        
        try:
            # Use centralized auth service for consistency with other auth operations
            # This ensures we use the same client creation pattern everywhere
            from app.shared.services.supabase_auth_service import SupabaseAuthService
            
            # For refresh, we have refresh_token but access_token is expired/empty
            # Supabase Python 2.9.1 allows setting session with empty access_token
            # when we have a valid refresh_token
            supabase = SupabaseAuthService.create_authenticated_client(
                access_token="",  # Expired, will be refreshed by refresh_session()
                refresh_token=refresh_token_value
            )
            
            # Refresh the session to get new access and refresh tokens
            # refresh_session() may raise an exception or return None on failure
            try:
                response = supabase.auth.refresh_session()
            except AttributeError as attr_error:
                # refresh_session() might not exist in this Supabase version
                logger.error(f"refresh_session() method not available: {attr_error}")
                # Try alternative: use set_session with refresh token to get new session
                # This might work if refresh_session() isn't available
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Token refresh method not available. Please contact support."
                )
            except Exception as refresh_error:
                logger.error(f"refresh_session() raised exception: {refresh_error}", exc_info=True)
                raise  # Re-raise to be caught by outer exception handler
            
            # Validate response structure
            if not response:
                logger.error("refresh_session() returned None")
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("invalid token")
                )
            
            # Check if response has session attribute
            if not hasattr(response, 'session') or not response.session:
                logger.error(f"Response missing session: {type(response)}, attributes: {dir(response) if hasattr(response, '__dict__') else 'N/A'}")
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("invalid token")
                )
            
            # Check if response has user attribute
            if not hasattr(response, 'user') or not response.user:
                logger.error(f"Response missing user: {type(response)}, attributes: {dir(response) if hasattr(response, '__dict__') else 'N/A'}")
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("invalid token")
                )
            
            session = response.session
            user = response.user
            
        except HTTPException:
            raise
        except Exception as refresh_error:
            # Log detailed error information for debugging
            error_type = type(refresh_error).__name__
            error_str = str(refresh_error).lower()
            error_repr = repr(refresh_error)
            
            logger.error(
                f"Token refresh failed: {error_type}: {refresh_error}",
                exc_info=True
            )
            logger.error(f"Error details - type: {error_type}, str: {error_str}, repr: {error_repr}")
            
            # Check for specific Supabase error types
            # Supabase may raise different exception types
            if hasattr(refresh_error, 'message'):
                error_message = str(refresh_error.message).lower()
            else:
                error_message = error_str
            
            # Check if it's a rate limit error from Supabase
            if "rate limit" in error_message or "rate_limit" in error_message or "429" in error_message:
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("rate limit exceeded"),
                    headers={"Retry-After": "60"}
                )
            
            # Check if it's a token expiration/invalid issue
            if any(keyword in error_message for keyword in ["expired", "invalid", "401", "unauthorized", "token"]):
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("invalid token")
                )
            
            # Check for network/connection errors
            if any(keyword in error_message for keyword in ["connection", "timeout", "network", "unreachable"]):
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("connection error")
                )
            
            # Generic error with user-friendly message
            from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=UserFriendlyErrorMessages.get_user_friendly_message("an unexpected error occurred")
            )
        
        # Get user data
        try:
            user_metadata = user.user_metadata or {}
            
            # Return merged user data with new session
            user_data = await get_merged_user_data(user.id, {
                "email": user.email,
                "user_metadata": user_metadata,
                "created_at": user.created_at,
                "updated_at": user.updated_at
            })
        except Exception as user_data_error:
            logger.error(f"Failed to get merged user data: {user_data_error}", exc_info=True)
            # If we can't get full user data, return basic user info from auth response
            # This allows token refresh to succeed even if user data fetch fails
            from app.models.core.user import UserResponse
            user_data = UserResponse(
                id=user.id,
                email=user.email or "",
                username=user_metadata.get("username") if user_metadata else None,
                first_name=user_metadata.get("first_name") if user_metadata else None,
                last_name=user_metadata.get("last_name") if user_metadata else None,
                role=user_metadata.get("role", "free") if user_metadata else "free",
                onboarded=False,
                created_at=user.created_at if hasattr(user, 'created_at') else None,
                updated_at=user.updated_at if hasattr(user, 'updated_at') else None
            )
        
        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "Bearer",
            "expires_in": session.expires_in if hasattr(session, 'expires_in') else 3600,
            "user": user_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Refresh token error: {e}", exc_info=True)
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("an unexpected error occurred")
        )
