"""
Health Event Model
Pet health event tracking for vomiting, shedding, vaccinations, etc.
"""

from datetime import datetime
from pydantic import BaseModel, Field, field_validator, ConfigDict, computed_field, model_validator
from typing import Optional, List
from enum import Enum
from app.shared.services.html_sanitization_service import HTMLSanitizationService


class HealthEventCategory(str, Enum):
    """Health event categories"""
    DIGESTIVE = "digestive"
    PHYSICAL = "physical"
    MEDICAL = "medical"
    BEHAVIORAL = "behavioral"
    
    @classmethod
    def from_event_type(cls, event_type: str) -> "HealthEventCategory":
        """Get category from event type"""
        category_mapping = {
            HealthEventType.VOMITING: cls.DIGESTIVE,
            HealthEventType.DIARRHEA: cls.DIGESTIVE,
            HealthEventType.SHEDDING: cls.PHYSICAL,
            HealthEventType.LOW_ENERGY: cls.PHYSICAL,
            HealthEventType.VACCINATION: cls.MEDICAL,
            HealthEventType.VET_VISIT: cls.MEDICAL,
            HealthEventType.MEDICATION: cls.MEDICAL,
            HealthEventType.ANXIETY: cls.BEHAVIORAL,
            HealthEventType.OTHER: cls.PHYSICAL,  # Default for custom events
        }
        return category_mapping.get(event_type, cls.PHYSICAL)


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
    documents: Optional[List[str]] = None  # Array of document URLs for vet paperwork
    
    @field_validator('event_type')
    @classmethod
    def validate_event_type(cls, v):
        """Validate event type and set category"""
        return v
    
    @field_validator('title')
    @classmethod
    def sanitize_title(cls, v):
        """Sanitize title field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_title(v, max_length=200)
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_notes(v, max_length=1000)
    
    @computed_field
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
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "pet_id": "123e4567-e89b-12d3-a456-426614174000",
                "event_type": "vomiting",
                "title": "Morning vomiting episode",
                "notes": "Vomited after breakfast, seemed fine afterwards",
                "severity_level": 2,
                "event_date": "2025-01-15T08:30:00Z"
            }
        }
    )


class HealthEventUpdate(BaseModel):
    """Schema for updating health events"""
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    notes: Optional[str] = None
    severity_level: Optional[int] = Field(None, ge=1, le=5)
    event_date: Optional[datetime] = None
    documents: Optional[List[str]] = None  # Array of document URLs for vet paperwork
    
    @field_validator('title')
    @classmethod
    def sanitize_title(cls, v):
        """Sanitize title field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_title(v, max_length=200)
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_notes(v, max_length=1000)
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "title": "Updated vomiting episode",
                "notes": "Added more details about the incident",
                "severity_level": 3,
                "event_date": "2025-01-15T09:00:00Z"
            }
        }
    )


class HealthEventResponse(HealthEventBase):
    """Schema for health event responses"""
    id: str
    pet_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
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
    )


class HealthEventListResponse(BaseModel):
    """Schema for health event list responses"""
    events: List[HealthEventResponse]
    total: int
    limit: int
    offset: int
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "events": [
                    {
                        "id": "123e4567-e89b-12d3-a456-426614174000",
                        "pet_id": "123e4567-e89b-12d3-a456-426614174001",
                        "user_id": "123e4567-e89b-12d3-a456-426614174002",
                        "event_type": "vomiting",
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
    )
