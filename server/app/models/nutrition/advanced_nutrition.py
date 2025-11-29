"""
Phase 3 Advanced Nutritional Analysis Models
Weight tracking, trends, comparisons, and advanced analytics
"""

from pydantic import BaseModel, ConfigDict, Field, validator, field_validator, ConfigDict
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date
from enum import Enum
from decimal import Decimal


class WeightGoalType(str, Enum):
    """Weight goal type enumeration"""
    WEIGHT_LOSS = "weight_loss"
    WEIGHT_GAIN = "weight_gain"
    MAINTENANCE = "maintenance"
    HEALTH_IMPROVEMENT = "health_improvement"


class RecommendationPriority(str, Enum):
    """Recommendation priority levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class RecommendationCategory(str, Enum):
    """Recommendation categories"""
    DIET = "diet"
    FEEDING = "feeding"
    SUPPLEMENT = "supplement"
    WARNING = "warning"
    WEIGHT = "weight"


class TrendDirection(str, Enum):
    """Weight trend direction"""
    INCREASING = "increasing"
    DECREASING = "decreasing"
    STABLE = "stable"


class TrendStrength(str, Enum):
    """Trend strength levels"""
    WEAK = "weak"
    MODERATE = "moderate"
    STRONG = "strong"


# Weight Tracking Models

class PetWeightRecordBase(BaseModel):
    """Base weight record model"""
    pet_id: str
    weight_kg: float = Field(..., gt=0, le=200, description="Weight in kilograms")
    recorded_at: datetime = Field(default_factory=datetime.utcnow)
    notes: Optional[str] = Field(None, max_length=500)
    
    model_config = ConfigDict(populate_by_name=True)
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        from app.shared.services.html_sanitization_service import HTMLSanitizationService
        return HTMLSanitizationService.sanitize_notes(v, max_length=500)


class PetWeightRecordCreate(PetWeightRecordBase):
    """Weight record creation model"""
    pass


class PetWeightRecordResponse(PetWeightRecordBase):
    """Weight record response model"""
    id: str
    recorded_by_user_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class PetWeightGoalBase(BaseModel):
    """Base weight goal model"""
    pet_id: str
    goal_type: WeightGoalType
    target_weight_kg: Optional[float] = Field(None, gt=0, le=200, serialization_alias="targetWeightKg", validation_alias="targetWeightKg")
    current_weight_kg: Optional[float] = Field(None, gt=0, le=200, serialization_alias="currentWeightKg", validation_alias="currentWeightKg")
    target_date: Optional[date] = Field(None, serialization_alias="targetDate", validation_alias="targetDate")
    is_active: bool = Field(True, serialization_alias="isActive", validation_alias="isActive")
    notes: Optional[str] = Field(None, max_length=1000)
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        from app.shared.services.html_sanitization_service import HTMLSanitizationService
        return HTMLSanitizationService.sanitize_notes(v, max_length=1000)
    
    @field_validator('target_date', mode='before')
    @classmethod
    def parse_target_date(cls, v):
        """Parse target_date from datetime string to date"""
        if v is None:
            return None
        if isinstance(v, date):
            return v
        if isinstance(v, datetime):
            return v.date()
        if isinstance(v, str):
            # Parse ISO datetime string and extract date
            try:
                dt = datetime.fromisoformat(v.replace('Z', '+00:00'))
                return dt.date()
            except ValueError:
                # Try parsing as date string
                try:
                    return datetime.strptime(v, '%Y-%m-%d').date()
                except ValueError:
                    raise ValueError(f"Invalid date format: {v}")
        raise ValueError(f"Invalid date type: {type(v)}")
    
    model_config = ConfigDict(populate_by_name=True)


class PetWeightGoalCreate(PetWeightGoalBase):
    """Weight goal creation model"""
    pass


class PetWeightGoalResponse(PetWeightGoalBase):
    """Weight goal response model"""
    id: str
    created_at: datetime = Field(serialization_alias="createdAt", validation_alias="createdAt")
    updated_at: datetime = Field(serialization_alias="updatedAt", validation_alias="updatedAt")
    
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


# Nutritional Trends Models

class NutritionalTrendBase(BaseModel):
    """Base nutritional trend model"""
    pet_id: str
    trend_date: date
    total_calories: float = Field(default=0, ge=0)
    total_protein_g: float = Field(default=0, ge=0)
    total_fat_g: float = Field(default=0, ge=0)
    total_fiber_g: float = Field(default=0, ge=0)
    feeding_count: int = Field(default=0, ge=0)
    average_compatibility_score: float = Field(default=0, ge=0, le=100)
    weight_change_kg: float = Field(default=0)


class NutritionalTrendResponse(NutritionalTrendBase):
    """Nutritional trend response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class WeightTrendAnalysis(BaseModel):
    """Weight trend analysis result"""
    trend_direction: TrendDirection
    weight_change_kg: float
    average_daily_change: float
    trend_strength: TrendStrength
    days_analyzed: int
    confidence_level: float = Field(..., ge=0, le=1)


