"""
Food Items Models
Models for managing food database and items
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.shared.services.html_sanitization_service import HTMLSanitizationService


class NutritionalInfoBase(BaseModel):
    """
    Standardized nutritional information model with 22 fields
    Matches the API reference structure for consistent data handling
    """
    # Nutritional Values (numbers or null)
    calories_per_100g: Optional[float] = Field(None, ge=0, description="Calories per 100g")
    protein_percentage: Optional[float] = Field(None, ge=0, le=100, description="Protein percentage")
    fat_percentage: Optional[float] = Field(None, ge=0, le=100, description="Fat percentage")
    fiber_percentage: Optional[float] = Field(None, ge=0, le=100, description="Fiber percentage")
    moisture_percentage: Optional[float] = Field(None, ge=0, le=100, description="Moisture percentage")
    ash_percentage: Optional[float] = Field(None, ge=0, le=100, description="Ash percentage")
    carbohydrates_percentage: Optional[float] = Field(None, ge=0, le=100, description="Carbohydrates percentage")
    sugars_percentage: Optional[float] = Field(None, ge=0, le=100, description="Sugars percentage")
    saturated_fat_percentage: Optional[float] = Field(None, ge=0, le=100, description="Saturated fat percentage")
    sodium_percentage: Optional[float] = Field(None, ge=0, le=100, description="Sodium percentage")
    
    # Arrays (empty arrays if missing)
    ingredients: List[str] = Field(default_factory=list, description="List of ingredients")
    allergens: List[str] = Field(default_factory=list, description="List of allergens")
    additives: List[str] = Field(default_factory=list, description="List of food additives")
    vitamins: List[str] = Field(default_factory=list, description="List of vitamins")
    minerals: List[str] = Field(default_factory=list, description="List of minerals")
    
    # Strings (empty strings if missing)
    source: str = Field(default="", description="Data source identifier")
    external_id: str = Field(default="", description="External system ID")
    data_quality_score: float = Field(default=0.0, ge=0, le=1, description="Data completeness score (0-1)")
    last_updated: str = Field(default="", description="Last update timestamp")
    
    # Objects (empty objects if missing)
    nutrient_levels: Dict[str, Any] = Field(default_factory=dict, description="Nutrient level classifications")
    packaging_info: Dict[str, Any] = Field(default_factory=dict, description="Packaging details")
    manufacturing_info: Dict[str, Any] = Field(default_factory=dict, description="Manufacturing details")


class FoodItemBase(BaseModel):
    """Base food item model"""
    name: str = Field(..., min_length=1, max_length=200, description="Food name")
    brand: Optional[str] = Field(None, max_length=100, description="Brand name")
    barcode: Optional[str] = Field(None, max_length=50, description="Barcode/UPC")
    nutritional_info: Optional[NutritionalInfoBase] = Field(None, description="Nutritional information")
    category: Optional[str] = Field(None, max_length=50, description="Food category")
    description: Optional[str] = Field(None, max_length=500, description="Food description")
    
    @field_validator('description')
    @classmethod
    def sanitize_description(cls, v):
        """Sanitize description field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_description(v, max_length=500)


class FoodItemCreate(FoodItemBase):
    """Food item creation model with user-contributed metadata"""
    species: Optional[str] = Field(None, max_length=20, description="Target species (dog, cat)")
    language: Optional[str] = Field(None, max_length=10, description="Language code (e.g., 'en')")
    country: Optional[str] = Field(None, max_length=50, description="Country code (e.g., 'en:united-states')")
    external_source: Optional[str] = Field(None, max_length=50, description="External data source (e.g., 'snifftest')")
    keywords: Optional[List[str]] = Field(None, description="Keywords for searchability")


class FoodItemUpdate(BaseModel):
    """Food item update model"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    barcode: Optional[str] = Field(None, max_length=50)
    nutritional_info: Optional[NutritionalInfoBase] = None
    category: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=500)
    
    @field_validator('description')
    @classmethod
    def sanitize_description(cls, v):
        """Sanitize description field to prevent XSS"""
        if v is None:
            return v
        return HTMLSanitizationService.sanitize_description(v, max_length=500)


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
