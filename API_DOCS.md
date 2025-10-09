# Pet Allergy Scanner API Documentation

Complete API reference for the Pet Allergy Scanner backend service.

## Table of Contents

- [Base URL](#base-url)
- [Interactive API Documentation](#interactive-api-documentation)
- [Authentication](#authentication)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Authentication Endpoints](#authentication-endpoints)
- [Pet Management](#pet-management)
- [Scan Processing](#scan-processing)
- [Ingredient Analysis](#ingredient-analysis)
- [Multi-Factor Authentication](#multi-factor-authentication)
- [Push Notifications](#push-notifications)
- [GDPR Compliance](#gdpr-compliance)
- [Monitoring & Health](#monitoring--health)
- [Data Models](#data-models)

## Base URL

```
Development: http://localhost:8000/api/v1
Production: https://snifftest-api-production.up.railway.app/api/v1
```

## Interactive API Documentation

FastAPI provides auto-generated interactive documentation:

### Development (localhost)
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

### Production
- **Swagger UI**: https://snifftest-api-production.up.railway.app/docs
- **ReDoc**: https://snifftest-api-production.up.railway.app/redoc
- **OpenAPI Schema**: https://snifftest-api-production.up.railway.app/openapi.json

> **Note**: Interactive docs are only enabled when `DEBUG=true` is set in environment variables for security reasons.

## Authentication

All API endpoints (except health checks) require authentication via JWT Bearer token:

```http
Authorization: Bearer <jwt_token>
```

## Error Handling

The API uses standard HTTP status codes and returns structured error responses:

```json
{
  "detail": "Error message",
  "error_code": "SPECIFIC_ERROR_CODE",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Common Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Validation Error
- `429` - Rate Limited
- `500` - Internal Server Error

## Rate Limiting

- **General API**: 60 requests/minute per IP
- **Authentication endpoints**: 5 requests/minute per IP
- **Headers included in responses**:
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

---

## Authentication Endpoints

### Register User

Create a new user account.

```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword",
  "username": "johndoe",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "user": {
    "id": "uuid-here",
    "email": "user@example.com",
    "username": "johndoe",
    "first_name": "John",
    "last_name": "Doe",
    "role": "free",
    "onboarded": false,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

### Login

Authenticate user with email or username.

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email_or_username": "user@example.com",
  "password": "securepassword"
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "user": {
    "id": "uuid-here",
    "email": "user@example.com",
    "username": "johndoe",
    "first_name": "John",
    "last_name": "Doe",
    "role": "free",
    "onboarded": true,
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

### Get Current User

Retrieve current user information.

```http
GET /api/v1/auth/me
Authorization: Bearer <jwt_token>
```

### Update User Profile

Update user profile information.

```http
PUT /api/v1/auth/me
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "username": "newusername",
  "first_name": "John",
  "last_name": "Doe",
  "onboarded": true
}
```

### Complete Onboarding

Mark user as having completed onboarding.

```http
POST /api/v1/auth/complete-onboarding
Authorization: Bearer <jwt_token>
```

---

## Pet Management

### Create Pet

Create a new pet profile.

```http
POST /api/v1/pets/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Buddy",
  "species": "dog",
  "breed": "Golden Retriever",
  "birthday": "2022-01-15",
  "weight_kg": 25.5,
  "known_sensitivities": ["chicken", "corn"],
  "vet_name": "Dr. Smith",
  "vet_phone": "+1234567890"
}
```

**Response:**
```json
{
  "id": "pet-uuid-here",
  "user_id": "user-uuid-here",
  "name": "Buddy",
  "species": "dog",
  "breed": "Golden Retriever",
  "birthday": "2022-01-15",
  "weight_kg": 25.5,
  "known_sensitivities": ["chicken", "corn"],
  "vet_name": "Dr. Smith",
  "vet_phone": "+1234567890",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Get User's Pets

Retrieve all pets for the authenticated user.

```http
GET /api/v1/pets/
Authorization: Bearer <jwt_token>
```

**Response:**
```json
[
  {
    "id": "pet-uuid-here",
    "user_id": "user-uuid-here",
    "name": "Buddy",
    "species": "dog",
    "breed": "Golden Retriever",
    "birthday": "2022-01-15",
    "weight_kg": 25.5,
    "known_sensitivities": ["chicken", "corn"],
    "vet_name": "Dr. Smith",
    "vet_phone": "+1234567890",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

### Get Specific Pet

Retrieve a specific pet by ID.

```http
GET /api/v1/pets/{pet_id}
Authorization: Bearer <jwt_token>
```

### Update Pet

Update pet profile information.

```http
PUT /api/v1/pets/{pet_id}
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Buddy Updated",
  "birthday": "2022-01-15",
  "weight_kg": 26.0,
  "known_sensitivities": ["chicken", "corn", "wheat"]
}
```

### Delete Pet

Delete a pet profile.

```http
DELETE /api/v1/pets/{pet_id}
Authorization: Bearer <jwt_token>
```

---

## Scan Processing

### Create Scan

Create a new scan record.

```http
POST /api/v1/scans/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "image_url": "https://example.com/image.jpg",
  "raw_text": "Chicken, Rice, Corn, Wheat..."
}
```

**Response:**
```json
{
  "id": "scan-uuid-here",
  "user_id": "user-uuid-here",
  "pet_id": "pet-uuid-here",
  "image_url": "https://example.com/image.jpg",
  "raw_text": "Chicken, Rice, Corn, Wheat...",
  "status": "pending",
  "result": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Analyze Ingredients

Analyze ingredients for safety and compatibility.

```http
POST /api/v1/scans/analyze
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "ingredients": ["chicken", "rice", "corn", "wheat"],
  "pet_species": "dog",
  "pet_sensitivities": ["chicken", "corn"]
}
```

**Response:**
```json
{
  "safety_status": "caution",
  "overall_score": 6.5,
  "ingredient_analysis": [
    {
      "name": "chicken",
      "safety_level": "caution",
      "is_allergen": true,
      "warning": "Known allergen for this pet"
    },
    {
      "name": "rice",
      "safety_level": "safe",
      "is_allergen": false,
      "warning": null
    }
  ],
  "recommendations": [
    "Avoid this product due to chicken content",
    "Consider alternative protein sources"
  ]
}
```

### Get Scan History

Retrieve user's scan history.

```http
GET /api/v1/scans/
Authorization: Bearer <jwt_token>
```

### Get Specific Scan

Retrieve a specific scan by ID.

```http
GET /api/v1/scans/{scan_id}
Authorization: Bearer <jwt_token>
```

### Update Scan

Update scan information.

```http
PUT /api/v1/scans/{scan_id}
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "status": "completed",
  "result": {
    "safety_status": "caution",
    "warnings": ["Contains known allergen: chicken"]
  }
}
```

### Delete Scan

Delete a scan record.

```http
DELETE /api/v1/scans/{scan_id}
Authorization: Bearer <jwt_token>
```

---

## Ingredient Analysis

### Get Ingredients

Search and filter ingredients.

```http
GET /api/v1/ingredients/?search=chicken&safety_level=caution
Authorization: Bearer <jwt_token>
```

### Get Common Allergens

Retrieve list of common pet allergens.

```http
GET /api/v1/ingredients/common-allergens
Authorization: Bearer <jwt_token>
```

### Get Safe Alternatives

Get safe ingredient alternatives.

```http
GET /api/v1/ingredients/safe-alternatives
Authorization: Bearer <jwt_token>
```

---

## Multi-Factor Authentication

### Enable MFA

Enable multi-factor authentication for user account.

```http
POST /api/v1/mfa/enable
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
  "secret_key": "JBSWY3DPEHPK3PXP",
  "backup_codes": [
    "12345678",
    "87654321",
    "11223344"
  ]
}
```

### Verify MFA

Verify MFA token during login.

```http
POST /api/v1/mfa/verify
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "token": "123456"
}
```

### Disable MFA

Disable multi-factor authentication.

```http
POST /api/v1/mfa/disable
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "token": "123456"
}
```

### Get Backup Codes

Retrieve current backup codes.

```http
GET /api/v1/mfa/backup-codes
Authorization: Bearer <jwt_token>
```

### Regenerate Backup Codes

Generate new backup codes.

```http
POST /api/v1/mfa/regenerate-backup-codes
Authorization: Bearer <jwt_token>
```

---

## Push Notifications

### Register Device Token

Register device for push notifications.

```http
POST /api/v1/notifications/register-device
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "device_token": "apns_device_token_here"
}
```

### Send Push Notification

Send push notification to device.

```http
POST /api/v1/notifications/send
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "device_token": "apns_device_token_here",
  "payload": {
    "title": "Pet Birthday!",
    "body": "It's Buddy's birthday today!",
    "data": {
      "type": "birthday",
      "pet_id": "pet-uuid-here"
    }
  }
}
```

---

## GDPR Compliance

### Export User Data

Export all user data in structured format.

```http
GET /api/v1/gdpr/export
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "user_data": {
    "profile": { /* user profile data */ },
    "pets": [ /* pet data */ ],
    "scans": [ /* scan history */ ],
    "favorites": [ /* saved products */ ]
  },
  "exported_at": "2024-01-15T10:30:00Z"
}
```

### Delete User Data

Permanently delete all user data.

```http
DELETE /api/v1/gdpr/delete
Authorization: Bearer <jwt_token>
```

---

## Monitoring & Health

### Basic Health Check

```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "version": "1.0.0"
}
```

### Detailed Health Check

```http
GET /api/v1/monitoring/health
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "database": {
    "status": "connected",
    "response_time_ms": 15
  },
  "memory": {
    "used_mb": 128,
    "available_mb": 896
  },
  "disk": {
    "used_gb": 2.5,
    "available_gb": 47.5
  }
}
```

### Get Metrics

```http
GET /api/v1/monitoring/metrics?hours=24
Authorization: Bearer <jwt_token>
```

---

## Data Models

### User Model

```typescript
interface User {
  id: string;
  email: string;
  username?: string;
  first_name?: string;
  last_name?: string;
  image_url?: string;
  role: 'free' | 'premium';
  onboarded: boolean;
  device_token?: string;
  created_at: string;
  updated_at: string;
}
```

### Pet Model

```typescript
interface Pet {
  id: string;
  user_id: string;
  name: string;
  species: 'dog' | 'cat';
  breed?: string;
  birthday?: string; // ISO date
  weight_kg?: number;
  known_sensitivities: string[];
  vet_name?: string;
  vet_phone?: string;
  created_at: string;
  updated_at: string;
}
```

### Scan Model

```typescript
interface Scan {
  id: string;
  user_id: string;
  pet_id: string;
  image_url?: string;
  raw_text?: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  result?: {
    safety_status: 'safe' | 'caution' | 'unsafe';
    overall_score: number;
    ingredient_analysis: IngredientAnalysis[];
    recommendations: string[];
  };
  created_at: string;
  updated_at: string;
}
```

### Ingredient Analysis Model

```typescript
interface IngredientAnalysis {
  name: string;
  safety_level: 'safe' | 'caution' | 'unsafe' | 'unknown';
  is_allergen: boolean;
  warning?: string;
  species_compatibility: 'dog_only' | 'cat_only' | 'both' | 'neither';
  description?: string;
}
```

---

## SDK Examples

### Swift/iOS

```swift
import Foundation

class PetAllergyScannerAPI {
    private let baseURL = "https://snifftest-api-production.up.railway.app/api/v1"
    private let session = URLSession.shared
    
    func createPet(_ pet: PetCreate) async throws -> Pet {
        let url = URL(string: baseURL + "/pets/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let data = try JSONEncoder().encode(pet)
        request.httpBody = data
        
        let (responseData, _) = try await session.data(for: request)
        return try JSONDecoder().decode(Pet.self, from: responseData)
    }
}
```

### Python

```python
import requests
import json

class PetAllergyScannerAPI:
    def __init__(self, base_url, auth_token):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
    
    def create_pet(self, pet_data):
        response = requests.post(
            f'{self.base_url}/pets/',
            headers=self.headers,
            json=pet_data
        )
        response.raise_for_status()
        return response.json()
```

---

*Last updated: October 2025*
*Production API: https://snifftest-api-production.up.railway.app*
