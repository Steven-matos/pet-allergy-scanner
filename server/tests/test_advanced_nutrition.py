"""
Advanced Nutritional Analysis Tests
Comprehensive test suite for weight tracking, trends, comparisons, and analytics
"""

import pytest
import asyncio
from datetime import datetime, date, timedelta
from decimal import Decimal
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch, MagicMock

from app.main import app
from app.models.advanced_nutrition import (
    PetWeightRecordCreate, PetWeightGoalCreate, WeightGoalType,
    FoodComparisonCreate, AnalyticsType
)
from app.services.weight_tracking_service import WeightTrackingService
from app.services.nutritional_trends_service import NutritionalTrendsService
from app.services.food_comparison_service import FoodComparisonService
from app.services.advanced_analytics_service import AdvancedAnalyticsService

client = TestClient(app)

# Test data
TEST_PET_ID = "test-pet-123"
TEST_USER_ID = "test-user-123"
TEST_WEIGHT_RECORD = PetWeightRecordCreate(
    pet_id=TEST_PET_ID,
    weight_kg=25.5,
    notes="Morning weight measurement"
)
TEST_WEIGHT_GOAL = PetWeightGoalCreate(
    pet_id=TEST_PET_ID,
    goal_type=WeightGoalType.MAINTENANCE,
    target_weight_kg=25.0,
    target_date=date.today() + timedelta(days=30),
    notes="Maintain healthy weight"
)
TEST_FOOD_COMPARISON = FoodComparisonCreate(
    comparison_name="Premium Food Comparison",
    food_ids=["food-1", "food-2", "food-3"]
)


class TestWeightTracking:
    """Test weight tracking functionality"""
    
    @pytest.mark.asyncio
    async def test_record_weight_success(self):
        """Test successful weight recording"""
        with patch('app.services.weight_tracking_service.WeightTrackingService.record_weight') as mock_record:
            mock_record.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/weight/record",
                json=TEST_WEIGHT_RECORD.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_record.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_record_weight_invalid_data(self):
        """Test weight recording with invalid data"""
        invalid_record = PetWeightRecordCreate(
            pet_id=TEST_PET_ID,
            weight_kg=-5.0,  # Invalid negative weight
            notes="Invalid weight"
        )
        
        response = client.post(
            "/api/v1/phase3/weight/record",
            json=invalid_record.dict(),
            headers={"Authorization": "Bearer test-token"}
        )
        
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_get_weight_history(self):
        """Test getting weight history"""
        with patch('app.services.weight_tracking_service.WeightTrackingService.get_weight_history') as mock_get:
            mock_get.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/weight/history/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_get.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_weight_goal(self):
        """Test creating weight goal"""
        with patch('app.services.weight_tracking_service.WeightTrackingService.create_weight_goal') as mock_create:
            mock_create.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/weight/goals",
                json=TEST_WEIGHT_GOAL.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_create.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_analyze_weight_trend(self):
        """Test weight trend analysis"""
        with patch('app.services.weight_tracking_service.WeightTrackingService.analyze_weight_trend') as mock_analyze:
            mock_analyze.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/weight/trend/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_analyze.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_weight_dashboard(self):
        """Test getting weight management dashboard"""
        with patch('app.services.weight_tracking_service.WeightTrackingService.get_weight_management_dashboard') as mock_dashboard:
            mock_dashboard.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/weight/dashboard/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_dashboard.assert_called_once()


class TestNutritionalTrends:
    """Test nutritional trends functionality"""
    
    @pytest.mark.asyncio
    async def test_get_nutritional_trends(self):
        """Test getting nutritional trends"""
        with patch('app.services.nutritional_trends_service.NutritionalTrendsService.get_nutritional_trends') as mock_get:
            mock_get.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/trends/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_get.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_trends_dashboard(self):
        """Test getting trends dashboard"""
        with patch('app.services.nutritional_trends_service.NutritionalTrendsService.get_trends_dashboard') as mock_dashboard:
            mock_dashboard.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/trends/dashboard/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_dashboard.assert_called_once()


