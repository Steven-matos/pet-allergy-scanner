# SniffTest

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

## Overview

SniffTest helps pet owners make informed decisions about their pets' food by:

- **Scanning pet food labels** using OCR technology
- **Analyzing ingredients** for species-specific safety and allergen information
- **Managing multiple pet profiles** with individual allergy tracking
- **Providing detailed safety assessments** with recommendations
- **Saving favorite products** for future reference

The application uses AI-powered ingredient analysis with comprehensive databases of pet-safe and potentially harmful ingredients, tailored specifically for dogs and cats.

## Features

### Core Functionality
- 📱 **Native iOS App**: Built with SwiftUI for iOS 17.0+ (v5.1)
- 🔍 **Camera Scanning**: Real-time OCR and barcode scanning for pet food labels
- 🧠 **AI-Powered Analysis**: Intelligent ingredient safety assessment with species-specific logic
- 🐕 **Pet Profiles**: Complete pet management with birthday tracking and age calculation
- 📊 **Safety Reports**: Detailed ingredient analysis with personalized recommendations
- 💾 **Offline Support**: Core scanning features work without internet connection
- 🥗 **Nutrition Tracking**: Comprehensive feeding logs, calorie goals, and nutritional analysis
- ⚖️ **Weight Management**: Track pet weight trends and set health goals
- 📱 **Food Database**: Searchable database with barcode lookup and nutritional info

### User Experience & Onboarding
- 🎯 **Guided Onboarding**: Step-by-step pet profile creation for new users
- 🎂 **Birthday Celebrations**: Push notifications for pet birthdays with celebration views
- 📱 **Modern Design**: Trust & Nature color palette with 4.5:1 contrast ratio
- 🌙 **Dark Mode**: Full system dark mode compatibility
- ♿ **Accessibility**: VoiceOver support and accessibility-first design
- 🔄 **Smart Navigation**: Context-aware tab navigation and deep linking

### Pet Management
- 👥 **Multiple Pet Profiles**: Support for unlimited pets per user
- 🎂 **Birthday Tracking**: Automatic age calculation and birthday reminders
- ⚖️ **Weight Management**: Track pet weight for size-appropriate recommendations
- 🏥 **Veterinary Integration**: Store vet contact information and notes
- ⚠️ **Sensitivity Tracking**: Comprehensive allergy and sensitivity management
- 📸 **Pet Photos**: Image upload and management for pet profiles

### Scanning & Analysis
- 📷 **Camera Integration**: Real-time camera view with OCR text extraction
- 📱 **Barcode Scanning**: Quick product lookup via barcode
- 🔍 **Ingredient Analysis**: Species-specific safety assessment (dogs vs cats)
- ⚠️ **Allergy Alerts**: Instant warnings for known pet sensitivities
- 📋 **Scan History**: Complete history of all scans with search and filtering
- ❤️ **Favorites**: Save safe products for quick reference
- 📊 **Detailed Reports**: Comprehensive safety analysis with recommendations
- 🥗 **Nutrition Facts**: Full nutritional breakdown with macros and calories

### Nutrition & Health Tracking
- 🍽️ **Feeding Logs**: Track daily meals with timestamps and portions
- 📊 **Calorie Tracking**: Monitor daily calorie intake vs goals
- 🎯 **Calorie Goals**: Set custom calorie targets for weight management
- 📈 **Nutritional Trends**: Analyze nutrition patterns over time
- ⚖️ **Weight Tracking**: Record and monitor pet weight changes
- 🎯 **Weight Goals**: Set target weight with progress tracking
- 🔄 **Food Comparisons**: Compare multiple foods side-by-side
- 🧠 **Health Insights**: AI-powered health recommendations
- 📱 **Daily Summaries**: View nutritional intake summaries by day
- 🏆 **Multi-Pet Insights**: Track nutrition across all your pets

### Notifications & Engagement
- 🔔 **Push Notifications**: Birthday reminders and important updates
- 🎉 **Birthday Celebrations**: Special celebration views for pet birthdays
- 📱 **Smart Notifications**: Context-aware notification scheduling
- 🔄 **Background Sync**: Automatic data synchronization when app becomes active

