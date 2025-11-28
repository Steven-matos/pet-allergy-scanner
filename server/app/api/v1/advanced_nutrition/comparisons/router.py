"""
Advanced Nutrition - Food Comparisons Sub-domain

Handles food comparison analysis and comparison dashboards.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from datetime import datetime

from app.database import get_supabase_client
from app.models.advanced_nutrition import (
    FoodComparisonCreate, FoodComparisonResponse,
    FoodComparisonDashboard
)
from app.models.user import User
from app.core.security.jwt_handler import get_current_user
from app.services.food_comparison_service import FoodComparisonService

router = APIRouter(prefix="/comparisons", tags=["advanced-nutrition-comparisons"])

# Service factory function

def get_comparison_service(supabase: Client):
    """
    Get food comparison service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
    """
    return FoodComparisonService(supabase)


@router.post("", response_model=FoodComparisonResponse)
async def create_food_comparison_no_slash(
    comparison: FoodComparisonCreate,
    current_user: User = Depends(get_current_user)
):
    """Create food comparison (without trailing slash)"""
    return await create_food_comparison_with_slash(comparison, current_user)

@router.post("/", response_model=FoodComparisonResponse)
async def create_food_comparison_with_slash(
    comparison: FoodComparisonCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create a food comparison analysis
    
    Args:
        comparison: Food comparison data
        current_user: Current authenticated user
        
    Returns:
        Created food comparison
        
    Raises:
        HTTPException: If comparison creation fails
    """
    try:
        # Create food comparison
        service = get_comparison_service(supabase)
        result = await service.create_comparison(comparison, current_user.id)
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create food comparison: {str(e)}"
        )


@router.get("/{comparison_id}", response_model=FoodComparisonResponse)
async def get_food_comparison(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get a specific food comparison
    
    Args:
        comparison_id: Comparison ID
        current_user: Current authenticated user
        
    Returns:
        Food comparison data
        
    Raises:
        HTTPException: If comparison not found or user not authorized
    """
    try:
        # Get food comparison
        service = get_comparison_service(supabase)
        comparison = await service.get_comparison(comparison_id, current_user.id)
        
        if not comparison:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Food comparison not found"
            )
        
        return comparison
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get food comparison: {str(e)}"
        )


@router.get("/", response_model=List[FoodComparisonResponse])
async def get_user_comparisons(
    current_user: User = Depends(get_current_user)
):
    """
    Get all food comparisons for the current user
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        List of food comparisons
        
    Raises:
        HTTPException: If comparisons retrieval fails
    """
    try:
        # Get user comparisons
        service = get_comparison_service(supabase)
        comparisons = await service.get_user_comparisons(current_user.id)
        
        return comparisons
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user comparisons: {str(e)}"
        )


@router.get("/dashboard/{comparison_id}", response_model=FoodComparisonDashboard)
async def get_comparison_dashboard(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get food comparison dashboard
    
    Args:
        comparison_id: Comparison ID
        current_user: Current authenticated user
        
    Returns:
        Food comparison dashboard
        
    Raises:
        HTTPException: If comparison not found or user not authorized
    """
    try:
        # Get comparison dashboard
        service = get_comparison_service(supabase)
        dashboard = await service.get_comparison_dashboard(comparison_id, current_user.id)
        
        if not dashboard:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Food comparison not found"
            )
        
        return dashboard
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get comparison dashboard: {str(e)}"
        )


@router.delete("/{comparison_id}")
async def delete_food_comparison(
    comparison_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Delete a food comparison
    
    Args:
        comparison_id: Comparison ID
        current_user: Current authenticated user
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If comparison not found or user not authorized
    """
    try:
        # Delete food comparison
        service = get_comparison_service(supabase)
        success = await service.delete_comparison(comparison_id, current_user.id)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Food comparison not found"
            )
        
        return {"message": "Food comparison deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete food comparison: {str(e)}"
        )
