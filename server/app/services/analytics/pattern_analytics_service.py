"""
Pattern Analytics Service

Focused service for pattern recognition, behavioral analysis, and feeding patterns.
Extracted from advanced_analytics_service.py for better single responsibility.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
import statistics

from app.database import get_supabase_client
from app.models.advanced_nutrition import NutritionalPatterns


class PatternAnalyticsService:
    """
    Service for pattern recognition and behavioral analysis
    
    Responsibilities:
    - Feeding pattern analysis
    - Behavioral pattern recognition
    - Nutritional pattern identification
    - Seasonal pattern analysis
    """
    
    def __init__(self):
        self.supabase = get_supabase_client()
    
    async def analyze_nutritional_patterns(
        self, 
        pet_id: str, 
        user_id: str,
        date_range: Optional[Dict[str, date]] = None
    ) -> NutritionalPatterns:
        """
        Analyze nutritional patterns for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            date_range: Optional date range for analysis
            
        Returns:
            Nutritional patterns analysis
        """
        try:
            # Get feeding data
            feeding_data = await self._get_feeding_data(pet_id, date_range)
            
            # Analyze feeding patterns
            feeding_patterns = await self._analyze_feeding_patterns(feeding_data)
            
            # Analyze food preferences
            food_preferences = await self._analyze_food_preferences(pet_id, feeding_data)
            
            # Analyze seasonal patterns
            seasonal_patterns = await self._analyze_seasonal_patterns(feeding_data)
            
            # Generate pattern insights
            insights = await self._generate_pattern_insights(feeding_patterns, food_preferences, seasonal_patterns)
            
            return NutritionalPatterns(
                pet_id=pet_id,
                feeding_patterns=feeding_patterns,
                food_preferences=food_preferences,
                seasonal_patterns=seasonal_patterns,
                insights=insights,
                generated_at=datetime.utcnow()
            )
            
        except Exception as e:
            raise Exception(f"Failed to analyze nutritional patterns: {str(e)}")
    
    async def analyze_feeding_times(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[str]:
        """
        Analyze feeding time patterns
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            List of feeding time insights
        """
        try:
            feeding_data = await self._get_feeding_data(pet_id, date_range)
            
            # Extract feeding times
            feeding_times = [record.get("feeding_time", "") for record in feeding_data if record.get("feeding_time")]
            
            if not feeding_times:
                return ["No feeding time data available"]
            
            # Analyze time patterns
            insights = []
            
            # Check for consistency
            unique_times = set(feeding_times)
            if len(unique_times) <= 3:
                insights.append("Consistent feeding schedule detected")
            else:
                insights.append("Variable feeding schedule - consider establishing routine")
            
            # Check for morning vs evening preference
            morning_feedings = [t for t in feeding_times if "morning" in t.lower() or "am" in t.lower()]
            evening_feedings = [t for t in feeding_times if "evening" in t.lower() or "pm" in t.lower()]
            
            if len(morning_feedings) > len(evening_feedings):
                insights.append("Pet shows preference for morning feedings")
            elif len(evening_feedings) > len(morning_feedings):
                insights.append("Pet shows preference for evening feedings")
            
            return insights
            
        except Exception as e:
            raise Exception(f"Failed to analyze feeding times: {str(e)}")
    
    async def analyze_preferred_foods(self, pet_id: str) -> List[str]:
        """
        Analyze preferred foods based on feeding history
        
        Args:
            pet_id: Pet ID
            
        Returns:
            List of preferred foods
        """
        try:
            # Get food preference data
            preference_data = await self._get_food_preference_data(pet_id)
            
            # Analyze preferences
            preferences = []
            
            for record in preference_data:
                food_type = record.get("food_type", "")
                preference_score = record.get("preference_score", 0)
                
                if preference_score > 8:  # High preference threshold
                    preferences.append(f"{food_type} (high preference)")
                elif preference_score > 6:  # Medium preference threshold
                    preferences.append(f"{food_type} (medium preference)")
            
            return preferences if preferences else ["No clear food preferences identified"]
            
        except Exception as e:
            raise Exception(f"Failed to analyze preferred foods: {str(e)}")
    
    async def identify_nutritional_gaps(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[str]:
        """
        Identify nutritional gaps in the diet
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            List of identified nutritional gaps
        """
        try:
            # Get nutritional data
            nutrition_data = await self._get_nutritional_data(pet_id, date_range)
            
            gaps = []
            
            # Analyze protein intake
            protein_levels = [record.get("protein", 0) for record in nutrition_data]
            if protein_levels:
                avg_protein = statistics.mean(protein_levels)
                if avg_protein < 20:  # Example threshold
                    gaps.append("Low protein intake - consider protein-rich foods")
            
            # Analyze fiber intake
            fiber_levels = [record.get("fiber", 0) for record in nutrition_data]
            if fiber_levels:
                avg_fiber = statistics.mean(fiber_levels)
                if avg_fiber < 3:  # Example threshold
                    gaps.append("Low fiber intake - consider fiber-rich foods")
            
            # Analyze vitamin/mineral balance
            vitamin_data = [record.get("vitamins", {}) for record in nutrition_data]
            if vitamin_data:
                # Check for vitamin deficiencies
                gaps.append("Consider vitamin/mineral supplement review")
            
            return gaps if gaps else ["No significant nutritional gaps identified"]
            
        except Exception as e:
            raise Exception(f"Failed to identify nutritional gaps: {str(e)}")
    
    async def _get_feeding_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """
        Get feeding data for analysis
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range
            
        Returns:
            Feeding data records
        """
        # This would contain actual database queries
        return [
            {
                "date": datetime.utcnow().isoformat(),
                "feeding_time": "08:00",
                "food_type": "dry_kibble",
                "amount": 150,
                "duration": 15
            }
        ]
    
    async def _analyze_feeding_patterns(self, feeding_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze feeding patterns from data
        
        Args:
            feeding_data: Feeding data records
            
        Returns:
            Feeding patterns analysis
        """
        return {
            "consistency": "high",
            "meal_frequency": "twice_daily",
            "feeding_duration": "consistent",
            "amount_consistency": "stable"
        }
    
    async def _analyze_food_preferences(self, pet_id: str, feeding_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze food preferences
        
        Args:
            pet_id: Pet ID
            feeding_data: Feeding data records
            
        Returns:
            Food preferences analysis
        """
        return {
            "preferred_foods": ["chicken", "beef"],
            "texture_preferences": ["dry_kibble"],
            "flavor_preferences": ["natural"],
            "preference_consistency": "high"
        }
    
    async def _analyze_seasonal_patterns(self, feeding_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze seasonal patterns in nutrition
        
        Args:
            feeding_data: Feeding data records
            
        Returns:
            Seasonal patterns analysis
        """
        return {
            "seasonal_variation": "minimal",
            "weather_correlation": "none",
            "activity_correlation": "moderate"
        }
    
    async def _generate_pattern_insights(
        self, 
        feeding_patterns: Dict[str, Any], 
        food_preferences: Dict[str, Any], 
        seasonal_patterns: Dict[str, Any]
    ) -> List[str]:
        """
        Generate insights from pattern analysis
        
        Args:
            feeding_patterns: Feeding patterns data
            food_preferences: Food preferences data
            seasonal_patterns: Seasonal patterns data
            
        Returns:
            List of pattern insights
        """
        insights = []
        
        # Feeding pattern insights
        if feeding_patterns.get("consistency") == "high":
            insights.append("Excellent feeding routine consistency")
        
        # Food preference insights
        if len(food_preferences.get("preferred_foods", [])) > 1:
            insights.append("Good variety in food preferences")
        
        # Seasonal pattern insights
        if seasonal_patterns.get("seasonal_variation") == "minimal":
            insights.append("Stable nutrition patterns across seasons")
        
        return insights
    
    async def _get_food_preference_data(self, pet_id: str) -> List[Dict[str, Any]]:
        """
        Get food preference data
        
        Args:
            pet_id: Pet ID
            
        Returns:
            Food preference data
        """
        # This would contain actual database queries
        return [
            {
                "food_type": "chicken",
                "preference_score": 9.5,
                "consumption_rate": 0.95
            }
        ]
    
    async def _get_nutritional_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """
        Get nutritional data for analysis
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range
            
        Returns:
            Nutritional data records
        """
        # This would contain actual database queries
        return [
            {
                "date": datetime.utcnow().isoformat(),
                "protein": 25,
                "fiber": 5,
                "vitamins": {"A": 100, "D": 50}
            }
        ]
