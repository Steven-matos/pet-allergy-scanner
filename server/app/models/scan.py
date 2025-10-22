"""
Scan data models and schemas
"""

from pydantic import BaseModel, ConfigDict, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum

class ScanStatus(str, Enum):
    """Scan status enumeration"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class ScanMethod(str, Enum):
    """Scan method enumeration"""
    BARCODE = "barcode"  # Barcode scan only - no image saved
    OCR = "ocr"  # OCR scan - image saved for processing
    HYBRID = "hybrid"  # Both barcode and OCR - image saved

class NutritionalAnalysis(BaseModel):
    """Nutritional analysis model for pet food"""
    serving_size_g: Optional[float] = Field(None, gt=0, description="Serving size in grams")
    calories_per_serving: Optional[float] = Field(None, gt=0, description="Calories per serving")
    calories_per_100g: Optional[float] = Field(None, gt=0, description="Calories per 100g")
    macronutrients: Optional[Dict[str, float]] = Field(default_factory=dict, description="Protein, fat, fiber, moisture, ash percentages")
    minerals: Optional[Dict[str, float]] = Field(default_factory=dict, description="Calcium, phosphorus percentages")
    recommendations: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Pet-specific nutritional recommendations")

class ScanResult(BaseModel):
    """Scan result model"""
    product_name: Optional[str] = None
    brand: Optional[str] = None
    ingredients_found: List[str] = Field(default_factory=list)
    unsafe_ingredients: List[str] = Field(default_factory=list)
    safe_ingredients: List[str] = Field(default_factory=list)
    overall_safety: str = "unknown"  # "safe", "caution", "unsafe"
    confidence_score: float = Field(0.0, ge=0.0, le=1.0)
    analysis_details: Dict[str, str] = Field(default_factory=dict)
    nutritional_analysis: Optional[NutritionalAnalysis] = None

class ScanBase(BaseModel):
    """Base scan model"""
    pet_id: str
    image_url: Optional[str] = None
    raw_text: Optional[str] = None
    status: ScanStatus = ScanStatus.PENDING
    scan_method: ScanMethod = ScanMethod.OCR
    result: Optional[ScanResult] = None
    nutritional_analysis: Optional[NutritionalAnalysis] = None

class ScanCreate(ScanBase):
    """Scan creation model"""
    pass

class ScanUpdate(BaseModel):
    """Scan update model"""
    status: Optional[ScanStatus] = None
    result: Optional[ScanResult] = None
    raw_text: Optional[str] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    notes: Optional[str] = Field(None, max_length=1000)
    method: Optional[ScanMethod] = None

class ScanResponse(ScanBase):
    """Scan response model"""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class ScanAnalysisRequest(BaseModel):
    """Scan analysis request model"""
    pet_id: str
    extracted_text: str
    product_name: Optional[str] = None
    scan_method: ScanMethod = ScanMethod.OCR
    image_data: Optional[str] = None  # Base64 encoded image for OCR scans
