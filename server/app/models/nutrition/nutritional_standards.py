"""
Nutritional standards data models and schemas
Based on AAFCO guidelines for pet nutrition
"""

from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
from datetime import datetime
from enum import Enum
from decimal import Decimal

class Species(str, Enum):
    """Pet species enumeration"""
    DOG = "dog"
    CAT = "cat"

class LifeStage(str, Enum):
    """Pet life stage enumeration"""
    PUPPY = "puppy"
    ADULT = "adult"
    SENIOR = "senior"
    PREGNANT = "pregnant"
    LACTATING = "lactating"

class ActivityLevel(str, Enum):
    """Pet activity level enumeration"""
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"

class NutritionalStandardBase(BaseModel):
    """Base nutritional standard model"""
    species: Species
    life_stage: LifeStage
    weight_range_min: float = Field(..., gt=0, description="Minimum weight in kg")
    weight_range_max: float = Field(..., gt=0, description="Maximum weight in kg")
    activity_level: ActivityLevel = ActivityLevel.MODERATE
    calories_per_kg: float = Field(..., gt=0, description="Calories per kg of body weight")
    protein_min_percent: float = Field(..., ge=0, le=100, description="Minimum protein percentage")
    fat_min_percent: float = Field(..., ge=0, le=100, description="Minimum fat percentage")
    fiber_max_percent: float = Field(..., ge=0, le=100, description="Maximum fiber percentage")
    moisture_max_percent: float = Field(..., ge=0, le=100, description="Maximum moisture percentage")
    ash_max_percent: float = Field(..., ge=0, le=100, description="Maximum ash percentage")
    calcium_min_percent: Optional[float] = Field(None, ge=0, le=100, description="Minimum calcium percentage")
    phosphorus_min_percent: Optional[float] = Field(None, ge=0, le=100, description="Minimum phosphorus percentage")

class NutritionalStandardCreate(NutritionalStandardBase):
    """Nutritional standard creation model"""
    pass

class NutritionalStandardUpdate(BaseModel):
    """Nutritional standard update model"""
    species: Optional[Species] = None
    life_stage: Optional[LifeStage] = None
    weight_range_min: Optional[float] = Field(None, gt=0)
    weight_range_max: Optional[float] = Field(None, gt=0)
    activity_level: Optional[ActivityLevel] = None
    calories_per_kg: Optional[float] = Field(None, gt=0)
    protein_min_percent: Optional[float] = Field(None, ge=0, le=100)
    fat_min_percent: Optional[float] = Field(None, ge=0, le=100)
    fiber_max_percent: Optional[float] = Field(None, ge=0, le=100)
    moisture_max_percent: Optional[float] = Field(None, ge=0, le=100)
    ash_max_percent: Optional[float] = Field(None, ge=0, le=100)
    calcium_min_percent: Optional[float] = Field(None, ge=0, le=100)
    phosphorus_min_percent: Optional[float] = Field(None, ge=0, le=100)

class NutritionalStandardResponse(NutritionalStandardBase):
    """Nutritional standard response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class NutritionalRecommendation(BaseModel):
    """Nutritional recommendation for a specific pet"""
    pet_id: str
    species: Species
    life_stage: LifeStage
    weight_kg: float = Field(..., gt=0)
    activity_level: ActivityLevel
    daily_calories_needed: float = Field(..., gt=0)
    protein_requirement_percent: float = Field(..., ge=0, le=100)
    fat_requirement_percent: float = Field(..., ge=0, le=100)
    fiber_limit_percent: float = Field(..., ge=0, le=100)
    moisture_limit_percent: float = Field(..., ge=0, le=100)
    ash_limit_percent: float = Field(..., ge=0, le=100)
    calcium_requirement_percent: Optional[float] = Field(None, ge=0, le=100)
    phosphorus_requirement_percent: Optional[float] = Field(None, ge=0, le=100)
    recommendations: dict = Field(default_factory=dict, description="Additional recommendations")

class NutritionalAnalysisRequest(BaseModel):
    """Request model for nutritional analysis"""
    pet_id: str
    product_name: Optional[str] = None
    brand: Optional[str] = None
    serving_size_g: Optional[float] = Field(None, gt=0)
    calories_per_serving: Optional[float] = Field(None, gt=0)
    macronutrients: Optional[dict] = None
    minerals: Optional[dict] = None
