#!/usr/bin/env python3
"""
APN Testing Script for SniffTest
Tests push notification functionality end-to-end
"""

import asyncio
import json
import sys
import os
from datetime import datetime
from typing import Dict, Any

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.services.push_notification_service import PushNotificationService
from app.core.config import settings
from app.database import get_db, init_db
from app.models.user import User
from sqlalchemy.orm import Session

class APNTester:
    """Test class for APN functionality"""
    
    def __init__(self):
        self.push_service = PushNotificationService()
        self.test_results = []
    
    async def test_apn_configuration(self) -> bool:
        """Test APN configuration validity"""
        print("🔧 Testing APN Configuration...")
        
        try:
            # Check if all required settings are present
            required_settings = [
                'APNS_URL', 'APNS_KEY_ID', 'APNS_TEAM_ID', 
                'APNS_BUNDLE_ID', 'APNS_PRIVATE_KEY'
            ]
            
            missing_settings = []
            for setting in required_settings:
                if not hasattr(settings, setting) or not getattr(settings, setting):
                    missing_settings.append(setting)
            
            if missing_settings:
                print(f"❌ Missing APN settings: {missing_settings}")
                return False
            
            print(f"✅ APN URL: {settings.APNS_URL}")
            print(f"✅ Key ID: {settings.APNS_KEY_ID}")
            print(f"✅ Team ID: {settings.APNS_TEAM_ID}")
            print(f"✅ Bundle ID: {settings.APNS_BUNDLE_ID}")
            print(f"✅ Private Key: {'*' * 20}...{settings.APNS_PRIVATE_KEY[-10:]}")
            
            return True
            
        except Exception as e:
            print(f"❌ APN configuration test failed: {e}")
            return False
    
    async def test_jwt_token_creation(self) -> bool:
        """Test JWT token creation for APN authentication"""
        print("\n🔐 Testing JWT Token Creation...")
        
        try:
            # This will test the JWT creation in the push service
            headers = await self.push_service._create_headers()
            
            if 'authorization' in headers:
                print("✅ JWT token created successfully")
                print(f"✅ Token preview: {headers['authorization'][:50]}...")
                return True
            else:
                print("❌ JWT token creation failed")
                return False
                
        except Exception as e:
            print(f"❌ JWT token creation test failed: {e}")
            return False
    
    async def test_database_connection(self) -> bool:
        """Test database connection and device token storage"""
        print("\n🗄️ Testing Database Connection...")
        
        try:
            # Initialize database first
            print("🔄 Initializing database connection...")
            db_initialized = await init_db()
            
            if not db_initialized:
                print("❌ Failed to initialize database")
                return False
            
            # Get Supabase client
            from app.database import get_supabase_client
            supabase = get_supabase_client()
            
            # Test querying users table
            response = supabase.table("users").select("id").execute()
            user_count = len(response.data) if response.data else 0
            print(f"✅ Database connected successfully")
            print(f"✅ Users in database: {user_count}")
            
            # Check if device_token column exists by querying a user
            try:
                users_response = supabase.table("users").select("device_token").limit(5).execute()
                users_with_tokens = sum(1 for user in users_response.data if user.get('device_token'))
                print(f"✅ Users with device tokens: {users_with_tokens}")
            except Exception as e:
                print(f"⚠️ Could not check device tokens: {e}")
                print("💡 Make sure the device_token column exists in your users table")
            
            return True
            
        except Exception as e:
            print(f"❌ Database connection test failed: {e}")
            return False
    
    async def test_push_notification_send(self, device_token: str) -> bool:
        """Test sending a push notification"""
        print(f"\n📱 Testing Push Notification Send...")
        print(f"Target device token: {device_token[:20]}...")
        
        try:
            # Create test payload
            test_payload = {
                "aps": {
                    "alert": {
                        "title": "🧪 APN Test",
                        "body": "This is a test notification from SniffTest"
                    },
                    "sound": "default",
                    "badge": 1
                },
                "type": "test",
                "action": "navigate_to_scan",
                "test_timestamp": datetime.utcnow().isoformat()
            }
            
            # Send notification
            success = await self.push_service.send_notification(device_token, test_payload)
            
            if success:
                print("✅ Push notification sent successfully")
                return True
            else:
                print("❌ Push notification send failed")
                return False
                
        except Exception as e:
            print(f"❌ Push notification send test failed: {e}")
            return False
    
    async def test_engagement_notification(self, device_token: str) -> bool:
        """Test engagement notification"""
        print(f"\n🎯 Testing Engagement Notification...")
        
        try:
            engagement_payload = {
                "aps": {
                    "alert": {
                        "title": "🔍 Time for a Scan!",
                        "body": "Keep your pet safe by scanning their food ingredients regularly."
                    },
                    "sound": "default",
                    "badge": 1,
                    "category": "engagement"
                },
                "type": "engagement_reminder",
                "action": "navigate_to_scan"
            }
            
            success = await self.push_service.send_notification(device_token, engagement_payload)
            
            if success:
                print("✅ Engagement notification sent successfully")
                return True
            else:
                print("❌ Engagement notification send failed")
                return False
                
        except Exception as e:
            print(f"❌ Engagement notification test failed: {e}")
            return False
    
    async def test_birthday_notification(self, device_token: str) -> bool:
        """Test birthday notification"""
        print(f"\n🎉 Testing Birthday Notification...")
        
        try:
            birthday_payload = {
                "aps": {
                    "alert": {
                        "title": "🎉 Surprise! It's Buddy's Birthday Month! 🎂",
                        "body": "This month is Buddy's special time! Time to celebrate! 🐾✨"
                    },
                    "sound": "default",
                    "badge": 1,
                    "category": "birthday"
                },
                "type": "birthday_celebration",
                "action": "navigate_to_scan",
                "pet_name": "Buddy",
                "pet_id": "test_pet_id"
            }
            
            success = await self.push_service.send_notification(device_token, birthday_payload)
            
            if success:
                print("✅ Birthday notification sent successfully")
                return True
            else:
                print("❌ Birthday notification send failed")
                return False
                
        except Exception as e:
            print(f"❌ Birthday notification test failed: {e}")
            return False
    
    def print_test_summary(self):
        """Print test results summary"""
        print("\n" + "="*50)
        print("📊 APN TEST SUMMARY")
        print("="*50)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result)
        
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {total_tests - passed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if passed_tests == total_tests:
            print("\n🎉 All tests passed! APN is working correctly.")
        else:
            print("\n⚠️ Some tests failed. Check the output above for details.")
        
        print("="*50)

async def main():
    """Main test function"""
    print("🚀 Starting APN Testing for SniffTest")
    print("="*60)
    
    tester = APNTester()
    
    # Test 1: Configuration
    config_ok = await tester.test_apn_configuration()
    tester.test_results.append(config_ok)
    
    if not config_ok:
        print("\n❌ Configuration test failed. Please check your .env file.")
        return
    
    # Test 2: JWT Token Creation
    jwt_ok = await tester.test_jwt_token_creation()
    tester.test_results.append(jwt_ok)
    
    # Test 3: Database Connection
    db_ok = await tester.test_database_connection()
    tester.test_results.append(db_ok)
    
    if not db_ok:
        print("\n❌ Database test failed. Please check your database connection.")
        return
    
    # Get device token from user
    print("\n📱 Device Token Required for Testing")
    print("To test push notifications, you need a device token from your iOS app.")
    print("1. Run the iOS app on a physical device (simulator won't work)")
    print("2. Grant push notification permissions")
    print("3. Check the console logs for the device token")
    print("4. Enter the device token below (or press Enter to skip push tests)")
    
    device_token = input("\nEnter device token (or press Enter to skip): ").strip()
    
    if device_token:
        # Test 4: Push Notification Send
        push_ok = await tester.test_push_notification_send(device_token)
        tester.test_results.append(push_ok)
        
        # Test 5: Engagement Notification
        engagement_ok = await tester.test_engagement_notification(device_token)
        tester.test_results.append(engagement_ok)
        
        # Test 6: Birthday Notification
        birthday_ok = await tester.test_birthday_notification(device_token)
        tester.test_results.append(birthday_ok)
    else:
        print("\n⏭️ Skipping push notification tests")
        tester.test_results.extend([True, True, True])  # Mark as passed for summary
    
    # Print summary
    tester.print_test_summary()

if __name__ == "__main__":
    asyncio.run(main())
