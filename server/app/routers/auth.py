"""
Authentication router for user management
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.user import UserCreate, UserResponse, UserUpdate, UserLogin
from app.core.config import settings
from app.database import get_supabase_client
from supabase import Client
import logging

router = APIRouter()
security = HTTPBearer()
logger = logging.getLogger(__name__)

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
            from app.utils.security import SecurityValidator
            validated_email = SecurityValidator.validate_email(identifier)
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
        from app.utils.security import SecurityValidator
        
        # Validate and sanitize input
        validated_email = SecurityValidator.validate_email(user_data.email)
        validated_password = SecurityValidator.validate_password(user_data.password)
        validated_username = SecurityValidator.validate_username(user_data.username) if user_data.username else None
        sanitized_first_name = SecurityValidator.sanitize_text(user_data.first_name or "", max_length=100)
        sanitized_last_name = SecurityValidator.sanitize_text(user_data.last_name or "", max_length=100)
        
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
            
            logger.info(f"Supabase sign_up response: {response}")
            
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
                
                # Insert into public.users table
                supabase.table("users").insert(user_insert_data).execute()
                logger.info(f"User inserted into public.users: {response.user.id}")
                
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
                # Email already confirmed - return tokens
                return {
                    "access_token": response.session.access_token,
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
        
        return {
            "access_token": response.session.access_token,
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
    
    Returns the authenticated user's profile information
    """
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        username=current_user.user_metadata.get("username"),
        first_name=current_user.user_metadata.get("first_name"),
        last_name=current_user.user_metadata.get("last_name"),
        role=current_user.user_metadata.get("role", "free"),
        created_at=current_user.created_at,
        updated_at=current_user.updated_at
    )

@router.put("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Update current user information
    
    Updates the authenticated user's profile information
    """
    try:
        # Use the existing authenticated Supabase client
        supabase = get_supabase_client()
        
        # Update user metadata
        update_data = {}
        if user_update.username is not None:
            # Validate username if provided
            from app.utils.security import SecurityValidator
            validated_username = SecurityValidator.validate_username(user_update.username)
            update_data["username"] = validated_username
        if user_update.first_name is not None:
            update_data["first_name"] = user_update.first_name
        if user_update.last_name is not None:
            update_data["last_name"] = user_update.last_name
        if user_update.role is not None:
            update_data["role"] = user_update.role.value
        
        # Update auth user metadata using the JWT token
        if update_data:
            # Create an authenticated Supabase client using the JWT token
            from supabase import create_client
            
            auth_supabase = create_client(
                settings.supabase_url,
                settings.supabase_key
            )
            
            # Set the session with the user's JWT token
            auth_supabase.auth.set_session(credentials.credentials, "")
            
            # Update user metadata
            auth_supabase.auth.update_user({
                "data": update_data
            })
        
        # Check if user exists in public.users table, create if not
        user_exists_response = supabase.table("users").select("id").eq("id", current_user.id).execute()
        
        if not user_exists_response.data:
            # User doesn't exist in public.users table, create them using service role
            logger.info(f"User {current_user.id} not found in public.users table, creating record")
            
            # Use the service role client to bypass RLS
            from supabase import create_client
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
                logger.info(f"Created user record in public.users table: {current_user.id}")
            except Exception as insert_error:
                # User might already exist due to race condition or previous creation
                if "duplicate key value violates unique constraint" in str(insert_error):
                    logger.info(f"User {current_user.id} already exists in public.users table, continuing with update")
                else:
                    logger.error(f"Failed to create user record: {insert_error}")
                    raise insert_error
        
        # Update public.users table for fields not in auth metadata
        public_update_data = {}
        if user_update.onboarded is not None:
            public_update_data["onboarded"] = user_update.onboarded
        
        if public_update_data:
            # Update the public.users table using the service role client
            logger.info(f"Updating public.users table with data: {public_update_data} for user: {current_user.id}")
            response = supabase.table("users").update(public_update_data).eq("id", current_user.id).execute()
            logger.info(f"Update response: {response}")
        
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
        
        # Get onboarded status from public.users table
        user_data_response = supabase.table("users").select("onboarded").eq("id", current_user.id).execute()
        logger.info(f"Query for onboarded status response: {user_data_response}")
        onboarded_status = False
        if user_data_response.data:
            onboarded_status = user_data_response.data[0].get("onboarded", False)
            logger.info(f"Retrieved onboarded status: {onboarded_status}")
        
        return UserResponse(
            id=current_user.id,
            email=current_user.email,
            username=updated_username,
            first_name=updated_first_name,
            last_name=updated_last_name,
            role=updated_role,
            onboarded=onboarded_status,
            created_at=current_user.created_at,
            updated_at=current_user.updated_at
        )
        
    except Exception as e:
        logger.error(f"Update user error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update user"
        )

@router.post("/reset-password")
async def reset_password(reset_data: dict):
    """
    Send password reset email to user
    
    Sends a password reset email using Supabase Auth
    """
    try:
        from app.utils.security import SecurityValidator
        
        email = reset_data.get("email")
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )
        
        # Validate email format
        validated_email = SecurityValidator.validate_email(email)
        
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

@router.get("/debug/user-exists")
async def debug_user_exists(current_user: dict = Depends(get_current_user)):
    """
    Debug endpoint to check if user exists in public.users table
    """
    try:
        supabase = get_supabase_client()
        
        # Check if user exists in public.users table
        user_response = supabase.table("users").select("*").eq("id", current_user.id).execute()
        
        # Check all users in public.users table
        all_users_response = supabase.table("users").select("*").execute()
        
        return {
            "user_id": current_user.id,
            "user_exists_in_public": len(user_response.data) > 0,
            "user_data": user_response.data[0] if user_response.data else None,
            "total_users": len(user_response.data),
            "all_users_count": len(all_users_response.data),
            "all_users": all_users_response.data
        }
    except Exception as e:
        logger.error(f"Debug user exists error: {e}")
        return {"error": str(e)}

@router.post("/logout")
async def logout_user(current_user: dict = Depends(get_current_user)):
    """
    Logout current user
    
    Invalidates the current user's session
    """
    try:
        supabase = get_supabase_client()
        supabase.auth.sign_out()
        return {"message": "Successfully logged out"}
    except Exception as e:
        logger.error(f"Logout error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to logout"
        )
