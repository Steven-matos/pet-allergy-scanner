"""
Pet data models and schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class PetSpecies(str, Enum):
    """Pet species enumeration"""
    DOG = "dog"
    CAT = "cat"

class PetBreed(BaseModel):
    """Pet breed information"""
    name: str
    species: PetSpecies

class PetBase(BaseModel):
    """Base pet model with common fields"""
    name: str = Field(..., min_length=1, max_length=100)
    species: PetSpecies
    breed: Optional[str] = None
    age_months: Optional[int] = Field(None, ge=0, le=300)  # 0-25 years
    weight_kg: Optional[float] = Field(None, ge=0.1, le=200.0)
    known_allergies: List[str] = Field(default_factory=list)
    vet_name: Optional[str] = None
    vet_phone: Optional[str] = None

class PetCreate(PetBase):
    """Pet creation model"""
    pass

class PetUpdate(BaseModel):
    """Pet update model"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    breed: Optional[str] = None
    age_months: Optional[int] = Field(None, ge=0, le=300)
    weight_kg: Optional[float] = Field(None, ge=0.1, le=200.0)
    known_allergies: Optional[List[str]] = None
    vet_name: Optional[str] = None
    vet_phone: Optional[str] = None

class PetResponse(PetBase):
    """Pet response model"""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