### Security & Privacy
- 🔐 **Multi-Factor Authentication**: TOTP-based MFA with backup codes
- 🛡️ **GDPR Compliance**: Complete data export and deletion capabilities
- 🔒 **End-to-End Security**: Encrypted data transmission with certificate pinning
- 📝 **Audit Logging**: Comprehensive activity tracking and security monitoring
- 🚫 **Rate Limiting**: Multi-tier API protection against abuse
- 🔑 **Secure Storage**: Keychain integration for sensitive data

### Advanced Features
- 💳 **Subscription Management**: Premium features and subscription handling
- 🌍 **Localization Ready**: Multi-language support infrastructure
- 📊 **Analytics**: User behavior tracking and performance monitoring
- 🔧 **Settings Management**: Comprehensive app configuration options
- 🧪 **Testing Suite**: Complete unit and integration test coverage

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

### iOS App Architecture (MVVM + Combine)
```
Features/
├── Authentication/
│   ├── Views/
│   │   ├── AuthenticationView.swift      # Login/Register with MFA
│   │   ├── ForgotPasswordView.swift      # Password recovery
│   │   └── MFASetupView.swift            # Multi-factor authentication
│   ├── Services/
│   │   ├── AuthService.swift             # Authentication logic
│   │   ├── CachedAuthService.swift       # Cached auth state
│   │   ├── MFAService.swift              # MFA implementation
│   │   └── KeychainHelper.swift          # Secure token storage
│   └── Models/
│       ├── User.swift                    # User data model
│       └── MFAModels.swift               # MFA-related models
├── Scanning/
│   ├── Views/
│   │   ├── ScanView.swift                # Main scanning interface
│   │   ├── ModernCameraView.swift        # Camera implementation
│   │   ├── CameraControlsView.swift      # Camera UI controls
│   │   ├── ScanResultView.swift          # Analysis results
│   │   ├── ScanOverlayView.swift         # Camera overlay UI
│   │   └── ImagePickerView.swift         # Photo library picker
│   ├── Services/
│   │   ├── ScanService.swift             # Scan processing
│   │   ├── OCRService.swift              # Text extraction
│   │   ├── BarcodeService.swift          # Barcode scanning
│   │   ├── HybridScanService.swift       # Combined OCR + barcode
│   │   └── CameraPermissionService.swift # Camera permissions
│   └── Models/
│       ├── Scan.swift                    # Scan data model
│       └── Ingredient.swift              # Ingredient model
├── Nutrition/
│   ├── Views/
│   │   ├── NutritionDashboardView.swift  # Main nutrition view
│   │   ├── AdvancedNutritionView.swift   # Advanced analytics
│   │   ├── FeedingLogView.swift          # Feeding history
│   │   ├── CalorieGoalsView.swift        # Calorie goal management
│   │   ├── WeightManagementView.swift    # Weight tracking
│   │   ├── NutritionalTrendsView.swift   # Trends and patterns
│   │   ├── FoodComparisonView.swift      # Compare foods
│   │   └── FoodSelectionView.swift       # Food picker
│   ├── Services/
│   │   ├── NutritionService.swift        # Nutrition API calls
│   │   ├── FoodService.swift             # Food database access
│   │   ├── FeedingLogService.swift       # Feeding logs
│   │   ├── CalorieGoalsService.swift     # Calorie goals
│   │   ├── WeightTrackingService.swift   # Weight tracking
│   │   ├── FoodComparisonService.swift   # Food comparison
│   │   └── NutritionalTrendsService.swift # Trend analysis
│   ├── ViewModels/
│   │   └── NutritionActivityViewModel.swift # Nutrition state
│   └── Models/
│       └── NutritionModels.swift         # Nutrition data models
├── Pets/
│   ├── Views/
│   │   ├── PetsView.swift                # Pet list
│   │   ├── AddPetView.swift              # Create pet
│   │   ├── EditPetView.swift             # Edit pet
│   │   ├── PetSelectionView.swift        # Pet picker
│   │   └── PetImagePickerView.swift      # Pet photo picker
│   ├── Services/
│   │   ├── PetService.swift              # Pet API calls
│   │   └── CachedPetService.swift        # Cached pet data
│   └── Models/
│       └── Pet.swift                     # Pet data model
├── Profile/
│   ├── Views/
│   │   ├── ProfileSettingsView.swift     # User settings
│   │   ├── EditProfileView.swift         # Profile editing
│   │   └── BirthdayCelebrationView.swift # Birthday UI
│   └── Services/
│       └── StorageService.swift          # Image storage
├── Notifications/
│   ├── Views/
│   │   ├── NotificationSettingsView.swift # Notification prefs
│   │   └── NotificationTestView.swift    # Testing tools
│   └── Services/
│       ├── NotificationManager.swift     # Notification scheduling
│       ├── NotificationService.swift     # Notification API
│       ├── PushNotificationService.swift # APNs integration
│       └── NotificationSettingsManager.swift # Settings persistence
├── History/
│   └── Views/
│       └── HistoryView.swift             # Scan history
├── Onboarding/
│   └── Views/
│       └── OnboardingView.swift          # First-time user flow
├── Settings/
│   └── Services/
│       └── WeightUnitPreferenceService.swift # Unit preferences
├── Subscription/
│   └── Views/
│       └── SubscriptionView.swift        # Premium features
└── Help/
    └── Views/
        └── HelpSupportView.swift         # Support resources

Shared/
├── Models/
│   ├── Pet.swift                      # Pet data model with birthday tracking
│   ├── User.swift                     # User data model with onboarding
│   ├── Scan.swift                     # Scan data model
│   └── Ingredient.swift               # Ingredient analysis model
├── Services/
│   ├── APIService.swift               # Backend communication
│   ├── CacheManager.swift             # Data caching and persistence
│   ├── GDPRService.swift              # Data export/deletion
│   ├── MonitoringService.swift        # Analytics and performance
│   ├── ImageProcessingService.swift   # Image optimization
│   ├── NetworkMonitor.swift           # Network connectivity
│   ├── SupabaseService.swift          # Supabase integration
│   └── URLHandler.swift               # Deep linking and URL handling
├── Utils/
│   ├── ModernDesignSystem.swift       # Trust & Nature design system
│   ├── AnalyticsManager.swift         # User behavior tracking
│   ├── SecurityManager.swift          # Security utilities
│   ├── SecureDataManager.swift        # Encrypted data management
│   ├── CertificatePinning.swift       # SSL certificate pinning
│   ├── HapticFeedback.swift           # Tactile feedback
│   ├── InputValidator.swift           # Form validation
│   └── LocalizationHelper.swift       # Internationalization
└── Views/
    ├── CommonComponents.swift         # Reusable UI components
    ├── LoadingView.swift              # Loading states
    ├── EmptyStateView.swift           # Empty state UI
    ├── ErrorView.swift                # Error displays
    ├── ConfirmationDialog.swift       # Confirmation modals
    └── ToastView.swift                # Toast notifications
```

