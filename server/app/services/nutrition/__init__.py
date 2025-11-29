"""
Nutrition Services Module

Combines all nutrition-related services into a unified interface.
"""

from .weight_tracking_service import WeightTrackingService
from .food_comparison_service import FoodComparisonService
from .nutritional_trends_service import NutritionalTrendsService
from .nutritional_calculator import NutritionalCalculator

__all__ = [
    'WeightTrackingService',
    'FoodComparisonService',
    'NutritionalTrendsService',
    'NutritionalCalculator',
]

