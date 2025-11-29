#!/usr/bin/env python3
"""
Supabase Table Analysis Script

Analyzes your Supabase database to identify:
1. Tables that are actually used by your API
2. Tables that are referenced in your codebase
3. Tables that can be safely removed
4. Missing tables that need to be created

Usage:
    python3 scripts/database/analyze_database_tables.py
"""

import os
import sys
from pathlib import Path
import re
from typing import Set, Dict, List

# Add the parent directory to the path so we can import app modules
sys.path.append(str(Path(__file__).parent.parent.parent))

from app.core.config import settings
from supabase import create_client
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_existing_tables(supabase) -> Set[str]:
    """Get all existing tables in Supabase"""
    try:
        # Try to get tables by querying each one we expect
        expected_tables = [
            'users', 'pets', 'scans', 'favorites', 'ingredients', 'food_items',
            'nutritional_requirements', 'food_analyses', 'feeding_records',
            'daily_nutrition_summaries', 'nutrition_recommendations', 'nutrition_goals',
            'pet_weight_records', 'pet_weight_goals', 'nutritional_trends',
            'food_comparisons', 'nutritional_analytics_cache', 'health_events',
            'medication_reminders', 'medical_records'
        ]
        
        existing_tables = set()
        for table in expected_tables:
            try:
                response = supabase.table(table).select('*').limit(1).execute()
                existing_tables.add(table)
                logger.info(f"✅ {table} - exists")
            except Exception as e:
                logger.info(f"❌ {table} - missing")
        
        return existing_tables
        
    except Exception as e:
        logger.error(f"Error checking tables: {e}")
        return set()

def scan_codebase_for_table_references() -> Dict[str, List[str]]:
    """Scan the codebase for table references"""
    table_references = {}
    
    # Define the server directory
    server_dir = Path(__file__).parent.parent.parent
    
    # File patterns to scan
    patterns = ['**/*.py', '**/*.sql']
    
    for pattern in patterns:
        for file_path in server_dir.glob(pattern):
            if file_path.is_file():
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    # Look for table references in various patterns
                    table_patterns = [
                        r'supabase\.table\(["\']([^"\']+)["\']',  # supabase.table('table_name')
                        r'FROM\s+([a-zA-Z_][a-zA-Z0-9_]*)',     # FROM table_name
                        r'INSERT\s+INTO\s+([a-zA-Z_][a-zA-Z0-9_]*)',  # INSERT INTO table_name
                        r'UPDATE\s+([a-zA-Z_][a-zA-Z0-9_]*)',    # UPDATE table_name
                        r'DELETE\s+FROM\s+([a-zA-Z_][a-zA-Z0-9_]*)',  # DELETE FROM table_name
                        r'CREATE\s+TABLE\s+([a-zA-Z_][a-zA-Z0-9_]*)', # CREATE TABLE table_name
                        r'ALTER\s+TABLE\s+([a-zA-Z_][a-zA-Z0-9_]*)',  # ALTER TABLE table_name
                        r'DROP\s+TABLE\s+([a-zA-Z_][a-zA-Z0-9_]*)',   # DROP TABLE table_name
                    ]
                    
                    for pattern in table_patterns:
                        matches = re.findall(pattern, content, re.IGNORECASE)
                        for match in matches:
                            table_name = match.lower()
                            if table_name not in table_references:
                                table_references[table_name] = []
                            table_references[table_name].append(str(file_path))
                            
                except Exception as e:
                    logger.warning(f"Could not read {file_path}: {e}")
    
    return table_references

def get_table_row_counts(supabase, tables: Set[str]) -> Dict[str, int]:
    """Get row counts for each table"""
    row_counts = {}
    
    for table in tables:
        try:
            response = supabase.table(table).select('*', count='exact').execute()
            row_counts[table] = response.count or 0
        except Exception as e:
            logger.warning(f"Could not get count for {table}: {e}")
            row_counts[table] = -1
    
    return row_counts

def analyze_table_dependencies(supabase, tables: Set[str]) -> Dict[str, List[str]]:
    """Analyze foreign key dependencies between tables"""
    dependencies = {}
    
    # Common foreign key patterns
    fk_patterns = {
        'pets': ['user_id'],
        'scans': ['user_id', 'pet_id'],
        'favorites': ['user_id', 'pet_id'],
        'nutritional_requirements': ['pet_id'],
        'food_analyses': ['pet_id'],
        'feeding_records': ['pet_id', 'food_analysis_id'],
        'daily_nutrition_summaries': ['pet_id'],
        'nutrition_recommendations': ['pet_id'],
        'nutrition_goals': ['pet_id'],
        'pet_weight_records': ['pet_id', 'recorded_by_user_id'],
        'pet_weight_goals': ['pet_id'],
        'nutritional_trends': ['pet_id'],
        'food_comparisons': ['user_id'],
        'nutritional_analytics_cache': ['pet_id'],
        'health_events': ['pet_id', 'user_id'],
        'medication_reminders': ['health_event_id', 'pet_id', 'user_id'],
    }
    
    for table in tables:
        if table in fk_patterns:
            dependencies[table] = fk_patterns[table]
    
    return dependencies

