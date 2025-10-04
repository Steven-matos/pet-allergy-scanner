"""
Pet data models and schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date
from enum import Enum

class PetSpecies(str, Enum):
    """Pet species enumeration"""
    DOG = "dog"
    CAT = "cat"

class PetActivityLevel(str, Enum):
    """Pet activity level enumeration"""
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"

class PetLifeStage(str, Enum):
    """Pet life stage enumeration"""
    PUPPY = "puppy"
    ADULT = "adult"
    SENIOR = "senior"
    PREGNANT = "pregnant"
    LACTATING = "lactating"

class PetBreed(BaseModel):
    """Pet breed information"""
    name: str
    species: PetSpecies

class PetBase(BaseModel):
    """Base pet model with common fields"""
    name: str = Field(..., min_length=1, max_length=100)
    species: PetSpecies
    breed: Optional[str] = None
    birthday: Optional[date] = None
    weight_kg: Optional[float] = Field(None, ge=0.1, le=200.0)
    activity_level: Optional[PetActivityLevel] = None
    image_url: Optional[str] = None
    known_sensitivities: List[str] = Field(default_factory=list)
    vet_name: Optional[str] = None
    vet_phone: Optional[str] = None

class PetCreate(PetBase):
    """Pet creation model"""
    pass

class PetUpdate(BaseModel):
    """Pet update model"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    breed: Optional[str] = None
    birthday: Optional[date] = None
    weight_kg: Optional[float] = Field(None, ge=0.1, le=200.0)
    activity_level: Optional[PetActivityLevel] = None
    image_url: Optional[str] = None
    known_sensitivities: Optional[List[str]] = None
    vet_name: Optional[str] = None
    vet_phone: Optional[str] = None

class PetResponse(PetBase):
    """Pet response model"""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    @property
    def age_months(self) -> Optional[int]:
        """Calculate age in months from birthday"""
        if not self.birthday:
            return None
        
        today = date.today()
        years = today.year - self.birthday.year
        months = today.month - self.birthday.month
        
        if today.day < self.birthday.day:
            months -= 1
        
        if months < 0:
            years -= 1
            months += 12
        
        return years * 12 + months
    
    @property
    def age_years(self) -> Optional[float]:
        """Calculate age in years from birthday"""
        if not self.birthday:
            return None
        
        today = date.today()
        years = today.year - self.birthday.year
        months = today.month - self.birthday.month
        
        if today.day < self.birthday.day:
            months -= 1
        
        if months < 0:
            years -= 1
            months += 12
        
        return years + (months / 12.0)
    
    @property
    def life_stage(self) -> PetLifeStage:
        """Calculate life stage based on age and species"""
        age_months = self.age_months
        if not age_months:
            return PetLifeStage.ADULT
        
        if age_months < 12:
            return PetLifeStage.PUPPY
        elif age_months >= 84:  # 7 years
            return PetLifeStage.SENIOR
        else:
            return PetLifeStage.ADULT
    
    @property
    def effective_activity_level(self) -> PetActivityLevel:
        """Get effective activity level (defaults to moderate if not set)"""
        return self.activity_level or PetActivityLevel.MODERATE
    
    class Config:
        from_attributes = True
        # Exclude computed properties from JSON serialization
        exclude = {'age_months', 'age_years'}
