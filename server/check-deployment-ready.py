#!/usr/bin/env python3
"""
Deployment Readiness Checker
Validates that all required files and configurations are present for Railway deployment
"""

import os
import sys
from pathlib import Path

def check_file_exists(filepath: str, required: bool = True) -> bool:
    """Check if a file exists"""
    exists = Path(filepath).exists()
    status = "✅" if exists else ("❌" if required else "⚠️")
    req_text = "(required)" if required else "(optional)"
    print(f"{status} {filepath} {req_text}")
    return exists

def check_env_variable(var_name: str, required: bool = True) -> bool:
    """Check if environment variable is set in .env file"""
    if not Path(".env").exists():
        return False
    
    with open(".env", "r") as f:
        content = f.read()
        # Simple check - not parsing the file properly
        exists = var_name in content and not content.split(var_name)[1].split('\n')[0].strip() == "="
        status = "✅" if exists else ("❌" if required else "⚠️")
        req_text = "(required)" if required else "(optional)"
        print(f"{status} {var_name} {req_text}")
        return exists

def main():
    print("=" * 60)
    print("🚂 Railway Deployment Readiness Check")
    print("=" * 60)
    print()
    
    all_good = True
    
    # Check required files
    print("📁 Checking Required Files:")
    print("-" * 60)
    all_good &= check_file_exists("requirements.txt")
    all_good &= check_file_exists("main.py")
    all_good &= check_file_exists("Procfile")
    all_good &= check_file_exists("railway.toml")
    all_good &= check_file_exists(".env")
    all_good &= check_file_exists("AuthKey_KJ9V6V9G59.p8")
    print()
    
    # Check optional files
    print("📄 Checking Optional Files:")
    print("-" * 60)
    check_file_exists("README.md", required=False)
    check_file_exists("RAILWAY_DEPLOYMENT.md", required=False)
    check_file_exists(".gitignore", required=False)
    check_file_exists(".railwayignore", required=False)
    print()
    
    # Check environment variables
    if Path(".env").exists():
        print("🔐 Checking Environment Variables:")
        print("-" * 60)
        
        # Supabase
        all_good &= check_env_variable("SUPABASE_URL")
        all_good &= check_env_variable("SUPABASE_KEY")
        all_good &= check_env_variable("SUPABASE_SERVICE_ROLE_KEY")
        all_good &= check_env_variable("SUPABASE_JWT_SECRET")
        all_good &= check_env_variable("DATABASE_URL")
        
        # Security
        all_good &= check_env_variable("SECRET_KEY")
        all_good &= check_env_variable("ALGORITHM")
        
        # APNs
        all_good &= check_env_variable("APNS_URL")
        all_good &= check_env_variable("APNS_KEY_ID")
        all_good &= check_env_variable("APNS_TEAM_ID")
        all_good &= check_env_variable("APNS_BUNDLE_ID")
        all_good &= check_env_variable("APNS_PRIVATE_KEY")
        
        # Optional but recommended
        check_env_variable("ALLOWED_ORIGINS_STR", required=False)
        check_env_variable("ALLOWED_HOSTS_STR", required=False)
        print()
    else:
        print("❌ .env file not found!")
        print()
        all_good = False
    
    # Check Python version
    print("🐍 Checking Python Version:")
    print("-" * 60)
    python_version = sys.version_info
    if python_version >= (3, 11):
        print(f"✅ Python {python_version.major}.{python_version.minor}.{python_version.micro}")
    else:
        print(f"⚠️ Python {python_version.major}.{python_version.minor}.{python_version.micro} (3.11+ recommended)")
    print()
    
    # Final status
    print("=" * 60)
    if all_good:
        print("✅ All checks passed! Ready for Railway deployment.")
        print()
        print("Next steps:")
        print("1. railway login")
        print("2. railway init")
        print("3. ./railway-setup.sh (or set variables manually)")
        print("4. railway up")
    else:
        print("❌ Some checks failed. Please fix the issues above.")
        print()
        print("Refer to RAILWAY_DEPLOYMENT.md for detailed instructions.")
    print("=" * 60)
    
    return 0 if all_good else 1

if __name__ == "__main__":
    sys.exit(main())
