#!/usr/bin/env python3
"""
Analyze Why Products Are Skipped
Shows detailed breakdown of why products are skipped during import.

Usage:
    python3 analyze_skipped_products.py
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
from collections import defaultdict

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

def extract_comprehensive_data(product):
    """Extract comprehensive product data."""
    try:
        name = product.get('product_name') or product.get('product_name_en') or product.get('product_name_fr')
        if not name or len(name.strip()) < 2:
            return None, "No valid product name"
            
        brand = product.get('brands') or product.get('brands_old')
        barcode = product.get('code') or product.get('_id')
        
        species, life_stage = extract_species_info(product)
        
        # Extract nutritional data
        nutriments = product.get('nutriments', {})
        calories = safe_float(nutriments.get('energy-kcal_100g') or nutriments.get('energy_100g'))
        protein = safe_float(nutriments.get('proteins_100g'))
        fat = safe_float(nutriments.get('fat_100g'))
        fiber = safe_float(nutriments.get('fiber_100g'))
        moisture = safe_float(nutriments.get('water_100g'))
        ash = safe_float(nutriments.get('ash_100g'))
        
        return {
            'name': name.strip()[:200],
            'brand': brand[:100] if brand else None,
            'barcode': barcode[:50] if barcode else None,
            'species': species,
            'life_stage': life_stage,
            'calories_per_100g': calories,
            'protein_percentage': protein,
            'fat_percentage': fat,
            'fiber_percentage': fiber,
            'moisture_percentage': moisture,
            'ash_percentage': ash,
            'external_id': product.get('_id')
        }, None
        
    except Exception as e:
        return None, f"Error extracting data: {e}"

def analyze_products(jsonl_file, existing_barcodes, existing_external_ids):
    """Analyze why products are skipped."""
    stats = {
        'total_lines': 0,
        'valid_products': 0,
        'duplicate_barcode': 0,
        'duplicate_external_id': 0,
        'no_name': 0,
        'extraction_error': 0,
        'low_quality': 0,
        'constraint_violation': 0,
        'other_errors': 0
    }
    
    skip_reasons = defaultdict(int)
    sample_skipped = []
    
    print("🔍 Analyzing products...")
    
    with open(jsonl_file, 'r', encoding='utf-8') as file:
        for line_num, line in enumerate(file, 1):
            stats['total_lines'] += 1
            
            try:
                product = json.loads(line.strip())
                
                # Check for duplicates
                barcode = product.get('code') or product.get('_id')
                external_id = product.get('_id')
                
                if barcode and barcode in existing_barcodes:
                    stats['duplicate_barcode'] += 1
                    skip_reasons[f"Duplicate barcode: {barcode}"] += 1
                    if len(sample_skipped) < 5:
                        sample_skipped.append(f"Line {line_num}: Duplicate barcode {barcode}")
                    continue
                
                if external_id and external_id in existing_external_ids:
                    stats['duplicate_external_id'] += 1
                    skip_reasons[f"Duplicate external ID: {external_id}"] += 1
                    if len(sample_skipped) < 5:
                        sample_skipped.append(f"Line {line_num}: Duplicate external ID {external_id}")
                    continue
                
                # Extract data
                product_data, error = extract_comprehensive_data(product)
                if not product_data:
                    if "No valid product name" in error:
                        stats['no_name'] += 1
                        skip_reasons["No valid product name"] += 1
                    else:
                        stats['extraction_error'] += 1
                        skip_reasons[f"Extraction error: {error}"] += 1
                    
                    if len(sample_skipped) < 5:
                        sample_skipped.append(f"Line {line_num}: {error}")
                    continue
                
                # Check data quality
                quality_score = 0
                if product_data['name']:
                    quality_score += 0.2
                if product_data['brand']:
                    quality_score += 0.2
                if product_data['barcode']:
                    quality_score += 0.2
                if product_data['calories_per_100g'] is not None:
                    quality_score += 0.1
                if product_data['protein_percentage'] is not None:
                    quality_score += 0.1
                if product_data['fat_percentage'] is not None:
                    quality_score += 0.1
                if product_data['species'] != 'unknown':
                    quality_score += 0.1
                
                if quality_score < 0.3:
                    stats['low_quality'] += 1
                    skip_reasons[f"Low quality (score: {quality_score:.2f})"] += 1
                    if len(sample_skipped) < 5:
                        sample_skipped.append(f"Line {line_num}: Low quality (score: {quality_score:.2f})")
                    continue
                
                stats['valid_products'] += 1
                
                # Progress update
                if line_num % 2000 == 0:
                    print(f"📊 Processed {line_num:,} lines...")
                
            except json.JSONDecodeError as e:
                stats['other_errors'] += 1
                skip_reasons[f"Invalid JSON: {str(e)[:50]}"] += 1
                if len(sample_skipped) < 5:
                    sample_skipped.append(f"Line {line_num}: Invalid JSON")
            except Exception as e:
                stats['other_errors'] += 1
                skip_reasons[f"Other error: {str(e)[:50]}"] += 1
                if len(sample_skipped) < 5:
                    sample_skipped.append(f"Line {line_num}: {str(e)[:50]}")
    
    return stats, skip_reasons, sample_skipped

def main():
    """Main function."""
    print("🔍 Analyzing Why Products Are Skipped")
    print("=" * 60)
    
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
    
    # File path
    jsonl_file = "openpetfoodfacts-products.jsonl"
    if not Path(jsonl_file).exists():
        print(f"❌ File not found: {jsonl_file}")
        sys.exit(1)
    
    print(f"\n📁 Analyzing file: {jsonl_file}")
    
    # Analyze products
    stats, skip_reasons, sample_skipped = analyze_products(jsonl_file, existing_barcodes, existing_external_ids)
    
    # Print results
    print("\n📊 ANALYSIS RESULTS")
    print("=" * 60)
    print(f"📈 Total lines in file: {stats['total_lines']:,}")
    print(f"✅ Valid products: {stats['valid_products']:,}")
    print(f"🔄 Duplicate barcodes: {stats['duplicate_barcode']:,}")
    print(f"🔄 Duplicate external IDs: {stats['duplicate_external_id']:,}")
    print(f"❌ No valid name: {stats['no_name']:,}")
    print(f"❌ Extraction errors: {stats['extraction_error']:,}")
    print(f"⚠️  Low quality data: {stats['low_quality']:,}")
    print(f"❌ Other errors: {stats['other_errors']:,}")
    
    total_skipped = (stats['duplicate_barcode'] + stats['duplicate_external_id'] + 
                     stats['no_name'] + stats['extraction_error'] + 
                     stats['low_quality'] + stats['other_errors'])
    
    print(f"\n📊 SUMMARY")
    print(f"✅ Would import: {stats['valid_products']:,} products")
    print(f"⏭️  Would skip: {total_skipped:,} products")
    print(f"📈 Success rate: {stats['valid_products']/stats['total_lines']*100:.1f}%")
    
    print(f"\n🔍 TOP SKIP REASONS")
    for reason, count in sorted(skip_reasons.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {reason}: {count:,}")
    
    if sample_skipped:
        print(f"\n📝 SAMPLE SKIPPED PRODUCTS")
        for sample in sample_skipped:
            print(f"  {sample}")
    
    conn.close()
    
    print(f"\n🎯 CONCLUSION")
    print(f"Out of {stats['total_lines']:,} total products:")
    print(f"  • {stats['valid_products']:,} would be imported successfully")
    print(f"  • {total_skipped:,} would be skipped for various reasons")
    print(f"  • This explains why you have {stats['valid_products']:,} records instead of {stats['total_lines']:,}")

if __name__ == '__main__':
    main()
