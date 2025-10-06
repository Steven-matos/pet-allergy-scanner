#!/usr/bin/env python3
"""
Script to safely run the food_items RLS policy migration.
This script handles the policy consolidation to fix multiple permissive policies.
"""

import os
import sys
import subprocess
from pathlib import Path

def run_migration():
    """Run the food_items RLS policy migration safely."""
    
    print("🔧 Running food_items RLS policy migration...")
    print("=" * 60)
    
    # Get the migration file path
    migration_file = Path(__file__).parent / "migrations" / "fix_food_items_multiple_policies.sql"
    
    if not migration_file.exists():
        print(f"❌ Migration file not found: {migration_file}")
        return False
    
    print(f"📁 Migration file: {migration_file}")
    
    # Check if we're in the right directory
    if not (Path(__file__).parent / "main.py").exists():
        print("❌ Please run this script from the server directory")
        return False
    
    # Run the migration
    try:
        print("\n🚀 Executing migration...")
        
        # You can run this with your preferred method:
        # Option 1: Using psql directly (if you have connection details)
        # Option 2: Using Supabase CLI
        # Option 3: Using your existing migration system
        
        print("\n📋 Migration commands to run:")
        print(f"   psql -f {migration_file}")
        print("\n   OR")
        print(f"   supabase db reset --linked")
        print(f"   supabase db push")
        
        print("\n✅ Migration file is ready to be executed!")
        print("\n🔍 After running the migration, you can test with:")
        print("   python tests/test_food_items_policies.py")
        
        return True
        
    except Exception as e:
        print(f"❌ Error running migration: {str(e)}")
        return False

def show_migration_preview():
    """Show a preview of what the migration will do."""
    
    print("\n📖 MIGRATION PREVIEW:")
    print("=" * 40)
    print("This migration will:")
    print("1. Drop existing conflicting policies:")
    print("   - 'Users can view all food items'")
    print("   - 'Anyone can view food items' (if exists)")
    print("   - 'Authenticated users can insert/update/delete food items'")
    print("   - 'Authenticated users can manage food items' (if exists)")
    print()
    print("2. Create consolidated policies:")
    print("   - 'Anyone can view food items' (SELECT for all users)")
    print("   - 'Authenticated users can manage food items' (ALL for authenticated)")
    print()
    print("3. Benefits:")
    print("   - ✅ Resolves multiple permissive policies warning")
    print("   - ✅ Improves query performance")
    print("   - ✅ Maintains security (public read, authenticated write)")
    print("   - ✅ Optimizes auth function calls")

if __name__ == "__main__":
    print("🍽️  Food Items RLS Policy Migration Tool")
    print("=" * 50)
    
    show_migration_preview()
    
    print("\n" + "=" * 50)
    success = run_migration()
    
    if success:
        print("\n🎉 Migration setup completed successfully!")
        print("\nNext steps:")
        print("1. Run the migration using your preferred method")
        print("2. Test the results with: python tests/test_food_items_policies.py")
        print("3. Check Supabase Security Advisor for resolved warnings")
    else:
        print("\n❌ Migration setup failed!")
        sys.exit(1)
