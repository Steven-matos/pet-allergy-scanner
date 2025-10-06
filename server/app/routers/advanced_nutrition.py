"""
Phase 3 Advanced Nutritional Analysis API endpoints
Weight tracking, trends, comparisons, and advanced analytics
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
from ..database import get_supabase_client
from ..models.advanced_nutrition import (
    PetWeightRecordCreate, PetWeightRecordResponse,
    PetWeightGoalCreate, PetWeightGoalResponse,
    WeightTrendAnalysis, NutritionalTrendResponse,
    FoodComparisonCreate, FoodComparisonResponse,
    AnalyticsType, NutritionalAnalyticsCacheResponse,
    HealthInsights, NutritionalPatterns,
    AdvancedNutritionResponse, WeightManagementDashboard,
    NutritionalTrendsDashboard, FoodComparisonDashboard
)
from ..models.user import User
from ..routers.auth import get_current_user
from ..services.weight_tracking_service import WeightTrackingService
from ..services.nutritional_trends_service import NutritionalTrendsService
from ..services.food_comparison_service import FoodComparisonService
from ..services.advanced_analytics_service import AdvancedAnalyticsService

router = APIRouter(prefix="/advanced-nutrition", tags=["advanced-nutrition"])

# Service instances will be created lazily to avoid database initialization issues
weight_service = None
trends_service = None
comparison_service = None
analytics_service = None

def get_weight_service():
    """Get weight tracking service instance (lazy initialization)"""
    global weight_service
    if weight_service is None:
        weight_service = WeightTrackingService()
    return weight_service

def get_trends_service():
    """Get nutritional trends service instance (lazy initialization)"""
    global trends_service
    if trends_service is None:
        trends_service = NutritionalTrendsService()
    return trends_service

def get_comparison_service():
    """Get food comparison service instance (lazy initialization)"""
    global comparison_service
    if comparison_service is None:
        comparison_service = FoodComparisonService()
    return comparison_service

def get_analytics_service():
    """Get advanced analytics service instance (lazy initialization)"""
    global analytics_service
    if analytics_service is None:
        analytics_service = AdvancedAnalyticsService()
    return analytics_service


# Weight Tracking Endpoints

@router.post("/weight/record", response_model=PetWeightRecordResponse)
async def record_weight(
    weight_record: PetWeightRecordCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Record a new weight measurement for a pet
    
    Args:
        weight_record: Weight record data
        current_user: Authenticated user
        
    Returns:
        Created weight record
    """
    try:
        return await get_weight_service().record_weight(weight_record, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to record weight: {str(e)}"
        )


@router.get("/weight/history/{pet_id}", response_model=List[PetWeightRecordResponse])
async def get_weight_history(
    pet_id: str,
    days_back: int = Query(30, ge=1, le=365),
    current_user: User = Depends(get_current_user)
):
    """
    Get weight history for a pet
    
    Args:
        pet_id: Pet ID
        days_back: Number of days to look back
        current_user: Authenticated user
        
    Returns:
        List of weight records
    """
    try:
        return await get_weight_service().get_weight_history(pet_id, current_user.id, days_back)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight history: {str(e)}"
        )


