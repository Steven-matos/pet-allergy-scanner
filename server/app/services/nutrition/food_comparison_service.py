"""
Food Comparison Service
Handles side-by-side food comparison, nutritional analysis, and recommendations
"""

from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime
from app.shared.services.datetime_service import DateTimeService
from decimal import Decimal
import statistics
from supabase import Client
from app.shared.services.database_operation_service import DatabaseOperationService
from app.models.nutrition.advanced_nutrition import (
    FoodComparisonCreate, FoodComparisonResponse,
    FoodComparisonMetrics, FoodComparisonDashboard
)
from app.models.nutrition.nutrition import FoodAnalysisResponse


class FoodComparisonService:
    """
    Service for comparing pet foods and generating recommendations
    
    Follows SOLID principles with single responsibility for food comparison
    Implements DRY by reusing common calculation methods
    Follows KISS by keeping comparison logic focused and simple
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize food comparison service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
    
    async def create_comparison(
        self, 
        comparison: FoodComparisonCreate,
        user_id: str
    ) -> FoodComparisonResponse:
        """
        Create a new food comparison
        
        Args:
            comparison: Comparison data
            user_id: User ID for authorization
            
        Returns:
            Created comparison
        """
        # Validate food IDs exist and user has access
        await self._validate_food_access(comparison.food_ids, user_id)
        
        # Generate comparison data
        comparison_data = await self._generate_comparison_data(comparison.food_ids)
        
        # Create comparison record
        comparison_record = {
            "user_id": user_id,
            "comparison_name": comparison.comparison_name,
            "food_ids": comparison.food_ids,
            "comparison_data": comparison_data
        }
        
        db_service = DatabaseOperationService(self.supabase)
        result = await db_service.insert_with_timestamps("food_comparisons", comparison_record)
        
        return FoodComparisonResponse(**result)
    
    async def get_comparison(
        self, 
        comparison_id: str, 
        user_id: str
    ) -> FoodComparisonResponse:
        """
        Get a food comparison by ID
        
        Args:
            comparison_id: Comparison ID
            user_id: User ID for authorization
            
        Returns:
            Food comparison data
        """
        response = self.supabase.table("food_comparisons")\
            .select("*")\
            .eq("id", comparison_id)\
            .eq("user_id", user_id)\
            .execute()
        
        if not response.data:
            raise ValueError("Comparison not found or access denied")
        
        return FoodComparisonResponse(**response.data[0])
    
    async def get_user_comparisons(
        self, 
        user_id: str,
        limit: int = 20
    ) -> List[FoodComparisonResponse]:
        """
        Get all comparisons for a user
        
        Args:
            user_id: User ID
            limit: Maximum number of comparisons to return
            
        Returns:
            List of user's comparisons
        """
        response = self.supabase.table("food_comparisons")\
            .select("*")\
            .eq("user_id", user_id)\
            .order("created_at", desc=True)\
            .limit(limit)\
            .execute()
        
        return [FoodComparisonResponse(**comp) for comp in response.data]
    
    async def get_comparison_dashboard(
        self, 
        comparison_id: str, 
        user_id: str
    ) -> FoodComparisonDashboard:
        """
        Get comprehensive comparison dashboard data
        
        Args:
            comparison_id: Comparison ID
            user_id: User ID for authorization
            
        Returns:
            Comparison dashboard data
        """
        # Get comparison
        comparison = await self.get_comparison(comparison_id, user_id)
        
        # Get food details
        foods = await self._get_food_details(comparison.food_ids)
        
        # Generate detailed metrics
        metrics = await self._generate_detailed_metrics(comparison.food_ids, foods)
        
        # Generate recommendations
        recommendations = await self._generate_comparison_recommendations(metrics, foods)
        
        # Determine best options
        best_overall = self._determine_best_overall(metrics, foods)
        best_value = self._determine_best_value(metrics, foods)
        best_nutrition = self._determine_best_nutrition(metrics, foods)
        
        return FoodComparisonDashboard(
            comparison_id=comparison_id,
            comparison_name=comparison.comparison_name,
            foods=foods,
            metrics=metrics,
            recommendations=recommendations,
            best_overall=best_overall,
            best_value=best_value,
            best_nutrition=best_nutrition
        )
    
    async def compare_foods_quick(
        self, 
        food_ids: List[str], 
        user_id: str
    ) -> FoodComparisonMetrics:
        """
        Quick comparison of foods without saving
        
        Args:
            food_ids: List of food IDs to compare
            user_id: User ID for authorization
            
        Returns:
            Comparison metrics
        """
        # Validate food access
        await self._validate_food_access(food_ids, user_id)
        
        # Get food details
        foods = await self._get_food_details(food_ids)
        
        # Generate metrics
        return await self._generate_detailed_metrics(food_ids, foods)
    
    async def _validate_food_access(self, food_ids: List[str], user_id: str) -> None:
        """Validate that user has access to all food IDs"""
        for food_id in food_ids:
            response = self.supabase.table("food_analyses")\
                .select("id")\
                .eq("id", food_id)\
                .eq("user_id", user_id)\
                .execute()
            
            if not response.data:
                raise ValueError(f"Food analysis {food_id} not found or access denied")
    
    async def _get_food_details(self, food_ids: List[str]) -> List[Dict[str, Any]]:
        """Get detailed food information for comparison"""
        foods = []
        
        for food_id in food_ids:
            response = self.supabase.table("food_analyses")\
                .select("*")\
                .eq("id", food_id)\
                .execute()
            
            if response.data:
                food_data = response.data[0]
                foods.append({
                    "id": food_data["id"],
                    "name": food_data["food_name"],
                    "brand": food_data.get("brand", "Unknown"),
                    "calories_per_100g": food_data["calories_per_100g"],
                    "protein_percentage": food_data["protein_percentage"],
                    "fat_percentage": food_data["fat_percentage"],
                    "fiber_percentage": food_data["fiber_percentage"],
                    "moisture_percentage": food_data["moisture_percentage"],
                    "ingredients": food_data.get("ingredients", []),
                    "allergens": food_data.get("allergens", []),
                    "analyzed_at": food_data["analyzed_at"]
                })
        
        return foods
    
    async def _generate_comparison_data(self, food_ids: List[str]) -> Dict[str, Any]:
        """Generate comparison data for storage"""
        foods = await self._get_food_details(food_ids)
        metrics = await self._generate_detailed_metrics(food_ids, foods)
        
        return {
            "foods": foods,
            "metrics": metrics.dict(),
            "generated_at": DateTimeService.now_iso()
        }
    
    async def _generate_detailed_metrics(
        self, 
        food_ids: List[str], 
        foods: List[Dict[str, Any]]
    ) -> FoodComparisonMetrics:
        """Generate detailed comparison metrics"""
        if not foods:
            raise ValueError("No food data available for comparison")
        
        # Extract nutritional data
        calories = {food["id"]: food["calories_per_100g"] for food in foods}
        protein = {food["id"]: food["protein_percentage"] for food in foods}
        fat = {food["id"]: food["fat_percentage"] for food in foods}
        fiber = {food["id"]: food["fiber_percentage"] for food in foods}
        
        # Calculate cost per calorie (mock data - would come from price data)
        cost_per_calorie = {food["id"]: 0.01 + (i * 0.005) for i, food in enumerate(foods)}
        
        # Calculate nutritional density (calories per gram of essential nutrients)
        nutritional_density = {}
        for food in foods:
            # Simple nutritional density calculation
            essential_nutrients = food["protein_percentage"] + food["fat_percentage"]
            if essential_nutrients > 0:
                density = food["calories_per_100g"] / essential_nutrients
            else:
                density = 0
            nutritional_density[food["id"]] = round(density, 2)
        
        # Calculate compatibility scores (mock data - would come from pet compatibility)
        compatibility_scores = {food["id"]: 70 + (i * 5) for i, food in enumerate(foods)}
        
        # Generate overall rankings
        overall_rankings = self._calculate_overall_rankings(foods, calories, protein, fat, fiber, cost_per_calorie)
        
        return FoodComparisonMetrics(
            calories_comparison=calories,
            protein_comparison=protein,
            fat_comparison=fat,
            fiber_comparison=fiber,
            cost_per_calorie=cost_per_calorie,
            nutritional_density=nutritional_density,
            compatibility_scores=compatibility_scores,
            overall_rankings=overall_rankings
        )
    
    def _calculate_overall_rankings(
        self, 
        foods: List[Dict[str, Any]], 
        calories: Dict[str, float],
        protein: Dict[str, float],
        fat: Dict[str, float],
        fiber: Dict[str, float],
        cost_per_calorie: Dict[str, float]
    ) -> List[Dict[str, Any]]:
        """Calculate overall rankings for foods"""
        rankings = []
        
        for food in foods:
            food_id = food["id"]
            
            # Calculate composite score (0-100)
            # Weight factors: calories (25%), protein (25%), fat (20%), fiber (15%), cost (15%)
            calorie_score = min(100, max(0, 100 - abs(calories[food_id] - 350) / 3.5))
            protein_score = min(100, protein[food_id] * 2)  # 50% protein = 100 points
            fat_score = min(100, fat[food_id] * 4)  # 25% fat = 100 points
            fiber_score = min(100, fiber[food_id] * 10)  # 10% fiber = 100 points
            cost_score = min(100, max(0, 100 - cost_per_calorie[food_id] * 1000))
            
            composite_score = (
                calorie_score * 0.25 +
                protein_score * 0.25 +
                fat_score * 0.20 +
                fiber_score * 0.15 +
                cost_score * 0.15
            )
            
            rankings.append({
                "food_id": food_id,
                "food_name": food["name"],
                "brand": food["brand"],
                "composite_score": round(composite_score, 1),
                "calorie_score": round(calorie_score, 1),
                "protein_score": round(protein_score, 1),
                "fat_score": round(fat_score, 1),
                "fiber_score": round(fiber_score, 1),
                "cost_score": round(cost_score, 1)
            })
        
        # Sort by composite score
        rankings.sort(key=lambda x: x["composite_score"], reverse=True)
        
        return rankings
    
    async def _generate_comparison_recommendations(
        self, 
        metrics: FoodComparisonMetrics, 
        foods: List[Dict[str, Any]]
    ) -> List[str]:
        """Generate recommendations based on comparison metrics"""
        recommendations = []
        
        if not foods:
            return recommendations
        
        # Find best and worst performers
        best_overall = max(metrics.overall_rankings, key=lambda x: x["composite_score"])
        worst_overall = min(metrics.overall_rankings, key=lambda x: x["composite_score"])
        
        # Protein recommendations
        protein_values = list(metrics.protein_comparison.values())
        if protein_values:
            max_protein = max(protein_values)
            min_protein = min(protein_values)
            
            if max_protein - min_protein > 10:
                recommendations.append(f"Protein content varies significantly ({min_protein:.1f}% - {max_protein:.1f}%)")
        
        # Calorie recommendations
        calorie_values = list(metrics.calories_comparison.values())
        if calorie_values:
            max_calories = max(calorie_values)
            min_calories = min(calorie_values)
            
            if max_calories - min_calories > 100:
                recommendations.append(f"Calorie content varies significantly ({min_calories:.0f} - {max_calories:.0f} kcal/100g)")
        
        # Cost recommendations
        cost_values = list(metrics.cost_per_calorie.values())
        if cost_values:
            max_cost = max(cost_values)
            min_cost = min(cost_values)
            
            if max_cost / min_cost > 2:
                recommendations.append("Significant cost variation - consider value for money")
        
        # Overall recommendation
        if best_overall["composite_score"] > 80:
            recommendations.append(f"{best_overall['food_name']} scores highest overall ({best_overall['composite_score']:.1f}/100)")
        elif worst_overall["composite_score"] < 40:
            recommendations.append(f"Consider avoiding {worst_overall['food_name']} (score: {worst_overall['composite_score']:.1f}/100)")
        
        return recommendations
    
    def _determine_best_overall(self, metrics: FoodComparisonMetrics, foods: List[Dict[str, Any]]) -> str:
        """Determine best overall food"""
        if not metrics.overall_rankings:
            return "No data"
        
        best = metrics.overall_rankings[0]
        return f"{best['food_name']} ({best['composite_score']:.1f}/100)"
    
    def _determine_best_value(self, metrics: FoodComparisonMetrics, foods: List[Dict[str, Any]]) -> str:
        """Determine best value food"""
        if not metrics.cost_per_calorie:
            return "No data"
        
        # Find food with lowest cost per calorie
        best_value_id = min(metrics.cost_per_calorie.keys(), key=lambda x: metrics.cost_per_calorie[x])
        best_food = next((f for f in foods if f["id"] == best_value_id), None)
        
        if best_food:
            cost = metrics.cost_per_calorie[best_value_id]
            return f"{best_food['name']} (${cost:.3f}/kcal)"
        
        return "No data"
    
    def _determine_best_nutrition(self, metrics: FoodComparisonMetrics, foods: List[Dict[str, Any]]) -> str:
        """Determine best nutritional food"""
        if not metrics.overall_rankings:
            return "No data"
        
        # Find food with highest nutritional density
        best_nutrition_id = max(metrics.nutritional_density.keys(), key=lambda x: metrics.nutritional_density[x])
        best_food = next((f for f in foods if f["id"] == best_nutrition_id), None)
        
        if best_food:
            density = metrics.nutritional_density[best_food["id"]]
            return f"{best_food['name']} (density: {density:.1f})"
        
        return "No data"
    
    async def delete_comparison(self, comparison_id: str, user_id: str) -> bool:
        """Delete a food comparison"""
        response = self.supabase.table("food_comparisons")\
            .delete()\
            .eq("id", comparison_id)\
            .eq("user_id", user_id)\
            .execute()
        
        return len(response.data) > 0
