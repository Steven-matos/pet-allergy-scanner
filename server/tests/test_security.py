"""
Security tests for the SniffTest API
"""

import pytest
import asyncio
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import json
import time

from main import app
from app.core.config import settings
from app.utils.security import SecurityValidator

client = TestClient(app)

class TestSecurityValidation:
    """Test security validation functions"""
    
    def test_sanitize_text_safe_input(self):
        """Test sanitization of safe text input"""
        safe_text = "This is a safe text input"
        result = SecurityValidator.sanitize_text(safe_text)
        assert result == safe_text
    
    def test_sanitize_text_dangerous_patterns(self):
        """Test sanitization rejects dangerous patterns"""
        dangerous_inputs = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "onload=alert('xss')",
            "eval('malicious code')",
            "<iframe src='evil.com'></iframe>"
        ]
        
        for dangerous_input in dangerous_inputs:
            with pytest.raises(Exception):
                SecurityValidator.sanitize_text(dangerous_input)
    
    def test_sanitize_text_sql_injection(self):
        """Test sanitization rejects SQL injection patterns"""
        sql_injection_inputs = [
            "'; DROP TABLE users; --",
            "UNION SELECT * FROM users",
            "1' OR '1'='1",
            "admin'--",
            "'; INSERT INTO users VALUES ('hacker', 'password'); --"
        ]
        
        for sql_input in sql_injection_inputs:
            with pytest.raises(Exception):
                SecurityValidator.sanitize_text(sql_input)
    
    def test_validate_email_valid(self):
        """Test email validation with valid emails"""
        valid_emails = [
            "user@example.com",
            "test.user@domain.co.uk",
            "user+tag@example.org"
        ]
        
        for email in valid_emails:
            result = SecurityValidator.validate_email(email)
            assert result == email.lower()
    
    def test_validate_email_invalid(self):
        """Test email validation with invalid emails"""
        invalid_emails = [
            "invalid-email",
            "@example.com",
            "user@",
            "user..double.dot@example.com",
            ""
        ]
        
        for email in invalid_emails:
            with pytest.raises(Exception):
                SecurityValidator.validate_email(email)
    
    def test_validate_password_strong(self):
        """Test password validation with strong passwords"""
        strong_passwords = [
            "StrongPass123!",
            "MySecure@Password1",
            "Complex#Pass2024"
        ]
        
        for password in strong_passwords:
            result = SecurityValidator.validate_password(password)
            assert result == password
    
    def test_validate_password_weak(self):
        """Test password validation rejects weak passwords"""
        weak_passwords = [
            "weak",
            "12345678",
            "password",
            "Password1",  # No special character
            "Password!",  # No number
            "pass123!",   # No uppercase
            "PASS123!",   # No lowercase
        ]
        
        for password in weak_passwords:
            with pytest.raises(Exception):
                SecurityValidator.validate_password(password)
    
    def test_validate_username_valid(self):
        """Test username validation with valid usernames"""
        valid_usernames = [
            "john_doe",
            "user123",
            "test-user",
            "validuser",
            "user_name"
        ]
        
        for username in valid_usernames:
            result = SecurityValidator.validate_username(username)
            assert result == username
    
    def test_validate_username_invalid(self):
        """Test username validation rejects invalid usernames"""
        invalid_usernames = [
            "ab",  # Too short
            "a" * 31,  # Too long
            "user@domain",  # Invalid characters
            "user name",  # Spaces
            "user<script>",  # XSS attempt
            "",  # Empty
            "admin",  # Reserved word
            "root",  # Reserved word
            "system"  # Reserved word
        ]
        
        for username in invalid_usernames:
            with pytest.raises(Exception):
                SecurityValidator.validate_username(username)

class TestRateLimiting:
    """Test rate limiting functionality"""
    
    def test_rate_limiting_general_endpoints(self):
        """Test rate limiting on general endpoints"""
        # Make multiple requests quickly
        for i in range(settings.rate_limit_per_minute + 1):
            response = client.get("/")
            
            if i < settings.rate_limit_per_minute:
                assert response.status_code == 200
            else:
                assert response.status_code == 429
                break
    
    def test_rate_limiting_auth_endpoints(self):
        """Test rate limiting on authentication endpoints"""
        # Make multiple login attempts
        for i in range(settings.auth_rate_limit_per_minute + 1):
            response = client.post("/api/v1/auth/login", data={
                "email": "test@example.com",
                "password": "wrongpassword"
            })
            
            if i < settings.auth_rate_limit_per_minute:
                assert response.status_code in [401, 422]  # Auth failure or validation error
            else:
                assert response.status_code == 429
                break

