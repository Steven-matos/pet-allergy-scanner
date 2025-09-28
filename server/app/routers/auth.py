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
        sanitized_first_name = SecurityValidator.sanitize_text(user_data.first_name or "", max_length=100)
        sanitized_last_name = SecurityValidator.sanitize_text(user_data.last_name or "", max_length=100)
        
        supabase = get_supabase_client()
        
        # Create user with Supabase Auth
        try:
            response = supabase.auth.sign_up({
                "email": validated_email,
                "password": validated_password,
                "options": {
                    "data": {
                        "first_name": sanitized_first_name,
                        "last_name": sanitized_last_name,
                        "role": user_data.role.value
                    }
                }
            })
            
            logger.info(f"Supabase sign_up response: {response}")
            
            if not response.user:
                logger.error("No user returned from Supabase sign_up")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to create user account - no user returned"
                )
            
            # Check if email confirmation is required
            if not response.session:
                # Email confirmation required - return success message
                return {
                    "message": "Account created successfully! Please check your email and click the verification link to activate your account.",
                    "email_verification_required": True,
                    "user": UserResponse(
                        id=response.user.id,
                        email=response.user.email,
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
        from app.utils.security import SecurityValidator
        
        # Validate and sanitize input
        validated_email = SecurityValidator.validate_email(login_data.email)
        # Note: Don't validate password here as it's already hashed
        
        supabase = get_supabase_client()
        
        # Authenticate with Supabase
        response = supabase.auth.sign_in_with_password({
            "email": validated_email,
            "password": login_data.password
        })
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
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
                detail="Invalid email or password"
            )
        
        return {
            "access_token": response.session.access_token,
            "token_type": "bearer",
            "user": UserResponse(
                id=response.user.id,
                email=response.user.email,
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
            detail="Invalid email or password"
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
        first_name=current_user.user_metadata.get("first_name"),
        last_name=current_user.user_metadata.get("last_name"),
        role=current_user.user_metadata.get("role", "free"),
        created_at=current_user.created_at,
        updated_at=current_user.updated_at
    )

@router.put("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    Update current user information
    
    Updates the authenticated user's profile information
    """
    try:
        supabase = get_supabase_client()
        
        # Update user metadata
        update_data = {}
        if user_update.first_name is not None:
            update_data["first_name"] = user_update.first_name
        if user_update.last_name is not None:
            update_data["last_name"] = user_update.last_name
        if user_update.role is not None:
            update_data["role"] = user_update.role.value
        
        response = supabase.auth.update_user({
            "data": update_data
        })
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to update user"
            )
        
        return UserResponse(
            id=response.user.id,
            email=response.user.email,
            first_name=response.user.user_metadata.get("first_name"),
            last_name=response.user.user_metadata.get("last_name"),
            role=response.user.user_metadata.get("role", "free"),
            created_at=response.user.created_at,
            updated_at=response.user.updated_at
        )
        
    except Exception as e:
        logger.error(f"Update user error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update user"
        )

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
