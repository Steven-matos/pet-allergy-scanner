#!/usr/bin/env python3
"""
Database Cleanup Script
Removes food items that don't have ingredient lists in their nutritional_info

This script will:
1. Find all food items where nutritional_info.ingredients is empty or missing
2. Delete those records from the database
3. Provide statistics on what was cleaned up

Usage:
    python scripts/database/cleanup_database.py [--dry-run] [--confirm]
"""

import asyncio
import sys
import os
import json
from typing import List, Dict, Any
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add the parent directory to the path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import init_db, get_supabase_client, close_db
from app.core.config import settings
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DatabaseCleanup:
    """
    Handles database cleanup operations for food items without ingredient lists
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
            'records_with_ingredients': 0,
            'records_without_ingredients': 0,
            'deleted_records': 0,
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
        Analyze the current state of food items in the database
        
        Returns:
            Dict containing analysis results
        """
        logger.info("🔍 Analyzing food items in database...")
        
        try:
            # Get total count of food items
            total_response = self.supabase.table("food_items").select("id", count="exact").execute()
            self.stats['total_records'] = total_response.count or 0
            
            logger.info(f"📊 Total food items in database: {self.stats['total_records']}")
            
            if self.stats['total_records'] == 0:
                logger.warning("⚠️  No food items found in database")
                return self.stats
            
            # Get all food items with their nutritional_info (handle pagination)
            logger.info("📋 Fetching food items with nutritional info...")
            all_food_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select(
                    "id, name, brand, nutritional_info"
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
            items_with_ingredients = []
            items_without_ingredients = []
            
            for item in food_items:
                nutritional_info = item.get('nutritional_info', {})
                
                # Check if ingredients list exists and is not empty
                ingredients = nutritional_info.get('ingredients', [])
                
                if ingredients and len(ingredients) > 0:
                    # Filter out empty strings and check if any real ingredients exist
                    valid_ingredients = [ing for ing in ingredients if ing and ing.strip()]
                    if valid_ingredients:
                        items_with_ingredients.append(item)
                    else:
                        items_without_ingredients.append(item)
                else:
                    items_without_ingredients.append(item)
            
            self.stats['records_with_ingredients'] = len(items_with_ingredients)
            self.stats['records_without_ingredients'] = len(items_without_ingredients)
            
            # Log analysis results
            logger.info(f"✅ Records with ingredients: {self.stats['records_with_ingredients']}")
            logger.info(f"❌ Records without ingredients: {self.stats['records_without_ingredients']}")
            
            # Show some examples of items without ingredients
            if items_without_ingredients:
                logger.info("📝 Sample items without ingredients:")
                for i, item in enumerate(items_without_ingredients[:5]):  # Show first 5
                    logger.info(f"  {i+1}. {item.get('name', 'Unknown')} (Brand: {item.get('brand', 'Unknown')})")
                if len(items_without_ingredients) > 5:
                    logger.info(f"  ... and {len(items_without_ingredients) - 5} more")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error analyzing data: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def cleanup_records(self) -> Dict[str, Any]:
        """
        Remove food items that don't have ingredient lists
        
        Returns:
            Dict containing cleanup results
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No records will be deleted")
            return self.stats
        
        logger.info("🧹 Starting database cleanup...")
        
        try:
            # Get all food items without ingredients (handle pagination)
            logger.info("📋 Identifying records to delete...")
            
            all_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select("id, name, brand, nutritional_info").range(offset, offset + page_size - 1).execute()
                
                if not response.data:
                    break
                    
                all_items.extend(response.data)
                offset += page_size
                
                logger.info(f"📦 Analyzed {len(all_items)} food items so far...")
                
                # Break if we got fewer items than page size (last page)
                if len(response.data) < page_size:
                    break
            
            items_to_delete = []
            for item in all_items:
                nutritional_info = item.get('nutritional_info', {})
                ingredients = nutritional_info.get('ingredients', [])
                
                # Check if ingredients list is empty or missing
                if not ingredients or len(ingredients) == 0:
                    items_to_delete.append(item['id'])
                else:
                    # Check if all ingredients are empty strings
                    valid_ingredients = [ing for ing in ingredients if ing and ing.strip()]
                    if not valid_ingredients:
                        items_to_delete.append(item['id'])
            
            logger.info(f"🎯 Found {len(items_to_delete)} records to delete")
            
            if not items_to_delete:
                logger.info("✅ No records need to be deleted")
                return self.stats
            
            # Delete records in batches to avoid overwhelming the database
            batch_size = 100
            deleted_count = 0
            
            for i in range(0, len(items_to_delete), batch_size):
                batch = items_to_delete[i:i + batch_size]
                
                try:
                    # Delete the batch
                    delete_response = self.supabase.table("food_items").delete().in_("id", batch).execute()
                    deleted_count += len(batch)
                    
                    logger.info(f"🗑️  Deleted batch {i//batch_size + 1}: {len(batch)} records")
                    
                except Exception as e:
                    error_msg = f"Error deleting batch {i//batch_size + 1}: {e}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
            
            self.stats['deleted_records'] = deleted_count
            logger.info(f"✅ Cleanup completed. Deleted {deleted_count} records")
            
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
        report.append("DATABASE CLEANUP REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE CLEANUP'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total records analyzed: {self.stats['total_records']}")
        report.append(f"  Records with ingredients: {self.stats['records_with_ingredients']}")
        report.append(f"  Records without ingredients: {self.stats['records_without_ingredients']}")
        report.append(f"  Records deleted: {self.stats['deleted_records']}")
        report.append("")
        
        if self.stats['errors']:
            report.append("❌ ERRORS:")
            for error in self.stats['errors']:
                report.append(f"  - {error}")
            report.append("")
        
        # Calculate percentages
        if self.stats['total_records'] > 0:
            kept_percentage = (self.stats['records_with_ingredients'] / self.stats['total_records']) * 100
            removed_percentage = (self.stats['records_without_ingredients'] / self.stats['total_records']) * 100
            
            report.append("📈 PERCENTAGES:")
            report.append(f"  Records kept: {kept_percentage:.1f}%")
            report.append(f"  Records removed: {removed_percentage:.1f}%")
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
        finally:
            # Close database connection
            await close_db()


async def main():
    """
    Main function to run the database cleanup
    """
    import argparse
    
    parser = argparse.ArgumentParser(description="Clean up database by removing food items without ingredient lists")
    parser.add_argument("--dry-run", action="store_true", help="Analyze data without making changes")
    parser.add_argument("--confirm", action="store_true", help="Confirm that you want to delete records")
    
    args = parser.parse_args()
    
    # Determine if this is a dry run
    dry_run = args.dry_run or not args.confirm
    
    if not dry_run:
        print("⚠️  WARNING: This will permanently delete records from your database!")
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
    cleanup = DatabaseCleanup(dry_run=dry_run)
    
    # Run cleanup
    success = await cleanup.cleanup()
    
    if success:
        print("\n✅ Database cleanup completed successfully!")
    else:
        print("\n❌ Database cleanup failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