class TestFoodComparison:
    """Test food comparison functionality"""
    
    @pytest.mark.asyncio
    async def test_create_food_comparison(self):
        """Test creating food comparison"""
        with patch('app.services.food_comparison_service.FoodComparisonService.create_comparison') as mock_create:
            mock_create.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/comparisons",
                json=TEST_FOOD_COMPARISON.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_create.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_food_comparison(self):
        """Test getting food comparison"""
        comparison_id = "test-comparison-123"
        
        with patch('app.services.food_comparison_service.FoodComparisonService.get_comparison') as mock_get:
            mock_get.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/comparisons/{comparison_id}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_get.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_user_comparisons(self):
        """Test getting user comparisons"""
        with patch('app.services.food_comparison_service.FoodComparisonService.get_user_comparisons') as mock_get:
            mock_get.return_value = AsyncMock()
            
            response = client.get(
                "/api/v1/phase3/comparisons",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_get.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_food_comparison(self):
        """Test deleting food comparison"""
        comparison_id = "test-comparison-123"
        
        with patch('app.services.food_comparison_service.FoodComparisonService.delete_comparison') as mock_delete:
            mock_delete.return_value = AsyncMock(return_value=True)
            
            response = client.delete(
                f"/api/v1/phase3/comparisons/{comparison_id}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_delete.assert_called_once()


class TestAdvancedAnalytics:
    """Test advanced analytics functionality"""
    
    @pytest.mark.asyncio
    async def test_generate_analytics(self):
        """Test generating analytics"""
        with patch('app.services.advanced_analytics_service.AdvancedAnalyticsService.generate_analytics') as mock_generate:
            mock_generate.return_value = AsyncMock()
            
            response = client.post(
                f"/api/v1/phase3/analytics/generate?pet_id={TEST_PET_ID}&analysis_type=weekly_summary",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_generate.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_health_insights(self):
        """Test getting health insights"""
        with patch('app.services.advanced_analytics_service.AdvancedAnalyticsService.get_health_insights') as mock_insights:
            mock_insights.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/analytics/health-insights/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_insights.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_analyze_nutritional_patterns(self):
        """Test analyzing nutritional patterns"""
        with patch('app.services.advanced_analytics_service.AdvancedAnalyticsService.analyze_nutritional_patterns') as mock_patterns:
            mock_patterns.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/analytics/patterns/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_patterns.assert_called_once()


class TestPhase3Dashboard:
    """Test comprehensive Phase 3 dashboard"""
    
    @pytest.mark.asyncio
    async def test_get_phase3_dashboard(self):
        """Test getting Phase 3 dashboard"""
        with patch('app.routers.phase3_nutrition.asyncio.gather') as mock_gather:
            mock_gather.return_value = AsyncMock(return_value=([], None, [], None))
            
            response = client.get(
                f"/api/v1/phase3/dashboard/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            
            assert response.status_code == 200
            mock_gather.assert_called_once()


class TestWeightTrackingService:
    """Test weight tracking service directly"""
    
    @pytest.mark.asyncio
    async def test_record_weight_service(self):
        """Test weight recording service method"""
        service = WeightTrackingService()
        
        with patch.object(service, 'supabase') as mock_supabase:
            # Mock pet verification
            mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"id": TEST_PET_ID}]
            
            # Mock weight record insertion
            mock_supabase.table.return_value.insert.return_value.execute.return_value.data = [{
                "id": "weight-123",
                "pet_id": TEST_PET_ID,
                "weight_kg": 25.5,
                "recorded_at": datetime.utcnow().isoformat(),
                "notes": "Test weight",
                "recorded_by_user_id": TEST_USER_ID,
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }]
            
            result = await service.record_weight(TEST_WEIGHT_RECORD, TEST_USER_ID)
            
            assert result.pet_id == TEST_PET_ID
            assert result.weight_kg == 25.5
    
    @pytest.mark.asyncio
    async def test_analyze_weight_trend_service(self):
        """Test weight trend analysis service method"""
        service = WeightTrackingService()
        
        # Mock weight history
        mock_history = [
            MagicMock(weight_kg=25.0, recorded_at=datetime.utcnow() - timedelta(days=7)),
            MagicMock(weight_kg=25.5, recorded_at=datetime.utcnow())
        ]
        
        with patch.object(service, 'get_weight_history', return_value=mock_history):
            result = service.analyze_weight_trend(TEST_PET_ID, TEST_USER_ID, 30)
            
            assert result.trend_direction in ["increasing", "decreasing", "stable"]
            assert result.weight_change_kg == 0.5
            assert result.days_analyzed == 2


class TestNutritionalTrendsService:
    """Test nutritional trends service directly"""
    
    @pytest.mark.asyncio
    async def test_load_trends_data_service(self):
        """Test loading trends data service method"""
        service = NutritionalTrendsService()
        
        with patch.object(service, 'supabase') as mock_supabase:
            # Mock pet verification
            mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"id": TEST_PET_ID}]
            
            # Mock trends data
            mock_supabase.table.return_value.select.return_value.eq.return_value.gte.return_value.order.return_value.execute.return_value.data = []
            
            await service.load_trends_data(TEST_PET_ID, TEST_USER_ID, 30)
            
            # Verify service was called
            assert mock_supabase.table.called


