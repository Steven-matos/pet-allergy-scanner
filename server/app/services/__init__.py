"""
Services package

Organized by domain:
- subscription/ - Subscription and RevenueCat services
- nutrition/ - Weight tracking, food comparison, nutritional analysis
- health/ - Health events and medication reminders
- analytics/ - Advanced analytics services
"""

# Subscription services
from .subscription import (
    RevenueCatService,
    RevenueCatWebhookService,
    RevenueCatAPIService,
    RevenueCatSubscriptionService,
)
from .subscription.subscription_service import SubscriptionService
from .subscription.subscription_checker import SubscriptionChecker

# Nutrition services
from .nutrition import (
    WeightTrackingService,
    FoodComparisonService,
    NutritionalTrendsService,
    NutritionalCalculator,
)

# Health services
from .health import (
    HealthEventService,
    MedicationReminderService,
)

# Analytics services
from .analytics import (
    HealthAnalyticsService,
    PatternAnalyticsService,
    TrendAnalyticsService,
    RecommendationService,
    AdvancedAnalyticsService,
)

# Other services (not yet organized by domain)
from .data_quality_service import DataQualityService
from .gdpr_service import GDPRService
from .image_optimizer import ImageOptimizerService
from .mfa_service import MFAService
from .monitoring import MonitoringService
from .push_notification_service import PushNotificationService
from .storage_service import StorageService

__all__ = [
    # Subscription
    'RevenueCatService',
    'RevenueCatWebhookService',
    'RevenueCatAPIService',
    'RevenueCatSubscriptionService',
    'SubscriptionService',
    'SubscriptionChecker',
    # Nutrition
    'WeightTrackingService',
    'FoodComparisonService',
    'NutritionalTrendsService',
    'NutritionalCalculator',
    # Health
    'HealthEventService',
    'MedicationReminderService',
    # Analytics
    'HealthAnalyticsService',
    'PatternAnalyticsService',
    'TrendAnalyticsService',
    'RecommendationService',
    # Other
    'AdvancedAnalyticsService',
    'DataQualityService',
    'GDPRService',
    'ImageOptimizerService',
    'MFAService',
    'MonitoringService',
    'PushNotificationService',
    'StorageService',
]