### Backend Architecture
```
app/
├── core/
│   ├── config.py              # Configuration and settings management
│   ├── database/              # Database connection and pooling
│   ├── security/              # Security utilities and JWT validation
│   ├── middleware/            # Core middleware implementations
│   └── validation/            # Request validation schemas
├── models/
│   ├── user.py               # User data models with onboarding support
│   ├── pet.py                # Pet data models with birthday tracking
│   ├── ingredient.py         # Ingredient analysis and safety models
│   ├── scan.py               # Scan processing and result models
│   ├── nutrition.py          # Nutritional data models
│   ├── advanced_nutrition.py # Weight tracking and analytics models
│   ├── food_items.py         # Food database models
│   └── calorie_goals.py      # Calorie goal tracking models
├── routers/
│   ├── auth.py               # Authentication and user management
│   ├── pets.py               # Pet CRUD operations and management
│   ├── ingredients.py        # Ingredient analysis and safety data
│   ├── scans.py              # Scan processing and analysis
│   ├── nutritional_analysis.py # Nutritional analysis and calculations
│   ├── food_management.py    # Food database management with barcode
│   ├── advanced_nutrition.py # Weight tracking, trends, comparisons
│   ├── mfa.py                # Multi-factor authentication
│   ├── gdpr.py               # GDPR compliance and data management
│   ├── monitoring.py         # Health monitoring and metrics
│   ├── notifications.py      # Push notification management
│   └── images.py             # Image processing and optimization
├── api/v1/
│   ├── nutrition/            # Structured nutrition API
│   │   ├── analysis/         # Food analysis endpoints
│   │   ├── feeding/          # Feeding log endpoints
│   │   ├── goals/            # Calorie goal endpoints
│   │   ├── requirements/     # Nutritional requirements
│   │   ├── summaries/        # Daily nutrition summaries
│   │   └── advanced/         # Advanced analytics and insights
│   └── advanced_nutrition/   # Advanced nutrition features
│       ├── weight/           # Weight tracking endpoints
│       ├── trends/           # Nutritional trends
│       ├── comparisons/      # Food comparison endpoints
│       └── analytics/        # Health insights and patterns
├── services/
│   ├── gdpr_service.py       # Data export and deletion services
│   ├── mfa_service.py        # MFA implementation and management
│   ├── push_notification_service.py # APNs integration
│   ├── monitoring.py         # Analytics and performance monitoring
│   ├── nutritional_calculator.py # Nutritional calculations
│   ├── nutritional_trends_service.py # Trend analysis
│   ├── food_comparison_service.py # Food comparison logic
│   ├── weight_tracking_service.py # Weight tracking service
│   └── advanced_analytics_service.py # AI-powered insights
├── middleware/
│   ├── security.py           # Security headers and protection
│   ├── audit.py              # Comprehensive audit logging
│   └── request_limits.py     # Multi-tier rate limiting
└── utils/
    ├── error_handling.py     # Centralized error management
    ├── security.py           # Security utilities and validation
    └── logging_config.py     # Structured logging configuration
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
- **Minimum iOS**: 17.0+

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

The SniffTest app uses a carefully crafted "Trust & Nature" color palette designed to convey safety, reliability, and warmth while maintaining excellent accessibility standards.

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
git clone https://github.com/yourusername/SniffTest.git
cd SniffTest
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
cd SniffTest
open SniffTest.xcodeproj
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
# Get this from your Supabase project dashboard > Settings > API > JWT Secret
SUPABASE_JWT_SECRET=your_supabase_jwt_secret_here

# FastAPI Configuration
SECRET_KEY=your_strong_secret_key_here_minimum_32_characters
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS Configuration (comma-separated)
# Development origins
ALLOWED_ORIGINS_STR=http://localhost:3000,http://localhost:8080,http://localhost,https://localhost,capacitor://localhost,ionic://localhost,SniffTest://,SniffTest://localhost,https://api.petallergyscanner.com,https://petallergyscanner.com
ALLOWED_HOSTS_STR=localhost,127.0.0.1

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
DEBUG=true

# Push Notification Configuration (APNs)
# For development, use sandbox URL. For production, use production URL
APNS_URL=https://api.sandbox.push.apple.com
# Get these from your Apple Developer account
APNS_KEY_ID=your_apns_key_id_here
APNS_TEAM_ID=your_apns_team_id_here
APNS_BUNDLE_ID=com.yourcompany.pet-allergy-scanner
# APNs private key content (P8 format) - single line
APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nyour_apns_private_key_content_here\n-----END PRIVATE KEY-----"
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
2. **AuditLogMiddleware** - Logs security events (disabled in production to avoid Railway rate limits)
3. **RateLimitMiddleware** - Enforces rate limits
4. **RequestSizeMiddleware** - Validates request sizes
5. **APIVersionMiddleware** - Handles API versioning
6. **RequestTimeoutMiddleware** - Handles request timeouts
7. **CORSMiddleware** - Handles CORS
8. **TrustedHostMiddleware** - Validates trusted hosts

#### Authentication System
- **Robust JWT Validation**: Multi-strategy validation with Supabase and server secret support
- **Lenient Token Validation**: Allows expired tokens during debugging while maintaining security
- **Comprehensive Error Logging**: Detailed authentication failure analysis
- **Service Role Integration**: Bypasses RLS policies for system operations
- **Token Analysis**: Automatic token payload inspection for debugging

#### Database Security
- **Row Level Security (RLS)**: Comprehensive RLS policies for all tables
- **Service Role Client**: Used for system operations that bypass RLS
- **Policy Enforcement**: Users can only access their own data
- **Automatic User Creation**: Handles missing user records gracefully

### 6. Logging Configuration

The server uses a centralized structured logging system:

#### Logging Features
- **Structured Logging**: JSON-formatted logs with timestamps and levels
- **Request/Response Logging**: Automatic logging of API requests
- **Error Tracking**: Comprehensive error logging with stack traces
- **Security Event Logging**: Audit trail for security-related events
- **Performance Monitoring**: Request duration tracking

#### Log Levels
Configure via `LOG_LEVEL` environment variable:
- `DEBUG`: Detailed debugging information
- `INFO`: General informational messages (default)
- `WARNING`: Warning messages
- `ERROR`: Error messages
- `CRITICAL`: Critical failure messages

#### Log Files
- **Application Logs**: Console output (stdout/stderr)
- **Audit Logs**: `logs/audit.log` (when audit middleware enabled)
- **Rotation**: Automatic log rotation for production

#### Configuration
```env
# Logging Configuration
LOG_LEVEL=INFO
VERBOSE_LOGGING=false
ENABLE_AUDIT_LOGGING=true
```

#### Security Headers
The server automatically adds security headers:
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
   - Current settings:
     - **Bundle ID**: `com.snifftest.app`
     - **Version**: `5.1` (Build 6)
     - **API_BASE_URL**: `https://snifftest-api-production.up.railway.app/api/v1`
     - **Supabase URL**: `https://oxjywpearruxtnysoyuf.supabase.co`
   - For local development, change `API_BASE_URL` to `http://localhost:8000/api/v1`