class TestCORS:
    """Test CORS configuration"""
    
    def test_cors_allowed_origins(self):
        """Test CORS with allowed origins"""
        for origin in settings.allowed_origins:
            response = client.options(
                "/",
                headers={"Origin": origin}
            )
            assert response.status_code == 200
            assert "Access-Control-Allow-Origin" in response.headers
    
    def test_cors_disallowed_origins(self):
        """Test CORS with disallowed origins"""
        response = client.options(
            "/",
            headers={"Origin": "https://malicious-site.com"}
        )
        # Should not include CORS headers for disallowed origins
        assert "Access-Control-Allow-Origin" not in response.headers

class TestSecurityHeaders:
    """Test security headers"""
    
    def test_security_headers_present(self):
        """Test that security headers are present in responses"""
        response = client.get("/")
        
        security_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
            "Strict-Transport-Security",
            "Referrer-Policy",
            "Content-Security-Policy"
        ]
        
        for header in security_headers:
            assert header in response.headers

class TestInputValidation:
    """Test input validation on API endpoints"""
    
    def test_register_validation(self):
        """Test user registration input validation"""
        # Test with invalid email
        response = client.post("/api/v1/auth/register", json={
            "email": "invalid-email",
            "password": "ValidPass123!",
            "first_name": "Test",
            "last_name": "User"
        })
        assert response.status_code == 422
    
    def test_login_with_username(self):
        """Test login with username instead of email"""
        # This test would require a registered user with username
        # For now, just test the endpoint accepts the new field
        response = client.post("/api/v1/auth/login", json={
            "email_or_username": "testuser",
            "password": "ValidPass123!"
        })
        # Should return 401 (user not found), 400 (bad request), or 422 (validation error)
        assert response.status_code in [400, 401, 422]
    
    def test_login_with_email(self):
        """Test login with email still works"""
        response = client.post("/api/v1/auth/login", json={
            "email_or_username": "test@example.com",
            "password": "ValidPass123!"
        })
        # Should return 401 (user not found), 400 (bad request), or 422 (validation error)
        assert response.status_code in [400, 401, 422]
    
    def test_password_reset_endpoint(self):
        """Test password reset endpoint"""
        response = client.post("/api/v1/auth/reset-password", json={
            "email": "test@example.com"
        })
        # Should return 200 (success) or 400 (bad request)
        assert response.status_code in [200, 400]
    
    def test_password_reset_invalid_email(self):
        """Test password reset with invalid email"""
        response = client.post("/api/v1/auth/reset-password", json={
            "email": "invalid-email"
        })
        assert response.status_code == 400
    
    def test_register_xss_attempt(self):
        """Test XSS prevention in registration"""
        response = client.post("/api/v1/auth/register", json={
            "email": "test@example.com",
            "password": "ValidPass123!",
            "first_name": "<script>alert('xss')</script>",
            "last_name": "User"
        })
        # Should either reject or sanitize the input
        assert response.status_code in [400, 422]
    
    def test_scan_analysis_xss(self):
        """Test XSS prevention in scan analysis"""
        # This would need authentication, but we can test the validation
        malicious_text = "<script>alert('xss')</script>"
        
        # Test the sanitization directly
        with pytest.raises(Exception):
            SecurityValidator.sanitize_text(malicious_text)

class TestAuthentication:
    """Test authentication security"""
    
    def test_jwt_token_validation(self):
        """Test JWT token validation"""
        # Test with invalid token
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer invalid-token"}
        )
        assert response.status_code == 401
    
    def test_missing_authorization_header(self):
        """Test missing authorization header"""
        response = client.get("/api/v1/auth/me")
        assert response.status_code == 403  # Missing authorization
    
    def test_malformed_authorization_header(self):
        """Test malformed authorization header"""
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "InvalidFormat token"}
        )
        assert response.status_code == 403

