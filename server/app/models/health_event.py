"""
Health Event Model
Pet health event tracking for vomiting, shedding, vaccinations, etc.
"""

from datetime import datetime
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from enum import Enum


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


class HealthEvent(HealthEventBase):
    """Main HealthEvent model for database operations"""
    id: str
    pet_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class HealthEventCreate(HealthEventBase):
    """Schema for creating health events"""
    pet_id: str = Field(..., description="Pet ID for the health event")
    
    class Config:
        json_schema_extra = {
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
        json_schema_extra = {
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
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
        json_schema_extra = {
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
        json_schema_extra = {
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
