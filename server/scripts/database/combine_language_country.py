#!/usr/bin/env python3
"""
Language-Country Combination Script
Combines language and country columns in the food_items table

This script will:
1. Find all food items that have both language and country values
2. Skip records where country is already in 'language:country' format (e.g., 'es:Spain', 'en:United States')
3. Combine remaining records as 'language:country' (e.g., 'es:Spain', 'en:Spain')
4. Update the country column with the combined value
5. Provide statistics on what was updated

Usage:
    python scripts/database/combine_language_country.py [--dry-run] [--confirm]
"""

import asyncio
import sys
import os
from typing import List, Dict, Any, Optional
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add the parent directory to the path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import settings
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class LanguageCountryCombiner:
    """
    Handles combining language and country columns in food_items table
    """
    
    def __init__(self, dry_run: bool = True):
        """
        Initialize the combiner
        
        Args:
            dry_run: If True, only analyze data without making changes
        """
        self.dry_run = dry_run
        self.supabase = None
        self.stats = {
            'total_records': 0,
            'records_with_both_values': 0,
            'records_missing_language': 0,
            'records_missing_country': 0,
            'records_already_formatted': 0,
            'records_to_update': 0,
            'records_updated': 0,
            'update_examples': [],
            'errors': []
        }
    
    async def initialize(self) -> bool:
        """
        Initialize database connection
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            logger.info("Initializing database connection...")
            # Use service role key for admin operations
            from supabase import create_client
            self.supabase = create_client(
                settings.supabase_url, 
                settings.supabase_service_role_key
            )
            logger.info("✅ Database connection established")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to initialize database: {e}")
            return False
    
    def _combine_language_country(self, language: str, country: str) -> Optional[str]:
        """
        Combine language and country into format 'language:country'
        
        Args:
            language: Language code (e.g., 'es', 'en')
            country: Country name (e.g., 'Spain', 'United States')
            
        Returns:
            Combined string in format 'language:country' or None if invalid
        """
        if not language or not country:
            return None
        
        language = language.strip().lower()
        country = country.strip()
        
        if not language or not country:
            return None
        
        # Remove existing language prefix from country if present
        # Handle cases like 'en:Spain' or 'es:Spain' -> 'Spain'
        if ':' in country:
            parts = country.split(':', 1)
            country = parts[-1].strip()  # Take the part after the last colon
        
        # Combine as 'language:country'
        return f"{language}:{country}"
    
    def _is_already_formatted(self, language: str, country: str) -> bool:
        """
        Check if country already has the format 'language:country' (with any language prefix)
        
        Args:
            language: Language code (e.g., 'es', 'en')
            country: Country name (e.g., 'es:Spain', 'en:Spain', 'fr:France')
            
        Returns:
            bool: True if country already has 'language:country' format, False otherwise
        """
        if not country:
            return False
        
        country = country.strip()
        
        # Check if country already has the format 'X:Y' where X is a language prefix
        # If it contains a colon and has text before the colon, consider it formatted
        if ':' in country:
            parts = country.split(':', 1)
            prefix = parts[0].strip()
            suffix = parts[1].strip() if len(parts) > 1 else ''
            
            # If there's a prefix and suffix, it's already in language:country format
            if prefix and suffix:
                return True
        
        return False
    
    async def analyze_data(self) -> Dict[str, Any]:
        """
        Analyze the current state of language and country columns in food_items table
        
        Returns:
            Dict containing analysis results
        """
        logger.info("🔍 Analyzing language and country columns in food_items table...")
        
        try:
            # Get total count of food items
            total_response = self.supabase.table("food_items").select(
                "id", 
                count="exact"
            ).execute()
            
            self.stats['total_records'] = total_response.count or 0
            
            logger.info(f"📊 Total food items: {self.stats['total_records']}")
            
            if self.stats['total_records'] == 0:
                logger.warning("⚠️  No food items found in database")
                return self.stats
            
            # Get all food items with both language and country values (handle pagination)
            logger.info("📋 Fetching food items...")
            all_food_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select(
                    "id, name, brand, language, country"
                ).range(offset, offset + page_size - 1).execute()
                
                if not response.data:
                    break
                    
                all_food_items.extend(response.data)
                offset += page_size
                
                logger.info(f"📦 Retrieved {len(all_food_items)} food items so far...")
                
                # Break if we got fewer items than page size (last page)
                if len(response.data) < page_size:
                    break
            
            food_items = all_food_items
            logger.info(f"📦 Retrieved {len(food_items)} food items total")
            
            # Analyze each item
            items_to_update = []
            items_with_both = []
            items_missing_language = []
            items_missing_country = []
            items_already_formatted = []
            
            for item in food_items:
                language = item.get('language', '').strip() if item.get('language') else ''
                country = item.get('country', '').strip() if item.get('country') else ''
                
                # Check if language is missing
                if not language:
                    items_missing_language.append(item)
                    continue
                
                # Check if country is missing
                if not country:
                    items_missing_country.append(item)
                    continue
                
                # Both values exist
                items_with_both.append(item)
                
                # Check if already formatted correctly
                if self._is_already_formatted(language, country):
                    items_already_formatted.append(item)
                    continue
                
                # Need to update
                combined = self._combine_language_country(language, country)
                if combined:
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': combined,
                        'language': language,
                        'name': item.get('name', 'Unknown'),
                        'brand': item.get('brand', 'Unknown')
                    })
            
            self.stats['records_with_both_values'] = len(items_with_both)
            self.stats['records_missing_language'] = len(items_missing_language)
            self.stats['records_missing_country'] = len(items_missing_country)
            self.stats['records_already_formatted'] = len(items_already_formatted)
            self.stats['records_to_update'] = len(items_to_update)
            
            # Store items to update for later use
            self.items_to_update = items_to_update
            
            # Store first 10 examples for reporting
            self.stats['update_examples'] = items_to_update[:10]
            
            # Log analysis results
            logger.info(f"📊 Analysis Results:")
            logger.info(f"  Records with both language and country: {self.stats['records_with_both_values']}")
            logger.info(f"  Records missing language: {self.stats['records_missing_language']}")
            logger.info(f"  Records missing country: {self.stats['records_missing_country']}")
            logger.info(f"  Records already in 'language:country' format (will be skipped): {self.stats['records_already_formatted']}")
            logger.info(f"  Records to update: {self.stats['records_to_update']}")
            
            # Show some examples of items that will be updated
            if items_to_update:
                logger.info("")
                logger.info("📝 Sample items to be updated:")
                for i, item_update in enumerate(items_to_update[:10]):  # Show first 10
                    logger.info(
                        f"  {i+1}. {item_update['name']} "
                        f"(Brand: {item_update['brand']}) "
                        f"[Language: '{item_update['language']}'] "
                        f"[{item_update['old_country']} → {item_update['new_country']}]"
                    )
                if len(items_to_update) > 10:
                    logger.info(f"  ... and {len(items_to_update) - 10} more")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error analyzing data: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def combine_records(self) -> Dict[str, Any]:
        """
        Update food items with combined language:country format
        
        Returns:
            Dict containing cleanup results
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No records will be updated")
            logger.info(f"   Would update {self.stats['records_to_update']} records")
            return self.stats
        
        if not hasattr(self, 'items_to_update') or not self.items_to_update:
            logger.info("✅ No records need to be updated")
            return self.stats
        
        logger.info(f"🔄 Starting language-country combination...")
        logger.info(f"   Will update {len(self.items_to_update)} records")
        
        try:
            updated_count = 0
            failed_count = 0
            
            # Update records one by one to ensure accuracy
            for i, item_update in enumerate(self.items_to_update):
                try:
                    # Update the record
                    update_response = self.supabase.table("food_items").update({
                        'country': item_update['new_country']
                    }).eq('id', item_update['id']).execute()
                    
                    if update_response.data:
                        updated_count += 1
                    
                    # Log progress every 100 records
                    if (i + 1) % 100 == 0:
                        logger.info(
                            f"📊 Progress: {i + 1}/{len(self.items_to_update)} "
                            f"updated, {failed_count} failed"
                        )
                        
                except Exception as e:
                    failed_count += 1
                    error_msg = (
                        f"Error updating record {item_update['id']} "
                        f"({item_update.get('name', 'Unknown')}): {e}"
                    )
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
            
            self.stats['records_updated'] = updated_count
            logger.info(f"✅ Combination completed:")
            logger.info(f"   Successfully updated: {updated_count} records")
            if failed_count > 0:
                logger.warning(f"   Failed to update: {failed_count} records")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error during combination: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def generate_report(self) -> str:
        """
        Generate a combination report
        
        Returns:
            str: Formatted report
        """
        report = []
        report.append("=" * 60)
        report.append("LANGUAGE-COUNTRY COMBINATION REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE UPDATE'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total records: {self.stats['total_records']}")
        report.append(f"  Records with both language and country: {self.stats['records_with_both_values']}")
        report.append(f"  Records missing language: {self.stats['records_missing_language']}")
        report.append(f"  Records missing country: {self.stats['records_missing_country']}")
        report.append(f"  Records already in 'language:country' format (skipped): {self.stats['records_already_formatted']}")
        report.append(f"  Records to update: {self.stats['records_to_update']}")
        report.append(f"  Records updated: {self.stats['records_updated']}")
        report.append("")
        
        if self.stats['update_examples']:
            report.append("📝 SAMPLE UPDATES:")
            for i, example in enumerate(self.stats['update_examples'][:10], 1):
                report.append(
                    f"  {i}. {example['name']} "
                    f"(Language: {example['language']}) "
                    f"[{example['old_country']} → {example['new_country']}]"
                )
            if self.stats['records_to_update'] > 10:
                report.append(f"  ... and {self.stats['records_to_update'] - 10} more")
            report.append("")
        
        if self.stats['errors']:
            report.append("❌ ERRORS:")
            for error in self.stats['errors'][:20]:  # Show first 20 errors
                report.append(f"  - {error}")
            if len(self.stats['errors']) > 20:
                report.append(f"  ... and {len(self.stats['errors']) - 20} more errors")
            report.append("")
        
        # Calculate percentages
        if self.stats['total_records'] > 0:
            both_percentage = (self.stats['records_with_both_values'] / self.stats['total_records']) * 100
            update_percentage = (
                (self.stats['records_updated'] / self.stats['total_records']) * 100
            ) if not self.dry_run else (
                (self.stats['records_to_update'] / self.stats['total_records']) * 100
            )
            
            report.append("📈 PERCENTAGES:")
            report.append(f"  Records with both values: {both_percentage:.1f}%")
            if not self.dry_run:
                report.append(f"  Records updated: {update_percentage:.1f}%")
            else:
                report.append(f"  Records that would be updated: {update_percentage:.1f}%")
            report.append("")
        
        report.append("=" * 60)
        
        return "\n".join(report)
    
    async def combine(self) -> bool:
        """
        Perform the complete combination process
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Initialize database connection
            if not await self.initialize():
                return False
            
            # Analyze current data
            await self.analyze_data()
            
            # Perform combination
            await self.combine_records()
            
            # Generate and display report
            report = await self.generate_report()
            print("\n" + report)
            
            # Log final status
            if self.stats['errors']:
                logger.warning(f"⚠️  Combination completed with {len(self.stats['errors'])} errors")
                return False
            else:
                logger.info("✅ Combination completed successfully")
                return True
                
        except Exception as e:
            logger.error(f"❌ Combination failed: {e}")
            return False


async def main():
    """
    Main function to run the language-country combination
    """
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Combine language and country columns in food_items table as 'language:country'"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Analyze data without making changes"
    )
    parser.add_argument(
        "--confirm", 
        action="store_true", 
        help="Confirm that you want to update records"
    )
    
    args = parser.parse_args()
    
    # Determine if this is a dry run
    dry_run = args.dry_run or not args.confirm
    
    if not dry_run:
        print("⚠️  WARNING: This will permanently update records in your database!")
        print("   The country column will be updated with format 'language:country'")
        print("   (e.g., 'es:Spain', 'en:Spain')")
        print("   Make sure you have a backup before proceeding.")
        print("   Use --dry-run to analyze data without making changes.")
        print()
        
        if args.confirm:
            print("✅ Confirmation flag provided - proceeding with combination...")
        else:
            confirm = input("Are you sure you want to proceed? (type 'yes' to confirm): ")
            if confirm.lower() != 'yes':
                print("❌ Operation cancelled")
                return
    
    # Create combiner handler
    combiner = LanguageCountryCombiner(dry_run=dry_run)
    
    # Run combination
    success = await combiner.combine()
    
    if success:
        print("\n✅ Language-country combination completed successfully!")
    else:
        print("\n❌ Language-country combination failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

