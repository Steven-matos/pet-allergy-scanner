"""
Scan management and analysis router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from typing import List, Dict
from app.models.scan import ScanCreate, ScanResponse, ScanUpdate, ScanAnalysisRequest, ScanResult, ScanStatus, ScanMethod
from app.models.ingredient import IngredientAnalysis
from app.core.security.jwt_handler import get_current_user
from app.routers.ingredients import analyze_ingredients
from app.database import get_supabase_client
from app.services.storage_service import StorageService
from supabase import Client
from app.utils.logging_config import get_logger
import re
import base64

router = APIRouter()
logger = get_logger(__name__)

@router.post("/", response_model=ScanResponse)
async def create_scan(
    scan_data: ScanCreate,
    current_user: dict = Depends(get_current_user)
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
            "status": scan_data.status.value,
            "scan_method": scan_data.scan_method.value
        }
        
        response = supabase.table("scans").insert(scan_record).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create scan record"
            )
        
        scan = response.data[0]
        return ScanResponse(
            id=scan["id"],
            user_id=scan["user_id"],
            pet_id=scan["pet_id"],
            image_url=scan["image_url"],
            raw_text=scan["raw_text"],
            status=ScanStatus(scan["status"]),
            result=ScanResult(**scan["result"]) if scan["result"] else None,
            created_at=scan["created_at"],
            updated_at=scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Create scan error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create scan record"
        )

@router.post("/analyze", response_model=ScanResponse)
async def analyze_scan(
    analysis_request: ScanAnalysisRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Analyze extracted text from a scan
    
    Processes extracted text and performs ingredient analysis.
    For OCR and hybrid scans, uploads the image to storage.
    For barcode scans, no image is saved.
    """
    try:
        supabase = get_supabase_client()
        
        # Get pet information
        pet_response = supabase.table("pets").select("*").eq("id", analysis_request.pet_id).eq("user_id", current_user.id).execute()
        
        if not pet_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet profile not found"
            )
        
        pet = pet_response.data[0]
        
        # Handle image upload for OCR and hybrid scans only
        image_url = None
        if analysis_request.scan_method in [ScanMethod.OCR, ScanMethod.HYBRID]:
            if analysis_request.image_data:
                try:
                    # Decode base64 image
                    image_bytes = base64.b64decode(analysis_request.image_data)
                    
                    # Create a temporary scan record to get scan_id
                    temp_scan = {
                        "user_id": current_user.id,
                        "pet_id": analysis_request.pet_id,
                        "status": ScanStatus.PROCESSING.value,
                        "scan_method": analysis_request.scan_method.value
                    }
                    temp_response = supabase.table("scans").insert(temp_scan).execute()
                    
                    if not temp_response.data:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Failed to create scan record"
                        )
                    
                    scan_id = temp_response.data[0]["id"]
                    
                    # Upload image to storage
                    image_url = await StorageService.upload_scan_image(
                        image_data=image_bytes,
                        user_id=current_user.id,
                        scan_id=scan_id,
                        optimize=True
                    )
                    
                    logger.info(f"Scan image uploaded for OCR scan: {scan_id}")
                    
                except Exception as e:
                    logger.error(f"Failed to upload scan image: {e}")
                    # Continue without image - don't fail the entire scan
        
        pet = pet_response.data[0]
        
        # Sanitize and extract ingredients from text
        from app.core.validation.input_validator import InputValidator
        sanitized_text = InputValidator.sanitize_text(analysis_request.extracted_text, max_length=10000)
        ingredients = extract_ingredients_from_text(sanitized_text)
        
        # Analyze ingredients
        ingredient_analyses = await analyze_ingredients(
            ingredients=ingredients,
            pet_species=pet["species"],
            pet_sensitivities=pet["known_sensitivities"],
            current_user=current_user
        )
        
        # Determine overall safety
        unsafe_ingredients = [analysis.ingredient_name for analysis in ingredient_analyses if analysis.is_unsafe_for_pet]
        safe_ingredients = [analysis.ingredient_name for analysis in ingredient_analyses if not analysis.is_unsafe_for_pet]
        
        if unsafe_ingredients:
            overall_safety = "unsafe"
        elif any(analysis.safety_level == "caution" for analysis in ingredient_analyses):
            overall_safety = "caution"
        else:
            overall_safety = "safe"
        
        # Calculate confidence score
        confidence_score = calculate_confidence_score(ingredient_analyses, ingredients)
        
        # Create scan result
        scan_result = ScanResult(
            product_name=analysis_request.product_name,
            ingredients_found=ingredients,
            unsafe_ingredients=unsafe_ingredients,
            safe_ingredients=safe_ingredients,
            overall_safety=overall_safety,
            confidence_score=confidence_score,
            analysis_details={
                "total_ingredients": len(ingredients),
                "unsafe_count": len(unsafe_ingredients),
                "safe_count": len(safe_ingredients),
                "analysis_timestamp": str(pet["updated_at"])
            }
        )
        
        # Update or create scan record
        scan_data = {
            "status": ScanStatus.COMPLETED.value,
            "result": scan_result.dict(),
            "raw_text": analysis_request.extracted_text,
            "scan_method": analysis_request.scan_method.value
        }
        
        # Add image_url if it was uploaded
        if image_url:
            scan_data["image_url"] = image_url
        
        # If we created a temp scan earlier, update it
        if image_url and 'scan_id' in locals():
            response = supabase.table("scans").update(scan_data).eq("id", scan_id).execute()
        else:
            # Create new scan record (for barcode scans without image)
            scan_data["user_id"] = current_user.id
            scan_data["pet_id"] = analysis_request.pet_id
            response = supabase.table("scans").insert(scan_data).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to update scan record"
            )
        
        scan = response.data[0]
        return ScanResponse(
            id=scan["id"],
            user_id=scan["user_id"],
            pet_id=scan["pet_id"],
            image_url=scan["image_url"],
            raw_text=scan["raw_text"],
            status=ScanStatus(scan["status"]),
            result=ScanResult(**scan["result"]) if scan["result"] else None,
            created_at=scan["created_at"],
            updated_at=scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analyze scan error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to analyze scan"
        )

