"""
Food Management Router
Handles food database, barcode scanning, and food item management
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime

from app.core.database import get_supabase_client, get_db
from app.models.nutrition.food_items import (
    FoodItemCreate,
    FoodItemResponse,
    FoodItemUpdate,
    FoodSearchRequest,
    FoodSearchResponse,
    FoodAnalysisResponse,
    NutritionalInfoBase
)
from app.models.core.user import UserResponse
from app.core.security.jwt_handler import get_current_user
from app.utils.error_handling import create_error_response, APIError
from app.utils.logging_config import get_logger
from app.shared.utils.async_supabase import execute_async

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.query_result_parser import QueryResultParser
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.decorators.error_handler import handle_errors

router = APIRouter(prefix="/foods", tags=["food-management"])
logger = get_logger(__name__)


@router.get("/recent", response_model=List[FoodItemResponse])
@handle_errors("get_recent_foods")
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
    # Get recent food items using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    result = await query_builder.with_ordering("created_at", desc=True)\
        .with_limit(limit)\
        .execute()
    
    # Handle empty response
    items_data = handle_empty_response(result["data"])
    
    # Parse JSON fields (nutritional_info)
    parsed_data = QueryResultParser.parse_list_json_fields(
        items_data,
        ["nutritional_info"],
        defaults={"nutritional_info": {}}
    )
    
    # Convert nutritional_info dicts to Pydantic models and create response models
    items = []
    for item in parsed_data:
        nutritional_info = None
        if item.get("nutritional_info"):
            try:
                nutritional_info = NutritionalInfoBase(**item["nutritional_info"])
            except Exception as e:
                logger.warning(f"Failed to parse nutritional_info: {e}")
                nutritional_info = None
        
        # Create response model manually since nutritional_info needs special handling
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
    
    return items


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
        # Import centralized services
        from app.shared.services.query_builder_service import QueryBuilderService
        from app.shared.services.response_model_service import ResponseModelService
        from app.shared.services.query_result_parser import QueryResultParser
        from app.shared.services.pagination_service import PaginationService
        
        # Build flexible multi-field search that handles typos and partial matches
        # Searches across name, brand, and description fields
        # Combines results from multiple field searches to ensure comprehensive matching
        # 
        # Future improvement: For better typo tolerance, consider using PostgreSQL's
        # pg_trgm extension with similarity() function via a custom RPC function.
        # This would allow fuzzy matching for typos (e.g., "Weruva" matches "Weruva" even with typos)
        
        if q:
            # Clean and prepare search term (case-insensitive matching)
            # PostgreSQL ILIKE is case-insensitive, but we normalize for consistency
            search_term = q.strip()
            if not search_term:
                search_term = None
            
            # For flexible search, we'll search name, brand, and description separately
            # and combine results to ensure we catch all matches (handles brand-only searches, typos, etc.)
            # All searches use ILIKE which is case-insensitive, so "Weruva", "WERUVA", "weruva" all match
            # This approach ensures we find products even if:
            # - User only searches brand name (e.g., "Weruva" or "WERUVA")
            # - User searches partial product name (e.g., "classic cat" or "Classic Cat")
            # - Database has mixed case (e.g., "Weruva" in DB, user searches "WERUVA")
            # - User has typos (partial matching helps catch some typos)
            all_results = []
            seen_ids = set()
            
            # Search in name field (primary search) - handles full product names
            # ILIKE is case-insensitive: matches "Weruva", "WERUVA", "weruva", etc.
            query_name = QueryBuilderService(supabase, "food_items", include_count=False)
            if category:
                query_name.with_filters({"category": category})
            if brand:
                # Brand filter is also case-insensitive via ILIKE
                query_name.with_ilike("brand", brand)
            # Case-insensitive search in name field
            query_name.with_ilike("name", search_term)
            result_name = await query_name.with_pagination(limit * 2, 0, include_count=False).execute()
            
            for item in result_name.get("data", []):
                if item["id"] not in seen_ids:
                    all_results.append(item)
                    seen_ids.add(item["id"])
            
            # Search in brand field (for brand-only searches)
            # Case-insensitive: "Weruva", "WERUVA", "weruva" all match
            query_brand = QueryBuilderService(supabase, "food_items", include_count=False)
            if category:
                query_brand.with_filters({"category": category})
            if brand:
                # Brand filter is also case-insensitive via ILIKE
                query_brand.with_ilike("brand", brand)
            # Case-insensitive search in brand field
            query_brand.with_ilike("brand", search_term)
            result_brand = await query_brand.with_pagination(limit * 2, 0, include_count=False).execute()
            
            for item in result_brand.get("data", []):
                if item["id"] not in seen_ids:
                    all_results.append(item)
                    seen_ids.add(item["id"])
            
            # Search in description field (if exists)
            # Case-insensitive search in description
            # Note: description might not exist in all records, so we'll try it
            try:
                query_desc = QueryBuilderService(supabase, "food_items", include_count=False)
                if category:
                    query_desc.with_filters({"category": category})
                if brand:
                    # Brand filter is also case-insensitive via ILIKE
                    query_desc.with_ilike("brand", brand)
                # Case-insensitive search in description field
                query_desc.with_ilike("description", search_term)
                result_desc = await query_desc.with_pagination(limit, 0, include_count=False).execute()
                
                for item in result_desc.get("data", []):
                    if item["id"] not in seen_ids:
                        all_results.append(item)
                        seen_ids.add(item["id"])
            except Exception as e:
                # Description field might not be searchable or might not exist
                logger.debug(f"Description search not available: {e}")
            
            # Sort results by relevance (name matches first, then brand, then description)
            # All comparisons are case-insensitive (using .lower()) to handle mixed case in database
            # This ensures consistent sorting regardless of how data is stored (e.g., "Weruva" vs "WERUVA")
            def sort_key(item):
                # Normalize to lowercase for case-insensitive comparison
                name_lower = (item.get("name") or "").lower()
                brand_lower = (item.get("brand") or "").lower()
                search_lower = search_term.lower()
                
                # Exact name match gets highest priority
                if name_lower == search_lower:
                    return (0, name_lower)
                # Name starts with search term
                elif name_lower.startswith(search_lower):
                    return (1, name_lower)
                # Name contains search term
                elif search_lower in name_lower:
                    return (2, name_lower)
                # Brand match
                elif search_lower in brand_lower:
                    return (3, brand_lower)
                # Other matches
                else:
                    return (4, name_lower)
            
            all_results.sort(key=sort_key)
            
            # Apply pagination to combined results
            paginated_results = all_results[offset:offset + limit]
            total_count = len(all_results)
            
            # Create result structure matching expected format
            result = {
                "data": paginated_results,
                "count": total_count
            }
        else:
            # No search query, just filters
            query_builder = QueryBuilderService(supabase, "food_items", include_count=True)
            filters = {}
            if category:
                filters["category"] = category
            if filters:
                query_builder.with_filters(filters)
            if brand:
                # Brand filter uses ILIKE for case-insensitive matching
                query_builder.with_ilike("brand", brand)
            
            # Execute with pagination
            result = await query_builder.with_pagination(limit, offset, include_count=False).execute()
        
        # Extract count from result (handled differently for search vs non-search)
        total_count = result.get("count")
        if total_count is None:
            # Fallback: if count not available, use data length as approximation
            total_count = len(result["data"])
            # If we got a full page and no search query, there might be more results
            if len(result["data"]) == limit and not q:
                total_count = limit + 1  # Indicate there might be more
        
        # Parse JSON fields (nutritional_info)
        parsed_data = QueryResultParser.parse_list_json_fields(
            result["data"],
            ["nutritional_info"],
            defaults={"nutritional_info": {}}
        )
        
        # Convert nutritional_info dicts to Pydantic models
        items = []
        for item in parsed_data:
            nutritional_info = None
            if item.get("nutritional_info"):
                try:
                    nutritional_info = NutritionalInfoBase(**item["nutritional_info"])
                except Exception as e:
                    logger.warning(f"Failed to parse nutritional_info: {e}")
                    nutritional_info = None
            
            # Create response model manually since nutritional_info needs special handling
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
        
        # Build pagination response using centralized service
        pagination = PaginationService.build_pagination_response(
            items=items,
            total_count=total_count,  # Use the count we calculated
            offset=offset,
            limit=limit
        )
        
        return FoodSearchResponse(
            items=pagination.items,
            total_count=pagination.total_count,
            has_more=pagination.has_more
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error searching foods: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/barcode/{barcode}", response_model=Optional[FoodItemResponse])
@handle_errors("get_food_by_barcode")
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
    from app.core.database import get_supabase_client
    supabase = get_supabase_client()
    
    # Clean barcode: trim whitespace and normalize
    cleaned_barcode = barcode.strip() if barcode else ""
    if not cleaned_barcode:
        logger.warning(f"Empty barcode provided for search")
        return None
    
    logger.info(f"Searching for barcode: {cleaned_barcode}")
    
    # Query food_items table by barcode using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    result = await query_builder.with_filters({"barcode": cleaned_barcode}).with_limit(1).execute()
    
    if not result["data"]:
        logger.info(f"No food item found with barcode: {cleaned_barcode}")
        return None
    
    logger.info(f"Found food item with barcode: {cleaned_barcode}, name: {result['data'][0].get('name', 'Unknown')}")
    
    food_item = result["data"][0]
    
    # Parse nutritional_info JSONB field using query result parser
    parsed_item = QueryResultParser.parse_json_fields(
        food_item,
        ["nutritional_info"],
        defaults={"nutritional_info": {}}
    )
    
    # Convert nutritional_info dict to Pydantic model
    nutritional_info = None
    if parsed_item.get("nutritional_info"):
        try:
            nutritional_info = NutritionalInfoBase(**parsed_item["nutritional_info"])
        except Exception as e:
            logger.warning(f"Failed to parse nutritional_info: {e}")
            nutritional_info = None
    
    # Build response model manually since we need to handle description
    return FoodItemResponse(
        id=parsed_item["id"],
        name=parsed_item["name"],
        brand=parsed_item.get("brand"),
        barcode=parsed_item.get("barcode"),
        nutritional_info=nutritional_info,
        category=parsed_item.get("category"),
        description=None,  # Build description from available data
        created_at=parsed_item["created_at"],
        updated_at=parsed_item["updated_at"]
    )


@router.post("", response_model=FoodItemResponse)
async def create_food_item_no_slash(
    food_item: FoodItemCreate,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create food item (without trailing slash)"""
    return await create_food_item_with_slash(food_item, supabase, current_user)

