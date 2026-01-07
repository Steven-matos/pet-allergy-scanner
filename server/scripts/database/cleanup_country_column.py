#!/usr/bin/env python3
"""
Country Column Cleanup Script
Cleans up the country column in the food_items table

This script will:
1. Find all food items where country contains 'en:US' in any capacity
2. Replace those with 'en:United States'
3. Find all food items where country is 'en:united-states'
4. Replace those with 'en:United States'
5. Find all food items where country is 'United States' (exact, without prefix)
6. Replace those with 'en:United States'
7. Find all food items where country is 'US' (without prefix)
8. Replace those with 'en:United States'
9. Find all food items where country is 'united-states' (without prefix)
10. Replace those with 'en:United States'
11. Find all food items where country is 'USA'
12. Replace those with 'en:United States'
13. Find all food items where country contains 'United States of America'
14. Replace those with 'en:United States'
15. Find all food items where country contains 'United States' (e.g., 'United States, Canada')
16. Replace those with 'en:United States'
17. Find all food items where country is 'États-Unis' (French for United States)
18. Replace those with 'en:United States'
19. Provide statistics on what was cleaned up

Usage:
    python scripts/database/cleanup_country_column.py [--dry-run] [--confirm]
"""

import asyncio
import sys
import os
from typing import List, Dict, Any
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