3. **Configure Signing**:
   - Select your development team
   - Bundle identifier: `com.snifftest.app`
   - Configure capabilities:
     - Camera access
     - Photo library access
     - Push notifications
     - Keychain sharing
     - Background modes (fetch, processing)

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

Complete API reference is available in [API_DOCS.md](API_DOCS.md).

### Quick API Overview

- **Authentication**: JWT-based with MFA support
- **Pet Management**: CRUD operations for pet profiles
- **Scan Processing**: Ingredient analysis and safety assessment
- **Nutrition API**: Comprehensive nutrition tracking and analysis
- **Food Management**: Searchable food database with barcode lookup
- **Advanced Nutrition**: Weight tracking, trends, and food comparisons
- **Push Notifications**: Birthday reminders and updates
- **GDPR Compliance**: Data export and deletion
- **Health Monitoring**: System status and metrics

### Base URLs
- **Development**: `http://localhost:8000/api/v1`
- **Production**: `https://snifftest-api-production.up.railway.app/api/v1`

### Authentication
All endpoints require JWT Bearer token:
```http
Authorization: Bearer <jwt_token>
```

## Database Schema

Built on **Supabase (PostgreSQL)** with Row Level Security (RLS) for data protection.

### Core Tables

| Table | Purpose | Key Features |
|-------|---------|--------------|
| `users` | User profiles | Username, onboarding status, device tokens |
| `pets` | Pet profiles | Birthday tracking, sensitivities, vet info |
| `scans` | Scan history | OCR text, analysis results, status tracking |
| `ingredients` | Safety database | Species compatibility, allergen flags |
| `favorites` | Saved products | User-curated safe products |
| `food_items` | Food database | Barcode, nutrition facts, ingredients |
| `food_analyses` | Nutrition analysis | Calorie/macro tracking per food |
| `feeding_records` | Feeding logs | Meal tracking with timestamps |
| `calorie_goals` | Calorie targets | Goal tracking with start/end dates |
| `nutritional_requirements` | Pet requirements | Daily nutritional needs per pet |
| `pet_weight_records` | Weight history | Weight measurements over time |
| `pet_weight_goals` | Weight targets | Weight loss/gain goals |
| `food_comparisons` | Product comparisons | Side-by-side food analysis |

