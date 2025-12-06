"""
Nutrition data models and schemas for pet nutrition tracking
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator
from typing import Optional, List, Dict, Any
from datetime import datetime, date
from enum import Enum
from decimal import Decimal

class NutritionCompatibilityLevel(str, Enum):
    """Nutrition compatibility level enumeration"""
    EXCELLENT = "excellent"
    GOOD = "good"
    FAIR = "fair"
    POOR = "poor"

class NutritionalRequirementsBase(BaseModel):
    """Base nutritional requirements model"""
    pet_id: str
    daily_calories: float = Field(..., gt=0)
    protein_percentage: float = Field(..., ge=0, le=100)
    fat_percentage: float = Field(..., ge=0, le=100)
    fiber_percentage: float = Field(..., ge=0, le=100)
    moisture_percentage: float = Field(..., ge=0, le=100)
    life_stage: str
    activity_level: str
    calculated_at: datetime

class NutritionalRequirementsCreate(NutritionalRequirementsBase):
    """Nutritional requirements creation model"""
    pass

class NutritionalRequirementsResponse(NutritionalRequirementsBase):
    """Nutritional requirements response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    # Override daily_calories to allow 0 for default/empty responses
    daily_calories: float = Field(..., ge=0)  # Allow 0 for "no data" responses
    
    class Config:
        from_attributes = True

class FoodAnalysisBase(BaseModel):
    """Base food analysis model"""
    pet_id: str
    food_name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    calories_per_100g: float = Field(..., ge=0)
    protein_percentage: float = Field(..., ge=0, le=100)
    fat_percentage: float = Field(..., ge=0, le=100)
    fiber_percentage: float = Field(..., ge=0, le=100)
    moisture_percentage: float = Field(..., ge=0, le=100)
    ingredients: List[str] = Field(default_factory=list)
    allergens: List[str] = Field(default_factory=list)
    analyzed_at: datetime

class FoodAnalysisCreate(BaseModel):
    """Food analysis creation model"""
    pet_id: str
    food_name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    ingredients: List[str] = Field(default_factory=list)
    nutritional_info: Optional['NutritionalInfo'] = None

class NutritionalInfo(BaseModel):
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

class FoodAnalysisResponse(FoodAnalysisBase):
    """Food analysis response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class NutritionCompatibilityResponse(BaseModel):
    """Nutrition compatibility assessment response"""
    food_analysis: FoodAnalysisResponse
    requirements: NutritionalRequirementsResponse
    compatibility: NutritionCompatibilityLevel
    score: float = Field(..., ge=0, le=100)
    issues: List[str] = Field(default_factory=list)
    recommendations: List[str] = Field(default_factory=list)
    assessed_at: datetime
    
    @property
    def compatibility_description(self) -> str:
        """Get user-friendly compatibility description"""
        descriptions = {
            NutritionCompatibilityLevel.EXCELLENT: "Excellent match for your pet's nutritional needs",
            NutritionCompatibilityLevel.GOOD: "Good nutritional match with minor considerations",
            NutritionCompatibilityLevel.FAIR: "Fair match - some nutritional gaps to address",
            NutritionCompatibilityLevel.POOR: "Poor match - significant nutritional concerns"
        }
        return descriptions.get(self.compatibility, "Unknown compatibility level")
    
    @property
    def compatibility_color(self) -> str:
        """Get color for UI representation"""
        colors = {
            NutritionCompatibilityLevel.EXCELLENT: "green",
            NutritionCompatibilityLevel.GOOD: "blue",
            NutritionCompatibilityLevel.FAIR: "orange",
            NutritionCompatibilityLevel.POOR: "red"
        }
        return colors.get(self.compatibility, "gray")

class FeedingRecordBase(BaseModel):
    """Base feeding record model"""
    pet_id: str
    food_analysis_id: str
    amount_grams: float = Field(..., gt=0)
    feeding_time: datetime
    notes: Optional[str] = Field(None, max_length=500)
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        from app.shared.services.html_sanitization_service import HTMLSanitizationService
        return HTMLSanitizationService.sanitize_notes(v, max_length=500)

class FeedingRecordCreate(FeedingRecordBase):
    """Feeding record creation model"""
    pass

class FeedingRecordResponse(FeedingRecordBase):
    """Feeding record response model"""
    id: str
    created_at: datetime
    food_name: Optional[str] = None  # Optional: populated when joining food_analysis
    food_brand: Optional[str] = None  # Optional: populated when joining food_analysis
    calories: Optional[float] = None  # Optional: calculated from food_analysis and amount_grams
    
    class Config:
        from_attributes = True

class DailyNutritionSummaryBase(BaseModel):
    """Base daily nutrition summary model"""
    pet_id: str
    date: date
    total_calories: float = Field(..., ge=0)
    total_protein: float = Field(..., ge=0)
    total_fat: float = Field(..., ge=0)
    total_fiber: float = Field(..., ge=0)
    feeding_count: int = Field(..., ge=0)
    average_compatibility: float = Field(..., ge=0, le=100)
    recommendations: List[str] = Field(default_factory=list)

class DailyNutritionSummaryResponse(DailyNutritionSummaryBase):
    """Daily nutrition summary response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class MultiPetNutritionInsights(BaseModel):
    """Multi-pet nutrition insights"""
    pets: List[Dict[str, Any]]
    generated_at: datetime
    requirements: Dict[str, NutritionalRequirementsResponse] = Field(default_factory=dict)
    recent_summaries: Dict[str, List[DailyNutritionSummaryResponse]] = Field(default_factory=dict)
    comparative_insights: List['ComparativeInsight'] = Field(default_factory=list)

class ComparativeInsight(BaseModel):
    """Comparative insight across multiple pets"""
    type: str
    title: str
    description: str
    severity: str
    
    class Config:
        from_attributes = True

class NutritionAnalysisRequest(BaseModel):
    """Request model for nutrition analysis"""
    pet_id: str
    food_name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    ingredients: List[str] = Field(default_factory=list)
    nutritional_info: Optional[NutritionalInfo] = None

class NutritionRecommendation(BaseModel):
    """Nutrition recommendation model"""
    pet_id: str
    title: str
    description: str
    priority: str = Field(..., pattern="^(low|medium|high|critical)$")
    category: str = Field(..., pattern="^(diet|feeding|supplement|warning)$")
    created_at: datetime
    expires_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class NutritionGoal(BaseModel):
    """Nutrition goal model for tracking pet health objectives"""
    pet_id: str
    goal_type: str = Field(..., pattern="^(weight_loss|weight_gain|maintenance|health_improvement)$")
    target_value: Optional[float] = None
    current_value: Optional[float] = None
    target_date: Optional[date] = None
    is_active: bool = True
    notes: Optional[str] = Field(None, max_length=1000)
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# Update forward references
NutritionalInfo.model_rebuild()
FoodAnalysisCreate.model_rebuild()
MultiPetNutritionInsights.model_rebuild()
