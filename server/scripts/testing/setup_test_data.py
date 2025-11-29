#!/usr/bin/env python3
"""
Test Data Setup Script (Fixed)

Creates test user and pet data using the service role key to bypass RLS.
This script works with the existing server architecture.

Usage:
    python3 scripts/testing/setup_test_data.py
"""

import os
import sys
from pathlib import Path
import uuid
from datetime import datetime, date

# Add the parent directory to the path so we can import app modules
sys.path.append(str(Path(__file__).parent.parent.parent))

from app.core.config import settings
from supabase import create_client
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_test_user_record(supabase, user_id: str, email: str) -> bool:
    """Create a user record in public.users table using service role"""
    try:
        user_data = {
            "id": user_id,
            "email": email,
            "username": "chichi-dad",
            "first_name": "Steven",
            "last_name": "Matos",
            "role": "free",
            "onboarded": True,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        response = supabase.table("users").upsert(user_data).execute()
        
        if response.data:
            logger.info(f"✅ Created user record: {email}")
            return True
        else:
            logger.error(f"❌ Failed to create user record: {email}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error creating user record: {e}")
        return False

def create_test_pet(supabase, pet_id: str, user_id: str) -> bool:
    """Create a test pet for the user"""
    try:
        pet_data = {
            "id": pet_id,
            "user_id": user_id,
            "name": "Chichi",
            "species": "dog",
            "breed": "Mixed Breed",
            "birthday": "2020-01-15",
            "weight_kg": 25.5,
            "activity_level": "moderate",
            "known_sensitivities": ["chicken", "corn"],
            "vet_name": "Dr. Smith",
            "vet_phone": "+1-555-0123",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        response = supabase.table("pets").upsert(pet_data).execute()
        
        if response.data:
            logger.info(f"✅ Created test pet: {pet_data['name']}")
            return True
        else:
            logger.error(f"❌ Failed to create test pet: {pet_data['name']}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error creating test pet: {e}")
        return False

def create_nutritional_requirements(supabase, pet_id: str) -> bool:
    """Create nutritional requirements for the pet"""
    try:
        requirements_data = {
            "pet_id": pet_id,
            "daily_calories": 1200.0,
            "protein_percentage": 25.0,
            "fat_percentage": 15.0,
            "fiber_percentage": 4.0,
            "moisture_percentage": 10.0,
            "life_stage": "adult",
            "activity_level": "moderate",
            "calculated_at": datetime.now().isoformat(),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        response = supabase.table("nutritional_requirements").upsert(requirements_data).execute()
        
        if response.data:
            logger.info(f"✅ Created nutritional requirements for pet")
            return True
        else:
            logger.error(f"❌ Failed to create nutritional requirements")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error creating nutritional requirements: {e}")
        return False

def main():
    """Main setup function"""
    logger.info("🚀 Setting up test data for SniffTest")
    logger.info("=" * 50)
    
    try:
        # Create Supabase client with service role key (bypasses RLS)
        supabase = create_client(settings.supabase_url, settings.supabase_service_role_key)
        
        # Test data from the JWT token
        user_id = "7a481030-e6fe-40ea-a81e-3616f1b78266"
        email = "steven_matos@ymail.com"
        pet_id = "831b04d5-5925-4914-9af4-0219a1358dd3"
        
        logger.info(f"📝 Setting up data for user: {email}")
        logger.info(f"🐕 Setting up data for pet: {pet_id}")
        
        # Verify user exists in Supabase Auth
        try:
            auth_user = supabase.auth.admin.get_user_by_id(user_id)
            logger.info(f"✅ User exists in Supabase Auth: {auth_user.user.email}")
        except Exception as e:
            logger.error(f"❌ User does not exist in Supabase Auth: {e}")
            logger.error("This user needs to be created through the app registration flow")
            return 1
        
        # Create user record in public.users table
        if create_test_user_record(supabase, user_id, email):
            logger.info("✅ User record created successfully")
        else:
            logger.error("❌ Failed to create user record")
            return 1
        
        # Create test pet
        if create_test_pet(supabase, pet_id, user_id):
            logger.info("✅ Pet created successfully")
        else:
            logger.error("❌ Failed to create pet")
            return 1
        
        # Create nutritional requirements
        if create_nutritional_requirements(supabase, pet_id):
            logger.info("✅ Nutritional requirements created successfully")
        else:
            logger.error("❌ Failed to create nutritional requirements")
            return 1
        
        logger.info("\n🎉 Test data setup complete!")
        logger.info("=" * 50)
        logger.info("✅ User: steven_matos@ymail.com")
        logger.info("✅ Pet: Chichi (dog)")
        logger.info("✅ Nutritional requirements: Created")
        logger.info("")
        logger.info("You can now test the API endpoints with this data.")
        logger.info("The pet ID 831b04d5-5925-4914-9af4-0219a1358dd3 should now work.")
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Setup failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())