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
    "rabbit": {"safety": "safe", "species": "both", "common": False},
    "salmon": {"safety": "safe", "species": "both", "common": False},
    "sweet potato": {"safety": "safe", "species": "both", "common": False},
    "peas": {"safety": "safe", "species": "both", "common": False},
    "carrots": {"safety": "safe", "species": "both", "common": False},
    "blueberries": {"safety": "safe", "species": "both", "common": False},
    "cranberries": {"safety": "safe", "species": "both", "common": False},
    "pumpkin": {"safety": "safe", "species": "both", "common": False},
    "spinach": {"safety": "safe", "species": "both", "common": False},
    "broccoli": {"safety": "safe", "species": "both", "common": False},
    "chocolate": {"safety": "dangerous", "species": "both", "common": False},
    "onions": {"safety": "dangerous", "species": "both", "common": False},
    "garlic": {"safety": "dangerous", "species": "both", "common": False},
    "grapes": {"safety": "dangerous", "species": "both", "common": False},
    "raisins": {"safety": "dangerous", "species": "both", "common": False},
    "avocado": {"safety": "dangerous", "species": "both", "common": False},
    "macadamia nuts": {"safety": "dangerous", "species": "both", "common": False},
    "xylitol": {"safety": "dangerous", "species": "both", "common": False},
    "artificial sweeteners": {"safety": "dangerous", "species": "both", "common": False},
    "alcohol": {"safety": "dangerous", "species": "both", "common": False},
    "caffeine": {"safety": "dangerous", "species": "both", "common": False},
    "salt": {"safety": "caution", "species": "both", "common": False},
    "sugar": {"safety": "caution", "species": "both", "common": False},
    "preservatives": {"safety": "caution", "species": "both", "common": False},
    "artificial colors": {"safety": "caution", "species": "both", "common": False},
    "artificial flavors": {"safety": "caution", "species": "both", "common": False}
}

def analyze_ingredient_safety(ingredient_name: str, pet_species: str) -> Dict:
    """
    Analyze the safety of an ingredient for a specific pet species
    
    Args:
        ingredient_name: Name of the ingredient to analyze
        pet_species: Species of the pet (cat, dog, both)
        
    Returns:
        Dictionary with safety analysis results
    """
    ingredient_lower = ingredient_name.lower().strip()
    
    # Check for exact matches first
    if ingredient_lower in COMMON_ALLERGENS:
        allergen_info = COMMON_ALLERGENS[ingredient_lower]
        
        # Check species compatibility
        if allergen_info["species"] == "both" or allergen_info["species"] == pet_species:
            return {
                "ingredient": ingredient_name,
                "safety_level": allergen_info["safety"],
                "is_common_allergen": allergen_info["common"],
                "species_compatible": True,
                "recommendation": get_safety_recommendation(allergen_info["safety"]),
                "notes": get_safety_notes(ingredient_name, allergen_info["safety"])
            }
    
    # Check for partial matches
    for allergen, info in COMMON_ALLERGENS.items():
        if allergen in ingredient_lower or ingredient_lower in allergen:
            if info["species"] == "both" or info["species"] == pet_species:
                return {
                    "ingredient": ingredient_name,
                    "safety_level": info["safety"],
                    "is_common_allergen": info["common"],
                    "species_compatible": True,
                    "recommendation": get_safety_recommendation(info["safety"]),
                    "notes": get_safety_notes(ingredient_name, info["safety"])
                }
    
    # Default to unknown if no match found
    return {
        "ingredient": ingredient_name,
        "safety_level": "unknown",
        "is_common_allergen": False,
        "species_compatible": True,
        "recommendation": "Consult with your veterinarian before feeding this ingredient",
        "notes": "This ingredient is not in our database. Please research its safety for your pet."
    }