### Key Features
- **Row Level Security**: Users can only access their own data
- **Automatic Timestamps**: `created_at` and `updated_at` fields
- **Data Validation**: Check constraints for data integrity
- **JSONB Support**: Flexible result storage for scans
- **Array Fields**: Support for multiple sensitivities and aliases

### Migrations
- `add_birthday_column.sql` - Added birthday tracking to pets
- `add_onboarded_column.sql` - Added onboarding status to users
- `sync_username_auth.sql` - Synchronized usernames with auth

See `database_schemas/database_schema.sql` for complete schema.

## Security Features

### 🔐 Authentication & Authorization
- **JWT Tokens**: HS256 algorithm with configurable expiration
- **Multi-Factor Authentication**: TOTP with QR codes and backup codes
- **Session Management**: 8-hour default timeout with secure storage
- **Password Security**: Bcrypt hashing with salt
- **Robust JWT Validation**: Multi-strategy validation supporting both Supabase and custom tokens
- **Service Role Integration**: Automatic RLS policy bypass for system operations

### 🛡️ API Protection
- **Rate Limiting**: 60 req/min general, 5 req/min auth endpoints
- **Input Validation**: Pydantic models with sanitization
- **Security Headers**: XSS, CSRF, and clickjacking protection
- **CORS Configuration**: Environment-specific origins
- **Request Size Limits**: Configurable upload limits

