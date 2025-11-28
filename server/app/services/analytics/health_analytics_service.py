"""
Health Analytics Service

Focused service for health insights, risk analysis, and health-related recommendations.
Extracted from advanced_analytics_service.py for better single responsibility.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
from app.shared.services.datetime_service import DateTimeService
from decimal import Decimal
import statistics

from supabase import Client
from app.models.advanced_nutrition import HealthInsights


class HealthAnalyticsService:
    """
    Service for health-focused analytics and insights
    
    Responsibilities:
    - Health risk analysis
    - Health insights generation
    - Health recommendations
    - Weight management analysis
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize health analytics service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
    
    async def get_health_insights(
        self, 
        pet_id: str, 
        user_id: str,
        date_range: Optional[Dict[str, date]] = None
    ) -> HealthInsights:
        """
        Generate comprehensive health insights for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            date_range: Optional date range for analysis
            
        Returns:
            Health insights data
        """
        try:
            # Get health data for the period
            health_data = await self._get_health_data(pet_id, date_range)
            
            # Analyze health trends
            health_trends = await self._analyze_health_trends(health_data)
            
            # Identify health risks
            health_risks = await self._identify_health_risks(health_data)
            
            # Generate health recommendations
            recommendations = await self._generate_health_recommendations(health_data, health_risks)
            
            # Calculate overall health score
            health_score = await self._calculate_overall_health_score(health_data)
            
            return HealthInsights(
                pet_id=pet_id,
                health_score=health_score,
                trends=health_trends,
                risks=health_risks,
                recommendations=recommendations,
                generated_at=DateTimeService.now()
            )
            
        except Exception as e:
            raise Exception(f"Failed to generate health insights: {str(e)}")
    
    async def analyze_weight_management(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> Dict[str, Any]:
        """
        Analyze weight management status and trends
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range for analysis
            
        Returns:
            Weight management analysis
        """
        try:
            # Get weight data
            weight_data = await self._get_weight_data(pet_id, date_range)
            
            # Analyze weight trends
            weight_trend = await self._analyze_weight_trend(weight_data)
            
            # Calculate weight management score
            management_score = await self._calculate_weight_management_score(weight_data)
            
            # Generate weight recommendations
            recommendations = await self._generate_weight_recommendations(weight_data, weight_trend)
            
            return {
                "pet_id": pet_id,
                "weight_trend": weight_trend,
                "management_score": management_score,
                "recommendations": recommendations,
                "analysis_date": DateTimeService.now_iso()
            }
            
        except Exception as e:
            raise Exception(f"Failed to analyze weight management: {str(e)}")
    
    async def _get_health_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """
        Get health data for analysis
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range
            
        Returns:
            Health data records
        """
        # This would contain actual database queries
        # For now, return placeholder data
        return [
            {
                "date": DateTimeService.now_iso(),
                "weight": 25.5,
                "energy_level": "high",
                "coat_condition": "excellent",
                "digestive_health": "good"
            }
        ]
    
    async def _analyze_health_trends(self, health_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze health trends from data
        
        Args:
            health_data: Health data records
            
        Returns:
            Health trends analysis
        """
        return {
            "weight_trend": "stable",
            "energy_trend": "improving",
            "coat_condition_trend": "excellent",
            "digestive_health_trend": "stable"
        }
    
    async def _identify_health_risks(self, health_data: List[Dict[str, Any]]) -> List[str]:
        """
        Identify potential health risks
        
        Args:
            health_data: Health data records
            
        Returns:
            List of identified health risks
        """
        risks = []
        
        # Analyze weight trends
        if len(health_data) > 1:
            weights = [record.get("weight", 0) for record in health_data]
            if weights and max(weights) - min(weights) > 2:
                risks.append("Significant weight fluctuation detected")
        
        # Analyze energy levels
        energy_levels = [record.get("energy_level", "") for record in health_data]
        if "low" in energy_levels:
            risks.append("Low energy levels detected")
        
        return risks
    
    async def _generate_health_recommendations(
        self, 
        health_data: List[Dict[str, Any]], 
        health_risks: List[str]
    ) -> List[str]:
        """
        Generate health recommendations based on data and risks
        
        Args:
            health_data: Health data records
            health_risks: Identified health risks
            
        Returns:
            List of health recommendations
        """
        recommendations = []
        
        if not health_risks:
            recommendations.append("Continue current health monitoring routine")
            recommendations.append("Maintain current nutrition plan")
        else:
            for risk in health_risks:
                if "weight fluctuation" in risk.lower():
                    recommendations.append("Monitor weight weekly and consult veterinarian")
                elif "low energy" in risk.lower():
                    recommendations.append("Consider nutrition review and veterinary consultation")
        
        return recommendations
    
    async def _calculate_overall_health_score(self, health_data: List[Dict[str, Any]]) -> float:
        """
        Calculate overall health score
        
        Args:
            health_data: Health data records
            
        Returns:
            Overall health score (0-100)
        """
        if not health_data:
            return 0.0
        
        # Calculate score based on various health indicators
        scores = []
        
        for record in health_data:
            score = 0
            
            # Weight score (assuming optimal range)
            weight = record.get("weight", 0)
            if 20 <= weight <= 30:  # Example optimal range
                score += 25
            
            # Energy level score
            energy = record.get("energy_level", "")
            if energy == "high":
                score += 25
            elif energy == "medium":
                score += 15
            
            # Coat condition score
            coat = record.get("coat_condition", "")
            if coat == "excellent":
                score += 25
            elif coat == "good":
                score += 20
            
            # Digestive health score
            digestive = record.get("digestive_health", "")
            if digestive == "good":
                score += 25
            elif digestive == "fair":
                score += 15
            
            scores.append(score)
        
        return sum(scores) / len(scores) if scores else 0.0
    
    async def _get_weight_data(self, pet_id: str, date_range: Optional[Dict[str, date]] = None) -> List[Dict[str, Any]]:
        """
        Get weight data for analysis
        
        Args:
            pet_id: Pet ID
            date_range: Optional date range
            
        Returns:
            Weight data records
        """
        # This would contain actual database queries
        return [
            {
                "date": DateTimeService.now_iso(),
                "weight": 25.5,
                "weight_change": 0.2
            }
        ]
    
    async def _analyze_weight_trend(self, weight_data: List[Dict[str, Any]]) -> str:
        """
        Analyze weight trend
        
        Args:
            weight_data: Weight data records
            
        Returns:
            Weight trend description
        """
        if len(weight_data) < 2:
            return "insufficient_data"
        
        weights = [record.get("weight", 0) for record in weight_data]
        if weights:
            if weights[-1] > weights[0]:
                return "increasing"
            elif weights[-1] < weights[0]:
                return "decreasing"
            else:
                return "stable"
        
        return "stable"
    
    async def _calculate_weight_management_score(self, weight_data: List[Dict[str, Any]]) -> float:
        """
        Calculate weight management score
        
        Args:
            weight_data: Weight data records
            
        Returns:
            Weight management score (0-100)
        """
        if not weight_data:
            return 0.0
        
        # Calculate consistency score
        weights = [record.get("weight", 0) for record in weight_data]
        if len(weights) > 1:
            variance = statistics.variance(weights)
            consistency_score = max(0, 100 - (variance * 10))
            return min(100, consistency_score)
        
        return 85.0  # Default score for single data point
    
    async def _generate_weight_recommendations(
        self, 
        weight_data: List[Dict[str, Any]], 
        weight_trend: str
    ) -> List[str]:
        """
        Generate weight management recommendations
        
        Args:
            weight_data: Weight data records
            weight_trend: Weight trend analysis
            
        Returns:
            List of weight recommendations
        """
        recommendations = []
        
        if weight_trend == "increasing":
            recommendations.append("Monitor calorie intake and consider portion control")
            recommendations.append("Increase physical activity if appropriate")
        elif weight_trend == "decreasing":
            recommendations.append("Ensure adequate calorie intake")
            recommendations.append("Monitor for any health concerns")
        else:
            recommendations.append("Maintain current weight management routine")
            recommendations.append("Continue regular weight monitoring")
        
        return recommendations
