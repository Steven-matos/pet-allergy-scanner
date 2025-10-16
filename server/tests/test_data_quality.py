"""
Data Quality Service Tests
Test the enhanced data quality assessment functionality
"""

import pytest
from app.services.data_quality_service import (
    DataQualityService, 
    DataQualityMetrics, 
    DataQualityLevel
)


class TestDataQualityService:
    """Test cases for DataQualityService"""
    
    def test_calculate_ingredients_score_empty(self):
        """Test ingredients score calculation with empty list"""
        score, count = DataQualityService.calculate_ingredients_score([])
        assert score == 0.0
        assert count == 0
    
    def test_calculate_ingredients_score_basic(self):
        """Test ingredients score calculation with basic ingredients"""
        ingredients = ["chicken", "rice"]
        score, count = DataQualityService.calculate_ingredients_score(ingredients)
        assert score == 0.2  # Very basic
        assert count == 2
    
    def test_calculate_ingredients_score_good(self):
        """Test ingredients score calculation with good ingredient list"""
        ingredients = ["chicken", "rice", "carrots", "peas", "chicken fat", "natural flavor"]
        score, count = DataQualityService.calculate_ingredients_score(ingredients)
        assert score == 0.7  # Good
        assert count == 6
    
    def test_calculate_ingredients_score_excellent(self):
        """Test ingredients score calculation with excellent ingredient list"""
        ingredients = [
            "chicken", "rice", "carrots", "peas", "chicken fat", "natural flavor",
            "vitamin A", "vitamin D", "vitamin E", "thiamine", "riboflavin",
            "niacin", "pantothenic acid", "pyridoxine", "folic acid"
        ]
        score, count = DataQualityService.calculate_ingredients_score(ingredients)
        assert score == 1.0  # Excellent
        assert count == 15
    
    def test_calculate_nutritional_score_empty(self):
        """Test nutritional score calculation with empty data"""
        nutritional_data = {}
        score, count = DataQualityService.calculate_nutritional_score(nutritional_data)
        assert score == 0.0
        assert count == 0
    
    def test_calculate_nutritional_score_basic(self):
        """Test nutritional score calculation with basic nutritional data"""
        nutritional_data = {
            "calories_per_100g": 350.0,
            "protein_percentage": 25.0,
            "fat_percentage": 15.0
        }
        score, count = DataQualityService.calculate_nutritional_score(nutritional_data)
        # Critical fields: 3 * 0.4 = 1.2, capped at 1.0
        assert score == 1.0
        assert count == 3
    
    def test_calculate_nutritional_score_good(self):
        """Test nutritional score calculation with good nutritional data"""
        nutritional_data = {
            "calories_per_100g": 350.0,
            "protein_percentage": 25.0,
            "fat_percentage": 15.0,
            "fiber_percentage": 3.0,
            "moisture_percentage": 10.0,
            "ash_percentage": 8.0,
            "carbohydrates_percentage": 40.0
        }
        score, count = DataQualityService.calculate_nutritional_score(nutritional_data)
        # Critical: 5 * 0.4 = 2.0, Important: 2 * 0.2 = 0.4, Total = 2.4, capped at 1.0
        assert score == 1.0
        assert count == 7
    
    def test_calculate_nutritional_score_excellent(self):
        """Test nutritional score calculation with excellent nutritional data"""
        nutritional_data = {
            "calories_per_100g": 350.0,
            "protein_percentage": 25.0,
            "fat_percentage": 15.0,
            "fiber_percentage": 3.0,
            "moisture_percentage": 10.0,
            "ash_percentage": 8.0,
            "carbohydrates_percentage": 40.0,
            "sodium_percentage": 0.5,
            "sugars_percentage": 2.0,
            "saturated_fat_percentage": 5.0
        }
        score, count = DataQualityService.calculate_nutritional_score(nutritional_data)
        # All fields present: 5*0.4 + 3*0.2 + 2*0.1 = 2.0 + 0.6 + 0.2 = 2.8, capped at 1.0
        assert score == 1.0
        assert count == 10
    
    def test_calculate_completeness_score_basic(self):
        """Test completeness score calculation with basic food item"""
        food_item = {
            "name": "Test Dog Food",
            "brand": "Test Brand",
            "barcode": "123456789",
            "nutritional_info": {
                "calories_per_100g": 350.0,
                "protein_percentage": 25.0,
                "ingredients": ["chicken", "rice"]
            }
        }
        score = DataQualityService.calculate_completeness_score(food_item)
        # Basic info: 0.3, Nutritional: 0.8 * 0.5 = 0.4, Ingredients: 0.2 * 0.2 = 0.04
        # Total: 0.3 + 0.4 + 0.04 = 0.74
        assert abs(score - 0.74) < 0.001  # Allow for floating point precision
    
    def test_identify_missing_critical_fields(self):
        """Test identification of missing critical fields"""
        nutritional_data = {
            "calories_per_100g": 350.0,
            "protein_percentage": 25.0,
            # Missing: fat_percentage, fiber_percentage, moisture_percentage
        }
        missing_fields = DataQualityService.identify_missing_critical_fields(nutritional_data)
        expected_missing = ["fat_percentage", "fiber_percentage", "moisture_percentage"]
        assert set(missing_fields) == set(expected_missing)
    
    def test_generate_quality_indicators(self):
        """Test quality indicators generation"""
        nutritional_data = {
            "calories_per_100g": 350.0,
            "protein_percentage": 25.0,
            "allergens": ["chicken"],
            "vitamins": ["vitamin A", "vitamin D"]
        }
        ingredients = ["chicken", "rice"]
        
        indicators = DataQualityService.generate_quality_indicators(nutritional_data, ingredients)
        
        assert indicators["has_calories"] == True
        assert indicators["has_protein"] == True
        assert indicators["has_fat"] == False
        assert indicators["has_ingredients"] == True
        assert indicators["has_allergens"] == True
        assert indicators["has_vitamins"] == True
        assert indicators["has_minerals"] == False
    
    def test_assess_data_quality_excellent(self):
        """Test comprehensive data quality assessment - excellent quality"""
        food_item = {
            "name": "Premium Dog Food",
            "brand": "Healthy Paws",
            "barcode": "123456789",
            "nutritional_info": {
                "calories_per_100g": 350.0,
                "protein_percentage": 25.0,
                "fat_percentage": 15.0,
                "fiber_percentage": 3.0,
                "moisture_percentage": 10.0,
                "ash_percentage": 8.0,
                "carbohydrates_percentage": 40.0,
                "sodium_percentage": 0.5,
                "sugars_percentage": 2.0,
                "saturated_fat_percentage": 5.0,
                "ingredients": [
                    "chicken", "rice", "carrots", "peas", "chicken fat", 
                    "natural flavor", "vitamin A", "vitamin D", "vitamin E",
                    "thiamine", "riboflavin", "niacin", "pantothenic acid"
                ],
                "allergens": ["chicken"],
                "vitamins": ["vitamin A", "vitamin D", "vitamin E"],
                "minerals": ["calcium", "phosphorus", "iron"]
            }
        }
        
        metrics = DataQualityService.assess_data_quality(food_item)
        
        assert metrics.level == DataQualityLevel.EXCELLENT
        assert metrics.overall_score >= 0.9
        assert metrics.ingredients_count == 13
        assert metrics.nutritional_fields_count == 10
        assert len(metrics.missing_critical_fields) == 0
        assert metrics.quality_indicators["has_ingredients"] == True
        assert metrics.quality_indicators["has_vitamins"] == True
        assert metrics.quality_indicators["has_minerals"] == True
    
    def test_assess_data_quality_poor(self):
        """Test comprehensive data quality assessment - poor quality"""
        food_item = {
            "name": "Basic Dog Food",
            "brand": None,
            "barcode": None,
            "nutritional_info": {
                "calories_per_100g": 350.0,
                # Missing most nutritional data
                "ingredients": []  # No ingredients
            }
        }
        
        metrics = DataQualityService.assess_data_quality(food_item)
        
        assert metrics.level == DataQualityLevel.POOR
        assert metrics.overall_score < 0.5
        assert metrics.ingredients_count == 0
        assert metrics.nutritional_fields_count == 1
        assert len(metrics.missing_critical_fields) == 4  # Missing 4 critical fields
        assert metrics.quality_indicators["has_ingredients"] == False
        assert metrics.quality_indicators["has_protein"] == False
    
    def test_get_quality_recommendations(self):
        """Test quality improvement recommendations"""
        # Create poor quality metrics
        metrics = DataQualityMetrics(
            overall_score=0.3,
            level=DataQualityLevel.POOR,
            ingredients_score=0.0,
            nutritional_score=0.4,
            completeness_score=0.3,
            ingredients_count=0,
            nutritional_fields_count=2,
            missing_critical_fields=["fat_percentage", "fiber_percentage", "moisture_percentage"],
            quality_indicators={
                "has_ingredients": False,
                "has_allergens": False,
                "has_protein": True
            }
        )
        
        recommendations = DataQualityService.get_quality_recommendations(metrics)
        
        assert "Add ingredient list for better product transparency" in recommendations
        assert "Add basic nutritional information (calories, protein, fat)" in recommendations
        assert any("missing critical nutritional data" in rec for rec in recommendations)
        assert "Include allergen information for pet safety" in recommendations
    
    def test_format_quality_summary(self):
        """Test quality summary formatting"""
        food_item = {
            "name": "Test Dog Food",
            "brand": "Test Brand",
            "nutritional_info": {
                "calories_per_100g": 350.0,
                "protein_percentage": 25.0,
                "ingredients": ["chicken", "rice"]
            }
        }
        
        metrics = DataQualityService.assess_data_quality(food_item)
        summary = DataQualityService.format_quality_summary(metrics)
        
        assert "overall_score" in summary
        assert "quality_level" in summary
        assert "breakdown" in summary
        assert "recommendations" in summary
        assert summary["overall_score"] <= 1.0
        assert summary["quality_level"] in ["excellent", "good", "fair", "poor"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
