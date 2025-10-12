"""
Food Management Router
Handles food database, barcode scanning, and food item management
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime
import uuid

from ..database import get_supabase_client, get_db
from ..models.food_items import (
    FoodItemCreate,
    FoodItemResponse,
    FoodItemUpdate,
    FoodSearchRequest,
    FoodSearchResponse,
    FoodAnalysisResponse,
    NutritionalInfoBase
)
from ..models.user import UserResponse
from ..core.security.jwt_handler import get_current_user
from ..utils.error_handling import create_error_response, APIError
from ..utils.logging_config import get_logger

router = APIRouter(prefix="/foods", tags=["food-management"])
logger = get_logger(__name__)


@router.get("/recent", response_model=List[FoodItemResponse])
async def get_recent_foods(
    limit: int = Query(20, ge=1, le=100, description="Maximum number of results"),
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get recently used food items for the current user
    
    Args:
        limit: Maximum number of results
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of recent food items
    """
    try:
        # Get recent food items ordered by creation date
        response = supabase.table("food_items").select("*").order("created_at", desc=True).limit(limit).execute()
        
        if not response.data:
            return []
        
        # Parse response into FoodItemResponse models
        recent_foods = []
        for item in response.data:
            nutritional_info = None
            if item.get("nutritional_info"):
                try:
                    nutritional_info = NutritionalInfoBase(**item["nutritional_info"])
                except Exception as e:
                    logger.warning(f"Failed to parse nutritional_info: {e}")
            
            recent_foods.append(FoodItemResponse(
                id=item["id"],
                name=item["name"],
                brand=item.get("brand"),
                barcode=item.get("barcode"),
                nutritional_info=nutritional_info,
                category=item.get("category"),
                description=item.get("description"),
                created_at=item["created_at"],
                updated_at=item["updated_at"]
            ))
        
        return recent_foods
        
    except Exception as e:
        logger.error(f"Error fetching recent foods: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/search", response_model=FoodSearchResponse)