@router.post("/", response_model=FoodItemResponse)
@handle_errors("create_food_item")
async def create_food_item_with_slash(
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
    # Check if food item with same name and brand already exists using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    existing_result = await query_builder.select(["id"]).with_filters({
        "name": food_item.name,
        "brand": food_item.brand
    }).with_limit(1).execute()
    
    if existing_result["data"]:
        raise HTTPException(
            status_code=400, 
            detail="Food item with this name and brand already exists"
        )
    
    # Prepare data for insertion using data transformation service
    item_data = DataTransformationService.model_to_dict_with_nested(food_item)
    item_data["id"] = IDGenerationService.generate_uuid()
    
    # Insert new food item using service role client to bypass RLS
    from app.core.database import get_supabase_service_role_client
    service_supabase = get_supabase_service_role_client()
    db_service = DatabaseOperationService(service_supabase)
    created_item = await db_service.insert_with_timestamps("food_items", item_data)
    
    # Parse nutritional_info and build response model
    parsed_item = QueryResultParser.parse_json_fields(
        created_item,
        ["nutritional_info"],
        defaults={"nutritional_info": {}}
    )
    
    nutritional_info = None
    if parsed_item.get("nutritional_info"):
        try:
            nutritional_info = NutritionalInfoBase(**parsed_item["nutritional_info"])
        except Exception as e:
            logger.warning(f"Failed to parse nutritional_info: {e}")
            nutritional_info = None
    
    # Create response model manually since nutritional_info needs special handling
    return FoodItemResponse(
        id=parsed_item["id"],
        name=parsed_item["name"],
        brand=parsed_item.get("brand"),
        barcode=parsed_item.get("barcode"),
        nutritional_info=nutritional_info,
        category=parsed_item.get("category"),
        description=parsed_item.get("description"),
        created_at=parsed_item["created_at"],
        updated_at=parsed_item["updated_at"]
    )


