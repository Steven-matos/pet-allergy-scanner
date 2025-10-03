#!/usr/bin/env python3
"""
Quick APN Test Script
Simple script to test APN functionality without full test suite
"""

import asyncio
import sys
import os
from datetime import datetime

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.services.push_notification_service import PushNotificationService

async def quick_test(device_token: str):
    """Quick test of APN functionality"""
    print("🚀 Quick APN Test")
    print("=" * 40)
    
    push_service = PushNotificationService()
    
    # Test payload
    test_payload = {
        "aps": {
            "alert": {
                "title": "🧪 Quick APN Test",
                "body": f"Test notification sent at {datetime.now().strftime('%H:%M:%S')}"
            },
            "sound": "default",
            "badge": 1
        },
        "type": "test",
        "action": "navigate_to_scan"
    }
    
    print(f"📱 Sending to device: {device_token[:20]}...")
    print(f"📦 Payload: {test_payload}")
    
    try:
        success = await push_service.send_notification(device_token, test_payload)
        
        if success:
            print("✅ Notification sent successfully!")
            print("📱 Check your device for the notification")
        else:
            print("❌ Failed to send notification")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_apn_test.py <device_token>")
        print("Get device token from iOS app console logs")
        sys.exit(1)
    
    device_token = sys.argv[1]
    asyncio.run(quick_test(device_token))
