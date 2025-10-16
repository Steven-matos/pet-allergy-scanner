"""
Authentication router for user management
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.user import UserCreate, UserResponse, UserUpdate, UserLogin
from app.core.config import settings
from app.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger
from app.core.validation.input_validator import InputValidator
from app.core.security.jwt_handler import security

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
            logger.info(f"User {user_id} not found in public.users, creating record")
            # If user doesn't exist in public.users, create them
            try:
                create_response = service_supabase.table("users").insert({
                    "id": user_id,
                    "onboarded": False,
                    "image_url": None
                }).execute()
                logger.info(f"Created new user record for {user_id}")
                onboarded_status = False
                image_url = None
            except Exception as create_error:
                logger.error(f"Failed to create user in public.users: {create_error}")
                # Continue with defaults
                onboarded_status = False
                image_url = None
    except Exception as e:
        logger.error(f"Error querying public.users table: {e}")
        # Fallback to defaults if database query fails
        onboarded_status = False
        image_url = None
    
    return UserResponse(
        id=user_id,
        email=auth_metadata.get("email"),
        username=auth_metadata.get("username"),
        first_name=auth_metadata.get("first_name"),
        last_name=auth_metadata.get("last_name"),
        image_url=image_url,  # From public.users
        role=auth_metadata.get("role", "free"),
        onboarded=onboarded_status,  # From public.users
        created_at=auth_metadata.get("created_at"),
        updated_at=auth_metadata.get("updated_at")
    )

router = APIRouter()
logger = get_logger(__name__)

async def get_user_email_by_username_or_email(identifier: str) -> str:
    """
    Get user email by username or email
    
    Args:
        identifier: Either username or email
        
    Returns:
        User's email address
        
    Raises:
        HTTPException: If user not found
    """
    try:
        supabase = get_supabase_client()
        
        # Check if identifier is an email (contains @)
        if "@" in identifier:
            # It's an email, validate and return
            from app.core.validation.input_validator import InputValidator
            validated_email = InputValidator.validate_email(identifier)
            return validated_email
        
        # It's a username, look up the user
        response = supabase.table("users").select("email").eq("username", identifier).execute()
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or email"
            )
        
        return response.data[0]["email"]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error looking up user: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or email"
        )

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    Get current authenticated user from JWT token
    """
    try:
        supabase = get_supabase_client()
        # Verify JWT token with Supabase
        response = supabase.auth.get_user(credentials.credentials)
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
        
        return response.user
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )

@router.post("/register")
async def register_user(user_data: UserCreate):
    """
    Register a new user account
    
    Creates a new user account with email and password authentication
    Returns success message instructing user to verify their email
    """
    try:
        # Validate and sanitize input
        validated_email = InputValidator.validate_email(user_data.email)
        validated_password = InputValidator.validate_password(user_data.password)
        validated_username = InputValidator.validate_username(user_data.username) if user_data.username else None
        sanitized_first_name = InputValidator.sanitize_text(user_data.first_name or "", max_length=100)
        sanitized_last_name = InputValidator.sanitize_text(user_data.last_name or "", max_length=100)
        
        supabase = get_supabase_client()
        
        # Create user with Supabase Auth
        try:
            # Prepare user metadata
            user_metadata = {
                "first_name": sanitized_first_name,
                "last_name": sanitized_last_name,
                "role": user_data.role.value
            }
            
            # Add username if provided
            if validated_username:
                user_metadata["username"] = validated_username
            
            response = supabase.auth.sign_up({
                "email": validated_email,
                "password": validated_password,
                "options": {
                    "data": user_metadata
                }
            })
            
            if not response.user:
                logger.error("No user returned from Supabase sign_up")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to create user account - no user returned"
                )
            
            # Manually insert user into public.users table
            try:
                user_insert_data = {
                    "id": response.user.id,
                    "email": response.user.email,
                    "username": response.user.user_metadata.get("username"),
                    "first_name": response.user.user_metadata.get("first_name"),
                    "last_name": response.user.user_metadata.get("last_name"),
                    "role": response.user.user_metadata.get("role", "free")
                }
                
                # Insert into public.users table using service role client to bypass RLS
                from app.core.config import settings
                from supabase import create_client
                
                service_supabase = create_client(
                    settings.supabase_url,
                    settings.supabase_service_role_key
                )
                
                service_supabase.table("users").insert(user_insert_data).execute()
                logger.info(f"User {response.user.id} registered successfully")
                
            except Exception as insert_error:
                logger.warning(f"Failed to insert user into public.users: {insert_error}")
                # Don't fail registration if public.users insert fails
                # The database trigger should handle this automatically
            
            # Check if email confirmation is required
            if not response.session:
                # Email confirmation required - return success message
                return {
                    "message": "Account created successfully! Please check your email and click the verification link to activate your account.",
                    "email_verification_required": True,
                    "user": UserResponse(
                        id=response.user.id,
                        email=response.user.email,
                        username=response.user.user_metadata.get("username"),
                        first_name=response.user.user_metadata.get("first_name"),
                        last_name=response.user.user_metadata.get("last_name"),
                        role=response.user.user_metadata.get("role", "free"),
                        created_at=response.user.created_at,
                        updated_at=response.user.updated_at
                    )
                }
            else:
                # Email already confirmed - return tokens with refresh token
                return {
                    "access_token": response.session.access_token,
                    "refresh_token": response.session.refresh_token,
                    "expires_in": response.session.expires_in,
                    "token_type": "bearer",
                    "user": UserResponse(
                        id=response.user.id,
                        email=response.user.email,
                        username=response.user.user_metadata.get("username"),
                        first_name=response.user.user_metadata.get("first_name"),
                        last_name=response.user.user_metadata.get("last_name"),
                        role=response.user.user_metadata.get("role", "free"),
                        created_at=response.user.created_at,
                        updated_at=response.user.updated_at
                    )
                }
                
        except Exception as supabase_error:
            logger.error(f"Supabase sign_up error: {supabase_error}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Failed to create user account: {str(supabase_error)}"
            )
        
    except Exception as e:
        logger.error(f"Registration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create user account"
        )