# Food Comparison Models

class FoodComparisonBase(BaseModel):
    """Base food comparison model"""
    comparison_name: str = Field(..., min_length=1, max_length=200)
    food_ids: List[str] = Field(..., min_items=2, max_items=10)
    comparison_data: Dict[str, Any]


class FoodComparisonCreate(FoodComparisonBase):
    """Food comparison creation model"""
    pass


class FoodComparisonResponse(FoodComparisonBase):
    """Food comparison response model"""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class FoodComparisonMetrics(BaseModel):
    """Detailed food comparison metrics"""
    calories_comparison: Dict[str, float]
    protein_comparison: Dict[str, float]
    fat_comparison: Dict[str, float]
    fiber_comparison: Dict[str, float]
    cost_per_calorie: Dict[str, float]
    nutritional_density: Dict[str, float]
    compatibility_scores: Dict[str, float]
    overall_rankings: List[Dict[str, Any]]


# Analytics Models

class AnalyticsType(str, Enum):
    """Analytics cache types"""
    WEEKLY_SUMMARY = "weekly_summary"
    MONTHLY_TRENDS = "monthly_trends"
    HEALTH_INSIGHTS = "health_insights"
    WEIGHT_ANALYSIS = "weight_analysis"
    NUTRITIONAL_PATTERNS = "nutritional_patterns"


class NutritionalAnalyticsCacheBase(BaseModel):
    """Base analytics cache model"""
    pet_id: str
    analysis_type: AnalyticsType
    analysis_data: Dict[str, Any]
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime


class NutritionalAnalyticsCacheResponse(NutritionalAnalyticsCacheBase):
    """Analytics cache response model"""
    id: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


# Recommendations Models

class NutritionalRecommendationBase(BaseModel):
    """Base nutritional recommendation model"""
    pet_id: str
    recommendation_type: str = Field(..., pattern="^(diet_adjustment|feeding_schedule|supplement|weight_management)$")
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1, max_length=2000)
    priority: RecommendationPriority
    category: RecommendationCategory
    is_active: bool = True
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: Optional[datetime] = None


class NutritionalRecommendationCreate(NutritionalRecommendationBase):
    """Recommendation creation model"""
    pass


class NutritionalRecommendationResponse(NutritionalRecommendationBase):
    """Recommendation response model"""
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


# Advanced Analytics Models

class WeeklyNutritionSummary(BaseModel):
    """Weekly nutrition summary"""
    pet_id: str
    week_start: date
    week_end: date
    total_calories: float
    average_daily_calories: float
    total_protein_g: float
    total_fat_g: float
    total_fiber_g: float
    feeding_frequency: float
    weight_change_kg: float
    compatibility_trend: str
    recommendations: List[str]
    health_score: float = Field(..., ge=0, le=100)


class MonthlyTrendAnalysis(BaseModel):
    """Monthly trend analysis"""
    pet_id: str
    month: str  # YYYY-MM format
    weight_trend: WeightTrendAnalysis
    calorie_trend: Dict[str, Any]
    nutritional_adequacy: Dict[str, Any]
    feeding_patterns: Dict[str, Any]
    health_indicators: Dict[str, Any]
    insights: List[str]
    predictions: List[str]


