#!/usr/bin/env python3
"""
Simple APN Test Script
Tests APN functionality without database dependencies
"""

import asyncio
import sys
import os
from datetime import datetime

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.services.push_notification_service import PushNotificationService
from app.core.config import settings

async def simple_apn_test(device_token: str = None):
    """Simple APN test without database dependencies"""
    print("🚀 Simple APN Test")
    print("=" * 40)
    
    # Test 1: Configuration
    print("🔧 Testing APN Configuration...")
    try:
        required_settings = ['APNS_URL', 'APNS_KEY_ID', 'APNS_TEAM_ID', 'APNS_BUNDLE_ID', 'APNS_PRIVATE_KEY']
        missing = [s for s in required_settings if not hasattr(settings, s) or not getattr(settings, s)]
        
        if missing:
            print(f"❌ Missing settings: {missing}")
            return False
        
        print(f"✅ APN URL: {settings.APNS_URL}")
        print(f"✅ Key ID: {settings.APNS_KEY_ID}")
        print(f"✅ Team ID: {settings.APNS_TEAM_ID}")
        print(f"✅ Bundle ID: {settings.APNS_BUNDLE_ID}")
        print(f"✅ Private Key: {'*' * 20}...{settings.APNS_PRIVATE_KEY[-10:]}")
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        return False
    
    # Test 2: JWT Token Creation
    print("\n🔐 Testing JWT Token Creation...")
    try:
        push_service = PushNotificationService()
        headers = await push_service._create_headers()
        
        if 'authorization' in headers:
            print("✅ JWT token created successfully")
            print(f"✅ Token preview: {headers['authorization'][:50]}...")
        else:
            print("❌ JWT token creation failed")
            return False
    except Exception as e:
        print(f"❌ JWT token creation failed: {e}")
        return False
    
    # Test 3: Push Notification (if device token provided)
    if device_token:
        print(f"\n📱 Testing Push Notification...")
        print(f"Target device: {device_token[:20]}...")
        
        try:
            test_payload = {
                "aps": {
                    "alert": {
                        "title": "🧪 Simple APN Test",
                        "body": f"Test sent at {datetime.now().strftime('%H:%M:%S')}"
                    },
                    "sound": "default",
                    "badge": 1
                },
                "type": "test",
                "action": "navigate_to_scan"
            }
            
            success = await push_service.send_notification(device_token, test_payload)
            
            if success:
                print("✅ Push notification sent successfully!")
                print("📱 Check your device for the notification")
            else:
                print("❌ Failed to send push notification")
                return False
                
        except Exception as e:
            print(f"❌ Push notification test failed: {e}")
            return False
    else:
        print("\n⏭️ Skipping push notification test (no device token provided)")
        print("💡 To test push notifications, run:")
        print("   python simple_apn_test.py <device_token>")
    
    print("\n🎉 All tests completed successfully!")
    return True

if __name__ == "__main__":
    device_token = sys.argv[1] if len(sys.argv) > 1 else None
    asyncio.run(simple_apn_test(device_token))
