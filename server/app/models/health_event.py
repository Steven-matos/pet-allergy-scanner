"""
Health Event Model
Pet health event tracking for vomiting, shedding, vaccinations, etc.
"""

from sqlalchemy import Column, String, Text, Integer, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from enum import Enum

from app.database import Base


class HealthEventCategory(str, Enum):
    """Health event categories"""
    DIGESTIVE = "digestive"
    PHYSICAL = "physical"
    MEDICAL = "medical"
    BEHAVIORAL = "behavioral"


class HealthEventType(str, Enum):
    """Health event types"""
    VOMITING = "vomiting"
    DIARRHEA = "diarrhea"
    SHEDDING = "shedding"
    LOW_ENERGY = "low_energy"
    VACCINATION = "vaccination"
    VET_VISIT = "vet_visit"
    MEDICATION = "medication"
    ANXIETY = "anxiety"
    OTHER = "other"


class HealthEvent(Base):
    """Health event database model"""
    __tablename__ = "health_events"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pet_id = Column(UUID(as_uuid=True), ForeignKey("pets.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String(100), nullable=False)
    event_category = Column(String(50), nullable=False)
    title = Column(String(200), nullable=False)
    notes = Column(Text)
    severity_level = Column(Integer, default=1)
    event_date = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Add check constraints
    __table_args__ = (
        CheckConstraint('event_category IN (\'digestive\', \'physical\', \'medical\', \'behavioral\')', name='check_event_category'),
        CheckConstraint('severity_level BETWEEN 1 AND 5', name='check_severity_level'),
        CheckConstraint('LENGTH(title) > 0 AND LENGTH(title) <= 200', name='check_title_length'),
    )


# Pydantic schemas for API
class HealthEventBase(BaseModel):
    """Base health event schema"""
    event_type: HealthEventType
    title: str = Field(..., min_length=1, max_length=200)
    notes: Optional[str] = None
    severity_level: int = Field(default=1, ge=1, le=5)
    event_date: datetime = Field(default_factory=datetime.utcnow)
    
    @validator('event_type')
    def validate_event_type(cls, v):
        """Validate event type and set category"""
        return v
    
    @property
    def event_category(self) -> HealthEventCategory:
        """Get category from event type"""
        category_mapping = {
            HealthEventType.VOMITING: HealthEventCategory.DIGESTIVE,
            HealthEventType.DIARRHEA: HealthEventCategory.DIGESTIVE,
            HealthEventType.SHEDDING: HealthEventCategory.PHYSICAL,
            HealthEventType.LOW_ENERGY: HealthEventCategory.PHYSICAL,
            HealthEventType.VACCINATION: HealthEventCategory.MEDICAL,
            HealthEventType.VET_VISIT: HealthEventCategory.MEDICAL,
            HealthEventType.MEDICATION: HealthEventCategory.MEDICAL,
            HealthEventType.ANXIETY: HealthEventCategory.BEHAVIORAL,
            HealthEventType.OTHER: HealthEventCategory.PHYSICAL,  # Default for custom events
        }
        return category_mapping.get(self.event_type, HealthEventCategory.PHYSICAL)


class HealthEventCreate(HealthEventBase):
    """Schema for creating health events"""
    pet_id: str = Field(..., description="Pet ID for the health event")
    
    class Config:
        schema_extra = {
            "example": {
                "pet_id": "123e4567-e89b-12d3-a456-426614174000",
                "event_type": "vomiting",
                "title": "Morning vomiting episode",
                "notes": "Vomited after breakfast, seemed fine afterwards",
                "severity_level": 2,
                "event_date": "2025-01-15T08:30:00Z"
            }
        }


class HealthEventUpdate(BaseModel):
    """Schema for updating health events"""
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    notes: Optional[str] = None
    severity_level: Optional[int] = Field(None, ge=1, le=5)
    event_date: Optional[datetime] = None
    
    class Config:
        schema_extra = {
            "example": {
                "title": "Updated vomiting episode",
                "notes": "Added more details about the incident",
                "severity_level": 3,
                "event_date": "2025-01-15T09:00:00Z"
            }
        }


class HealthEventResponse(HealthEventBase):
    """Schema for health event responses"""
    id: str
    pet_id: str
    user_id: str
    event_category: HealthEventCategory
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
        schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "pet_id": "123e4567-e89b-12d3-a456-426614174001",
                "user_id": "123e4567-e89b-12d3-a456-426614174002",
                "event_type": "vomiting",
                "event_category": "digestive",
                "title": "Morning vomiting episode",
                "notes": "Vomited after breakfast, seemed fine afterwards",
                "severity_level": 2,
                "event_date": "2025-01-15T08:30:00Z",
                "created_at": "2025-01-15T08:30:00Z",
                "updated_at": "2025-01-15T08:30:00Z"
            }
        }


class HealthEventListResponse(BaseModel):
    """Schema for health event list responses"""
    events: List[HealthEventResponse]
    total: int
    limit: int
    offset: int
    
    class Config:
        schema_extra = {
            "example": {
                "events": [
                    {
                        "id": "123e4567-e89b-12d3-a456-426614174000",
                        "pet_id": "123e4567-e89b-12d3-a456-426614174001",
                        "user_id": "123e4567-e89b-12d3-a456-426614174002",
                        "event_type": "vomiting",
                        "event_category": "digestive",
                        "title": "Morning vomiting episode",
                        "notes": "Vomited after breakfast",
                        "severity_level": 2,
                        "event_date": "2025-01-15T08:30:00Z",
                        "created_at": "2025-01-15T08:30:00Z",
                        "updated_at": "2025-01-15T08:30:00Z"
                    }
                ],
                "total": 1,
                "limit": 50,
                "offset": 0
            }
        }
