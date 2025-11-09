#!/usr/bin/env python3
"""
Test RLS fix for food creation
"""

import requests
import json
import time

import os

BASE_URL = os.getenv("TEST_BASE_URL", "https://snifftest-api-production.up.railway.app")
EMAIL = os.getenv("TEST_EMAIL")
PASSWORD = os.getenv("TEST_PASSWORD")

def test_food_creation_rls_fix():
    """Test that food creation now works without RLS errors
    
    Required environment variables:
    - TEST_EMAIL: Test user email
    - TEST_PASSWORD: Test user password
    """
    
    # Check for required credentials
    if not EMAIL or not PASSWORD:
        print("❌ ERROR: TEST_EMAIL and TEST_PASSWORD environment variables must be set")
        print("   Set them with: export TEST_EMAIL='your@email.com' TEST_PASSWORD='your_password'")
        return
    
    # Login
    print("🔐 Logging in...")
    login_data = {
        "email_or_username": EMAIL,
        "password": PASSWORD
    }
    
    response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        json=login_data,
        headers={"Content-Type": "application/json"},
        timeout=30
    )
    
    if response.status_code != 200:
        print(f"❌ Login failed: {response.text}")
        return
    
    token = response.json().get('access_token')
    print(f"✅ Login successful")
    
    # Test food creation with the same data that was failing
    food_data = {
        "name": "CHEESY PEASY SOFT BAKES - RLS Test",
        "brand": "BARK",
        "barcode": f"0840134680217_{int(time.time())}",
        "category": "Treats",
        "nutritional_info": {
            "calories_per_100g": 301.3,
            "protein_per_100g": 25.0,
            "fat_per_100g": 15.0,
            "carbohydrates_per_100g": 45.0,
            "fiber_per_100g": 5.0,
            "ingredients": [
                "Chicken",
                "Rice Flour",
                "Dried Cheese",
                "Natural Flavors"
            ],
            "source": "user_upload",
            "external_id": f"0840134680217_{int(time.time())}"
        }
    }
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    print("\n🍎 Testing food creation with RLS fix...")
    try:
        response = requests.post(
            f"{BASE_URL}/api/v1/foods",
            json=food_data,
            headers=headers,
            timeout=30
        )
        
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ SUCCESS! Food created with ID: {data.get('id', 'N/A')}")
            print(f"   Name: {data.get('name', 'N/A')}")
            print(f"   Brand: {data.get('brand', 'N/A')}")
            print(f"   Created At: {data.get('created_at', 'N/A')}")
            return True
        else:
            print(f"   ❌ FAILED: {response.text}")
            
            # Check if it's still an RLS error
            try:
                error_data = response.json()
                error_msg = error_data.get('error', '')
                if 'row-level security policy' in error_msg.lower():
                    print(f"   🔍 Still getting RLS error - fix may not be deployed yet")
                else:
                    print(f"   🔍 Different error - not RLS related")
            except:
                pass
                
            return False
            
    except Exception as e:
        print(f"   ❌ ERROR: {e}")
        return False

if __name__ == "__main__":
    success = test_food_creation_rls_fix()
    
    if success:
        print(f"\n🎉 RLS FIX SUCCESSFUL!")
        print(f"   - Food creation now works without RLS errors")
        print(f"   - iOS app should be able to upload food items")
    else:
        print(f"\n⚠️ RLS fix may need more time to deploy or additional changes")
    
    print("=" * 60)
