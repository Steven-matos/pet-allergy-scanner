"""
Scan data models and schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime
from enum import Enum

class ScanStatus(str, Enum):
    """Scan status enumeration"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

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

class ScanBase(BaseModel):
    """Base scan model"""
    pet_id: str
    image_url: Optional[str] = None
    raw_text: Optional[str] = None
    status: ScanStatus = ScanStatus.PENDING
    result: Optional[ScanResult] = None

class ScanCreate(ScanBase):
    """Scan creation model"""
    pass

class ScanUpdate(BaseModel):
    """Scan update model"""
    status: Optional[ScanStatus] = None
    result: Optional[ScanResult] = None
    raw_text: Optional[str] = None

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
