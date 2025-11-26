"""
Weight Tracking Service
Handles pet weight management, goal tracking, and trend analysis
"""

from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime, date, timedelta
from decimal import Decimal
import statistics
from ..database import get_supabase_client
from ..utils.logging_config import get_logger
from ..models.advanced_nutrition import (
    PetWeightRecordCreate, PetWeightRecordResponse,
    PetWeightGoalCreate, PetWeightGoalResponse,
    WeightTrendAnalysis, TrendDirection, TrendStrength,
    WeightManagementDashboard
)

logger = get_logger(__name__)


class WeightTrackingService:
    """
    Service for managing pet weight tracking and analysis
    
    Follows SOLID principles with single responsibility for weight management
    Implements DRY by reusing common calculation methods
    Follows KISS by keeping methods focused and simple
    """
    
    def __init__(self):
        self.supabase = get_supabase_client()
    
    async def record_weight(
        self, 
        weight_record: PetWeightRecordCreate,
        user_id: str
    ) -> PetWeightRecordResponse:
        """
        Record a new weight measurement for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            weight_record: Weight record data
            user_id: ID of the user recording the weight (used for logging/audit)
            
        Returns:
            Created weight record
            
        Raises:
            ValueError: If weight recording fails
        """
        # Insert weight record using centralized service
        # Note: Pet ownership is verified by the router before calling this method
        weight_data = {
            "pet_id": weight_record.pet_id,
            "weight_kg": float(weight_record.weight_kg),
            "recorded_at": weight_record.recorded_at.isoformat(),
            "notes": weight_record.notes,
            "recorded_by_user_id": user_id
        }
        
        db_service = DatabaseOperationService(self.supabase)
        result = db_service.insert_with_timestamps("pet_weight_records", weight_data, include_created_at=False)
        
        # Update nutritional trends for this date
        await self._update_nutritional_trends(weight_record.pet_id, weight_record.recorded_at.date())
        
        return PetWeightRecordResponse(**result)
    
    async def get_weight_history(
        self, 
        pet_id: str, 
        user_id: str,
        days_back: int = 30
    ) -> List[PetWeightRecordResponse]:
        """
        Get weight history for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            days_back: Number of days to look back
            
        Returns:
            List of weight records (empty list if no records exist)
        """
        # Get weight records
        # Note: Pet ownership is verified by the router before calling this method
        start_date = DateTimeService.now() - timedelta(days=days_back)
        
        response = self.supabase.table("pet_weight_records")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .gte("recorded_at", start_date.isoformat())\
            .order("recorded_at", desc=True)\
            .execute()
        
        # Return empty list if no records exist (200 status with empty data)
        return [PetWeightRecordResponse(**record) for record in response.data]
    
    async def upsert_weight_goal(
        self, 
        goal: PetWeightGoalCreate,
        user_id: str
    ) -> PetWeightGoalResponse:
        """
        Create or update a weight goal for a pet (one goal per pet)
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            goal: Weight goal data
            user_id: User ID for authorization (used for logging/audit)
            
        Returns:
            Created or updated weight goal
        """
        # Check if pet already has a weight goal
        # Note: Pet ownership is verified by the router before calling this method
        existing_goal_response = self.supabase.table("pet_weight_goals")\
            .select("*")\
            .eq("pet_id", goal.pet_id)\
            .execute()
        
        goal_data = {
            "pet_id": goal.pet_id,
            "goal_type": goal.goal_type.value,
            "target_weight_kg": float(goal.target_weight_kg) if goal.target_weight_kg else None,
            "current_weight_kg": float(goal.current_weight_kg) if goal.current_weight_kg else None,
            "target_date": goal.target_date.isoformat() if goal.target_date else None,
            "is_active": goal.is_active,
            "notes": goal.notes
        }
        
        if existing_goal_response.data:
            # Update existing goal
            goal_id = existing_goal_response.data[0]["id"]
            response = self.supabase.table("pet_weight_goals")\
                .update(goal_data)\
                .eq("id", goal_id)\
                .execute()
            
            if not response.data:
                raise ValueError("Failed to update weight goal")
            
            return PetWeightGoalResponse(**response.data[0])
        else:
            # Create new goal
            db_service = DatabaseOperationService(self.supabase)
            result = db_service.insert_with_timestamps("pet_weight_goals", goal_data)
            
            return PetWeightGoalResponse(**result)
    
    async def create_weight_goal(
        self, 
        goal: PetWeightGoalCreate,
        user_id: str
    ) -> PetWeightGoalResponse:
        """
        Create a weight goal for a pet (deprecated - use upsert_weight_goal instead)
        
        Args:
            goal: Weight goal data
            user_id: User ID for authorization
            
        Returns:
            Created weight goal
        """
        # Delegate to upsert method for consistency
        return await self.upsert_weight_goal(goal, user_id)
    
    async def get_active_weight_goal(
        self, 
        pet_id: str, 
        user_id: str
    ) -> Optional[PetWeightGoalResponse]:
        """
        Get active weight goal for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            
        Returns:
            Active weight goal or None (returns None if no goal exists)
        """
        # Get active goal
        # Note: Pet ownership is verified by the router before calling this method
        response = self.supabase.table("pet_weight_goals")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .eq("is_active", True)\
            .execute()
        
        if not response.data:
            return None
        
        return PetWeightGoalResponse(**response.data[0])
    
    async def analyze_weight_trend(
        self, 
        pet_id: str, 
        user_id: str,
        days_back: int = 30
    ) -> WeightTrendAnalysis:
        """
        Analyze weight trend for a pet
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            days_back: Number of days to analyze
            
        Returns:
            Weight trend analysis
        """
        # Get weight history
        weight_records = await self.get_weight_history(pet_id, user_id, days_back)
        
        if len(weight_records) < 2:
            return WeightTrendAnalysis(
                trend_direction=TrendDirection.STABLE,
                weight_change_kg=0.0,
                average_daily_change=0.0,
                trend_strength=TrendStrength.WEAK,
                days_analyzed=len(weight_records),
                confidence_level=0.0
            )
        
        # Sort by date
        sorted_records = sorted(weight_records, key=lambda x: x.recorded_at)
        
        # Calculate trend
        current_weight = sorted_records[-1].weight_kg
        old_weight = sorted_records[0].weight_kg
        weight_change = current_weight - old_weight
        
        # Calculate daily change
        days_span = (sorted_records[-1].recorded_at - sorted_records[0].recorded_at).days
        daily_change = weight_change / days_span if days_span > 0 else 0
        
        # Determine trend direction
        if weight_change > 0.5:
            trend_direction = TrendDirection.INCREASING
        elif weight_change < -0.5:
            trend_direction = TrendDirection.DECREASING
        else:
            trend_direction = TrendDirection.STABLE
        
        # Determine trend strength
        abs_change = abs(weight_change)
        if abs_change > 2.0:
            trend_strength = TrendStrength.STRONG
        elif abs_change > 0.5:
            trend_strength = TrendStrength.MODERATE
        else:
            trend_strength = TrendStrength.WEAK
        
        # Calculate confidence level based on data points and consistency
        confidence = min(1.0, len(weight_records) / 14)  # Max confidence at 2 weeks of data
        
        return WeightTrendAnalysis(
            trend_direction=trend_direction,
            weight_change_kg=round(weight_change, 2),
            average_daily_change=round(daily_change, 3),
            trend_strength=trend_strength,
            days_analyzed=len(weight_records),
            confidence_level=confidence
        )
    
    async def get_weight_management_dashboard(
        self, 
        pet_id: str, 
        user_id: str
    ) -> WeightManagementDashboard:
        """
        Get comprehensive weight management dashboard data
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization
            
        Returns:
            Weight management dashboard data
        """
        # Get current weight (most recent)
        weight_records = await self.get_weight_history(pet_id, user_id, 1)
        current_weight = weight_records[0].weight_kg if weight_records else None
        
        # Get active weight goal
        weight_goal = await self.get_active_weight_goal(pet_id, user_id)
        target_weight = weight_goal.target_weight_kg if weight_goal else None
        
        # Get weight trend
        weight_trend = await self.analyze_weight_trend(pet_id, user_id, 30)
        
        # Get weekly progress (last 4 weeks)
        weekly_progress = await self._get_weekly_progress(pet_id, user_id, 4)
        
        # Get recommendations (would be generated by recommendation service)
        recommendations = []  # TODO: Integrate with recommendation service
        
        return WeightManagementDashboard(
            pet_id=pet_id,
            current_weight=current_weight,
            target_weight=target_weight,
            weight_goal=weight_goal,
            recent_trend=weight_trend,
            weekly_progress=weekly_progress,
            recommendations=recommendations
        )
    
    async def _deactivate_existing_goals(self, pet_id: str) -> None:
        """Deactivate existing active goals for a pet"""
        self.supabase.table("pet_weight_goals")\
            .update({"is_active": False})\
            .eq("pet_id", pet_id)\
            .eq("is_active", True)\
            .execute()
    
    async def _update_nutritional_trends(self, pet_id: str, trend_date: date) -> None:
        """Update nutritional trends for a specific date"""
        # This would call the database function to update trends
        # For now, we'll implement a simple version
        try:
            self.supabase.rpc("update_nutritional_trends", {
                "pet_uuid": pet_id,
                "trend_date": trend_date.isoformat()
            }).execute()
        except Exception as e:
            # Log error but don't fail the weight recording
            logger.warning(f"Failed to update nutritional trends: {e}")
    
    async def _get_weekly_progress(
        self, 
        pet_id: str, 
        user_id: str, 
        weeks: int
    ) -> List[Dict[str, Any]]:
        """Get weekly weight progress data"""
        weekly_data = []
        
        for week_offset in range(weeks):
            now = DateTimeService.now()
            week_start = now - timedelta(weeks=week_offset + 1)
            week_end = week_start + timedelta(days=6)
            
            # Get weight records for this week
            week_records = await self.get_weight_history(
                pet_id, 
                user_id, 
                (week_end - now).days + 7
            )
            
            # Filter to this week
            week_records = [
                r for r in week_records 
                if week_start.date() <= r.recorded_at.date() <= week_end.date()
            ]
            
            if week_records:
                start_weight = week_records[0].weight_kg
                end_weight = week_records[-1].weight_kg
                weight_change = end_weight - start_weight
                
                weekly_data.append({
                    "week_start": week_start.date().isoformat(),
                    "week_end": week_end.date().isoformat(),
                    "start_weight": start_weight,
                    "end_weight": end_weight,
                    "weight_change": weight_change,
                    "measurements": len(week_records)
                })
        
        return weekly_data