class TestFileUpload:
    """Test file upload security"""
    
    def test_file_size_limit(self):
        """Test file size limits"""
        # Create a file that exceeds the limit
        large_content = b"x" * (settings.max_file_size_mb * 1024 * 1024 + 1)
        
        response = client.post(
            "/api/v1/scans/",
            files={"file": ("test.jpg", large_content, "image/jpeg")}
        )
        assert response.status_code == 413  # Payload too large
    
    def test_file_type_validation(self):
        """Test file type validation"""
        # Test with disallowed file type
        response = client.post(
            "/api/v1/scans/",
            files={"file": ("test.exe", b"malicious content", "application/x-executable")}
        )
        assert response.status_code == 400  # Bad request

class TestErrorHandling:
    """Test error handling and information disclosure"""
    
    def test_error_messages_sanitized(self):
        """Test that error messages don't leak sensitive information"""
        # Test with SQL injection in error path
        response = client.get("/api/v1/pets/invalid-id")
        
        # Error message should not contain sensitive information
        assert "database" not in response.text.lower()
        assert "sql" not in response.text.lower()
        assert "connection" not in response.text.lower()
    
    def test_stack_trace_not_exposed(self):
        """Test that stack traces are not exposed in production"""
        # This would need to be tested in production mode
        # For now, just ensure error responses are structured
        response = client.get("/api/v1/nonexistent-endpoint")
        assert response.status_code == 404
        
        # Response should be JSON, not HTML error page
        assert response.headers["content-type"] == "application/json"

class TestGDPRCompliance:
    """Test GDPR compliance features"""
    
    def test_data_export_endpoint(self):
        """Test data export endpoint exists and requires authentication"""
        response = client.get("/api/v1/gdpr/export")
        assert response.status_code == 403  # Requires authentication
    
    def test_data_deletion_endpoint(self):
        """Test data deletion endpoint exists and requires authentication"""
        response = client.delete("/api/v1/gdpr/delete")
        assert response.status_code == 403  # Requires authentication
    
    def test_data_retention_info(self):
        """Test data retention information endpoint"""
        response = client.get("/api/v1/gdpr/retention")
        assert response.status_code == 403  # Requires authentication
    
    def test_data_subject_rights(self):
        """Test data subject rights information"""
        response = client.get("/api/v1/gdpr/rights")
        assert response.status_code == 200
        
        data = response.json()
        assert "data_subject_rights" in data
        assert "data_controller" in data
        assert "legal_basis" in data

class TestMonitoring:
    """Test monitoring and health check endpoints"""
    
    def test_health_check(self):
        """Test health check endpoint"""
        response = client.get("/api/v1/monitoring/health")
        assert response.status_code == 200
        
        data = response.json()
        assert "status" in data
        assert "timestamp" in data
    
    def test_metrics_endpoint(self):
        """Test metrics endpoint"""
        response = client.get("/api/v1/monitoring/metrics")
        assert response.status_code == 200
        
        data = response.json()
        assert "period_hours" in data
        assert "metrics" in data
    
    def test_status_endpoint(self):
        """Test status endpoint"""
        response = client.get("/api/v1/monitoring/status")
        assert response.status_code == 200
        
        data = response.json()
        assert "environment" in data
        assert "api_version" in data
        assert "features" in data

class TestMFA:
    """Test Multi-Factor Authentication"""
    
    def test_mfa_setup_requires_auth(self):
        """Test MFA setup requires authentication"""
        response = client.post("/api/v1/mfa/setup")
        assert response.status_code == 403  # Requires authentication
    
    def test_mfa_status_endpoint(self):
        """Test MFA status endpoint requires authentication"""
        response = client.get("/api/v1/mfa/status")
        assert response.status_code == 403  # Requires authentication

# Performance and Load Tests
class TestPerformance:
    """Test performance under load"""
    
    def test_concurrent_requests(self):
        """Test handling of concurrent requests"""
        import threading
        import time
        
        results = []
        
        def make_request():
            response = client.get("/")
            results.append(response.status_code)
        
        # Create multiple threads
        threads = []
        for i in range(10):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
        
        # Start all threads
        for thread in threads:
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # All requests should succeed
        assert all(status == 200 for status in results)
        assert len(results) == 10

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
