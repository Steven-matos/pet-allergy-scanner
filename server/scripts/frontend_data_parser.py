#!/usr/bin/env python3
"""
Frontend Data Parser for Pet Food Items
Handles consistent parsing of food_items data for frontend consumption.
"""

import json
import re
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

@dataclass
class ParsedIngredient:
    """Standardized ingredient structure for frontend."""
    name: str
    percentage: Optional[float] = None
    category: Optional[str] = None
    is_allergen: bool = False

@dataclass
class ParsedFoodItem:
    """Standardized food item structure for frontend."""
    id: str
    name: str
    brand: str
    barcode: str
    category: str
    species: str
    life_stage: str
    product_type: str
    quantity: str
    country: str
    image_url: str
    ingredients: List[ParsedIngredient]
    allergens: List[str]
    nutritional_info: Dict[str, Any]
    data_quality_score: float
    language: str

class FoodItemParser:
    """Parser for food_items data to ensure consistent frontend format."""
    
    def __init__(self):
        # Common allergen keywords to identify potential allergens
        self.allergen_keywords = {
            'chicken', 'beef', 'fish', 'salmon', 'tuna', 'lamb', 'turkey', 'duck',
            'corn', 'wheat', 'soy', 'soybean', 'dairy', 'milk', 'cheese', 'eggs',
            'chocolate', 'grapes', 'raisins', 'onions', 'garlic', 'xylitol'
        }
        
        # Language codes to filter for English
        self.english_language_codes = {'en', 'english', 'en-us', 'en-gb'}
    
    def parse_ingredient(self, ingredient_text: str) -> ParsedIngredient:
        """Parse individual ingredient text into structured data."""
        if not ingredient_text or not isinstance(ingredient_text, str):
            return ParsedIngredient(name="Unknown")
        
        # Clean the ingredient text
        ingredient_text = ingredient_text.strip()
        
        # Remove common prefixes
        if ingredient_text.startswith('en:'):
            ingredient_text = ingredient_text[3:]
        
        # Extract percentage if present (e.g., "beef (4%)" -> name: "beef", percentage: 4.0)
        percentage = None
        name = ingredient_text
        
        percentage_match = re.search(r'\((\d+(?:\.\d+)?)\s*%\)', ingredient_text)
        if percentage_match:
            percentage = float(percentage_match.group(1))
            name = re.sub(r'\s*\(\d+(?:\.\d+)?\s*%\)', '', ingredient_text).strip()
        
        # Remove parentheses content that's not percentage
        name = re.sub(r'\([^)]*\)', '', name).strip()
        
        # Check if ingredient is a potential allergen
        name_lower = name.lower()
        is_allergen = any(keyword in name_lower for keyword in self.allergen_keywords)
        
        return ParsedIngredient(
            name=name,
            percentage=percentage,
            is_allergen=is_allergen
        )
    
    def parse_ingredients(self, ingredients_data: Any) -> List[ParsedIngredient]:
        """Parse ingredients from various data sources."""
        if not ingredients_data:
            return []
        
        ingredients = []
        
        if isinstance(ingredients_data, list):
            for item in ingredients_data:
                if isinstance(item, str):
                    parsed = self.parse_ingredient(item)
                    if parsed.name:
                        ingredients.append(parsed)
        
        elif isinstance(ingredients_data, dict):
            # Handle structured ingredient data
            if 'ingredients' in ingredients_data:
                return self.parse_ingredients(ingredients_data['ingredients'])
        
        return ingredients
    
    def parse_allergens(self, allergens_data: Any) -> List[str]:
        """Parse allergens from various data sources."""
        if not allergens_data:
            return []
        
        allergens = []
        
        if isinstance(allergens_data, list):
            for item in allergens_data:
                if isinstance(item, str):
                    # Clean allergen name
                    allergen = item.strip()
                    if allergen.startswith('en:'):
                        allergen = allergen[3:]
                    allergens.append(allergen)
        
        return allergens
    
    def calculate_data_quality_score(self, item_data: Dict[str, Any]) -> float:
        """Calculate data quality score based on completeness."""
        score = 0.0
        max_score = 10.0
        
        # Basic info (4 points)
        if item_data.get('name'):
            score += 1.0
        if item_data.get('brand'):
            score += 1.0
        if item_data.get('barcode'):
            score += 1.0
        if item_data.get('category'):
            score += 1.0
        
        # Species and life stage (2 points)
        if item_data.get('species') and item_data.get('species') != 'unknown':
            score += 1.0
        if item_data.get('life_stage') and item_data.get('life_stage') != 'unknown':
            score += 1.0
        
        # Nutritional info (2 points)
        nutritional_info = item_data.get('nutritional_info', {})
        if nutritional_info:
            if nutritional_info.get('calories_per_100g') is not None:
                score += 0.5
            if nutritional_info.get('protein_percentage') is not None:
                score += 0.5
            if nutritional_info.get('fat_percentage') is not None:
                score += 0.5
            if nutritional_info.get('fiber_percentage') is not None:
                score += 0.5
        
        # Ingredients and allergens (2 points)
        if item_data.get('ingredients_hierarchy'):
            score += 1.0
        if item_data.get('allergens_hierarchy'):
            score += 1.0
        
        return min(score / max_score, 1.0)
    
    def parse_food_item(self, raw_data: Dict[str, Any]) -> Optional[ParsedFoodItem]:
        """Parse raw food item data into standardized format."""
        try:
            # Filter for English language only
            language = raw_data.get('language', '').lower()
            if language not in self.english_language_codes:
                return None
            
            # Parse ingredients
            ingredients = []
            if raw_data.get('ingredients_hierarchy'):
                ingredients = self.parse_ingredients(raw_data['ingredients_hierarchy'])
            elif raw_data.get('nutritional_info', {}).get('ingredients'):
                ingredients = self.parse_ingredients(raw_data['nutritional_info']['ingredients'])
            
            # Parse allergens
            allergens = []
            if raw_data.get('allergens_hierarchy'):
                allergens = self.parse_allergens(raw_data['allergens_hierarchy'])
            
            # Calculate data quality score
            data_quality_score = self.calculate_data_quality_score(raw_data)
            
            # Only return items with minimum quality score
            if data_quality_score < 0.3:
                return None
            
            return ParsedFoodItem(
                id=str(raw_data.get('id', '')),
                name=raw_data.get('name', 'Unknown Product'),
                brand=raw_data.get('brand', ''),
                barcode=raw_data.get('barcode', ''),
                category=raw_data.get('category', ''),
                species=raw_data.get('species', 'unknown'),
                life_stage=raw_data.get('life_stage', 'unknown'),
                product_type=raw_data.get('product_type', 'unknown'),
                quantity=raw_data.get('quantity', ''),
                country=raw_data.get('country', ''),
                image_url=raw_data.get('image_url', ''),
                ingredients=ingredients,
                allergens=allergens,
                nutritional_info=raw_data.get('nutritional_info', {}),
                data_quality_score=data_quality_score,
                language=language
            )
        
        except Exception as e:
            print(f"Error parsing food item: {e}")
            return None
    
    def to_frontend_format(self, parsed_item: ParsedFoodItem) -> Dict[str, Any]:
        """Convert parsed item to frontend-friendly format."""
        return {
            "id": parsed_item.id,
            "name": parsed_item.name,
            "brand": parsed_item.brand,
            "barcode": parsed_item.barcode,
            "category": parsed_item.category,
            "species": parsed_item.species,
            "life_stage": parsed_item.life_stage,
            "product_type": parsed_item.product_type,
            "quantity": parsed_item.quantity,
            "country": parsed_item.country,
            "image_url": parsed_item.image_url,
            "ingredients": [
                {
                    "name": ing.name,
                    "percentage": ing.percentage,
                    "is_allergen": ing.is_allergen
                }
                for ing in parsed_item.ingredients
            ],
            "allergens": parsed_item.allergens,
            "nutritional_info": parsed_item.nutritional_info,
            "data_quality_score": parsed_item.data_quality_score,
            "language": parsed_item.language
        }

