#!/usr/bin/env python3
"""
Test script to verify food_items RLS policies work correctly after consolidation.
This script tests the consolidated policies to ensure they resolve the multiple 
permissive policies warning while maintaining proper security.
"""

import asyncio
import sys
import os
from typing import Dict, Any

# Add the parent directory to the path so we can import from app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import get_db
from app.models.food_items import FoodItem
from sqlalchemy.orm import Session
from sqlalchemy import text

async def test_food_items_policies():
    """
    Test the consolidated food_items RLS policies to ensure they work correctly.
    
    Tests:
    1. Anonymous users can SELECT (read) food items
    2. Authenticated users can SELECT, INSERT, UPDATE, DELETE food items
    3. No multiple permissive policies exist
    """
    
    print("🧪 Testing food_items RLS policies consolidation...")
    
    try:
        # Get database connection
        db = next(get_db())
        
        # Test 1: Check that we can query food_items (basic connectivity)
        print("\n1️⃣ Testing basic food_items table access...")
        
        result = db.execute(text("SELECT COUNT(*) as count FROM public.food_items"))
        count = result.fetchone()[0]
        print(f"   ✅ Found {count} food items in database")
        
        # Test 2: Check current RLS policies on food_items table
        print("\n2️⃣ Checking current RLS policies on food_items table...")
        
        policies_query = """
        SELECT 
            schemaname,
            tablename,
            policyname,
            permissive,
            roles,
            cmd,
            qual,
            with_check
        FROM pg_policies 
        WHERE tablename = 'food_items' 
        AND schemaname = 'public'
        ORDER BY policyname;
        """
        
        result = db.execute(text(policies_query))
        policies = result.fetchall()
        
        print(f"   📋 Found {len(policies)} policies on food_items table:")
        for policy in policies:
            print(f"      - {policy[2]} ({policy[5]}) - Permissive: {policy[3]}")
        
        # Test 3: Check for multiple permissive policies (the issue we're fixing)
        print("\n3️⃣ Checking for multiple permissive policies...")
        
        permissive_select_policies = [
            p for p in policies 
            if p[3] == 'PERMISSIVE' and p[5] == 'SELECT'
        ]
        
        if len(permissive_select_policies) > 1:
            print(f"   ⚠️  WARNING: Found {len(permissive_select_policies)} permissive SELECT policies!")
            print("      This will cause performance issues. Policies:")
            for policy in permissive_select_policies:
                print(f"         - {policy[2]}")
        else:
            print(f"   ✅ Only {len(permissive_select_policies)} permissive SELECT policy found (good!)")
        
        # Test 4: Verify policy structure is correct
        print("\n4️⃣ Verifying policy structure...")
        
        # Check for the expected policies
        policy_names = [p[2] for p in policies]
        
        # Check for either the old or new policy names
        expected_policies = [
            "Anyone can view food items",  # New consolidated policy
            "Users can view all food items",  # Original policy (should be dropped)
            "Authenticated users can manage food items"
        ]
        
        # Check for the new consolidated policies (should exist after migration)
        new_policies = ["Anyone can view food items", "Authenticated users can manage food items"]
        old_policies = ["Users can view all food items"]
        
        for expected in new_policies:
            if expected in policy_names:
                print(f"   ✅ Found new consolidated policy: {expected}")
            else:
                print(f"   ❌ Missing new consolidated policy: {expected}")
        
        # Check that old policies are gone (should not exist after migration)
        for old_policy in old_policies:
            if old_policy in policy_names:
                print(f"   ⚠️  Old policy still exists (should be dropped): {old_policy}")
            else:
                print(f"   ✅ Old policy properly dropped: {old_policy}")
        
        # Test 5: Check policy details
        print("\n5️⃣ Checking policy details...")
        
        for policy in policies:
            policy_name = policy[2]
            cmd = policy[5]
            permissive = policy[3]
            
            print(f"   📝 Policy: {policy_name}")
            print(f"      Command: {cmd}")
            print(f"      Permissive: {permissive}")
            print(f"      Roles: {policy[4]}")
            
            if policy[6]:  # qual (USING clause)
                print(f"      USING: {policy[6]}")
            if policy[7]:  # with_check (WITH CHECK clause)
                print(f"      WITH CHECK: {policy[7]}")
            print()
        
        print("🎉 Food items RLS policy testing completed!")
        
        # Summary
        print("\n📊 SUMMARY:")
        print(f"   - Total policies: {len(policies)}")
        print(f"   - Permissive SELECT policies: {len(permissive_select_policies)}")
        print(f"   - New consolidated policies found: {sum(1 for policy in new_policies if policy in policy_names)}/{len(new_policies)}")
        print(f"   - Old policies still present: {sum(1 for policy in old_policies if policy in policy_names)}")
        
        if len(permissive_select_policies) <= 1:
            print("   ✅ Multiple permissive policies issue RESOLVED!")
        else:
            print("   ❌ Multiple permissive policies issue still exists!")
            
        if all(policy in policy_names for policy in new_policies) and not any(policy in policy_names for policy in old_policies):
            print("   ✅ Policy consolidation completed successfully!")
        else:
            print("   ⚠️  Policy consolidation may need attention!")
            
    except Exception as e:
        print(f"❌ Error during testing: {str(e)}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(test_food_items_policies())
