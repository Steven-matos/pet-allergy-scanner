#!/usr/bin/env python3
"""
Import OpenPetFoodFacts Data Without Duplicates
Checks existing data and only imports new records.

Usage:
    python3 import_no_duplicates.py [--dry-run] [--resume-from N]
"""

import json
import sys
import logging
import time
import re
import os
from pathlib import Path
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_existing_barcodes(conn):
    """Get all existing barcodes from the database."""
    cursor = conn.cursor()
    cursor.execute("SELECT barcode FROM public.food_items WHERE barcode IS NOT NULL")
    existing_barcodes = set(row[0] for row in cursor.fetchall())
    cursor.close()
    return existing_barcodes

def get_existing_external_ids(conn):
    """Get all existing external IDs from the database."""
    cursor = conn.cursor()
    cursor.execute("SELECT external_id FROM public.food_items WHERE external_id IS NOT NULL")
    existing_ids = set(row[0] for row in cursor.fetchall())
    cursor.close()
    return existing_ids

def safe_float(value):
    """Safely convert a value to float."""
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

def extract_species_info(product):
    """Extract species and life stage information."""
    species = 'unknown'
    life_stage = 'unknown'
    
    categories = product.get('categories_tags', [])
    categories_hierarchy = product.get('categories_hierarchy', [])
    
    for category in categories + categories_hierarchy:
        if isinstance(category, str):
            category_lower = category.lower()
            if 'dog' in category_lower or 'chien' in category_lower:
                species = 'dog'
            elif 'cat' in category_lower or 'chat' in category_lower:
                species = 'cat'
            
            if any(stage in category_lower for stage in ['puppy', 'puppies', 'chiot']):
                life_stage = 'puppy'
            elif any(stage in category_lower for stage in ['kitten', 'kittens', 'chaton']):
                life_stage = 'kitten'
            elif any(stage in category_lower for stage in ['adult', 'adulte']):
                life_stage = 'adult'
            elif any(stage in category_lower for stage in ['senior', 'sénior', 'senior']):
                life_stage = 'senior'
    
    # Check product name and keywords
    product_name = (product.get('product_name', '') + ' ' + 
                   product.get('product_name_en', '') + ' ' + 
                   product.get('product_name_fr', '')).lower()
    
    keywords = product.get('_keywords', [])
    if isinstance(keywords, list):
        keyword_text = ' '.join(keywords).lower()
    else:
        keyword_text = str(keywords).lower()
    
    combined_text = f"{product_name} {keyword_text}"
    
    if 'dog' in combined_text or 'chien' in combined_text or 'canine' in combined_text:
        species = 'dog'
    elif 'cat' in combined_text or 'chat' in combined_text or 'feline' in combined_text:
        species = 'cat'
    
    if any(stage in combined_text for stage in ['puppy', 'puppies', 'chiot']):
        life_stage = 'puppy'
    elif any(stage in combined_text for stage in ['kitten', 'kittens', 'chaton']):
        life_stage = 'kitten'
    elif any(stage in combined_text for stage in ['adult', 'adulte']):
        life_stage = 'adult'
    elif any(stage in combined_text for stage in ['senior', 'sénior', 'senior']):
        life_stage = 'senior'
    
    return species, life_stage

def extract_product_type(product):
    """Extract product type."""
    categories = product.get('categories_tags', [])
    categories_hierarchy = product.get('categories_hierarchy', [])
    
    for category in categories + categories_hierarchy:
        if isinstance(category, str):
            category_lower = category.lower()
            if any(dry in category_lower for dry in ['dry', 'croquette', 'kibble']):
                return 'dry'
            elif any(wet in category_lower for wet in ['wet', 'pate', 'mousse', 'sauce']):
                return 'wet'
            elif any(treat in category_lower for treat in ['treat', 'reward', 'snack', 'friandise']):
                return 'treat'
            elif any(supp in category_lower for supp in ['supplement', 'vitamin', 'supplément']):
                return 'supplement'
    
    return 'unknown'

def extract_ingredients(product):
    """Extract ingredients list."""
    ingredients = []
    
    ingredient_fields = [
        'ingredients_text',
        'ingredients_text_en',
        'ingredients_text_fr',
        'ingredients'
    ]
    
    for field in ingredient_fields:
        ingredient_text = product.get(field)
        if ingredient_text and isinstance(ingredient_text, str):
            ingredient_list = re.split(r'[,;]', ingredient_text)
            for ingredient in ingredient_list:
                cleaned = ingredient.strip()
                if cleaned and len(cleaned) > 1:
                    ingredients.append(cleaned)
            break
    
    # Remove duplicates
    seen = set()
    unique_ingredients = []
    for ingredient in ingredients:
        if ingredient.lower() not in seen:
            seen.add(ingredient.lower())
            unique_ingredients.append(ingredient)
            
    return unique_ingredients[:20]