@router.post("/login")
async def login_user(login_data: UserLogin):
    """
    Authenticate user and return access token
    
    Validates user credentials and returns JWT token for API access
    """
    try:
        # Get user email by username or email
        user_email = await get_user_email_by_username_or_email(login_data.email_or_username)
        
        supabase = get_supabase_client()
        
        # Authenticate with Supabase using the resolved email
        response = supabase.auth.sign_in_with_password({
            "email": user_email,
            "password": login_data.password
        })
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username/email or password"
            )
        
        # Check if email is verified
        if not response.user.email_confirmed_at:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email address before logging in. Check your inbox for a verification link."
            )
        
        if not response.session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username/email or password"
            )
        
        # Create auth metadata dict for the helper function
        auth_metadata = {
            "email": response.user.email,
            "username": response.user.user_metadata.get("username"),
            "first_name": response.user.user_metadata.get("first_name"),
            "last_name": response.user.user_metadata.get("last_name"),
            "role": response.user.user_metadata.get("role", "free"),
            "created_at": response.user.created_at,
            "updated_at": response.user.updated_at
        }
        
        # Get merged user data
        user_data = await get_merged_user_data(response.user.id, auth_metadata)
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "expires_in": response.session.expires_in,
            "token_type": "bearer",
            "user": user_data
        }
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username/email or password"
        )

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """
    Get current user information
    
    Returns the authenticated user's profile information merged from auth.users and public.users tables
    """
    try:
        from supabase import create_client
        
        # Create service role client to fetch data from public.users table
        service_supabase = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key
        )
        
        # Get onboarded status and image_url from public.users table
        user_data_response = service_supabase.table("users").select("onboarded, image_url, role").eq("id", current_user.id).execute()
        onboarded_status = False
        image_url = None
        if user_data_response.data:
            onboarded_status = user_data_response.data[0].get("onboarded", False)
            image_url = user_data_response.data[0].get("image_url")
            role = user_data_response.data[0].get("role", "free")
        
        return UserResponse(
            id=current_user.id,
            email=current_user.email,
            username=current_user.user_metadata.get("username"),
            first_name=current_user.user_metadata.get("first_name"),
            last_name=current_user.user_metadata.get("last_name"),
            image_url=image_url,
            role=role,
            onboarded=onboarded_status,
            created_at=current_user.created_at,
            updated_at=current_user.updated_at
        )
    except Exception as e:
        logger.error(f"Get current user error: {e}")
        # Fallback to returning data without onboarded/image_url if query fails
        return UserResponse(
            id=current_user.id,
            email=current_user.email,
            username=current_user.user_metadata.get("username"),
            first_name=current_user.user_metadata.get("first_name"),
            last_name=current_user.user_metadata.get("last_name"),
            image_url=None,
            role="free",
            onboarded=False,
            created_at=current_user.created_at,
            updated_at=current_user.updated_at
        )

