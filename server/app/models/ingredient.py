"""
Ingredient data models and schemas
"""

from pydantic import BaseModel, Field
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

class IngredientBase(BaseModel):
    """Base ingredient model"""
    name: str = Field(..., min_length=1, max_length=200)
    aliases: List[str] = Field(default_factory=list)
    safety_level: IngredientSafety = IngredientSafety.UNKNOWN
    species_compatibility: SpeciesCompatibility = SpeciesCompatibility.BOTH
    description: Optional[str] = None
    common_allergen: bool = False
    nutritional_value: Optional[Dict[str, str]] = None

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
    nutritional_value: Optional[Dict[str, str]] = None

class IngredientResponse(IngredientBase):
    """Ingredient response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class IngredientAnalysis(BaseModel):
    """Ingredient analysis result"""
    ingredient_name: str
    safety_level: IngredientSafety
    is_unsafe_for_pet: bool
    reason: Optional[str] = None
    alternatives: List[str] = Field(default_factory=list)
