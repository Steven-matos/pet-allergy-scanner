"""
Waitlist router for email signup management
"""
from fastapi import APIRouter, HTTPException, status
from datetime import datetime
from app.models.waitlist import WaitlistSignup, WaitlistResponse
from app.database import get_supabase_client
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

@router.post("/", response_model=WaitlistResponse, status_code=status.HTTP_201_CREATED)
async def signup_waitlist(signup_data: WaitlistSignup):
    """
    Add email to waitlist
    
    Args:
        signup_data: Email address for waitlist signup
        
    Returns:
        WaitlistResponse with signup confirmation
        
    Raises:
        HTTPException: If signup fails or email already exists
    """
    try:
        # Normalize email (Pydantic already validates format)
        normalized_email = signup_data.email.lower().strip()
        
        supabase = get_supabase_client()
        
        # Check if email already exists
        existing = supabase.table("waitlist").select("id, email, notified, notified_at, created_at, updated_at").eq("email", normalized_email).execute()
        
        if existing.data:
            # Email already exists, return existing entry
            logger.info(f"Waitlist signup: Email {normalized_email} already exists")
            existing_entry = existing.data[0]
            
            # Parse datetime strings
            created_at = datetime.fromisoformat(existing_entry["created_at"].replace("Z", "+00:00"))
            updated_at = datetime.fromisoformat(existing_entry["updated_at"].replace("Z", "+00:00"))
            notified_at = None
            if existing_entry.get("notified_at"):
                notified_at = datetime.fromisoformat(existing_entry["notified_at"].replace("Z", "+00:00"))
            
            return WaitlistResponse(
                id=existing_entry["id"],
                email=existing_entry["email"],
                notified=existing_entry.get("notified", False),
                notified_at=notified_at,
                created_at=created_at,
                updated_at=updated_at
            )
        
        # Insert new waitlist entry
        insert_response = supabase.table("waitlist").insert({
            "email": normalized_email
        }).execute()
        
        if not insert_response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to add email to waitlist"
            )
        
        logger.info(f"Waitlist signup successful: {normalized_email}")
        entry = insert_response.data[0]
        
        # Parse datetime strings
        created_at = datetime.fromisoformat(entry["created_at"].replace("Z", "+00:00"))
        updated_at = datetime.fromisoformat(entry["updated_at"].replace("Z", "+00:00"))
        notified_at = None
        if entry.get("notified_at"):
            notified_at = datetime.fromisoformat(entry["notified_at"].replace("Z", "+00:00"))
        
        return WaitlistResponse(
            id=entry["id"],
            email=entry["email"],
            notified=entry.get("notified", False),
            notified_at=notified_at,
            created_at=created_at,
            updated_at=updated_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Waitlist signup error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during waitlist signup"
        )