@router.get("/", response_model=List[ScanResponse])
async def get_user_scans(
    pet_id: str = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Get scans for the current user
    
    Returns a list of scans for the authenticated user, optionally filtered by pet
    """
    try:
        supabase = get_supabase_client()
        
        query = supabase.table("scans").select("*").eq("user_id", current_user.id)
        
        if pet_id:
            query = query.eq("pet_id", pet_id)
        
        response = query.order("created_at", desc=True).execute()
        
        scans = []
        for scan in response.data:
            scans.append(ScanResponse(
                id=scan["id"],
                user_id=scan["user_id"],
                pet_id=scan["pet_id"],
                image_url=scan["image_url"],
                raw_text=scan["raw_text"],
                status=ScanStatus(scan["status"]),
                result=ScanResult(**scan["result"]) if scan["result"] else None,
                created_at=scan["created_at"],
                updated_at=scan["updated_at"]
            ))
        
        return scans
        
    except Exception as e:
        logger.error(f"Get scans error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve scans"
        )

@router.get("/{scan_id}", response_model=ScanResponse)
async def get_scan(
    scan_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Get a specific scan
    
    Returns detailed information for a specific scan
    """
    try:
        supabase = get_supabase_client()
        
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
            result=ScanResult(**scan["result"]) if scan["result"] else None,
            created_at=scan["created_at"],
            updated_at=scan["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get scan error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve scan"
        )

def extract_ingredients_from_text(text: str) -> List[str]:
    """
    Extract ingredient names from scanned text
    
    Uses regex patterns to identify ingredient names in the text
    """
    if not text:
        return []
    
    # Common ingredient patterns
    patterns = [
        r'\b(?:chicken|beef|fish|lamb|turkey|duck|venison|salmon|tuna)\b',
        r'\b(?:corn|wheat|soy|rice|oats|quinoa|barley)\b',
        r'\b(?:sweet potato|potato|carrot|peas|beans|lentils)\b',
        r'\b(?:chocolate|grapes|raisins|onions|garlic|avocado)\b',
        r'\b(?:xylitol|sorbitol|mannitol|erythritol)\b',
        r'\b(?:salt|sugar|honey|molasses)\b',
        r'\b(?:preservatives|artificial colors|artificial flavors)\b',
        r'\b(?:vitamin [a-z]|mineral [a-z]|calcium|phosphorus)\b',
        r'\b(?:chicken meal|beef meal|fish meal|lamb meal)\b',
        r'\b(?:chicken by-product|beef by-product|fish by-product)\b'
    ]
    
    ingredients = set()
    text_lower = text.lower()
    
    for pattern in patterns:
        matches = re.findall(pattern, text_lower)
        ingredients.update(matches)
    
    # Also look for comma-separated lists
    if ',' in text:
        potential_ingredients = [ingredient.strip() for ingredient in text.split(',')]
        ingredients.update(potential_ingredients)
    
    return list(ingredients)

def calculate_confidence_score(analyses: List[IngredientAnalysis], total_ingredients: List[str]) -> float:
    """
    Calculate confidence score for the analysis
    
    Returns a score between 0.0 and 1.0 indicating analysis confidence
    """
    if not total_ingredients:
        return 0.0
    
    # Base confidence on ingredient recognition
    recognized_ingredients = len(analyses)
    recognition_rate = recognized_ingredients / len(total_ingredients)
    
    # Adjust based on analysis quality
    quality_score = 1.0
    for analysis in analyses:
        if analysis.safety_level == "unknown":
            quality_score -= 0.1
    
    return min(1.0, max(0.0, recognition_rate * quality_score))
