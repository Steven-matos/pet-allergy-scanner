"""
Advanced Nutrition - Trends Sub-domain

Handles nutritional trends analysis and trends dashboard.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List
from datetime import datetime, date, timedelta

from app.database import get_supabase_client
from app.models.advanced_nutrition import (
    NutritionalTrendResponse, NutritionalTrendsDashboard
)
from app.models.user import User
from app.core.security.jwt_handler import get_current_user, security
from app.services.nutritional_trends_service import NutritionalTrendsService

router = APIRouter(prefix="/trends", tags=["advanced-nutrition-trends"])

# Lazy service initialization
trends_service = None

def get_trends_service():
    """Get nutritional trends service instance (lazy initialization)"""
    global trends_service
    if trends_service is None:
        trends_service = NutritionalTrendsService()
    return trends_service


@router.get("/{pet_id}", response_model=List[NutritionalTrendResponse])
async def get_nutritional_trends(
    pet_id: str,
    days: int = Query(30, description="Number of days to analyze"),
    trend_type: str = Query("all", description="Type of trends to analyze"),
    current_user: User = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get nutritional trends for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to analyze
        trend_type: Type of trends to analyze
        current_user: Current authenticated user
        
    Returns:
        List of nutritional trends
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Create authenticated Supabase client for RLS policies
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet ownership with authenticated client
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get nutritional trends
        service = get_trends_service()
        trends = await service.get_nutritional_trends(pet_id, days, trend_type)
        
        return trends
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get nutritional trends: {str(e)}"
        )


@router.get("/dashboard/{pet_id}", response_model=NutritionalTrendsDashboard)
async def get_trends_dashboard(
    pet_id: str,
    days: int = Query(30, description="Number of days for dashboard"),
    current_user: User = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get nutritional trends dashboard for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days for dashboard
        current_user: Current authenticated user
        
    Returns:
        Nutritional trends dashboard
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Create authenticated Supabase client for RLS policies
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet ownership with authenticated client
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get trends dashboard
        service = get_trends_service()
        dashboard = await service.get_trends_dashboard(pet_id, days)
        
        return dashboard
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get trends dashboard: {str(e)}"
        )
