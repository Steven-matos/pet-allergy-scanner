"""
Unit tests for user metadata mapper service

Tests centralized user metadata extraction and mapping.
"""

import pytest
from unittest.mock import Mock
from datetime import datetime

from app.shared.services.user_metadata_mapper import UserMetadataMapper


class TestUserMetadataMapper:
    """Test suite for user metadata mapper"""
    
    def test_extract_auth_metadata(self):
        """Test extracting metadata from Supabase auth response"""
        # Arrange
        mock_user = Mock()
        mock_user.email = "test@example.com"
        mock_user.user_metadata = {
            "username": "testuser",
            "first_name": "Test",
            "last_name": "User",
            "role": "premium"
        }
        mock_user.created_at = "2025-01-01T00:00:00Z"
        mock_user.updated_at = "2025-01-02T00:00:00Z"
        
        # Act
        result = UserMetadataMapper.extract_auth_metadata(mock_user)
        
        # Assert
        assert result["email"] == "test@example.com"
        assert result["username"] == "testuser"
        assert result["first_name"] == "Test"
        assert result["last_name"] == "User"
        assert result["role"] == "premium"
        assert result["created_at"] == "2025-01-01T00:00:00Z"
        assert result["updated_at"] == "2025-01-02T00:00:00Z"
    
    def test_extract_auth_metadata_missing_fields(self):
        """Test extracting metadata when optional fields are missing"""
        # Arrange
        mock_user = Mock()
        mock_user.email = "test@example.com"
        mock_user.user_metadata = {}  # No metadata
        mock_user.created_at = "2025-01-01T00:00:00Z"
        mock_user.updated_at = "2025-01-02T00:00:00Z"
        
        # Act
        result = UserMetadataMapper.extract_auth_metadata(mock_user)
        
        # Assert
        assert result["email"] == "test@example.com"
        assert result["username"] is None
        assert result["first_name"] is None
        assert result["last_name"] is None
        assert result["role"] == "free"  # Default role
    
    def test_prepare_user_insert_data(self):
        """Test preparing user data for database insertion"""
        # Arrange
        mock_user = Mock()
        mock_user.id = "user-123"
        mock_user.email = "test@example.com"
        mock_user.user_metadata = {
            "username": "testuser",
            "first_name": "Test",
            "last_name": "User",
            "role": "premium"
        }
        
        # Act
        result = UserMetadataMapper.prepare_user_insert_data(mock_user)
        
        # Assert
        assert result["id"] == "user-123"
        assert result["email"] == "test@example.com"
        assert result["username"] == "testuser"
        assert result["first_name"] == "Test"
        assert result["last_name"] == "User"
        assert result["role"] == "premium"
    
    def test_prepare_metadata_update_all_fields(self):
        """Test preparing update data with all fields"""
        # Act
        result = UserMetadataMapper.prepare_metadata_update(
            username="newuser",
            first_name="New",
            last_name="Name",
            role="premium"
        )
        
        # Assert
        assert len(result) == 4
        assert result["username"] == "newuser"
        assert result["first_name"] == "New"
        assert result["last_name"] == "Name"
        assert result["role"] == "premium"
    
    def test_prepare_metadata_update_partial(self):
        """Test preparing update data with only some fields"""
        # Act
        result = UserMetadataMapper.prepare_metadata_update(
            first_name="Updated",
            last_name="Name"
        )
        
        # Assert
        assert len(result) == 2
        assert result["first_name"] == "Updated"
        assert result["last_name"] == "Name"
        assert "username" not in result
        assert "role" not in result
    
    def test_prepare_metadata_update_empty(self):
        """Test preparing update data with no fields"""
        # Act
        result = UserMetadataMapper.prepare_metadata_update()
        
        # Assert
        assert len(result) == 0
        assert result == {}
    
    def test_merge_auth_and_public_data_with_public(self):
        """Test merging auth and public data"""
        # Arrange
        auth_metadata = {
            "email": "test@example.com",
            "username": "testuser",
            "role": "free"
        }
        public_data = {
            "onboarded": True,
            "image_url": "https://example.com/image.jpg",
            "role": "premium"  # Should override auth role
        }
        
        # Act
        result = UserMetadataMapper.merge_auth_and_public_data(
            auth_metadata, public_data
        )
        
        # Assert
        assert result["email"] == "test@example.com"
        assert result["username"] == "testuser"
        assert result["onboarded"] is True
        assert result["image_url"] == "https://example.com/image.jpg"
        assert result["role"] == "premium"  # From public_data
    
    def test_merge_auth_and_public_data_without_public(self):
        """Test merging when public data is None"""
        # Arrange
        auth_metadata = {
            "email": "test@example.com",
            "username": "testuser",
            "role": "free"
        }
        
        # Act
        result = UserMetadataMapper.merge_auth_and_public_data(
            auth_metadata, None
        )
        
        # Assert
        assert result["email"] == "test@example.com"
        assert result["username"] == "testuser"
        assert result["onboarded"] is False
        assert result["image_url"] is None
        assert result["role"] == "free"
    
    def test_format_full_name_both_names(self):
        """Test formatting full name with both first and last name"""
        result = UserMetadataMapper.format_full_name("John", "Doe")
        assert result == "John Doe"
    
    def test_format_full_name_first_only(self):
        """Test formatting full name with only first name"""
        result = UserMetadataMapper.format_full_name("John", None)
        assert result == "John"
    
    def test_format_full_name_last_only(self):
        """Test formatting full name with only last name"""
        result = UserMetadataMapper.format_full_name(None, "Doe")
        assert result == "Doe"
    
    def test_format_full_name_neither(self):
        """Test formatting full name with no names"""
        result = UserMetadataMapper.format_full_name(None, None)
        assert result == ""

