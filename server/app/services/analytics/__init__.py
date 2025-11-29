"""
Analytics Services Module

Combines all analytics services into a unified interface.
"""

from .health_analytics_service import HealthAnalyticsService
from .pattern_analytics_service import PatternAnalyticsService
from .trend_analytics_service import TrendAnalyticsService
from .recommendation_service import RecommendationService
from .advanced_analytics_service import AdvancedAnalyticsService

__all__ = [
    'HealthAnalyticsService',
    'PatternAnalyticsService', 
    'TrendAnalyticsService',
    'RecommendationService',
    'AdvancedAnalyticsService',
]
