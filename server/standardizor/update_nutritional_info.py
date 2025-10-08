#!/usr/bin/env python3
"""
Update Nutritional Info from Cleaned Data
Updates existing database records' nutritional_info field using cleaned_food_items.json as reference.
"""

import json
import sys
import logging
import os
import requests
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NutritionalInfoUpdater:
    """Update nutritional_info field using JSONL data as reference."""
    
    def __init__(self, supabase_url: str, supabase_key: str, jsonl_file: str = None):
        self.supabase_url = supabase_url.rstrip('/')
        self.supabase_key = supabase_key
        self.jsonl_file = jsonl_file or "../importing/openpetfoodfacts-products.jsonl"
        
        self.headers = {
            'apikey': self.supabase_key,
            'Authorization': f'Bearer {self.supabase_key}',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        }
        
        # Load JSONL data for reference
        self.jsonl_data = {}
        self.load_jsonl_data()
    
    def load_jsonl_data(self):
        """Load JSONL data and index by external_id."""
        if not Path(self.jsonl_file).exists():
            logger.error(f"JSONL file not found: {self.jsonl_file}")
            return
        
        logger.info(f"📚 Loading JSONL data from {self.jsonl_file}...")
        
        with open(self.jsonl_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                try:
                    data = json.loads(line.strip())
                    external_id = data.get('_id') or data.get('id')
                    if external_id:
                        self.jsonl_data[external_id] = data
                except json.JSONDecodeError as e:
                    logger.warning(f"Invalid JSON on line {line_num}: {e}")
                    continue
        
        logger.info(f"✅ Loaded {len(self.jsonl_data):,} JSONL products indexed by external_id")
    
    def test_connection(self) -> bool:
        """Test Supabase API connection."""
        url = f"{self.supabase_url}/rest/v1/food_items?select=count"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            logger.info("✅ Supabase API connection successful")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Supabase API connection failed: {e}")
            return False
    
    def get_records_to_update(self, limit: int = None) -> list:
        """Get existing records that have external_id and can be updated."""
        url = f"{self.supabase_url}/rest/v1/food_items?external_id=not.is.null&select=id,name,external_id,nutritional_info"
        
        if limit:
            url += f"&limit={limit}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching records: {e}")
            return []
    
    def extract_nutritional_data_from_jsonl(self, jsonl_item: dict) -> dict:
        """Extract nutritional data from JSONL item and convert to standardized format."""
        # Extract nutriments data
        nutriments = jsonl_item.get('nutriments', {})
        
        # Extract ingredients
        ingredients = []
        if 'ingredients_text' in jsonl_item:
            ingredients_text = jsonl_item['ingredients_text']
            if isinstance(ingredients_text, str):
                ingredients = [ing.strip() for ing in ingredients_text.split(',') if ing.strip()]
        elif 'ingredients' in jsonl_item:
            ingredients = jsonl_item['ingredients']
            if isinstance(ingredients, list):
                ingredients = [str(ing) for ing in ingredients if ing]
        
        # Extract allergens
        allergens = []
        if 'allergens_tags' in jsonl_item:
            allergens = [tag.replace('en:', '') for tag in jsonl_item['allergens_tags'] if tag.startswith('en:')]
        elif 'allergens' in jsonl_item:
            allergens = jsonl_item['allergens']
            if isinstance(allergens, list):
                allergens = [str(allergen) for allergen in allergens if allergen]
        
        # Extract nutritional values
        nutritional_data = {
            # Calories (try multiple fields)
            'calories_per_100g': (
                nutriments.get('energy-kcal_100g') or 
                nutriments.get('energy_100g') or 
                nutriments.get('energy-kcal') or 
                nutriments.get('energy')
            ),
            
            # Protein
            'protein_percentage': (
                nutriments.get('proteins_100g') or 
                nutriments.get('proteins')
            ),
            
            # Fat
            'fat_percentage': (
                nutriments.get('fat_100g') or 
                nutriments.get('fat')
            ),
            
            # Fiber
            'fiber_percentage': (
                nutriments.get('fiber_100g') or 
                nutriments.get('fiber')
            ),
            
            # Moisture
            'moisture_percentage': (
                nutriments.get('moisture_100g') or 
                nutriments.get('moisture')
            ),
            
            # Ash
            'ash_percentage': (
                nutriments.get('ash_100g') or 
                nutriments.get('ash')
            ),
            
            # Carbohydrates
            'carbohydrates_percentage': (
                nutriments.get('carbohydrates_100g') or 
                nutriments.get('carbohydrates')
            ),
            
            # Sugars
            'sugars_percentage': (
                nutriments.get('sugars_100g') or 
                nutriments.get('sugars')
            ),
            
            # Saturated fat
            'saturated_fat_percentage': (
                nutriments.get('saturated-fat_100g') or 
                nutriments.get('saturated-fat')
            ),
            
            # Sodium
            'sodium_percentage': (
                nutriments.get('sodium_100g') or 
                nutriments.get('sodium')
            ),
            
            # Arrays
            'ingredients': ingredients,
            'allergens': allergens,
            'additives': jsonl_item.get('additives_tags', []),
            'vitamins': jsonl_item.get('vitamins_tags', []),
            'minerals': jsonl_item.get('minerals_tags', []),
            
            # Strings
            'source': 'openpetfoodfacts',
            'external_id': jsonl_item.get('_id', ''),
            'data_quality_score': jsonl_item.get('completeness', 0.0),
            'last_updated': jsonl_item.get('last_modified_t', ''),
            
            # Objects
            'nutrient_levels': jsonl_item.get('nutrient_levels', {}),
            'packaging_info': jsonl_item.get('packaging', {}),
            'manufacturing_info': {
                'country': jsonl_item.get('countries', ''),
                'brand': jsonl_item.get('brands', ''),
                'manufacturer': jsonl_item.get('manufacturing_places', '')
            }
        }
        
        return nutritional_data
    
    def standardize_nutritional_info(self, nutritional_info: dict) -> dict:
        """Standardize nutritional_info to ensure all properties are present with appropriate defaults."""
        # Define the complete standardized structure with default values
        standardized = {
            # Nutritional values (numbers or null)
            'calories_per_100g': None,
            'protein_percentage': None,
            'fat_percentage': None,
            'fiber_percentage': None,
            'moisture_percentage': None,
            'ash_percentage': None,
            'carbohydrates_percentage': None,
            'sugars_percentage': None,
            'saturated_fat_percentage': None,
            'sodium_percentage': None,
            
            # Arrays (empty arrays if missing)
            'ingredients': [],
            'allergens': [],
            'additives': [],
            'vitamins': [],
            'minerals': [],
            
            # Strings (empty strings if missing)
            'source': '',
            'external_id': '',
            'data_quality_score': 0.0,
            'last_updated': '',
            
            # Objects (empty objects if missing)
            'nutrient_levels': {},
            'packaging_info': {},
            'manufacturing_info': {}
        }
        
        # Update with actual values from nutritional_info
        if nutritional_info:
            for key, value in nutritional_info.items():
                if key in standardized:
                    # Ensure proper data types
                    if key in ['calories_per_100g', 'protein_percentage', 'fat_percentage', 
                              'fiber_percentage', 'moisture_percentage', 'ash_percentage',
                              'carbohydrates_percentage', 'sugars_percentage', 'saturated_fat_percentage',
                              'sodium_percentage', 'data_quality_score']:
                        # Numeric fields
                        standardized[key] = value if value is not None else None
                    elif key in ['ingredients', 'allergens', 'additives', 'vitamins', 'minerals']:
                        # Array fields
                        standardized[key] = value if isinstance(value, list) else []
                    elif key in ['source', 'external_id', 'last_updated']:
                        # String fields
                        standardized[key] = str(value) if value is not None else ''
                    elif key in ['nutrient_levels', 'packaging_info', 'manufacturing_info']:
                        # Object fields
                        standardized[key] = value if isinstance(value, dict) else {}
        
        return standardized
    
    def update_nutritional_info(self, record_id: str, nutritional_info: dict) -> bool:
        """Update nutritional_info for a specific record with standardized structure."""
        url = f"{self.supabase_url}/rest/v1/food_items"
        params = {'id': f'eq.{record_id}'}
        
        # Standardize the nutritional_info structure
        standardized_nutritional_info = self.standardize_nutritional_info(nutritional_info)
        
        update_data = {'nutritional_info': standardized_nutritional_info}
        
        try:
            response = requests.patch(url, json=update_data, headers=self.headers, params=params)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.warning(f"Error updating record {record_id}: {e}")
            return False
    
    def update_records(self, limit: int = None):
        """Update nutritional_info for records that have matching external_id in cleaned data."""
        logger.info("🔍 Finding records to update...")
        
        # Get existing records
        existing_records = self.get_records_to_update(limit)
        logger.info(f"📊 Found {len(existing_records):,} existing records with external_id")
        
        updated_count = 0
        not_found_count = 0
        error_count = 0
        
        for i, record in enumerate(existing_records):
            external_id = record.get('external_id')
            record_id = record.get('id')
            name = record.get('name', 'Unknown')
            
            try:
                # Check if we have cleaned data for this external_id
                if external_id in self.cleaned_data:
                    cleaned_item = self.cleaned_data[external_id]
                    cleaned_nutritional_info = cleaned_item.get('nutritional_info', {})
                    
                    if cleaned_nutritional_info:
                        # Update the record with cleaned nutritional_info
                        if self.update_nutritional_info(record_id, cleaned_nutritional_info):
                            updated_count += 1
                            logger.info(f"✅ Updated {name} (external_id: {external_id})")
                        else:
                            error_count += 1
                    else:
                        logger.warning(f"⚠️  No nutritional_info in cleaned data for {name}")
                        error_count += 1
                else:
                    not_found_count += 1
                    if not_found_count <= 5:  # Only log first 5 not found
                        logger.info(f"🔍 No cleaned data found for {name} (external_id: {external_id})")
                
                # Progress update
                if (i + 1) % 100 == 0:
                    logger.info(f"📊 Processed {i + 1:,}/{len(existing_records):,} records...")
                
            except Exception as e:
                logger.error(f"Error processing record {record_id}: {e}")
                error_count += 1
        
        logger.info("✅ Update completed!")
        logger.info(f"📈 Total records processed: {len(existing_records):,}")
        logger.info(f"✅ Updated: {updated_count:,}")
        logger.info(f"🔍 Not found in cleaned data: {not_found_count:,}")
        logger.info(f"❌ Errors: {error_count:,}")
    
    def standardize_all_records(self, limit: int = None):
        """Standardize nutritional_info structure for ALL records using JSONL data."""
        logger.info("🔧 Standardizing ALL records with complete nutritional_info structure using JSONL data...")
        
        # Get ALL records (not just those with external_id)
        url = f"{self.supabase_url}/rest/v1/food_items?select=id,name,external_id,nutritional_info"
        if limit:
            url += f"&limit={limit}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            all_records = response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching all records: {e}")
            return
        
        logger.info(f"📊 Found {len(all_records):,} total records to standardize")
        
        updated_count = 0
        error_count = 0
        jsonl_matches = 0
        
        for i, record in enumerate(all_records):
            record_id = record.get('id')
            name = record.get('name', 'Unknown')
            external_id = record.get('external_id')
            current_nutritional_info = record.get('nutritional_info', {})
            
            try:
                # Check if we have JSONL data for this external_id
                if external_id and external_id in self.jsonl_data:
                    # Extract nutritional data from JSONL
                    jsonl_item = self.jsonl_data[external_id]
                    nutritional_data = self.extract_nutritional_data_from_jsonl(jsonl_item)
                    jsonl_matches += 1
                else:
                    # Use existing nutritional_info or empty dict
                    nutritional_data = current_nutritional_info
                
                # Standardize the structure
                if self.update_nutritional_info(record_id, nutritional_data):
                    updated_count += 1
                    if updated_count % 50 == 0:
                        logger.info(f"✅ Standardized {name}")
                else:
                    error_count += 1
                
                # Progress update
                if (i + 1) % 100 == 0:
                    logger.info(f"📊 Processed {i + 1:,}/{len(all_records):,} records...")
                
            except Exception as e:
                logger.error(f"Error processing record {record_id}: {e}")
                error_count += 1
        
        logger.info("✅ Standardization completed!")
        logger.info(f"📈 Total records processed: {len(all_records):,}")
        logger.info(f"✅ Standardized: {updated_count:,}")
        logger.info(f"🔗 JSONL matches: {jsonl_matches:,}")
        logger.info(f"❌ Errors: {error_count:,}")
    
    def analyze_results(self):
        """Analyze the results of the update."""
        try:
            logger.info("\n📊 UPDATE RESULTS ANALYSIS")
            logger.info("=" * 60)
            
            # Total counts
            url = f"{self.supabase_url}/rest/v1/food_items?select=count"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            total = response.json()[0]['count']
            
            # Records with nutritional_info
            url = f"{self.supabase_url}/rest/v1/food_items?nutritional_info=not.is.null&select=count"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            with_nutritional_info = response.json()[0]['count']
            
            # Records with calories
            url = f"{self.supabase_url}/rest/v1/food_items?nutritional_info->calories_per_100g=not.is.null&select=count"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            with_calories = response.json()[0]['count']
            
            # Records with ingredients
            url = f"{self.supabase_url}/rest/v1/food_items?nutritional_info->ingredients=not.is.null&select=count"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            with_ingredients = response.json()[0]['count']
            
            logger.info(f"📊 Total records: {total:,}")
            logger.info(f"🥗 Records with nutritional_info: {with_nutritional_info:,}")
            logger.info(f"🔥 Records with calories: {with_calories:,}")
            logger.info(f"🥘 Records with ingredients: {with_ingredients:,}")
            
            # Sample of updated data
            url = f"{self.supabase_url}/rest/v1/food_items?nutritional_info->calories_per_100g=not.is.null&select=name,brand,nutritional_info&limit=3"
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            logger.info("\n🔍 SAMPLE UPDATED DATA:")
            for row in response.json():
                logger.info(f"  📦 {row['name']} ({row['brand']})")
                
                nutritional_info = row['nutritional_info']
                if 'calories_per_100g' in nutritional_info:
                    logger.info(f"     Calories: {nutritional_info['calories_per_100g']} kcal/100g")
                if 'protein_percentage' in nutritional_info:
                    logger.info(f"     Protein: {nutritional_info['protein_percentage']}%")
                if 'fat_percentage' in nutritional_info:
                    logger.info(f"     Fat: {nutritional_info['fat_percentage']}%")
                if 'ingredients' in nutritional_info:
                    ingredients = nutritional_info['ingredients']
                    if isinstance(ingredients, list) and ingredients:
                        logger.info(f"     Ingredients: {ingredients[:3]}...")
                logger.info("")
        
        except requests.exceptions.RequestException as e:
            logger.error(f"Error analyzing results: {e}")

def main():
    """Main function."""
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    
    if not supabase_url or not supabase_key:
        logger.error("❌ SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not found in .env file")
        sys.exit(1)
    
    jsonl_file = "../importing/openpetfoodfacts-products.jsonl"
    if not Path(jsonl_file).exists():
        logger.error(f"❌ JSONL file not found: {jsonl_file}")
        sys.exit(1)
    
    updater = NutritionalInfoUpdater(supabase_url, supabase_key, jsonl_file)
    
    # Test connection first
    if not updater.test_connection():
        logger.error("❌ Cannot connect to Supabase API. Please check your credentials.")
        sys.exit(1)
    
    try:
        # Standardize ALL records using JSONL data
        updater.standardize_all_records()  # Test with 100 records first
        
        # Analyze results
        updater.analyze_results()
        
    except KeyboardInterrupt:
        logger.info("🛑 Update interrupted by user")
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")

if __name__ == '__main__':
    main()
