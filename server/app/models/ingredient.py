"""
Ingredient data models and schemas
"""

from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List, Dict
from datetime import datetime
from enum import Enum

class IngredientSafety(str, Enum):
    """Ingredient safety level enumeration"""
    SAFE = "safe"
    CAUTION = "caution"
    UNSAFE = "unsafe"
    UNKNOWN = "unknown"

class SpeciesCompatibility(str, Enum):
    """Species compatibility enumeration"""
    DOG_ONLY = "dog_only"
    CAT_ONLY = "cat_only"
    BOTH = "both"
    NEITHER = "neither"

class IngredientNutritionalValue(BaseModel):
    """Structured nutritional value for ingredients"""
    calories_per_100g: Optional[float] = Field(None, gt=0, description="Calories per 100g")
    protein_percent: Optional[float] = Field(None, ge=0, le=100, description="Protein percentage")
    fat_percent: Optional[float] = Field(None, ge=0, le=100, description="Fat percentage")
    fiber_percent: Optional[float] = Field(None, ge=0, le=100, description="Fiber percentage")
    moisture_percent: Optional[float] = Field(None, ge=0, le=100, description="Moisture percentage")
    ash_percent: Optional[float] = Field(None, ge=0, le=100, description="Ash percentage")
    calcium_percent: Optional[float] = Field(None, ge=0, le=100, description="Calcium percentage")
    phosphorus_percent: Optional[float] = Field(None, ge=0, le=100, description="Phosphorus percentage")

class IngredientBase(BaseModel):
    """Base ingredient model"""
    name: str = Field(..., min_length=1, max_length=200)
    aliases: List[str] = Field(default_factory=list)
    safety_level: IngredientSafety = IngredientSafety.UNKNOWN
    species_compatibility: SpeciesCompatibility = SpeciesCompatibility.BOTH
    description: Optional[str] = None
    common_allergen: bool = False
    nutritional_value: Optional[IngredientNutritionalValue] = None

class IngredientCreate(IngredientBase):
    """Ingredient creation model"""
    pass

class IngredientUpdate(BaseModel):
    """Ingredient update model"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    aliases: Optional[List[str]] = None
    safety_level: Optional[IngredientSafety] = None
    species_compatibility: Optional[SpeciesCompatibility] = None
    description: Optional[str] = None
    common_allergen: Optional[bool] = None
    nutritional_value: Optional[IngredientNutritionalValue] = None

class IngredientResponse(IngredientBase):
    """Ingredient response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class IngredientAnalysis(BaseModel):
    """Ingredient analysis result"""
    ingredients: List[IngredientResponse] = Field(default_factory=list)
    safe_ingredients: List[str] = Field(default_factory=list)
    caution_ingredients: List[str] = Field(default_factory=list)
    dangerous_ingredients: List[str] = Field(default_factory=list)
    unknown_ingredients: List[str] = Field(default_factory=list)
    allergy_warnings: List[str] = Field(default_factory=list)
    overall_safety: str = "unknown"
    recommendations: List[str] = Field(default_factory=list)
    confidence_score: float = Field(default=0.0, ge=0.0, le=1.0)
