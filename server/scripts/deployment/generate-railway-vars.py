#!/usr/bin/env python3
"""
Railway Variables Generator
Generates Railway CLI commands from your .env file for easy copy-paste
"""

import os
from pathlib import Path

def read_env_file():
    """Read .env file and parse variables"""
    env_vars = {}
    
    if not Path(".env").exists():
        print("❌ .env file not found!")
        return None
    
    with open(".env", "r") as f:
        lines = f.readlines()
    
    current_key = None
    current_value = []
    in_multiline = False
    
    for line in lines:
        line = line.rstrip('\n')
        
        # Skip comments and empty lines
        if line.startswith('#') or not line.strip():
            continue
        
        # Check if line starts a new variable
        if '=' in line and not in_multiline:
            # Save previous variable if exists
            if current_key:
                env_vars[current_key] = ''.join(current_value)
            
            # Parse new variable
            key, value = line.split('=', 1)
            current_key = key.strip()
            
            # Remove quotes if present
            value = value.strip()
            if value.startswith('"'):
                value = value[1:]
                if value.endswith('"'):
                    value = value[:-1]
                    in_multiline = False
                else:
                    in_multiline = True
            
            current_value = [value]
        elif in_multiline:
            # Continue multi-line value
            if line.endswith('"'):
                current_value.append(line[:-1])
                in_multiline = False
            else:
                current_value.append(line)
    
    # Save last variable
    if current_key:
        env_vars[current_key] = ''.join(current_value)
    
    return env_vars

def generate_commands(env_vars):
    """Generate Railway CLI commands"""
    
    # Variables to set from .env
    keys_to_set = [
        'SUPABASE_URL',
        'SUPABASE_KEY',
        'SUPABASE_SERVICE_ROLE_KEY',
        'SUPABASE_JWT_SECRET',
        'DATABASE_URL',
        'SECRET_KEY',
        'ALGORITHM',
        'ACCESS_TOKEN_EXPIRE_MINUTES',
        'RATE_LIMIT_PER_MINUTE',
        'AUTH_RATE_LIMIT_PER_MINUTE',
        'DATABASE_POOL_SIZE',
        'DATABASE_TIMEOUT',
        'MAX_FILE_SIZE_MB',
        'MAX_REQUEST_SIZE_MB',
        'ENABLE_MFA',
        'ENABLE_AUDIT_LOGGING',
        'SESSION_TIMEOUT_MINUTES',
        'DATA_RETENTION_DAYS',
        'ENABLE_DATA_EXPORT',
        'ENABLE_DATA_DELETION',
        'APNS_KEY_ID',
        'APNS_TEAM_ID',
        'APNS_BUNDLE_ID',
        'APNS_PRIVATE_KEY',
    ]
    
    commands = []
    
    print("=" * 80)
    print("🚂 Railway Environment Variables - Copy & Paste Commands")
    print("=" * 80)
    print()
    print("📋 OPTION 1: Use Railway CLI")
    print("-" * 80)
    print()
    
    for key in keys_to_set:
        if key in env_vars:
            value = env_vars[key].replace('"', '\\"')  # Escape quotes
            # Use the format that works with newer Railway CLI
            cmd = f'railway variables --set "{key}={value}"'
            commands.append(cmd)
            print(cmd)
    
    # Add production-specific variables
    print()
    print("# Production-specific variables:")
    prod_vars = {
        'ENVIRONMENT': 'production',
        'DEBUG': 'false',
        'LOG_LEVEL': 'INFO',
        'VERBOSE_LOGGING': 'false',
        'APNS_URL': 'https://api.push.apple.com'
    }
    
    for key, value in prod_vars.items():
        cmd = f'railway variables --set "{key}={value}"'
        commands.append(cmd)
        print(cmd)
    
    # Generate .env format for web UI
    print()
    print()
    print("=" * 80)
    print("📋 OPTION 2: Use Railway Web UI (Recommended if CLI fails)")
    print("=" * 80)
    print()
    print("1. Go to https://railway.app")
    print("2. Open your project")
    print("3. Go to Variables tab")
    print("4. Click 'RAW Editor'")
    print("5. Copy and paste the following:")
    print()
    print("-" * 80)
    
    for key in keys_to_set:
        if key in env_vars:
            value = env_vars[key]
            print(f"{key}={value}")
    
    for key, value in prod_vars.items():
        print(f"{key}={value}")
    
    print("-" * 80)
    print()
    print("⚠️  IMPORTANT: After deployment, add these variables:")
    print()
    print("ALLOWED_ORIGINS_STR=https://YOUR-APP.up.railway.app,https://api.petallergyscanner.com,capacitor://localhost,sniffsafe://")
    print("ALLOWED_HOSTS_STR=YOUR-APP.up.railway.app,api.petallergyscanner.com")
    print()
    print("=" * 80)
    
    return commands

def main():
    print()
    print("🔍 Reading .env file...")
    print()
    
    env_vars = read_env_file()
    
    if not env_vars:
        return 1
    
    print(f"✅ Found {len(env_vars)} variables")
    print()
    
    generate_commands(env_vars)
    
    print()
    print("✅ Commands generated successfully!")
    print()
    print("💡 TIP: If Railway CLI commands fail, use the Web UI method (Option 2)")
    print()
    
    return 0

if __name__ == "__main__":
    exit(main())
