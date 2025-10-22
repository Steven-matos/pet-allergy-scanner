"""
Scan management and analysis router
"""

from fastapi import APIRouter, HTTPException, Depends, status
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
async def create_scan_with_slash(
    scan_data: ScanCreate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create a new scan record
    
    Creates a new scan record for processing ingredient analysis
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet belongs to user
        pet_response = supabase.table("pets").select("*").eq("id", scan_data.pet_id).eq("user_id", current_user.id).execute()
        
        if not pet_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet profile not found"
            )
        
        # Create scan record
        scan_record = {
            "user_id": current_user.id,
            "pet_id": scan_data.pet_id,
            "image_url": scan_data.image_url,
            "raw_text": scan_data.raw_text,
            "status": scan_data.status.value
        }
        
        # Insert scan into database
        response = supabase.table("scans").insert(scan_record).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create scan record"
            )
        
        created_scan = response.data[0]
        
        return ScanResponse(
            id=created_scan["id"],
            user_id=created_scan["user_id"],
            pet_id=created_scan["pet_id"],
            image_url=created_scan["image_url"],
            raw_text=created_scan["raw_text"],
            status=ScanStatus(created_scan["status"]),
            scan_method=ScanMethod.OCR,  # Default to OCR since method field doesn't exist in DB
            result=created_scan.get("result"),
            created_at=created_scan["created_at"],
            updated_at=created_scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating scan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error creating scan"
        )

@router.get("/", response_model=List[ScanResponse])
async def get_user_scans(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get all scans for the current user
    
    Returns a list of all scan records belonging to the authenticated user
    """
    try:
        supabase = get_supabase_client()
        
        # Get scans for the current user
        response = supabase.table("scans").select("*").eq("user_id", current_user.id).order("created_at", desc=True).execute()
        
        if not response.data:
            return []
        
        scans = []
        for scan in response.data:
            scans.append(ScanResponse(
                id=scan["id"],
                user_id=scan["user_id"],
                pet_id=scan["pet_id"],
                image_url=scan["image_url"],
                raw_text=scan["raw_text"],
                status=ScanStatus(scan["status"]),
                scan_method=ScanMethod.OCR,  # Default to OCR since method field doesn't exist in DB
                result=scan.get("result"),
                created_at=scan["created_at"],
                updated_at=scan["updated_at"]
            ))
        
        return scans
        
    except Exception as e:
        logger.error(f"Error fetching scans: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching scans"
        )

@router.get("/{scan_id}", response_model=ScanResponse)
async def get_scan(
    scan_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get a specific scan by ID
    
    Returns the scan record if it belongs to the authenticated user
    """
    try:
        supabase = get_supabase_client()
        
        # Get scan by ID and verify ownership
        response = supabase.table("scans").select("*").eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Scan not found"
            )
        
        scan = response.data[0]
        
        return ScanResponse(
            id=scan["id"],
            user_id=scan["user_id"],
            pet_id=scan["pet_id"],
            image_url=scan["image_url"],
            raw_text=scan["raw_text"],
            status=ScanStatus(scan["status"]),
            scan_method=ScanMethod.OCR,  # Default to OCR since method field doesn't exist in DB
            result=scan.get("result"),
            created_at=scan["created_at"],
            updated_at=scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching scan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching scan"
        )

@router.put("/{scan_id}", response_model=ScanResponse)
async def update_scan(
    scan_id: str,
    scan_update: ScanUpdate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update a scan record
    
    Updates the scan record if it belongs to the authenticated user
    """
    try:
        supabase = get_supabase_client()
        
        # Verify scan exists and belongs to user
        existing_response = supabase.table("scans").select("id").eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        if not existing_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Scan not found"
            )
        
        # Prepare update data
        update_data = scan_update.dict(exclude_unset=True)
        
        # Update scan
        response = supabase.table("scans").update(update_data).eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update scan record"
            )
        
        updated_scan = response.data[0]
        
        return ScanResponse(
            id=updated_scan["id"],
            user_id=updated_scan["user_id"],
            pet_id=updated_scan["pet_id"],
            image_url=updated_scan["image_url"],
            raw_text=updated_scan["raw_text"],
            status=ScanStatus(updated_scan["status"]),
            scan_method=ScanMethod(updated_scan.get("method", "ocr")),
            result=updated_scan.get("result"),
            created_at=updated_scan["created_at"],
            updated_at=updated_scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating scan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error updating scan"
        )

@router.delete("/{scan_id}")
async def delete_scan(
    scan_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a scan record
    
    Deletes the scan record if it belongs to the authenticated user
    """
    try:
        supabase = get_supabase_client()
        
        # Verify scan exists and belongs to user
        existing_response = supabase.table("scans").select("id").eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        if not existing_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Scan not found"
            )
        
        # Delete scan
        response = supabase.table("scans").delete().eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        return {"message": "Scan record deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting scan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error deleting scan"
        )

@router.post("/{scan_id}/analyze", response_model=ScanResult)
async def analyze_scan(
    scan_id: str,
    analysis_request: ScanAnalysisRequest,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze a scan for ingredients and potential issues
    
    Performs ingredient analysis on the scan data and returns results
    """
    try:
        supabase = get_supabase_client()
        
        # Get scan and verify ownership
        scan_response = supabase.table("scans").select("*").eq("id", scan_id).eq("user_id", current_user.id).execute()
        
        if not scan_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Scan not found"
            )
        
        scan = scan_response.data[0]
        
        # Get pet information
        pet_response = supabase.table("pets").select("*").eq("id", scan["pet_id"]).eq("user_id", current_user.id).execute()
        
        if not pet_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        pet = pet_response.data[0]
        
        # Perform ingredient analysis
        analysis_result = await analyze_ingredients(
            scan["raw_text"],
            pet.get("known_sensitivities", []),
            []  # No dietary_restrictions field in database
        )
        
        # Convert IngredientAnalysis to ScanResult
        scan_result = ScanResult(
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
        
        # Update scan with analysis results
        update_data = {
            "status": ScanStatus.COMPLETED.value,
            "confidence_score": analysis_result.confidence_score,
            "notes": f"Analysis completed with {len(analysis_result.ingredients)} ingredients found"
        }
        
        supabase.table("scans").update(update_data).eq("id", scan_id).execute()
        
        return scan_result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error analyzing scan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error analyzing scan"
        )