def create_sql_query_for_frontend() -> str:
    """Generate SQL query optimized for frontend with English filtering."""
    return """
    SELECT 
        id,
        name,
        brand,
        barcode,
        category,
        species,
        life_stage,
        product_type,
        quantity,
        country,
        image_url,
        ingredients_hierarchy,
        allergens_hierarchy,
        nutritional_info,
        data_completeness,
        language
    FROM public.food_items 
    WHERE language = 'en'
    AND data_completeness >= 0.3
    AND name IS NOT NULL
    AND name != ''
    ORDER BY data_completeness DESC, name ASC
    """

def example_usage():
    """Example of how to use the parser."""
    parser = FoodItemParser()
    
    # Example raw data from your database
    raw_data = {
        "id": "123",
        "name": "Purina Adult Dog Food",
        "brand": "Purina",
        "barcode": "1234567890",
        "category": "Dog Food",
        "species": "dog",
        "life_stage": "adult",
        "product_type": "dry",
        "language": "en",
        "ingredients_hierarchy": [
            "Chicken (25%)",
            "Rice (20%)",
            "Corn meal",
            "Fish meal (5%)"
        ],
        "allergens_hierarchy": ["en:fish", "Fish"],
        "nutritional_info": {
            "calories_per_100g": 350,
            "protein_percentage": 25.0,
            "fat_percentage": 15.0,
            "fiber_percentage": 4.0
        }
    }
    
    # Parse the data
    parsed_item = parser.parse_food_item(raw_data)
    
    if parsed_item:
        # Convert to frontend format
        frontend_data = parser.to_frontend_format(parsed_item)
        print("Frontend-ready data:")
        print(json.dumps(frontend_data, indent=2))
    else:
        print("Item filtered out (non-English or low quality)")

if __name__ == '__main__':
    example_usage()