def main():
    """Main analysis function"""
    logger.info("🔍 Supabase Table Analysis")
    logger.info("=" * 60)
    
    try:
        # Create Supabase client
        supabase = create_client(settings.supabase_url, settings.supabase_key)
        
        # Get existing tables
        logger.info("📊 Checking existing tables...")
        existing_tables = get_existing_tables(supabase)
        
        # Scan codebase for references
        logger.info("\n🔍 Scanning codebase for table references...")
        table_references = scan_codebase_for_table_references()
        
        # Get row counts
        logger.info("\n📈 Getting table row counts...")
        row_counts = get_table_row_counts(supabase, existing_tables)
        
        # Analyze dependencies
        logger.info("\n🔗 Analyzing table dependencies...")
        dependencies = analyze_table_dependencies(supabase, existing_tables)
        
        # Define expected tables from your schema
        expected_tables = {
            'users', 'pets', 'scans', 'favorites', 'ingredients', 'food_items',
            'nutritional_requirements', 'food_analyses', 'feeding_records',
            'daily_nutrition_summaries', 'nutrition_recommendations', 'nutrition_goals',
            'pet_weight_records', 'pet_weight_goals', 'nutritional_trends',
            'food_comparisons', 'nutritional_analytics_cache', 'health_events',
            'medication_reminders', 'medical_records'
        }
        
        # Analysis results
        logger.info("\n" + "=" * 60)
        logger.info("📋 ANALYSIS RESULTS")
        logger.info("=" * 60)
        
        # Tables that exist and are expected
        expected_existing = existing_tables.intersection(expected_tables)
        logger.info(f"\n✅ EXPECTED TABLES THAT EXIST ({len(expected_existing)}):")
        for table in sorted(expected_existing):
            count = row_counts.get(table, 0)
            refs = len(table_references.get(table, []))
            logger.info(f"  • {table} ({count} rows, {refs} code references)")
        
        # Missing expected tables
        missing_expected = expected_tables - existing_tables
        logger.info(f"\n❌ MISSING EXPECTED TABLES ({len(missing_expected)}):")
        for table in sorted(missing_expected):
            refs = len(table_references.get(table, []))
            logger.info(f"  • {table} ({refs} code references)")
        
        # Unexpected tables (exist but not in expected list)
        unexpected_existing = existing_tables - expected_tables
        logger.info(f"\n⚠️  UNEXPECTED TABLES ({len(unexpected_existing)}):")
        for table in sorted(unexpected_existing):
            count = row_counts.get(table, 0)
            refs = len(table_references.get(table, []))
            if refs > 0:
                logger.info(f"  • {table} ({count} rows, {refs} code references) - USED IN CODE")
            else:
                logger.info(f"  • {table} ({count} rows, 0 code references) - POTENTIALLY UNUSED")
        
        # Tables with no data
        empty_tables = [table for table, count in row_counts.items() if count == 0]
        logger.info(f"\n📭 EMPTY TABLES ({len(empty_tables)}):")
        for table in sorted(empty_tables):
            refs = len(table_references.get(table, []))
            logger.info(f"  • {table} ({refs} code references)")
        
        # Recommendations
        logger.info(f"\n🎯 RECOMMENDATIONS:")
        logger.info("=" * 60)
        
        if missing_expected:
            logger.info(f"\n1. CREATE MISSING TABLES ({len(missing_expected)}):")
            logger.info("   Run the missing_tables.sql script to create these tables.")
            for table in sorted(missing_expected):
                logger.info(f"   • {table}")
        
        unused_tables = [table for table in unexpected_existing if len(table_references.get(table, [])) == 0]
        if unused_tables:
            logger.info(f"\n2. CONSIDER REMOVING UNUSED TABLES ({len(unused_tables)}):")
            logger.info("   These tables exist but are not referenced in your code.")
            for table in sorted(unused_tables):
                count = row_counts.get(table, 0)
                logger.info(f"   • {table} ({count} rows) - No code references")
        
        if empty_tables:
            logger.info(f"\n3. EMPTY TABLES ({len(empty_tables)}):")
            logger.info("   These tables exist but have no data.")
            for table in sorted(empty_tables):
                logger.info(f"   • {table}")
        
        # Summary
        logger.info(f"\n📊 SUMMARY:")
        logger.info(f"  • Total tables in database: {len(existing_tables)}")
        logger.info(f"  • Expected tables: {len(expected_tables)}")
        logger.info(f"  • Missing expected tables: {len(missing_expected)}")
        logger.info(f"  • Unexpected tables: {len(unexpected_existing)}")
        logger.info(f"  • Empty tables: {len(empty_tables)}")
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Analysis failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
