"""
User data models and schemas
"""

from pydantic import BaseModel, ConfigDict, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    """User role enumeration"""
    FREE = "free"
    PREMIUM = "premium"

class UserBase(BaseModel):
    """Base user model with common fields"""
    email: EmailStr
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    image_url: Optional[str] = None
    role: UserRole = UserRole.FREE
    onboarded: bool = False

class UserCreate(UserBase):
    """User creation model"""
    password: str

class UserUpdate(BaseModel):
    """User update model"""
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    image_url: Optional[str] = None
    role: Optional[UserRole] = None
    onboarded: Optional[bool] = None
    device_token: Optional[str] = None

class UserResponse(UserBase):
    """User response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class UserInDB(UserResponse):
    """User model with internal fields"""
    hashed_password: str

class User(UserResponse):
    """Main User model for database operations"""
    device_token: Optional[str] = None

class UserLogin(BaseModel):
    """User login model - accepts either email or username"""
    email_or_username: str
    password: str