@router.put("/{food_id}", response_model=FoodItemResponse)
@handle_errors("update_food_item")
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
    # Check if food item exists using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    existing_result = await query_builder.select(["id"]).with_filters({"id": food_id}).with_limit(1).execute()
    
    if not existing_result["data"]:
        raise HTTPException(status_code=404, detail="Food item not found")
    
    # Prepare update data using data transformation service
    update_data = DataTransformationService.model_to_dict_with_nested(food_update, exclude_none=True)
    
    # Update food item using centralized service
    from app.core.database import get_supabase_service_role_client
    service_supabase = get_supabase_service_role_client()
    db_service = DatabaseOperationService(service_supabase)
    updated_item = await db_service.update_with_timestamp("food_items", food_id, update_data)
    
    # Parse nutritional_info and build response model
    parsed_item = QueryResultParser.parse_json_fields(
        updated_item,
        ["nutritional_info"],
        defaults={"nutritional_info": {}}
    )
    
    nutritional_info = None
    if parsed_item.get("nutritional_info"):
        try:
            nutritional_info = NutritionalInfoBase(**parsed_item["nutritional_info"])
        except Exception as e:
            logger.warning(f"Failed to parse nutritional_info: {e}")
            nutritional_info = None
    
    # Create response model manually since nutritional_info needs special handling
    return FoodItemResponse(
        id=parsed_item["id"],
        name=parsed_item["name"],
        brand=parsed_item.get("brand"),
        barcode=parsed_item.get("barcode"),
        nutritional_info=nutritional_info,
        category=parsed_item.get("category"),
        description=parsed_item.get("description"),
        created_at=parsed_item["created_at"],
        updated_at=parsed_item["updated_at"]
    )