class HealthInsights(BaseModel):
    """Health insights from nutritional data"""
    pet_id: str
    analysis_date: date
    weight_management_status: str
    nutritional_adequacy_score: float
    feeding_consistency_score: float
    health_risks: List[str]
    positive_indicators: List[str]
    recommendations: List[NutritionalRecommendationResponse]
    overall_health_score: float = Field(..., ge=0, le=100)


class NutritionalPatterns(BaseModel):
    """Nutritional pattern analysis"""
    pet_id: str
    analysis_period: str
    feeding_times: List[str]
    preferred_foods: List[str]
    nutritional_gaps: List[str]
    seasonal_patterns: Dict[str, Any]
    behavioral_insights: List[str]
    optimization_suggestions: List[str]


# Request/Response Models for API

class WeightTrackingRequest(BaseModel):
    """Request for weight tracking operations"""
    pet_id: str
    weight_kg: float = Field(..., gt=0, le=200)
    notes: Optional[str] = None
    
    @field_validator('notes')
    @classmethod
    def sanitize_notes(cls, v):
        """Sanitize notes field to prevent XSS"""
        if v is None:
            return v
        from app.shared.services.html_sanitization_service import HTMLSanitizationService
        return HTMLSanitizationService.sanitize_notes(v, max_length=500)


class TrendAnalysisRequest(BaseModel):
    """Request for trend analysis"""
    pet_id: str
    start_date: date
    end_date: date
    analysis_type: str = "comprehensive"


class FoodComparisonRequest(BaseModel):
    """Request for food comparison"""
    food_ids: List[str] = Field(..., min_items=2, max_items=10)
    comparison_name: str = Field(..., min_length=1, max_length=200)
    metrics: List[str] = Field(default=["calories", "protein", "fat", "fiber", "cost"])


class AnalyticsRequest(BaseModel):
    """Request for analytics generation"""
    pet_id: str
    analysis_type: AnalyticsType
    date_range: Optional[Dict[str, date]] = None
    force_refresh: bool = False


# Response Models

class AdvancedNutritionResponse(BaseModel):
    """Comprehensive advanced nutrition response"""
    weight_records: List[PetWeightRecordResponse]
    weight_goals: List[PetWeightGoalResponse]
    current_trends: List[NutritionalTrendResponse]
    active_recommendations: List[NutritionalRecommendationResponse]
    analytics_cache: Optional[NutritionalAnalyticsCacheResponse]
    health_insights: Optional[HealthInsights]


class WeightManagementDashboard(BaseModel):
    """Weight management dashboard data"""
    pet_id: str
    current_weight: Optional[float]
    target_weight: Optional[float]
    weight_goal: Optional[PetWeightGoalResponse]
    recent_trend: Optional[WeightTrendAnalysis]
    weekly_progress: List[Dict[str, Any]]
    recommendations: List[NutritionalRecommendationResponse]


class NutritionalTrendsDashboard(BaseModel):
    """Nutritional trends dashboard data"""
    pet_id: str
    trend_period: str
    calorie_trends: List[Dict[str, Any]]
    macronutrient_trends: List[Dict[str, Any]]
    weight_correlation: Dict[str, Any]
    feeding_patterns: List[Dict[str, Any]]
    insights: List[str]


class FoodComparisonDashboard(BaseModel):
    """Food comparison dashboard data"""
    comparison_id: str
    comparison_name: str
    foods: List[Dict[str, Any]]
    metrics: FoodComparisonMetrics
    recommendations: List[str]
    best_overall: str
    best_value: str
    best_nutrition: str


# Validation helpers

@validator('target_date')
def validate_target_date(cls, v, values):
    """Validate target date is in the future"""
    if v and v <= date.today():
        raise ValueError('Target date must be in the future')
    return v


@validator('food_ids')
def validate_food_ids(cls, v):
    """Validate food IDs are unique"""
    if len(v) != len(set(v)):
        raise ValueError('Food IDs must be unique')
    return v


@validator('expires_at')
def validate_expires_at(cls, v, values):
    """Validate expires_at is after generated_at"""
    if v and 'generated_at' in values and v <= values['generated_at']:
        raise ValueError('Expires at must be after generated at')
    return v
