"""
Food Management Router
Handles food database, barcode scanning, and food item management
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
import uuid

from ..database import get_db
from ..models.food_items import (
    FoodItemCreate,
    FoodItemResponse,
    FoodItemUpdate,
    FoodSearchRequest,
    FoodSearchResponse,
    FoodAnalysisResponse
)
from ..models.user import UserResponse
from ..utils.security import get_current_user
from ..utils.error_handling import create_error_response, APIError

router = APIRouter(prefix="/foods", tags=["food-management"])


@router.get("/recent", response_model=List[FoodItemResponse])
async def get_recent_foods(
    limit: int = Query(20, ge=1, le=100, description="Maximum number of results"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get recently used food items for the current user
    
    Args:
        limit: Maximum number of results
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of recent food items
    """
    try:
        # Get recent food items based on feeding records
        # This would typically join with feeding_records table
        # For now, return a simple query of food items
        
        recent_foods = db.query(FoodItemResponse).order_by(
            FoodItemResponse.created_at.desc()
        ).limit(limit).all()
        
        return recent_foods
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/search", response_model=FoodSearchResponse)
async def search_foods(
    q: Optional[str] = Query(None, description="Search query"),
    brand: Optional[str] = Query(None, description="Brand filter"),
    category: Optional[str] = Query(None, description="Category filter"),
    limit: int = Query(20, ge=1, le=100, description="Maximum results"),
    offset: int = Query(0, ge=0, description="Results offset"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Search food items with filters
    
    Args:
        q: Search query
        brand: Brand filter
        category: Category filter
        limit: Maximum results
        offset: Results offset
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Search results with pagination
    """
    try:
        # Build query
        query = db.query(FoodItemResponse)
        
        if q:
            query = query.filter(
                FoodItemResponse.name.ilike(f"%{q}%") |
                FoodItemResponse.brand.ilike(f"%{q}%") |
                FoodItemResponse.description.ilike(f"%{q}%")
            )
        
        if brand:
            query = query.filter(FoodItemResponse.brand.ilike(f"%{brand}%"))
        
        if category:
            query = query.filter(FoodItemResponse.category == category)
        
        # Get total count
        total_count = query.count()
        
        # Get paginated results
        items = query.offset(offset).limit(limit).all()
        
        return FoodSearchResponse(
            items=items,
            total_count=total_count,
            has_more=(offset + limit) < total_count
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/barcode/{barcode}", response_model=Optional[FoodItemResponse])
async def get_food_by_barcode(
    barcode: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food item by barcode
    
    Args:
        barcode: Barcode/UPC code
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Food item or None if not found
    """
    try:
        food_item = db.query(FoodItemResponse).filter(
            FoodItemResponse.barcode == barcode
        ).first()
        
        return food_item
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/", response_model=FoodItemResponse)
async def create_food_item(
    food_item: FoodItemCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create a new food item
    
    Args:
        food_item: Food item data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created food item
    """
    try:
        # Check if food item with same name and brand already exists
        existing_item = db.query(FoodItemResponse).filter(
            FoodItemResponse.name == food_item.name,
            FoodItemResponse.brand == food_item.brand
        ).first()
        
        if existing_item:
            raise HTTPException(
                status_code=400, 
                detail="Food item with this name and brand already exists"
            )
        
        # Create new food item
        new_food_item = FoodItemResponse(
            id=str(uuid.uuid4()),
            **food_item.dict(),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        db.add(new_food_item)
        db.commit()
        db.refresh(new_food_item)
        
        return new_food_item
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.put("/{food_id}", response_model=FoodItemResponse)
async def update_food_item(
    food_id: str,
    food_update: FoodItemUpdate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update an existing food item
    
    Args:
        food_id: Food item ID
        food_update: Updated food item data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Updated food item
    """
    try:
        # Get existing food item
        food_item = db.query(FoodItemResponse).filter(
            FoodItemResponse.id == food_id
        ).first()
        
        if not food_item:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        # Update fields
        update_data = food_update.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(food_item, field, value)
        
        food_item.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(food_item)
        
        return food_item
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.delete("/{food_id}")
async def delete_food_item(
    food_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a food item
    
    Args:
        food_id: Food item ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Success message
    """
    try:
        # Get existing food item
        food_item = db.query(FoodItemResponse).filter(
            FoodItemResponse.id == food_id
        ).first()
        
        if not food_item:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        # Check if food item is being used in feeding records
        # This would typically check feeding_records table
        # For now, we'll allow deletion
        
        db.delete(food_item)
        db.commit()
        
        return {"message": "Food item deleted successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/{food_id}", response_model=FoodItemResponse)
async def get_food_item(
    food_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food item by ID
    
    Args:
        food_id: Food item ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Food item details
    """
    try:
        food_item = db.query(FoodItemResponse).filter(
            FoodItemResponse.id == food_id
        ).first()
        
        if not food_item:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        return food_item
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/categories", response_model=List[str])
async def get_food_categories(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of available food categories
    
    Args:
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of food categories
    """
    try:
        # Get distinct categories
        categories = db.query(FoodItemResponse.category).distinct().all()
        
        # Filter out None values and return as list
        category_list = [cat[0] for cat in categories if cat[0] is not None]
        
        return sorted(category_list)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/brands", response_model=List[str])
async def get_food_brands(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of available food brands
    
    Args:
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of food brands
    """
    try:
        # Get distinct brands
        brands = db.query(FoodItemResponse.brand).distinct().all()
        
        # Filter out None values and return as list
        brand_list = [brand[0] for brand in brands if brand[0] is not None]
        
        return sorted(brand_list)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
