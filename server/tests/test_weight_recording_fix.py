"""
Test for weight recording async/await fix

This test verifies that the weight recording endpoint works correctly
after fixing the missing await statements.
"""

import pytest
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.weight_tracking_service import WeightTrackingService
from app.models.advanced_nutrition import PetWeightRecordCreate


@pytest.mark.asyncio
async def test_weight_recording_with_await():
    """Test that weight recording properly awaits database operations"""
    
    # Mock the Supabase client
    mock_supabase = MagicMock()
    
    # Mock the RPC call for nutritional trends
    mock_rpc = MagicMock()
    mock_rpc.execute.return_value = MagicMock(data=None)
    mock_supabase.rpc.return_value = mock_rpc
    
    # Create service instance
    service = WeightTrackingService()
    service.supabase = mock_supabase
    
    # Mock DatabaseOperationService.insert_with_timestamps to return a dict
    mock_db_result = {
        "id": "test-weight-id",
        "pet_id": "test-pet-id",
        "weight_kg": 5.5,
        "recorded_at": "2024-11-28T16:00:00Z",
        "notes": "Test weight",
        "recorded_by_user_id": "test-user-id",
        "created_at": "2024-11-28T16:00:00Z",
        "updated_at": "2024-11-28T16:00:00Z"
    }
    
    with patch('app.services.weight_tracking_service.DatabaseOperationService') as MockDBService:
        # Create an async mock that returns the expected data
        mock_db_instance = MagicMock()
        mock_db_instance.insert_with_timestamps = AsyncMock(return_value=mock_db_result)
        MockDBService.return_value = mock_db_instance
        
        # Create test data
        weight_record = PetWeightRecordCreate(
            pet_id="test-pet-id",
            weight_kg=5.5,
            recorded_at=datetime(2024, 11, 28, 16, 0, 0),
            notes="Test weight"
        )
        
        # Call the service method
        result = await service.record_weight(weight_record, "test-user-id")
        
        # Verify the database operation was called with await
        mock_db_instance.insert_with_timestamps.assert_called_once()
        
        # Verify the result is a PetWeightRecordResponse object, not a coroutine
        assert result.id == "test-weight-id"
        assert result.pet_id == "test-pet-id"
        assert result.weight_kg == 5.5
        assert result.notes == "Test weight"
        
        # Verify it's not a coroutine
        assert not hasattr(result, '__await__'), "Result should not be a coroutine"


@pytest.mark.asyncio
async def test_weight_goal_creation_with_await():
    """Test that weight goal creation properly awaits database operations"""
    
    # Mock the Supabase client
    mock_supabase = MagicMock()
    
    # Mock the select query to return no existing goal
    mock_select = MagicMock()
    mock_select.eq.return_value = mock_select
    mock_select.execute.return_value = MagicMock(data=[])
    mock_supabase.table.return_value.select.return_value = mock_select
    
    # Create service instance
    service = WeightTrackingService()
    service.supabase = mock_supabase
    
    # Mock DatabaseOperationService.insert_with_timestamps
    mock_db_result = {
        "id": "test-goal-id",
        "pet_id": "test-pet-id",
        "goal_type": "weight_loss",
        "target_weight_kg": 5.0,
        "current_weight_kg": 6.0,
        "target_date": "2024-12-31",
        "is_active": True,
        "notes": "Weight loss goal",
        "created_at": "2024-11-28T16:00:00Z",
        "updated_at": "2024-11-28T16:00:00Z"
    }
    
    with patch('app.services.weight_tracking_service.DatabaseOperationService') as MockDBService:
        mock_db_instance = MagicMock()
        mock_db_instance.insert_with_timestamps = AsyncMock(return_value=mock_db_result)
        MockDBService.return_value = mock_db_instance
        
        from app.models.advanced_nutrition import PetWeightGoalCreate, GoalType
        
        # Create test data
        goal = PetWeightGoalCreate(
            pet_id="test-pet-id",
            goal_type=GoalType.WEIGHT_LOSS,
            target_weight_kg=5.0,
            current_weight_kg=6.0,
            target_date=datetime(2024, 12, 31).date(),
            is_active=True,
            notes="Weight loss goal"
        )
        
        # Call the service method
        result = await service.upsert_weight_goal(goal, "test-user-id")
        
        # Verify the database operation was called with await
        mock_db_instance.insert_with_timestamps.assert_called_once()
        
        # Verify the result is a PetWeightGoalResponse object, not a coroutine
        assert result.id == "test-goal-id"
        assert result.pet_id == "test-pet-id"
        assert result.goal_type == GoalType.WEIGHT_LOSS
        
        # Verify it's not a coroutine
        assert not hasattr(result, '__await__'), "Result should not be a coroutine"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

