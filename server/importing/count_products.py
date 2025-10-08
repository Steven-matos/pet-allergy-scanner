#!/usr/bin/env python3
"""
Count Products in JSONL File
Quick script to count the total number of products in the OpenPetFoodFacts JSONL file.

Usage:
    python3 count_products.py [file_path]
"""

import sys
from pathlib import Path

def count_products(file_path):
    """
    Count the number of products in a JSONL file.
    
    Args:
        file_path: Path to the JSONL file
        
    Returns:
        Number of products
    """
    count = 0
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            for line_num, line in enumerate(file, 1):
                if line.strip():  # Skip empty lines
                    count += 1
                if line_num % 10000 == 0:
                    print(f"Processed {line_num:,} lines...")
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        return 0
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return 0
    
    return count

def main():
    """Main function to count products."""
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    else:
        file_path = "openpetfoodfacts-products.jsonl"
    
    if not Path(file_path).exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    print(f"🔍 Counting products in: {file_path}")
    print("⏳ This may take a moment for large files...")
    
    count = count_products(file_path)
    
    if count > 0:
        print(f"\n📊 Total products found: {count:,}")
        
        # Estimate processing time
        estimated_minutes = count / 1000  # Rough estimate: 1000 products per minute
        print(f"⏱️  Estimated processing time: {estimated_minutes:.1f} minutes")
        
        # Estimate database size
        estimated_mb = count * 0.5  # Rough estimate: 0.5MB per product
        print(f"💾 Estimated database size increase: {estimated_mb:.1f} MB")
    else:
        print("❌ No products found or error occurred")

if __name__ == '__main__':
    main()
