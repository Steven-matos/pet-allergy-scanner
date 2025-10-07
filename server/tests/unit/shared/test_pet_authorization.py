"""
Unit tests for pet authorization service

Tests the centralized pet ownership verification functionality.
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch
from fastapi import HTTPException

from app.shared.services.pet_authorization import verify_pet_ownership


class TestPetAuthorization:
    """Test suite for pet authorization service"""
    
    @pytest.mark.asyncio
    async def test_verify_pet_ownership_success(self):
        """Test successful pet ownership verification"""
        # Arrange
        pet_id = "test-pet-123"
        user_id = "test-user-456"
        expected_pet = {
            "id": pet_id,
            "user_id": user_id,
            "name": "Fluffy",
            "species": "dog"
        }
        
        mock_db = Mock()
        mock_table = Mock()
        mock_select = Mock()
        mock_eq1 = Mock()
        mock_eq2 = Mock()
        mock_response = Mock()
        mock_response.data = [expected_pet]
        
        mock_db.table.return_value = mock_table
        mock_table.select.return_value = mock_select
        mock_select.eq.return_value = mock_eq1
        mock_eq1.eq.return_value = mock_eq2
        mock_eq2.execute.return_value = mock_response
        
        # Act
        result = await verify_pet_ownership(pet_id, user_id, db=mock_db)
        
        # Assert
        assert result == expected_pet
        mock_db.table.assert_called_once_with("pets")
        mock_table.select.assert_called_once_with("*")
    
    @pytest.mark.asyncio
    async def test_verify_pet_ownership_not_found(self):
        """Test pet ownership verification when pet not found"""
        # Arrange
        pet_id = "nonexistent-pet"
        user_id = "test-user-456"
        
        mock_db = Mock()
        mock_table = Mock()
        mock_select = Mock()
        mock_eq1 = Mock()
        mock_eq2 = Mock()
        mock_response = Mock()
        mock_response.data = []  # No pet found
        
        mock_db.table.return_value = mock_table
        mock_table.select.return_value = mock_select
        mock_select.eq.return_value = mock_eq1
        mock_eq1.eq.return_value = mock_eq2
        mock_eq2.execute.return_value = mock_response
        
        # Act & Assert
        with pytest.raises(HTTPException) as exc_info:
            await verify_pet_ownership(pet_id, user_id, db=mock_db)
        
        assert exc_info.value.status_code == 404
        assert "Pet not found or access denied" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_verify_pet_ownership_wrong_user(self):
        """Test pet ownership verification with wrong user ID"""
        # Arrange
        pet_id = "test-pet-123"
        user_id = "wrong-user"
        
        mock_db = Mock()
        mock_table = Mock()
        mock_select = Mock()
        mock_eq1 = Mock()
        mock_eq2 = Mock()
        mock_response = Mock()
        mock_response.data = []  # No match for this user
        
        mock_db.table.return_value = mock_table
        mock_table.select.return_value = mock_select
        mock_select.eq.return_value = mock_eq1
        mock_eq1.eq.return_value = mock_eq2
        mock_eq2.execute.return_value = mock_response
        
        # Act & Assert
        with pytest.raises(HTTPException) as exc_info:
            await verify_pet_ownership(pet_id, user_id, db=mock_db)
        
        assert exc_info.value.status_code == 404

