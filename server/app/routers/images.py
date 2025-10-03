"""
Image optimization and upload endpoints
"""

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import Response
from typing import Optional
from app.utils.logging_config import get_logger

from ..services.image_optimizer import ImageOptimizerService
from ..middleware.security import get_current_user

logger = get_logger(__name__)

router = APIRouter(prefix="/images", tags=["images"])

@router.post("/optimize")
async def optimize_image(
    file: UploadFile = File(...),
    target_size: Optional[int] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Optimize an uploaded image with compression and resizing
    
    Args:
        file: Image file to optimize
        target_size: Optional target file size in bytes
        
    Returns:
        Optimized image data and metadata
        
    Example:
        POST /api/v1/images/optimize
        Content-Type: multipart/form-data
        
        Response:
        {
            "success": true,
            "metadata": {
                "original_size": 5242880,
                "optimized_size": 1048576,
                "compression_ratio": 0.2,
                "size_reduction_percent": 80.0,
                "original_dimensions": {"width": 4000, "height": 3000},
                "optimized_dimensions": {"width": 1024, "height": 768},
                "final_quality": 75,
                "optimization_attempts": 3
            }
        }
    """
    try:
        # Validate file type
        if not file.content_type or not file.content_type.startswith('image/'):
            raise HTTPException(
                status_code=400,
                detail="File must be an image (JPEG, PNG, WebP)"
            )
        
        # Read image data
        image_data = await file.read()
        
        # Validate image
        if not ImageOptimizerService.validate_image(image_data):
            raise HTTPException(
                status_code=400,
                detail="Invalid image file"
            )
        
        # Optimize image
        try:
            optimized_data, metadata = ImageOptimizerService.optimize_image(
                image_data,
                target_size=target_size or ImageOptimizerService.TARGET_FILE_SIZE
            )
        except ValueError as e:
            raise HTTPException(
                status_code=413,
                detail=str(e)
            )
        
        # Return optimized image with metadata
        return Response(
            content=optimized_data,
            media_type="image/jpeg",
            headers={
                "X-Original-Size": str(metadata["original_size"]),
                "X-Optimized-Size": str(metadata["optimized_size"]),
                "X-Compression-Ratio": str(metadata["compression_ratio"]),
                "X-Size-Reduction": str(metadata["size_reduction_percent"]),
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Image optimization failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Image optimization failed"
        )

@router.post("/thumbnail")
async def create_thumbnail(
    file: UploadFile = File(...),
    size: int = 200,
    current_user: dict = Depends(get_current_user)
):
    """
    Create a square thumbnail from an image
    
    Args:
        file: Image file to create thumbnail from
        size: Thumbnail size in pixels (default: 200)
        
    Returns:
        Thumbnail image
        
    Example:
        POST /api/v1/images/thumbnail?size=300
        Content-Type: multipart/form-data
    """
    try:
        # Validate file type
        if not file.content_type or not file.content_type.startswith('image/'):
            raise HTTPException(
                status_code=400,
                detail="File must be an image"
            )
        
        # Validate size
        if size < 50 or size > 1000:
            raise HTTPException(
                status_code=400,
                detail="Size must be between 50 and 1000 pixels"
            )
        
        # Read image data
        image_data = await file.read()
        
        # Validate image
        if not ImageOptimizerService.validate_image(image_data):
            raise HTTPException(
                status_code=400,
                detail="Invalid image file"
            )
        
        # Create thumbnail
        thumbnail_data = ImageOptimizerService.create_thumbnail(image_data, size)
        
        return Response(
            content=thumbnail_data,
            media_type="image/jpeg"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Thumbnail creation failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Thumbnail creation failed"
        )

@router.post("/validate")
async def validate_image(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """
    Validate an image file and return information
    
    Args:
        file: Image file to validate
        
    Returns:
        Image information and validation status
        
    Example:
        POST /api/v1/images/validate
        Content-Type: multipart/form-data
        
        Response:
        {
            "valid": true,
            "info": {
                "format": "JPEG",
                "mode": "RGB",
                "size": [4000, 3000],
                "width": 4000,
                "height": 3000,
                "file_size": 5242880
            }
        }
    """
    try:
        # Read image data
        image_data = await file.read()
        
        # Validate and get info
        is_valid = ImageOptimizerService.validate_image(image_data)
        
        if not is_valid:
            return {
                "valid": False,
                "error": "Invalid image file"
            }
        
        # Get image info
        info = ImageOptimizerService.get_image_info(image_data)
        
        return {
            "valid": True,
            "info": info
        }
        
    except Exception as e:
        logger.error(f"Image validation failed: {str(e)}")
        return {
            "valid": False,
            "error": str(e)
        }

