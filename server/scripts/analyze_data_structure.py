#!/usr/bin/env python3
"""
Analyze Food Items Data Structure
Shows current data structure and inconsistencies for frontend parsing.
"""

import json
import sys
import os
import psycopg2
from dotenv import load_dotenv
from collections import defaultdict

# Load environment variables
load_dotenv()

def analyze_data_structure():
    """Analyze the current data structure in food_items table."""
    
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        print("❌ DATABASE_URL not found in .env file")
        return
    
    try:
        conn = psycopg2.connect(database_url)
        cursor = conn.cursor()
        
        print("🔍 ANALYZING FOOD ITEMS DATA STRUCTURE")
        print("=" * 60)
        
        # Get language distribution
        cursor.execute("SELECT language, COUNT(*) FROM public.food_items GROUP BY language ORDER BY COUNT(*) DESC")
        languages = cursor.fetchall()
        
        print("\n📊 LANGUAGE DISTRIBUTION:")
        for lang, count in languages:
            print(f"  {lang}: {count:,} products")
        
        # Get sample English data
        cursor.execute("""
            SELECT name, brand, language, nutritional_info, ingredients_hierarchy, allergens_hierarchy
            FROM public.food_items 
            WHERE language = 'en' AND nutritional_info IS NOT NULL 
            LIMIT 5
        """)
        
        print("\n🇺🇸 ENGLISH SAMPLE DATA:")
        print("-" * 40)
        
        for row in cursor.fetchall():
            name, brand, language, nutritional_info, ingredients_hierarchy, allergens_hierarchy = row
            print(f"\n📦 Product: {name}")
            print(f"   Brand: {brand}")
            print(f"   Language: {language}")
            
            if nutritional_info:
                print(f"   Nutritional Info Keys: {list(nutritional_info.keys())}")
                if 'ingredients' in nutritional_info:
                    ingredients = nutritional_info['ingredients']
                    print(f"   Ingredients Type: {type(ingredients)}")
                    if isinstance(ingredients, list) and ingredients:
                        print(f"   First Ingredient: {ingredients[0]}")
                        print(f"   Ingredients Count: {len(ingredients)}")
            
            if ingredients_hierarchy:
                print(f"   Ingredients Hierarchy: {ingredients_hierarchy[:3]}...")  # First 3
                
            if allergens_hierarchy:
                print(f"   Allergens Hierarchy: {allergens_hierarchy[:3]}...")  # First 3
        
        # Get sample non-English data for comparison
        cursor.execute("""
            SELECT name, brand, language, nutritional_info, ingredients_hierarchy, allergens_hierarchy
            FROM public.food_items 
            WHERE language != 'en' AND nutritional_info IS NOT NULL 
            LIMIT 3
        """)
        
        print("\n🌍 NON-ENGLISH SAMPLE DATA:")
        print("-" * 40)
        
        for row in cursor.fetchall():
            name, brand, language, nutritional_info, ingredients_hierarchy, allergens_hierarchy = row
            print(f"\n📦 Product: {name}")
            print(f"   Brand: {brand}")
            print(f"   Language: {language}")
            
            if nutritional_info and 'ingredients' in nutritional_info:
                ingredients = nutritional_info['ingredients']
                if isinstance(ingredients, list) and ingredients:
                    print(f"   First Ingredient: {ingredients[0]}")
        
        # Analyze ingredient structure inconsistencies
        cursor.execute("""
            SELECT nutritional_info
            FROM public.food_items 
            WHERE nutritional_info IS NOT NULL 
            AND nutritional_info ? 'ingredients'
            LIMIT 10
        """)
        
        print("\n🔍 INGREDIENT STRUCTURE ANALYSIS:")
        print("-" * 40)
        
        ingredient_patterns = defaultdict(int)
        
        for row in cursor.fetchall():
            nutritional_info = row[0]
            if nutritional_info and 'ingredients' in nutritional_info:
                ingredients = nutritional_info['ingredients']
                if isinstance(ingredients, list):
                    for ingredient in ingredients[:3]:  # First 3 ingredients
                        if isinstance(ingredient, str):
                            # Analyze patterns
                            if '(' in ingredient and ')' in ingredient:
                                ingredient_patterns['parentheses'] += 1
                            if ',' in ingredient:
                                ingredient_patterns['commas'] += 1
                            if ingredient.startswith('en:'):
                                ingredient_patterns['en_prefix'] += 1
                            if any(char.isdigit() for char in ingredient):
                                ingredient_patterns['contains_numbers'] += 1
        
        print("\n📈 INGREDIENT PATTERNS FOUND:")
        for pattern, count in ingredient_patterns.items():
            print(f"  {pattern}: {count} occurrences")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == '__main__':
    analyze_data_structure()
