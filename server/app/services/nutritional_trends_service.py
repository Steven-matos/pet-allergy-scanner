"""
Nutritional Trends Service
Handles nutritional trend analysis, pattern recognition, and insights generation
"""

from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime, date, timedelta
from app.shared.services.datetime_service import DateTimeService
from decimal import Decimal
import statistics
import json
from ..database import get_supabase_client
from ..models.advanced_nutrition import (
    NutritionalTrendResponse, NutritionalTrendsDashboard,
    WeeklyNutritionSummary, MonthlyTrendAnalysis,
    HealthInsights, NutritionalPatterns
)


class NutritionalTrendsService:
    """
    Service for analyzing nutritional trends and generating insights
    
    Follows SOLID principles with single responsibility for trend analysis
    Implements DRY by reusing common analysis methods
    Follows KISS by keeping analysis methods focused and simple
    """
    
    def __init__(self):
        self.supabase = get_supabase_client()
    
    async def get_nutritional_trends(
        self, 
        pet_id: str, 
        user_id: str,
        days_back: int = 30
    ) -> List[NutritionalTrendResponse]:
        """
        Get nutritional trends for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            days_back: Number of days to look back
            
        Returns:
            List of nutritional trend records (empty list if no trends exist)
        """
        # Get trend data
        # Note: Pet ownership is verified by the router before calling this method
        start_date = DateTimeService.now() - timedelta(days=days_back)
        
        response = self.supabase.table("nutritional_trends")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .gte("trend_date", start_date.date().isoformat())\
            .order("trend_date", desc=True)\
            .execute()
        
        # Return empty list if no trends exist (200 status with empty data)
        return [NutritionalTrendResponse(**trend) for trend in response.data]
    
    async def generate_weekly_summary(
        self, 
        pet_id: str, 
        user_id: str,
        week_start: date
    ) -> WeeklyNutritionSummary:
        """
        Generate weekly nutrition summary
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            week_start: Start date of the week
            
        Returns:
            Weekly nutrition summary (with default values if no data exists)
        """
        week_end = week_start + timedelta(days=6)
        # Note: Pet ownership is verified by the router before calling this method
        
        # Get trends for the week
        trends = await self.get_nutritional_trends(pet_id, user_id, 7)
        week_trends = [
            t for t in trends 
            if week_start <= t.trend_date <= week_end
        ]
        
        if not week_trends:
            return WeeklyNutritionSummary(
                pet_id=pet_id,
                week_start=week_start,
                week_end=week_end,
                total_calories=0.0,
                average_daily_calories=0.0,
                total_protein_g=0.0,
                total_fat_g=0.0,
                total_fiber_g=0.0,
                feeding_frequency=0.0,
                weight_change_kg=0.0,
                compatibility_trend="stable",
                recommendations=[],
                health_score=0.0
            )
        
        # Calculate totals
        total_calories = sum(t.total_calories for t in week_trends)
        total_protein = sum(t.total_protein_g for t in week_trends)
        total_fat = sum(t.total_fat_g for t in week_trends)
        total_fiber = sum(t.total_fiber_g for t in week_trends)
        total_feedings = sum(t.feeding_count for t in week_trends)
        weight_change = sum(t.weight_change_kg for t in week_trends)
        
        # Calculate averages
        avg_daily_calories = total_calories / len(week_trends)
        avg_compatibility = statistics.mean([t.average_compatibility_score for t in week_trends])
        feeding_frequency = total_feedings / len(week_trends)
        
        # Determine compatibility trend
        if len(week_trends) >= 2:
            recent_avg = statistics.mean([t.average_compatibility_score for t in week_trends[:3]])
            older_avg = statistics.mean([t.average_compatibility_score for t in week_trends[-3:]])
            
            if recent_avg > older_avg + 5:
                compatibility_trend = "improving"
            elif recent_avg < older_avg - 5:
                compatibility_trend = "declining"
            else:
                compatibility_trend = "stable"
        else:
            compatibility_trend = "stable"
        
        # Generate recommendations
        recommendations = await self._generate_weekly_recommendations(
            pet_id, week_trends, avg_daily_calories, avg_compatibility
        )
        
        # Calculate health score
        health_score = self._calculate_health_score(
            avg_daily_calories, avg_compatibility, feeding_frequency, weight_change
        )
        
        return WeeklyNutritionSummary(
            pet_id=pet_id,
            week_start=week_start,
            week_end=week_end,
            total_calories=round(total_calories, 1),
            average_daily_calories=round(avg_daily_calories, 1),
            total_protein_g=round(total_protein, 1),
            total_fat_g=round(total_fat, 1),
            total_fiber_g=round(total_fiber, 1),
            feeding_frequency=round(feeding_frequency, 1),
            weight_change_kg=round(weight_change, 2),
            compatibility_trend=compatibility_trend,
            recommendations=recommendations,
            health_score=round(health_score, 1)
        )
    
    async def generate_monthly_analysis(
        self, 
        pet_id: str, 
        user_id: str,
        month: str  # YYYY-MM format
    ) -> MonthlyTrendAnalysis:
        """
        Generate monthly trend analysis
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            month: Month in YYYY-MM format
            
        Returns:
            Monthly trend analysis (with default values if no data exists)
        """
        # Parse month
        # Note: Pet ownership is verified by the router before calling this method
        year, month_num = month.split('-')
        month_start = date(int(year), int(month_num), 1)
        
        # Get last day of month
        if month_num == '12':
            next_month = date(int(year) + 1, 1, 1)
        else:
            next_month = date(int(year), int(month_num) + 1, 1)
        month_end = next_month - timedelta(days=1)
        
        # Get trends for the month
        trends = await self.get_nutritional_trends(pet_id, user_id, 31)
        month_trends = [
            t for t in trends 
            if month_start <= t.trend_date <= month_end
        ]
        
        # Analyze weight trend
        weight_trend = await self._analyze_weight_trend_for_month(month_trends)
        
        # Analyze calorie trend
        calorie_trend = await self._analyze_calorie_trend(month_trends)
        
        # Analyze nutritional adequacy
        nutritional_adequacy = await self._analyze_nutritional_adequacy(month_trends)
        
        # Analyze feeding patterns
        feeding_patterns = await self._analyze_feeding_patterns(month_trends)
        
        # Generate health indicators
        health_indicators = await self._generate_health_indicators(month_trends)
        
        # Generate insights and predictions
        insights = await self._generate_monthly_insights(month_trends, weight_trend, calorie_trend)
        predictions = await self._generate_monthly_predictions(month_trends, insights)
        
        return MonthlyTrendAnalysis(
            pet_id=pet_id,
            month=month,
            weight_trend=weight_trend,
            calorie_trend=calorie_trend,
            nutritional_adequacy=nutritional_adequacy,
            feeding_patterns=feeding_patterns,
            health_indicators=health_indicators,
            insights=insights,
            predictions=predictions
        )
    
    async def get_trends_dashboard(
        self, 
        pet_id: str, 
        user_id: str,
        period: str = "30_days"
    ) -> NutritionalTrendsDashboard:
        """
        Get comprehensive trends dashboard data
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            period: Analysis period (7_days, 30_days, 90_days)
            
        Returns:
            Trends dashboard data (with empty/default values if no trends exist)
        """
        # Get trends based on period
        # Note: Pet ownership is verified by the router before calling this method
        days_map = {"7_days": 7, "30_days": 30, "90_days": 90}
        days_back = days_map.get(period, 30)
        
        trends = await self.get_nutritional_trends(pet_id, user_id, days_back)
        
        # Generate trend data
        calorie_trends = self._format_calorie_trends(trends)
        macronutrient_trends = self._format_macronutrient_trends(trends)
        weight_correlation = self._calculate_weight_correlation(trends)
        feeding_patterns = self._format_feeding_patterns(trends)
        insights = await self._generate_dashboard_insights(trends)
        
        return NutritionalTrendsDashboard(
            pet_id=pet_id,
            trend_period=period,
            calorie_trends=calorie_trends,
            macronutrient_trends=macronutrient_trends,
            weight_correlation=weight_correlation,
            feeding_patterns=feeding_patterns,
            insights=insights
        )
    
    async def _generate_weekly_recommendations(
        self, 
        pet_id: str, 
        trends: List[NutritionalTrendResponse],
        avg_calories: float,
        avg_compatibility: float
    ) -> List[str]:
        """Generate weekly recommendations based on trends"""
        recommendations = []
        
        if avg_compatibility < 70:
            recommendations.append("Consider switching to higher quality pet food for better nutritional balance")
        
        if avg_calories < 200:
            recommendations.append("Your pet may need more calories - consult with your veterinarian")
        elif avg_calories > 500:
            recommendations.append("Consider reducing portion sizes to prevent overfeeding")
        
        # Check for consistency
        if len(trends) >= 3:
            calorie_variance = statistics.stdev([t.total_calories for t in trends])
            if calorie_variance > 100:
                recommendations.append("Try to maintain more consistent feeding amounts")
        
        return recommendations
    
    def _calculate_health_score(
        self, 
        avg_calories: float, 
        avg_compatibility: float, 
        feeding_frequency: float,
        weight_change: float
    ) -> float:
        """Calculate overall health score based on multiple factors"""
        # Calorie score (0-25 points)
        calorie_score = min(25, max(0, 25 - abs(avg_calories - 300) / 10))
        
        # Compatibility score (0-25 points)
        compatibility_score = avg_compatibility * 0.25
        
        # Feeding frequency score (0-25 points)
        frequency_score = min(25, feeding_frequency * 5)
        
        # Weight stability score (0-25 points)
        weight_score = max(0, 25 - abs(weight_change) * 10)
        
        return calorie_score + compatibility_score + frequency_score + weight_score
    
    def _format_calorie_trends(self, trends: List[NutritionalTrendResponse]) -> List[Dict[str, Any]]:
        """Format calorie trends for dashboard"""
        return [
            {
                "date": trend.trend_date.isoformat(),
                "calories": trend.total_calories,
                "target": 300  # Would be calculated based on pet needs
            }
            for trend in sorted(trends, key=lambda x: x.trend_date)
        ]
    
    def _format_macronutrient_trends(self, trends: List[NutritionalTrendResponse]) -> List[Dict[str, Any]]:
        """Format macronutrient trends for dashboard"""
        return [
            {
                "date": trend.trend_date.isoformat(),
                "protein": trend.total_protein_g,
                "fat": trend.total_fat_g,
                "fiber": trend.total_fiber_g
            }
            for trend in sorted(trends, key=lambda x: x.trend_date)
        ]
    
    def _calculate_weight_correlation(self, trends: List[NutritionalTrendResponse]) -> Dict[str, Any]:
        """Calculate correlation between nutrition and weight changes"""
        if len(trends) < 3:
            return {"correlation": 0, "strength": "insufficient_data"}
        
        calories = [t.total_calories for t in trends]
        weight_changes = [t.weight_change_kg for t in trends]
        
        try:
            correlation = statistics.correlation(calories, weight_changes)
        except statistics.StatisticsError:
            correlation = 0
        
        if abs(correlation) > 0.7:
            strength = "strong"
        elif abs(correlation) > 0.4:
            strength = "moderate"
        else:
            strength = "weak"
        
        return {
            "correlation": round(correlation, 3),
            "strength": strength,
            "interpretation": "positive" if correlation > 0 else "negative"
        }
    
    def _format_feeding_patterns(self, trends: List[NutritionalTrendResponse]) -> List[Dict[str, Any]]:
        """Format feeding patterns for dashboard"""
        return [
            {
                "date": trend.trend_date.isoformat(),
                "feeding_count": trend.feeding_count,
                "compatibility_score": trend.average_compatibility_score
            }
            for trend in sorted(trends, key=lambda x: x.trend_date)
        ]
    
    async def _generate_dashboard_insights(self, trends: List[NutritionalTrendResponse]) -> List[str]:
        """Generate insights for the trends dashboard"""
        insights = []
        
        if not trends:
            return ["No nutritional data available for analysis"]
        
        # Calorie consistency
        calories = [t.total_calories for t in trends]
        if len(calories) > 1:
            calorie_variance = statistics.stdev(calories)
            if calorie_variance < 50:
                insights.append("Excellent calorie consistency - keep up the good work!")
            elif calorie_variance > 150:
                insights.append("Consider maintaining more consistent feeding amounts")
        
        # Compatibility trends
        compatibility_scores = [t.average_compatibility_score for t in trends]
        avg_compatibility = statistics.mean(compatibility_scores)
        
        if avg_compatibility > 80:
            insights.append("Great nutritional compatibility with your pet's needs")
        elif avg_compatibility < 60:
            insights.append("Consider reviewing your pet's diet for better nutritional balance")
        
        # Weight management
        weight_changes = [t.weight_change_kg for t in trends]
        total_weight_change = sum(weight_changes)
        
        if total_weight_change > 1.0:
            insights.append("Monitor weight gain - consider adjusting portion sizes")
        elif total_weight_change < -1.0:
            insights.append("Monitor weight loss - ensure adequate nutrition")
        
        return insights
    
    async def _analyze_weight_trend_for_month(self, trends: List[NutritionalTrendResponse]) -> Any:
        """Analyze weight trend for the month"""
        # This would integrate with the weight tracking service
        # For now, return a simple analysis
        if not trends:
            return {"trend": "no_data", "change": 0.0}
        
        weight_changes = [t.weight_change_kg for t in trends]
        total_change = sum(weight_changes)
        
        if total_change > 0.5:
            return {"trend": "increasing", "change": total_change}
        elif total_change < -0.5:
            return {"trend": "decreasing", "change": total_change}
        else:
            return {"trend": "stable", "change": total_change}
    
    async def _analyze_calorie_trend(self, trends: List[NutritionalTrendResponse]) -> Dict[str, Any]:
        """Analyze calorie trend for the month"""
        if not trends:
            return {"trend": "no_data", "average": 0.0}
        
        calories = [t.total_calories for t in trends]
        avg_calories = statistics.mean(calories)
        
        if len(calories) > 1:
            trend_direction = "increasing" if calories[-1] > calories[0] else "decreasing"
        else:
            trend_direction = "stable"
        
        return {
            "trend": trend_direction,
            "average": round(avg_calories, 1),
            "variance": round(statistics.stdev(calories) if len(calories) > 1 else 0, 1)
        }
    
    async def _analyze_nutritional_adequacy(self, trends: List[NutritionalTrendResponse]) -> Dict[str, Any]:
        """Analyze nutritional adequacy for the month"""
        if not trends:
            return {"score": 0, "status": "no_data"}
        
        compatibility_scores = [t.average_compatibility_score for t in trends]
        avg_score = statistics.mean(compatibility_scores)
        
        if avg_score > 80:
            status = "excellent"
        elif avg_score > 60:
            status = "good"
        elif avg_score > 40:
            status = "fair"
        else:
            status = "poor"
        
        return {
            "score": round(avg_score, 1),
            "status": status,
            "trend": "improving" if len(compatibility_scores) > 1 and compatibility_scores[-1] > compatibility_scores[0] else "stable"
        }
    
    async def _analyze_feeding_patterns(self, trends: List[NutritionalTrendResponse]) -> Dict[str, Any]:
        """Analyze feeding patterns for the month"""
        if not trends:
            return {"frequency": 0, "consistency": "no_data"}
        
        feeding_counts = [t.feeding_count for t in trends]
        avg_frequency = statistics.mean(feeding_counts)
        
        if len(feeding_counts) > 1:
            consistency = "consistent" if statistics.stdev(feeding_counts) < 1 else "variable"
        else:
            consistency = "unknown"
        
        return {
            "frequency": round(avg_frequency, 1),
            "consistency": consistency,
            "total_feedings": sum(feeding_counts)
        }
    
    async def _generate_health_indicators(self, trends: List[NutritionalTrendResponse]) -> Dict[str, Any]:
        """Generate health indicators from trends"""
        if not trends:
            return {"overall": "no_data"}
        
        # Calculate various health indicators
        calories = [t.total_calories for t in trends]
        compatibility_scores = [t.average_compatibility_score for t in trends]
        weight_changes = [t.weight_change_kg for t in trends]
        
        avg_calories = statistics.mean(calories)
        avg_compatibility = statistics.mean(compatibility_scores)
        total_weight_change = sum(weight_changes)
        
        # Determine overall health status
        if avg_compatibility > 80 and abs(total_weight_change) < 0.5:
            overall = "excellent"
        elif avg_compatibility > 60 and abs(total_weight_change) < 1.0:
            overall = "good"
        elif avg_compatibility > 40:
            overall = "fair"
        else:
            overall = "needs_attention"
        
        return {
            "overall": overall,
            "calorie_adequacy": "adequate" if 200 <= avg_calories <= 400 else "needs_adjustment",
            "nutritional_balance": "good" if avg_compatibility > 60 else "needs_improvement",
            "weight_stability": "stable" if abs(total_weight_change) < 0.5 else "unstable"
        }
    
    async def _generate_monthly_insights(self, trends: List[NutritionalTrendResponse], weight_trend: Any, calorie_trend: Any) -> List[str]:
        """Generate monthly insights"""
        insights = []
        
        if not trends:
            return ["No data available for analysis"]
        
        # Weight insights
        if weight_trend["trend"] == "increasing":
            insights.append("Weight is trending upward - monitor portion sizes")
        elif weight_trend["trend"] == "decreasing":
            insights.append("Weight is trending downward - ensure adequate nutrition")
        
        # Calorie insights
        if calorie_trend["trend"] == "increasing":
            insights.append("Calorie intake is increasing - watch for overfeeding")
        elif calorie_trend["trend"] == "decreasing":
            insights.append("Calorie intake is decreasing - ensure nutritional needs are met")
        
        # Consistency insights
        calories = [t.total_calories for t in trends]
        if len(calories) > 1:
            variance = statistics.stdev(calories)
            if variance < 50:
                insights.append("Excellent feeding consistency this month")
            elif variance > 150:
                insights.append("Consider more consistent feeding amounts")
        
        return insights
    
    async def _generate_monthly_predictions(self, trends: List[NutritionalTrendResponse], insights: List[str]) -> List[str]:
        """Generate monthly predictions based on trends"""
        predictions = []
        
        if not trends:
            return ["Insufficient data for predictions"]
        
        # Simple prediction logic (in production, this would use ML models)
        calories = [t.total_calories for t in trends]
        if len(calories) > 1:
            recent_avg = statistics.mean(calories[-7:]) if len(calories) >= 7 else statistics.mean(calories)
            
            if recent_avg > 400:
                predictions.append("Continued high calorie intake may lead to weight gain")
            elif recent_avg < 200:
                predictions.append("Low calorie intake may lead to weight loss")
        
        compatibility_scores = [t.average_compatibility_score for t in trends]
        if len(compatibility_scores) > 1:
            recent_compatibility = statistics.mean(compatibility_scores[-7:]) if len(compatibility_scores) >= 7 else statistics.mean(compatibility_scores)
            
            if recent_compatibility > 80:
                predictions.append("Excellent nutritional balance should continue with current diet")
            elif recent_compatibility < 60:
                predictions.append("Consider dietary changes to improve nutritional balance")
        
        return predictions
