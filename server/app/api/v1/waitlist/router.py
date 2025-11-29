"""
Waitlist router for email signup management
"""
from fastapi import APIRouter, HTTPException, status
from datetime import datetime
from app.models.core.waitlist import WaitlistSignup, WaitlistResponse
from app.core.database import get_supabase_service_role_client
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

def _parse_datetime(dt_str: str) -> datetime:
    """
    Parse ISO datetime string to datetime object
    
    Args:
        dt_str: ISO format datetime string
        
    Returns:
        Parsed datetime object
    """
    return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))

def _build_waitlist_response(entry: dict, is_duplicate: bool = False) -> WaitlistResponse:
    """
    Build WaitlistResponse from database entry
    
    Args:
        entry: Dictionary containing waitlist entry data
        is_duplicate: Whether this is a duplicate email signup
        
    Returns:
        WaitlistResponse object
    """
    created_at = _parse_datetime(entry["created_at"])
    updated_at = _parse_datetime(entry["updated_at"])
    notified_at = None
    if entry.get("notified_at"):
        notified_at = _parse_datetime(entry["notified_at"])
    
    return WaitlistResponse(
        id=entry["id"],
        email=entry["email"],
        notified=entry.get("notified", False),
        notified_at=notified_at,
        created_at=created_at,
        updated_at=updated_at,
        is_duplicate=is_duplicate
    )

@router.post("/", response_model=WaitlistResponse, status_code=status.HTTP_201_CREATED)
async def signup_waitlist(signup_data: WaitlistSignup):
    """
    Add email to waitlist using upsert to prevent duplicates
    
    Uses service_role client to bypass RLS for backend operations.
    Uses database-level upsert to handle duplicate emails gracefully.
    
    Args:
        signup_data: Email address for waitlist signup
        
    Returns:
        WaitlistResponse with signup confirmation
        
    Raises:
        HTTPException: If signup fails
    """
    # Normalize email (Pydantic already validates format)
    normalized_email = signup_data.email.lower().strip()
    
    # Use service_role client for backend operations (bypasses RLS)
    supabase = get_supabase_service_role_client()
    
    try:
        # First, check if email already exists
        from app.shared.utils.async_supabase import execute_async
        existing = await execute_async(
            lambda: supabase.table("waitlist").select(
                "id, email, notified, notified_at, created_at, updated_at"
            ).eq("email", normalized_email).execute()
        )
        
        if existing.data:
            # Email already exists, return existing entry with duplicate flag
            return _build_waitlist_response(existing.data[0], is_duplicate=True)
        
        # Email doesn't exist, insert new entry using centralized service
        from app.shared.services.database_operation_service import DatabaseOperationService
        
        db_service = DatabaseOperationService(supabase)
        entry = await db_service.insert_with_timestamps("waitlist", {
            "email": normalized_email
        })
        return _build_waitlist_response(entry, is_duplicate=False)
        
    except HTTPException:
        raise
    except Exception as e:
        error_str = str(e)
        
        # Handle RLS errors specifically
        if '42501' in error_str or 'row-level security' in error_str.lower():
            logger.error(f"RLS policy violation during waitlist signup: {error_str}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Database security policy error. Please contact support."
            )
        
        # Handle duplicate email constraint violations (PostgreSQL error code 23505)
        if 'duplicate' in error_str.lower() or 'unique' in error_str.lower() or '23505' in error_str:
            # Fetch existing entry
            try:
                from app.shared.utils.async_supabase import execute_async
                existing = await execute_async(
                    lambda: supabase.table("waitlist").select(
                        "id, email, notified, notified_at, created_at, updated_at"
                    ).eq("email", normalized_email).execute()
                )
                
                if existing.data:
                    return _build_waitlist_response(existing.data[0], is_duplicate=True)
            except Exception as fetch_error:
                logger.error(f"Failed to fetch existing waitlist entry: {fetch_error}")
        
        logger.error(f"Waitlist signup error: {error_str}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during waitlist signup"
        )

