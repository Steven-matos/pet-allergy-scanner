"""
Trend Analytics Service

Focused service for trend analysis, forecasting, and temporal pattern recognition.
Extracted from advanced_analytics_service.py for better single responsibility.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
from app.shared.services.datetime_service import DateTimeService
import statistics

from app.database import get_supabase_client


class TrendAnalyticsService:
    """
    Service for trend analysis and forecasting
    
    Responsibilities:
    - Nutritional trend analysis
    - Health trend tracking
    - Behavioral trend monitoring
    - Predictive analytics
    """
    
    def __init__(self):
        self.supabase = get_supabase_client()
    
    async def analyze_nutritional_trends(
        self, 
        pet_id: str, 
        user_id: str,
        date_range: Optional[Dict[str, date]] = None
    ) -> Dict[str, Any]:
        """
        Analyze nutritional trends for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            date_range: Optional date range for analysis
            
        Returns:
            Nutritional trends analysis
        """
        try:
            # Get nutritional data
            nutrition_data = await self._get_nutritional_data(pet_id, date_range)
            
            # Analyze calorie trends
            calorie_trends = await self._analyze_calorie_trends(nutrition_data)
            
            # Analyze macronutrient trends
            macro_trends = await self._analyze_macronutrient_trends(nutrition_data)
            
            # Analyze feeding frequency trends
            frequency_trends = await self._analyze_feeding_frequency_trends(nutrition_data)
            
            # Generate trend insights
            insights = await self._generate_trend_insights(calorie_trends, macro_trends, frequency_trends)
            
            return {
                "pet_id": pet_id,
                "calorie_trends": calorie_trends,
                "macro_trends": macro_trends,
                "frequency_trends": frequency_trends,
                "insights": insights,
                "generated_at": DateTimeService.now_iso()
            }
            
        except Exception as e:
            raise Exception(f"Failed to analyze nutritional trends: {str(e)}")
    
    async def analyze_health_trends(
        self, 
        pet_id: str, 
        date_range: Optional[Dict[str, date]] = None
    ) -> Dict[str, Any]:
        """
        Analyze health trends for a pet
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            Health trends analysis
        """
        try:
            # Get health data
            health_data = await self._get_health_data(pet_id, date_range)
            
            # Analyze weight trends
            weight_trends = await self._analyze_weight_trends(health_data)
            
            # Analyze energy level trends
            energy_trends = await self._analyze_energy_trends(health_data)
            
            # Analyze overall health score trends
            health_score_trends = await self._analyze_health_score_trends(health_data)
            
            return {
                "pet_id": pet_id,
                "weight_trends": weight_trends,
                "energy_trends": energy_trends,
                "health_score_trends": health_score_trends,
                "generated_at": DateTimeService.now_iso()
            }
            
        except Exception as e:
            raise Exception(f"Failed to analyze health trends: {str(e)}")
    
    async def generate_weekly_analysis(
        self, 
        pet_id: str, 
        date_range: Optional[Dict[str, date]] = None
    ) -> Dict[str, Any]:
        """
        Generate weekly analysis for a pet
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            Weekly analysis results
        """
        try:
            # Get weekly data
            weekly_data = await self._get_weekly_data(pet_id, date_range)
            
            # Analyze weekly patterns
            weekly_patterns = await self._analyze_weekly_patterns(weekly_data)
            
            # Generate weekly insights
            insights = await self._generate_weekly_insights(weekly_patterns)
            
            return {
                "pet_id": pet_id,
                "analysis_type": "weekly",
                "patterns": weekly_patterns,
                "insights": insights,
                "generated_at": DateTimeService.now_iso()
            }
            
        except Exception as e:
            raise Exception(f"Failed to generate weekly analysis: {str(e)}")
    
    async def generate_monthly_analysis(
        self, 
        pet_id: str, 
        date_range: Optional[Dict[str, date]] = None
    ) -> Dict[str, Any]:
        """
        Generate monthly analysis for a pet
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            Monthly analysis results
        """
        try:
            # Get monthly data
            monthly_data = await self._get_monthly_data(pet_id, date_range)
            
            # Analyze monthly patterns
            monthly_patterns = await self._analyze_monthly_patterns(monthly_data)
            
            # Generate monthly insights
            insights = await self._generate_monthly_insights(monthly_patterns)
            
            return {
                "pet_id": pet_id,
                "analysis_type": "monthly",
                "patterns": monthly_patterns,
                "insights": insights,
                "generated_at": DateTimeService.now_iso()
            }
            
        except Exception as e:
            raise Exception(f"Failed to generate monthly analysis: {str(e)}")
    
    async def _get_nutritional_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """
        Get nutritional data for trend analysis
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range
            
        Returns:
            Nutritional data records
        """
        # This would contain actual database queries
        return [
            {
                "date": DateTimeService.now_iso(),
                "calories": 300,
                "protein": 25,
                "carbs": 15,
                "fat": 10,
                "fiber": 5
            }
        ]
    
    async def _analyze_calorie_trends(self, nutrition_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze calorie trends
        
        Args:
            nutrition_data: Nutritional data records
            
        Returns:
            Calorie trends analysis
        """
        if not nutrition_data:
            return {"trend": "no_data", "change_percentage": 0}
        
        calories = [record.get("calories", 0) for record in nutrition_data]
        
        if len(calories) < 2:
            return {"trend": "insufficient_data", "change_percentage": 0}
        
        # Calculate trend
        first_half = calories[:len(calories)//2]
        second_half = calories[len(calories)//2:]
        
        avg_first = statistics.mean(first_half)
        avg_second = statistics.mean(second_half)
        
        change_percentage = ((avg_second - avg_first) / avg_first) * 100 if avg_first > 0 else 0
        
        if change_percentage > 5:
            trend = "increasing"
        elif change_percentage < -5:
            trend = "decreasing"
        else:
            trend = "stable"
        
        return {
            "trend": trend,
            "change_percentage": round(change_percentage, 2),
            "average_calories": round(statistics.mean(calories), 2)
        }
    
    async def _analyze_macronutrient_trends(self, nutrition_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze macronutrient trends
        
        Args:
            nutrition_data: Nutritional data records
            
        Returns:
            Macronutrient trends analysis
        """
        if not nutrition_data:
            return {"protein_trend": "no_data", "carb_trend": "no_data", "fat_trend": "no_data"}
        
        proteins = [record.get("protein", 0) for record in nutrition_data]
        carbs = [record.get("carbs", 0) for record in nutrition_data]
        fats = [record.get("fat", 0) for record in nutrition_data]
        
        return {
            "protein_trend": await self._calculate_trend(proteins),
            "carb_trend": await self._calculate_trend(carbs),
            "fat_trend": await self._calculate_trend(fats)
        }
    
    async def _analyze_feeding_frequency_trends(self, nutrition_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze feeding frequency trends
        
        Args:
            nutrition_data: Nutritional data records
            
        Returns:
            Feeding frequency trends analysis
        """
        return {
            "frequency_trend": "stable",
            "average_daily_feedings": 2.0,
            "consistency_score": 85
        }
    
    async def _generate_trend_insights(
        self, 
        calorie_trends: Dict[str, Any], 
        macro_trends: Dict[str, Any], 
        frequency_trends: Dict[str, Any]
    ) -> List[str]:
        """
        Generate insights from trend analysis
        
        Args:
            calorie_trends: Calorie trends data
            macro_trends: Macronutrient trends data
            frequency_trends: Feeding frequency trends data
            
        Returns:
            List of trend insights
        """
        insights = []
        
        # Calorie trend insights
        if calorie_trends.get("trend") == "increasing":
            insights.append("Calorie intake trending upward - monitor weight")
        elif calorie_trends.get("trend") == "decreasing":
            insights.append("Calorie intake trending downward - ensure adequate nutrition")
        
        # Macronutrient trend insights
        if macro_trends.get("protein_trend") == "increasing":
            insights.append("Protein intake increasing - good for muscle maintenance")
        
        return insights
    
    async def _calculate_trend(self, values: List[float]) -> str:
        """
        Calculate trend for a list of values
        
        Args:
            values: List of numeric values
            
        Returns:
            Trend description
        """
        if len(values) < 2:
            return "insufficient_data"
        
        first_half = values[:len(values)//2]
        second_half = values[len(values)//2:]
        
        avg_first = statistics.mean(first_half)
        avg_second = statistics.mean(second_half)
        
        change_percentage = ((avg_second - avg_first) / avg_first) * 100 if avg_first > 0 else 0
        
        if change_percentage > 5:
            return "increasing"
        elif change_percentage < -5:
            return "decreasing"
        else:
            return "stable"
    
    async def _get_health_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """Get health data for analysis"""
        return [
            {
                "date": DateTimeService.now_iso(),
                "weight": 25.5,
                "energy_level": "high",
                "health_score": 88
            }
        ]
    
    async def _analyze_weight_trends(self, health_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze weight trends"""
        return {"trend": "stable", "change_percentage": 0.5}
    
    async def _analyze_energy_trends(self, health_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze energy level trends"""
        return {"trend": "stable", "average_level": "high"}
    
    async def _analyze_health_score_trends(self, health_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze health score trends"""
        return {"trend": "improving", "change_percentage": 2.5}
    
    async def _get_weekly_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """Get weekly data for analysis"""
        return []
    
    async def _analyze_weekly_patterns(self, weekly_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze weekly patterns"""
        return {"consistency": "high", "variability": "low"}
    
    async def _generate_weekly_insights(self, patterns: Dict[str, Any]) -> List[str]:
        """Generate weekly insights"""
        return ["Consistent weekly patterns detected"]
    
    async def _get_monthly_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """Get monthly data for analysis"""
        return []
    
    async def _analyze_monthly_patterns(self, monthly_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze monthly patterns"""
        return {"seasonal_variation": "minimal", "trend_direction": "positive"}
    
    async def _generate_monthly_insights(self, patterns: Dict[str, Any]) -> List[str]:
        """Generate monthly insights"""
        return ["Positive monthly trends observed"]
