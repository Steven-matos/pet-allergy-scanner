#!/usr/bin/env python3
"""
Backfill Missing Nutritional Trends Script

This script finds all dates with feeding records but no corresponding nutritional trends
and creates the missing trend records by calling the update_nutritional_trends function.

Usage:
    python scripts/database/backfill_nutritional_trends.py [--dry-run] [--limit N]
"""

import asyncio
import sys
import os
from typing import List, Dict, Any, Optional
from datetime import datetime, date
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Add the parent directory to the path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from supabase import create_client
from app.core.config import settings
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class NutritionalTrendsBackfill:
    """
    Handles backfilling missing nutritional trends records
    """
    
    def __init__(self, dry_run: bool = False, limit: Optional[int] = None):
        """
        Initialize the backfill handler
        
        Args:
            dry_run: If True, only analyze data without creating records
            limit: Maximum number of records to process (None for all)
        """
        self.dry_run = dry_run
        self.limit = limit
        self.supabase = None
        self.stats = {
            'total_feeding_records': 0,
            'total_existing_trends': 0,
            'missing_trends_found': 0,
            'trends_created': 0,
            'trends_updated': 0,
            'errors': [],
            'processed_pets': set()
        }
    
    async def initialize(self) -> bool:
        """
        Initialize database connection
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            logger.info("🔌 Initializing database connection...")
            # Use service role key for admin operations
            self.supabase = create_client(
                settings.supabase_url, 
                settings.supabase_service_role_key
            )
            logger.info("✅ Database connection established")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to initialize database: {e}")
            return False
    
    async def find_missing_trends(self) -> List[Dict[str, Any]]:
        """
        Find all dates with feeding records but no nutritional trends
        
        Returns:
            List of dicts with pet_id and trend_date
        """
        logger.info("🔍 Finding missing nutritional trends...")
        
        try:
            # Query to find missing trends
            # We'll use a raw SQL query via RPC or direct query
            # First, let's get all unique pet_id and date combinations from feeding_records
            logger.info("📊 Fetching feeding records...")
            
            # Get all feeding records with pagination (include food_analysis_id to check)
            all_feeding_records = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.supabase.table("feeding_records").select(
                    "pet_id, feeding_time, food_analysis_id"
                ).range(offset, offset + page_size - 1).execute()
                
                if not response.data:
                    break
                
                all_feeding_records.extend(response.data)
                offset += page_size
                
                if len(response.data) < page_size:
                    break
            
            self.stats['total_feeding_records'] = len(all_feeding_records)
            logger.info(f"📦 Found {len(all_feeding_records)} feeding records")
            
            # Check how many have food_analysis_id
            records_with_analysis = [r for r in all_feeding_records if r.get('food_analysis_id')]
            records_without_analysis = len(all_feeding_records) - len(records_with_analysis)
            
            if records_without_analysis > 0:
                logger.warning(
                    f"⚠️  {records_without_analysis} feeding records don't have food_analysis_id. "
                    f"These won't be included in nutritional trends (function uses INNER JOIN)."
                )
            
            if len(all_feeding_records) == 0:
                logger.warning("⚠️  No feeding records found in database")
                return []
            
            # Get existing trends
            logger.info("📊 Fetching existing nutritional trends...")
            all_trends = []
            offset = 0
            
            while True:
                response = self.supabase.table("nutritional_trends").select(
                    "pet_id, trend_date"
                ).range(offset, offset + page_size - 1).execute()
                
                if not response.data:
                    break
                
                all_trends.extend(response.data)
                offset += page_size
                
                if len(response.data) < page_size:
                    break
            
            self.stats['total_existing_trends'] = len(all_trends)
            logger.info(f"📦 Found {len(all_trends)} existing nutritional trends")
            
            # Create a set of existing (pet_id, date) combinations for fast lookup
            existing_trends = set()
            for trend in all_trends:
                pet_id = trend.get('pet_id')
                trend_date = trend.get('trend_date')
                if pet_id and trend_date:
                    # Normalize date to string for comparison
                    if isinstance(trend_date, str):
                        date_str = trend_date.split('T')[0]  # Remove time if present
                    else:
                        date_str = str(trend_date)
                    existing_trends.add((pet_id, date_str))
            
            # Find missing trends
            missing_trends = []
            seen_combinations = set()
            
            for record in all_feeding_records:
                pet_id = record.get('pet_id')
                feeding_time = record.get('feeding_time')
                food_analysis_id = record.get('food_analysis_id')
                
                if not pet_id or not feeding_time:
                    continue
                
                # Extract date from feeding_time
                if isinstance(feeding_time, str):
                    # Parse ISO format string
                    try:
                        dt = datetime.fromisoformat(feeding_time.replace('Z', '+00:00'))
                        trend_date = dt.date()
                    except:
                        continue
                elif isinstance(feeding_time, datetime):
                    trend_date = feeding_time.date()
                else:
                    continue
                
                date_str = str(trend_date)
                combination = (pet_id, date_str)
                
                # Skip if we've already seen this combination
                if combination in seen_combinations:
                    continue
                
                seen_combinations.add(combination)
                
                # Check if trend exists
                if combination not in existing_trends:
                    missing_trends.append({
                        'pet_id': pet_id,
                        'trend_date': trend_date,
                        'has_food_analysis': food_analysis_id is not None
                    })
                    self.stats['processed_pets'].add(pet_id)
            
            self.stats['missing_trends_found'] = len(missing_trends)
            logger.info(f"🎯 Found {len(missing_trends)} missing nutritional trends")
            
            # Apply limit if specified
            if self.limit and len(missing_trends) > self.limit:
                logger.info(f"📝 Limiting to first {self.limit} records")
                missing_trends = missing_trends[:self.limit]
            
            return missing_trends
            
        except Exception as e:
            error_msg = f"Error finding missing trends: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return []
    
    async def create_trends(self, missing_trends: List[Dict[str, Any]]) -> bool:
        """
        Create missing nutritional trends by calling the update_nutritional_trends function
        
        Args:
            missing_trends: List of dicts with pet_id and trend_date
            
        Returns:
            bool: True if successful, False otherwise
        """
        if self.dry_run:
            logger.info("🔍 DRY RUN MODE - No trends will be created")
            logger.info(f"📝 Would create {len(missing_trends)} nutritional trends")
            return True
        
        if not missing_trends:
            logger.info("✅ No missing trends to create")
            return True
        
        logger.info(f"🚀 Starting to create {len(missing_trends)} nutritional trends...")
        
        try:
            processed = 0
            errors = 0
            
            for i, trend_info in enumerate(missing_trends, 1):
                pet_id = trend_info['pet_id']
                trend_date = trend_info['trend_date']
                
                try:
                    # Convert date to string if needed
                    if isinstance(trend_date, date):
                        date_str = trend_date.isoformat()
                    else:
                        date_str = str(trend_date)
                    
                    # Log what we're about to process
                    logger.debug(f"Processing pet {pet_id} for date {date_str}")
                    
                    # Call the update_nutritional_trends function
                    # Note: Function parameter is p_trend_date to avoid ambiguity
                    try:
                        result = self.supabase.rpc(
                            'update_nutritional_trends',
                            {
                                'pet_uuid': pet_id,
                                'p_trend_date': date_str  # Updated to match new parameter name
                            }
                        ).execute()
                        logger.debug(f"RPC call successful for pet {pet_id} on {date_str}")
                    except Exception as rpc_error:
                        # Log the RPC error with more detail
                        logger.error(f"RPC call failed for pet {pet_id} on {date_str}: {rpc_error}")
                        logger.error(f"RPC error type: {type(rpc_error).__name__}")
                        if hasattr(rpc_error, 'message'):
                            logger.error(f"RPC error message: {rpc_error.message}")
                        raise  # Re-raise to be caught by outer exception handler
                    
                    # Wait a moment for the database to commit
                    await asyncio.sleep(0.1)
                    
                    # Check if a new record was created or existing was updated
                    # We'll check by querying the trends table
                    check_result = self.supabase.table("nutritional_trends").select(
                        "id, created_at, updated_at, feeding_count"
                    ).eq("pet_id", pet_id).eq("trend_date", date_str).execute()
                    
                    if check_result.data:
                        trend = check_result.data[0]
                        feeding_count = trend.get('feeding_count', 0)
                        
                        # If feeding_count is 0, the function didn't find any feeding records
                        # This could mean the feeding records don't have food_analyses
                        if feeding_count == 0:
                            logger.warning(
                                f"⚠️  Trend created for pet {pet_id} on {date_str} but feeding_count is 0. "
                                f"This might mean feeding records don't have food_analyses linked."
                            )
                        
                        created_at = trend.get('created_at')
                        updated_at = trend.get('updated_at')
                        
                        # If created_at and updated_at are very close, it's likely a new record
                        if created_at and updated_at:
                            try:
                                created = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                                updated = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                                time_diff = abs((updated - created).total_seconds())
                                
                                if time_diff < 2:  # Less than 2 seconds difference
                                    self.stats['trends_created'] += 1
                                    logger.debug(f"✅ Created new trend for pet {pet_id} on {date_str} (feeding_count: {feeding_count})")
                                else:
                                    self.stats['trends_updated'] += 1
                                    logger.debug(f"🔄 Updated existing trend for pet {pet_id} on {date_str} (feeding_count: {feeding_count})")
                            except:
                                # Default to created if we can't determine
                                self.stats['trends_created'] += 1
                                logger.debug(f"✅ Created new trend for pet {pet_id} on {date_str} (feeding_count: {feeding_count})")
                        else:
                            self.stats['trends_created'] += 1
                            logger.debug(f"✅ Created new trend for pet {pet_id} on {date_str} (feeding_count: {feeding_count})")
                    else:
                        # No trend was created - this is a problem
                        logger.warning(
                            f"⚠️  RPC call succeeded but no trend record found for pet {pet_id} on {date_str}. "
                            f"This might mean the function didn't create a record (possibly no feeding records with food_analyses)."
                        )
                        # Check if there are feeding records for this date
                        feeding_check = self.supabase.table("feeding_records").select(
                            "id, food_analysis_id"
                        ).eq("pet_id", pet_id).gte("feeding_time", f"{date_str}T00:00:00").lt("feeding_time", f"{date_str}T23:59:59").execute()
                        
                        if feeding_check.data:
                            logger.info(f"📋 Found {len(feeding_check.data)} feeding records for this date")
                            records_with_analysis = [r for r in feeding_check.data if r.get('food_analysis_id')]
                            logger.info(f"📋 {len(records_with_analysis)} of {len(feeding_check.data)} have food_analysis_id")
                        else:
                            logger.warning(f"⚠️  No feeding records found for pet {pet_id} on {date_str}")
                    
                    processed += 1
                    
                    # Log progress every 50 records
                    if processed % 50 == 0:
                        logger.info(f"📊 Progress: {processed}/{len(missing_trends)} trends processed...")
                    
                except Exception as e:
                    errors += 1
                    error_msg = f"Error creating trend for pet {pet_id} on {trend_date}: {e}"
                    logger.error(error_msg)
                    self.stats['errors'].append(error_msg)
                    continue
            
            logger.info(f"✅ Processed {processed} trends ({self.stats['trends_created']} created, {self.stats['trends_updated']} updated)")
            if errors > 0:
                logger.warning(f"⚠️  Encountered {errors} errors during processing")
            
            return errors == 0
            
        except Exception as e:
            error_msg = f"Error during trend creation: {e}"
            logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return False
    
    async def generate_report(self) -> str:
        """
        Generate a backfill report
        
        Returns:
            str: Formatted report
        """
        report = []
        report.append("=" * 60)
        report.append("NUTRITIONAL TRENDS BACKFILL REPORT")
        report.append("=" * 60)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE BACKFILL'}")
        report.append("")
        
        report.append("📊 STATISTICS:")
        report.append(f"  Total feeding records: {self.stats['total_feeding_records']}")
        report.append(f"  Existing nutritional trends: {self.stats['total_existing_trends']}")
        report.append(f"  Missing trends found: {self.stats['missing_trends_found']}")
        report.append(f"  Trends created: {self.stats['trends_created']}")
        report.append(f"  Trends updated: {self.stats['trends_updated']}")
        report.append(f"  Unique pets processed: {len(self.stats['processed_pets'])}")
        report.append("")
        
        if self.stats['errors']:
            report.append(f"❌ ERRORS ({len(self.stats['errors'])}):")
            for error in self.stats['errors'][:10]:  # Show first 10 errors
                report.append(f"  - {error}")
            if len(self.stats['errors']) > 10:
                report.append(f"  ... and {len(self.stats['errors']) - 10} more errors")
            report.append("")
        
        # Calculate coverage
        if self.stats['total_feeding_records'] > 0:
            coverage = ((self.stats['total_existing_trends'] + self.stats['trends_created']) / 
                        self.stats['missing_trends_found'] * 100) if self.stats['missing_trends_found'] > 0 else 100
            report.append("📈 COVERAGE:")
            report.append(f"  Trends coverage: {coverage:.1f}%")
            report.append("")
        
        report.append("=" * 60)
        
        return "\n".join(report)
    
    async def backfill(self) -> bool:
        """
        Perform the complete backfill process
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            # Initialize database connection
            if not await self.initialize():
                return False
            
            # Find missing trends
            missing_trends = await self.find_missing_trends()
            
            if not missing_trends:
                logger.info("✅ No missing trends found. All dates with feeding records already have trends.")
                return True
            
            # Create missing trends
            success = await self.create_trends(missing_trends)
            
            # Generate and display report
            report = await self.generate_report()
            print("\n" + report)
            
            # Log final status
            if self.stats['errors']:
                logger.warning(f"⚠️  Backfill completed with {len(self.stats['errors'])} errors")
                return len(self.stats['errors']) < len(missing_trends)  # Success if most worked
            else:
                logger.info("✅ Backfill completed successfully")
                return True
                
        except Exception as e:
            logger.error(f"❌ Backfill failed: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False


async def main():
    """
    Main function to run the nutritional trends backfill
    """
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Backfill missing nutritional trends records",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Dry run to see what would be created
  python scripts/database/backfill_nutritional_trends.py --dry-run
  
  # Create all missing trends
  python scripts/database/backfill_nutritional_trends.py
  
  # Create only first 100 missing trends
  python scripts/database/backfill_nutritional_trends.py --limit 100
        """
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Analyze data without creating records"
    )
    parser.add_argument(
        "--limit", 
        type=int, 
        default=None,
        help="Maximum number of trends to create (default: all)"
    )
    
    args = parser.parse_args()
    
    if args.dry_run:
        print("🔍 DRY RUN MODE - No records will be created")
        print()
    
    # Create backfill handler
    backfill = NutritionalTrendsBackfill(dry_run=args.dry_run, limit=args.limit)
    
    # Run backfill
    success = await backfill.backfill()
    
    if success:
        print("\n✅ Nutritional trends backfill completed successfully!")
        sys.exit(0)
    else:
        print("\n❌ Nutritional trends backfill failed. Check the logs for details.")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

