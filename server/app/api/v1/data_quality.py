"""
Data Quality API Endpoints
API endpoints for data quality assessment and analysis
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.database import get_db
from app.services.data_quality_service import DataQualityService, DataQualityMetrics
from app.models.food_items import FoodItemResponse
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/assess/{food_item_id}", response_model=Dict[str, Any])
async def assess_food_item_quality(
    food_item_id: str,
    db: Session = Depends(get_db)
):
    """
    Assess data quality for a specific food item
    
    Args:
        food_item_id: UUID of the food item to assess
        db: Database session
        
    Returns:
        Comprehensive data quality assessment
    """
    try:
        # Fetch food item data
        query = text("""
            SELECT 
                fi.id,
                fi.name,
                fi.brand,
                fi.barcode,
                fi.category,
                fi.nutritional_info,
                fi.data_completeness,
                fi.created_at,
                fi.updated_at
            FROM food_items fi
            WHERE fi.id = :food_item_id
        """)
        
        result = db.execute(query, {"food_item_id": food_item_id}).fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Food item not found")
            
        # Convert to dictionary format
        food_item_data = {
            'id': str(result.id),
            'name': result.name,
            'brand': result.brand,
            'barcode': result.barcode,
            'category': result.category,
            'nutritional_info': result.nutritional_info or {},
            'data_completeness': result.data_completeness,
            'created_at': result.created_at,
            'updated_at': result.updated_at
        }
        
        # Assess data quality
        metrics = DataQualityService.assess_data_quality(food_item_data)
        
        # Format response
        return DataQualityService.format_quality_summary(metrics)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error assessing food item quality: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.post("/assess/batch", response_model=List[Dict[str, Any]])
async def assess_multiple_food_items_quality(
    food_item_ids: List[str],
    db: Session = Depends(get_db)
):
    """
    Assess data quality for multiple food items
    
    Args:
        food_item_ids: List of food item UUIDs to assess
        db: Database session
        
    Returns:
        List of data quality assessments
    """
    try:
        if len(food_item_ids) > 50:
            raise HTTPException(status_code=400, detail="Maximum 50 items allowed per batch")
            
        # Fetch food items data
        placeholders = ','.join([f':id_{i}' for i in range(len(food_item_ids))])
        query = text(f"""
            SELECT 
                fi.id,
                fi.name,
                fi.brand,
                fi.barcode,
                fi.category,
                fi.nutritional_info,
                fi.data_completeness,
                fi.created_at,
                fi.updated_at
            FROM food_items fi
            WHERE fi.id IN ({placeholders})
        """)
        
        params = {f'id_{i}': food_item_id for i, food_item_id in enumerate(food_item_ids)}
        results = db.execute(query, params).fetchall()
        
        if not results:
            raise HTTPException(status_code=404, detail="No food items found")
            
        assessments = []
        
        for result in results:
            # Convert to dictionary format
            food_item_data = {
                'id': str(result.id),
                'name': result.name,
                'brand': result.brand,
                'barcode': result.barcode,
                'category': result.category,
                'nutritional_info': result.nutritional_info or {},
                'data_completeness': result.data_completeness,
                'created_at': result.created_at,
                'updated_at': result.updated_at
            }
            
            # Assess data quality
            metrics = DataQualityService.assess_data_quality(food_item_data)
            
            # Format response with item info
            assessment = DataQualityService.format_quality_summary(metrics)
            assessment['food_item_id'] = str(result.id)
            assessment['food_name'] = result.name
            assessment['brand'] = result.brand
            
            assessments.append(assessment)
            
        return assessments
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error assessing multiple food items quality: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/stats/overview", response_model=Dict[str, Any])
async def get_quality_statistics_overview(
    limit: int = Query(1000, ge=1, le=5000, description="Number of items to analyze"),
    db: Session = Depends(get_db)
):
    """
    Get overall data quality statistics
    
    Args:
        limit: Maximum number of food items to analyze
        db: Database session
        
    Returns:
        Overall quality statistics
    """
    try:
        # Fetch sample of food items
        query = text("""
            SELECT 
                fi.id,
                fi.name,
                fi.brand,
                fi.barcode,
                fi.nutritional_info,
                fi.data_completeness
            FROM food_items fi
            ORDER BY fi.updated_at DESC
            LIMIT :limit
        """)
        
        results = db.execute(query, {"limit": limit}).fetchall()
        
        if not results:
            return {
                "total_items": 0,
                "quality_distribution": {"excellent": 0, "good": 0, "fair": 0, "poor": 0},
                "average_score": 0.0,
                "ingredients_coverage": 0.0,
                "nutritional_coverage": 0.0
            }
        
        # Analyze quality distribution
        quality_counts = {"excellent": 0, "good": 0, "fair": 0, "poor": 0}
        total_score = 0.0
        total_items = len(results)
        items_with_ingredients = 0
        items_with_nutritional = 0
        
        for result in results:
            food_item_data = {
                'id': str(result.id),
                'name': result.name,
                'brand': result.brand,
                'barcode': result.barcode,
                'nutritional_info': result.nutritional_info or {}
            }
            
            metrics = DataQualityService.assess_data_quality(food_item_data)
            
            # Count quality levels
            quality_counts[metrics.level.value] += 1
            total_score += metrics.overall_score
            
            # Count coverage
            if metrics.ingredients_count > 0:
                items_with_ingredients += 1
            if metrics.nutritional_fields_count > 0:
                items_with_nutritional += 1
        
        return {
            "total_items": total_items,
            "quality_distribution": quality_counts,
            "average_score": round(total_score / total_items, 3),
            "ingredients_coverage": round(items_with_ingredients / total_items, 3),
            "nutritional_coverage": round(items_with_nutritional / total_items, 3),
            "sample_size": limit
        }
        
    except Exception as e:
        logger.error(f"Error getting quality statistics: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/recommendations/{food_item_id}", response_model=Dict[str, Any])
async def get_quality_recommendations(
    food_item_id: str,
    db: Session = Depends(get_db)
):
    """
    Get quality improvement recommendations for a food item
    
    Args:
        food_item_id: UUID of the food item
        db: Database session
        
    Returns:
        Quality improvement recommendations
    """
    try:
        # First assess the item
        assessment = await assess_food_item_quality(food_item_id, db)
        
        # Extract recommendations
        recommendations = assessment.get('recommendations', [])
        
        return {
            "food_item_id": food_item_id,
            "current_quality_level": assessment.get('quality_level'),
            "current_score": assessment.get('overall_score'),
            "recommendations": recommendations,
            "priority": "high" if assessment.get('overall_score', 0) < 0.5 else 
                       "medium" if assessment.get('overall_score', 0) < 0.7 else "low"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting quality recommendations: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/low-quality", response_model=List[Dict[str, Any]])
async def get_low_quality_items(
    threshold: float = Query(0.5, ge=0.0, le=1.0, description="Quality threshold"),
    limit: int = Query(50, ge=1, le=200, description="Maximum results"),
    db: Session = Depends(get_db)
):
    """
    Get food items with quality scores below threshold
    
    Args:
        threshold: Quality score threshold (0.0 to 1.0)
        limit: Maximum number of results
        db: Database session
        
    Returns:
        List of low-quality food items with assessments
    """
    try:
        # Fetch food items with low data completeness
        query = text("""
            SELECT 
                fi.id,
                fi.name,
                fi.brand,
                fi.barcode,
                fi.category,
                fi.nutritional_info,
                fi.data_completeness
            FROM food_items fi
            WHERE fi.data_completeness < :threshold
            ORDER BY fi.data_completeness ASC
            LIMIT :limit
        """)
        
        results = db.execute(query, {"threshold": threshold, "limit": limit}).fetchall()
        
        if not results:
            return []
        
        low_quality_items = []
        
        for result in results:
            food_item_data = {
                'id': str(result.id),
                'name': result.name,
                'brand': result.brand,
                'barcode': result.barcode,
                'category': result.category,
                'nutritional_info': result.nutritional_info or {}
            }
            
            metrics = DataQualityService.assess_data_quality(food_item_data)
            
            # Only include if still below threshold with new calculation
            if metrics.overall_score < threshold:
                assessment = DataQualityService.format_quality_summary(metrics)
                assessment['food_item_id'] = str(result.id)
                assessment['food_name'] = result.name
                assessment['brand'] = result.brand
                assessment['legacy_completeness'] = result.data_completeness
                
                low_quality_items.append(assessment)
        
        return low_quality_items
        
    except Exception as e:
        logger.error(f"Error getting low quality items: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")
