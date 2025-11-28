"""
Scan management and analysis router
"""

from fastapi import APIRouter, HTTPException, Depends, status, Query
from typing import List, Dict
from app.models.scan import ScanCreate, ScanResponse, ScanUpdate, ScanAnalysisRequest, ScanResult, ScanStatus, ScanMethod
from app.models.ingredient import IngredientAnalysis
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
from app.api.v1.ingredients.router import analyze_ingredients
from app.database import get_supabase_client
from app.services.storage_service import StorageService
from supabase import Client
from app.utils.logging_config import get_logger
from app.shared.services.pet_authorization import verify_pet_ownership

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.decorators.error_handler import handle_errors

import re
import base64

router = APIRouter()
logger = get_logger(__name__)

@router.post("", response_model=ScanResponse)
async def create_scan_no_slash(
    scan_data: ScanCreate,
    current_user: UserResponse = Depends(get_current_user)
):
    """Create scan (without trailing slash)"""
    return await create_scan_with_slash(scan_data, current_user)

@router.post("/", response_model=ScanResponse)
@handle_errors("create_scan")
async def create_scan_with_slash(
    scan_data: ScanCreate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create a new scan record
    
    Creates a new scan record for processing ingredient analysis
    """
    supabase = get_supabase_client()
    
    # Verify pet ownership using centralized service
    await verify_pet_ownership(scan_data.pet_id, current_user.id, supabase)
    
    # Create scan record
    scan_record = {
        "user_id": current_user.id,
        "pet_id": scan_data.pet_id,
        "image_url": scan_data.image_url,
        "raw_text": scan_data.raw_text,
        "status": scan_data.status.value
    }
    
    # Insert scan into database using centralized service
    db_service = DatabaseOperationService(supabase)
    created_scan = await db_service.insert_with_timestamps("scans", scan_record)
    
    # Convert to response model - need to handle enum conversions
    scan_dict = created_scan.copy()
    scan_dict["status"] = ScanStatus(scan_dict["status"])
    scan_dict["scan_method"] = ScanMethod.OCR  # Default to OCR since method field doesn't exist in DB
    
    return ResponseModelService.convert_to_model(scan_dict, ScanResponse)

@router.get("/", response_model=List[ScanResponse])
@handle_errors("get_user_scans")
async def get_user_scans(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get all scans for the current user
    
    Returns a list of all scan records belonging to the authenticated user
    """
    supabase = get_supabase_client()
    
    # Get scans for the current user using query builder
    query_builder = QueryBuilderService(supabase, "scans")
    result = await query_builder.with_filters({"user_id": current_user.id})\
        .with_ordering("created_at", desc=True)\
        .execute()
    
    # Handle empty response
    scans_data = handle_empty_response(result["data"])
    
    # Convert enum fields before model conversion
    for scan in scans_data:
        scan["status"] = ScanStatus(scan["status"])
        scan["scan_method"] = ScanMethod.OCR  # Default to OCR since method field doesn't exist in DB
    
    # Convert to response models
    return ResponseModelService.convert_list_to_models(scans_data, ScanResponse)

@router.get("/mobile", response_model=List[dict])
@handle_errors("get_user_scans_mobile")
async def get_user_scans_mobile(
    current_user: UserResponse = Depends(get_current_user),
    limit: int = Query(20, ge=1, le=50, description="Maximum results (mobile optimized)")
):
    """
    Mobile-optimized endpoint to get scans with minimal fields.
    
    Returns only essential fields (id, pet_id, status, created_at, image_url)
    for faster loading on mobile devices with limited bandwidth.
    """
    supabase = get_supabase_client()
    
    # Select only essential fields for mobile
    query_builder = QueryBuilderService(
        supabase, 
        "scans",
        default_columns=["id", "pet_id", "status", "created_at", "image_url"]
    )
    result = await query_builder.with_filters({"user_id": current_user.id})\
        .with_ordering("created_at", desc=True)\
        .with_limit(limit)\
        .execute()
    
    # Handle empty response
    scans_data = handle_empty_response(result["data"])
    
    # Convert status enum
    for scan in scans_data:
        scan["status"] = ScanStatus(scan["status"]).value if scan.get("status") else "pending"
    
    return scans_data

@router.get("/{scan_id}", response_model=ScanResponse)
@handle_errors("get_scan")
async def get_scan(
    scan_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get a specific scan by ID
    
    Returns the scan record if it belongs to the authenticated user
    """
    supabase = get_supabase_client()
    
    # Get scan by ID and verify ownership using query builder
    query_builder = QueryBuilderService(supabase, "scans")
    result = await query_builder.with_filters({
        "id": scan_id,
        "user_id": current_user.id
    }).execute()
    
    if not result["data"]:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("scan not found", context="scan", action="not_found")
        )
    
    # Convert enum fields before model conversion
    scan = result["data"][0]
    scan["status"] = ScanStatus(scan["status"])
    scan["scan_method"] = ScanMethod.OCR  # Default to OCR since method field doesn't exist in DB
    
    return ResponseModelService.convert_to_model(scan, ScanResponse)

@router.put("/{scan_id}", response_model=ScanResponse)
@handle_errors("update_scan")
async def update_scan(
    scan_id: str,
    scan_update: ScanUpdate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update a scan record
    
    Updates the scan record if it belongs to the authenticated user
    """
    supabase = get_supabase_client()
    
    # Verify scan exists and belongs to user using query builder
    query_builder = QueryBuilderService(supabase, "scans")
    existing_result = await query_builder.select(["id"]).with_filters({
        "id": scan_id,
        "user_id": current_user.id
    }).execute()
    
    if not existing_result["data"]:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("scan not found", context="scan", action="not_found")
        )
    
    # Prepare update data using data transformation service
    update_data = DataTransformationService.model_to_dict(scan_update, exclude_none=True)
    
    # Handle enum serialization
    if "status" in update_data and hasattr(update_data["status"], "value"):
        update_data["status"] = update_data["status"].value
    if "scan_method" in update_data and hasattr(update_data["scan_method"], "value"):
        update_data["scan_method"] = update_data["scan_method"].value
    
    # Update scan using centralized service
    db_service = DatabaseOperationService(supabase)
    updated_scan = await db_service.update_with_timestamp("scans", scan_id, update_data)
    
    # Convert enum fields before model conversion
    updated_scan["status"] = ScanStatus(updated_scan["status"])
    updated_scan["scan_method"] = ScanMethod(updated_scan.get("method", "ocr"))
    
    return ResponseModelService.convert_to_model(updated_scan, ScanResponse)

@router.delete("/{scan_id}")
@handle_errors("delete_scan")
async def delete_scan(
    scan_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a scan record
    
    Deletes the scan record if it belongs to the authenticated user
    """
    supabase = get_supabase_client()
    
    # Verify scan exists and belongs to user using query builder
    query_builder = QueryBuilderService(supabase, "scans")
    existing_result = await query_builder.select(["id"]).with_filters({
        "id": scan_id,
        "user_id": current_user.id
    }).execute()
    
    if not existing_result["data"]:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("scan not found", context="scan", action="not_found")
        )
    
    # Delete scan using centralized service
    db_service = DatabaseOperationService(supabase)
    await db_service.delete_record("scans", scan_id)
    
    return {"message": "Scan record deleted successfully"}

@router.post("/{scan_id}/analyze", response_model=ScanResponse)
@handle_errors("analyze_scan")
async def analyze_scan(
    scan_id: str,
    analysis_request: ScanAnalysisRequest,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze a scan for ingredients and potential issues
    
    Performs ingredient analysis on the scan data and returns the updated scan
    """
    supabase = get_supabase_client()
    
    # Get scan and verify ownership using query builder
    query_builder = QueryBuilderService(supabase, "scans")
    scan_result = await query_builder.with_filters({
        "id": scan_id,
        "user_id": current_user.id
    }).execute()
    
    if not scan_result["data"]:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("scan not found", context="scan", action="not_found")
        )
    
    scan = scan_result["data"][0]
    
    # Verify pet ownership using centralized service
    pet = await verify_pet_ownership(scan["pet_id"], current_user.id, supabase)
    
    # Perform ingredient analysis
    analysis_result = await analyze_ingredients(
        scan["raw_text"],
        pet.get("known_sensitivities", []),
        []  # No dietary_restrictions field in database
    )
    
    # Convert IngredientAnalysis to ScanResult
    scan_result_obj = ScanResult(
        product_name=analysis_request.product_name,
        brand=None,  # Not available from barcode scan
        ingredients_found=[ing.name for ing in analysis_result.ingredients],
        unsafe_ingredients=analysis_result.dangerous_ingredients,
        safe_ingredients=analysis_result.safe_ingredients,
        overall_safety=analysis_result.overall_safety,
        confidence_score=analysis_result.confidence_score,
        analysis_details={
            "caution_ingredients": ", ".join(analysis_result.caution_ingredients),
            "unknown_ingredients": ", ".join(analysis_result.unknown_ingredients),
            "allergy_warnings": ", ".join(analysis_result.allergy_warnings),
            "recommendations": "; ".join(analysis_result.recommendations),
            "analysis_type": "server_analysis"
        }
    )
    
    # Update scan with analysis results using data transformation service
    update_data = {
        "status": ScanStatus.COMPLETED.value,
        "confidence_score": analysis_result.confidence_score,
        "notes": f"Analysis completed with {len(analysis_result.ingredients)} ingredients found",
        "result": DataTransformationService.model_to_dict(scan_result_obj)  # Store the result in the scan record
    }
    
    # Update scan with analysis results using centralized service
    db_service = DatabaseOperationService(supabase)
    updated_scan = await db_service.update_with_timestamp("scans", scan_id, update_data)
    
    # Convert enum fields and use scan_result_obj for result
    updated_scan["status"] = ScanStatus(updated_scan["status"])
    updated_scan["scan_method"] = ScanMethod(updated_scan.get("method", "ocr"))
    updated_scan["result"] = scan_result_obj
    
    return ResponseModelService.convert_to_model(updated_scan, ScanResponse)
