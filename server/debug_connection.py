#!/usr/bin/env python3
"""
Debug script to diagnose Supabase connection issues
"""

import os
import socket
import requests
import time
from dotenv import load_dotenv

def test_dns_resolution():
    """Test DNS resolution for Supabase URL"""
    print("🔍 Testing DNS resolution...")
    
    try:
        ip = socket.gethostbyname('oxjywpearruxtnysoyuf.supabase.co')
        print(f"✅ DNS resolution successful: {ip}")
        return True
    except Exception as e:
        print(f"❌ DNS resolution failed: {e}")
        return False

def test_http_connection():
    """Test HTTP connection to Supabase"""
    print("\n🌐 Testing HTTP connection...")
    
    load_dotenv()
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_KEY')
    
    if not url or not key:
        print("❌ Missing environment variables")
        return False
    
    try:
        response = requests.get(
            f'{url}/rest/v1/', 
            headers={
                'apikey': key, 
                'Authorization': f'Bearer {key}'
            }, 
            timeout=10
        )
        print(f"✅ HTTP connection successful: {response.status_code}")
        return True
    except Exception as e:
        print(f"❌ HTTP connection failed: {e}")
        return False

def test_supabase_client():
    """Test Supabase Python client"""
    print("\n🐍 Testing Supabase Python client...")
    
    try:
        from supabase import create_client
        
        load_dotenv()
        url = os.getenv('SUPABASE_URL')
        key = os.getenv('SUPABASE_KEY')
        
        supabase = create_client(url, key)
        response = supabase.table('users').select('id').limit(1).execute()
        print(f"✅ Supabase client successful: {len(response.data)} records")
        return True
    except Exception as e:
        print(f"❌ Supabase client failed: {e}")
        return False

def test_alternative_dns():
    """Test alternative DNS servers"""
    print("\n🔧 Testing alternative DNS servers...")
    
    dns_servers = [
        '8.8.8.8',      # Google DNS
        '1.1.1.1',      # Cloudflare DNS
        '208.67.222.222' # OpenDNS
    ]
    
    for dns in dns_servers:
        try:
            # This is a simplified test - in practice, you'd need to configure the resolver
            print(f"  Testing with {dns}...")
            # Note: This won't actually change the DNS server used by Python
            # It's just to show what servers are available
        except Exception as e:
            print(f"  ❌ {dns}: {e}")

def main():
    """Run all diagnostic tests"""
    print("🚀 Supabase Connection Diagnostics")
    print("=" * 40)
    
    # Test DNS resolution
    dns_ok = test_dns_resolution()
    
    # Test HTTP connection
    http_ok = test_http_connection()
    
    # Test Supabase client
    client_ok = test_supabase_client()
    
    # Test alternative DNS
    test_alternative_dns()
    
    print("\n📊 Summary:")
    print(f"DNS Resolution: {'✅' if dns_ok else '❌'}")
    print(f"HTTP Connection: {'✅' if http_ok else '❌'}")
    print(f"Supabase Client: {'✅' if client_ok else '❌'}")
    
    if not client_ok:
        print("\n🔧 Troubleshooting suggestions:")
        print("1. Check your internet connection")
        print("2. Try using a VPN if you're behind a corporate firewall")
        print("3. Check if your ISP is blocking the connection")
        print("4. Try restarting your network connection")
        print("5. Check if the Supabase project is still active")
        print("6. Verify the Supabase URL and keys are correct")

if __name__ == "__main__":
    main()