@router.post("/weight/goals", response_model=PetWeightGoalResponse)
async def create_weight_goal(
    goal: PetWeightGoalCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create or update a weight goal for a pet (one goal per pet)
    
    Args:
        goal: Weight goal data
        current_user: Authenticated user
        
    Returns:
        Created or updated weight goal
    """
    try:
        return await get_weight_service().upsert_weight_goal(goal, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create/update weight goal: {str(e)}"
        )


@router.put("/weight/goals", response_model=PetWeightGoalResponse)
async def upsert_weight_goal(
    goal: PetWeightGoalCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create or update a weight goal for a pet (explicit upsert endpoint)
    
    Args:
        goal: Weight goal data
        current_user: Authenticated user
        
    Returns:
        Created or updated weight goal
    """
    try:
        return await get_weight_service().upsert_weight_goal(goal, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upsert weight goal: {str(e)}"
        )


@router.get("/weight/goals/{pet_id}/active", response_model=Optional[PetWeightGoalResponse])
async def get_active_weight_goal(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get active weight goal for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        
    Returns:
        Active weight goal or None
    """
    try:
        return await get_weight_service().get_active_weight_goal(pet_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight goal: {str(e)}"
        )


@router.get("/weight/trend/{pet_id}", response_model=WeightTrendAnalysis)
async def analyze_weight_trend(
    pet_id: str,
    days_back: int = Query(30, ge=7, le=365),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze weight trend for a pet
    
    Args:
        pet_id: Pet ID
        days_back: Number of days to analyze
        current_user: Authenticated user
        
    Returns:
        Weight trend analysis
    """
    try:
        return await get_weight_service().analyze_weight_trend(pet_id, current_user.id, days_back)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to analyze weight trend: {str(e)}"
        )


@router.get("/weight/dashboard/{pet_id}", response_model=WeightManagementDashboard)
async def get_weight_management_dashboard(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get comprehensive weight management dashboard data
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        
    Returns:
        Weight management dashboard data
    """
    try:
        return await get_weight_service().get_weight_management_dashboard(pet_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight dashboard: {str(e)}"
        )


# Nutritional Trends Endpoints

@router.get("/trends/{pet_id}", response_model=List[NutritionalTrendResponse])
async def get_nutritional_trends(
    pet_id: str,
    days_back: int = Query(30, ge=1, le=365),
    current_user: User = Depends(get_current_user)
):
    """
    Get nutritional trends for a pet
    
    Args:
        pet_id: Pet ID
        days_back: Number of days to look back
        current_user: Authenticated user
        
    Returns:
        List of nutritional trend records
    """
    try:
        return await get_trends_service().get_nutritional_trends(pet_id, current_user.id, days_back)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get nutritional trends: {str(e)}"
        )


@router.get("/trends/dashboard/{pet_id}", response_model=NutritionalTrendsDashboard)
async def get_trends_dashboard(
    pet_id: str,
    period: str = Query("30_days", regex="^(7_days|30_days|90_days)$"),
    current_user: User = Depends(get_current_user)
):
    """
    Get comprehensive trends dashboard data
    
    Args:
        pet_id: Pet ID
        period: Analysis period
        current_user: Authenticated user
        
    Returns:
        Trends dashboard data
    """
    try:
        return await get_trends_service().get_trends_dashboard(pet_id, current_user.id, period)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get trends dashboard: {str(e)}"
        )


# Food Comparison Endpoints

@router.post("/comparisons", response_model=FoodComparisonResponse)
async def create_food_comparison(
    comparison: FoodComparisonCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create a new food comparison
    
    Args:
        comparison: Comparison data
        current_user: Authenticated user
        
    Returns:
        Created comparison
    """
    try:
        return await get_comparison_service().create_comparison(comparison, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create comparison: {str(e)}"
        )


@router.get("/comparisons/{comparison_id}", response_model=FoodComparisonResponse)
async def get_food_comparison(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get a food comparison by ID
    
    Args:
        comparison_id: Comparison ID
        current_user: Authenticated user
        
    Returns:
        Food comparison data
    """
    try:
        return await get_comparison_service().get_comparison(comparison_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get comparison: {str(e)}"
        )


@router.get("/comparisons", response_model=List[FoodComparisonResponse])
async def get_user_comparisons(
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user)
):
    """
    Get all comparisons for a user
    
    Args:
        limit: Maximum number of comparisons to return
        current_user: Authenticated user
        
    Returns:
        List of user's comparisons
    """
    try:
        return await get_comparison_service().get_user_comparisons(current_user.id, limit)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get comparisons: {str(e)}"
        )


@router.get("/comparisons/dashboard/{comparison_id}", response_model=FoodComparisonDashboard)
async def get_comparison_dashboard(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get comprehensive comparison dashboard data
    
    Args:
        comparison_id: Comparison ID
        current_user: Authenticated user
        
    Returns:
        Comparison dashboard data
    """
    try:
        return await get_comparison_service().get_comparison_dashboard(comparison_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get comparison dashboard: {str(e)}"
        )


@router.delete("/comparisons/{comparison_id}")
async def delete_food_comparison(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Delete a food comparison
    
    Args:
        comparison_id: Comparison ID
        current_user: Authenticated user
        
    Returns:
        Success message
    """
    try:
        success = await get_comparison_service().delete_comparison(comparison_id, current_user.id)
        if success:
            return {"message": "Comparison deleted successfully"}
        else:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Comparison not found")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete comparison: {str(e)}"
        )


# Advanced Analytics Endpoints

@router.post("/analytics/generate", response_model=NutritionalAnalyticsCacheResponse)
async def generate_analytics(
    pet_id: str,
    analysis_type: AnalyticsType,
    force_refresh: bool = Query(False),
    current_user: User = Depends(get_current_user)
):
    """
    Generate advanced analytics for a pet
    
    Args:
        pet_id: Pet ID
        analysis_type: Type of analysis to perform
        force_refresh: Force regeneration even if cache exists
        current_user: Authenticated user
        
    Returns:
        Analytics cache response
    """
    try:
        return await get_analytics_service().generate_analytics(
            pet_id, current_user.id, analysis_type, force_refresh
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate analytics: {str(e)}"
        )


@router.get("/analytics/health-insights/{pet_id}", response_model=HealthInsights)
async def get_health_insights(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get comprehensive health insights for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        
    Returns:
        Health insights data
    """
    try:
        return await get_analytics_service().get_health_insights(pet_id, current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get health insights: {str(e)}"
        )


@router.get("/analytics/patterns/{pet_id}", response_model=NutritionalPatterns)
async def analyze_nutritional_patterns(
    pet_id: str,
    analysis_period: str = Query("30_days", regex="^(7_days|30_days|90_days)$"),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze nutritional patterns for a pet
    
    Args:
        pet_id: Pet ID
        analysis_period: Period for analysis
        current_user: Authenticated user
        
    Returns:
        Nutritional patterns analysis
    """
    try:
        return await get_analytics_service().analyze_nutritional_patterns(
            pet_id, current_user.id, analysis_period
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to analyze patterns: {str(e)}"
        )


# Comprehensive Advanced Nutrition Dashboard

@router.get("/dashboard/{pet_id}", response_model=AdvancedNutritionResponse)
async def get_advanced_nutrition_dashboard(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get comprehensive advanced nutrition dashboard data
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        
    Returns:
        Complete advanced nutrition data
    """
    try:
        # Get all advanced nutrition data in parallel
        import asyncio
        
        weight_records_task = get_weight_service().get_weight_history(pet_id, current_user.id, 30)
        weight_goals_task = get_weight_service().get_active_weight_goal(pet_id, current_user.id)
        trends_task = get_trends_service().get_nutritional_trends(pet_id, current_user.id, 30)
        health_insights_task = get_analytics_service().get_health_insights(pet_id, current_user.id)
        
        # Wait for all tasks to complete
        weight_records, weight_goals, trends, health_insights = await asyncio.gather(
            weight_records_task,
            weight_goals_task,
            trends_task,
            health_insights_task,
            return_exceptions=True
        )
        
        # Handle any exceptions
        if isinstance(weight_records, Exception):
            raise weight_records
        if isinstance(weight_goals, Exception):
            raise weight_goals
        if isinstance(trends, Exception):
            raise trends
        if isinstance(health_insights, Exception):
            raise health_insights
        
        # Get recommendations (would be generated by recommendation service)
        recommendations = []  # TODO: Integrate with recommendation service
        
        return AdvancedNutritionResponse(
            weight_records=weight_records,
            weight_goals=[weight_goals] if weight_goals else [],
            current_trends=trends,
            active_recommendations=recommendations,
            analytics_cache=None,  # Would be populated by analytics service
            health_insights=health_insights
        )
        
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get Phase 3 dashboard: {str(e)}"
        )