def get_safety_recommendation(safety_level: str) -> str:
    """Get recommendation based on safety level"""
    recommendations = {
        "safe": "This ingredient is generally safe for your pet",
        "caution": "This ingredient may cause issues for some pets. Monitor your pet closely",
        "dangerous": "This ingredient is dangerous and should be avoided",
        "unknown": "This ingredient is not in our database. Consult your veterinarian"
    }
    return recommendations.get(safety_level, "Unknown safety level")

def get_safety_notes(ingredient_name: str, safety_level: str) -> str:
    """Get specific notes based on ingredient and safety level"""
    if safety_level == "dangerous":
        if "chocolate" in ingredient_name.lower():
            return "Chocolate contains theobromine which is toxic to pets"
        elif "onion" in ingredient_name.lower() or "garlic" in ingredient_name.lower():
            return "Onions and garlic can cause hemolytic anemia in pets"
        elif "grape" in ingredient_name.lower() or "raisin" in ingredient_name.lower():
            return "Grapes and raisins can cause kidney failure in pets"
        elif "xylitol" in ingredient_name.lower():
            return "Xylitol can cause rapid insulin release and liver failure"
        else:
            return "This ingredient is known to be toxic to pets"
    elif safety_level == "caution":
        return "This ingredient may cause allergic reactions or digestive issues in some pets"
    else:
        return "This ingredient appears to be safe for your pet"

async def analyze_ingredients(ingredient_text: str, pet_allergies: List[str] = None, dietary_restrictions: List[str] = None) -> IngredientAnalysis:
    """
    Analyze a list of ingredients for safety and compatibility
    
    Args:
        ingredient_text: Text containing ingredients to analyze
        pet_allergies: List of known pet allergies
        dietary_restrictions: List of dietary restrictions
        
    Returns:
        IngredientAnalysis with detailed results
    """
    try:
        # Parse ingredients from text
        ingredients = parse_ingredients_from_text(ingredient_text)
        
        if not ingredients:
            return IngredientAnalysis(
                ingredients=[],
                safe_ingredients=[],
                caution_ingredients=[],
                dangerous_ingredients=[],
                unknown_ingredients=[],
                allergy_warnings=[],
                overall_safety="unknown",
                recommendations=[]
            )
        
        # Analyze each ingredient
        analyzed_ingredients = []
        safe_ingredients = []
        caution_ingredients = []
        dangerous_ingredients = []
        unknown_ingredients = []
        allergy_warnings = []
        
        for ingredient in ingredients:
            analysis = analyze_ingredient_safety(ingredient, "both")  # Default to both species
            
            analyzed_ingredients.append(IngredientResponse(
                name=ingredient,
                safety_level=analysis["safety_level"],
                is_common_allergen=analysis["is_common_allergen"],
                recommendation=analysis["recommendation"],
                notes=analysis["notes"]
            ))
            
            # Categorize ingredients
            if analysis["safety_level"] == "safe":
                safe_ingredients.append(ingredient)
            elif analysis["safety_level"] == "caution":
                caution_ingredients.append(ingredient)
            elif analysis["safety_level"] == "dangerous":
                dangerous_ingredients.append(ingredient)
            else:
                unknown_ingredients.append(ingredient)
            
            # Check for allergy warnings
            if pet_allergies:
                for allergy in pet_allergies:
                    if allergy.lower() in ingredient.lower():
                        allergy_warnings.append(f"Warning: {ingredient} may contain {allergy}")
        
        # Determine overall safety
        if dangerous_ingredients:
            overall_safety = "dangerous"
        elif caution_ingredients:
            overall_safety = "caution"
        elif unknown_ingredients:
            overall_safety = "unknown"
        else:
            overall_safety = "safe"
        
        # Generate recommendations
        recommendations = []
        if dangerous_ingredients:
            recommendations.append("Avoid this product - contains dangerous ingredients")
        if caution_ingredients:
            recommendations.append("Monitor your pet closely if feeding this product")
        if unknown_ingredients:
            recommendations.append("Consult your veterinarian about unknown ingredients")
        if allergy_warnings:
            recommendations.append("Check for potential allergens")
        
        return IngredientAnalysis(
            ingredients=analyzed_ingredients,
            safe_ingredients=safe_ingredients,
            caution_ingredients=caution_ingredients,
            dangerous_ingredients=dangerous_ingredients,
            unknown_ingredients=unknown_ingredients,
            allergy_warnings=allergy_warnings,
            overall_safety=overall_safety,
            recommendations=recommendations
        )
        
    except Exception as e:
        logger.error(f"Error analyzing ingredients: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error analyzing ingredients"
        )

