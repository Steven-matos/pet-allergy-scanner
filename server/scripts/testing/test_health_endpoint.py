#!/usr/bin/env python3
"""
Quick test script to verify health endpoint responds fast
Tests that server starts and responds within acceptable timeframe
"""

import asyncio
import time
import sys
from pathlib import Path

# Add server directory to path
# Script is now in scripts/testing/, so go up two levels to get to server/
server_dir = Path(__file__).parent.parent.parent
sys.path.insert(0, str(server_dir))

async def test_health_endpoint():
    """
    Test that health endpoint is accessible and fast
    """
    try:
        print("=" * 60)
        print("Testing Health Endpoint Startup Time")
        print("=" * 60)
        
        # Import the app
        from main import app
        from fastapi.testclient import TestClient
        
        # Create test client
        start_time = time.time()
        print("Creating test client...")
        client = TestClient(app)
        
        # Test health endpoint
        print("Testing /health endpoint...")
        # Add proper host header to bypass TrustedHostMiddleware
        response = client.get("/health", headers={"Host": "localhost"})
        elapsed = time.time() - start_time

        # Test HEAD request (Railway uses HEAD pings)
        head_response = client.head("/health", headers={"Host": "localhost"})
        
        print("\n" + "=" * 60)
        print("RESULTS")
        print("=" * 60)
        print(f"Status Code: {response.status_code}")
        print(f"Response Text: {response.text}")
        
        if response.status_code == 200:
            print(f"Response JSON: {response.json()}")
        
        print(f"Time to respond: {elapsed:.2f}s")
        print(f"HEAD Status Code: {head_response.status_code}")
        
        # Verify response
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        
        data = response.json()
        assert data["status"] == "healthy", f"Expected 'healthy', got {data.get('status')}"
        assert "version" in data, "Missing 'version' in response"
        assert "service" in data, "Missing 'service' in response"
        
        # Check response time
        if head_response.status_code != 200:
            print("\n❌ HEAD request failed; healthcheck will fail on Railway")
            return False

        if elapsed > 5.0:
            print(f"\n⚠️  WARNING: Slow response ({elapsed:.2f}s)")
            print("   Health endpoint should respond in < 2 seconds")
            print("   This may cause Railway healthcheck failures")
        elif elapsed > 2.0:
            print(f"\n⚠️  CAUTION: Response time is borderline ({elapsed:.2f}s)")
            print("   Consider optimizing startup time")
        else:
            print(f"\n✅ PASS: Fast response time ({elapsed:.2f}s)")
        
        print("=" * 60)
        print("✅ All health checks passed!")
        print("=" * 60)
        
        return True
        
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ FAILED")
        print("=" * 60)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_root_endpoint():
    """
    Test root endpoint as well
    """
    try:
        from main import app
        from fastapi.testclient import TestClient
        
        print("\nTesting / endpoint...")
        client = TestClient(app)
        response = client.get("/", headers={"Host": "localhost"})
        
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        print(f"✅ Root endpoint: {data}")
        
    except Exception as e:
        print(f"❌ Root endpoint failed: {e}")
        return False
    
    return True

async def main():
    """Run all tests"""
    health_ok = await test_health_endpoint()
    root_ok = await test_root_endpoint()
    
    if health_ok and root_ok:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())

