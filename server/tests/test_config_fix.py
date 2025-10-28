"""
Test to verify Settings has supabase_anon_key attribute
"""
import pytest
from app.core.config import Settings
from pydantic import ValidationError


def test_supabase_anon_key_property():
    """
    Test that Settings has supabase_anon_key property
    that returns the same value as supabase_key
    """
    # This test verifies the fix for: 'Settings' object has no attribute 'supabase_anon_key'
    
    # Mock the required environment variables
    import os
    os.environ['SUPABASE_URL'] = 'https://test.supabase.co'
    os.environ['SUPABASE_KEY'] = 'test_anon_key_12345'
    os.environ['SUPABASE_SERVICE_ROLE_KEY'] = 'test_service_key_12345'
    os.environ['SUPABASE_JWT_SECRET'] = 'test_jwt_secret_12345'
    os.environ['SECRET_KEY'] = 'test_secret_key_must_be_at_least_32_chars_long_12345'
    os.environ['DATABASE_URL'] = 'postgresql://test:test@localhost/test'
    
    # Create settings instance
    settings = Settings()
    
    # Verify that supabase_anon_key attribute exists
    assert hasattr(settings, 'supabase_anon_key'), \
        "Settings object must have supabase_anon_key attribute"
    
    # Verify that supabase_anon_key returns the same value as supabase_key
    assert settings.supabase_anon_key == settings.supabase_key, \
        "supabase_anon_key should return the same value as supabase_key"
    
    # Verify the value is correct
    assert settings.supabase_anon_key == 'test_anon_key_12345', \
        "supabase_anon_key should return the correct anon key value"
    
    print("✅ Settings.supabase_anon_key property works correctly")
    print(f"   supabase_key: {settings.supabase_key}")
    print(f"   supabase_anon_key: {settings.supabase_anon_key}")


def test_settings_backward_compatibility():
    """
    Test that both supabase_key and supabase_anon_key can be used interchangeably
    """
    import os
    os.environ['SUPABASE_URL'] = 'https://test.supabase.co'
    os.environ['SUPABASE_KEY'] = 'backward_compat_test_key'
    os.environ['SUPABASE_SERVICE_ROLE_KEY'] = 'test_service_key_12345'
    os.environ['SUPABASE_JWT_SECRET'] = 'test_jwt_secret_12345'
    os.environ['SECRET_KEY'] = 'test_secret_key_must_be_at_least_32_chars_long_12345'
    os.environ['DATABASE_URL'] = 'postgresql://test:test@localhost/test'
    
    settings = Settings()
    
    # Both should work and return the same value
    key1 = settings.supabase_key
    key2 = settings.supabase_anon_key
    
    assert key1 == key2, "Both accessors should return the same value"
    assert key1 == 'backward_compat_test_key', "Value should match environment variable"
    
    print("✅ Backward compatibility maintained")
    print(f"   Both methods return: {key1}")


if __name__ == "__main__":
    test_supabase_anon_key_property()
    test_settings_backward_compatibility()
    print("\n✅ All configuration tests passed!")

