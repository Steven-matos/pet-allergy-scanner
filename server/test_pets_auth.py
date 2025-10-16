#!/usr/bin/env python3
"""
Quick test to verify pets endpoint authentication is fixed
"""

import requests
import json

# Configuration
BASE_URL = "https://snifftest-api-production.up.railway.app"
EMAIL = "steven_matos@ymail.com"
PASSWORD = "Nissan@1990"

def test_pets_auth():
    """Test pets endpoint authentication"""
    print("🔐 Testing pets endpoint authentication...")
    
    # Step 1: Login
    login_data = {
        "email_or_username": EMAIL,
        "password": PASSWORD
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/api/v1/auth/login",
            json=login_data,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code != 200:
            print(f"   ❌ Login failed: {response.text}")
            return False
            
        token = response.json().get('access_token')
        print(f"   ✅ Login successful")
        
    except Exception as e:
        print(f"   ❌ Login error: {e}")
        return False
    
    # Step 2: Test both endpoints with same token
    print("🐕 Testing pets endpoint...")
    print(f"   Token length: {len(token)}")
    print(f"   Token preview: {token[:50]}...")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Test pets endpoint (without trailing slash)
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/pets",
            headers=headers,
            timeout=30
        )
        
        print(f"   Pets Status Code (no slash): {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Pets endpoint successful!")
            print(f"   Pets count: {len(data)}")
            return True
        else:
            print(f"   ❌ Pets endpoint failed (no slash): {response.text}")
            
    except Exception as e:
        print(f"   ❌ Pets endpoint error (no slash): {e}")
    
    # Test pets endpoint (with trailing slash)
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/pets/",
            headers=headers,
            timeout=30
        )
        
        print(f"   Pets Status Code (with slash): {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Pets endpoint successful!")
            print(f"   Pets count: {len(data)}")
            return True
        else:
            print(f"   ❌ Pets endpoint failed (with slash): {response.text}")
            
    except Exception as e:
        print(f"   ❌ Pets endpoint error (with slash): {e}")
        return False
    
    # Test food endpoint for comparison
    print("🍎 Testing food endpoint for comparison...")
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/foods/recent",
            headers=headers,
            timeout=30
        )
        
        print(f"   Food Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print(f"   ✅ Food endpoint successful!")
            return True
        else:
            print(f"   ❌ Food endpoint failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ Food endpoint error: {e}")
        return False

if __name__ == "__main__":
    success = test_pets_auth()
    if success:
        print("\n🎉 Pets authentication issue is FIXED!")
    else:
        print("\n⚠️ Pets authentication issue persists")
