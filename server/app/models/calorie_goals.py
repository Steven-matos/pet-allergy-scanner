"""
Calorie Goals Models
Models for managing pet calorie goals
"""

from pydantic import BaseModel, ConfigDict, Field
from datetime import datetime
from typing import Optional


class CalorieGoalBase(BaseModel):
    """Base calorie goal model"""
    pet_id: str
    daily_calories: float = Field(..., gt=0, description="Daily calorie goal in kcal")
    notes: Optional[str] = Field(None, max_length=500, description="Optional notes about the goal")


class CalorieGoalCreate(CalorieGoalBase):
    """Calorie goal creation model"""
    pass


class CalorieGoalUpdate(BaseModel):
    """Calorie goal update model"""
    daily_calories: float = Field(..., gt=0, description="Daily calorie goal in kcal")
    notes: Optional[str] = Field(None, max_length=500, description="Optional notes about the goal")


class CalorieGoalResponse(CalorieGoalBase):
    """Calorie goal response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CalorieGoalProgress(BaseModel):
    """Calorie goal progress model"""
    pet_id: str
    date: datetime
    goal_calories: float
    consumed_calories: float
    remaining_calories: float
    progress_percentage: float
    is_goal_met: bool
    is_over_goal: bool