async def search_foods(
    q: Optional[str] = Query(None, description="Search query"),
    brand: Optional[str] = Query(None, description="Brand filter"),
    category: Optional[str] = Query(None, description="Category filter"),
    limit: int = Query(20, ge=1, le=100, description="Maximum results"),
    offset: int = Query(0, ge=0, description="Results offset"),
    supabase = Depends(get_db),
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
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Search results with pagination
    """
    try:
        # Build query with filters
        query = supabase.table("food_items").select("*", count="exact")
        
        if q:
            # Search in name, brand, and description
            query = query.or_(f"name.ilike.%{q}%,brand.ilike.%{q}%,description.ilike.%{q}%")
        
        if brand:
            query = query.ilike("brand", f"%{brand}%")
        
        if category:
            query = query.eq("category", category)
        
        # Execute with pagination
        response = query.range(offset, offset + limit - 1).execute()
        
        # Parse results
        items = []
        for item in response.data:
            nutritional_info = None
            if item.get("nutritional_info"):
                try:
                    nutritional_info = NutritionalInfoBase(**item["nutritional_info"])
                except Exception as e:
                    logger.warning(f"Failed to parse nutritional_info: {e}")
            
            items.append(FoodItemResponse(
                id=item["id"],
                name=item["name"],
                brand=item.get("brand"),
                barcode=item.get("barcode"),
                nutritional_info=nutritional_info,
                category=item.get("category"),
                description=item.get("description"),
                created_at=item["created_at"],
                updated_at=item["updated_at"]
            ))
        
        total_count = response.count if response.count else 0
        
        return FoodSearchResponse(
            items=items,
            total_count=total_count,
            has_more=(offset + limit) < total_count
        )
        
    except Exception as e:
        logger.error(f"Error searching foods: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/barcode/{barcode}", response_model=Optional[FoodItemResponse])
async def get_food_by_barcode(
    barcode: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food item by barcode
    
    Searches the food_items database for a product with the given barcode.
    Returns product details with nutritional information if found.
    
    Args:
        barcode: Barcode/UPC code (e.g., EAN-13, UPC-A)
        current_user: Current authenticated user
        
    Returns:
        Food item with full details or None if not found
    """
    try:
        from ..database import get_supabase_client
        from ..utils.logging_config import get_logger
        
        logger = get_logger(__name__)
        supabase = get_supabase_client()
        
        # Query food_items table by barcode
        response = supabase.table("food_items").select("*").eq("barcode", barcode).limit(1).execute()
        
        if not response.data or len(response.data) == 0:
            logger.info(f"No product found for barcode: {barcode}")
            return None
        
        food_item = response.data[0]
        logger.info(f"Found product for barcode {barcode}: {food_item.get('name', 'Unknown')}")
        
        # Parse nutritional_info JSONB field
        nutritional_info = None
        if food_item.get("nutritional_info"):
            try:
                nutritional_info = NutritionalInfoBase(**food_item["nutritional_info"])
            except Exception as e:
                logger.warning(f"Failed to parse nutritional_info: {e}")
                nutritional_info = None
        
        return FoodItemResponse(
            id=food_item["id"],
            name=food_item["name"],
            brand=food_item.get("brand"),
            barcode=food_item.get("barcode"),
            nutritional_info=nutritional_info,
            category=food_item.get("category"),
            description=None,  # Build description from available data
            created_at=food_item["created_at"],
            updated_at=food_item["updated_at"]
        )
        
    except Exception as e:
        from ..utils.logging_config import get_logger
        logger = get_logger(__name__)
        logger.error(f"Error fetching food by barcode {barcode}: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/", response_model=FoodItemResponse)
async def create_food_item(
    food_item: FoodItemCreate,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create a new food item
    
    Args:
        food_item: Food item data
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Created food item
    """
    try:
        # Check if food item with same name and brand already exists
        existing_response = supabase.table("food_items").select("id").eq("name", food_item.name).eq("brand", food_item.brand).limit(1).execute()
        
        if existing_response.data:
            raise HTTPException(
                status_code=400, 
                detail="Food item with this name and brand already exists"
            )
        
        # Prepare data for insertion
        item_data = food_item.dict()
        item_data["id"] = str(uuid.uuid4())
        
        # Convert nutritional_info to dict if it's a Pydantic model
        if item_data.get("nutritional_info") and hasattr(item_data["nutritional_info"], "dict"):
            item_data["nutritional_info"] = item_data["nutritional_info"].dict()
        
        # Insert new food item
        response = supabase.table("food_items").insert(item_data).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create food item")
        
        created_item = response.data[0]
        
        # Parse and return response
        nutritional_info = None
        if created_item.get("nutritional_info"):
            try:
                nutritional_info = NutritionalInfoBase(**created_item["nutritional_info"])
            except Exception as e:
                logger.warning(f"Failed to parse nutritional_info: {e}")
        
        return FoodItemResponse(
            id=created_item["id"],
            name=created_item["name"],
            brand=created_item.get("brand"),
            barcode=created_item.get("barcode"),
            nutritional_info=nutritional_info,
            category=created_item.get("category"),
            description=created_item.get("description"),
            created_at=created_item["created_at"],
            updated_at=created_item["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating food item: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.put("/{food_id}", response_model=FoodItemResponse)
async def update_food_item(
    food_id: str,
    food_update: FoodItemUpdate,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update an existing food item
    
    Args:
        food_id: Food item ID
        food_update: Updated food item data
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Updated food item
    """
    try:
        # Check if food item exists
        existing_response = supabase.table("food_items").select("id").eq("id", food_id).limit(1).execute()
        
        if not existing_response.data:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        # Prepare update data
        update_data = food_update.dict(exclude_unset=True)
        
        # Convert nutritional_info to dict if it's a Pydantic model
        if update_data.get("nutritional_info") and hasattr(update_data["nutritional_info"], "dict"):
            update_data["nutritional_info"] = update_data["nutritional_info"].dict()
        
        # Update food item
        response = supabase.table("food_items").update(update_data).eq("id", food_id).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to update food item")
        
        updated_item = response.data[0]
        
        # Parse and return response
        nutritional_info = None
        if updated_item.get("nutritional_info"):
            try:
                nutritional_info = NutritionalInfoBase(**updated_item["nutritional_info"])
            except Exception as e:
                logger.warning(f"Failed to parse nutritional_info: {e}")
        
        return FoodItemResponse(
            id=updated_item["id"],
            name=updated_item["name"],
            brand=updated_item.get("brand"),
            barcode=updated_item.get("barcode"),
            nutritional_info=nutritional_info,
            category=updated_item.get("category"),
            description=updated_item.get("description"),
            created_at=updated_item["created_at"],
            updated_at=updated_item["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating food item: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.delete("/{food_id}")
async def delete_food_item(
    food_id: str,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a food item
    
    Args:
        food_id: Food item ID
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Success message
    """
    try:
        # Check if food item exists
        existing_response = supabase.table("food_items").select("id").eq("id", food_id).limit(1).execute()
        
        if not existing_response.data:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        # Delete food item
        response = supabase.table("food_items").delete().eq("id", food_id).execute()
        
        return {"message": "Food item deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting food item: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/{food_id}", response_model=FoodItemResponse)
async def get_food_item(
    food_id: str,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food item by ID
    
    Args:
        food_id: Food item ID
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Food item details
    """
    try:
        response = supabase.table("food_items").select("*").eq("id", food_id).limit(1).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Food item not found")
        
        item = response.data[0]
        
        # Parse nutritional info
        nutritional_info = None
        if item.get("nutritional_info"):
            try:
                nutritional_info = NutritionalInfoBase(**item["nutritional_info"])
            except Exception as e:
                logger.warning(f"Failed to parse nutritional_info: {e}")
        
        return FoodItemResponse(
            id=item["id"],
            name=item["name"],
            brand=item.get("brand"),
            barcode=item.get("barcode"),
            nutritional_info=nutritional_info,
            category=item.get("category"),
            description=item.get("description"),
            created_at=item["created_at"],
            updated_at=item["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching food item: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/categories", response_model=List[str])
async def get_food_categories(
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of available food categories
    
    Args:
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of food categories
    """
    try:
        # Get all unique categories
        response = supabase.table("food_items").select("category").execute()
        
        if not response.data:
            return []
        
        # Extract unique categories and filter out None values
        categories = set()
        for item in response.data:
            if item.get("category"):
                categories.add(item["category"])
        
        return sorted(list(categories))
        
    except Exception as e:
        logger.error(f"Error fetching food categories: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/brands", response_model=List[str])
async def get_food_brands(
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of available food brands
    
    Args:
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of food brands
    """
    try:
        # Get all unique brands
        response = supabase.table("food_items").select("brand").execute()
        
        if not response.data:
            return []
        
        # Extract unique brands and filter out None values
        brands = set()
        for item in response.data:
            if item.get("brand"):
                brands.add(item["brand"])
        
        return sorted(list(brands))
        
    except Exception as e:
        logger.error(f"Error fetching food brands: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
