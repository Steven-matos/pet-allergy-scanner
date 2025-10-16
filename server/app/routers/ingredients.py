"""
Ingredient management and analysis router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from typing import List, Dict
from app.models.ingredient import IngredientResponse, IngredientAnalysis
from app.models.pet import PetSpecies
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
from app.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger
import re

router = APIRouter()
logger = get_logger(__name__)

# Common allergen ingredients database
COMMON_ALLERGENS = {
    "chicken": {"safety": "caution", "species": "both", "common": True},
    "beef": {"safety": "caution", "species": "both", "common": True},
    "fish": {"safety": "caution", "species": "both", "common": True},
    "corn": {"safety": "caution", "species": "both", "common": True},
    "wheat": {"safety": "caution", "species": "both", "common": True},
    "soy": {"safety": "caution", "species": "both", "common": True},
    "dairy": {"safety": "caution", "species": "both", "common": True},
    "eggs": {"safety": "caution", "species": "both", "common": True},
    "lamb": {"safety": "safe", "species": "both", "common": False},
    "turkey": {"safety": "safe", "species": "both", "common": False},
    "duck": {"safety": "safe", "species": "both", "common": False},
    "venison": {"safety": "safe", "species": "both", "common": False},
    "sweet potato": {"safety": "safe", "species": "both", "common": False},
    "brown rice": {"safety": "safe", "species": "both", "common": False},
    "oats": {"safety": "safe", "species": "both", "common": False},
    "quinoa": {"safety": "safe", "species": "both", "common": False},
    "salmon": {"safety": "safe", "species": "both", "common": False},
    "tuna": {"safety": "safe", "species": "both", "common": False},
    "chocolate": {"safety": "unsafe", "species": "both", "common": True},
    "grapes": {"safety": "unsafe", "species": "both", "common": True},
    "raisins": {"safety": "unsafe", "species": "both", "common": True},
    "onions": {"safety": "unsafe", "species": "both", "common": True},
    "garlic": {"safety": "unsafe", "species": "both", "common": True},
    "xylitol": {"safety": "unsafe", "species": "both", "common": True},
    "macadamia nuts": {"safety": "unsafe", "species": "both", "common": True},
    "avocado": {"safety": "unsafe", "species": "both", "common": True},
    "coffee": {"safety": "unsafe", "species": "both", "common": True},
    "alcohol": {"safety": "unsafe", "species": "both", "common": True},
    "propylene glycol": {"safety": "unsafe", "species": "cat_only", "common": True},
    "artificial sweeteners": {"safety": "unsafe", "species": "both", "common": True},
    "salt": {"safety": "caution", "species": "both", "common": True},
    "sugar": {"safety": "caution", "species": "both", "common": True},
    "preservatives": {"safety": "caution", "species": "both", "common": True},
    "artificial colors": {"safety": "caution", "species": "both", "common": True},
    "artificial flavors": {"safety": "caution", "species": "both", "common": True}
}

@router.get("", response_model=List[IngredientResponse])
@router.get("/", response_model=List[IngredientResponse])
async def get_ingredients(
    search: str = None,
    safety_level: str = None,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get ingredients with optional filtering
    
    Returns a list of ingredients with optional search and safety level filtering
    """
    try:
        supabase = get_supabase_client()
        
        query = supabase.table("ingredients").select("*")
        
        if search:
            query = query.ilike("name", f"%{search}%")
        
        if safety_level:
            query = query.eq("safety_level", safety_level)
        
        response = query.execute()
        
        ingredients = []
        for ingredient in response.data:
            ingredients.append(IngredientResponse(
                id=ingredient["id"],
                name=ingredient["name"],
                aliases=ingredient["aliases"],
                safety_level=ingredient["safety_level"],
                species_compatibility=ingredient["species_compatibility"],
                description=ingredient["description"],
                common_allergen=ingredient["common_allergen"],
                nutritional_value=ingredient["nutritional_value"],
                created_at=ingredient["created_at"],
                updated_at=ingredient["updated_at"]
            ))
        
        return ingredients
        
    except Exception as e:
        logger.error(f"Get ingredients error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve ingredients"
        )