def extract_allergens(product):
    """Extract allergens list."""
    allergens = []
    
    allergens_text = product.get('allergens', '')
    if allergens_text and isinstance(allergens_text, str):
        allergen_list = re.split(r'[,;]', allergens_text)
        for allergen in allergen_list:
            cleaned = allergen.strip()
            if cleaned:
                allergens.append(cleaned)
    
    allergens_tags = product.get('allergens_tags', [])
    if isinstance(allergens_tags, list):
        for tag in allergens_tags:
            if isinstance(tag, str) and tag.startswith('en:'):
                allergen_name = tag[3:].replace('-', ' ').title()
                if allergen_name not in allergens:
                    allergens.append(allergen_name)
    
    return allergens[:10]

def calculate_data_completeness(product):
    """Calculate data completeness score."""
    score = 0.0
    
    if product.get('product_name'):
        score += 0.1
    if product.get('brands'):
        score += 0.1
    if product.get('code'):
        score += 0.1
        
    nutriments = product.get('nutriments', {})
    if nutriments:
        nutritional_fields = [
            'energy-kcal_100g', 'proteins_100g', 'fat_100g',
            'fiber_100g', 'water_100g', 'ash_100g'
        ]
        available_fields = sum(1 for field in nutritional_fields if nutriments.get(field))
        score += (available_fields / len(nutritional_fields)) * 0.4
        
    if product.get('ingredients_text') or product.get('ingredients'):
        score += 0.2
        
    images = product.get('images', {})
    if images:
        image_count = len([k for k in images.keys() if k not in ['1', '2', '3', '4', '5']])
        score += min(image_count / 3, 1.0) * 0.1
        
    return min(score, 1.0)

def extract_comprehensive_data(product):
    """Extract comprehensive product data."""
    try:
        name = product.get('product_name') or product.get('product_name_en') or product.get('product_name_fr')
        if not name or len(name.strip()) < 2:
            return None
            
        brand = product.get('brands') or product.get('brands_old')
        barcode = product.get('code') or product.get('_id')
        
        species, life_stage = extract_species_info(product)
        product_type = extract_product_type(product)
        
        # Extract nutritional data
        nutriments = product.get('nutriments', {})
        calories = safe_float(nutriments.get('energy-kcal_100g') or nutriments.get('energy_100g'))
        protein = safe_float(nutriments.get('proteins_100g'))
        fat = safe_float(nutriments.get('fat_100g'))
        fiber = safe_float(nutriments.get('fiber_100g'))
        moisture = safe_float(nutriments.get('water_100g'))
        ash = safe_float(nutriments.get('ash_100g'))
        
        ingredients = extract_ingredients(product)
        allergens = extract_allergens(product)
        
        country = product.get('countries', '')
        language = product.get('lang', 'en')
        keywords = product.get('_keywords', [])
        categories_hierarchy = product.get('categories_hierarchy', [])
        brands_hierarchy = product.get('brands_hierarchy', [])
        allergens_hierarchy = product.get('allergens_hierarchy', [])
        
        completeness = calculate_data_completeness(product)
        
        # Validate and clean data
        category = extract_category(product)
        if category and len(category) > 50:
            category = category[:50]
        
        return {
            'name': name.strip()[:200],
            'brand': brand[:100] if brand else None,
            'barcode': barcode[:50] if barcode else None,
            'category': category,
            'description': None,
            'species': species,
            'life_stage': life_stage,
            'product_type': product_type,
            'country': country[:100] if country else None,
            'language': language[:10] if language else 'en',
            'calories_per_100g': calories,
            'protein_percentage': protein,
            'fat_percentage': fat,
            'fiber_percentage': fiber,
            'moisture_percentage': moisture,
            'ash_percentage': ash,
            'ingredients': ingredients,
            'allergens': allergens,
            'keywords': keywords,
            'categories_hierarchy': categories_hierarchy,
            'brands_hierarchy': brands_hierarchy,
            'allergens_hierarchy': allergens_hierarchy,
            'data_completeness': completeness,
            'external_source': 'openpetfoodfacts',
            'external_id': product.get('_id')
        }
        
    except Exception as e:
        logger.warning(f"Error extracting product data: {e}")
        return None

