"""
Waitlist data models and schemas
"""
from pydantic import BaseModel, ConfigDict, EmailStr, field_validator
from datetime import datetime
from typing import Optional

class WaitlistSignup(BaseModel):
    """
    Waitlist signup request model
    """
    email: EmailStr
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Validate and normalize email"""
        return v.lower().strip()

class WaitlistResponse(BaseModel):
    """
    Waitlist response model
    """
    id: str
    email: str
    notified: bool
    notified_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

