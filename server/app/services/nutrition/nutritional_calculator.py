"""
Nutritional calculation service for pet food analysis
Implements AAFCO guidelines and nutritional recommendations
"""

from typing import Dict, Optional, Tuple
from decimal import Decimal, ROUND_HALF_UP
import math
from app.models.nutrition.nutritional_standards import (
    NutritionalStandardResponse, 
    NutritionalRecommendation,
    Species,
    LifeStage,
    ActivityLevel
)
from app.models.scanning.scan import NutritionalAnalysis


class NutritionalCalculator:
    """
    Service for calculating nutritional values and recommendations
    Follows AAFCO guidelines for pet nutrition
    """
    
    def __init__(self):
        self.calorie_conversion_factors = {
            'protein': 3.5,  # kcal per gram
            'fat': 8.5,      # kcal per gram
            'carbohydrate': 3.5,  # kcal per gram
            'fiber': 0,      # no calories
        }
    
    def calculate_calories_per_100g(
        self, 
        protein_percent: float, 
        fat_percent: float, 
        fiber_percent: float,
        moisture_percent: float,
        ash_percent: float
    ) -> float:
        """
        Calculate calories per 100g using Atwater factors
        
        Args:
            protein_percent: Protein percentage (dry matter basis)
            fat_percent: Fat percentage (dry matter basis)
            fiber_percent: Fiber percentage (dry matter basis)
            moisture_percent: Moisture percentage
            ash_percent: Ash percentage (dry matter basis)
            
        Returns:
            Calories per 100g
        """
        # Convert to dry matter basis
        dry_matter_percent = 100 - moisture_percent
        
        if dry_matter_percent <= 0:
            return 0.0
        
        # Convert percentages to dry matter basis
        protein_dm = (protein_percent / dry_matter_percent) * 100
        fat_dm = (fat_percent / dry_matter_percent) * 100
        fiber_dm = (fiber_percent / dry_matter_percent) * 100
        ash_dm = (ash_percent / dry_matter_percent) * 100
        
        # Calculate carbohydrate percentage (dry matter basis)
        # Carbohydrates = 100 - protein - fat - fiber - ash
        carb_dm = 100 - protein_dm - fat_dm - fiber_dm - ash_dm
        
        # Calculate calories using Atwater factors
        protein_calories = protein_dm * self.calorie_conversion_factors['protein']
        fat_calories = fat_dm * self.calorie_conversion_factors['fat']
        carb_calories = max(0, carb_dm) * self.calorie_conversion_factors['carbohydrate']
        
        total_calories_dm = protein_calories + fat_calories + carb_calories
        
        # Convert back to as-fed basis
        calories_per_100g = (total_calories_dm / 100) * dry_matter_percent
        
        return round(calories_per_100g, 1)
    
    def calculate_daily_calorie_needs(
        self,
        weight_kg: float,
        species: Species,
        life_stage: LifeStage,
        activity_level: ActivityLevel,
        age_months: Optional[int] = None
    ) -> float:
        """
        Calculate daily calorie needs based on pet characteristics
        
        Args:
            weight_kg: Pet weight in kilograms
            species: Dog or cat
            life_stage: Puppy, adult, senior, pregnant, lactating
            activity_level: Low, moderate, high
            age_months: Age in months (for puppies/kittens)
            
        Returns:
            Daily calorie needs
        """
        # Base calorie requirements per kg
        base_calories_per_kg = self._get_base_calories_per_kg(species, life_stage, age_months)
        
        # Activity level multiplier
        activity_multiplier = self._get_activity_multiplier(activity_level)
        
        # Life stage adjustments
        life_stage_multiplier = self._get_life_stage_multiplier(life_stage, species, age_months)
        
        # Calculate daily needs
        daily_calories = weight_kg * base_calories_per_kg * activity_multiplier * life_stage_multiplier
        
        return round(daily_calories, 0)
    
    def analyze_nutritional_adequacy(
        self,
        nutritional_analysis: NutritionalAnalysis,
        pet_weight_kg: float,
        species: Species,
        life_stage: LifeStage,
        activity_level: ActivityLevel
    ) -> Dict[str, any]:
        """
        Analyze if pet food meets nutritional requirements
        
        Args:
            nutritional_analysis: Extracted nutritional data
            pet_weight_kg: Pet weight in kilograms
            species: Dog or cat
            life_stage: Pet life stage
            activity_level: Pet activity level
            
        Returns:
            Analysis results with recommendations
        """
        # Get nutritional standards for this pet
        standards = self._get_nutritional_standards(species, life_stage, pet_weight_kg, activity_level)
        
        if not standards:
            return {"error": "No nutritional standards found for this pet profile"}
        
        analysis = {
            "suitable_for_pet": True,
            "warnings": [],
            "recommendations": [],
            "daily_servings": None,
            "calorie_contribution_percent": None
        }
        
        # Calculate daily calorie needs
        daily_calories_needed = self.calculate_daily_calorie_needs(
            pet_weight_kg, species, life_stage, activity_level
        )
        
        # Analyze macronutrients if available
        if nutritional_analysis.macronutrients:
            macronutrients = nutritional_analysis.macronutrients
            
            # Check protein adequacy
            protein_percent = macronutrients.get('protein_percent', 0)
            if protein_percent < standards.protein_min_percent:
                analysis["warnings"].append(
                    f"Protein content ({protein_percent}%) is below recommended minimum ({standards.protein_min_percent}%)"
                )
                analysis["suitable_for_pet"] = False
            
            # Check fat adequacy
            fat_percent = macronutrients.get('fat_percent', 0)
            if fat_percent < standards.fat_min_percent:
                analysis["warnings"].append(
                    f"Fat content ({fat_percent}%) is below recommended minimum ({standards.fat_min_percent}%)"
                )
                analysis["suitable_for_pet"] = False
            
            # Check fiber limits
            fiber_percent = macronutrients.get('fiber_percent', 0)
            if fiber_percent > standards.fiber_max_percent:
                analysis["warnings"].append(
                    f"Fiber content ({fiber_percent}%) exceeds recommended maximum ({standards.fiber_max_percent}%)"
                )
            
            # Check moisture limits
            moisture_percent = macronutrients.get('moisture_percent', 0)
            if moisture_percent > standards.moisture_max_percent:
                analysis["warnings"].append(
                    f"Moisture content ({moisture_percent}%) exceeds recommended maximum ({standards.moisture_max_percent}%)"
                )
        
        # Calculate serving recommendations
        if nutritional_analysis.calories_per_serving and nutritional_analysis.serving_size_g:
            daily_servings = daily_calories_needed / nutritional_analysis.calories_per_serving
            analysis["daily_servings"] = round(daily_servings, 1)
            
            # Calculate calorie contribution percentage
            if daily_servings > 0:
                calorie_contribution = (nutritional_analysis.calories_per_serving * daily_servings) / daily_calories_needed * 100
                analysis["calorie_contribution_percent"] = round(calorie_contribution, 1)
        
        # Add general recommendations
        if analysis["suitable_for_pet"]:
            analysis["recommendations"].append("This food appears suitable for your pet's nutritional needs")
        
        if life_stage == LifeStage.PUPPY:
            analysis["recommendations"].append("Ensure food is specifically formulated for growing puppies")
        elif life_stage == LifeStage.SENIOR:
            analysis["recommendations"].append("Consider senior-specific formulas for optimal health")
        
        return analysis
    
    def _get_base_calories_per_kg(
        self, 
        species: Species, 
        life_stage: LifeStage, 
        age_months: Optional[int]
    ) -> float:
        """Get base calories per kg based on species and life stage"""
        if species == Species.DOG:
            if life_stage == LifeStage.PUPPY:
                if age_months and age_months < 4:
                    return 200  # Very young puppies
                elif age_months and age_months < 12:
                    return 160  # Older puppies
                else:
                    return 140  # Adult maintenance
            elif life_stage == LifeStage.ADULT:
                return 120
            elif life_stage == LifeStage.SENIOR:
                return 100
            elif life_stage in [LifeStage.PREGNANT, LifeStage.LACTATING]:
                return 200
        elif species == Species.CAT:
            if life_stage == LifeStage.PUPPY:
                if age_months and age_months < 4:
                    return 250  # Very young kittens
                elif age_months and age_months < 12:
                    return 200  # Older kittens
                else:
                    return 140  # Adult maintenance
            elif life_stage == LifeStage.ADULT:
                return 120
            elif life_stage == LifeStage.SENIOR:
                return 100
            elif life_stage in [LifeStage.PREGNANT, LifeStage.LACTATING]:
                return 250
        
        return 120  # Default adult maintenance
    
    def _get_activity_multiplier(self, activity_level: ActivityLevel) -> float:
        """Get activity level multiplier"""
        multipliers = {
            ActivityLevel.LOW: 0.8,
            ActivityLevel.MODERATE: 1.0,
            ActivityLevel.HIGH: 1.4
        }
        return multipliers.get(activity_level, 1.0)
    
    def _get_life_stage_multiplier(
        self, 
        life_stage: LifeStage, 
        species: Species, 
        age_months: Optional[int]
    ) -> float:
        """Get life stage multiplier"""
        if life_stage == LifeStage.PUPPY:
            if age_months and age_months < 4:
                return 2.0  # Very young animals need more calories
            elif age_months and age_months < 12:
                return 1.5  # Growing animals
            else:
                return 1.2  # Young adults
        elif life_stage == LifeStage.PREGNANT:
            return 1.5
        elif life_stage == LifeStage.LACTATING:
            return 2.0
        else:
            return 1.0
    
    def _get_nutritional_standards(
        self,
        species: Species,
        life_stage: LifeStage,
        weight_kg: float,
        activity_level: ActivityLevel
    ) -> Optional[NutritionalStandardResponse]:
        """
        Get nutritional standards for the pet
        This would typically query the database
        For now, return a mock standard
        """
        # This is a simplified version - in production, this would query the database
        return NutritionalStandardResponse(
            id="mock-standard",
            species=species,
            life_stage=life_stage,
            weight_range_min=0.5,
            weight_range_max=50.0,
            activity_level=activity_level,
            calories_per_kg=120.0,
            protein_min_percent=18.0,
            fat_min_percent=5.0,
            fiber_max_percent=4.0,
            moisture_max_percent=78.0,
            ash_max_percent=6.0,
            calcium_min_percent=0.6,
            phosphorus_min_percent=0.5,
            created_at=None,
            updated_at=None
        )
