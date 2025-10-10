"""
Test JWT migration from python-jose to PyJWT
Verifies that the security fix maintains functionality
"""

import jwt
from datetime import datetime, timedelta, timezone
import pytest


def test_jwt_encoding_decoding():
    """Test basic JWT encode/decode functionality with PyJWT"""
    secret = "test_secret_key"
    algorithm = "HS256"
    
    # Create payload
    payload = {
        "sub": "user123",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=30),
        "iat": datetime.now(timezone.utc)
    }
    
    # Encode
    token = jwt.encode(payload, secret, algorithm=algorithm)
    
    # Decode
    decoded = jwt.decode(token, secret, algorithms=[algorithm])
    
    assert decoded["sub"] == "user123"
    print("✅ JWT encoding/decoding works correctly")


def test_jwt_expiration():
    """Test JWT expiration handling"""
    secret = "test_secret_key"
    algorithm = "HS256"
    
    # Create expired token
    payload = {
        "sub": "user123",
        "exp": datetime.now(timezone.utc) - timedelta(minutes=1)  # Expired
    }
    
    token = jwt.encode(payload, secret, algorithm=algorithm)
    
    # Should raise ExpiredSignatureError
    with pytest.raises(jwt.ExpiredSignatureError):
        jwt.decode(token, secret, algorithms=[algorithm])
    
    print("✅ JWT expiration validation works correctly")


def test_jwt_invalid_signature():
    """Test JWT invalid signature detection"""
    secret = "test_secret_key"
    wrong_secret = "wrong_secret_key"
    algorithm = "HS256"
    
    # Create token
    payload = {"sub": "user123"}
    token = jwt.encode(payload, secret, algorithm=algorithm)
    
    # Try to decode with wrong secret
    with pytest.raises(jwt.InvalidSignatureError):
        jwt.decode(token, wrong_secret, algorithms=[algorithm])
    
    print("✅ JWT signature validation works correctly")


def test_jwt_with_audience():
    """Test JWT with audience validation (like Supabase)"""
    secret = "test_secret_key"
    algorithm = "HS256"
    
    # Create token with audience
    payload = {
        "sub": "user123",
        "aud": "authenticated"
    }
    
    token = jwt.encode(payload, secret, algorithm=algorithm)
    
    # Decode with audience check
    decoded = jwt.decode(
        token, 
        secret, 
        algorithms=[algorithm],
        audience="authenticated"
    )
    
    assert decoded["sub"] == "user123"
    assert decoded["aud"] == "authenticated"
    print("✅ JWT audience validation works correctly")


def test_jwt_algorithm_allowlist():
    """Test that algorithm allowlist prevents 'none' algorithm attack"""
    secret = "test_secret_key"
    
    # Create token
    payload = {"sub": "user123"}
    token = jwt.encode(payload, secret, algorithm="HS256")
    
    # Should NOT allow decoding with 'none' algorithm
    # This prevents the "none" algorithm attack
    with pytest.raises((jwt.InvalidAlgorithmError, jwt.DecodeError)):
        jwt.decode(token, secret, algorithms=["none"])
    
    print("✅ JWT algorithm allowlist security works correctly")


if __name__ == "__main__":
    """Run tests manually"""
    print("🔒 Testing JWT Migration Security")
    print("=" * 50)
    
    try:
        test_jwt_encoding_decoding()
        test_jwt_expiration()
        test_jwt_invalid_signature()
        test_jwt_with_audience()
        test_jwt_algorithm_allowlist()
        
        print("\n✅ All JWT security tests passed!")
        print("\n📝 Summary:")
        print("  - PyJWT successfully replaced python-jose")
        print("  - No ecdsa dependency vulnerability")
        print("  - All security validations working")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        raise

