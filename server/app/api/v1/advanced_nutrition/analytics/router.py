"""
Advanced Nutrition - Analytics Sub-domain

Handles advanced analytics, health insights, and pattern analysis.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional
from datetime import datetime
from app.shared.services.datetime_service import DateTimeService

from app.api.v1.dependencies import get_authenticated_supabase_client
from supabase import Client
from app.models.advanced_nutrition import (
    AnalyticsType, NutritionalAnalyticsCacheResponse,
    HealthInsights, NutritionalPatterns,
    AdvancedNutritionResponse
)
from app.models.user import User
from app.core.security.jwt_handler import get_current_user
from app.services.analytics import (
    HealthAnalyticsService, 
    PatternAnalyticsService, 
    TrendAnalyticsService,
    RecommendationService
)

router = APIRouter(prefix="/analytics", tags=["advanced-nutrition-analytics"])

# Service factory functions

def get_health_analytics_service(supabase: Client):
    """
    Get health analytics service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
    """
    return HealthAnalyticsService(supabase)

def get_pattern_analytics_service(supabase: Client):
    """
    Get pattern analytics service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
    """
    return PatternAnalyticsService(supabase)

def get_trend_analytics_service(supabase: Client):
    """
    Get trend analytics service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
    """
    return TrendAnalyticsService(supabase)

def get_recommendation_service(supabase: Client):
    """
    Get recommendation service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
    """
    return RecommendationService(supabase)


@router.post("/generate", response_model=NutritionalAnalyticsCacheResponse)
async def generate_analytics(
    pet_id: str,
    analysis_type: AnalyticsType,
    force_refresh: bool = False,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Generate advanced analytics for a pet
    
    Args:
        pet_id: Pet ID
        analysis_type: Type of analysis to perform
        force_refresh: Force regeneration even if cache exists
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Analytics cache response
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Generate analytics based on type
        if analysis_type == AnalyticsType.HEALTH:
            service = get_health_analytics_service(supabase)
            result = await service.get_health_insights(pet_id, current_user.id)
        elif analysis_type == AnalyticsType.PATTERNS:
            service = get_pattern_analytics_service(supabase)
            result = await service.analyze_nutritional_patterns(pet_id, current_user.id)
        elif analysis_type == AnalyticsType.TRENDS:
            service = get_trend_analytics_service(supabase)
            result = await service.analyze_nutritional_trends(pet_id, current_user.id)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid analysis type"
            )
        
        return NutritionalAnalyticsCacheResponse(
            pet_id=pet_id,
            analysis_type=analysis_type,
            result=result,
            generated_at=DateTimeService.now(),
            cached=True
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate analytics: {str(e)}"
        )


@router.get("/health-insights/{pet_id}", response_model=HealthInsights)
async def get_health_insights(
    pet_id: str,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get health insights for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Health insights data
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get health insights
        service = get_health_analytics_service(supabase)
        insights = await service.get_health_insights(pet_id, current_user.id)
        
        return insights
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get health insights: {str(e)}"
        )


@router.get("/patterns/{pet_id}", response_model=NutritionalPatterns)
async def analyze_nutritional_patterns(
    pet_id: str,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Analyze nutritional patterns for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Nutritional patterns analysis
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Analyze nutritional patterns
        service = get_pattern_analytics_service(supabase)
        patterns = await service.analyze_nutritional_patterns(pet_id, current_user.id)
        
        return patterns
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to analyze nutritional patterns: {str(e)}"
        )


@router.get("/dashboard/{pet_id}", response_model=AdvancedNutritionResponse)
async def get_advanced_nutrition_dashboard(
    pet_id: str,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get comprehensive advanced nutrition dashboard for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Advanced nutrition dashboard
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get comprehensive dashboard data
        health_service = get_health_analytics_service(supabase)
        pattern_service = get_pattern_analytics_service(supabase)
        trend_service = get_trend_analytics_service(supabase)
        recommendation_service = get_recommendation_service(supabase)
        
        # Gather all analytics data
        health_insights = await health_service.get_health_insights(pet_id, current_user.id)
        patterns = await pattern_service.analyze_nutritional_patterns(pet_id, current_user.id)
        trends = await trend_service.analyze_nutritional_trends(pet_id, current_user.id)
        
        # Generate recommendations using data transformation service
        from app.shared.services.data_transformation_service import DataTransformationService
        health_recommendations = await recommendation_service.generate_health_recommendations(
            pet_id, current_user.id, DataTransformationService.model_to_dict(health_insights)
        )
        
        return AdvancedNutritionResponse(
            pet_id=pet_id,
            health_insights=health_insights,
            patterns=patterns,
            trends=trends,
            recommendations=health_recommendations,
            generated_at=DateTimeService.now()
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get advanced nutrition dashboard: {str(e)}"
        )
