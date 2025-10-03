"""
Server-side image optimization service
Handles image compression, resizing, and format conversion
"""

from PIL import Image
from io import BytesIO
from typing import Tuple, Optional
from app.utils.logging_config import get_logger

logger = get_logger(__name__)

class ImageOptimizerService:
    """Service for optimizing images on the server side"""
    
    # Maximum file size in bytes (5MB)
    MAX_FILE_SIZE = 5_242_880
    
    # Target file size for optimal storage (2MB)
    TARGET_FILE_SIZE = 2_097_152
    
    # Maximum image dimension (width or height)
    MAX_DIMENSION = 1024
    
    # Minimum JPEG quality
    MIN_QUALITY = 30
    
    # Starting JPEG quality
    START_QUALITY = 85
    
    @classmethod
    def optimize_image(
        cls,
        image_data: bytes,
        target_size: int = TARGET_FILE_SIZE,
        max_size: int = MAX_FILE_SIZE
    ) -> Tuple[bytes, dict]:
        """
        Optimize image with progressive compression and resizing
        
        Args:
            image_data: Raw image bytes
            target_size: Target file size in bytes
            max_size: Maximum allowed file size in bytes
            
        Returns:
            Tuple of (optimized_image_bytes, metadata_dict)
            
        Raises:
            ValueError: If image cannot be optimized within constraints
        """
        try:
            # Open image
            img = Image.open(BytesIO(image_data))
            original_size = len(image_data)
            original_dimensions = img.size
            
            # Convert to RGB if necessary (handles RGBA, P, L modes)
            if img.mode != 'RGB':
                if img.mode == 'RGBA':
                    # Handle transparency by adding white background
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    background.paste(img, mask=img.split()[3] if len(img.split()) == 4 else None)
                    img = background
                else:
                    img = img.convert('RGB')
            
            # Step 1: Resize if image is too large
            if cls._should_resize(img):
                img = cls._resize_image(img, cls.MAX_DIMENSION)
            
            # Step 2: Progressive compression
            quality = cls.START_QUALITY
            attempts = 0
            max_attempts = 10
            
            while attempts < max_attempts:
                attempts += 1
                
                # Compress image
                output = BytesIO()
                img.save(
                    output,
                    format='JPEG',
                    quality=quality,
                    optimize=True,
                    progressive=True
                )
                compressed_data = output.getvalue()
                current_size = len(compressed_data)
                
                # Check if size is acceptable
                if current_size <= target_size:
                    break
                
                # Reduce quality
                quality -= 10
                
                # If quality too low, resize further
                if quality < cls.MIN_QUALITY:
                    quality = cls.MIN_QUALITY
                    reduction_factor = (target_size / current_size) ** 0.5
                    new_dimension = int(max(img.size) * reduction_factor)
                    img = cls._resize_image(img, new_dimension)
            
            # Final size check
            if current_size > max_size:
                raise ValueError(
                    f"Image size ({current_size:,} bytes) exceeds maximum "
                    f"allowed ({max_size:,} bytes) after {attempts} optimization attempts"
                )
            
            # Calculate metadata
            compression_ratio = current_size / original_size
            size_reduction = (1 - compression_ratio) * 100
            
            metadata = {
                "original_size": original_size,
                "optimized_size": current_size,
                "compression_ratio": round(compression_ratio, 3),
                "size_reduction_percent": round(size_reduction, 1),
                "original_dimensions": {
                    "width": original_dimensions[0],
                    "height": original_dimensions[1]
                },
                "optimized_dimensions": {
                    "width": img.size[0],
                    "height": img.size[1]
                },
                "final_quality": quality,
                "optimization_attempts": attempts
            }
            
            logger.info(
                f"Image optimized: {original_size:,} → {current_size:,} bytes "
                f"({size_reduction:.1f}% reduction)"
            )
            
            return compressed_data, metadata
            
        except Exception as e:
            logger.error(f"Image optimization failed: {str(e)}")
            raise ValueError(f"Image optimization failed: {str(e)}")
    
    @classmethod
    def _should_resize(cls, img: Image.Image) -> bool:
        """Check if image should be resized based on dimensions"""
        return max(img.size) > cls.MAX_DIMENSION
    
    @classmethod
    def _resize_image(cls, img: Image.Image, max_dimension: int) -> Image.Image:
        """
        Resize image while maintaining aspect ratio
        
        Args:
            img: PIL Image object
            max_dimension: Maximum width or height
            
        Returns:
            Resized PIL Image object
        """
        width, height = img.size
        aspect_ratio = width / height
        
        if width > height:
            # Landscape
            new_width = max_dimension
            new_height = int(max_dimension / aspect_ratio)
        else:
            # Portrait or square
            new_width = int(max_dimension * aspect_ratio)
            new_height = max_dimension
        
        # Use high-quality Lanczos resampling
        return img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    @classmethod
    def create_thumbnail(
        cls,
        image_data: bytes,
        size: int = 200
    ) -> bytes:
        """
        Create square thumbnail from image
        
        Args:
            image_data: Raw image bytes
            size: Thumbnail size (square)
            
        Returns:
            Thumbnail image bytes
        """
        img = Image.open(BytesIO(image_data))
        
        # Convert to RGB if necessary
        if img.mode != 'RGB':
            if img.mode == 'RGBA':
                background = Image.new('RGB', img.size, (255, 255, 255))
                background.paste(img, mask=img.split()[3] if len(img.split()) == 4 else None)
                img = background
            else:
                img = img.convert('RGB')
        
        # Create thumbnail
        img.thumbnail((size, size), Image.Resampling.LANCZOS)
        
        # Save as JPEG
        output = BytesIO()
        img.save(output, format='JPEG', quality=85, optimize=True)
        return output.getvalue()
    
    @classmethod
    def validate_image(cls, image_data: bytes) -> bool:
        """
        Validate that data is a valid image
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            True if valid image, False otherwise
        """
        try:
            img = Image.open(BytesIO(image_data))
            img.verify()
            return True
        except Exception:
            return False
    
    @classmethod
    def get_image_info(cls, image_data: bytes) -> dict:
        """
        Get information about an image
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Dictionary with image information
        """
        try:
            img = Image.open(BytesIO(image_data))
            return {
                "format": img.format,
                "mode": img.mode,
                "size": img.size,
                "width": img.size[0],
                "height": img.size[1],
                "file_size": len(image_data)
            }
        except Exception as e:
            raise ValueError(f"Failed to get image info: {str(e)}")

