#!/usr/bin/env python3
"""
Simple test script to debug authentication issues
"""

import requests
import json

# Test token (this is a fake token for testing)
test_token = "eyJhbGciOiJIUzI1NiIsImt5cCI6IkpXVCIsImtpZCI6InFQVkhBY1JuRnhjYnVYbkUifQ.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzYwNTczMDQ0LCJpYXQiOjE3NjA1Njk0NDQsImlzcyI6Imh0dHBzOi8vb3hqeXdwZWFycnV4dG55c295dWYuc3VwYWJhc2UuY28vYXV0aC92MSIsInN1YiI6IjdhNDgxMDMwLWU2ZmUtNDBlYS1hODFlLTM2MTZmMWI3ODI2NiIsImVtYWlsIjoidGVzdEBleGFtcGxlLmNvbSIsInBob25lIjoiIiwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTc2MDU2OTQ0NH1dLCJzZXNzaW9uX2lkIjoiYTA5M2U2NWQtNGM3NS00MWZlLWJmZGItMmY0YjE1NTk5ZWEyIiwiaXNfYW5vbnltb3VzIjpmYWxzZX0.example"

base_url = "https://snifftest-api-production.up.railway.app"

def test_debug_headers():
    """Test the debug headers endpoint"""
    print("Testing debug headers endpoint...")
    
    headers = {
        "Authorization": f"Bearer {test_token}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(f"{base_url}/debug/headers", headers=headers, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_food_creation():
    """Test food creation endpoint"""
    print("\nTesting food creation endpoint...")
    
    headers = {
        "Authorization": f"Bearer {test_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "name": "Test Food Item",
        "brand": "Test Brand"
    }
    
    try:
        response = requests.post(
            f"{base_url}/api/v1/foods", 
            headers=headers, 
            json=data,
            timeout=30
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_health_check():
    """Test health check endpoint"""
    print("\nTesting health check endpoint...")
    
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    print("Starting authentication tests...")
    
    # Test health check first
    health_ok = test_health_check()
    
    # Test debug headers
    debug_ok = test_debug_headers()
    
    # Test food creation
    food_ok = test_food_creation()
    
    print(f"\nResults:")
    print(f"Health Check: {'✅' if health_ok else '❌'}")
    print(f"Debug Headers: {'✅' if debug_ok else '❌'}")
    print(f"Food Creation: {'✅' if food_ok else '❌'}")
