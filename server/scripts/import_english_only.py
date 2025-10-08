#!/usr/bin/env python3
"""
Import Pet Food Data - English Only
Filters and imports only English language products with consistent data structure.
"""

import json
import sys
import logging
import re
import os
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from typing import Dict, List, Optional, Any

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class EnglishOnlyImporter:
    """Import pet food data with English language filtering and consistent parsing."""
    
    def __init__(self, database_url: str):
        self.database_url = database_url
        self.conn = None
        
        # English language indicators
        self.english_indicators = {
            'en', 'english', 'en-us', 'en-gb', 'en-ca', 'en-au'
        }
        
        # Quality thresholds
        self.min_quality_score = 0.3
        self.min_name_length = 2
        
    def connect(self):
        """Connect to database."""
        try:
            self.conn = psycopg2.connect(self.database_url)
            logger.info("✅ Connected to database")
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            sys.exit(1)
    
    def disconnect(self):
        """Disconnect from database."""
        if self.conn:
            self.conn.close()
    
    def is_english_product(self, product: Dict[str, Any]) -> bool:
        """Check if product is in English language."""
        # Check language field
        language = product.get('lang', '').lower()
        if language in self.english_indicators:
            return True
        
        # Check languages_codes
        languages_codes = product.get('languages_codes', {})
        if isinstance(languages_codes, dict):
            for lang_code in languages_codes.keys():
                if lang_code.lower() in self.english_indicators:
                    return True
        
        # Check product name for English indicators
        product_name = product.get('product_name', '') or product.get('product_name_en', '')
        if product_name:
            # Simple heuristic: if product_name_en exists and product_name doesn't have non-ASCII chars
            if (product.get('product_name_en') and 
                not any(ord(char) > 127 for char in product_name)):
                return True
        
        # Check countries that are primarily English-speaking
        countries = product.get('countries', '').lower()
        english_countries = ['united states', 'usa', 'canada', 'united kingdom', 'uk', 'australia']
        if any(country in countries for country in english_countries):
            return True
        
        return False
    
    def clean_ingredient(self, ingredient: str) -> str:
        """Clean and standardize ingredient text."""
        if not ingredient or not isinstance(ingredient, str):
            return ""
        
        # Remove common prefixes
        ingredient = ingredient.strip()
        if ingredient.startswith('en:'):
            ingredient = ingredient[3:]
        
        # Remove parentheses with percentages but keep the main ingredient
        # e.g., "Chicken (25%)" -> "Chicken"
        ingredient = re.sub(r'\s*\(\d+(?:\.\d+)?\s*%\)', '', ingredient).strip()
        
        # Remove other parentheses content
        ingredient = re.sub(r'\([^)]*\)', '', ingredient).strip()
        
        return ingredient
    
    def extract_ingredients(self, product: Dict[str, Any]) -> List[str]:
        """Extract and clean ingredients list."""
        ingredients = []
        
        # Try ingredients_text first
        ingredients_text = product.get('ingredients_text', '') or product.get('ingredients_text_en', '')
        if ingredients_text:
            # Split by common separators
            raw_ingredients = re.split(r'[,;]', ingredients_text)
            for ingredient in raw_ingredients:
                cleaned = self.clean_ingredient(ingredient)
                if cleaned and len(cleaned) > 1:
                    ingredients.append(cleaned)
        
        # Try ingredients_tags as fallback
        if not ingredients:
            ingredients_tags = product.get('ingredients_tags', [])
            if isinstance(ingredients_tags, list):
                for tag in ingredients_tags:
                    if isinstance(tag, str):
                        cleaned = self.clean_ingredient(tag)
                        if cleaned and len(cleaned) > 1:
                            ingredients.append(cleaned)
        
        return ingredients
    
    def extract_allergens(self, product: Dict[str, Any]) -> List[str]:
        """Extract allergens list."""
        allergens = []
        
        # Try allergens_tags first
        allergens_tags = product.get('allergens_tags', [])
        if isinstance(allergens_tags, list):
            for tag in allergens_tags:
                if isinstance(tag, str):
                    cleaned = self.clean_ingredient(tag)
                    if cleaned:
                        allergens.append(cleaned)
        
        # Try allergens_hierarchy as fallback
        if not allergens:
            allergens_hierarchy = product.get('allergens_hierarchy', [])
            if isinstance(allergens_hierarchy, list):
                for allergen in allergens_hierarchy:
                    if isinstance(allergen, str):
                        cleaned = self.clean_ingredient(allergen)
                        if cleaned:
                            allergens.append(cleaned)
        
        return allergens
    
    def extract_nutritional_info(self, product: Dict[str, Any]) -> Dict[str, Any]:
        """Extract nutritional information."""
        nutriments = product.get('nutriments', {})
        
        def safe_float(value):
            if value is None:
                return None
            try:
                if isinstance(value, str):
                    cleaned = re.sub(r'[^\d.,\-]', '', value.strip())
                    if not cleaned:
                        return None
                    cleaned = cleaned.replace(',', '.')
                    return float(cleaned)
                return float(value)
            except (ValueError, TypeError):
                return None
        
        return {
            'calories_per_100g': safe_float(nutriments.get('energy-kcal_100g') or nutriments.get('energy_100g')),
            'protein_percentage': safe_float(nutriments.get('proteins_100g')),
            'fat_percentage': safe_float(nutriments.get('fat_100g')),
            'fiber_percentage': safe_float(nutriments.get('fiber_100g')),
            'moisture_percentage': safe_float(nutriments.get('water_100g')),
            'ash_percentage': safe_float(nutriments.get('ash_100g')),
            'carbohydrates_percentage': safe_float(nutriments.get('carbohydrates_100g')),
            'sugars_percentage': safe_float(nutriments.get('sugars_100g'))
        }
    
    def calculate_quality_score(self, product: Dict[str, Any]) -> float:
        """Calculate data quality score."""
        score = 0.0
        max_score = 10.0
        
        # Basic info (4 points)
        if product.get('product_name') or product.get('product_name_en'):
            score += 1.0
        if product.get('brands'):
            score += 1.0
        if product.get('code') or product.get('_id'):
            score += 1.0
        if product.get('categories'):
            score += 1.0
        
        # Species and life stage (2 points)
        if any('dog' in str(product.get('categories', '')).lower() or 
               'dog' in str(product.get('product_name', '')).lower() for _ in [1]):
            score += 1.0
        if any('adult' in str(product.get('categories', '')).lower() or 
               'adult' in str(product.get('product_name', '')).lower() for _ in [1]):
            score += 1.0
        
        # Nutritional info (2 points)
        nutriments = product.get('nutriments', {})
        if nutriments.get('energy_100g') or nutriments.get('energy-kcal_100g'):
            score += 0.5
        if nutriments.get('proteins_100g'):
            score += 0.5
        if nutriments.get('fat_100g'):
            score += 0.5
        if nutriments.get('fiber_100g'):
            score += 0.5
        
        # Ingredients and allergens (2 points)
        if self.extract_ingredients(product):
            score += 1.0
        if self.extract_allergens(product):
            score += 1.0
        
        return min(score / max_score, 1.0)
    
    def extract_comprehensive_data(self, product: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Extract comprehensive product data with English filtering."""
        try:
            # Filter for English language
            if not self.is_english_product(product):
                return None
            
            name = product.get('product_name') or product.get('product_name_en')
            if not name or len(name.strip()) < self.min_name_length:
                return None
            
            # Calculate quality score
            quality_score = self.calculate_quality_score(product)
            if quality_score < self.min_quality_score:
                return None
            
            # Extract data
            ingredients = self.extract_ingredients(product)
            allergens = self.extract_allergens(product)
            nutritional_info = self.extract_nutritional_info(product)
            
            # Add ingredients and allergens to nutritional_info for consistency
            nutritional_info.update({
                'ingredients': ingredients,
                'allergens': allergens,
                'source': 'openpetfoodfacts',
                'external_id': product.get('_id'),
                'data_quality_score': quality_score
            })
            
            return {
                'name': name.strip()[:200],
                'brand': (product.get('brands') or '')[:100],
                'barcode': (product.get('code') or product.get('_id') or '')[:50],
                'category': (product.get('categories') or '')[:50],
                'species': 'dog' if 'dog' in str(product.get('categories', '')).lower() else 'cat',
                'life_stage': 'adult',  # Default, can be improved
                'product_type': 'dry',  # Default, can be improved
                'quantity': product.get('quantity', ''),
                'country': product.get('countries', ''),
                'language': 'en',
                'image_url': '',  # Can be extracted from images if needed
                'external_id': product.get('_id'),
                'external_source': 'openpetfoodfacts',
                'data_completeness': quality_score,
                'nutritional_info': nutritional_info,
                'ingredients_hierarchy': ingredients,
                'allergens_hierarchy': allergens
            }
            
        except Exception as e:
            logger.warning(f"Error extracting data: {e}")
            return None
    
    def insert_food_item(self, product_data: Dict[str, Any]) -> bool:
        """Insert food item into database."""
        cursor = self.conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO public.food_items (
                    name, brand, barcode, category, species, life_stage, product_type,
                    quantity, country, language, image_url, external_id, external_source,
                    data_completeness, nutritional_info, ingredients_hierarchy, allergens_hierarchy
                ) VALUES (
                    %(name)s, %(brand)s, %(barcode)s, %(category)s, %(species)s, %(life_stage)s, %(product_type)s,
                    %(quantity)s, %(country)s, %(language)s, %(image_url)s, %(external_id)s, %(external_source)s,
                    %(data_completeness)s, %(nutritional_info)s, %(ingredients_hierarchy)s, %(allergens_hierarchy)s
                )
                ON CONFLICT (barcode) DO NOTHING
            """, product_data)
            
            self.conn.commit()
            return True
            
        except psycopg2.IntegrityError as e:
            self.conn.rollback()
            if 'barcode' in str(e):
                return False  # Duplicate barcode
            logger.warning(f"Integrity error for {product_data['name']}: {e}")
            return False
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error inserting {product_data['name']}: {e}")
            return False
        finally:
            cursor.close()
    
    def import_from_jsonl(self, jsonl_file: str, batch_size: int = 100):
        """Import data from JSONL file with English filtering."""
        if not Path(jsonl_file).exists():
            logger.error(f"File not found: {jsonl_file}")
            return
        
        logger.info(f"🚀 Starting English-only import from {jsonl_file}")
        
        imported_count = 0
        skipped_count = 0
        duplicate_count = 0
        batch = []
        
        with open(jsonl_file, 'r', encoding='utf-8') as file:
            for line_num, line in enumerate(file, 1):
                try:
                    product = json.loads(line.strip())
                    
                    # Extract data
                    product_data = self.extract_comprehensive_data(product)
                    if not product_data:
                        skipped_count += 1
                        continue
                    
                    batch.append(product_data)
                    
                    # Process batch
                    if len(batch) >= batch_size:
                        for item in batch:
                            if self.insert_food_item(item):
                                imported_count += 1
                            else:
                                duplicate_count += 1
                        batch = []
                        
                        if line_num % 1000 == 0:
                            logger.info(f"📊 Processed {line_num:,} lines - Imported: {imported_count}, Skipped: {skipped_count}, Duplicates: {duplicate_count}")
                
                except json.JSONDecodeError:
                    skipped_count += 1
                    continue
                except Exception as e:
                    logger.error(f"Error processing line {line_num}: {e}")
                    skipped_count += 1
        
        # Process remaining batch
        for item in batch:
            if self.insert_food_item(item):
                imported_count += 1
            else:
                duplicate_count += 1
        
        logger.info(f"✅ Import completed!")
        logger.info(f"📈 Total processed: {line_num:,}")
        logger.info(f"✅ Imported: {imported_count:,}")
        logger.info(f"⏭️  Skipped (non-English/low quality): {skipped_count:,}")
        logger.info(f"🔄 Duplicates: {duplicate_count:,}")

def main():
    """Main function."""
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        logger.error("❌ DATABASE_URL not found in .env file")
        sys.exit(1)
    
    jsonl_file = "openpetfoodfacts-products.jsonl"
    if not Path(jsonl_file).exists():
        logger.error(f"❌ File not found: {jsonl_file}")
        sys.exit(1)
    
    importer = EnglishOnlyImporter(database_url)
    importer.connect()
    
    try:
        importer.import_from_jsonl(jsonl_file, batch_size=100)
    finally:
        importer.disconnect()

if __name__ == '__main__':
    main()
