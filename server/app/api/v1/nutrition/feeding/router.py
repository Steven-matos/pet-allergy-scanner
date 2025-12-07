"""
Nutrition Feeding Sub-domain Router

Handles feeding records and daily nutrition summaries.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional
from datetime import datetime

from app.core.database import get_db
from app.models.nutrition.nutrition import (
    FeedingRecordCreate,
    FeedingRecordResponse,
    DailyNutritionSummaryResponse
)
from app.models.core.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.query_result_parser import QueryResultParser
from app.shared.decorators.error_handler import handle_errors

logger = get_logger(__name__)
router = APIRouter(prefix="/feeding", tags=["nutrition-feeding"])


@router.post("", response_model=FeedingRecordResponse)
async def record_feeding_no_slash(
    feeding_record: FeedingRecordCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Record feeding (without trailing slash)"""
    return await record_feeding_with_slash(feeding_record, current_user, supabase)

@router.post("/", response_model=FeedingRecordResponse)
@handle_errors("record_feeding")
async def record_feeding_with_slash(
    feeding_record: FeedingRecordCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Record a feeding event for a pet
    
    Args:
        feeding_record: Feeding record data
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Created feeding record
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(feeding_record.pet_id, current_user.id, supabase)
    
    # Verify food_analysis exists and belongs to the correct pet
    # If it doesn't exist, create a minimal food_analysis automatically
    query_builder = QueryBuilderService(supabase, "food_analyses")
    food_analysis_result = await query_builder.with_filters({
        "id": feeding_record.food_analysis_id,
        "pet_id": feeding_record.pet_id
    }).with_limit(1).execute()
    
    if not food_analysis_result.get("data"):
        # Food analysis doesn't exist - check if the ID is actually a food_item ID
        # This allows users to log feedings with any product without requiring
        # them to create a food analysis first
        logger.info(
            f"Food analysis {feeding_record.food_analysis_id} not found for pet {feeding_record.pet_id}. "
            f"Checking if it's a food_item ID and creating food analysis automatically."
        )
        
        # Check if this ID exists in food_items table
        food_item_query = QueryBuilderService(supabase, "food_items")
        food_item_result = await food_item_query.with_filters({
            "id": feeding_record.food_analysis_id
        }).with_limit(1).execute()
        
        food_name = "Manual Feeding Entry"
        brand = None
        calories_per_100g = 0.0
        protein_percentage = 0.0
        fat_percentage = 0.0
        fiber_percentage = 0.0
        moisture_percentage = 0.0
        ingredients = []
        allergens = []
        
        if food_item_result.get("data"):
            # Found a food_item - use its data to create a proper food_analysis
            food_item = food_item_result["data"][0]
            
            # Parse nutritional_info JSONB field using QueryResultParser
            parsed_item = QueryResultParser.parse_json_fields(
                food_item,
                ["nutritional_info"],
                defaults={"nutritional_info": {}}
            )
            
            # Extract food item basic info
            food_name = parsed_item.get("name", "Manual Feeding Entry")
            brand = parsed_item.get("brand")
            
            # Extract nutritional info from food_item if available
            nutritional_info = parsed_item.get("nutritional_info", {})
            if isinstance(nutritional_info, dict) and nutritional_info:
                # Extract all nutritional values, handling None values properly
                calories_per_100g = float(nutritional_info.get("calories_per_100g") or 0.0)
                protein_percentage = float(nutritional_info.get("protein_percentage") or 0.0)
                fat_percentage = float(nutritional_info.get("fat_percentage") or 0.0)
                fiber_percentage = float(nutritional_info.get("fiber_percentage") or 0.0)
                moisture_percentage = float(nutritional_info.get("moisture_percentage") or 0.0)
                
                # Extract arrays, ensuring they're lists
                ingredients = nutritional_info.get("ingredients", [])
                if not isinstance(ingredients, list):
                    ingredients = []
                
                allergens = nutritional_info.get("allergens", [])
                if not isinstance(allergens, list):
                    allergens = []
            else:
                # No nutritional info available - use defaults
                logger.warning(
                    f"Food item {feeding_record.food_analysis_id} has no nutritional_info. "
                    f"Using default values for food analysis."
                )
            
            logger.info(
                f"Found food_item {feeding_record.food_analysis_id} with name '{food_name}', "
                f"brand '{brand}', calories: {calories_per_100g} kcal/100g. "
                f"Creating food analysis with food item data."
            )
        else:
            logger.info(
                f"ID {feeding_record.food_analysis_id} not found in food_items. "
                f"Creating minimal food analysis with default values."
            )
        
        # Create food analysis with food_item data or defaults
        minimal_analysis_data = {
            "id": feeding_record.food_analysis_id,  # Use the provided ID
            "pet_id": feeding_record.pet_id,
            "food_name": food_name,
            "brand": brand,
            "calories_per_100g": calories_per_100g,
            "protein_percentage": protein_percentage,
            "fat_percentage": fat_percentage,
            "fiber_percentage": fiber_percentage,
            "moisture_percentage": moisture_percentage,
            "ingredients": ingredients,
            "allergens": allergens,
            "analyzed_at": DateTimeService.now()
        }
        
        # Insert the minimal food analysis
        db_service = DatabaseOperationService(supabase)
        try:
            await db_service.insert_with_timestamps(
                "food_analyses",
                minimal_analysis_data,
                include_created_at=True,
                include_updated_at=True
            )
            logger.info(
                f"Successfully created minimal food analysis {feeding_record.food_analysis_id} for pet {feeding_record.pet_id}"
            )
        except Exception as e:
            logger.error(
                f"Failed to create minimal food analysis {feeding_record.food_analysis_id}: {e}"
            )
            # If creation fails, still allow the feeding to proceed if the ID exists
            # (might be a race condition where it was created between checks)
            food_analysis_check = await query_builder.with_filters({
                "id": feeding_record.food_analysis_id
            }).with_limit(1).execute()
            
            if not food_analysis_check.get("data"):
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to create food analysis and analysis does not exist. Please try again."
                )
    
    # Create feeding record using data transformation service
    # Note: feeding_records table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    record_data = DataTransformationService.model_to_dict(feeding_record)
    record_data['id'] = IDGenerationService.generate_uuid()
    
    # Calculate calories before inserting (if food_analysis is available)
    # Fetch food_analysis to get nutritional data for calorie calculation
    food_analysis_id = feeding_record.food_analysis_id
    amount_grams = float(feeding_record.amount_grams)
    analysis_data = None
    
    if food_analysis_id:
        # Fetch food_analysis to get nutritional data
        food_analysis_query = QueryBuilderService(supabase, "food_analyses")
        analysis_result = await food_analysis_query.with_filters({
            "id": food_analysis_id,
            "pet_id": feeding_record.pet_id
        }).with_limit(1).execute()
        
        if analysis_result.get("data"):
            analysis_data = analysis_result["data"][0]
            
            # Calculate calories: (calories_per_100g / 100) * amount_grams
            calories_per_100g = analysis_data.get("calories_per_100g")
            if calories_per_100g is not None and amount_grams > 0:
                record_data["calories"] = (float(calories_per_100g) / 100.0) * amount_grams
    
    # Insert into database using centralized service
    # Note: feeding_records table only has created_at, not updated_at
    db_service = DatabaseOperationService(supabase)
    created_record = await db_service.insert_with_timestamps(
        "feeding_records", 
        record_data,
        include_created_at=True,
        include_updated_at=False  # feeding_records table doesn't have updated_at column
    )
    
    # Enrich response with food_analysis data (food_name, food_brand) for API response
    if analysis_data:
        created_record["food_name"] = analysis_data.get("food_name")
        created_record["food_brand"] = analysis_data.get("brand")
    
    # Update nutritional trends for this date
    # This aggregates feeding records and creates/updates the trend record
    try:
        from datetime import date as date_type
        feeding_date = feeding_record.feeding_time.date() if hasattr(feeding_record.feeding_time, 'date') else feeding_record.feeding_time
        if isinstance(feeding_date, str):
            from datetime import datetime
            feeding_date = datetime.fromisoformat(feeding_date.replace('Z', '+00:00')).date()
        
        supabase.rpc("update_nutritional_trends", {
            "pet_uuid": feeding_record.pet_id,
            "p_trend_date": feeding_date.isoformat()  # Updated parameter name to avoid ambiguity
        }).execute()
    except Exception as e:
        # Log error but don't fail the feeding record creation
        logger.warning(f"Failed to update nutritional trends: {e}")
    
    # Convert to response model
    return ResponseModelService.convert_to_model(created_record, FeedingRecordResponse)