class CountryColumnCleanup:
    """
    Handles database cleanup operations for country column standardization
    """
    
    def __init__(self, dry_run: bool = True):
        """
        Initialize the cleanup handler
        
        Args:
            dry_run: If True, only analyze data without making changes
        """
        self.dry_run = dry_run
        self.supabase = None
        self.stats = {
            'total_records': 0,
            'records_with_en_us': 0,
            'records_with_en_united_states_hyphen': 0,
            'records_with_united_states': 0,
            'records_with_us_only': 0,
            'records_with_united_states_hyphen': 0,
            'records_with_usa': 0,
            'records_with_united_states_of_america': 0,
            'records_containing_united_states': 0,
            'records_with_etats_unis': 0,
            'records_already_correct': 0,
            'records_updated': 0,
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
    
    async def analyze_data(self) -> Dict[str, Any]:
        """
        Analyze the current state of country column in food_items table
        
        Returns:
            Dict containing analysis results
        """
        logger.info("🔍 Analyzing country column in food_items table...")
        
        try:
            # Get total count of food items with country values
            total_response = self.supabase.table("food_items").select(
                "id", 
                count="exact"
            ).not_.is_("country", "null").execute()
            
            self.stats['total_records'] = total_response.count or 0
            
            logger.info(f"📊 Total food items with country values: {self.stats['total_records']}")
            
            if self.stats['total_records'] == 0:
                logger.warning("⚠️  No food items with country values found in database")
                return self.stats
            
            # Get all food items with country values (handle pagination)
            logger.info("📋 Fetching food items with country values...")
            all_food_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select(
                    "id, name, brand, country"
                ).not_.is_("country", "null").range(offset, offset + page_size - 1).execute()
                
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
            items_with_en_us = []
            items_with_en_united_states_hyphen = []
            items_with_united_states = []
            items_with_us_only = []
            items_with_united_states_hyphen = []
            items_with_usa = []
            items_with_united_states_of_america = []
            items_containing_united_states = []
            items_with_etats_unis = []
            items_already_correct = []
            
            for item in food_items:
                country = item.get('country', '').strip()
                country_lower = country.lower()
                country_casefold = country.casefold()
                
                if not country:
                    continue
                
                # Check if already correct first (skip processing)
                if country == 'en:United States':
                    items_already_correct.append(item)
                    continue
                
                # Check if country contains 'en:US' or 'en:us' in any capacity (case-insensitive, must check before standalone US)
                if 'en:us' in country_lower:
                    items_with_en_us.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'en:united-states' (case-insensitive)
                elif country_lower == 'en:united-states':
                    items_with_en_united_states_hyphen.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'United States' (case-insensitive, without prefix)
                elif country_lower == 'united states':
                    items_with_united_states.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'US' (case-insensitive, without prefix)
                # Only match if it's not already handled by 'en:US' check above
                elif country_lower == 'us':
                    items_with_us_only.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'united-states' (case-insensitive, without prefix)
                elif country_lower == 'united-states':
                    items_with_united_states_hyphen.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'USA' (case-insensitive)
                elif country_lower == 'usa':
                    items_with_usa.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country is exactly 'États-Unis' (case-insensitive, French for United States)
                elif country_casefold == 'états-unis':
                    items_with_etats_unis.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country contains 'United States of America' (case-insensitive)
                elif 'united states of america' in country_lower:
                    items_with_united_states_of_america.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
                # Check if country contains 'United States' (but not already matched above)
                # This catches cases like "United States, Canada" or similar
                elif 'united states' in country_lower:
                    items_containing_united_states.append(item)
                    items_to_update.append({
                        'id': item['id'],
                        'old_country': country,
                        'new_country': 'en:United States'
                    })
            
            self.stats['records_with_en_us'] = len(items_with_en_us)
            self.stats['records_with_en_united_states_hyphen'] = len(items_with_en_united_states_hyphen)
            self.stats['records_with_united_states'] = len(items_with_united_states)
            self.stats['records_with_us_only'] = len(items_with_us_only)
            self.stats['records_with_united_states_hyphen'] = len(items_with_united_states_hyphen)
            self.stats['records_with_usa'] = len(items_with_usa)
            self.stats['records_with_united_states_of_america'] = len(items_with_united_states_of_america)
            self.stats['records_containing_united_states'] = len(items_containing_united_states)
            self.stats['records_with_etats_unis'] = len(items_with_etats_unis)
            self.stats['records_already_correct'] = len(items_already_correct)
            
            # Store items to update for later use
            self.items_to_update = items_to_update
            
            # Log analysis results
            logger.info(f"📊 Analysis Results:")
            logger.info(f"  Records containing 'en:US': {self.stats['records_with_en_us']}")
            logger.info(f"  Records with 'en:united-states': {self.stats['records_with_en_united_states_hyphen']}")
            logger.info(f"  Records with 'United States' (exact, no prefix): {self.stats['records_with_united_states']}")
            logger.info(f"  Records with 'US' (no prefix): {self.stats['records_with_us_only']}")
            logger.info(f"  Records with 'united-states' (no prefix): {self.stats['records_with_united_states_hyphen']}")
            logger.info(f"  Records with 'USA': {self.stats['records_with_usa']}")
            logger.info(f"  Records with 'United States of America': {self.stats['records_with_united_states_of_america']}")
            logger.info(f"  Records containing 'United States' (e.g., 'United States, Canada'): {self.stats['records_containing_united_states']}")
            logger.info(f"  Records with 'États-Unis' (French): {self.stats['records_with_etats_unis']}")
            logger.info(f"  Records already correct: {self.stats['records_already_correct']}")
            logger.info(f"  Total records to update: {len(items_to_update)}")
            
            # Show some examples of items that will be updated
            if items_to_update:
                logger.info("📝 Sample items to be updated:")
                for i, item_update in enumerate(items_to_update[:10]):  # Show first 10
                    # Find the full item data for display
                    item_data = next(
                        (item for item in food_items if item['id'] == item_update['id']), 
                        None
                    )
                    if item_data:
                        logger.info(
                            f"  {i+1}. {item_data.get('name', 'Unknown')} "
                            f"(Brand: {item_data.get('brand', 'Unknown')}) "
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
    
    async def cleanup_records(self) -> Dict[str, Any]:
        """
        Update food items with standardized country values
        
        Returns:
            Dict containing cleanup results
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No records will be updated")
            return self.stats
        
        if not hasattr(self, 'items_to_update') or not self.items_to_update:
            logger.info("✅ No records need to be updated")
            return self.stats
        
        logger.info("🧹 Starting country column cleanup...")
        
        try:
            updated_count = 0
            
            # Update records one by one to ensure accuracy
            # (Supabase doesn't support batch updates with different values easily)
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
                        logger.info(f"📊 Updated {i + 1} of {len(self.items_to_update)} records...")
                        
                except Exception as e:
                    error_msg = f"Error updating record {item_update['id']}: {e}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
            
            self.stats['records_updated'] = updated_count
            logger.info(f"✅ Cleanup completed. Updated {updated_count} records")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error during cleanup: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def generate_report(self) -> str:
        """
        Generate a cleanup report
        
        Returns:
            str: Formatted report
        """
        report = []
        report.append("=" * 60)
        report.append("COUNTRY COLUMN CLEANUP REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE CLEANUP'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total records with country values: {self.stats['total_records']}")
        report.append(f"  Records containing 'en:US': {self.stats['records_with_en_us']}")
        report.append(
            f"  Records with 'en:united-states': {self.stats['records_with_en_united_states_hyphen']}"
        )
        report.append(
            f"  Records with 'United States' (exact, no prefix): {self.stats['records_with_united_states']}"
        )
        report.append(f"  Records with 'US' (no prefix): {self.stats['records_with_us_only']}")
        report.append(
            f"  Records with 'united-states' (no prefix): {self.stats['records_with_united_states_hyphen']}"
        )
        report.append(f"  Records with 'USA': {self.stats['records_with_usa']}")
        report.append(
            f"  Records with 'United States of America': {self.stats['records_with_united_states_of_america']}"
        )
        report.append(
            f"  Records containing 'United States' (e.g., 'United States, Canada'): {self.stats['records_containing_united_states']}"
        )
        report.append(f"  Records with 'États-Unis' (French): {self.stats['records_with_etats_unis']}")
        report.append(f"  Records already correct: {self.stats['records_already_correct']}")
        report.append(f"  Records updated: {self.stats['records_updated']}")
        report.append("")
        
        if self.stats['errors']:
            report.append("❌ ERRORS:")
            for error in self.stats['errors']:
                report.append(f"  - {error}")
            report.append("")
        
        # Calculate percentages
        if self.stats['total_records'] > 0:
            total_to_update = (
                self.stats['records_with_en_us'] + 
                self.stats['records_with_en_united_states_hyphen'] +
                self.stats['records_with_united_states'] +
                self.stats['records_with_us_only'] +
                self.stats['records_with_united_states_hyphen'] +
                self.stats['records_with_usa'] +
                self.stats['records_with_united_states_of_america'] +
                self.stats['records_containing_united_states'] +
                self.stats['records_with_etats_unis']
            )
            updated_percentage = (
                (self.stats['records_updated'] / self.stats['total_records']) * 100
            ) if not self.dry_run else (
                (total_to_update / self.stats['total_records']) * 100
            )
            correct_percentage = (self.stats['records_already_correct'] / self.stats['total_records']) * 100
            
            report.append("📈 PERCENTAGES:")
            if not self.dry_run:
                report.append(f"  Records updated: {updated_percentage:.1f}%")
            else:
                report.append(f"  Records that would be updated: {updated_percentage:.1f}%")
            report.append(f"  Records already correct: {correct_percentage:.1f}%")
            report.append("")
        
        report.append("=" * 60)
        
        return "\n".join(report)
    
    async def cleanup(self) -> bool:
        """
        Perform the complete cleanup process
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Initialize database connection
            if not await self.initialize():
                return False
            
            # Analyze current data
            await self.analyze_data()
            
            # Perform cleanup
            await self.cleanup_records()
            
            # Generate and display report
            report = await self.generate_report()
            print("\n" + report)
            
            # Log final status
            if self.stats['errors']:
                logger.warning(f"⚠️  Cleanup completed with {len(self.stats['errors'])} errors")
                return False
            else:
                logger.info("✅ Cleanup completed successfully")
                return True
                
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {e}")
            return False


async def main():
    """
    Main function to run the country column cleanup
    """
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Clean up country column in food_items table by standardizing US country codes"
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
        print("   Make sure you have a backup before proceeding.")
        print("   Use --dry-run to analyze data without making changes.")
        print()
        
        if args.confirm:
            print("✅ Confirmation flag provided - proceeding with cleanup...")
        else:
            confirm = input("Are you sure you want to proceed? (type 'yes' to confirm): ")
            if confirm.lower() != 'yes':
                print("❌ Operation cancelled")
                return
    
    # Create cleanup handler
    cleanup = CountryColumnCleanup(dry_run=dry_run)
    
    # Run cleanup
    success = await cleanup.cleanup()
    
    if success:
        print("\n✅ Country column cleanup completed successfully!")
    else:
        print("\n❌ Country column cleanup failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