def parse_ingredients_from_text(text: str) -> List[str]:
    """
    Parse ingredients from text using various methods
    
    Args:
        text: Text containing ingredients
        
    Returns:
        List of ingredient names
    """
    if not text or not text.strip():
        return []
    
    # Clean the text
    text = text.strip()
    
    # Try to split by common separators
    separators = [',', ';', '\n', '|', '•', '·']
    
    for separator in separators:
        if separator in text:
            ingredients = [ingredient.strip() for ingredient in text.split(separator)]
            # Filter out empty strings and clean up
            ingredients = [ingredient for ingredient in ingredients if ingredient]
            if len(ingredients) > 1:  # Only use this method if we get multiple ingredients
                return ingredients
    
    # If no separators found, try to split by common patterns
    # Look for patterns like "ingredient1, ingredient2, ingredient3"
    if ',' in text:
        ingredients = [ingredient.strip() for ingredient in text.split(',')]
        return [ingredient for ingredient in ingredients if ingredient]
    
    # If all else fails, return the text as a single ingredient
    return [text]

@router.post("/analyze", response_model=IngredientAnalysis)
async def analyze_ingredients_endpoint(
    ingredient_text: str,
    pet_allergies: List[str] = None,
    dietary_restrictions: List[str] = None,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze ingredients for safety and compatibility
    
    Args:
        ingredient_text: Text containing ingredients to analyze
        pet_allergies: List of known pet allergies
        dietary_restrictions: List of dietary restrictions
        current_user: Current authenticated user
        
    Returns:
        Detailed ingredient analysis results
    """
    try:
        if not ingredient_text or not ingredient_text.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ingredient text is required"
            )
        
        return await analyze_ingredients(ingredient_text, pet_allergies, dietary_restrictions)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in ingredient analysis endpoint: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error analyzing ingredients"
        )

@router.get("/allergens", response_model=List[str])
async def get_common_allergens(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of common allergen ingredients
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        List of common allergen ingredient names
    """
    try:
        # Return common allergens that are marked as common
        common_allergens = [
            ingredient for ingredient, info in COMMON_ALLERGENS.items()
            if info.get("common", False)
        ]
        
        return sorted(common_allergens)
        
    except Exception as e:
        logger.error(f"Error fetching common allergens: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching allergens"
        )

@router.get("/safe", response_model=List[str])
async def get_safe_ingredients(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of generally safe ingredients
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        List of generally safe ingredient names
    """
    try:
        # Return ingredients marked as safe
        safe_ingredients = [
            ingredient for ingredient, info in COMMON_ALLERGENS.items()
            if info.get("safety") == "safe"
        ]
        
        return sorted(safe_ingredients)
        
    except Exception as e:
        logger.error(f"Error fetching safe ingredients: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching safe ingredients"
        )

@router.get("/dangerous", response_model=List[str])
async def get_dangerous_ingredients(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get list of dangerous ingredients
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        List of dangerous ingredient names
    """
    try:
        # Return ingredients marked as dangerous
        dangerous_ingredients = [
            ingredient for ingredient, info in COMMON_ALLERGENS.items()
            if info.get("safety") == "dangerous"
        ]
        
        return sorted(dangerous_ingredients)
        
    except Exception as e:
        logger.error(f"Error fetching dangerous ingredients: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching dangerous ingredients"
        )
