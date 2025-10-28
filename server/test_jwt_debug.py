#!/usr/bin/env python3
"""
Debug JWT Token Validation
Test the actual JWT token from the server logs
"""

import jwt
import os
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Test token from the server logs (the one that's failing)
TEST_TOKEN = "eyJhbGciOiJIUzI1NiIsImtpZCI6InFQVkhBY1JuRnhjYnVYbkUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL294anl3cGVhcnJ1eHRueXNveXVmLnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiI3YTQ4MTAzMC1lNmZlLTQwZWEtYTgxZS0zNjE2ZjFiNzgyNjYiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzYxNjI3NDg5LCJpYXQiOjE3NjE2MjM4ODksImVtYWlsIjoic3RldmVuX21hdG9zQHltYWlsLmNvbSIsInBob25lIjoiIiwiYXBwX21ldGFkYXRhIjp7InByb3ZpZGVyIjoiZW1haWwiLCJwcm92aWRlcnMiOlsiZW1haWwiXX0sInVzZXJfbWV0YWRhdGEiOnsiZW1haWwiOiJzdGV2ZW5fbWF0b3NAeW1haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImZpcnN0X25hbWUiOiJTdGV2ZW4iLCJsYXN0X25hbWUiOiJNYXRvcyIsInBob25lX3ZlcmlmaWVkIjpmYWxzZSwicm9sZSI6ImZyZWUiLCJzdWIiOiI3YTQ4MTAzMC1lNmZlLTQwZWEtYTgxZS0zNjE2ZjFiNzgyNjYiLCJ1c2VybmFtZSI6ImNoaWNoaS1kYWQifSwicm9sZSI6ImF1dGhlbnRpY2F0ZWQiLCJhYWwiOiJhYWwxIiwiYW1yIjpbeyJtZXRob2QiOiJwYXNzd29yZCIsInRpbWVzdGFtcCI6MTc2MTYyMzAwNn1dLCJzZXNzaW9uX2lkIjoiMWY4MTEyMDEtNDRkOC00NjU2LWIyNTYtOTE0N2EyOTQ3ZTliIiwiaXNfYW5vbnltb3VzIjpmYWxzZX0.ImbZYVFGhI0my-OXR25sqVJuEadU7fYFt-lh7X6zqA8"

def debug_jwt_token():
    """Debug the JWT token validation"""
    
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
    supabase_url = os.getenv("SUPABASE_URL")
    
    print("🔍 JWT Token Debug Analysis")
    print("=" * 50)
    print(f"Supabase URL: {supabase_url}")
    print(f"JWT Secret: {jwt_secret[:20]}..." if jwt_secret else "❌ Not found")
    print(f"JWT Secret Length: {len(jwt_secret)}" if jwt_secret else "❌ Not found")
    print()
    
    # First, decode without verification to see the payload
    print("📋 Token Payload (unverified):")
    print("-" * 30)
    try:
        unverified_payload = jwt.decode(TEST_TOKEN, options={"verify_signature": False})
        for key, value in unverified_payload.items():
            print(f"  {key}: {value}")
        
        # Check expiration
        exp = unverified_payload.get("exp")
        if exp:
            current_time = int(time.time())
            if exp < current_time:
                print(f"\n⚠️  Token expired {current_time - exp} seconds ago")
            else:
                print(f"\n✅ Token expires in {exp - current_time} seconds")
        
        # Check issuer
        iss = unverified_payload.get("iss")
        expected_iss = f"{supabase_url}/auth/v1"
        print(f"\n🔍 Issuer Analysis:")
        print(f"  Expected: {expected_iss}")
        print(f"  Actual:   {iss}")
        print(f"  Match:    {'✅' if iss == expected_iss else '❌'}")
        
    except Exception as e:
        print(f"❌ Failed to decode token: {e}")
        return
    
    print("\n🔐 Signature Verification Test:")
    print("-" * 30)
    
    if not jwt_secret:
        print("❌ No JWT secret found")
        return
    
    # Test signature verification
    try:
        payload = jwt.decode(
            TEST_TOKEN, 
            jwt_secret, 
            algorithms=["HS256"],
            options={
                "verify_signature": True,
                "verify_exp": False,  # Don't verify expiration for testing
                "verify_aud": False,  # Don't verify audience
                "verify_iss": False   # Don't verify issuer
            }
        )
        print("✅ Signature verification successful!")
        print(f"  User ID: {payload.get('sub')}")
        print(f"  Email: {payload.get('email')}")
        
    except jwt.InvalidSignatureError:
        print("❌ Invalid signature - JWT secret is incorrect")
    except jwt.InvalidTokenError as e:
        print(f"❌ Invalid token: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    debug_jwt_token()
