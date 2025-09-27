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

### 3. First Launch

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
- **JWT Tokens**: Secure token-based authentication
- **Multi-Factor Authentication**: TOTP-based MFA support
- **Session Management**: Configurable session timeouts
- **Password Security**: Bcrypt hashing with salt

### API Security
- **Rate Limiting**: Per-user and per-endpoint limits
- **Request Validation**: Pydantic model validation
- **SQL Injection Protection**: Parameterized queries
- **CORS Configuration**: Restricted origins
- **Security Headers**: HSTS, CSP, X-Frame-Options

### Data Protection
- **Encryption at Rest**: Supabase encryption
- **Encryption in Transit**: TLS 1.3
- **Keychain Storage**: iOS secure storage
- **Audit Logging**: Comprehensive activity tracking
- **Data Anonymization**: GDPR compliance

### Privacy & Compliance
- **GDPR Compliance**: Data export and deletion
- **Data Retention**: Configurable retention policies
- **Privacy by Design**: Minimal data collection
- **User Consent**: Clear privacy policies
- **Data Portability**: Export user data

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
ENVIRONMENT=production
DEBUG=false
SECRET_KEY=your_production_secret_key
SUPABASE_URL=your_production_supabase_url
SUPABASE_KEY=your_production_supabase_key
```

#### Production Server
```bash
# Using Gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

# Using Uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

#### Docker Deployment
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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

*Last updated: January 2025*