@router.delete("/{food_id}")
@handle_errors("delete_food_item")
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
    # Check if food item exists using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    existing_result = await query_builder.select(["id"]).with_filters({"id": food_id}).with_limit(1).execute()
    
    if not existing_result["data"]:
        raise HTTPException(status_code=404, detail="Food item not found")
    
    # Delete food item using centralized service
    from app.core.database import get_supabase_service_role_client
    service_supabase = get_supabase_service_role_client()
    db_service = DatabaseOperationService(service_supabase)
    await db_service.delete_record("food_items", food_id)
    
    return {"message": "Food item deleted successfully"}


@router.get("/{food_id}", response_model=FoodItemResponse)
@handle_errors("get_food_item")
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
    # Get food item using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    result = await query_builder.with_filters({"id": food_id}).with_limit(1).execute()
    
    if not result["data"]:
        raise HTTPException(status_code=404, detail="Food item not found")
    
    item = result["data"][0]
    
    # Parse nutritional info using query result parser
    parsed_item = QueryResultParser.parse_json_fields(
        item,
        ["nutritional_info"],
        defaults={"nutritional_info": {}}
    )
    
    # Convert nutritional_info dict to Pydantic model
    nutritional_info = None
    if parsed_item.get("nutritional_info"):
        try:
            nutritional_info = NutritionalInfoBase(**parsed_item["nutritional_info"])
        except Exception as e:
            logger.warning(f"Failed to parse nutritional_info: {e}")
            nutritional_info = None
    
    # Create response model manually since nutritional_info needs special handling
    return FoodItemResponse(
        id=parsed_item["id"],
        name=parsed_item["name"],
        brand=parsed_item.get("brand"),
        barcode=parsed_item.get("barcode"),
        nutritional_info=nutritional_info,
        category=parsed_item.get("category"),
        description=parsed_item.get("description"),
        created_at=parsed_item["created_at"],
        updated_at=parsed_item["updated_at"]
    )


@router.get("/categories", response_model=List[str])
@handle_errors("get_food_categories")
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
    # Get all unique categories using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    query_builder.select(["category"])
    result = await query_builder.execute()
    
    # Handle empty response
    items_data = handle_empty_response(result["data"])
    
    # Extract unique categories and filter out None values
    categories = set()
    for item in items_data:
        if item.get("category"):
            categories.add(item["category"])
    
    return sorted(list(categories))


@router.get("/brands", response_model=List[str])
@handle_errors("get_food_brands")
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
    # Get all unique brands using query builder
    query_builder = QueryBuilderService(supabase, "food_items")
    query_builder.select(["brand"])
    result = await query_builder.execute()
    
    # Handle empty response
    items_data = handle_empty_response(result["data"])
    
    # Extract unique brands and filter out None values
    brands = set()
    for item in items_data:
        if item.get("brand"):
            brands.add(item["brand"])
    
    return sorted(list(brands))
