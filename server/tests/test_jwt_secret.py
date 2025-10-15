#!/usr/bin/env python3
"""
Test JWT Secret Configuration
Verifies that the SUPABASE_JWT_SECRET can decode a Supabase JWT token
"""

import sys
import jwt
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Test token from iOS app logs (replace with actual token from your logs)
TEST_TOKEN = "eyJhbGciOiJIUzI1NiIsImt...YOUR_ACTUAL_TOKEN_HERE..."

def test_jwt_secret():
    """Test if the JWT secret can decode the token"""
    
    supabase_url = os.getenv("SUPABASE_URL")
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
    
    if not jwt_secret:
        print("❌ SUPABASE_JWT_SECRET not found in environment")
        return False
    
    print(f"✅ Found SUPABASE_JWT_SECRET: {jwt_secret[:20]}...")
    print(f"✅ Length: {len(jwt_secret)} characters")
    print(f"✅ Supabase URL: {supabase_url}")
    print()
    
    # Check for common issues
    if jwt_secret.startswith(" ") or jwt_secret.endswith(" "):
        print("⚠️  WARNING: JWT secret has leading/trailing whitespace!")
        jwt_secret = jwt_secret.strip()
        print(f"   Trimmed to: {jwt_secret[:20]}...")
    
    if "\n" in jwt_secret or "\r" in jwt_secret:
        print("⚠️  WARNING: JWT secret contains newline characters!")
        jwt_secret = jwt_secret.replace("\n", "").replace("\r", "")
        print(f"   Cleaned to: {jwt_secret[:20]}...")
    
    print()
    print("Testing JWT decoding...")
    print("-" * 50)
    
    try:
        # Try to decode the test token
        payload = jwt.decode(
            TEST_TOKEN,
            jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
            issuer=f"{supabase_url}/auth/v1",
            options={"verify_signature": True}
        )
        
        print("✅ JWT DECODED SUCCESSFULLY!")
        print(f"   User ID: {payload.get('sub')}")
        print(f"   Email: {payload.get('email')}")
        print(f"   Role: {payload.get('role')}")
        print(f"   Issuer: {payload.get('iss')}")
        return True
        
    except jwt.InvalidSignatureError:
        print("❌ INVALID SIGNATURE")
        print("   The JWT secret does not match the one used to sign the token")
        print("   Check that SUPABASE_JWT_SECRET matches your Supabase project settings")
        return False
        
    except jwt.ExpiredSignatureError:
        print("⚠️  TOKEN EXPIRED")
        print("   The token is valid but has expired. Get a fresh token and try again.")
        return False
        
    except jwt.InvalidIssuerError:
        print("❌ INVALID ISSUER")
        print(f"   Expected: {supabase_url}/auth/v1")
        print(f"   Got: {payload.get('iss') if 'payload' in locals() else 'unknown'}")
        return False
        
    except jwt.InvalidAudienceError:
        print("❌ INVALID AUDIENCE")
        print("   Expected audience: 'authenticated'")
        return False
        
    except Exception as e:
        print(f"❌ UNEXPECTED ERROR: {type(e).__name__}")
        print(f"   {str(e)}")
        return False

if __name__ == "__main__":
    print("=" * 50)
    print("JWT Secret Validation Test")
    print("=" * 50)
    print()
    
    if TEST_TOKEN == "eyJhbGciOiJIUzI1NiIsImt...YOUR_ACTUAL_TOKEN_HERE...":
        print("⚠️  Please replace TEST_TOKEN with an actual JWT token from your iOS logs")
        print()
        print("To get a token:")
        print("1. Run your iOS app")
        print("2. Try to create a food item")
        print("3. Copy the full JWT token from the iOS console logs")
        print("4. Paste it into this script as TEST_TOKEN")
        print()
        sys.exit(1)
    
    success = test_jwt_secret()
    sys.exit(0 if success else 1)

