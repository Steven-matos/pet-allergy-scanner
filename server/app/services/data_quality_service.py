"""
Data Quality Assessment Service
Comprehensive data quality scoring based on ingredients and nutritional values
"""

from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class DataQualityLevel(Enum):
    """Data quality classification levels"""
    EXCELLENT = "excellent"
    GOOD = "good" 
    FAIR = "fair"
    POOR = "poor"


@dataclass
class DataQualityMetrics:
    """Comprehensive data quality metrics"""
    overall_score: float
    level: DataQualityLevel
    ingredients_score: float
    nutritional_score: float
    completeness_score: float
    ingredients_count: int
    nutritional_fields_count: int
    missing_critical_fields: List[str]
    quality_indicators: Dict[str, bool]


class DataQualityService:
    """
    Enhanced data quality assessment service
    Focuses on ingredients and nutritional values as primary quality indicators
    """
    
    # Critical nutritional fields that should be present for good quality
    CRITICAL_NUTRITIONAL_FIELDS = [
        'calories_per_100g',
        'protein_percentage', 
        'fat_percentage',
        'fiber_percentage',
        'moisture_percentage'
    ]
    
    # Important nutritional fields that add to quality
    IMPORTANT_NUTRITIONAL_FIELDS = [
        'ash_percentage',
        'carbohydrates_percentage',
        'sodium_percentage'
    ]
    
    # Extended nutritional fields for excellent quality
    EXTENDED_NUTRITIONAL_FIELDS = [
        'sugars_percentage',
        'saturated_fat_percentage'
    ]
    
    # Quality thresholds
    EXCELLENT_THRESHOLD = 0.9
    GOOD_THRESHOLD = 0.7
    FAIR_THRESHOLD = 0.5

    @classmethod
    def calculate_ingredients_score(cls, ingredients: List[str]) -> Tuple[float, int]:
        """
        Calculate ingredients quality score
        
        Args:
            ingredients: List of ingredient strings
            
        Returns:
            Tuple of (score, count)
        """
        if not ingredients:
            return 0.0, 0
            
        ingredient_count = len(ingredients)
        
        # Base score based on ingredient count
        if ingredient_count == 0:
            score = 0.0
        elif ingredient_count < 3:
            score = 0.2  # Very basic
        elif ingredient_count < 6:
            score = 0.5  # Basic
        elif ingredient_count < 10:
            score = 0.7  # Good
        elif ingredient_count < 15:
            score = 0.85  # Very good
        else:
            score = 1.0  # Excellent detail
            
        return min(score, 1.0), ingredient_count

    @classmethod
    def calculate_nutritional_score(cls, nutritional_data: Dict[str, Any]) -> Tuple[float, int]:
        """
        Calculate nutritional information quality score
        
        Args:
            nutritional_data: Dictionary containing nutritional information
            
        Returns:
            Tuple of (score, count of available fields)
        """
        available_fields = 0
        total_score = 0.0
        
        # Check critical fields (weight: 0.4 each)
        critical_score = 0.0
        for field in cls.CRITICAL_NUTRITIONAL_FIELDS:
            if nutritional_data.get(field) is not None:
                critical_score += 0.4
                available_fields += 1
        
        # Check important fields (weight: 0.2 each) 
        important_score = 0.0
        for field in cls.IMPORTANT_NUTRITIONAL_FIELDS:
            if nutritional_data.get(field) is not None:
                important_score += 0.2
                available_fields += 1
                
        # Check extended fields (weight: 0.1 each)
        extended_score = 0.0
        for field in cls.EXTENDED_NUTRITIONAL_FIELDS:
            if nutritional_data.get(field) is not None:
                extended_score += 0.1
                available_fields += 1
        
        total_score = critical_score + important_score + extended_score
        
        return min(total_score, 1.0), available_fields

    @classmethod
    def calculate_completeness_score(cls, food_item: Dict[str, Any]) -> float:
        """
        Calculate overall data completeness score
        
        Args:
            food_item: Complete food item data
            
        Returns:
            Completeness score (0.0 to 1.0)
        """
        score = 0.0
        
        # Basic product information (30% weight)
        if food_item.get('name'):
            score += 0.1
        if food_item.get('brand'):
            score += 0.1
        if food_item.get('barcode'):
            score += 0.1
            
        # Nutritional information (50% weight)
        nutritional_data = food_item.get('nutritional_info', {})
        nutritional_score, _ = cls.calculate_nutritional_score(nutritional_data)
        score += nutritional_score * 0.5
        
        # Ingredients information (20% weight)
        ingredients = nutritional_data.get('ingredients', [])
        ingredients_score, _ = cls.calculate_ingredients_score(ingredients)
        score += ingredients_score * 0.2
        
        return min(score, 1.0)

    @classmethod
    def identify_missing_critical_fields(cls, nutritional_data: Dict[str, Any]) -> List[str]:
        """
        Identify missing critical nutritional fields
        
        Args:
            nutritional_data: Dictionary containing nutritional information
            
        Returns:
            List of missing critical field names
        """
        missing_fields = []
        
        for field in cls.CRITICAL_NUTRITIONAL_FIELDS:
            if nutritional_data.get(field) is None:
                missing_fields.append(field)
                
        return missing_fields

    @classmethod
    def generate_quality_indicators(cls, nutritional_data: Dict[str, Any], 
                                  ingredients: List[str]) -> Dict[str, bool]:
        """
        Generate quality indicator flags
        
        Args:
            nutritional_data: Dictionary containing nutritional information
            ingredients: List of ingredients
            
        Returns:
            Dictionary of quality indicators
        """
        return {
            'has_calories': nutritional_data.get('calories_per_100g') is not None,
            'has_protein': nutritional_data.get('protein_percentage') is not None,
            'has_fat': nutritional_data.get('fat_percentage') is not None,
            'has_fiber': nutritional_data.get('fiber_percentage') is not None,
            'has_moisture': nutritional_data.get('moisture_percentage') is not None,
            'has_ingredients': len(ingredients) > 0,
            'has_allergens': len(nutritional_data.get('allergens', [])) > 0,
            'has_additives': len(nutritional_data.get('additives', [])) > 0,
            'has_vitamins': len(nutritional_data.get('vitamins', [])) > 0,
            'has_minerals': len(nutritional_data.get('minerals', [])) > 0,
            'has_extended_nutrition': any(
                nutritional_data.get(field) is not None 
                for field in cls.EXTENDED_NUTRITIONAL_FIELDS
            )
        }

    @classmethod
    def assess_data_quality(cls, food_item: Dict[str, Any]) -> DataQualityMetrics:
        """
        Comprehensive data quality assessment
        
        Args:
            food_item: Complete food item data
            
        Returns:
            DataQualityMetrics object with detailed quality assessment
        """
        nutritional_data = food_item.get('nutritional_info', {})
        ingredients = nutritional_data.get('ingredients', [])
        
        # Calculate individual scores
        ingredients_score, ingredients_count = cls.calculate_ingredients_score(ingredients)
        nutritional_score, nutritional_fields_count = cls.calculate_nutritional_score(nutritional_data)
        completeness_score = cls.calculate_completeness_score(food_item)
        
        # Calculate overall score (weighted average)
        overall_score = (
            ingredients_score * 0.3 +
            nutritional_score * 0.5 +
            completeness_score * 0.2
        )
        
        # Determine quality level
        if overall_score >= cls.EXCELLENT_THRESHOLD:
            level = DataQualityLevel.EXCELLENT
        elif overall_score >= cls.GOOD_THRESHOLD:
            level = DataQualityLevel.GOOD
        elif overall_score >= cls.FAIR_THRESHOLD:
            level = DataQualityLevel.FAIR
        else:
            level = DataQualityLevel.POOR
            
        # Identify missing critical fields
        missing_critical_fields = cls.identify_missing_critical_fields(nutritional_data)
        
        # Generate quality indicators
        quality_indicators = cls.generate_quality_indicators(nutritional_data, ingredients)
        
        return DataQualityMetrics(
            overall_score=overall_score,
            level=level,
            ingredients_score=ingredients_score,
            nutritional_score=nutritional_score,
            completeness_score=completeness_score,
            ingredients_count=ingredients_count,
            nutritional_fields_count=nutritional_fields_count,
            missing_critical_fields=missing_critical_fields,
            quality_indicators=quality_indicators
        )

    @classmethod
    def get_quality_recommendations(cls, metrics: DataQualityMetrics) -> List[str]:
        """
        Generate quality improvement recommendations
        
        Args:
            metrics: DataQualityMetrics object
            
        Returns:
            List of improvement recommendations
        """
        recommendations = []
        
        # Ingredients recommendations
        if metrics.ingredients_count == 0:
            recommendations.append("Add ingredient list for better product transparency")
        elif metrics.ingredients_count < 3:
            recommendations.append("Provide more detailed ingredient information")
            
        # Nutritional recommendations
        if metrics.nutritional_score < 0.5:
            recommendations.append("Add basic nutritional information (calories, protein, fat)")
        elif metrics.nutritional_score < 0.8:
            recommendations.append("Include additional nutritional values (fiber, moisture, ash)")
            
        # Missing critical fields
        if metrics.missing_critical_fields:
            missing_list = ", ".join(metrics.missing_critical_fields)
            recommendations.append(f"Add missing critical nutritional data: {missing_list}")
            
        # Quality indicators
        if not metrics.quality_indicators.get('has_allergens'):
            recommendations.append("Include allergen information for pet safety")
            
        return recommendations

    @classmethod
    def format_quality_summary(cls, metrics: DataQualityMetrics) -> Dict[str, Any]:
        """
        Format quality metrics for API response
        
        Args:
            metrics: DataQualityMetrics object
            
        Returns:
            Formatted dictionary for API response
        """
        return {
            'overall_score': round(metrics.overall_score, 3),
            'quality_level': metrics.level.value,
            'breakdown': {
                'ingredients': {
                    'score': round(metrics.ingredients_score, 3),
                    'count': metrics.ingredients_count
                },
                'nutritional': {
                    'score': round(metrics.nutritional_score, 3),
                    'fields_count': metrics.nutritional_fields_count
                },
                'completeness': {
                    'score': round(metrics.completeness_score, 3)
                }
            },
            'missing_critical_fields': metrics.missing_critical_fields,
            'quality_indicators': metrics.quality_indicators,
            'recommendations': cls.get_quality_recommendations(metrics)
        }
