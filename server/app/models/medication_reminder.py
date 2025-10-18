"""
Medication Reminder Model
Pet medication reminder scheduling and management
"""

from datetime import datetime
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List
from enum import Enum


class MedicationFrequency(str, Enum):
    """Medication frequency options"""
    ONCE = "once"
    DAILY = "daily"
    TWICE_DAILY = "twice_daily"
    THREE_TIMES_DAILY = "three_times_daily"
    EVERY_OTHER_DAY = "every_other_day"
    WEEKLY = "weekly"
    AS_NEEDED = "as_needed"
    
    @property
    def display_name(self) -> str:
        """Display name for UI"""
        mapping = {
            "once": "Once",
            "daily": "Daily", 
            "twice_daily": "Twice Daily",
            "three_times_daily": "Three Times Daily",
            "every_other_day": "Every Other Day",
            "weekly": "Weekly",
            "as_needed": "As Needed"
        }
        return mapping.get(self.value, self.value)
    
    @property
    def description(self) -> str:
        """Description for UI"""
        mapping = {
            "once": "One time only",
            "daily": "Once per day",
            "twice_daily": "Morning and evening",
            "three_times_daily": "Morning, afternoon, and evening",
            "every_other_day": "Every other day",
            "weekly": "Once per week",
            "as_needed": "When symptoms occur"
        }
        return mapping.get(self.value, self.value)


class MedicationReminderTime(BaseModel):
    """Medication reminder time"""
    time: str = Field(..., description="Time in HH:MM format")
    label: str = Field(..., description="Label for the reminder time")
    
    @field_validator('time')
    @classmethod
    def validate_time_format(cls, v):
        """Validate time format"""
        import re
        if not re.match(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$', v):
            raise ValueError('Time must be in HH:MM format')
        return v


class MedicationReminderBase(BaseModel):
    """Base medication reminder schema"""
    medication_name: str = Field(..., min_length=1, max_length=200)
    dosage: str = Field(..., min_length=1, max_length=100)
    frequency: MedicationFrequency
    reminder_times: List[MedicationReminderTime] = Field(..., min_length=1)
    start_date: datetime
    end_date: Optional[datetime] = None
    is_active: bool = Field(default=True)
    
    @field_validator('reminder_times')
    @classmethod
    def validate_reminder_times(cls, v):
        """Validate reminder times"""
        if not v:
            raise ValueError('At least one reminder time is required')
        return v


class MedicationReminder(MedicationReminderBase):
    """Main MedicationReminder model for database operations"""
    id: str
    health_event_id: str
    pet_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime


class MedicationReminderCreate(MedicationReminderBase):
    """Schema for creating medication reminders"""
    health_event_id: str = Field(..., description="Health event ID for the medication")
    pet_id: str = Field(..., description="Pet ID for the medication reminder")
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "health_event_id": "123e4567-e89b-12d3-a456-426614174000",
                "pet_id": "123e4567-e89b-12d3-a456-426614174001",
                "medication_name": "Amoxicillin",
                "dosage": "250mg",
                "frequency": "twice_daily",
                "reminder_times": [
                    {"time": "09:00", "label": "Morning"},
                    {"time": "21:00", "label": "Evening"}
                ],
                "start_date": "2025-01-15T09:00:00Z",
                "end_date": "2025-01-22T09:00:00Z",
                "is_active": True
            }
        }
    )


class MedicationReminderUpdate(BaseModel):
    """Schema for updating medication reminders"""
    medication_name: Optional[str] = Field(None, min_length=1, max_length=200)
    dosage: Optional[str] = Field(None, min_length=1, max_length=100)
    frequency: Optional[MedicationFrequency] = None
    reminder_times: Optional[List[MedicationReminderTime]] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    is_active: Optional[bool] = None
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "medication_name": "Updated Amoxicillin",
                "dosage": "500mg",
                "frequency": "daily",
                "reminder_times": [
                    {"time": "08:00", "label": "Morning"}
                ],
                "is_active": False
            }
        }
    )


class MedicationReminderResponse(MedicationReminderBase):
    """Schema for medication reminder responses"""
    id: str
    health_event_id: str
    pet_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "health_event_id": "123e4567-e89b-12d3-a456-426614174001",
                "pet_id": "123e4567-e89b-12d3-a456-426614174002",
                "user_id": "123e4567-e89b-12d3-a456-426614174003",
                "medication_name": "Amoxicillin",
                "dosage": "250mg",
                "frequency": "twice_daily",
                "reminder_times": [
                    {"time": "09:00", "label": "Morning"},
                    {"time": "21:00", "label": "Evening"}
                ],
                "start_date": "2025-01-15T09:00:00Z",
                "end_date": "2025-01-22T09:00:00Z",
                "is_active": True,
                "created_at": "2025-01-15T09:00:00Z",
                "updated_at": "2025-01-15T09:00:00Z"
            }
        }
    )


class MedicationReminderListResponse(BaseModel):
    """Schema for medication reminder list responses"""
    reminders: List[MedicationReminderResponse]
    total: int
    limit: int
    offset: int
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "reminders": [
                    {
                        "id": "123e4567-e89b-12d3-a456-426614174000",
                        "health_event_id": "123e4567-e89b-12d3-a456-426614174001",
                        "pet_id": "123e4567-e89b-12d3-a456-426614174002",
                        "user_id": "123e4567-e89b-12d3-a456-426614174003",
                        "medication_name": "Amoxicillin",
                        "dosage": "250mg",
                        "frequency": "twice_daily",
                        "reminder_times": [
                            {"time": "09:00", "label": "Morning"},
                            {"time": "21:00", "label": "Evening"}
                        ],
                        "start_date": "2025-01-15T09:00:00Z",
                        "end_date": "2025-01-22T09:00:00Z",
                        "is_active": True,
                        "created_at": "2025-01-15T09:00:00Z",
                        "updated_at": "2025-01-15T09:00:00Z"
                    }
                ],
                "total": 1,
                "limit": 50,
                "offset": 0
            }
        }
    )
