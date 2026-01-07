#!/usr/bin/env python3
"""
Language Column Cleanup Script
Cleans up the language column in the food_items table

This script will:
1. Find all food items where language is NOT 'en' or 'es'
2. Delete those records
3. Provide statistics on what was cleaned up

Usage:
    python scripts/database/cleanup_language_column.py [--dry-run] [--confirm]
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


class LanguageColumnCleanup:
    """
    Handles database cleanup operations for language column filtering
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
            'records_with_en': 0,
            'records_with_es': 0,
            'records_to_delete': 0,
            'records_deleted': 0,
            'language_distribution': {},
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
        Analyze the current state of language column in food_items table
        
        Returns:
            Dict containing analysis results
        """
        logger.info("🔍 Analyzing language column in food_items table...")
        
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
            
            # Get all food items with language values (handle pagination)
            logger.info("📋 Fetching food items...")
            all_food_items = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("food_items").select(
                    "id, name, brand, language"
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
            items_to_delete = []
            items_with_en = []
            items_with_es = []
            language_distribution = {}
            
            for item in food_items:
                language = item.get('language', '').strip().lower() if item.get('language') else ''
                
                # Track language distribution
                lang_key = language if language else 'null/empty'
                language_distribution[lang_key] = language_distribution.get(lang_key, 0) + 1
                
                # Keep 'en' and 'es' (case-insensitive)
                if language == 'en':
                    items_with_en.append(item)
                elif language == 'es':
                    items_with_es.append(item)
                else:
                    # Mark for deletion (null, empty, or any other language)
                    items_to_delete.append(item)
            
            self.stats['records_with_en'] = len(items_with_en)
            self.stats['records_with_es'] = len(items_with_es)
            self.stats['records_to_delete'] = len(items_to_delete)
            self.stats['language_distribution'] = language_distribution
            
            # Store items to delete for later use
            self.items_to_delete = items_to_delete
            
            # Log analysis results
            logger.info(f"📊 Analysis Results:")
            logger.info(f"  Records with language 'en': {self.stats['records_with_en']}")
            logger.info(f"  Records with language 'es': {self.stats['records_with_es']}")
            logger.info(f"  Records to delete (not 'en' or 'es'): {self.stats['records_to_delete']}")
            logger.info("")
            logger.info("📋 Language Distribution:")
            for lang, count in sorted(language_distribution.items(), key=lambda x: x[1], reverse=True):
                logger.info(f"  '{lang}': {count}")
            
            # Show some examples of items that will be deleted
            if items_to_delete:
                logger.info("")
                logger.info("📝 Sample items to be deleted:")
                for i, item in enumerate(items_to_delete[:10]):  # Show first 10
                    lang = item.get('language', 'null/empty')
                    logger.info(
                        f"  {i+1}. {item.get('name', 'Unknown')} "
                        f"(Brand: {item.get('brand', 'Unknown')}) "
                        f"[Language: '{lang}']"
                    )
                if len(items_to_delete) > 10:
                    logger.info(f"  ... and {len(items_to_delete) - 10} more")
            
            return self.stats
            
        except Exception as e:
            error_msg = f"Error analyzing data: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return self.stats
    
    async def cleanup_records(self) -> Dict[str, Any]:
        """
        Delete food items that don't have language 'en' or 'es'
        
        This method deletes all records where language is NOT 'en' or 'es'
        (including null/empty values).
        
        Returns:
            Dict containing cleanup results
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No records will be deleted")
            logger.info(f"   Would delete {self.stats['records_to_delete']} records")
            return self.stats
        
        if not hasattr(self, 'items_to_delete') or not self.items_to_delete:
            logger.info("✅ No records need to be deleted")
            return self.stats
        
        logger.info(f"🧹 Starting language column cleanup...")
        logger.info(f"   Will delete {len(self.items_to_delete)} records")
        
        try:
            deleted_count = 0
            failed_count = 0
            
            # Delete records one by one to ensure accuracy and proper error handling
            # This approach ensures we only delete exactly what we analyzed
            for i, item in enumerate(self.items_to_delete):
                try:
                    # Delete the record by ID
                    delete_response = self.supabase.table("food_items").delete().eq(
                        'id', item['id']
                    ).execute()
                    
                    # Check if deletion was successful
                    # Supabase returns deleted data or empty list
                    if delete_response.data is not None:
                        deleted_count += 1
                    else:
                        # If no data returned but no error, record might not exist
                        # Log it but count as successful (might have been deleted already)
                        logger.debug(f"Record {item['id']} returned no data (might already be deleted)")
                        deleted_count += 1
                    
                    # Log progress every 100 records
                    if (i + 1) % 100 == 0:
                        logger.info(
                            f"📊 Progress: {i + 1}/{len(self.items_to_delete)} "
                            f"deleted, {failed_count} failed"
                        )
                        
                except Exception as e:
                    failed_count += 1
                    error_msg = f"Error deleting record {item['id']} ({item.get('name', 'Unknown')}): {e}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
            
            self.stats['records_deleted'] = deleted_count
            logger.info(f"✅ Cleanup completed:")
            logger.info(f"   Successfully deleted: {deleted_count} records")
            if failed_count > 0:
                logger.warning(f"   Failed to delete: {failed_count} records")
            
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
        report.append("LANGUAGE COLUMN CLEANUP REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE CLEANUP'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total records: {self.stats['total_records']}")
        report.append(f"  Records with language 'en': {self.stats['records_with_en']}")
        report.append(f"  Records with language 'es': {self.stats['records_with_es']}")
        report.append(f"  Records to delete: {self.stats['records_to_delete']}")
        report.append(f"  Records deleted: {self.stats['records_deleted']}")
        report.append("")
        
        report.append("📋 LANGUAGE DISTRIBUTION:")
        for lang, count in sorted(
            self.stats['language_distribution'].items(), 
            key=lambda x: x[1], 
            reverse=True
        ):
            report.append(f"  '{lang}': {count}")
        report.append("")
        
        if self.stats['errors']:
            report.append("❌ ERRORS:")
            for error in self.stats['errors']:
                report.append(f"  - {error}")
            report.append("")
        
        # Calculate percentages
        if self.stats['total_records'] > 0:
            en_percentage = (self.stats['records_with_en'] / self.stats['total_records']) * 100
            es_percentage = (self.stats['records_with_es'] / self.stats['total_records']) * 100
            delete_percentage = (
                (self.stats['records_deleted'] / self.stats['total_records']) * 100
            ) if not self.dry_run else (
                (self.stats['records_to_delete'] / self.stats['total_records']) * 100
            )
            
            report.append("📈 PERCENTAGES:")
            report.append(f"  Records with 'en': {en_percentage:.1f}%")
            report.append(f"  Records with 'es': {es_percentage:.1f}%")
            if not self.dry_run:
                report.append(f"  Records deleted: {delete_percentage:.1f}%")
            else:
                report.append(f"  Records that would be deleted: {delete_percentage:.1f}%")
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
    Main function to run the language column cleanup
    """
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Clean up language column in food_items table by removing all items that are NOT 'en' or 'es'"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Analyze data without making changes"
    )
    parser.add_argument(
        "--confirm", 
        action="store_true", 
        help="Confirm that you want to delete records"
    )
    
    args = parser.parse_args()
    
    # Determine if this is a dry run
    dry_run = args.dry_run or not args.confirm
    
    if not dry_run:
        print("⚠️  WARNING: This will permanently DELETE records from your database!")
        print("   Only records with language 'en' or 'es' will be kept.")
        print("   All other records (including null/empty language) will be DELETED.")
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
    cleanup = LanguageColumnCleanup(dry_run=dry_run)
    
    # Run cleanup
    success = await cleanup.cleanup()
    
    if success:
        print("\n✅ Language column cleanup completed successfully!")
    else:
        print("\n❌ Language column cleanup failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

