#!/usr/bin/env python3
"""
Test food management router trailing slash fix
"""

import requests
import json
import time

BASE_URL = "https://snifftest-api-production.up.railway.app"
EMAIL = "steven_matos@ymail.com"
PASSWORD = "Nissan@1990"

def test_food_endpoints():
    """Test both food endpoint URL formats"""
    
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
    
    # Test data
    food_data = {
        "name": f"Test Food - Trailing Slash Test {int(time.time())}",
        "brand": "Test Brand",
        "barcode": f"1234567890{int(time.time())}",
        "category": "Test Category",
        "nutritional_info": {
            "calories_per_100g": 350,
            "protein_per_100g": 25.0,
            "fat_per_100g": 15.0,
            "carbohydrates_per_100g": 45.0,
            "fiber_per_100g": 5.0,
            "ingredients": ["Test Ingredient 1", "Test Ingredient 2"],
            "source": "trailing_slash_test",
            "external_id": f"test_{int(time.time())}"
        }
    }
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Test without trailing slash (what iOS app uses)
    print("\n🍎 Testing food creation WITHOUT trailing slash...")
    try:
        response = requests.post(
            f"{BASE_URL}/api/v1/foods",  # No trailing slash
            json=food_data,
            headers=headers,
            timeout=30
        )
        
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ SUCCESS! Food created with ID: {data.get('id', 'N/A')}")
            food_id_1 = data.get('id')
        else:
            print(f"   ❌ FAILED: {response.text}")
            food_id_1 = None
            
    except Exception as e:
        print(f"   ❌ ERROR: {e}")
        food_id_1 = None
    
    # Test with trailing slash
    print("\n🍎 Testing food creation WITH trailing slash...")
    try:
        food_data["name"] = f"Test Food - With Slash {int(time.time())}"
        food_data["barcode"] = f"1234567891{int(time.time())}"
        
        response = requests.post(
            f"{BASE_URL}/api/v1/foods/",  # With trailing slash
            json=food_data,
            headers=headers,
            timeout=30
        )
        
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ SUCCESS! Food created with ID: {data.get('id', 'N/A')}")
            food_id_2 = data.get('id')
        else:
            print(f"   ❌ FAILED: {response.text}")
            food_id_2 = None
            
    except Exception as e:
        print(f"   ❌ ERROR: {e}")
        food_id_2 = None
    
    # Summary
    print(f"\n📊 SUMMARY:")
    print(f"   Without trailing slash: {'✅ WORKING' if food_id_1 else '❌ FAILED'}")
    print(f"   With trailing slash: {'✅ WORKING' if food_id_2 else '❌ FAILED'}")
    
    if food_id_1 and food_id_2:
        print(f"\n🎉 BOTH URL FORMATS WORK PERFECTLY!")
        print(f"   - iOS app will work with /api/v1/foods")
        print(f"   - Other clients can use /api/v1/foods/")
    elif food_id_1:
        print(f"\n✅ iOS app format works (/api/v1/foods)")
    elif food_id_2:
        print(f"\n✅ Trailing slash format works (/api/v1/foods/)")
    else:
        print(f"\n❌ Both formats failed - need to investigate")

if __name__ == "__main__":
    test_food_endpoints()
