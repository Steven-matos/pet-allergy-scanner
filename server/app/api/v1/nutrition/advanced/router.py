"""
Advanced Nutrition Analytics Router

Handles advanced analytics, insights, patterns, and trends.
Future-ready module for sophisticated nutrition analysis.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

# Import advanced analytics services
from .analytics_service import AdvancedAnalyticsService
from .insights_service import NutritionInsightsService
from .patterns_service import NutritionPatternsService
from .trends_service import NutritionTrendsService

router = APIRouter(prefix="/advanced", tags=["nutrition-advanced"])


@router.get("/analytics/overview")
async def get_analytics_overview(
    pet_id: Optional[str] = Query(None, description="Pet ID for specific analytics"),
    days: int = Query(30, description="Number of days to analyze"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get comprehensive nutrition analytics overview
    
    Args:
        pet_id: Optional pet ID for specific pet analytics
        days: Number of days to analyze (default: 30)
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Comprehensive analytics overview
        
    Raises:
        HTTPException: If analytics generation fails
    """
    try:
        analytics_service = AdvancedAnalyticsService(db)
        
        if pet_id:
            # Verify pet ownership
            from app.shared.services.pet_authorization import verify_pet_ownership
            await verify_pet_ownership(pet_id, current_user.id)
            
            analytics = await analytics_service.get_pet_analytics(pet_id, days)
        else:
            analytics = await analytics_service.get_user_analytics(current_user.id, days)
        
        return analytics
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate analytics overview: {str(e)}"
        )


@router.get("/insights/{pet_id}")
async def get_nutrition_insights(
    pet_id: str,
    insight_type: str = Query("all", description="Type of insights to generate"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get advanced nutrition insights for a pet
    
    Args:
        pet_id: Pet ID
        insight_type: Type of insights (all, health, behavior, trends)
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Advanced nutrition insights
        
    Raises:
        HTTPException: If pet not found or insights generation fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        insights_service = NutritionInsightsService(db)
        insights = await insights_service.generate_insights(pet_id, insight_type)
        
        return insights
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate nutrition insights: {str(e)}"
        )


@router.get("/patterns/{pet_id}")
async def get_nutrition_patterns(
    pet_id: str,
    pattern_type: str = Query("feeding", description="Type of patterns to analyze"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze nutrition patterns for a pet
    
    Args:
        pet_id: Pet ID
        pattern_type: Type of patterns (feeding, preferences, health)
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutrition patterns analysis
        
    Raises:
        HTTPException: If pet not found or pattern analysis fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        patterns_service = NutritionPatternsService(db)
        patterns = await patterns_service.analyze_patterns(pet_id, pattern_type)
        
        return patterns
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze nutrition patterns: {str(e)}"
        )


@router.get("/trends/{pet_id}")
async def get_nutrition_trends(
    pet_id: str,
    trend_period: str = Query("monthly", description="Trend period (weekly, monthly, yearly)"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get nutrition trends for a pet
    
    Args:
        pet_id: Pet ID
        trend_period: Trend analysis period
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutrition trends analysis
        
    Raises:
        HTTPException: If pet not found or trend analysis fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        trends_service = NutritionTrendsService(db)
        trends = await trends_service.analyze_trends(pet_id, trend_period)
        
        return trends
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze nutrition trends: {str(e)}"
        )


@router.get("/recommendations/{pet_id}")
async def get_advanced_recommendations(
    pet_id: str,
    recommendation_type: str = Query("all", description="Type of recommendations"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get advanced nutrition recommendations for a pet
    
    Args:
        pet_id: Pet ID
        recommendation_type: Type of recommendations (diet, supplements, schedule)
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Advanced nutrition recommendations
        
    Raises:
        HTTPException: If pet not found or recommendations generation fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Combine insights from all services for comprehensive recommendations
        insights_service = NutritionInsightsService(db)
        patterns_service = NutritionPatternsService(db)
        trends_service = NutritionTrendsService(db)
        
        insights = await insights_service.generate_insights(pet_id, "all")
        patterns = await patterns_service.analyze_patterns(pet_id, "all")
        trends = await trends_service.analyze_trends(pet_id, "monthly")
        
        # Generate comprehensive recommendations
        recommendations = {
            "pet_id": pet_id,
            "generated_at": datetime.utcnow(),
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
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate advanced recommendations: {str(e)}"
        )
