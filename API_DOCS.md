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
- [Nutrition API](#nutrition-api)
- [Food Management](#food-management)
- [Advanced Nutrition](#advanced-nutrition)
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

## Nutrition API

### Analyze Food

Analyze food nutritional content and compatibility with pet.

```http
POST /api/v1/nutrition/analysis/analyze
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "food_item_id": "uuid-here",
  "pet_id": "pet-uuid-here",
  "serving_size_g": 100
}
```

**Response:**
```json
{
  "id": "analysis-uuid",
  "food_item_id": "uuid-here",
  "pet_id": "pet-uuid-here",
  "calories": 350,
  "protein_g": 25.0,
  "fat_g": 15.0,
  "carbohydrates_g": 30.0,
  "fiber_g": 3.5,
  "analysis_date": "2025-10-10T10:30:00Z",
  "compatibility_score": 8.5,
  "warnings": []
}
```

### Get Food Analyses

Retrieve food analysis history for a pet.

```http
GET /api/v1/nutrition/analysis/analyses/{pet_id}
Authorization: Bearer <jwt_token>
```

### Check Nutrition Compatibility

Check if a food is compatible with pet's nutritional needs.

```http
POST /api/v1/nutrition/analysis/compatibility
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "food_item_id": "uuid-here",
  "pet_id": "pet-uuid-here"
}
```

### Get Nutritional Requirements

Calculate and retrieve pet's nutritional requirements.

```http
GET /api/v1/nutrition/requirements/{pet_id}
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "pet_id": "pet-uuid-here",
  "daily_calories": 750,
  "protein_g": 50.0,
  "fat_g": 25.0,
  "carbohydrates_g": 85.0,
  "fiber_g": 5.0,
  "calculated_at": "2025-10-10T10:30:00Z"
}
```

### Create Nutritional Requirements

Create custom nutritional requirements for a pet.

```http
POST /api/v1/nutrition/requirements/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "daily_calories": 800,
  "protein_g": 55.0,
  "fat_g": 30.0
}
```

### Log Feeding Record

Log a feeding session for nutrition tracking.

```http
POST /api/v1/nutrition/feeding/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "food_item_id": "uuid-here",
  "amount_g": 150,
  "meal_type": "breakfast",
  "notes": "Regular morning meal"
}
```

### Get Feeding History

Retrieve feeding history for a pet.

```http
GET /api/v1/nutrition/feeding/{pet_id}
Authorization: Bearer <jwt_token>
```

### Get Daily Nutrition Summary

Get aggregated daily nutrition summary for a pet.

```http
GET /api/v1/nutrition/feeding/daily-summary/{pet_id}?date=2025-10-10
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "pet_id": "pet-uuid-here",
  "date": "2025-10-10",
  "total_calories": 720,
  "total_protein_g": 48.0,
  "total_fat_g": 24.0,
  "total_carbs_g": 82.0,
  "meal_count": 3,
  "target_calories": 750,
  "calories_remaining": 30
}
```

### Create Calorie Goal

Set calorie goals for a pet.

```http
POST /api/v1/nutrition/goals/calorie-goals
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "target_calories": 800,
  "goal_type": "weight_loss",
  "start_date": "2025-10-10",
  "end_date": "2025-12-10"
}
```

### Get Calorie Goals

Retrieve all calorie goals for user's pets.

```http
GET /api/v1/nutrition/goals/calorie-goals
Authorization: Bearer <jwt_token>
```

### Get Pet's Active Calorie Goal

Get the active calorie goal for a specific pet.

```http
GET /api/v1/nutrition/goals/calorie-goals/{pet_id}
Authorization: Bearer <jwt_token>
```

### Multi-Pet Nutrition Insights

Get nutrition insights across multiple pets.

```http
GET /api/v1/nutrition/summaries/insights/multi-pet
Authorization: Bearer <jwt_token>
```

### Advanced Nutrition Analytics

Get comprehensive nutrition analytics.

```http
GET /api/v1/nutrition/advanced/analytics/overview?pet_id={pet_id}&date_from=2025-09-01&date_to=2025-10-10
Authorization: Bearer <jwt_token>
```

### Nutrition Insights

Get detailed nutrition insights for a pet.

```http
GET /api/v1/nutrition/advanced/insights/{pet_id}
Authorization: Bearer <jwt_token>
```

### Nutrition Patterns

Analyze nutrition patterns and trends.

```http
GET /api/v1/nutrition/advanced/patterns/{pet_id}
Authorization: Bearer <jwt_token>
```

### Nutrition Trends

Get nutrition trends over time.

```http
GET /api/v1/nutrition/advanced/trends/{pet_id}?period=30
Authorization: Bearer <jwt_token>
```

### Nutrition Recommendations

Get personalized nutrition recommendations.

```http
GET /api/v1/nutrition/advanced/recommendations/{pet_id}
Authorization: Bearer <jwt_token>
```

---

## Food Management

### Search Foods

Search for food items in the database.

```http
GET /api/v1/food-management/search?query=chicken&limit=20&offset=0
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "items": [
    {
      "id": "food-uuid",
      "name": "Chicken & Rice Dog Food",
      "brand": "Premium Pet Foods",
      "barcode": "123456789012",
      "category": "dry_food",
      "species": "dog",
      "calories_per_100g": 350,
      "protein_g": 25.0,
      "fat_g": 12.0,
      "ingredients": ["chicken", "rice", "vegetables"]
    }
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

### Get Food by Barcode

Look up food item by barcode.

```http
GET /api/v1/food-management/barcode/{barcode}
Authorization: Bearer <jwt_token>
```

### Get Recent Foods

Get recently accessed food items.

```http
GET /api/v1/food-management/recent?limit=10
Authorization: Bearer <jwt_token>
```

### Get Food Item

Get detailed information about a specific food item.

```http
GET /api/v1/food-management/{food_id}
Authorization: Bearer <jwt_token>
```

### Create Food Item

Create a new food item in the database.

```http
POST /api/v1/food-management/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Chicken & Rice Dog Food",
  "brand": "Premium Pet Foods",
  "barcode": "123456789012",
  "category": "dry_food",
  "species": "dog",
  "calories_per_100g": 350,
  "protein_g": 25.0,
  "fat_g": 12.0,
  "carbohydrates_g": 30.0,
  "fiber_g": 3.5,
  "ingredients": ["chicken", "rice", "vegetables"]
}
```

### Update Food Item

Update existing food item.

```http
PUT /api/v1/food-management/{food_id}
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Chicken & Rice Dog Food - Updated",
  "calories_per_100g": 355
}
```

### Delete Food Item

Delete a food item.

```http
DELETE /api/v1/food-management/{food_id}
Authorization: Bearer <jwt_token>
```

### Get Food Categories

Get list of available food categories.

```http
GET /api/v1/food-management/categories
Authorization: Bearer <jwt_token>
```

**Response:**
```json
[
  "dry_food",
  "wet_food",
  "treats",
  "supplements",
  "raw_food"
]
```

### Get Food Brands

Get list of available food brands.

```http
GET /api/v1/food-management/brands
Authorization: Bearer <jwt_token>
```

---

## Advanced Nutrition

### Record Pet Weight

Record a weight measurement for a pet.

```http
POST /api/v1/advanced-nutrition/weight/record
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "weight_kg": 25.5,
  "notes": "Post-vet checkup weight"
}
```

### Get Weight History

Retrieve weight history for a pet.

```http
GET /api/v1/advanced-nutrition/weight/history/{pet_id}
Authorization: Bearer <jwt_token>
```

**Response:**
```json
[
  {
    "id": "record-uuid",
    "pet_id": "pet-uuid-here",
    "weight_kg": 25.5,
    "recorded_at": "2025-10-10T10:30:00Z",
    "notes": "Post-vet checkup weight"
  }
]
```

### Create Weight Goal

Set a weight goal for a pet.

```http
POST /api/v1/advanced-nutrition/weight/goals
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "target_weight_kg": 23.0,
  "goal_type": "weight_loss",
  "start_date": "2025-10-10",
  "target_date": "2025-12-10",
  "notes": "Vet recommended weight loss plan"
}
```

### Update Weight Goal

Update an existing weight goal.

```http
PUT /api/v1/advanced-nutrition/weight/goals
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "goal_id": "goal-uuid",
  "target_weight_kg": 22.5,
  "progress_notes": "Good progress, adjusting target"
}
```

### Get Active Weight Goal

Get the active weight goal for a pet.

```http
GET /api/v1/advanced-nutrition/weight/goals/{pet_id}/active
Authorization: Bearer <jwt_token>
```

### Get Weight Trend Analysis

Analyze weight trends over time.

```http
GET /api/v1/advanced-nutrition/weight/trend/{pet_id}?days=30
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "pet_id": "pet-uuid-here",
  "current_weight_kg": 25.5,
  "average_weight_kg": 25.8,
  "trend": "decreasing",
  "change_kg": -0.5,
  "change_percentage": -1.9,
  "period_days": 30
}
```

### Get Weight Management Dashboard

Get comprehensive weight management dashboard.

```http
GET /api/v1/advanced-nutrition/weight/dashboard/{pet_id}
Authorization: Bearer <jwt_token>
```

### Get Nutritional Trends

Get nutritional trends for a pet.

```http
GET /api/v1/advanced-nutrition/trends/{pet_id}?period=30
Authorization: Bearer <jwt_token>
```

### Get Nutritional Trends Dashboard

Get comprehensive nutritional trends dashboard.

```http
GET /api/v1/advanced-nutrition/trends/dashboard/{pet_id}
Authorization: Bearer <jwt_token>
```

### Create Food Comparison

Compare multiple food items.

```http
POST /api/v1/advanced-nutrition/comparisons
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "food_item_ids": ["uuid1", "uuid2", "uuid3"],
  "pet_id": "pet-uuid-here",
  "comparison_notes": "Comparing options for weight loss"
}
```

### Get Food Comparison

Retrieve a specific food comparison.

```http
GET /api/v1/advanced-nutrition/comparisons/{comparison_id}
Authorization: Bearer <jwt_token>
```

### List Food Comparisons

List all food comparisons for user.

```http
GET /api/v1/advanced-nutrition/comparisons
Authorization: Bearer <jwt_token>
```

### Get Comparison Dashboard

Get detailed comparison dashboard with analytics.

```http
GET /api/v1/advanced-nutrition/comparisons/dashboard/{comparison_id}
Authorization: Bearer <jwt_token>
```

### Delete Food Comparison

Delete a food comparison.

```http
DELETE /api/v1/advanced-nutrition/comparisons/{comparison_id}
Authorization: Bearer <jwt_token>
```

### Generate Nutritional Analytics

Generate comprehensive nutritional analytics cache.

```http
POST /api/v1/advanced-nutrition/analytics/generate
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "pet-uuid-here",
  "date_from": "2025-09-01",
  "date_to": "2025-10-10"
}
```

### Get Health Insights

Get AI-powered health insights for a pet.

```http
GET /api/v1/advanced-nutrition/analytics/health-insights/{pet_id}
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "pet_id": "pet-uuid-here",
  "overall_health_score": 8.5,
  "insights": [
    {
      "category": "weight",
      "status": "good",
      "message": "Weight is within healthy range",
      "recommendation": "Maintain current feeding routine"
    }
  ],
  "alerts": [],
  "generated_at": "2025-10-10T10:30:00Z"
}
```

### Get Nutritional Patterns

Analyze nutritional patterns for optimization.

```http
GET /api/v1/advanced-nutrition/analytics/patterns/{pet_id}
Authorization: Bearer <jwt_token>
```

### Get Advanced Nutrition Dashboard

Get comprehensive advanced nutrition dashboard.

```http
GET /api/v1/advanced-nutrition/analytics/dashboard/{pet_id}
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

## API Version History

### v1.0.0 (Current)
- Complete authentication system with MFA
- Pet management with birthday tracking
- Ingredient scanning and analysis
- **NEW**: Comprehensive nutrition tracking API
- **NEW**: Food database with barcode scanning
- **NEW**: Advanced nutrition (weight tracking, trends, comparisons)
- **NEW**: Calorie goals and feeding logs
- **NEW**: Health insights and analytics
- Push notifications (APNs)
- GDPR compliance features
- Health monitoring and metrics

---

*Last updated: January 2025*
*API Version: 1.0.0*
*Production API: https://snifftest-api-production.up.railway.app*
