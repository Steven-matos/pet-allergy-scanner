"""
Advanced Analytics Service
Handles complex nutritional analytics, pattern recognition, and predictive insights
"""

from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime, date, timedelta
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from decimal import Decimal
import statistics
import json
from supabase import Client
from app.models.nutrition.advanced_nutrition import (
    AnalyticsType, NutritionalAnalyticsCacheResponse,
    HealthInsights, NutritionalPatterns,
    NutritionalRecommendationCreate, NutritionalRecommendationResponse
)


class AdvancedAnalyticsService:
    """
    Service for advanced nutritional analytics and insights generation
    
    Follows SOLID principles with single responsibility for analytics
    Implements DRY by reusing common analysis methods
    Follows KISS by keeping analytics methods focused and simple
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize advanced analytics service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
    
    async def generate_analytics(
        self, 
        pet_id: str, 
        user_id: str,
        analysis_type: AnalyticsType,
        force_refresh: bool = False,
        date_range: Optional[Dict[str, date]] = None
    ) -> NutritionalAnalyticsCacheResponse:
        """
        Generate advanced analytics for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            analysis_type: Type of analysis to perform
            force_refresh: Force regeneration even if cache exists
            date_range: Optional date range for analysis
            
        Returns:
            Analytics cache response
        """
        # Check for existing cache
        # Note: Pet ownership is verified by the router before calling this method
        if not force_refresh:
            cached = await self._get_cached_analytics(pet_id, analysis_type)
            if cached and cached.expires_at > DateTimeService.now():
                return cached
        
        # Generate new analytics
        analysis_data = await self._perform_analysis(pet_id, analysis_type, date_range)
        
        # Cache the results
        cache_response = await self._cache_analytics(pet_id, analysis_type, analysis_data)
        
        return cache_response
    
    async def get_health_insights(
        self, 
        pet_id: str, 
        user_id: str
    ) -> HealthInsights:
        """
        Get comprehensive health insights for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            
        Returns:
            Health insights data (with default values if no data exists)
        """
        # Get recent trends (last 30 days)
        # Note: Pet ownership is verified by the router before calling this method
        trends_response = self.supabase.table("nutritional_trends")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .gte("trend_date", (DateTimeService.now() - timedelta(days=30)).date().isoformat())\
            .order("trend_date", descending=True)\
            .execute()
        
        trends = trends_response.data
        
        if not trends:
            return HealthInsights(
                pet_id=pet_id,
                analysis_date=date.today(),
                weight_management_status="no_data",
                nutritional_adequacy_score=0.0,
                feeding_consistency_score=0.0,
                health_risks=["Insufficient data for analysis"],
                positive_indicators=[],
                recommendations=[],
                overall_health_score=0.0
            )
        
        # Analyze weight management
        weight_status = await self._analyze_weight_management(trends)
        
        # Calculate nutritional adequacy score
        adequacy_score = self._calculate_nutritional_adequacy_score(trends)
        
        # Calculate feeding consistency score
        consistency_score = self._calculate_feeding_consistency_score(trends)
        
        # Identify health risks
        health_risks = await self._identify_health_risks(trends, weight_status)
        
        # Identify positive indicators
        positive_indicators = await self._identify_positive_indicators(trends)
        
        # Generate recommendations
        recommendations = await self._generate_health_recommendations(
            pet_id, trends, weight_status, adequacy_score, consistency_score
        )
        
        # Calculate overall health score
        overall_score = self._calculate_overall_health_score(
            adequacy_score, consistency_score, weight_status, len(health_risks)
        )
        
        return HealthInsights(
            pet_id=pet_id,
            analysis_date=date.today(),
            weight_management_status=weight_status,
            nutritional_adequacy_score=round(adequacy_score, 1),
            feeding_consistency_score=round(consistency_score, 1),
            health_risks=health_risks,
            positive_indicators=positive_indicators,
            recommendations=recommendations,
            overall_health_score=round(overall_score, 1)
        )
    
    async def analyze_nutritional_patterns(
        self, 
        pet_id: str, 
        user_id: str,
        analysis_period: str = "30_days"
    ) -> NutritionalPatterns:
        """
        Analyze nutritional patterns for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            analysis_period: Period for analysis (7_days, 30_days, 90_days)
            
        Returns:
            Nutritional patterns analysis (with default values if no data exists)
        """
        # Get trends based on period
        # Note: Pet ownership is verified by the router before calling this method
        days_map = {"7_days": 7, "30_days": 30, "90_days": 90}
        days_back = days_map.get(analysis_period, 30)
        
        trends_response = self.supabase.table("nutritional_trends")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .gte("trend_date", (DateTimeService.now() - timedelta(days=days_back)).date().isoformat())\
            .order("trend_date", descending=True)\
            .execute()
        
        trends = trends_response.data
        
        if not trends:
            return NutritionalPatterns(
                pet_id=pet_id,
                analysis_period=analysis_period,
                feeding_times=[],
                preferred_foods=[],
                nutritional_gaps=[],
                seasonal_patterns={},
                behavioral_insights=[],
                optimization_suggestions=[]
            )
        
        # Analyze feeding times
        feeding_times = await self._analyze_feeding_times(trends)
        
        # Analyze preferred foods
        preferred_foods = await self._analyze_preferred_foods(pet_id)
        
        # Identify nutritional gaps
        nutritional_gaps = await self._identify_nutritional_gaps(trends)
        
        # Analyze seasonal patterns
        seasonal_patterns = await self._analyze_seasonal_patterns(trends)
        
        # Generate behavioral insights
        behavioral_insights = await self._generate_behavioral_insights(trends, feeding_times)
        
        # Generate optimization suggestions
        optimization_suggestions = await self._generate_optimization_suggestions(
            trends, nutritional_gaps, behavioral_insights
        )
        
        return NutritionalPatterns(
            pet_id=pet_id,
            analysis_period=analysis_period,
            feeding_times=feeding_times,
            preferred_foods=preferred_foods,
            nutritional_gaps=nutritional_gaps,
            seasonal_patterns=seasonal_patterns,
            behavioral_insights=behavioral_insights,
            optimization_suggestions=optimization_suggestions
        )
    
    async def _get_cached_analytics(
        self, 
        pet_id: str, 
        analysis_type: AnalyticsType
    ) -> Optional[NutritionalAnalyticsCacheResponse]:
        """Get cached analytics if available and not expired"""
        response = self.supabase.table("nutritional_analytics_cache")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .eq("analysis_type", analysis_type.value)\
            .gt("expires_at", DateTimeService.now_iso())\
            .order("generated_at", descending=True)\
            .limit(1)\
            .execute()
        
        if response.data:
            return NutritionalAnalyticsCacheResponse(**response.data[0])
        
        return None
    
    async def _perform_analysis(
        self, 
        pet_id: str, 
        analysis_type: AnalyticsType,
        date_range: Optional[Dict[str, date]] = None
    ) -> Dict[str, Any]:
        """Perform the specified analysis type"""
        if analysis_type == AnalyticsType.WEEKLY_SUMMARY:
            return await self._generate_weekly_analysis(pet_id, date_range)
        elif analysis_type == AnalyticsType.MONTHLY_TRENDS:
            return await self._generate_monthly_analysis(pet_id, date_range)
        elif analysis_type == AnalyticsType.HEALTH_INSIGHTS:
            return await self._generate_health_analysis(pet_id, date_range)
        elif analysis_type == AnalyticsType.WEIGHT_ANALYSIS:
            return await self._generate_weight_analysis(pet_id, date_range)
        elif analysis_type == AnalyticsType.NUTRITIONAL_PATTERNS:
            return await self._generate_pattern_analysis(pet_id, date_range)
        else:
            raise ValueError(f"Unknown analysis type: {analysis_type}")
    
    async def _cache_analytics(
        self, 
        pet_id: str, 
        analysis_type: AnalyticsType,
        analysis_data: Dict[str, Any]
    ) -> NutritionalAnalyticsCacheResponse:
        """Cache analytics results"""
        # Set expiration time based on analysis type
        expiration_hours = {
            AnalyticsType.WEEKLY_SUMMARY: 24,
            AnalyticsType.MONTHLY_TRENDS: 72,
            AnalyticsType.HEALTH_INSIGHTS: 48,
            AnalyticsType.WEIGHT_ANALYSIS: 24,
            AnalyticsType.NUTRITIONAL_PATTERNS: 72
        }
        
        expires_at = DateTimeService.now() + timedelta(hours=expiration_hours.get(analysis_type, 24))
        
        cache_data = {
            "pet_id": pet_id,
            "analysis_type": analysis_type.value,
            "analysis_data": analysis_data,
            "expires_at": expires_at.isoformat()
        }
        
        db_service = DatabaseOperationService(self.supabase)
        result = await db_service.insert_with_timestamps("nutritional_analytics_cache", cache_data)
        
        return NutritionalAnalyticsCacheResponse(**result)
    
    async def _analyze_weight_management(self, trends: List[Dict[str, Any]]) -> str:
        """Analyze weight management status"""
        if not trends:
            return "no_data"
        
        # Calculate total weight change
        total_weight_change = sum(trend.get("weight_change_kg", 0) for trend in trends)
        
        if total_weight_change > 1.0:
            return "weight_gain"
        elif total_weight_change < -1.0:
            return "weight_loss"
        else:
            return "stable"
    
    def _calculate_nutritional_adequacy_score(self, trends: List[Dict[str, Any]]) -> float:
        """Calculate nutritional adequacy score"""
        if not trends:
            return 0.0
        
        compatibility_scores = [trend.get("average_compatibility_score", 0) for trend in trends]
        return statistics.mean(compatibility_scores)
    
    def _calculate_feeding_consistency_score(self, trends: List[Dict[str, Any]]) -> float:
        """Calculate feeding consistency score"""
        if not trends or len(trends) < 2:
            return 0.0
        
        feeding_counts = [trend.get("feeding_count", 0) for trend in trends]
        
        # Calculate coefficient of variation (lower is more consistent)
        mean_count = statistics.mean(feeding_counts)
        if mean_count == 0:
            return 0.0
        
        try:
            cv = statistics.stdev(feeding_counts) / mean_count
            # Convert to score (0-100, higher is more consistent)
            consistency_score = max(0, 100 - (cv * 100))
            return consistency_score
        except statistics.StatisticsError:
            return 0.0
    
    async def _identify_health_risks(
        self, 
        trends: List[Dict[str, Any]], 
        weight_status: str
    ) -> List[str]:
        """Identify potential health risks"""
        risks = []
        
        if not trends:
            return ["Insufficient data for risk assessment"]
        
        # Weight-related risks
        if weight_status == "weight_gain":
            risks.append("Rapid weight gain may indicate overfeeding")
        elif weight_status == "weight_loss":
            risks.append("Weight loss may indicate underfeeding or health issues")
        
        # Nutritional risks
        avg_compatibility = statistics.mean([t.get("average_compatibility_score", 0) for t in trends])
        if avg_compatibility < 50:
            risks.append("Low nutritional compatibility may affect health")
        
        # Feeding consistency risks
        feeding_counts = [t.get("feeding_count", 0) for t in trends]
        if len(feeding_counts) > 1:
            feeding_variance = statistics.stdev(feeding_counts)
            if feeding_variance > 2:
                risks.append("Inconsistent feeding schedule may affect digestion")
        
        # Calorie risks
        calories = [t.get("total_calories", 0) for t in trends]
        if calories:
            avg_calories = statistics.mean(calories)
            if avg_calories < 150:
                risks.append("Low calorie intake may lead to malnutrition")
            elif avg_calories > 500:
                risks.append("High calorie intake may lead to obesity")
        
        return risks
    
    async def _identify_positive_indicators(self, trends: List[Dict[str, Any]]) -> List[str]:
        """Identify positive health indicators"""
        indicators = []
        
        if not trends:
            return indicators
        
        # Weight stability
        total_weight_change = sum(t.get("weight_change_kg", 0) for t in trends)
        if abs(total_weight_change) < 0.5:
            indicators.append("Excellent weight stability")
        
        # Nutritional adequacy
        avg_compatibility = statistics.mean([t.get("average_compatibility_score", 0) for t in trends])
        if avg_compatibility > 80:
            indicators.append("Excellent nutritional compatibility")
        elif avg_compatibility > 60:
            indicators.append("Good nutritional balance")
        
        # Feeding consistency
        feeding_counts = [t.get("feeding_count", 0) for t in trends]
        if len(feeding_counts) > 1:
            feeding_variance = statistics.stdev(feeding_counts)
            if feeding_variance < 1:
                indicators.append("Very consistent feeding schedule")
        
        # Calorie adequacy
        calories = [t.get("total_calories", 0) for t in trends]
        if calories:
            avg_calories = statistics.mean(calories)
            if 200 <= avg_calories <= 400:
                indicators.append("Optimal calorie intake")
        
        return indicators
    
    async def _generate_health_recommendations(
        self, 
        pet_id: str, 
        trends: List[Dict[str, Any]], 
        weight_status: str,
        adequacy_score: float,
        consistency_score: float
    ) -> List[NutritionalRecommendationResponse]:
        """Generate health recommendations"""
        recommendations = []
        
        # Weight management recommendations
        if weight_status == "weight_gain":
            recommendations.append(NutritionalRecommendationResponse(
                id="weight_gain_1",
                pet_id=pet_id,
                recommendation_type="weight_management",
                title="Monitor Weight Gain",
                description="Your pet is gaining weight. Consider reducing portion sizes or increasing exercise.",
                priority="high",
                category="weight",
                is_active=True,
                generated_at=DateTimeService.now(),
                expires_at=DateTimeService.now() + timedelta(days=30),
                created_at=DateTimeService.now(),
                updated_at=DateTimeService.now()
            ))
        elif weight_status == "weight_loss":
            recommendations.append(NutritionalRecommendationResponse(
                id="weight_loss_1",
                pet_id=pet_id,
                recommendation_type="diet_adjustment",
                title="Address Weight Loss",
                description="Your pet is losing weight. Ensure adequate nutrition and consult your veterinarian.",
                priority="critical",
                category="diet",
                is_active=True,
                generated_at=DateTimeService.now(),
                expires_at=DateTimeService.now() + timedelta(days=14),
                created_at=DateTimeService.now(),
                updated_at=DateTimeService.now()
            ))
        
        # Nutritional adequacy recommendations
        if adequacy_score < 60:
            recommendations.append(NutritionalRecommendationResponse(
                id="nutrition_1",
                pet_id=pet_id,
                recommendation_type="diet_adjustment",
                title="Improve Nutritional Balance",
                description="Consider switching to higher quality pet food for better nutritional balance.",
                priority="medium",
                category="diet",
                is_active=True,
                generated_at=DateTimeService.now(),
                expires_at=DateTimeService.now() + timedelta(days=60),
                created_at=DateTimeService.now(),
                updated_at=DateTimeService.now()
            ))
        
        # Feeding consistency recommendations
        if consistency_score < 70:
            recommendations.append(NutritionalRecommendationResponse(
                id="consistency_1",
                pet_id=pet_id,
                recommendation_type="feeding_schedule",
                title="Improve Feeding Consistency",
                description="Try to maintain more consistent feeding times and amounts.",
                priority="low",
                category="feeding",
                is_active=True,
                generated_at=DateTimeService.now(),
                expires_at=DateTimeService.now() + timedelta(days=30),
                created_at=DateTimeService.now(),
                updated_at=DateTimeService.now()
            ))
        
        return recommendations
    
    def _calculate_overall_health_score(
        self, 
        adequacy_score: float, 
        consistency_score: float, 
        weight_status: str,
        risk_count: int
    ) -> float:
        """Calculate overall health score"""
        # Base score from nutritional adequacy
        base_score = adequacy_score * 0.4
        
        # Add consistency score
        consistency_contribution = consistency_score * 0.3
        
        # Weight status contribution
        weight_contribution = 0
        if weight_status == "stable":
            weight_contribution = 30
        elif weight_status in ["weight_gain", "weight_loss"]:
            weight_contribution = 10
        
        # Risk penalty
        risk_penalty = min(20, risk_count * 5)
        
        # Calculate final score
        final_score = base_score + consistency_contribution + weight_contribution - risk_penalty
        
        return max(0, min(100, final_score))
    
    async def _analyze_feeding_times(self, trends: List[Dict[str, Any]]) -> List[str]:
        """Analyze feeding time patterns"""
        # This would analyze actual feeding times from feeding records
        # For now, return mock data
        return ["Morning (8:00 AM)", "Evening (6:00 PM)"]
    
    async def _analyze_preferred_foods(self, pet_id: str) -> List[str]:
        """Analyze preferred foods based on feeding history"""
        # This would analyze feeding records to find most frequently fed foods
        # For now, return mock data
        return ["Chicken & Rice", "Salmon Formula", "Lamb & Sweet Potato"]
    
    async def _identify_nutritional_gaps(self, trends: List[Dict[str, Any]]) -> List[str]:
        """Identify nutritional gaps in the diet"""
        gaps = []
        
        if not trends:
            return ["Insufficient data for gap analysis"]
        
        # Analyze protein levels
        protein_levels = [t.get("total_protein_g", 0) for t in trends]
        if protein_levels:
            avg_protein = statistics.mean(protein_levels)
            if avg_protein < 20:
                gaps.append("Low protein intake")
        
        # Analyze fiber levels
        fiber_levels = [t.get("total_fiber_g", 0) for t in trends]
        if fiber_levels:
            avg_fiber = statistics.mean(fiber_levels)
            if avg_fiber < 5:
                gaps.append("Insufficient fiber intake")
        
        return gaps
    
    async def _analyze_seasonal_patterns(self, trends: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze seasonal patterns in nutrition"""
        # This would analyze trends over different seasons
        # For now, return mock data
        return {
            "winter": {"calories": 320, "feeding_frequency": 2.1},
            "spring": {"calories": 300, "feeding_frequency": 2.0},
            "summer": {"calories": 280, "feeding_frequency": 1.9},
            "fall": {"calories": 310, "feeding_frequency": 2.0}
        }
    
    async def _generate_behavioral_insights(
        self, 
        trends: List[Dict[str, Any]], 
        feeding_times: List[str]
    ) -> List[str]:
        """Generate behavioral insights from patterns"""
        insights = []
        
        if not trends:
            return ["Insufficient data for behavioral analysis"]
        
        # Analyze feeding frequency patterns
        feeding_counts = [t.get("feeding_count", 0) for t in trends]
        if len(feeding_counts) > 1:
            avg_feedings = statistics.mean(feeding_counts)
            if avg_feedings > 2.5:
                insights.append("Pet prefers frequent small meals")
            elif avg_feedings < 1.5:
                insights.append("Pet prefers fewer large meals")
        
        # Analyze calorie consistency
        calories = [t.get("total_calories", 0) for t in trends]
        if len(calories) > 1:
            calorie_variance = statistics.stdev(calories)
            if calorie_variance < 50:
                insights.append("Very consistent appetite and feeding behavior")
            elif calorie_variance > 150:
                insights.append("Variable appetite - may indicate health changes")
        
        return insights
    
    async def _generate_optimization_suggestions(
        self, 
        trends: List[Dict[str, Any]], 
        nutritional_gaps: List[str],
        behavioral_insights: List[str]
    ) -> List[str]:
        """Generate optimization suggestions"""
        suggestions = []
        
        # Address nutritional gaps
        for gap in nutritional_gaps:
            if "protein" in gap.lower():
                suggestions.append("Consider adding high-protein treats or supplements")
            elif "fiber" in gap.lower():
                suggestions.append("Add fiber-rich vegetables to meals")
        
        # Address behavioral patterns
        for insight in behavioral_insights:
            if "frequent" in insight.lower():
                suggestions.append("Consider using puzzle feeders for mental stimulation")
            elif "variable" in insight.lower():
                suggestions.append("Monitor appetite changes and consult veterinarian if concerned")
        
        # General optimization suggestions
        if not suggestions:
            suggestions.append("Continue current feeding routine - patterns look healthy")
        
        return suggestions
    
    # Placeholder methods for different analysis types
    async def _generate_weekly_analysis(self, pet_id: str, date_range: Optional[Dict[str, date]]) -> Dict[str, Any]:
        """Generate weekly analysis"""
        return {"type": "weekly", "data": "placeholder"}
    
    async def _generate_monthly_analysis(self, pet_id: str, date_range: Optional[Dict[str, date]]) -> Dict[str, Any]:
        """Generate monthly analysis"""
        return {"type": "monthly", "data": "placeholder"}
    
    async def _generate_health_analysis(self, pet_id: str, date_range: Optional[Dict[str, date]]) -> Dict[str, Any]:
        """Generate health analysis"""
        return {"type": "health", "data": "placeholder"}
    
    async def _generate_weight_analysis(self, pet_id: str, date_range: Optional[Dict[str, date]]) -> Dict[str, Any]:
        """Generate weight analysis"""
        return {"type": "weight", "data": "placeholder"}
    
    async def _generate_pattern_analysis(self, pet_id: str, date_range: Optional[Dict[str, date]]) -> Dict[str, Any]:
        """Generate pattern analysis"""
        return {"type": "patterns", "data": "placeholder"}