@router.post("/analyze", response_model=List[IngredientAnalysis])
async def analyze_ingredients(
    ingredients: List[str],
    pet_species: PetSpecies,
    pet_sensitivities: List[str] = None,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze ingredients for a specific pet
    
    Analyzes a list of ingredients against pet species and known sensitivities
    """
    try:
        if pet_sensitivities is None:
            pet_sensitivities = []
        
        analyses = []
        
        for ingredient in ingredients:
            # Normalize ingredient name
            normalized_ingredient = ingredient.lower().strip()
            
            # Check against common allergens database
            allergen_info = COMMON_ALLERGENS.get(normalized_ingredient, {
                "safety": "unknown",
                "species": "both",
                "common": False
            })
            
            # Check species compatibility
            is_safe_for_species = True
            if allergen_info["species"] == "cat_only" and pet_species != PetSpecies.CAT:
                is_safe_for_species = False
            elif allergen_info["species"] == "dog_only" and pet_species != PetSpecies.DOG:
                is_safe_for_species = False
            elif allergen_info["species"] == "neither":
                is_safe_for_species = False
            
            # Check against pet's known allergies
            is_unsafe_for_pet = False
            reason = None
            
            if normalized_ingredient in [sensitivity.lower() for sensitivity in pet_sensitivities]:
                is_unsafe_for_pet = True
                reason = "Known food sensitivity for this pet"
            elif allergen_info["safety"] == "unsafe":
                is_unsafe_for_pet = True
                reason = "Toxic to pets"
            elif allergen_info["safety"] == "caution" and allergen_info["common"]:
                is_unsafe_for_pet = True
                reason = "Common allergen"
            elif not is_safe_for_species:
                is_unsafe_for_pet = True
                reason = f"Not suitable for {pet_species.value}s"
            
            # Determine overall safety
            if is_unsafe_for_pet:
                safety_level = "unsafe"
            elif allergen_info["safety"] == "caution":
                safety_level = "caution"
            elif allergen_info["safety"] == "safe":
                safety_level = "safe"
            else:
                safety_level = "unknown"
            
            # Generate alternatives for unsafe ingredients
            alternatives = []
            if is_unsafe_for_pet and allergen_info["safety"] == "caution":
                if "chicken" in normalized_ingredient:
                    alternatives = ["turkey", "duck", "lamb"]
                elif "beef" in normalized_ingredient:
                    alternatives = ["lamb", "turkey", "duck"]
                elif "corn" in normalized_ingredient:
                    alternatives = ["brown rice", "oats", "quinoa"]
                elif "wheat" in normalized_ingredient:
                    alternatives = ["brown rice", "oats", "quinoa"]
            
            analyses.append(IngredientAnalysis(
                ingredient_name=ingredient,
                safety_level=safety_level,
                is_unsafe_for_pet=is_unsafe_for_pet,
                reason=reason,
                alternatives=alternatives
            ))
        
        return analyses
        
    except Exception as e:
        logger.error(f"Analyze ingredients error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to analyze ingredients"
        )

@router.get("/common-allergens", response_model=List[str])
async def get_common_allergens():
    """
    Get list of common allergen ingredients
    
    Returns a list of ingredients commonly associated with pet allergies
    """
    try:
        common_allergens = [
            ingredient for ingredient, info in COMMON_ALLERGENS.items()
            if info["common"] and info["safety"] in ["caution", "unsafe"]
        ]
        return sorted(common_allergens)
        
    except Exception as e:
        logger.error(f"Get common allergens error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve common allergens"
        )

@router.get("/safe-alternatives", response_model=List[str])
async def get_safe_alternatives():
    """
    Get list of safe alternative ingredients
    
    Returns a list of ingredients that are generally safe for pets
    """
    try:
        safe_alternatives = [
            ingredient for ingredient, info in COMMON_ALLERGENS.items()
            if info["safety"] == "safe"
        ]
        return sorted(safe_alternatives)
        
    except Exception as e:
        logger.error(f"Get safe alternatives error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve safe alternatives"
        )