def extract_category(product):
    """Extract category from product data with validation."""
    categories = product.get('categories', '')
    if categories:
        category_parts = categories.split(',')
        if category_parts:
            category = category_parts[0].strip()
            # Clean and validate category
            if category and len(category) <= 50:
                return category
    
    categories_tags = product.get('categories_tags', [])
    if categories_tags and isinstance(categories_tags, list):
        for tag in categories_tags:
            if isinstance(tag, str) and tag.startswith('en:'):
                category = tag[3:].replace('-', ' ').title()
                # Clean and validate category
                if category and len(category) <= 50:
                    return category
    
    # Try to extract from product name or other fields
    product_name = product.get('product_name', '') or product.get('product_name_en', '') or product.get('product_name_fr', '')
    if product_name:
        # Simple category extraction from product name
        name_lower = product_name.lower()
        if any(word in name_lower for word in ['dog', 'chien', 'canine']):
            return 'Dog Food'
        elif any(word in name_lower for word in ['cat', 'chat', 'feline']):
            return 'Cat Food'
        elif any(word in name_lower for word in ['treat', 'reward', 'snack']):
            return 'Pet Treats'
        elif any(word in name_lower for word in ['supplement', 'vitamin']):
            return 'Pet Supplements'
    
    return None

def insert_food_item(conn, product_data, dry_run=False):
    """Insert a single food item into the database."""
    try:
        if dry_run:
            return True
        
        # Prepare nutritional info JSONB
        nutritional_info = {}
        if product_data['calories_per_100g'] is not None:
            nutritional_info['calories_per_100g'] = product_data['calories_per_100g']
        if product_data['protein_percentage'] is not None:
            nutritional_info['protein_percentage'] = product_data['protein_percentage']
        if product_data['fat_percentage'] is not None:
            nutritional_info['fat_percentage'] = product_data['fat_percentage']
        if product_data['fiber_percentage'] is not None:
            nutritional_info['fiber_percentage'] = product_data['fiber_percentage']
        if product_data['moisture_percentage'] is not None:
            nutritional_info['moisture_percentage'] = product_data['moisture_percentage']
        if product_data['ash_percentage'] is not None:
            nutritional_info['ash_percentage'] = product_data['ash_percentage']
        if product_data['ingredients']:
            nutritional_info['ingredients'] = product_data['ingredients']
        if product_data['allergens']:
            nutritional_info['allergens'] = product_data['allergens']
        
        nutritional_info['source'] = 'openpetfoodfacts'
        nutritional_info['external_id'] = product_data['external_id']
        nutritional_info['data_quality_score'] = product_data['data_completeness']
        
        cursor = conn.cursor()
        
        insert_sql = """
        INSERT INTO public.food_items (
            name, brand, barcode, category, description, nutritional_info,
            species, life_stage, product_type, country, language,
            data_completeness, external_source, external_id,
            keywords, categories_hierarchy, brands_hierarchy, allergens_hierarchy
        ) VALUES (
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s, %s, %s
        )
        """
        
        cursor.execute(insert_sql, (
            product_data['name'],
            product_data['brand'],
            product_data['barcode'],
            product_data['category'],
            product_data['description'],
            json.dumps(nutritional_info),
            product_data['species'],
            product_data['life_stage'],
            product_data['product_type'],
            product_data['country'],
            product_data['language'],
            product_data['data_completeness'],
            product_data['external_source'],
            product_data['external_id'],
            product_data['keywords'],
            product_data['categories_hierarchy'],
            product_data['brands_hierarchy'],
            product_data['allergens_hierarchy']
        ))
        
        conn.commit()
        cursor.close()
        
        return True
        
    except psycopg2.IntegrityError as e:
        conn.rollback()  # Rollback the failed transaction
        if 'barcode' in str(e):
            return False  # Duplicate barcode
        elif 'check constraint' in str(e):
            logger.warning(f"Constraint violation for {product_data['name']}: {e}")
            return False
        else:
            logger.warning(f"Integrity error for {product_data['name']}: {e}")
            return False
            
    except psycopg2.InternalError as e:
        conn.rollback()  # Rollback the failed transaction
        logger.warning(f"Internal error for {product_data['name']}: {e}")
        return False
        
    except Exception as e:
        conn.rollback()  # Rollback the failed transaction
        logger.error(f"Error inserting {product_data['name']}: {e}")
        return False

