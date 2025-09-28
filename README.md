# Pet Allergy Scanner

A comprehensive iOS application with FastAPI backend for scanning and analyzing pet food ingredients to identify potential allergens and safety concerns for dogs and cats.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Server Setup](#server-setup)
- [iOS App Setup](#ios-app-setup)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Security Features](#security-features)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## Overview

Pet Allergy Scanner helps pet owners make informed decisions about their pets' food by:

- **Scanning pet food labels** using OCR technology
- **Analyzing ingredients** for species-specific safety and allergen information
- **Managing multiple pet profiles** with individual allergy tracking
- **Providing detailed safety assessments** with recommendations
- **Saving favorite products** for future reference

The application uses AI-powered ingredient analysis with comprehensive databases of pet-safe and potentially harmful ingredients, tailored specifically for dogs and cats.

## Features

### Core Functionality
- 📱 **Mobile-First Design**: Native iOS app with SwiftUI
- 🔍 **OCR Text Extraction**: Camera-based ingredient list scanning
- 🧠 **AI-Powered Analysis**: Intelligent ingredient safety assessment
- 🐕 **Species-Specific Logic**: Different nutritional requirements for dogs vs cats
- 📊 **Detailed Reports**: Comprehensive safety analysis with recommendations

### Design System
- 🎨 **Trust & Nature Palette**: Carefully crafted color scheme for safety and trust
- 🌙 **Dark Mode Support**: Full dark mode compatibility with system colors
- ♿ **Accessibility First**: 4.5:1 contrast ratio minimum for all text
- 🎯 **Consistent Branding**: Cohesive visual identity across all views
- 📱 **Modern UI**: Clean, intuitive interface following Apple's design guidelines

### Pet Management
- 👥 **Multiple Pet Profiles**: Support for multiple pets per user
- 🏥 **Veterinary Information**: Store vet contact details
- ⚠️ **Allergy Tracking**: Track known allergies per pet
- 📈 **Health History**: Monitor ingredient reactions over time

### User Experience
- 🔐 **Secure Authentication**: JWT-based auth with MFA support
- 💾 **Offline Capability**: Core features work without internet
- 🌙 **Dark Mode Support**: Full dark mode compatibility
- ♿ **Accessibility**: VoiceOver and accessibility features
- 🌍 **Localization**: Multi-language support ready

### Security & Privacy
- 🔒 **End-to-End Security**: Encrypted data transmission
- 🛡️ **GDPR Compliance**: Data export and deletion capabilities
- 🔐 **Multi-Factor Authentication**: Enhanced account security
- 📝 **Audit Logging**: Comprehensive activity tracking
- 🚫 **Rate Limiting**: API abuse prevention

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │   FastAPI       │    │   Supabase      │
│   (SwiftUI)     │◄──►│   Backend       │◄──►│   Database      │
│                 │    │                 │    │                 │
│ • Camera/OCR    │    │ • REST API      │    │ • PostgreSQL    │
│ • Pet Profiles  │    │ • Authentication│    │ • Row Level     │
│ • Scan Results  │    │ • Ingredient    │    │   Security      │
│ • Favorites     │    │   Analysis      │    │ • Real-time     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### iOS App Architecture (MVVM)
```
Views/
├── AuthenticationView.swift    # Login/Register
├── MainTabView.swift          # Main navigation
├── PetsView.swift             # Pet management
├── ScanView.swift             # Camera scanning
├── ScanResultView.swift       # Analysis results
└── ProfileView.swift          # User settings

Models/
├── Pet.swift                  # Pet data model
├── User.swift                 # User data model
├── Scan.swift                 # Scan data model
└── Ingredient.swift           # Ingredient model

Services/
├── APIService.swift           # Backend communication
├── AuthService.swift          # Authentication
├── OCRService.swift           # Text extraction
└── PetService.swift           # Pet management
```

### Backend Architecture
```
app/
├── core/
│   └── config.py              # Configuration settings
├── models/
│   ├── user.py               # User data models
│   ├── pet.py                # Pet data models
│   ├── ingredient.py         # Ingredient models
│   └── scan.py               # Scan models
├── routers/
│   ├── auth.py               # Authentication endpoints
│   ├── pets.py               # Pet management
│   ├── ingredients.py        # Ingredient analysis
│   ├── scans.py              # Scan processing
│   ├── mfa.py                # Multi-factor auth
│   ├── gdpr.py               # GDPR compliance
│   └── monitoring.py         # Health monitoring
├── services/
│   ├── gdpr_service.py       # Data management
│   └── mfa_service.py        # MFA implementation
├── middleware/
│   ├── security.py           # Security headers
│   ├── audit.py              # Audit logging
│   └── request_limits.py     # Rate limiting
└── utils/
    ├── error_handling.py     # Error management
    └── security.py           # Security utilities
```

## Tech Stack

### iOS Application
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Architecture**: MVVM with Combine
- **Concurrency**: async/await
- **Networking**: URLSession with async/await
- **Storage**: Keychain for secure data
- **Camera**: AVFoundation for OCR
- **Minimum iOS**: 16.0+

### Backend Server
- **Language**: Python 3.9+
- **Framework**: FastAPI 0.104+
- **Database**: PostgreSQL via Supabase
- **Authentication**: JWT with Supabase Auth
- **Validation**: Pydantic v2
- **Security**: Multiple middleware layers
- **Testing**: pytest with async support
- **Deployment**: ASGI with Uvicorn

### Infrastructure
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime
- **Hosting**: Vercel/Railway/Heroku ready

## Trust & Nature Color Scheme

The Pet Allergy Scanner app uses a carefully crafted "Trust & Nature" color palette designed to convey safety, reliability, and warmth while maintaining excellent accessibility standards.

### Color Palette

#### Primary Colors
- **Deep Forest Green** (`#2D5A3D`): Primary color conveying trust and safety
  - Used for: Primary buttons, active states, safe ingredient indicators
  - Psychology: Associated with nature, growth, and safety

- **Soft Cream** (`#FEFDF8`): Warm background color
  - Used for: Main backgrounds, tab bar, surface elements
  - Psychology: Creates comfort and warmth

- **Golden Yellow** (`#FFD700`): Accent color for premium features
  - Used for: Call-to-action buttons, premium indicators, highlights
  - Psychology: Represents quality and attention-grabbing actions

#### Secondary Colors
- **Charcoal Gray** (`#2C3E50`): Primary text color
  - Used for: All primary text, headings, important information
  - Psychology: Professional, readable, trustworthy

- **Warm Coral** (`#FF7F7F`): Warning/error color
  - Used for: Unsafe ingredients, error states, allergy indicators
  - Psychology: Clear warning without being alarming

- **Light Gray** (`#E0E0E0`): Neutral secondary color
  - Used for: Borders, secondary text, neutral elements
  - Psychology: Subtle, non-intrusive

### Design Principles

#### Accessibility Compliance
- **Contrast Ratio**: All text maintains 4.5:1 contrast ratio minimum
- **Color-Blind Friendly**: Uses shapes and icons alongside colors for status
- **Dark Mode**: Automatic adaptation using system colors where appropriate
- **VoiceOver Support**: All color-coded information has text alternatives

#### Color Usage by View Category

**Main Navigation & Tab Bar**
- Background: Soft Cream (`#FEFDF8`)
- Active tabs: Deep Forest Green (`#2D5A3D`)
- Inactive tabs: Charcoal Gray (`#2C3E50`) at 60% opacity

**Core Scanning Views**
- Background: Deep Forest Green (`#2D5A3D`) - conveys trust and safety
- Scan button: Golden Yellow (`#FFD700`) with white icon
- Safe ingredients: Deep Forest Green background, white text
- Warning ingredients: Warm Coral (`#FF7F7F`) background, white text

**Pet Management Views**
- Background: Soft Cream (`#FEFDF8`)
- Pet cards: White background with Deep Forest Green borders
- Add pet button: Golden Yellow (`#FFD700`)
- Allergy indicators: Warm Coral (`#FF7F7F`)

**Authentication & Security**
- Background: Soft Cream (`#FEFDF8`)
- Primary buttons: Deep Forest Green (`#2D5A3D`)
- Error messages: Warm Coral (`#FF7F7F`)
- Success messages: Deep Forest Green (`#2D5A3D`)

### Implementation

The color scheme is implemented through a centralized `ModernDesignSystem` that provides:

```swift
// Trust & Nature Primary Colors
static let deepForestGreen = Color(red: 0.176, green: 0.353, blue: 0.239)
static let softCream = Color(red: 0.996, green: 0.992, blue: 0.973)
static let goldenYellow = Color(red: 1.0, green: 0.843, blue: 0.0)
static let charcoalGray = Color(red: 0.173, green: 0.243, blue: 0.314)
static let warmCoral = Color(red: 1.0, green: 0.498, blue: 0.498)
static let lightGray = Color(red: 0.878, green: 0.878, blue: 0.878)
```

### Benefits

- **Trust & Safety**: Deep forest green reinforces the app's safety message
- **Warm & Welcoming**: Soft cream backgrounds create comfort
- **Clear Hierarchy**: Color coding makes information easy to scan
- **Professional**: Cohesive design reinforces app credibility
- **Accessible**: Meets WCAG guidelines for color contrast
- **Consistent**: Unified visual language across all features

## Prerequisites

### Development Environment
- **macOS**: 13.0+ (for iOS development)
- **Xcode**: 15.0+
- **Python**: 3.9+
- **Node.js**: 18+ (for tooling)
- **Git**: Latest version

### Accounts Required
- **Apple Developer Account**: For iOS app distribution
- **Supabase Account**: For backend services
- **GitHub Account**: For version control

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/pet-allergy-scanner.git
cd pet-allergy-scanner
```

### 2. Server Setup (5 minutes)
```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp env.example .env
# Edit .env with your Supabase credentials
python start.py
```

### 3. iOS App Setup (5 minutes)
```bash
cd pet-allergy-scanner
open pet-allergy-scanner.xcodeproj
# Update API_BASE_URL in Info.plist
# Build and run in Xcode
```

## Server Setup

### 1. Environment Configuration

Create a `.env` file in the `server/` directory:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url_here
SUPABASE_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here

# FastAPI Configuration
SECRET_KEY=your_strong_secret_key_here_minimum_32_characters
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS Configuration (comma-separated)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,capacitor://localhost,ionic://localhost,http://localhost,https://localhost
ALLOWED_HOSTS=localhost,127.0.0.1

# Database Configuration
DATABASE_URL=postgresql://user:password@localhost:5432/pet_allergy_scanner
DATABASE_POOL_SIZE=10
DATABASE_TIMEOUT=30

# Rate Limiting
RATE_LIMIT_PER_MINUTE=60
AUTH_RATE_LIMIT_PER_MINUTE=5

# File Upload Limits
MAX_FILE_SIZE_MB=10
MAX_REQUEST_SIZE_MB=50

# Security Features
ENABLE_MFA=true
ENABLE_AUDIT_LOGGING=true
SESSION_TIMEOUT_MINUTES=480

# GDPR Compliance
DATA_RETENTION_DAYS=365
ENABLE_DATA_EXPORT=true
ENABLE_DATA_DELETION=true

# Environment
ENVIRONMENT=development
```

### 2. Supabase Setup

1. **Create Supabase Project**:
   - Go to [supabase.com](https://supabase.com)
   - Create new project
   - Note your project URL and API keys

2. **Database Schema**:
   ```bash
   # Copy database_schema.sql content
   # Paste in Supabase SQL Editor
   # Execute to create tables and policies
   ```

3. **Authentication Setup**:
   - Enable email authentication
   - Configure email templates
   - Set up MFA if needed

### 3. Install Dependencies

```bash
cd server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 4. Run the Server

```bash
# Development
python start.py

# Production
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at:
- **API**: `http://localhost:8000`
- **Docs**: `http://localhost:8000/docs`
- **Health**: `http://localhost:8000/health`
- **Monitoring**: `http://localhost:8000/api/v1/monitoring/health`

### 5. Security Configuration

The server includes comprehensive security features that are automatically enabled:

#### Security Middleware Stack
The security middleware is applied in the following order (order matters):

1. **SecurityHeadersMiddleware** - Adds security headers
2. **AuditLogMiddleware** - Logs security events
3. **RateLimitMiddleware** - Enforces rate limits
4. **RequestSizeMiddleware** - Validates request sizes
5. **APIVersionMiddleware** - Handles API versioning
6. **RequestTimeoutMiddleware** - Handles request timeouts
7. **CORSMiddleware** - Handles CORS
8. **TrustedHostMiddleware** - Validates trusted hosts

#### Security Headers
The server automatically adds the following security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `Content-Security-Policy: default-src 'self'`
- `Referrer-Policy: strict-origin-when-cross-origin`

#### Rate Limiting
- **General API**: 60 requests/minute per IP
- **Authentication endpoints**: 5 requests/minute per IP
- **Headers**: Rate limit information included in responses

## iOS App Setup

### 1. Xcode Configuration

1. **Open Project**:
   ```bash
   cd pet-allergy-scanner
   open pet-allergy-scanner.xcodeproj
   ```

2. **Update API Configuration**:
   - Open `Info.plist`
   - Set `API_BASE_URL` to your server URL
   - Example: `http://localhost:8000/api/v1`

3. **Configure Signing**:
   - Select your development team
   - Update bundle identifier
   - Configure capabilities (Camera, Keychain)

### 2. Build and Run

1. **Select Target Device**: iPhone simulator or physical device
2. **Build**: `Cmd + B`
3. **Run**: `Cmd + R`

### 3. Design System

The app uses the **Trust & Nature** color scheme implemented in `ModernDesignSystem.swift`:

- **Primary**: Deep Forest Green (`#2D5A3D`) for trust and safety
- **Background**: Soft Cream (`#FEFDF8`) for warmth and comfort  
- **Accent**: Golden Yellow (`#FFD700`) for call-to-actions
- **Text**: Charcoal Gray (`#2C3E50`) for excellent readability
- **Warning**: Warm Coral (`#FF7F7F`) for unsafe ingredients
- **Neutral**: Light Gray (`#E0E0E0`) for secondary elements

All colors maintain 4.5:1 contrast ratio for accessibility compliance.

### 4. First Launch

1. **Register Account**: Create new user account
2. **Add Pet**: Create your first pet profile
3. **Grant Permissions**: Allow camera access for scanning
4. **Test Scan**: Try scanning a pet food label

## API Documentation

### Authentication Endpoints

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword",
  "first_name": "John",
  "last_name": "Doe"
}
```

#### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```

#### Get Current User
```http
GET /api/v1/auth/me
Authorization: Bearer <jwt_token>
```

### Pet Management

#### Create Pet
```http
POST /api/v1/pets/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Buddy",
  "species": "dog",
  "breed": "Golden Retriever",
  "age_months": 24,
  "weight_kg": 25.5,
  "known_allergies": ["chicken", "corn"],
  "vet_name": "Dr. Smith",
  "vet_phone": "+1234567890"
}
```

#### Get User's Pets
```http
GET /api/v1/pets/
Authorization: Bearer <jwt_token>
```

#### Update Pet
```http
PUT /api/v1/pets/{pet_id}
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "name": "Buddy Updated",
  "known_allergies": ["chicken", "corn", "wheat"]
}
```

### Scan Processing

#### Create Scan
```http
POST /api/v1/scans/
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "uuid-here",
  "image_url": "https://example.com/image.jpg",
  "raw_text": "Chicken, Rice, Corn, Wheat..."
}
```

#### Analyze Ingredients
```http
POST /api/v1/scans/analyze
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "pet_id": "uuid-here",
  "ingredients": ["chicken", "rice", "corn", "wheat"],
  "pet_species": "dog",
  "pet_allergies": ["chicken", "corn"]
}
```

### Ingredient Analysis

#### Get Common Allergens
```http
GET /api/v1/ingredients/common-allergens
Authorization: Bearer <jwt_token>
```

#### Get Safe Alternatives
```http
GET /api/v1/ingredients/safe-alternatives
Authorization: Bearer <jwt_token>
```

### Multi-Factor Authentication

#### Enable MFA
```http
POST /api/v1/mfa/enable
Authorization: Bearer <jwt_token>
```

#### Verify MFA
```http
POST /api/v1/mfa/verify
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "token": "123456"
}
```

### GDPR Compliance

#### Export User Data
```http
GET /api/v1/gdpr/export
Authorization: Bearer <jwt_token>
```

#### Delete User Data
```http
DELETE /api/v1/gdpr/delete
Authorization: Bearer <jwt_token>
```

## Database Schema

### Core Tables

#### Users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    first_name TEXT,
    last_name TEXT,
    role TEXT DEFAULT 'free' CHECK (role IN ('free', 'premium')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Pets
```sql
CREATE TABLE pets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 100),
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat')),
    breed TEXT,
    age_months INTEGER CHECK (age_months >= 0 AND age_months <= 300),
    weight_kg DECIMAL(5,2) CHECK (weight_kg >= 0.1 AND weight_kg <= 200.0),
    known_allergies TEXT[] DEFAULT '{}',
    vet_name TEXT,
    vet_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Ingredients
```sql
CREATE TABLE ingredients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 200),
    aliases TEXT[] DEFAULT '{}',
    safety_level TEXT DEFAULT 'unknown' CHECK (safety_level IN ('safe', 'caution', 'unsafe', 'unknown')),
    species_compatibility TEXT DEFAULT 'both' CHECK (species_compatibility IN ('dog_only', 'cat_only', 'both', 'neither')),
    description TEXT,
    common_allergen BOOLEAN DEFAULT FALSE,
    nutritional_value JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Scans
```sql
CREATE TABLE scans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT,
    raw_text TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS)

All tables implement Row Level Security to ensure users can only access their own data:

```sql
-- Users can only access their own pets
CREATE POLICY "Users can view own pets" ON pets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pets" ON pets
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

## Security Features

### Authentication & Authorization
- **JWT Tokens**: Secure token-based authentication with HS256 algorithm
- **Multi-Factor Authentication**: TOTP-based MFA with QR code generation
- **Session Management**: Configurable session timeouts (default: 8 hours)
- **Password Security**: Bcrypt hashing with salt
- **Backup Codes**: 10 backup codes per user for MFA recovery

### API Security
- **Rate Limiting**: Multi-tier rate limiting system
  - General API: 60 requests/minute per IP
  - Auth endpoints: 5 requests/minute per IP
- **Request Validation**: Pydantic model validation with input sanitization
- **SQL Injection Protection**: Parameterized queries with Supabase
- **CORS Configuration**: Environment-specific origins
- **Security Headers**: Comprehensive security header middleware
- **Request Size Limits**: Configurable file upload and request size limits

### Data Protection
- **Encryption at Rest**: Supabase encryption
- **Encryption in Transit**: TLS 1.3
- **Keychain Storage**: iOS secure storage for tokens
- **Audit Logging**: Comprehensive activity tracking with structured logs
- **Data Anonymization**: GDPR compliance with data anonymization
- **Input Sanitization**: XSS, SQL injection, and HTML injection protection

### Privacy & Compliance
- **GDPR Compliance**: Full GDPR compliance implementation
  - Right of Access: Data export endpoint
  - Right to Rectification: Profile update functionality
  - Right to Erasure: Complete data deletion
  - Right to Data Portability: Structured JSON export
  - Right to Object: Data anonymization
- **Data Retention**: Configurable retention policies (default: 365 days)
- **Privacy by Design**: Minimal data collection principles
- **User Consent**: Clear privacy policies and consent management
- **Data Portability**: Export user data in structured format

### Security Monitoring
- **Health Checks**: Real-time system health monitoring
- **Performance Metrics**: Response time and throughput tracking
- **Security Events**: Automated security event logging
- **Alerting System**: Critical event notifications
- **Audit Trail**: Comprehensive audit logging for compliance

### Security Testing
- **Automated Security Tests**: Comprehensive security test suite
- **Vulnerability Scanning**: Dependency vulnerability checks
- **Penetration Testing**: Regular security assessments
- **Security Audit**: Automated security audit tool

## iOS CORS Configuration

### Overview
iOS apps use custom URL schemes rather than traditional HTTP origins, which requires special CORS configuration for the Pet Allergy Scanner API.

### iOS App URL Schemes

#### Capacitor/Ionic Apps
- **Development**: `capacitor://localhost` or `ionic://localhost`
- **Production**: `capacitor://your-app-id` or `ionic://your-app-id`

#### React Native Apps
- **Development**: `http://localhost:8081` (Metro bundler)
- **Production**: Custom scheme like `yourapp://`

#### Native iOS Apps
- **Custom Scheme**: `yourapp://` (defined in Info.plist)

### Current Configuration

The server is configured to allow the following origins by default:

```python
allowed_origins = [
    "http://localhost:3000",      # Web development
    "http://localhost:8080",      # Web development
    "capacitor://localhost",      # Capacitor iOS development
    "ionic://localhost",          # Ionic iOS development
    "http://localhost",           # General localhost
    "https://localhost"           # HTTPS localhost
]
```

### Production Configuration

For production, update the `ALLOWED_ORIGINS` environment variable:

```bash
# Example production configuration
ALLOWED_ORIGINS=https://yourdomain.com,capacitor://com.yourcompany.petallergyscanner,yourapp://
```

### iOS App Setup

#### 1. Capacitor/Ionic Apps

In your `capacitor.config.ts`:

```typescript
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.yourcompany.petallergyscanner',
  appName: 'Pet Allergy Scanner',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
    iosScheme: 'capacitor'
  }
};

export default config;
```

#### 2. Native iOS Apps

In your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.petallergyscanner</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

### API Client Configuration

#### Swift/iOS Example

```swift
import Foundation

class APIClient {
    private let baseURL = "https://your-api-domain.com/api/v1"
    
    func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
    }
}
```

### Testing CORS Configuration

#### Test with curl

```bash
# Test from iOS app origin
curl -H "Origin: capacitor://localhost" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     -X OPTIONS \
     https://your-api-domain.com/api/v1/auth/login
```

#### Test with JavaScript

```javascript
// Test CORS from iOS app
fetch('https://your-api-domain.com/api/v1/health', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
  },
})
.then(response => response.json())
.then(data => console.log('CORS test successful:', data))
.catch(error => console.error('CORS test failed:', error));
```

### Troubleshooting

#### Common Issues

1. **CORS Error**: "Access to fetch at '...' from origin 'capacitor://localhost' has been blocked by CORS policy"
   - **Solution**: Add your iOS app's URL scheme to `ALLOWED_ORIGINS`

2. **Preflight Request Fails**: OPTIONS request returns 403
   - **Solution**: Ensure CORS middleware is properly configured and origins are correct

3. **Authentication Issues**: JWT tokens not being sent
   - **Solution**: Check that Authorization header is properly set in your API client

#### Debug Steps

1. Check server logs for CORS-related errors
2. Verify the Origin header in browser dev tools
3. Test with different URL schemes
4. Check that the CORS middleware is applied in the correct order

### Security Considerations

1. **Production Origins**: Only add production app schemes to avoid security issues
2. **HTTPS**: Always use HTTPS in production
3. **Token Security**: Store JWT tokens securely (Keychain on iOS)
4. **Certificate Pinning**: Consider implementing certificate pinning for additional security

### Environment-Specific Configuration

#### Development
```bash
ALLOWED_ORIGINS=http://localhost:3000,capacitor://localhost,ionic://localhost
```

#### Staging
```bash
ALLOWED_ORIGINS=https://staging.yourdomain.com,capacitor://com.yourcompany.petallergyscanner.staging
```

#### Production
```bash
ALLOWED_ORIGINS=https://yourdomain.com,capacitor://com.yourcompany.petallergyscanner
```

## Monitoring & Health Checks

### Health Check Endpoints

#### Basic Health Check
```http
GET /health
```

Response:
```json
{
  "status": "healthy",
  "database": "connected",
  "version": "1.0.0"
}
```

#### Detailed Health Check
```http
GET /api/v1/monitoring/health
```

Response:
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

### Metrics Endpoint

```http
GET /api/v1/monitoring/metrics
```

Response:
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "requests": {
    "total": 15420,
    "successful": 15380,
    "failed": 40,
    "rate_per_minute": 45
  },
  "response_times": {
    "average_ms": 120,
    "p95_ms": 250,
    "p99_ms": 500
  },
  "errors": {
    "4xx": 25,
    "5xx": 15
  }
}
```

### Audit Logging

The server maintains comprehensive audit logs in `audit.log`:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "event_type": "authentication",
  "user_id": "uuid-here",
  "ip_address": "192.168.1.100",
  "user_agent": "PetAllergyScanner/1.0.0",
  "success": true,
  "details": {
    "method": "login",
    "endpoint": "/api/v1/auth/login"
  }
}
```

### Security Testing

#### Run Security Tests

```bash
# Run all security tests
cd server
pytest tests/test_security.py -v

# Run specific test categories
pytest tests/test_security.py::TestSecurityValidation -v
pytest tests/test_security.py::TestRateLimiting -v
pytest tests/test_security.py::TestInputValidation -v
```

#### Run Security Audit

```bash
# Run comprehensive security audit
python security_audit.py

# Check for dependency vulnerabilities
pip-audit

# Run security tests with coverage
pytest tests/test_security.py --cov=app --cov-report=html
```

## Development

### Code Standards

#### Swift (iOS)
- **SOLID Principles**: Single responsibility, open/closed, etc.
- **DRY**: Don't repeat yourself
- **KISS**: Keep it simple, stupid
- **Swift Style Guide**: Follow Apple's conventions
- **Documentation**: JSDoc-style comments for functions

#### Python (Backend)
- **PEP 8**: Python style guide compliance
- **Type Hints**: Full type annotation
- **Async/Await**: Modern async patterns
- **Error Handling**: Comprehensive error management
- **Testing**: pytest with async support

### Project Structure

```
pet-allergy-scanner/
├── README.md                 # This file
├── server/                   # FastAPI backend
│   ├── app/
│   │   ├── core/            # Configuration
│   │   ├── models/          # Data models
│   │   ├── routers/         # API endpoints
│   │   ├── services/        # Business logic
│   │   ├── middleware/      # Security & logging
│   │   └── utils/           # Utilities
│   ├── tests/               # Backend tests
│   ├── requirements.txt     # Python dependencies
│   ├── main.py             # FastAPI app
│   └── database_schema.sql # Database schema
├── pet-allergy-scanner/     # iOS app
│   ├── Models/             # Data models
│   ├── Views/              # SwiftUI views
│   ├── Services/           # API & business logic
│   ├── Utils/              # Utilities
│   └── Resources/          # Assets & localization
└── pet-allergy-scannerTests/ # iOS tests
```

### Adding New Features

#### Backend
1. **Create Model**: Add Pydantic model in `app/models/`
2. **Add Router**: Create endpoint in `app/routers/`
3. **Update Schema**: Modify database schema if needed
4. **Add Tests**: Write tests in `tests/`
5. **Update Docs**: Document new endpoints

#### iOS
1. **Create Model**: Add Swift model in `Models/`
2. **Add Service**: Extend `APIService` for new endpoints
3. **Create View**: Add SwiftUI view in `Views/`
4. **Add Tests**: Write unit tests
5. **Update UI**: Integrate with existing navigation

## Testing

### Backend Testing

#### Run Tests
```bash
cd server
python -m pytest tests/ -v
```

#### Test Coverage
```bash
python -m pytest tests/ --cov=app --cov-report=html
```

#### Test Types
- **Unit Tests**: Individual function testing
- **Integration Tests**: API endpoint testing
- **Security Tests**: Authentication and authorization
- **Performance Tests**: Load and stress testing

### iOS Testing

#### Run Tests
```bash
# In Xcode
Cmd + U

# Command line
xcodebuild test -scheme pet-allergy-scanner -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### Test Types
- **Unit Tests**: Model and service testing
- **UI Tests**: User interface testing
- **Integration Tests**: API communication testing
- **Performance Tests**: Memory and CPU profiling

## Deployment

### Backend Deployment

#### Environment Setup
```env
# Production Environment
ENVIRONMENT=production
DEBUG=false

# Security Configuration
SECRET_KEY=your_production_secret_key_32_chars_minimum
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Supabase Production
SUPABASE_URL=your_production_supabase_url
SUPABASE_KEY=your_production_supabase_key
SUPABASE_SERVICE_ROLE_KEY=your_production_service_role_key

# CORS Production
ALLOWED_ORIGINS=https://yourdomain.com,capacitor://com.yourcompany.petallergyscanner
ALLOWED_HOSTS=yourdomain.com

# Database Production
DATABASE_URL=postgresql://user:password@your-db-host:5432/pet_allergy_scanner
DATABASE_POOL_SIZE=20
DATABASE_TIMEOUT=30

# Rate Limiting Production
RATE_LIMIT_PER_MINUTE=100
AUTH_RATE_LIMIT_PER_MINUTE=10

# Security Features
ENABLE_MFA=true
ENABLE_AUDIT_LOGGING=true
SESSION_TIMEOUT_MINUTES=480

# GDPR Compliance
DATA_RETENTION_DAYS=365
ENABLE_DATA_EXPORT=true
ENABLE_DATA_DELETION=true
```

#### Production Server
```bash
# Using Gunicorn (Recommended)
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --keep-alive 2 \
  --max-requests 1000 \
  --max-requests-jitter 100 \
  --access-logfile - \
  --error-logfile -

# Using Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

#### Docker Deployment
```dockerfile
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app
USER app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["gunicorn", "main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
```

#### Docker Compose
```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ENVIRONMENT=production
      - DATABASE_URL=postgresql://user:password@db:5432/pet_allergy_scanner
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
      - SECRET_KEY=${SECRET_KEY}
    depends_on:
      - db
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=pet_allergy_scanner
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

#### Platform Deployment

##### Vercel
```json
{
  "version": 2,
  "builds": [
    {
      "src": "main.py",
      "use": "@vercel/python"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "main.py"
    }
  ],
  "env": {
    "ENVIRONMENT": "production",
    "SUPABASE_URL": "@supabase_url",
    "SUPABASE_KEY": "@supabase_key",
    "SECRET_KEY": "@secret_key"
  }
}
```

##### Railway
```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 10
```

##### Heroku
```procfile
web: gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
```

#### Production Checklist

- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] SSL/TLS certificates installed
- [ ] CORS origins updated for production
- [ ] Rate limiting configured
- [ ] Monitoring and logging set up
- [ ] Backup strategy implemented
- [ ] Security audit completed
- [ ] Performance testing done
- [ ] Health checks configured

### iOS App Deployment

#### App Store Preparation
1. **Version Bump**: Update version and build number
2. **Code Signing**: Configure production certificates
3. **App Store Connect**: Upload build and metadata
4. **Review Process**: Submit for Apple review

#### TestFlight Distribution
1. **Internal Testing**: Team member testing
2. **External Testing**: Beta user testing
3. **Feedback Collection**: User feedback and crash reports

## Contributing

### Getting Started
1. **Fork Repository**: Create your fork
2. **Clone**: `git clone your-fork-url`
3. **Create Branch**: `git checkout -b feature/your-feature`
4. **Make Changes**: Follow coding standards
5. **Test**: Ensure all tests pass
6. **Commit**: `git commit -m "Add your feature"`
7. **Push**: `git push origin feature/your-feature`
8. **Pull Request**: Create PR with description

### Code Review Process
1. **Automated Checks**: CI/CD pipeline validation
2. **Code Review**: Peer review required
3. **Testing**: Manual and automated testing
4. **Documentation**: Update relevant documentation
5. **Merge**: Squash and merge to main

### Development Guidelines
- **Commit Messages**: Clear and descriptive
- **Code Style**: Follow project conventions
- **Testing**: Write tests for new features
- **Documentation**: Update README and code comments
- **Security**: Consider security implications

## License

### Third-Party Licenses
- **FastAPI**: MIT License
- **SwiftUI**: Apple License
- **Supabase**: Apache 2.0 License
- **Other Dependencies**: See individual license files

## Support

### Documentation
- **API Docs**: Available at `/docs` when server is running
- **iOS Documentation**: In-code documentation and comments
- **Database Schema**: See `database_schema.sql`

### Community
- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: General questions and ideas
- **Email**: Direct support contact

---

**Built with ❤️ for pet owners everywhere**

*Last updated: October 2025*