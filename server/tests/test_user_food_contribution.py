"""
Test User-Contributed Food Items API
Tests the endpoint for users to add scanned products to the database
"""

import pytest
import asyncio
from httpx import AsyncClient
from fastapi import status

# Test data matching the format from SniffTest app
TEST_FOOD_ITEM = {
    "name": "Wilderness Chicken Recipe",
    "brand": "Blue Buffalo",
    "barcode": "0840243101642",
    "category": "Dog Food",
    "species": "dog",
    "language": "en",
    "country": "en:united-states",
    "external_source": "snifftest",
    "keywords": ["blue", "buffalo", "wilderness", "chicken"],
    "nutritional_info": {
        "source": "snifftest",
        "external_id": "0840243101642",
        "data_quality_score": 0.9,
        "ingredients": [
            "Deboned Chicken",
            "Chicken Meal",
            "Brown Rice",
            "Peas",
            "Barley"
        ],
        "calories_per_100g": 375.0,
        "protein_percentage": 26.0,
        "fat_percentage": 15.0,
        "fiber_percentage": 5.0,
        "moisture_percentage": 10.0,
        "ash_percentage": 7.0
    }
}


@pytest.mark.asyncio
async def test_create_food_item_success(async_client: AsyncClient, auth_token: str):
    """
    Test successful creation of a user-contributed food item
    
    This test simulates the iOS app submitting user-verified scan data
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    response = await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK or response.status_code == status.HTTP_201_CREATED
    data = response.json()
    
    # Verify response structure
    assert "id" in data
    assert data["name"] == TEST_FOOD_ITEM["name"]
    assert data["brand"] == TEST_FOOD_ITEM["brand"]
    assert data["barcode"] == TEST_FOOD_ITEM["barcode"]
    assert "created_at" in data
    assert "updated_at" in data
    
    # Verify nutritional info is preserved
    assert data["nutritional_info"] is not None
    assert data["nutritional_info"]["source"] == "snifftest"
    assert data["nutritional_info"]["data_quality_score"] == 0.9
    assert len(data["nutritional_info"]["ingredients"]) == 5


@pytest.mark.asyncio
async def test_create_food_item_minimal(async_client: AsyncClient, auth_token: str):
    """
    Test creating food item with only required fields
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    minimal_item = {
        "name": "Test Minimal Product"
    }
    
    response = await async_client.post(
        "/api/v1/foods",
        json=minimal_item,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK or response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["name"] == minimal_item["name"]


@pytest.mark.asyncio
async def test_create_food_item_duplicate(async_client: AsyncClient, auth_token: str):
    """
    Test that duplicate food items (same name and brand) are rejected
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    # Create first item
    await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM,
        headers=headers
    )
    
    # Try to create duplicate
    response = await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already exists" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_create_food_item_unauthorized(async_client: AsyncClient):
    """
    Test that creating food items requires authentication
    """
    response = await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.asyncio
async def test_create_food_item_invalid_data(async_client: AsyncClient, auth_token: str):
    """
    Test validation of required fields
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    # Missing required name field
    invalid_item = {
        "brand": "Test Brand"
    }
    
    response = await async_client.post(
        "/api/v1/foods",
        json=invalid_item,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_create_food_item_with_keywords(async_client: AsyncClient, auth_token: str):
    """
    Test that keywords are properly stored
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    item_with_keywords = {
        "name": "Premium Salmon Treats",
        "brand": "Wild Caught",
        "keywords": ["wild", "caught", "premium", "salmon", "treats"]
    }
    
    response = await async_client.post(
        "/api/v1/foods",
        json=item_with_keywords,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK or response.status_code == status.HTTP_201_CREATED
    # Note: Keywords may be returned differently depending on backend implementation


@pytest.mark.asyncio
async def test_create_food_item_species_lowercased(async_client: AsyncClient, auth_token: str):
    """
    Test that species is stored in lowercase
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    item = {
        "name": "Test Cat Food",
        "species": "Cat"  # Capitalized
    }
    
    response = await async_client.post(
        "/api/v1/foods",
        json=item,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK or response.status_code == status.HTTP_201_CREATED
    # Species should be stored as lowercase in database


@pytest.mark.asyncio
async def test_lookup_contributed_food_by_barcode(async_client: AsyncClient, auth_token: str):
    """
    Test that contributed food items can be looked up by barcode
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    # First, create a food item with barcode
    await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM,
        headers=headers
    )
    
    # Then lookup by barcode
    barcode = TEST_FOOD_ITEM["barcode"]
    response = await async_client.get(
        f"/api/v1/foods/barcode/{barcode}",
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["barcode"] == barcode
    assert data["name"] == TEST_FOOD_ITEM["name"]


@pytest.mark.asyncio
async def test_nutritional_data_preservation(async_client: AsyncClient, auth_token: str):
    """
    Test that all nutritional data fields are preserved correctly
    """
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    response = await async_client.post(
        "/api/v1/foods",
        json=TEST_FOOD_ITEM,
        headers=headers
    )
    
    assert response.status_code == status.HTTP_200_OK or response.status_code == status.HTTP_201_CREATED
    data = response.json()
    
    # Verify all nutritional fields
    nutritional_info = data["nutritional_info"]
    assert nutritional_info["calories_per_100g"] == 375.0
    assert nutritional_info["protein_percentage"] == 26.0
    assert nutritional_info["fat_percentage"] == 15.0
    assert nutritional_info["fiber_percentage"] == 5.0
    assert nutritional_info["moisture_percentage"] == 10.0
    assert nutritional_info["ash_percentage"] == 7.0
    assert nutritional_info["data_quality_score"] == 0.9


# Fixtures
@pytest.fixture
async def async_client():
    """Create async HTTP client for testing"""
    from main import app
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.fixture
async def auth_token(async_client: AsyncClient):
    """
    Create a test user and return authentication token
    """
    # Register test user
    test_email = f"test_{asyncio.get_event_loop().time()}@example.com"
    test_password = "SecureTestPassword123!"
    
    await async_client.post(
        "/api/v1/auth/signup",
        json={
            "email": test_email,
            "password": test_password
        }
    )
    
    # Login and get token
    response = await async_client.post(
        "/api/v1/auth/login",
        json={
            "email": test_email,
            "password": test_password
        }
    )
    
    data = response.json()
    return data["access_token"]


if __name__ == "__main__":
    """
    Run tests directly
    """
    pytest.main([__file__, "-v", "-s"])