def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Import OpenPetFoodFacts data without duplicates')
    parser.add_argument('--dry-run', '-d', action='store_true', help='Run without inserting data')
    parser.add_argument('--resume-from', '-r', type=int, default=0, help='Resume from line number')
    args = parser.parse_args()
    
    print("🚀 OpenPetFoodFacts Data Import (No Duplicates)")
    print("=" * 60)
    print("This script will check existing data and only import new records")
    print()
    
    # Get database URL from environment
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        print("❌ DATABASE_URL not found in .env file")
        sys.exit(1)
    
    print(f"🔗 Database: {database_url.split('@')[1].split('/')[0]}")
    
    # Test connection
    print("🔗 Testing database connection...")
    try:
        conn = psycopg2.connect(database_url)
        print("✅ Connection successful!")
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)
    
    # Get existing data
    print("🔍 Checking existing data...")
    existing_barcodes = get_existing_barcodes(conn)
    existing_external_ids = get_existing_external_ids(conn)
    
    print(f"📊 Found {len(existing_barcodes)} existing barcodes")
    print(f"📊 Found {len(existing_external_ids)} existing external IDs")
    
    if args.dry_run:
        print("🧪 DRY RUN MODE: No data will be inserted")
    else:
        print("💾 LIVE MODE: Data will be inserted into database")
    
    # Confirm
    if not args.dry_run:
        confirm = input("\n⚠️  This will insert data into your database. Continue? (y/N): ").strip().lower()
        if confirm != 'y':
            print("❌ Import cancelled")
            sys.exit(0)
    
    # File path
    jsonl_file = "openpetfoodfacts-products.jsonl"
    if not Path(jsonl_file).exists():
        print(f"❌ File not found: {jsonl_file}")
        sys.exit(1)
    
    print(f"\n📁 Processing file: {jsonl_file}")
    
    # Count total lines
    total_lines = 0
    with open(jsonl_file, 'r', encoding='utf-8') as file:
        for line in file:
            if line.strip():
                total_lines += 1
    
    print(f"📊 Total products in file: {total_lines:,}")
    if args.resume_from > 0:
        print(f"🔄 Resuming from line: {args.resume_from:,}")
    
    # Process file
    processed_count = 0
    skipped_count = 0
    error_count = 0
    duplicate_count = 0
    new_count = 0
    
    start_time = time.time()
    
    try:
        with open(jsonl_file, 'r', encoding='utf-8') as file:
            for line_num, line in enumerate(file, 1):
                # Skip lines before resume point
                if line_num < args.resume_from:
                    continue
                
                try:
                    product = json.loads(line.strip())
                    
                    # Check for duplicates
                    barcode = product.get('code') or product.get('_id')
                    external_id = product.get('_id')
                    
                    if barcode and barcode in existing_barcodes:
                        duplicate_count += 1
                        continue
                    
                    if external_id and external_id in existing_external_ids:
                        duplicate_count += 1
                        continue
                    
                    # Extract data
                    product_data = extract_comprehensive_data(product)
                    if not product_data:
                        skipped_count += 1
                        continue
                    
                    # Insert into database
                    if insert_food_item(conn, product_data, args.dry_run):
                        processed_count += 1
                        new_count += 1
                    else:
                        skipped_count += 1
                    
                    # Progress update
                    if line_num % 1000 == 0:
                        elapsed = time.time() - start_time
                        rate = line_num / elapsed
                        eta = (total_lines - line_num) / rate / 60
                        print(f"📊 Progress: {line_num:,}/{total_lines:,} ({line_num/total_lines*100:.1f}%) | Rate: {rate:.1f} lines/sec | ETA: {eta:.1f} min")
                        print(f"   ✅ New: {new_count:,} | 🔄 Duplicates: {duplicate_count:,} | ⏭️  Skipped: {skipped_count:,}")
                    
                except json.JSONDecodeError as e:
                    logger.warning(f"Invalid JSON at line {line_num}: {e}")
                    error_count += 1
                except psycopg2.OperationalError as e:
                    logger.error(f"Database connection error at line {line_num}: {e}")
                    # Try to reconnect
                    try:
                        conn.close()
                        conn = psycopg2.connect(database_url)
                        logger.info("Database connection restored")
                    except Exception as reconnect_error:
                        logger.error(f"Failed to reconnect to database: {reconnect_error}")
                        break
                    error_count += 1
                except Exception as e:
                    logger.error(f"Error processing line {line_num}: {e}")
                    error_count += 1
                    
    except Exception as e:
        logger.error(f"Error processing file: {e}")
        sys.exit(1)
    finally:
        conn.close()
    
    total_time = time.time() - start_time
    
    print("\n🎉 Import Completed!")
    print("=" * 60)
    print(f"⏱️  Processing time: {total_time/60:.1f} minutes")
    print(f"📊 New products imported: {new_count:,}")
    print(f"📊 Duplicates skipped: {duplicate_count:,}")
    print(f"📊 Products skipped: {skipped_count:,}")
    print(f"📊 Errors: {error_count:,}")
    print(f"📊 Total lines processed: {line_num:,}")
    
    if args.dry_run:
        print("\n🧪 This was a dry run - no data was actually inserted")
        print("💡 Run without --dry-run to perform the actual import")
    else:
        print("\n✅ Only new products have been imported!")
        print("🎯 No duplicates were created!")

if __name__ == '__main__':
    main()