# IMPORTANT: DELETE route must come BEFORE GET route to avoid route conflicts
# FastAPI matches routes in order, and both use /{id} pattern
# Using explicit path segment to avoid conflicts with GET /{pet_id}
@router.delete("/record/{feeding_record_id}", status_code=204)
@handle_errors("delete_feeding_record")
async def delete_feeding_record(
    feeding_record_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete a feeding record
    
    Args:
        feeding_record_id: Feeding record ID to delete
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        No content (204)
        
    Raises:
        HTTPException: If record not found or user not authorized
    """
    # Log immediately at function entry - this should always appear
    import sys
    print(f"[DELETE_FEEDING] ===== DELETE ENDPOINT CALLED =====", file=sys.stderr, flush=True)
    print(f"[DELETE_FEEDING] feeding_record_id: {feeding_record_id}", file=sys.stderr, flush=True)
    print(f"[DELETE_FEEDING] user_id: {current_user.id}", file=sys.stderr, flush=True)
    
    # Log the delete attempt with full context
    logger.info(
        f"[DELETE_FEEDING] Attempting to delete feeding record {feeding_record_id} "
        f"for user {current_user.id}"
    )
    
    # First, verify the session is set correctly and RLS is working
    try:
        session = supabase.auth.get_session()
        if session and hasattr(session, 'user') and session.user:
            session_user_id = session.user.id
            logger.info(
                f"[DELETE_FEEDING] Session verified. auth.uid() should be: {session_user_id}, "
                f"expected user_id: {current_user.id}"
            )
            if session_user_id != current_user.id:
                logger.warning(
                    f"[DELETE_FEEDING] Session user_id mismatch! Session: {session_user_id}, "
                    f"Expected: {current_user.id}. RLS may not work correctly."
                )
            
            # Test RLS by querying pets - this should work if RLS is functioning
            try:
                test_pets = await QueryBuilderService(supabase, "pets").with_limit(1).execute()
                logger.info(
                    f"[DELETE_FEEDING] RLS test query on pets table returned {len(test_pets.get('data', []))} records. "
                    f"This confirms RLS is working (or would return 0 if no pets)."
                )
            except Exception as rls_test_error:
                logger.error(
                    f"[DELETE_FEEDING] RLS test query failed: {rls_test_error}. "
                    f"This suggests RLS may not be working correctly."
                )
        else:
            logger.error(
                f"[DELETE_FEEDING] No session found! RLS will not work. "
                f"auth.uid() will be NULL."
            )
    except Exception as session_error:
        logger.error(
            f"[DELETE_FEEDING] Error checking session: {session_error}. "
            f"RLS may not work correctly."
        )
    
    # Try to get the feeding record to verify ownership
    # RLS will automatically filter to only records for pets owned by the user
    # We query first to get pet_id for logging, but if query fails, we'll try delete anyway
    query_builder = QueryBuilderService(supabase, "feeding_records")
    pet_id = None
    try:
        logger.debug(
            f"[DELETE_FEEDING] Querying feeding_records table for id={feeding_record_id}"
        )
        record_result = await query_builder.with_filters({
            "id": feeding_record_id
        }).with_limit(1).execute()
        
        logger.debug(
            f"[DELETE_FEEDING] Query result: data={record_result.get('data')}, "
            f"count={record_result.get('count', 0)}"
        )
        
        if record_result.get("data"):
            record_data = record_result["data"][0]
            pet_id = record_data.get("pet_id")
            feeding_time = record_data.get("feeding_time")
            logger.info(
                f"[DELETE_FEEDING] Found feeding record {feeding_record_id} for pet {pet_id} "
                f"(user: {current_user.id})"
            )
            
            # Verify pet ownership explicitly to help debug RLS issues
            from app.shared.services.pet_authorization import verify_pet_ownership
            try:
                await verify_pet_ownership(pet_id, current_user.id, supabase)
                logger.info(
                    f"[DELETE_FEEDING] Pet ownership verified for pet {pet_id}"
                )
            except Exception as ownership_error:
                logger.error(
                    f"[DELETE_FEEDING] Pet ownership verification failed: {ownership_error}"
                )
                raise HTTPException(
                    status_code=403,
                    detail="You don't have permission to delete this feeding record"
                )
        else:
            logger.warning(
                f"[DELETE_FEEDING] Feeding record {feeding_record_id} not found in query "
                f"for user {current_user.id}. Query returned empty data. "
                f"This could be due to: RLS filtering, record not existing, or record already deleted."
            )
            
            # If RLS is blocking, try to get pet_id using service role client
            # This is a workaround to verify ownership when RLS blocks the query
            try:
                from app.core.database import get_supabase_service_role_client
                service_client = get_supabase_service_role_client()
                service_query = QueryBuilderService(service_client, "feeding_records")
                service_result = await service_query.with_filters({
                    "id": feeding_record_id
                }).with_limit(1).execute()
                
                if service_result.get("data"):
                    record_data = service_result["data"][0]
                    pet_id = record_data.get("pet_id")
                    feeding_time = record_data.get("feeding_time")
                    logger.info(
                        f"[DELETE_FEEDING] Found record using service role. pet_id: {pet_id}"
                    )
                    
                    # Verify pet ownership explicitly
                    from app.shared.services.pet_authorization import verify_pet_ownership
                    await verify_pet_ownership(pet_id, current_user.id, supabase)
                    logger.info(
                        f"[DELETE_FEEDING] Pet ownership verified for pet {pet_id}. "
                        f"RLS was blocking query, but ownership is confirmed. Proceeding with delete."
                    )
                else:
                    logger.warning(
                        f"[DELETE_FEEDING] Record {feeding_record_id} not found even with service role. "
                        f"Record likely doesn't exist."
                    )
                    raise HTTPException(
                        status_code=404,
                        detail="Feeding record not found"
                    )
            except HTTPException:
                raise
            except Exception as service_error:
                logger.error(
                    f"[DELETE_FEEDING] Error using service role to verify record: {service_error}"
                )
                # Will attempt delete anyway - RLS will block if unauthorized
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.warning(
            f"[DELETE_FEEDING] Error querying feeding record {feeding_record_id}: {e}. "
            f"Will attempt delete anyway - RLS will block if unauthorized."
        )
    
    # Attempt to delete the feeding record
    # RLS will ensure only records for user's pets can be deleted
    # If RLS blocks it, the delete will return False or raise an error
    logger.info(
        f"Attempting to delete feeding record {feeding_record_id} "
        f"(user: {current_user.id}, pet: {pet_id or 'unknown'})"
    )
    
    db_service = DatabaseOperationService(supabase)
    
    try:
        deleted = await db_service.delete_record("feeding_records", feeding_record_id)
        
        if deleted:
            logger.info(
                f"Successfully deleted feeding record {feeding_record_id} "
                f"for pet {pet_id or 'unknown'} (user: {current_user.id})"
            )
            
            # Update nutritional trends for the date of the deleted record
            if pet_id and feeding_time:
                try:
                    from datetime import datetime, date as date_type
                    # Parse feeding_time to get the date
                    if isinstance(feeding_time, str):
                        feeding_date = datetime.fromisoformat(feeding_time.replace('Z', '+00:00')).date()
                    elif hasattr(feeding_time, 'date'):
                        feeding_date = feeding_time.date()
                    else:
                        feeding_date = feeding_time
                    
                    supabase.rpc("update_nutritional_trends", {
                        "pet_uuid": pet_id,
                        "p_trend_date": feeding_date.isoformat() if isinstance(feeding_date, date_type) else str(feeding_date)  # Updated parameter name to avoid ambiguity
                    }).execute()
                    logger.info(f"Updated nutritional trends for pet {pet_id} on {feeding_date}")
                except Exception as trend_error:
                    # Log error but don't fail the delete operation
                    logger.warning(f"Failed to update nutritional trends after delete: {trend_error}")
        else:
            # Delete returned False - record might not exist or RLS blocked it
            logger.warning(
                f"Delete operation returned False for feeding record {feeding_record_id}. "
                f"This could mean: record doesn't exist, RLS blocked it, or record was already deleted. "
                f"User: {current_user.id}, Pet: {pet_id or 'unknown'}"
            )
            raise HTTPException(
                status_code=404,
                detail="Feeding record not found or you don't have permission to delete it"
            )
            
    except HTTPException:
        # Re-raise HTTP exceptions (like 404)
        raise
    except Exception as delete_error:
        logger.error(
            f"Error during delete operation for feeding record {feeding_record_id}: {delete_error}",
            exc_info=True
        )
        # Check if it's a permission/RLS error
        error_str = str(delete_error).lower()
        if "permission" in error_str or "policy" in error_str or "rls" in error_str:
            raise HTTPException(
                status_code=403,
                detail="You don't have permission to delete this feeding record"
            )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete feeding record: {str(delete_error)}"
        )
    
    return None


@router.get("/{pet_id}", response_model=List[FeedingRecordResponse])
@handle_errors("get_feeding_records")
async def get_feeding_records(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get feeding records for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of feeding records for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get feeding records with joined food_analysis data
    # Note: feeding_records table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    # CRITICAL: Ensure calories column is included in the query
    query_builder = QueryBuilderService(supabase, "feeding_records")
    result = await query_builder.with_filters({"pet_id": pet_id})\
        .with_ordering("created_at", desc=True)\
        .execute()
    
    # Handle empty response
    records_data = handle_empty_response(result["data"])
    
    # CRITICAL: Debug - Log raw database values to verify calories column
    if records_data:
        for idx, record in enumerate(records_data[:3]):  # Log first 3 records
            raw_calories = record.get("calories")
            logger.info(
                f"[GET_FEEDING_RECORDS] 🔍 RAW DB Record {idx} - ID: {record.get('id')}, "
                f"calories (raw from DB): {raw_calories} (type: {type(raw_calories).__name__}), "
                f"amount_grams: {record.get('amount_grams')} (type: {type(record.get('amount_grams')).__name__}), "
                f"food_analysis_id: {record.get('food_analysis_id')}"
            )
    
    # Join food_analysis data for each feeding record
    # Get all unique food_analysis_ids
    food_analysis_ids = list(set([record.get("food_analysis_id") for record in records_data if record.get("food_analysis_id")]))
    
    # Fetch all food_analyses in one query
    food_analyses_map = {}
    if food_analysis_ids:
        food_analysis_query = QueryBuilderService(supabase, "food_analyses")
        # Query for all food_analyses for this pet (RLS will filter by pet_id)
        analysis_result = await food_analysis_query.with_filters({
            "pet_id": pet_id
        }).execute()
        
        # Create a map of food_analysis_id -> food_analysis data
        for analysis in analysis_result.get("data", []):
            food_analyses_map[analysis.get("id")] = analysis
    
    # Enrich records with food_analysis data
    enriched_records = []
    for record in records_data:
        food_analysis_id = record.get("food_analysis_id")
        amount_grams = record.get("amount_grams", 0)
        record_id = record.get("id", "unknown")
        
        # CRITICAL: Preserve calories from database if already set
        # The feeding_records table has a calories column that may already contain the correct value
        # This is important because food_analysis might have calories_per_100g = 0, but the database
        # feeding_records table may have the correct calculated calories stored
        # Handle both string and numeric types (Supabase may return DECIMAL as string)
        raw_calories = record.get("calories")
        existing_calories = None
        if raw_calories is not None:
            if isinstance(raw_calories, str):
                try:
                    existing_calories = float(raw_calories)
                    logger.debug(
                        f"[GET_FEEDING_RECORDS] Converted calories string '{raw_calories}' to float {existing_calories} for record {record_id}"
                    )
                except (ValueError, TypeError):
                    logger.warning(
                        f"[GET_FEEDING_RECORDS] Failed to convert calories string '{raw_calories}' to float for record {record_id}"
                    )
            elif isinstance(raw_calories, (int, float)):
                existing_calories = float(raw_calories)
            else:
                logger.warning(
                    f"[GET_FEEDING_RECORDS] Unexpected calories type {type(raw_calories)} for record {record_id}: {raw_calories}"
                )
        
        # Log what we're starting with
        logger.debug(
            f"[GET_FEEDING_RECORDS] Processing record {record_id}: "
            f"existing_calories={existing_calories}, food_analysis_id={food_analysis_id}, amount_grams={amount_grams}"
        )
        
        if food_analysis_id and food_analysis_id in food_analyses_map:
            analysis = food_analyses_map[food_analysis_id]
            record["food_name"] = analysis.get("food_name")
            record["food_brand"] = analysis.get("brand")
            
            # CRITICAL: Only calculate calories if database doesn't have a valid value (> 0)
            # Always preserve database calories if they exist - don't overwrite with calculated value
            if existing_calories is None or existing_calories == 0:
                # Calculate calories: (calories_per_100g / 100) * amount_grams
                calories_per_100g = analysis.get("calories_per_100g")
                if calories_per_100g is not None and calories_per_100g > 0 and amount_grams > 0:
                    calculated_calories = (float(calories_per_100g) / 100.0) * float(amount_grams)
                    record["calories"] = calculated_calories
                    logger.info(
                        f"[GET_FEEDING_RECORDS] Calculated calories for record {record_id}: "
                        f"{calculated_calories} (from food_analysis {food_analysis_id}, "
                        f"calories_per_100g={calories_per_100g}, amount={amount_grams}g)"
                    )
                else:
                    # Keep existing value (None or 0) - don't overwrite with None
                    # This preserves the database value even if food_analysis has no calories data
                    logger.debug(
                        f"[GET_FEEDING_RECORDS] Keeping existing calories for record {record_id}: "
                        f"{existing_calories} (food_analysis calories_per_100g={calories_per_100g}, cannot calculate)"
                    )
            else:
                # Database already has calories - ALWAYS use that value, don't recalculate
                logger.info(
                    f"[GET_FEEDING_RECORDS] ✅ Using database calories for record {record_id}: {existing_calories} "
                    f"(NOT recalculating from food_analysis)"
                )
                # Explicitly set it to ensure it's included in response
                record["calories"] = existing_calories
        else:
            # No food_analysis found - preserve database calories if they exist
            if existing_calories is not None and existing_calories > 0:
                logger.info(
                    f"[GET_FEEDING_RECORDS] ✅ No food_analysis found for record {record_id}, "
                    f"but using database calories: {existing_calories}"
                )
                record["calories"] = existing_calories
            else:
                logger.debug(
                    f"[GET_FEEDING_RECORDS] No food_analysis found for record {record_id}, "
                    f"and no database calories (value: {existing_calories})"
                )
        
        # Log final calories value being returned
        final_calories = record.get("calories")
        logger.info(
            f"[GET_FEEDING_RECORDS] ✅ Final calories for record {record_id}: {final_calories} "
            f"(type: {type(final_calories).__name__})"
        )
        
        # CRITICAL: Ensure calories is always in the record dict (even if None)
        # This ensures the response model includes the calories field
        if "calories" not in record:
            record["calories"] = None
            logger.warning(
                f"[GET_FEEDING_RECORDS] ⚠️ Calories key missing from record {record_id}, setting to None"
            )
        
        enriched_records.append(record)
    
    # Convert to response models
    return ResponseModelService.convert_list_to_models(enriched_records, FeedingRecordResponse)


@router.get("/summaries/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
@handle_errors("get_daily_summaries")
async def get_daily_summaries(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get daily nutrition summaries for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of daily nutrition summaries
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get daily summaries (this would contain the actual summary logic)
    summaries = []  # Placeholder for actual summary generation
    
    return summaries


@router.get("/daily-summary/{pet_id}", response_model=Optional[DailyNutritionSummaryResponse])
@handle_errors("get_daily_summary")
async def get_daily_summary(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get today's nutrition summary for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Today's nutrition summary
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get today's summary (this would contain the actual summary logic)
    summary = None  # Placeholder for actual summary generation
    
    return summary
