"""
Food Items Models
Models for managing food database and items
"""

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List, Dict, Any


class NutritionalInfoBase(BaseModel):
    """Base nutritional information model"""
    calories_per_100g: Optional[float] = Field(None, ge=0, description="Calories per 100g")
    protein_percentage: Optional[float] = Field(None, ge=0, le=100, description="Protein percentage")
    fat_percentage: Optional[float] = Field(None, ge=0, le=100, description="Fat percentage")
    fiber_percentage: Optional[float] = Field(None, ge=0, le=100, description="Fiber percentage")
    moisture_percentage: Optional[float] = Field(None, ge=0, le=100, description="Moisture percentage")
    ash_percentage: Optional[float] = Field(None, ge=0, le=100, description="Ash percentage")
    ingredients: Optional[List[str]] = Field(default_factory=list, description="List of ingredients")
    allergens: Optional[List[str]] = Field(default_factory=list, description="List of allergens")


class FoodItemBase(BaseModel):
    """Base food item model"""
    name: str = Field(..., min_length=1, max_length=200, description="Food name")
    brand: Optional[str] = Field(None, max_length=100, description="Brand name")
    barcode: Optional[str] = Field(None, max_length=50, description="Barcode/UPC")
    nutritional_info: Optional[NutritionalInfoBase] = Field(None, description="Nutritional information")
    category: Optional[str] = Field(None, max_length=50, description="Food category")
    description: Optional[str] = Field(None, max_length=500, description="Food description")


class FoodItemCreate(FoodItemBase):
    """Food item creation model"""
    pass


class FoodItemUpdate(BaseModel):
    """Food item update model"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    barcode: Optional[str] = Field(None, max_length=50)
    nutritional_info: Optional[NutritionalInfoBase] = None
    category: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=500)


class FoodItemResponse(FoodItemBase):
    """Food item response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class FoodSearchRequest(BaseModel):
    """Food search request model"""
    query: Optional[str] = Field(None, description="Search query")
    brand: Optional[str] = Field(None, description="Brand filter")
    category: Optional[str] = Field(None, description="Category filter")
    limit: int = Field(20, ge=1, le=100, description="Maximum results")
    offset: int = Field(0, ge=0, description="Results offset")


class FoodSearchResponse(BaseModel):
    """Food search response model"""
    items: List[FoodItemResponse]
    total_count: int
    has_more: bool


class FoodAnalysisResponse(BaseModel):
    """Food analysis response model for feeding calculations"""
    id: str
    food_name: str
    calories_per_100g: float
    protein_percentage: float
    fat_percentage: float
    fiber_percentage: float
    moisture_percentage: float
    ash_percentage: float
    ingredients: List[str]
    allergens: List[str]
    analyzed_at: datetime
    
    class Config:
        from_attributes = True
