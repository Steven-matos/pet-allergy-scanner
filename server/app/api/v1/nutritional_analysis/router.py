"""
Nutritional analysis API endpoints
Provides nutritional analysis and recommendations for pet food
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from datetime import datetime
import uuid
from app.database import get_supabase_client
from app.models.nutritional_standards import (
    NutritionalStandardResponse,
    NutritionalRecommendation,
    NutritionalAnalysisRequest,
    Species,
    LifeStage,
    ActivityLevel
)
from app.models.pet import PetResponse, PetLifeStage, PetActivityLevel
from app.models.scan import NutritionalAnalysis
from app.services.nutritional_calculator import NutritionalCalculator
from app.models.user import User
from app.core.security.jwt_handler import get_current_user
from app.shared.services.pet_authorization import verify_pet_ownership

router = APIRouter(prefix="/nutritional-analysis", tags=["nutritional-analysis"])

# Initialize nutritional calculator
nutritional_calculator = NutritionalCalculator()


@router.post("/analyze", response_model=dict)
async def analyze_nutritional_content(
    analysis_request: NutritionalAnalysisRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Analyze nutritional content of pet food and provide recommendations
    
    Args:
        analysis_request: Nutritional data from OCR or manual input
        current_user: Authenticated user
        
    Returns:
        Nutritional analysis with recommendations
    """
    try:
        # Verify pet ownership using centralized service
        supabase = get_supabase_client()
        pet_data = await verify_pet_ownership(analysis_request.pet_id, current_user.id, supabase)
        pet = PetResponse(
            id=pet_data["id"],
            user_id=pet_data["user_id"],
            name=pet_data["name"],
            species=pet_data["species"],
            breed=pet_data["breed"],
            birthday=pet_data["birthday"],
            weight_kg=pet_data["weight_kg"],
            activity_level=pet_data.get("activity_level"),
            image_url=pet_data.get("image_url"),
            known_sensitivities=pet_data["known_sensitivities"],
            vet_name=pet_data["vet_name"],
            vet_phone=pet_data["vet_phone"],
            created_at=pet_data["created_at"],
            updated_at=pet_data["updated_at"]
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
        
        # Convert pet enums to nutritional enums
        species_enum = Species.DOG if pet.species == "dog" else Species.CAT
        life_stage_enum = LifeStage(pet.life_stage.value)
        activity_level_enum = ActivityLevel(pet.effective_activity_level.value)
        
        # Analyze nutritional adequacy
        analysis_result = nutritional_calculator.analyze_nutritional_adequacy(
            nutritional_analysis=nutritional_analysis,
            pet_weight_kg=pet.weight_kg or 0,
            species=species_enum,
            life_stage=life_stage_enum,
            activity_level=activity_level_enum
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
    life_stage: Optional[LifeStage] = None
):
    """
    Get nutritional standards for pets
    
    Args:
        species: Filter by species (dog/cat)
        life_stage: Filter by life stage
        
    Returns:
        List of nutritional standards
    """
    try:
        # Query nutritional standards from Supabase
        supabase = get_supabase_client()
        query = supabase.table("nutritional_standards").select("*")
        
        if species:
            query = query.eq("species", species.value)
        if life_stage:
            query = query.eq("life_stage", life_stage.value)
        
        response = query.execute()
        
        # Convert to response models
        standards = []
        for standard in response.data:
            # Parse datetime strings if they exist
            created_at = datetime.now()
            updated_at = datetime.now()
            
            if "created_at" in standard and standard["created_at"]:
                try:
                    if isinstance(standard["created_at"], str):
                        # Try ISO format first
                        created_at = datetime.fromisoformat(standard["created_at"].replace('Z', '+00:00'))
                    else:
                        created_at = standard["created_at"]
                except (ValueError, AttributeError):
                    created_at = datetime.now()
            
            if "updated_at" in standard and standard["updated_at"]:
                try:
                    if isinstance(standard["updated_at"], str):
                        # Try ISO format first
                        updated_at = datetime.fromisoformat(standard["updated_at"].replace('Z', '+00:00'))
                    else:
                        updated_at = standard["updated_at"]
                except (ValueError, AttributeError):
                    updated_at = datetime.now()
            
            standards.append(NutritionalStandardResponse(
                id=standard.get("id", str(uuid.uuid4())),
                species=standard["species"],
                life_stage=standard["life_stage"],
                weight_range_min=standard["weight_range_min"],
                weight_range_max=standard["weight_range_max"],
                activity_level=standard["activity_level"],
                calories_per_kg=standard["calories_per_kg"],
                protein_min_percent=standard["protein_min_percent"],
                fat_min_percent=standard["fat_min_percent"],
                fiber_max_percent=standard["fiber_max_percent"],
                moisture_max_percent=standard["moisture_max_percent"],
                ash_max_percent=standard["ash_max_percent"],
                calcium_min_percent=standard.get("calcium_min_percent"),
                phosphorus_min_percent=standard.get("phosphorus_min_percent"),
                created_at=created_at,
                updated_at=updated_at
            ))
        
        return standards
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve nutritional standards: {str(e)}"
        )


@router.get("/recommendations/{pet_id}", response_model=NutritionalRecommendation)
async def get_nutritional_recommendations(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get nutritional recommendations for a specific pet
    
    Args:
        pet_id: Pet ID
        current_user: Authenticated user
        
    Returns:
        Nutritional recommendations for the pet
    """
    try:
        # Verify pet ownership using centralized service
        supabase = get_supabase_client()
        pet_data = await verify_pet_ownership(pet_id, current_user.id, supabase)
        pet = PetResponse(
            id=pet_data["id"],
            user_id=pet_data["user_id"],
            name=pet_data["name"],
            species=pet_data["species"],
            breed=pet_data["breed"],
            birthday=pet_data["birthday"],
            weight_kg=pet_data["weight_kg"],
            activity_level=pet_data.get("activity_level"),
            image_url=pet_data.get("image_url"),
            known_sensitivities=pet_data["known_sensitivities"],
            vet_name=pet_data["vet_name"],
            vet_phone=pet_data["vet_phone"],
            created_at=pet_data["created_at"],
            updated_at=pet_data["updated_at"]
        )
        
        # Convert pet enums to nutritional enums
        species_enum = Species.DOG if pet.species == "dog" else Species.CAT
        life_stage_enum = LifeStage(pet.life_stage.value)
        activity_level_enum = ActivityLevel(pet.effective_activity_level.value)
        
        # Calculate daily calorie needs
        daily_calories = nutritional_calculator.calculate_daily_calorie_needs(
            weight_kg=pet.weight_kg or 0,
            species=species_enum,
            life_stage=life_stage_enum,
            activity_level=activity_level_enum,
            age_months=pet.age_months
        )
        
        # Get nutritional standards
        standards = nutritional_calculator._get_nutritional_standards(
            species=species_enum,
            life_stage=life_stage_enum,
            weight_kg=pet.weight_kg or 0,
            activity_level=activity_level_enum
        )
        
        if not standards:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No nutritional standards found for this pet profile"
            )
        
        # Create recommendation
        recommendation = NutritionalRecommendation(
            pet_id=pet_id,
            species=species_enum,
            life_stage=life_stage_enum,
            weight_kg=pet.weight_kg or 0,
            activity_level=activity_level_enum,
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
                "monitoring": "Monitor weight and adjust portions as needed",
                "life_stage": pet.life_stage.value,
                "activity_level": pet.effective_activity_level.value
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
