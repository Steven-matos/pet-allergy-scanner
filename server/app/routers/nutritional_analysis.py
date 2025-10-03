"""
Nutritional analysis API endpoints
Provides nutritional analysis and recommendations for pet food
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from ..database import get_db
from ..models.nutritional_standards import (
    NutritionalStandardResponse,
    NutritionalRecommendation,
    NutritionalAnalysisRequest,
    Species,
    LifeStage,
    ActivityLevel
)
from ..models.scan import NutritionalAnalysis
from ..services.nutritional_calculator import NutritionalCalculator
from ..models.user import User
from ..models.pet import Pet
from ..models.nutritional_standards import NutritionalStandard
from ..routers.auth import get_current_user

router = APIRouter(prefix="/nutritional-analysis", tags=["nutritional-analysis"])

# Initialize nutritional calculator
nutritional_calculator = NutritionalCalculator()


@router.post("/analyze", response_model=dict)
async def analyze_nutritional_content(
    analysis_request: NutritionalAnalysisRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Analyze nutritional content of pet food and provide recommendations
    
    Args:
        analysis_request: Nutritional data from OCR or manual input
        current_user: Authenticated user
        db: Database session
        
    Returns:
        Nutritional analysis with recommendations
    """
    try:
        # Get pet information
        pet = db.query(Pet).filter(
            Pet.id == analysis_request.pet_id,
            Pet.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        # Create nutritional analysis object
        nutritional_analysis = NutritionalAnalysis(
            serving_size_g=analysis_request.serving_size_g,
            calories_per_serving=analysis_request.calories_per_serving,
            calories_per_100g=None,  # Will be calculated
            macronutrients=analysis_request.macronutrients or {},
            minerals=analysis_request.minerals or {}
        )
        
        # Calculate calories per 100g if we have macronutrient data
        if (nutritional_analysis.macronutrients and 
            all(key in nutritional_analysis.macronutrients for key in 
                ['protein_percent', 'fat_percent', 'fiber_percent', 'moisture_percent', 'ash_percent'])):
            
            calories_per_100g = nutritional_calculator.calculate_calories_per_100g(
                protein_percent=nutritional_analysis.macronutrients['protein_percent'],
                fat_percent=nutritional_analysis.macronutrients['fat_percent'],
                fiber_percent=nutritional_analysis.macronutrients['fiber_percent'],
                moisture_percent=nutritional_analysis.macronutrients['moisture_percent'],
                ash_percent=nutritional_analysis.macronutrients['ash_percent']
            )
            nutritional_analysis.calories_per_100g = calories_per_100g
        
        # Analyze nutritional adequacy
        analysis_result = nutritional_calculator.analyze_nutritional_adequacy(
            nutritional_analysis=nutritional_analysis,
            pet_weight_kg=pet.weight_kg or 0,
            species=Species(pet.species),
            life_stage=LifeStage.ADULT,  # TODO: Calculate from pet birthday
            activity_level=ActivityLevel.MODERATE  # TODO: Add activity level to pet model
        )
        
        # Add nutritional analysis to the result
        analysis_result["nutritional_analysis"] = nutritional_analysis.dict()
        
        return analysis_result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Nutritional analysis failed: {str(e)}"
        )


@router.get("/standards", response_model=List[NutritionalStandardResponse])
async def get_nutritional_standards(
    species: Optional[Species] = None,
    life_stage: Optional[LifeStage] = None,
    db: Session = Depends(get_db)
):
    """
    Get nutritional standards for pets
    
    Args:
        species: Filter by species (dog/cat)
        life_stage: Filter by life stage
        db: Database session
        
    Returns:
        List of nutritional standards
    """
    try:
        # Query nutritional standards from database
        query = db.query(NutritionalStandard)
        
        if species:
            query = query.filter(NutritionalStandard.species == species)
        if life_stage:
            query = query.filter(NutritionalStandard.life_stage == life_stage)
        
        standards = query.all()
        return standards
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve nutritional standards: {str(e)}"
        )


@router.get("/recommendations/{pet_id}", response_model=NutritionalRecommendation)
async def get_nutritional_recommendations(
    pet_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get nutritional recommendations for a specific pet
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        db: Database session
        
    Returns:
        Nutritional recommendations for the pet
    """
    try:
        # Get pet information
        pet = db.query(Pet).filter(
            Pet.id == pet_id,
            Pet.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        # Calculate daily calorie needs
        daily_calories = nutritional_calculator.calculate_daily_calorie_needs(
            weight_kg=pet.weight_kg or 0,
            species=Species(pet.species),
            life_stage=LifeStage.ADULT,  # TODO: Calculate from pet birthday
            activity_level=ActivityLevel.MODERATE  # TODO: Add activity level to pet model
        )
        
        # Get nutritional standards
        standards = nutritional_calculator._get_nutritional_standards(
            species=Species(pet.species),
            life_stage=LifeStage.ADULT,
            weight_kg=pet.weight_kg or 0,
            activity_level=ActivityLevel.MODERATE
        )
        
        if not standards:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No nutritional standards found for this pet profile"
            )
        
        # Create recommendation
        recommendation = NutritionalRecommendation(
            pet_id=pet_id,
            species=Species(pet.species),
            life_stage=LifeStage.ADULT,
            weight_kg=pet.weight_kg or 0,
            activity_level=ActivityLevel.MODERATE,
            daily_calories_needed=daily_calories,
            protein_requirement_percent=standards.protein_min_percent,
            fat_requirement_percent=standards.fat_min_percent,
            fiber_limit_percent=standards.fiber_max_percent,
            moisture_limit_percent=standards.moisture_max_percent,
            ash_limit_percent=standards.ash_max_percent,
            calcium_requirement_percent=standards.calcium_min_percent,
            phosphorus_requirement_percent=standards.phosphorus_min_percent,
            recommendations={
                "daily_calories": daily_calories,
                "feeding_frequency": "2-3 times per day",
                "water_intake": "Always provide fresh water",
                "monitoring": "Monitor weight and adjust portions as needed"
            }
        )
        
        return recommendation
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate nutritional recommendations: {str(e)}"
        )


@router.post("/calculate-calories", response_model=dict)
async def calculate_calories(
    protein_percent: float,
    fat_percent: float,
    fiber_percent: float,
    moisture_percent: float,
    ash_percent: float
):
    """
    Calculate calories per 100g from macronutrient percentages
    
    Args:
        protein_percent: Protein percentage
        fat_percent: Fat percentage
        fiber_percent: Fiber percentage
        moisture_percent: Moisture percentage
        ash_percent: Ash percentage
        
    Returns:
        Calculated calories per 100g
    """
    try:
        calories_per_100g = nutritional_calculator.calculate_calories_per_100g(
            protein_percent=protein_percent,
            fat_percent=fat_percent,
            fiber_percent=fiber_percent,
            moisture_percent=moisture_percent,
            ash_percent=ash_percent
        )
        
        return {
            "calories_per_100g": calories_per_100g,
            "input_values": {
                "protein_percent": protein_percent,
                "fat_percent": fat_percent,
                "fiber_percent": fiber_percent,
                "moisture_percent": moisture_percent,
                "ash_percent": ash_percent
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid nutritional data: {str(e)}"
        )
