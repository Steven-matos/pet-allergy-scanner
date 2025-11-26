"""
Advanced Nutrition Analytics Router

Handles advanced analytics, insights, patterns, and trends.
Future-ready module for sophisticated nutrition analysis.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional, Dict, Any
from datetime import datetime
from app.shared.services.datetime_service import DateTimeService
from datetime import timedelta

from app.database import get_db
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

# Import advanced analytics services
from .analytics_service import AdvancedAnalyticsService
from .insights_service import NutritionInsightsService
from .patterns_service import NutritionPatternsService
from .trends_service import NutritionTrendsService

logger = get_logger(__name__)
router = APIRouter(prefix="/advanced", tags=["nutrition-advanced"])


@router.get("/analytics/overview")
async def get_analytics_overview(
    pet_id: Optional[str] = Query(None, description="Pet ID for specific analytics"),
    days: int = Query(30, description="Number of days to analyze"),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get comprehensive nutrition analytics overview
    
    Args:
        pet_id: Optional pet ID for specific pet analytics
        days: Number of days to analyze (default: 30)
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Comprehensive analytics overview
        
    Raises:
        HTTPException: If analytics generation fails
    """
    try:
        analytics_service = AdvancedAnalyticsService(supabase)
        
        if pet_id:
            # Verify pet ownership
            from app.shared.services.pet_authorization import verify_pet_ownership
            await verify_pet_ownership(pet_id, current_user.id, supabase)
            
            analytics = await analytics_service.get_pet_analytics(pet_id, days)
        else:
            analytics = await analytics_service.get_user_analytics(current_user.id, days)
        
        return analytics
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate analytics overview: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate analytics overview: {str(e)}"
        )


@router.get("/insights/{pet_id}")
async def get_nutrition_insights(
    pet_id: str,
    insight_type: str = Query("all", description="Type of insights to generate"),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get advanced nutrition insights for a pet
    
    Args:
        pet_id: Pet ID
        insight_type: Type of insights (all, health, behavior, trends)
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Advanced nutrition insights
        
    Raises:
        HTTPException: If pet not found or insights generation fails
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        insights_service = NutritionInsightsService(supabase)
        insights = await insights_service.generate_insights(pet_id, insight_type)
        
        return insights
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate nutrition insights: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate nutrition insights: {str(e)}"
        )


@router.get("/patterns/{pet_id}")
async def get_nutrition_patterns(
    pet_id: str,
    pattern_type: str = Query("feeding", description="Type of patterns to analyze"),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Analyze nutrition patterns for a pet
    
    Args:
        pet_id: Pet ID
        pattern_type: Type of patterns (feeding, preferences, health)
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Nutrition patterns analysis
        
    Raises:
        HTTPException: If pet not found or pattern analysis fails
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        patterns_service = NutritionPatternsService(supabase)
        patterns = await patterns_service.analyze_patterns(pet_id, pattern_type)
        
        return patterns
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to analyze nutrition patterns: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze nutrition patterns: {str(e)}"
        )


@router.get("/trends/{pet_id}")
async def get_nutrition_trends(
    pet_id: str,
    trend_period: str = Query("monthly", description="Trend period (weekly, monthly, yearly)"),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get nutrition trends for a pet
    
    Args:
        pet_id: Pet ID
        trend_period: Trend analysis period
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Nutrition trends analysis
        
    Raises:
        HTTPException: If pet not found or trend analysis fails
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        trends_service = NutritionTrendsService(supabase)
        trends = await trends_service.analyze_trends(pet_id, trend_period)
        
        return trends
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to analyze nutrition trends: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze nutrition trends: {str(e)}"
        )


@router.get("/recommendations/{pet_id}")
async def get_advanced_recommendations(
    pet_id: str,
    recommendation_type: str = Query("all", description="Type of recommendations"),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get advanced nutrition recommendations for a pet
    
    Args:
        pet_id: Pet ID
        recommendation_type: Type of recommendations (diet, supplements, schedule)
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Advanced nutrition recommendations
        
    Raises:
        HTTPException: If pet not found or recommendations generation fails
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Combine insights from all services for comprehensive recommendations
        insights_service = NutritionInsightsService(supabase)
        patterns_service = NutritionPatternsService(supabase)
        trends_service = NutritionTrendsService(supabase)
        
        insights = await insights_service.generate_insights(pet_id, "all")
        patterns = await patterns_service.analyze_patterns(pet_id, "all")
        trends = await trends_service.analyze_trends(pet_id, "monthly")
        
        # Generate comprehensive recommendations
        recommendations = {
            "pet_id": pet_id,
            "generated_at": DateTimeService.now(),
            "insights": insights,
            "patterns": patterns,
            "trends": trends,
            "recommendations": [
                "Consider rotating protein sources for variety",
                "Monitor weight trends monthly",
                "Schedule annual nutrition review"
            ],
            "priority_level": "medium"
        }
        
        return recommendations
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate advanced recommendations: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate advanced recommendations: {str(e)}"
        )