class TestFoodComparisonService:
    """Test food comparison service directly"""
    
    @pytest.mark.asyncio
    async def test_compare_foods_service(self):
        """Test food comparison service method"""
        service = FoodComparisonService()
        
        with patch.object(service, 'load_food_details') as mock_load:
            mock_load.return_value = [
                MagicMock(id="food-1", name="Food 1", calories_per_100g=300.0),
                MagicMock(id="food-2", name="Food 2", calories_per_100g=350.0)
            ]
            
            result = await service.compare_foods(["food-1", "food-2"], "Test Comparison")
            
            assert result.comparison_name == "Test Comparison"
            assert len(result.foods) == 2


class TestAdvancedAnalyticsService:
    """Test advanced analytics service directly"""
    
    @pytest.mark.asyncio
    async def test_generate_analytics_service(self):
        """Test analytics generation service method"""
        service = AdvancedAnalyticsService()
        
        with patch.object(service, 'supabase') as mock_supabase:
            # Mock pet verification
            mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"id": TEST_PET_ID}]
            
            # Mock analytics generation
            with patch.object(service, '_perform_analysis') as mock_analysis:
                mock_analysis.return_value = {"test": "data"}
                
                with patch.object(service, '_cache_analytics') as mock_cache:
                    mock_cache.return_value = MagicMock()
                    
                    result = await service.generate_analytics(
                        TEST_PET_ID, TEST_USER_ID, AnalyticsType.WEEKLY_SUMMARY
                    )
                    
                    assert mock_analysis.called
                    assert mock_cache.called


# Integration Tests

class TestAdvancedNutritionIntegration:
    """Integration tests for advanced nutrition features"""
    
    @pytest.mark.asyncio
    async def test_complete_weight_management_flow(self):
        """Test complete weight management workflow"""
        # 1. Record weight
        with patch('app.services.weight_tracking_service.WeightTrackingService.record_weight') as mock_record:
            mock_record.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/weight/record",
                json=TEST_WEIGHT_RECORD.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == 200
        
        # 2. Create weight goal
        with patch('app.services.weight_tracking_service.WeightTrackingService.create_weight_goal') as mock_goal:
            mock_goal.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/weight/goals",
                json=TEST_WEIGHT_GOAL.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == 200
        
        # 3. Get weight dashboard
        with patch('app.services.weight_tracking_service.WeightTrackingService.get_weight_management_dashboard') as mock_dashboard:
            mock_dashboard.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/weight/dashboard/{TEST_PET_ID}",
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_complete_food_comparison_flow(self):
        """Test complete food comparison workflow"""
        # 1. Create comparison
        with patch('app.services.food_comparison_service.FoodComparisonService.create_comparison') as mock_create:
            mock_create.return_value = AsyncMock()
            
            response = client.post(
                "/api/v1/phase3/comparisons",
                json=TEST_FOOD_COMPARISON.dict(),
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == 200
        
        # 2. Get comparison dashboard
        comparison_id = "test-comparison-123"
        with patch('app.services.food_comparison_service.FoodComparisonService.get_comparison_dashboard') as mock_dashboard:
            mock_dashboard.return_value = AsyncMock()
            
            response = client.get(
                f"/api/v1/phase3/comparisons/dashboard/{comparison_id}",
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == 200


# Performance Tests

class TestAdvancedNutritionPerformance:
    """Performance tests for advanced nutrition features"""
    
    @pytest.mark.asyncio
    async def test_weight_trend_analysis_performance(self):
        """Test weight trend analysis performance with large dataset"""
        service = WeightTrackingService()
        
        # Create large mock dataset
        large_history = [
            MagicMock(weight_kg=25.0 + i * 0.1, recorded_at=datetime.utcnow() - timedelta(days=i))
            for i in range(365)  # 1 year of data
        ]
        
        with patch.object(service, 'get_weight_history', return_value=large_history):
            import time
            start_time = time.time()
            
            result = service.analyze_weight_trend(TEST_PET_ID, TEST_USER_ID, 365)
            
            end_time = time.time()
            execution_time = end_time - start_time
            
            # Should complete within reasonable time (1 second)
            assert execution_time < 1.0
            assert result.days_analyzed == 365
    
    @pytest.mark.asyncio
    async def test_food_comparison_performance(self):
        """Test food comparison performance with maximum foods"""
        service = FoodComparisonService()
        
        # Test with maximum allowed foods (10)
        food_ids = [f"food-{i}" for i in range(10)]
        
        with patch.object(service, 'load_food_details') as mock_load:
            mock_load.return_value = [
                MagicMock(id=f"food-{i}", name=f"Food {i}", calories_per_100g=300.0 + i * 10)
                for i in range(10)
            ]
            
            import time
            start_time = time.time()
            
            result = await service.compare_foods(food_ids, "Performance Test")
            
            end_time = time.time()
            execution_time = end_time - start_time
            
            # Should complete within reasonable time (2 seconds)
            assert execution_time < 2.0
            assert len(result.foods) == 10


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
