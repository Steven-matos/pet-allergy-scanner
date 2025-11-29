"""
Weight Tracking Service
Handles pet weight management, goal tracking, and trend analysis

Fixed: 2025-11-29 - Correct descending parameter for Supabase order()
"""

from typing import List, Optional, Dict, Any, Tuple
from datetime import datetime, date, timedelta
from decimal import Decimal
import statistics
from supabase import Client
from ...utils.logging_config import get_logger
from ...shared.services.datetime_service import DateTimeService
from ...shared.services.database_operation_service import DatabaseOperationService
from app.models.nutrition.advanced_nutrition import (
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
    
    def __init__(self, supabase: 'Client'):
        """
        Initialize weight tracking service
        
        Args:
            supabase: Authenticated Supabase client with user session (for RLS compliance)
        """
        self.supabase = supabase
    
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
        result = await db_service.insert_with_timestamps("pet_weight_records", weight_data, include_created_at=False)
        
        # Update pet's current weight in the pets table
        # Use the most recent recorded weight as the pet's current weight
        logger.info(f"[record_weight] About to update pet weight - pet_id: {weight_record.pet_id}, weight: {weight_record.weight_kg}")
        try:
            await self._update_pet_weight(weight_record.pet_id, float(weight_record.weight_kg))
            logger.info(f"[record_weight] Pet weight update completed successfully")
        except Exception as e:
            logger.error(f"[record_weight] Failed to update pet weight: {str(e)}")
            logger.error(f"[record_weight] Error type: {type(e).__name__}")
            # Continue even if pet weight update fails - we still have the weight record
        
        # Update nutritional trends for this date
        await self._update_nutritional_trends(weight_record.pet_id, weight_record.recorded_at.date())
        
        return PetWeightRecordResponse(**result)
    
    async def get_weight_history(
        self, 
        pet_id: str, 
        user_id: str,
        days_back: int = 365
    ) -> List[PetWeightRecordResponse]:
        """
        Get weight history for a pet
        
        Note: Pet ownership should be verified by the calling router/endpoint
        before calling this method. This method assumes the pet exists and
        the user has access.
        
        Args:
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            days_back: Number of days to look back (default: 365, use 0 for all records)
            
        Returns:
            List of weight records (empty list if no records exist)
        """
        # Get weight records
        # Note: Pet ownership is verified by the router before calling this method
        logger.info(f"[get_weight_history] Starting - pet_id: {pet_id}, days_back: {days_back}")
        logger.info(f"[get_weight_history] Supabase client type: {type(self.supabase)}")
        
        # Build query with pet filter
        query = self.supabase.table("pet_weight_records").select("*").eq("pet_id", pet_id)
        
        # If days_back is 0, get all records; otherwise filter by date
        if days_back > 0:
            start_date = DateTimeService.now() - timedelta(days=days_back)
            query = query.gte("recorded_at", start_date.isoformat())
            logger.info(f"[get_weight_history] Filtering records from {start_date.isoformat()}")
        else:
            logger.info(f"[get_weight_history] Getting ALL weight records (no date filter)")
        
        # Execute query with descending order (most recent first)
        response = query.order("recorded_at", desc=True).execute()
        
        logger.info(f"[get_weight_history] Query executed successfully")
        logger.info(f"[get_weight_history] Found {len(response.data)} weight records for pet {pet_id}")
        
        # Log each record for debugging
        for i, record in enumerate(response.data):
            logger.info(f"[get_weight_history] Record {i+1}: weight={record.get('weight_kg')}kg, recorded_at={record.get('recorded_at')}")
        
        # Return empty list if no records exist (200 status with empty data)
        records = [PetWeightRecordResponse(**record) for record in response.data]
        logger.info(f"[get_weight_history] Returning {len(records)} serialized records")
        return records
    
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
            result = await db_service.insert_with_timestamps("pet_weight_goals", goal_data)
            
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
        logger.info(f"[get_active_weight_goal] Fetching active weight goal for pet {pet_id}")
        logger.info(f"[get_active_weight_goal] User ID: {user_id}")
        logger.info(f"[get_active_weight_goal] Query: pet_weight_goals where pet_id={pet_id} AND is_active=True")
        
        # First, verify the pet exists and user has access
        try:
            pet_check = self.supabase.table("pets").select("id, user_id").eq("id", pet_id).execute()
            logger.info(f"[get_active_weight_goal] Pet check result: {len(pet_check.data)} pets found")
            if pet_check.data:
                logger.info(f"[get_active_weight_goal] Pet belongs to user: {pet_check.data[0].get('user_id')}")
        except Exception as e:
            logger.error(f"[get_active_weight_goal] Error checking pet: {e}")
        
        response = self.supabase.table("pet_weight_goals")\
            .select("*")\
            .eq("pet_id", pet_id)\
            .eq("is_active", True)\
            .execute()
        
        logger.info(f"[get_active_weight_goal] Query executed")
        logger.info(f"[get_active_weight_goal] Response status: {getattr(response, 'status_code', 'N/A')}")
        logger.info(f"[get_active_weight_goal] Response data count: {len(response.data) if response.data else 0}")
        logger.info(f"[get_active_weight_goal] Response data: {response.data}")
        
        if not response.data:
            logger.warning(f"[get_active_weight_goal] No active weight goal found for pet {pet_id}")
            logger.warning(f"[get_active_weight_goal] This might be due to:")
            logger.warning(f"  1. No goal exists in database")
            logger.warning(f"  2. Goal exists but is_active=false")
            logger.warning(f"  3. RLS policy blocking access")
            logger.warning(f"  4. Goal exists for different pet_id")
            return None
    
    async def delete_weight_record(self, record_id: str, pet_id: str, user_id: str) -> dict:
        """
        Delete a weight record and update pet's weight to previous record
        
        This is used for the "undo" functionality. When a weight record is deleted,
        the pet's weight is automatically updated to the second-most-recent weight,
        or cleared if no previous weights exist.
        
        Args:
            record_id: Weight record ID to delete
            pet_id: Pet ID
            user_id: User ID for authorization (used for logging/audit)
            
        Returns:
            Dict with success message and updated pet weight info
        """
        logger.info(f"[delete_weight_record] Starting - record_id: {record_id}, pet_id: {pet_id}")
        
        try:
            # Delete the weight record
            delete_response = self.supabase.table("pet_weight_records").delete().eq("id", record_id).execute()
            
            if not delete_response.data:
                logger.error(f"[delete_weight_record] Failed to delete record {record_id}")
                raise Exception("Failed to delete weight record")
            
            logger.info(f"[delete_weight_record] Record deleted successfully")
            
            # Get the most recent weight after deletion (if any)
            history_response = self.supabase.table("pet_weight_records") \
                .select("*") \
                .eq("pet_id", pet_id) \
                .order("recorded_at", desc=True) \
                .limit(1) \
                .execute()
            
            if history_response.data and len(history_response.data) > 0:
                # Update pet weight to the previous recorded weight
                previous_weight = float(history_response.data[0]["weight_kg"])
                logger.info(f"[delete_weight_record] Found previous weight: {previous_weight} kg")
                
                await self._update_pet_weight(pet_id, previous_weight)
                
                return {
                    "success": True,
                    "message": "Weight record deleted and pet weight updated to previous record",
                    "updated_weight_kg": previous_weight
                }
            else:
                # No previous weights - clear the pet's weight
                logger.info(f"[delete_weight_record] No previous weights found, clearing pet weight")
                
                db_service = DatabaseOperationService(self.supabase)
                await db_service.update_with_timestamp("pets", pet_id, {"weight_kg": None})
                
                return {
                    "success": True,
                    "message": "Weight record deleted and pet weight cleared (no previous records)",
                    "updated_weight_kg": None
                }
                
        except Exception as e:
            logger.error(f"[delete_weight_record] Error: {str(e)}")
            raise
        
        goal_data = response.data[0]
        logger.info(f"[get_active_weight_goal] Found active weight goal:")
        logger.info(f"  - ID: {goal_data.get('id')}")
        logger.info(f"  - Goal Type: {goal_data.get('goal_type')}")
        logger.info(f"  - Target Weight: {goal_data.get('target_weight_kg')} kg")
        logger.info(f"  - Current Weight: {goal_data.get('current_weight_kg')} kg")
        logger.info(f"  - Target Date: {goal_data.get('target_date')}")
        logger.info(f"  - Is Active: {goal_data.get('is_active')}")
        logger.info(f"  - Notes: {goal_data.get('notes')}")
        
        return PetWeightGoalResponse(**goal_data)
    
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
        
        # Get recommendations from recommendation service
        try:
            from app.services.analytics.recommendation_service import RecommendationService
            recommendation_service = RecommendationService()
            
            # Generate weight-based recommendations
            weight_trend_data = {
                "weight_trend": weight_trend.trend_direction.value if weight_trend else "stable",
                "weight_change": weight_trend.weight_change_kg if weight_trend else 0.0,
                "trend_strength": weight_trend.trend_strength.value if weight_trend else "weak"
            }
            
            health_recommendations = await recommendation_service.generate_health_recommendations(
                pet_id=pet_id,
                user_id=user_id,
                health_data=weight_trend_data
            )
            
            # Convert to list of recommendation strings for dashboard
            recommendations = [
                rec.get("description", "") for rec in health_recommendations
            ]
        except Exception as e:
            logger.warning(f"Failed to generate recommendations: {e}")
            recommendations = []
        
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
    
    async def _update_pet_weight(self, pet_id: str, weight_kg: float) -> None:
        """
        Update pet's current weight in the pets table
        
        This ensures the pet's profile weight matches the most recent recorded weight.
        We always update the pet table with the newly recorded weight since we know
        there's at least one recorded weight (the one we just created).
        
        Args:
            pet_id: Pet ID
            weight_kg: Weight in kg to set as current weight (from the newly recorded weight)
        """
        try:
            logger.info(f"[_update_pet_weight] Starting - pet_id: {pet_id}, weight_kg: {weight_kg}")
            
            # First, verify the pet exists before updating
            check_response = self.supabase.table("pets").select("id, weight_kg").eq("id", pet_id).execute()
            if not check_response.data:
                logger.error(f"[_update_pet_weight] Pet {pet_id} not found in database")
                return
            
            existing_weight = check_response.data[0].get("weight_kg")
            logger.info(f"[_update_pet_weight] Current pet weight in DB: {existing_weight} kg")
            
            # Update pet's weight in the pets table
            update_data = {"weight_kg": float(weight_kg)}
            db_service = DatabaseOperationService(self.supabase)
            updated_pet = await db_service.update_with_timestamp("pets", pet_id, update_data)
            
            logger.info(f"[_update_pet_weight] Update successful")
            logger.info(f"[_update_pet_weight] Updated pet data: {updated_pet}")
            logger.info(f"[_update_pet_weight] New weight from update: {updated_pet.get('weight_kg')} kg")
            
        except Exception as e:
            # Log error but don't fail the weight recording
            logger.error(f"[_update_pet_weight] Failed to update pet weight: {e}", exc_info=True)
    
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
