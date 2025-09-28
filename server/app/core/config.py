"""
Application configuration settings with enhanced security
"""

import os
from typing import List, Optional
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    """Application settings configuration with security enhancements"""
    
    # Supabase Configuration
    supabase_url: str = Field(..., description="Supabase project URL")
    supabase_key: str = Field(..., description="Supabase anon key")
    supabase_service_role_key: str = Field(..., description="Supabase service role key")
    
    # Security Configuration
    secret_key: str = Field(..., min_length=32, description="Strong secret key for JWT signing")
    algorithm: str = Field(default="HS256", description="JWT algorithm")
    access_token_expire_minutes: int = Field(default=30, ge=5, le=1440, description="Token expiration in minutes")
    
    # CORS and Security Headers
    allowed_origins_str: Optional[str] = Field(
        default=None,
        description="Comma-separated allowed CORS origins"
    )
    allowed_hosts_str: Optional[str] = Field(
        default=None,
        description="Comma-separated trusted hosts"
    )
    
    @property
    def allowed_origins(self) -> List[str]:
        """Get allowed origins as a list"""
        if self.allowed_origins_str:
            return [origin.strip() for origin in self.allowed_origins_str.split(',') if origin.strip()]
        return [
            # Development origins
            "http://localhost:3000", 
            "http://localhost:8080",
            "http://localhost",
            "https://localhost",
            # Capacitor/Ionic origins
            "capacitor://localhost",
            "ionic://localhost",
            # iOS app URL schemes
            "sniffsafe://",
            "sniffsafe://localhost",
            # Production origins (update these with your actual domains)
            "https://api.petallergyscanner.com",
            "https://petallergyscanner.com"
        ]
    
    @property
    def allowed_hosts(self) -> List[str]:
        """Get allowed hosts as a list"""
        if self.allowed_hosts_str:
            return [host.strip() for host in self.allowed_hosts_str.split(',') if host.strip()]
        return ["localhost", "127.0.0.1"]
    
    # Rate Limiting
    rate_limit_per_minute: int = Field(default=60, ge=1, le=1000, description="Rate limit per minute")
    auth_rate_limit_per_minute: int = Field(default=5, ge=1, le=20, description="Auth rate limit per minute")
    
    # Database Configuration
    database_url: str = Field(..., description="Database connection URL")
    database_pool_size: int = Field(default=10, ge=1, le=100, description="Database connection pool size")
    database_timeout: int = Field(default=30, ge=5, le=300, description="Database query timeout in seconds")
    
    # File Upload Limits
    max_file_size_mb: int = Field(default=10, ge=1, le=100, description="Maximum file upload size in MB")
    max_request_size_mb: int = Field(default=50, ge=1, le=500, description="Maximum request size in MB")
    
    # Environment
    environment: str = Field(default="development", description="Application environment")
    debug: bool = Field(default=False, description="Debug mode")
    
    # API Configuration
    api_v1_prefix: str = "/api/v1"
    api_version: str = "1.0.0"
    
    # Security Features
    enable_mfa: bool = Field(default=True, description="Enable multi-factor authentication")
    enable_audit_logging: bool = Field(default=True, description="Enable audit logging")
    session_timeout_minutes: int = Field(default=480, ge=30, le=1440, description="Session timeout in minutes")
    
    # GDPR Compliance
    data_retention_days: int = Field(default=365, ge=30, le=2555, description="Data retention period in days")
    enable_data_export: bool = Field(default=True, description="Enable data export for GDPR")
    enable_data_deletion: bool = Field(default=True, description="Enable data deletion for GDPR")
    
    @field_validator('secret_key')
    @classmethod
    def validate_secret_key(cls, v):
        """Validate secret key strength"""
        if len(v) < 32:
            raise ValueError('Secret key must be at least 32 characters long')
        if v == "your-secret-key-here":
            raise ValueError('Please set a proper secret key in environment variables')
        return v
    
    @field_validator('environment')
    @classmethod
    def validate_environment(cls, v):
        """Validate environment setting"""
        if v not in ['development', 'staging', 'production']:
            raise ValueError('Environment must be development, staging, or production')
        return v
    
    
    model_config = {
        "env_file": ".env",
        "case_sensitive": False,
        "env_parse_none_str": "None",
    }

# Global settings instance
settings = Settings()