@router.put("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Update current user information
    
    Updates the authenticated user's profile information
    """
    try:
        # Import at function level to ensure it's always available
        from supabase import create_client
        from app.core.validation.input_validator import InputValidator
        
        # Use the existing authenticated Supabase client
        supabase = get_supabase_client()
        
        # Update user metadata
        update_data = {}
        if user_update.username is not None:
            # Validate username if provided (but skip if empty string)
            if user_update.username:
                validated_username = InputValidator.validate_username(user_update.username)
                update_data["username"] = validated_username
        if user_update.first_name is not None:
            # Basic length validation for first name (no aggressive sanitization for names)
            if user_update.first_name:
                if len(user_update.first_name) > 100:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="First name too long"
                    )
                update_data["first_name"] = user_update.first_name
        if user_update.last_name is not None:
            # Basic length validation for last name (no aggressive sanitization for names)
            if user_update.last_name:
                if len(user_update.last_name) > 100:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Last name too long"
                    )
                update_data["last_name"] = user_update.last_name
        if user_update.role is not None:
            update_data["role"] = user_update.role.value
        
        # Check if user exists in public.users table, create if not
        user_exists_response = supabase.table("users").select("id").eq("id", current_user.id).execute()
        
        if not user_exists_response.data:
            # User doesn't exist in public.users table, create them using service role
            logger.info(f"Creating user record for {current_user.id}")
            
            # Use the service role client to bypass RLS
            service_supabase = create_client(
                settings.supabase_url,
                settings.supabase_service_role_key  # Use service key to bypass RLS
            )
            
            user_create_data = {
                "id": current_user.id,
                "email": current_user.email,
                "username": current_user.user_metadata.get("username"),
                "first_name": current_user.user_metadata.get("first_name"),
                "last_name": current_user.user_metadata.get("last_name"),
                "role": current_user.user_metadata.get("role", "free"),
                "onboarded": False
            }
            try:
                service_supabase.table("users").insert(user_create_data).execute()
                logger.info(f"Created user record for {current_user.id}")
            except Exception as insert_error:
                # User might already exist due to race condition or previous creation
                if "duplicate key value violates unique constraint" not in str(insert_error):
                    logger.error(f"Failed to create user record: {insert_error}")
                    raise insert_error
        
        # Create service role client for public.users table operations
        # (Re-create to ensure it's always available, even if user existed)
        service_supabase = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key  # Use service key to bypass RLS
        )
        
        # Update auth user metadata using the service role client
        if update_data:
            # Use service role client to update auth user metadata
            # This bypasses the need for a user session
            try:
                service_supabase.auth.admin.update_user_by_id(
                    current_user.id,
                    {"user_metadata": update_data}
                )
            except Exception as auth_update_error:
                logger.warning(f"Failed to update auth user metadata: {auth_update_error}")
                # Don't fail the entire operation if auth metadata update fails
                # The public.users table update is more important
        
        # Get current user data to check for existing image
        try:
            current_user_data = service_supabase.table("users").select("image_url").eq("id", current_user.id).execute()
            current_image_url = None
            if current_user_data.data:
                current_image_url = current_user_data.data[0].get("image_url")
        except Exception as e:
            logger.error(f"Error fetching current user data: {e}")
            current_image_url = None
        
        # Update public.users table for fields not in auth metadata
        public_update_data = {}
        if user_update.onboarded is not None:
            public_update_data["onboarded"] = user_update.onboarded
        if user_update.image_url is not None:
            # Don't validate image_url as it's a file path, not user-facing text
            # Just limit the length to prevent abuse
            if len(user_update.image_url) > 500:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Image URL too long"
                )
            
            # Delete old image from storage if it exists and is different from new one
            if current_image_url and current_image_url != user_update.image_url:
                if "storage/v1/object/public/user-images/" in current_image_url:
                    try:
                        # Extract the storage path from the full URL
                        storage_path = current_image_url.split("/storage/v1/object/public/user-images/")[-1]
                        service_supabase.storage.from_("user-images").remove([storage_path])
                    except Exception as e:
                        logger.warning(f"Failed to delete old user image: {e}")
            
            public_update_data["image_url"] = user_update.image_url
        if user_update.role is not None:
            public_update_data["role"] = user_update.role.value
        
        if public_update_data:
            # Update the public.users table using the service role client
            logger.info(f"Updating user profile for {current_user.id}")
            try:
                response = service_supabase.table("users").update(public_update_data).eq("id", current_user.id).execute()
                if not response.data:
                    logger.warning("No data returned from update operation")
            except Exception as update_error:
                logger.error(f"Error updating public.users table: {update_error}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Failed to update user profile: {str(update_error)}"
                )
        
        # Get updated user data from the original current_user object
        # and merge with any updates from the database
        updated_username = current_user.user_metadata.get("username")
        updated_first_name = current_user.user_metadata.get("first_name")
        updated_last_name = current_user.user_metadata.get("last_name")
        updated_role = current_user.user_metadata.get("role", "free")
        
        # Apply updates if they were provided
        if user_update.username is not None:
            updated_username = user_update.username
        if user_update.first_name is not None:
            updated_first_name = user_update.first_name
        if user_update.last_name is not None:
            updated_last_name = user_update.last_name
        if user_update.role is not None:
            updated_role = user_update.role.value
        
        # Get onboarded status and image_url from public.users table
        user_data_response = service_supabase.table("users").select("onboarded, image_url, role").eq("id", current_user.id).execute()
        onboarded_status = False
        image_url = None
        if user_data_response.data:
            onboarded_status = user_data_response.data[0].get("onboarded", False)
            image_url = user_data_response.data[0].get("image_url")
            role = user_data_response.data[0].get("role", "free")
        
        return UserResponse(
            id=current_user.id,
            email=current_user.email,
            username=updated_username,
            first_name=updated_first_name,
            last_name=updated_last_name,
            image_url=image_url,
            role=role,
            onboarded=onboarded_status,
            created_at=current_user.created_at,
            updated_at=current_user.updated_at
        )
        
    except Exception as e:
        logger.error(f"Update user error: {e}")
        logger.error(f"Error type: {type(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update user"
        )

@router.post("/refresh")
async def refresh_token(refresh_data: dict):
    """
    Refresh authentication token using refresh token
    
    Exchanges a valid refresh token for a new access token and refresh token pair.
    This allows users to stay authenticated for extended periods without re-login.
    """
    try:
        refresh_token = refresh_data.get("refresh_token")
        if not refresh_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Refresh token is required"
            )
        
        supabase = get_supabase_client()
        
        # Refresh the session using Supabase
        response = supabase.auth.refresh_session(refresh_token)
        
        if not response.session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token"
            )
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token"
            )
        
        # Create auth metadata dict for the helper function
        auth_metadata = {
            "email": response.user.email,
            "username": response.user.user_metadata.get("username"),
            "first_name": response.user.user_metadata.get("first_name"),
            "last_name": response.user.user_metadata.get("last_name"),
            "role": response.user.user_metadata.get("role", "free"),
            "created_at": response.user.created_at,
            "updated_at": response.user.updated_at
        }
        
        # Get merged user data
        user_data = await get_merged_user_data(response.user.id, auth_metadata)
        
        logger.info(f"Token refreshed successfully for user: {response.user.id}")
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "expires_in": response.session.expires_in,
            "token_type": "bearer",
            "user": user_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token refresh error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Failed to refresh authentication token"
        )

@router.post("/reset-password")
async def reset_password(reset_data: dict):
    """
    Send password reset email to user
    
    Sends a password reset email using Supabase Auth
    """
    try:
        email = reset_data.get("email")
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        
        # Validate email format
        validated_email = InputValidator.validate_email(email)
        
        supabase = get_supabase_client()
        
        # Send password reset email using Supabase
        response = supabase.auth.reset_password_email(validated_email)
        
        logger.info(f"Password reset email sent to: {validated_email}")
        return {
            "message": "Password reset email sent successfully. Please check your email for instructions.",
            "email": validated_email
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Password reset error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to send password reset email"
        )


@router.post("/logout")
async def logout_user():
    """
    Logout current user
    
    Note: Logout is primarily handled client-side by clearing the JWT token.
    This endpoint exists for compatibility but doesn't perform server-side session invalidation
    since Supabase handles JWT validation statefully.
    """
    return {"message": "Successfully logged out"}
