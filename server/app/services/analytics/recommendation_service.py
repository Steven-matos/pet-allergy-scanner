"""
Recommendation Service

Focused service for generating intelligent recommendations based on analytics data.
Extracted from advanced_analytics_service.py for better single responsibility.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
from app.shared.services.datetime_service import DateTimeService

from supabase import Client
from app.models.advanced_nutrition import (
    NutritionalRecommendationCreate, 
    NutritionalRecommendationResponse
)


class RecommendationService:
    """
    Service for generating intelligent recommendations
    
    Responsibilities:
    - Health-based recommendations
    - Nutrition optimization suggestions
    - Behavioral recommendations
    - Preventive care recommendations
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize recommendation service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
    
    async def generate_health_recommendations(
        self, 
        pet_id: str, 
        user_id: str,
        health_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Generate health-based recommendations
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            health_data: Health analytics data
            
        Returns:
            List of health recommendations
        """
        try:
            recommendations = []
            
            # Weight management recommendations
            if health_data.get("weight_trend") == "increasing":
                recommendations.append({
                    "type": "weight_management",
                    "priority": "high",
                    "title": "Weight Management",
                    "description": "Consider portion control and increased activity",
                    "action_items": [
                        "Monitor daily calorie intake",
                        "Increase physical activity",
                        "Consult veterinarian if weight gain continues"
                    ]
                })
            
            # Energy level recommendations
            if health_data.get("energy_level") == "low":
                recommendations.append({
                    "type": "energy_boost",
                    "priority": "medium",
                    "title": "Energy Enhancement",
                    "description": "Support energy levels with nutrition",
                    "action_items": [
                        "Ensure adequate protein intake",
                        "Consider vitamin supplements",
                        "Schedule veterinary checkup"
                    ]
                })
            
            # Coat condition recommendations
            if health_data.get("coat_condition") != "excellent":
                recommendations.append({
                    "type": "coat_health",
                    "priority": "medium",
                    "title": "Coat Health Improvement",
                    "description": "Enhance coat condition through nutrition",
                    "action_items": [
                        "Increase omega-3 fatty acids",
                        "Ensure adequate protein",
                        "Consider coat supplements"
                    ]
                })
            
            return recommendations
            
        except Exception as e:
            raise Exception(f"Failed to generate health recommendations: {str(e)}")
    
    async def generate_nutrition_recommendations(
        self, 
        pet_id: str, 
        nutrition_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Generate nutrition optimization recommendations
        
        Args:
            pet_id: Pet ID
            nutrition_data: Nutrition analytics data
            
        Returns:
            List of nutrition recommendations
        """
        try:
            recommendations = []
            
            # Protein recommendations
            protein_trend = nutrition_data.get("protein_trend", "stable")
            if protein_trend == "decreasing":
                recommendations.append({
                    "type": "protein_optimization",
                    "priority": "medium",
                    "title": "Protein Intake Optimization",
                    "description": "Increase protein intake for muscle maintenance",
                    "action_items": [
                        "Add protein-rich foods to diet",
                        "Consider high-protein treats",
                        "Monitor protein levels weekly"
                    ]
                })
            
            # Fiber recommendations
            fiber_level = nutrition_data.get("fiber_level", 0)
            if fiber_level < 3:  # Example threshold
                recommendations.append({
                    "type": "fiber_enhancement",
                    "priority": "low",
                    "title": "Fiber Intake Enhancement",
                    "description": "Increase fiber for digestive health",
                    "action_items": [
                        "Add fiber-rich vegetables",
                        "Consider fiber supplements",
                        "Gradually increase fiber intake"
                    ]
                })
            
            # Calorie balance recommendations
            calorie_trend = nutrition_data.get("calorie_trend", "stable")
            if calorie_trend == "increasing":
                recommendations.append({
                    "type": "calorie_balance",
                    "priority": "medium",
                    "title": "Calorie Balance",
                    "description": "Monitor calorie intake for weight management",
                    "action_items": [
                        "Track daily calorie intake",
                        "Adjust portion sizes",
                        "Monitor weight weekly"
                    ]
                })
            
            return recommendations
            
        except Exception as e:
            raise Exception(f"Failed to generate nutrition recommendations: {str(e)}")
    
    async def generate_behavioral_recommendations(
        self, 
        pet_id: str, 
        behavioral_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Generate behavioral recommendations
        
        Args:
            pet_id: Pet ID
            behavioral_data: Behavioral analytics data
            
        Returns:
            List of behavioral recommendations
        """
        try:
            recommendations = []
            
            # Feeding consistency recommendations
            feeding_consistency = behavioral_data.get("feeding_consistency", "good")
            if feeding_consistency == "poor":
                recommendations.append({
                    "type": "feeding_routine",
                    "priority": "medium",
                    "title": "Feeding Routine Improvement",
                    "description": "Establish consistent feeding schedule",
                    "action_items": [
                        "Set regular feeding times",
                        "Use feeding reminders",
                        "Maintain consistent meal portions"
                    ]
                })
            
            # Food variety recommendations
            food_variety = behavioral_data.get("food_variety", "good")
            if food_variety == "limited":
                recommendations.append({
                    "type": "food_variety",
                    "priority": "low",
                    "title": "Food Variety Enhancement",
                    "description": "Introduce variety to prevent food boredom",
                    "action_items": [
                        "Gradually introduce new foods",
                        "Rotate protein sources",
                        "Monitor for food preferences"
                    ]
                })
            
            return recommendations
            
        except Exception as e:
            raise Exception(f"Failed to generate behavioral recommendations: {str(e)}")
    
    async def generate_preventive_recommendations(
        self, 
        pet_id: str, 
        preventive_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Generate preventive care recommendations
        
        Args:
            pet_id: Pet ID
            preventive_data: Preventive analytics data
            
        Returns:
            List of preventive recommendations
        """
        try:
            recommendations = []
            
            # Age-based recommendations
            pet_age = preventive_data.get("age", 0)
            if pet_age > 7:  # Senior pet threshold
                recommendations.append({
                    "type": "senior_care",
                    "priority": "high",
                    "title": "Senior Pet Care",
                    "description": "Specialized care for senior pets",
                    "action_items": [
                        "Schedule bi-annual veterinary checkups",
                        "Consider joint health supplements",
                        "Monitor for age-related health changes"
                    ]
                })
            
            # Breed-specific recommendations
            breed = preventive_data.get("breed", "")
            if breed.lower() in ["golden retriever", "labrador"]:
                recommendations.append({
                    "type": "breed_specific",
                    "priority": "medium",
                    "title": "Breed-Specific Health Monitoring",
                    "description": "Monitor for breed-specific health conditions",
                    "action_items": [
                        "Regular hip health monitoring",
                        "Weight management for joint health",
                        "Annual orthopedic screening"
                    ]
                })
            
            # Seasonal recommendations
            from app.shared.services.datetime_service import DateTimeService
            current_month = DateTimeService.now().month
            if current_month in [6, 7, 8]:  # Summer months
                recommendations.append({
                    "type": "seasonal_care",
                    "priority": "medium",
                    "title": "Summer Health Care",
                    "description": "Summer-specific health considerations",
                    "action_items": [
                        "Ensure adequate hydration",
                        "Monitor for heat stress",
                        "Adjust feeding schedule for hot weather"
                    ]
                })
            
            return recommendations
            
        except Exception as e:
            raise Exception(f"Failed to generate preventive recommendations: {str(e)}")
    
    async def save_recommendations(
        self, 
        pet_id: str, 
        user_id: str,
        recommendations: List[Dict[str, Any]]
    ) -> List[NutritionalRecommendationResponse]:
        """
        Save recommendations to database
        
        Args:
            pet_id: Pet ID
            user_id: User ID
            recommendations: List of recommendations to save
            
        Returns:
            List of saved recommendation responses
        """
        try:
            saved_recommendations = []
            
            for rec in recommendations:
                # Create recommendation record
                rec_data = {
                    "pet_id": pet_id,
                    "user_id": user_id,
                    "recommendation_type": rec.get("type", "general"),
                    "priority": rec.get("priority", "medium"),
                    "title": rec.get("title", ""),
                    "description": rec.get("description", ""),
                    "action_items": rec.get("action_items", []),
                    "created_at": DateTimeService.now_iso()
                }
                
                # Save to database
                response = self.supabase.table("nutritional_recommendations")\
                    .insert(rec_data)\
                    .execute()
                
                if response.data:
                    saved_recommendations.append(
                        NutritionalRecommendationResponse(**response.data[0])
                    )
            
            return saved_recommendations
            
        except Exception as e:
            raise Exception(f"Failed to save recommendations: {str(e)}")
    
    async def get_recommendations(
        self, 
        pet_id: str, 
        user_id: str,
        recommendation_type: Optional[str] = None
    ) -> List[NutritionalRecommendationResponse]:
        """
        Get recommendations for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID
            recommendation_type: Optional filter by recommendation type
            
        Returns:
            List of recommendations
        """
        try:
            query = self.supabase.table("nutritional_recommendations")\
                .select("*")\
                .eq("pet_id", pet_id)\
                .eq("user_id", user_id)
            
            if recommendation_type:
                query = query.eq("recommendation_type", recommendation_type)
            
            response = query.order("created_at", desc=True).execute()
            
            return [
                NutritionalRecommendationResponse(**rec) 
                for rec in response.data
            ]
            
        except Exception as e:
            raise Exception(f"Failed to get recommendations: {str(e)}")