### 🔒 Data Protection
- **Encryption**: TLS 1.3 in transit, Supabase encryption at rest
- **Secure Storage**: iOS Keychain for sensitive data
- **Audit Logging**: Comprehensive activity tracking
- **GDPR Compliance**: Data export, deletion, and portability

### 📊 Monitoring
- **Health Checks**: Real-time system monitoring
- **Security Events**: Automated logging and alerting
- **Performance Metrics**: Response time and throughput tracking

## Development

### Prerequisites
- **macOS**: 13.0+ (for iOS development)
- **Xcode**: 15.0+
- **Python**: 3.9+
- **Supabase Account**: For backend services

### Quick Start
1. **Clone Repository**: `git clone <repo-url>`
2. **Backend Setup**: `cd server && pip install -r requirements.txt`
3. **iOS Setup**: Open `pet-allergy-scanner.xcodeproj` in Xcode
4. **Configure**: Update API URLs and Supabase credentials
5. **Run**: Start server with `python start.py` and build iOS app

### Project Structure
```
SniffTest/
├── server/                 # FastAPI backend
│   ├── app/               # Application code
│   ├── tests/             # Backend tests
│   └── requirements.txt   # Python dependencies
├── SniffTest/             # iOS app
│   ├── Views/             # SwiftUI views
│   ├── Models/            # Data models
│   ├── Services/          # API & business logic
│   └── Utils/             # Utilities
└── API_DOCS.md           # Complete API reference
```

### Testing
- **Backend**: `pytest tests/ -v`
- **iOS**: `Cmd + U` in Xcode
- **Security**: `python security_audit.py`

## Deployment

### Backend

#### Production (Railway)
- **API URL**: `https://snifftest-api-production.up.railway.app`
- **Health Check**: `https://snifftest-api-production.up.railway.app/health`
- **Interactive Docs**: `https://snifftest-api-production.up.railway.app/docs` (when DEBUG=true)
- **Platform**: Railway deployment with automatic HTTPS

#### Development
- **Local Server**: `python start.py`
- **API URL**: `http://localhost:8000/api/v1`
- **Docs**: `http://localhost:8000/docs`

#### Deployment Options
- **Railway**: Currently deployed ✅
- **Vercel**: Serverless deployment ready
- **Heroku**: Platform as a Service ready
- **Docker**: Included Dockerfile and docker-compose.yml

### iOS App
- **Development**: Xcode simulator or device
- **API Configuration**: Update `API_BASE_URL` in `Info.plist`
  - Development: `http://localhost:8000/api/v1`
  - Production: `https://snifftest-api-production.up.railway.app/api/v1`
- **Distribution**: TestFlight for beta testing
- **App Store**: Production release via App Store Connect

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request

---

## Version History

### v5.1 (Current - Build 6)
- Enhanced nutrition tracking with feeding logs
- Calorie goals and weight management
- Food database with barcode scanning
- Advanced nutritional analytics and insights
- Food comparison feature
- Health trend analysis
- Multi-pet nutrition insights
- Improved camera and barcode scanning
- **FIXED**: Authentication system with robust JWT validation
- **FIXED**: Row Level Security (RLS) policy violations
- **FIXED**: Trailing slash routing issues across all endpoints
- **IMPROVED**: Error handling and debugging capabilities
- Bug fixes and performance improvements

### v5.0
- Major nutrition feature release
- Comprehensive food database integration
- Advanced analytics dashboard
- Weight tracking system

---

**Built with ❤️ for pet owners everywhere**

*Last updated: January 2025*
*iOS App Version: 5.1 (Build 6)*
*API Version: 1.0.0*