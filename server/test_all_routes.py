#!/usr/bin/env python3
"""
Comprehensive test for all router authentication fixes
Tests both trailing slash and type annotation fixes
"""

import requests
import json
import time

# Configuration
BASE_URL = "https://snifftest-api-production.up.railway.app"
EMAIL = "steven_matos@ymail.com"
PASSWORD = "Nissan@1990"

def get_auth_token():
    """Get authentication token"""
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
        
        if response.status_code == 200:
            return response.json().get('access_token')
        else:
            print(f"   ❌ Login failed: {response.text}")
            return None
            
    except Exception as e:
        print(f"   ❌ Login error: {e}")
        return None

def test_endpoint(token, endpoint_name, url_with_slash, url_without_slash=None):
    """Test an endpoint with authentication"""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    results = {}
    
    # Test with trailing slash
    try:
        response = requests.get(url_with_slash, headers=headers, timeout=30)
        results['with_slash'] = {
            'status': response.status_code,
            'success': response.status_code == 200,
            'error': response.text if response.status_code != 200 else None
        }
    except Exception as e:
        results['with_slash'] = {
            'status': 'ERROR',
            'success': False,
            'error': str(e)
        }
    
    # Test without trailing slash (if different URL provided)
    if url_without_slash and url_without_slash != url_with_slash:
        try:
            response = requests.get(url_without_slash, headers=headers, timeout=30)
            results['without_slash'] = {
                'status': response.status_code,
                'success': response.status_code == 200,
                'error': response.text if response.status_code != 200 else None
            }
        except Exception as e:
            results['without_slash'] = {
                'status': 'ERROR',
                'success': False,
                'error': str(e)
            }
    
    return results

def main():
    """Test all router fixes"""
    print("🧪 Testing All Router Authentication Fixes")
    print("=" * 60)
    
    # Get auth token
    print("🔐 Getting authentication token...")
    token = get_auth_token()
    
    if not token:
        print("❌ Cannot proceed without authentication token")
        return
    
    print(f"✅ Token obtained (length: {len(token)})")
    print()
    
    # Define endpoints to test
    endpoints = [
        {
            'name': 'Pets',
            'with_slash': f"{BASE_URL}/api/v1/pets/",
            'without_slash': f"{BASE_URL}/api/v1/pets"
        },
        {
            'name': 'Scans',
            'with_slash': f"{BASE_URL}/api/v1/scans/",
            'without_slash': f"{BASE_URL}/api/v1/scans"
        },
        {
            'name': 'Ingredients',
            'with_slash': f"{BASE_URL}/api/v1/ingredients/",
            'without_slash': f"{BASE_URL}/api/v1/ingredients"
        },
        {
            'name': 'Food Recent',
            'with_slash': f"{BASE_URL}/api/v1/foods/recent",
            'without_slash': None  # This endpoint doesn't have trailing slash issue
        }
    ]
    
    # Test all endpoints
    results = {}
    for endpoint in endpoints:
        print(f"🔍 Testing {endpoint['name']} endpoint...")
        results[endpoint['name']] = test_endpoint(
            token, 
            endpoint['name'], 
            endpoint['with_slash'], 
            endpoint['without_slash']
        )
        
        # Print results
        if endpoint['without_slash']:
            with_slash_success = results[endpoint['name']]['with_slash']['success']
            without_slash_success = results[endpoint['name']]['without_slash']['success']
            
            print(f"   With slash: {'✅' if with_slash_success else '❌'} "
                  f"({results[endpoint['name']]['with_slash']['status']})")
            print(f"   Without slash: {'✅' if without_slash_success else '❌'} "
                  f"({results[endpoint['name']]['without_slash']['status']})")
            
            if not without_slash_success and results[endpoint['name']]['without_slash']['error']:
                error_msg = results[endpoint['name']]['without_slash']['error'][:100]
                print(f"   Error: {error_msg}...")
        else:
            with_slash_success = results[endpoint['name']]['with_slash']['success']
            print(f"   Result: {'✅' if with_slash_success else '❌'} "
                  f"({results[endpoint['name']]['with_slash']['status']})")
        
        print()
    
    # Summary
    print("📊 SUMMARY")
    print("=" * 60)
    
    all_fixed = True
    for name, result in results.items():
        if 'without_slash' in result:
            both_work = (result['with_slash']['success'] and 
                        result['without_slash']['success'])
            status = "✅ FIXED" if both_work else "❌ NEEDS WORK"
            if not both_work:
                all_fixed = False
            print(f"{name:12} {status}")
        else:
            works = result['with_slash']['success']
            status = "✅ WORKING" if works else "❌ BROKEN"
            if not works:
                all_fixed = False
            print(f"{name:12} {status}")
    
    print()
    if all_fixed:
        print("🎉 ALL ROUTER FIXES WORKING PERFECTLY!")
        print("   - Trailing slash issues resolved")
        print("   - Type annotation issues resolved")
        print("   - Authentication working across all endpoints")
    else:
        print("⚠️ Some endpoints still need attention")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
