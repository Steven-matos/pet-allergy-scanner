#!/usr/bin/env python3
"""
Quick configuration test script for Railway deployment

This script checks if your environment variables are properly configured
Run this locally before deploying to Railway
"""

import sys
import os

def test_config():
    """Test if configuration can be loaded"""
    print("🔍 Testing Railway Configuration...\n")
    
    errors = []
    warnings = []
    
    # Test required environment variables
    required_vars = [
        "SUPABASE_URL",
        "SUPABASE_KEY", 
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_JWT_SECRET",
        "SECRET_KEY",
        "DATABASE_URL",
    ]
    
    print("📋 Checking Required Environment Variables:")
    for var in required_vars:
        value = os.getenv(var)
        if not value:
            errors.append(f"❌ Missing required variable: {var}")
            print(f"   ❌ {var}: NOT SET")
        else:
            print(f"   ✅ {var}: Set ({len(value)} chars)")
    
    # Check SECRET_KEY length
    secret_key = os.getenv("SECRET_KEY", "")
    if secret_key and len(secret_key) < 32:
        errors.append(f"❌ SECRET_KEY too short: {len(secret_key)} chars (need 32+)")
    
    # Test optional variables
    optional_vars = [
        "ENVIRONMENT",
        "APNS_KEY_ID",
        "APNS_TEAM_ID",
        "APNS_BUNDLE_ID",
        "ALLOWED_ORIGINS_STR",
    ]
    
    print("\n📋 Checking Optional Variables:")
    for var in optional_vars:
        value = os.getenv(var)
        if value:
            print(f"   ✅ {var}: Set")
        else:
            print(f"   ⚠️  {var}: Not set (optional)")
            warnings.append(f"Optional: {var}")
    
    # Try to load settings
    print("\n🔧 Testing Settings Module...")
    try:
        from app.core.config import settings
        print("   ✅ Settings loaded successfully")
        print(f"   ✅ Environment: {settings.environment}")
        print(f"   ✅ API Version: {settings.api_version}")
        print(f"   ✅ Debug Mode: {settings.debug}")
        print(f"   ✅ Allowed Hosts: {len(settings.allowed_hosts)} hosts")
    except Exception as e:
        errors.append(f"❌ Failed to load settings: {e}")
        print(f"   ❌ Error: {e}")
    
    # Test database connection (optional)
    print("\n🗄️  Testing Database Connection...")
    try:
        from app.database import create_client
        from app.core.config import settings
        
        client = create_client(settings.supabase_url, settings.supabase_key)
        result = client.table("users").select("id").limit(1).execute()
        print("   ✅ Database connection successful")
    except Exception as e:
        warnings.append(f"Database connection failed: {e}")
        print(f"   ⚠️  Database connection failed (app will start anyway)")
        print(f"      Error: {e}")
    
    # Summary
    print("\n" + "="*60)
    print("📊 Configuration Test Summary")
    print("="*60)
    
    if errors:
        print("\n❌ ERRORS (must fix before deploying):")
        for error in errors:
            print(f"   {error}")
    else:
        print("\n✅ No critical errors found!")
    
    if warnings:
        print("\n⚠️  WARNINGS (app will work but features may be limited):")
        for warning in warnings:
            print(f"   {warning}")
    
    print("\n" + "="*60)
    
    if errors:
        print("\n❌ Configuration test FAILED")
        print("   Fix errors above before deploying to Railway")
        return False
    else:
        print("\n✅ Configuration test PASSED")
        print("   Ready to deploy to Railway!")
        return True

def generate_secret_key():
    """Generate a secure secret key"""
    import secrets
    key = secrets.token_urlsafe(32)
    print(f"\n🔑 Generated SECRET_KEY:\n{key}")
    print("\nAdd this to Railway environment variables:")
    print(f"SECRET_KEY={key}")

if __name__ == "__main__":
    if "--generate-key" in sys.argv:
        generate_secret_key()
        sys.exit(0)
    
    success = test_config()
    sys.exit(0 if success else 1)

