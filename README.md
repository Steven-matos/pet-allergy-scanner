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
- [Website Setup](#website-setup)
- [iOS App Setup](#ios-app-setup)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Security Features](#security-features)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Environment Variables](#environment-variables-reference)
- [Known Issues](#known-issues--important-notes)
- [Version History](#version-history)
- [Contributing](#contributing)
- [Support & Resources](#support--resources)

## Overview

**SniffTest** is a comprehensive pet food safety and nutrition tracking platform consisting of three main components:

1. **iOS App** (Swift/SwiftUI) - Native mobile app for scanning and tracking
2. **FastAPI Backend** (Python) - RESTful API with comprehensive features
3. **Next.js Website** (TypeScript/React) - Landing page and legal documentation

SniffTest helps pet owners make informed decisions about their pets' food by:

- **Scanning pet food labels** using OCR technology
- **Analyzing ingredients** for species-specific safety and allergen information
- **Managing multiple pet profiles** with individual allergy tracking
- **Providing detailed safety assessments** with recommendations
- **Saving favorite products** for future reference

The application uses AI-powered ingredient analysis with comprehensive databases of pet-safe and potentially harmful ingredients, tailored specifically for dogs and cats.

## Features

### Core Functionality
- 📱 **Native iOS App**: Built with SwiftUI for iOS 17.0+ (v1.0.0)
- 🔍 **Camera Scanning**: Real-time OCR and barcode scanning for pet food labels
- 🧠 **AI-Powered Analysis**: Intelligent ingredient safety assessment with species-specific logic
- 🐕 **Pet Profiles**: Complete pet management with birthday tracking and age calculation
- 📊 **Safety Reports**: Detailed ingredient analysis with personalized recommendations
- 💾 **Offline Support**: Core scanning features work without internet connection with intelligent caching
- 🥗 **Nutrition Tracking**: Comprehensive feeding logs, calorie goals, and nutritional analysis
- ⚖️ **Weight Management**: Track pet weight trends and set health goals
- 📱 **Food Database**: Searchable database with barcode lookup and nutritional info
- 📋 **Trackers Hub**: Centralized health event tracking and management
- 🏥 **Visit Summaries**: One-tap vet-readable health summaries for veterinary visits

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
- 💊 **Medication Reminders**: Schedule and track pet medications with customizable frequencies
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
- 💳 **Subscription Management**: Premium features with App Store & RevenueCat integration
  - **Free Tier**: 5 scans/day, 1 pet, 5 scan history limit
  - **Premium Tier**: Unlimited scans, unlimited pets, unlimited history, health tracking, analytics, trends
- 📧 **Waitlist System**: Pre-launch email signup and notification system
- 💊 **Medication Tracking**: Comprehensive medication reminder scheduling
- 🌍 **Localization Ready**: Multi-language support infrastructure
- 📊 **Analytics**: PostHog integration for user behavior tracking and performance monitoring
- 🔧 **Settings Management**: Comprehensive app configuration options
- 🧪 **Testing Suite**: Complete unit and integration test coverage
- 💾 **Intelligent Caching**: Multi-layer caching system with automatic sync and memory optimization
- 🏥 **Vet Visit Summaries**: Generate comprehensive health summaries for veterinary visits (30/60/90 day ranges)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │   FastAPI       │    │   Supabase      │
│   (SwiftUI)     │◄──►│   Backend       │◄──►│   Database      │
│                 │    │   (Railway)     │    │                 │
│ • Camera/OCR    │    │                 │    │ • PostgreSQL    │
│ • Pet Profiles  │    │ • REST API      │    │ • Row Level     │
│ • Scan Results  │    │ • Authentication│    │   Security      │
│ • Nutrition     │    │ • Ingredient    │    │ • Real-time     │
│ • Health Events │    │   Analysis      │    │ • Storage       │
└─────────────────┘    │ • Nutrition     │    └─────────────────┘
                       │ • Subscriptions │
┌─────────────────┐    │ • GDPR/MFA      │
│   Website       │    │ • Push Notifs   │
│   (Next.js)     │◄──►│                 │
│                 │    └─────────────────┘
│ • Landing Page  │
│ • Terms/Privacy │
│ • Waitlist      │
│ • Support       │
└─────────────────┘
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
├── Tracking/
│   ├── Views/
│   │   ├── TrackersView.swift            # Central tracking hub (replaces History)
│   │   └── [Health event tracking views]
│   ├── Services/
│   │   └── HealthEventService.swift      # Health event management
│   └── Models/
│       └── [Health tracking models]
├── VisitSummary/
│   ├── Views/
│   │   └── VisitSummaryView.swift        # Vet-readable health summaries
│   ├── Services/
│   │   └── VisitSummaryService.swift    # Summary generation
│   └── Models/
│       └── VisitSummaryModels.swift      # Summary data models
├── Onboarding/
│   └── Views/
│       └── OnboardingView.swift          # First-time user flow
├── Settings/
│   └── Services/
│       └── WeightUnitPreferenceService.swift # Unit preferences
├── Subscription/
│   ├── Views/
│   │   ├── SubscriptionView.swift       # Premium features
│   │   ├── PaywallView.swift            # Subscription purchase UI
│   │   └── SubscriptionBlockerView.swift # Feature gating
│   ├── Services/
│   │   └── RevenueCatSubscriptionProvider.swift # RevenueCat integration
│   ├── ViewModels/
│   │   └── SubscriptionViewModel.swift  # Subscription state management
│   └── Models/
│       ├── SubscriptionTier.swift       # Free/Premium tier definitions
│       └── SubscriptionProduct.swift    # Product models
├── Guidance/
│   ├── Services/
│   │   └── GuidanceEngine.swift         # Health guidance logic
│   └── Views/
│       └── HealthGuidanceCard.swift     # Guidance UI components
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
│   ├── CacheManager.swift             # Legacy cache manager
│   ├── UnifiedCacheCoordinator.swift  # Centralized cache coordination
│   ├── CacheFirstDataLoader.swift     # Cache-first data loading
│   ├── CacheServerSyncService.swift   # Background sync service
│   ├── CacheAnalyticsService.swift    # Cache performance analytics
│   ├── EnhancedCacheManager.swift     # Enhanced caching with memory optimization
│   ├── ObservableCacheManager.swift   # Observable cache state
│   ├── MultiCacheService.swift        # Multi-layer caching
│   ├── GDPRService.swift              # Data export/deletion
│   ├── MonitoringService.swift        # Analytics and performance
│   ├── MemoryEfficientImageProcessor.swift # Optimized image processing
│   ├── NetworkMonitor.swift           # Network connectivity
│   ├── SupabaseService.swift          # Supabase integration
│   ├── URLHandler.swift               # Deep linking and URL handling
│   ├── AutomaticTokenRefreshService.swift # Token refresh automation
│   └── PetSensitivityService.swift    # Pet sensitivity management
├── Utils/
│   ├── ModernDesignSystem.swift       # Trust & Nature design system
│   ├── HapticFeedback.swift           # Tactile feedback
│   ├── InputValidator.swift           # Form validation
│   ├── LocalizationHelper.swift       # Internationalization
│   ├── ImageOptimizer.swift           # Image optimization utilities
│   ├── ImageLoader.swift              # Efficient image loading
│   ├── Debouncer.swift                # Debouncing utilities
│   ├── DevicePerformanceHelper.swift  # Performance optimization
│   ├── iOS18Compatibility.swift       # iOS 18 compatibility fixes
│   ├── KeyboardManager.swift          # Keyboard handling
│   ├── OrientationManager.swift       # Orientation management
│   ├── SettingsManager.swift          # Settings persistence
│   └── SystemWarningSuppressionHelper.swift # Console noise reduction
└── Views/
    ├── CommonComponents.swift         # Reusable UI components
    ├── LoadingView.swift              # Loading states
    ├── EmptyStateView.swift           # Empty state UI
    ├── ErrorView.swift                # Error displays
    ├── ConfirmationDialog.swift       # Confirmation modals
    ├── ToastView.swift                # Toast notifications
    ├── MainTabView.swift              # Main tab navigation
    ├── CacheHydrationProgressView.swift # Cache loading UI
    ├── GDPRView.swift                 # GDPR compliance UI
    ├── LegalViews.swift               # Legal documentation views
    ├── ModernSwiftUIAnimations.swift  # Animation utilities
    ├── ModernSwiftUIConcurrency.swift # Concurrency helpers
    ├── NutritionComponents.swift      # Nutrition UI components
    └── SafeTextField.swift            # Secure text input
```

### Backend Architecture
```
app/
├── core/
│   ├── config.py              # Configuration and settings management
│   ├── database/              # Database connection and pooling
│   │   ├── client.py         # Supabase client initialization
│   │   └── __init__.py
│   ├── security/              # Security utilities and JWT validation
│   │   ├── jwt_handler.py    # JWT token validation and parsing
│   │   ├── auth_enhancements.py  # Enhanced auth features
│   │   └── __init__.py
│   ├── middleware/            # Core middleware implementations
│   │   ├── security.py       # Security headers middleware
│   │   ├── audit.py          # Audit logging middleware
│   │   ├── request_limits.py # Request size and rate limiting
│   │   ├── query_monitoring.py  # Database query monitoring
│   │   └── __init__.py
│   └── validation/            # Request validation schemas
│       ├── input_validator.py    # Input validation utilities
│       ├── file_validator.py     # File upload validation
│       ├── security_patterns.py  # Security pattern matching
│       └── __init__.py
├── models/
│   ├── core/                  # Core data models
│   │   ├── user.py           # User models with onboarding
│   │   ├── pet.py            # Pet models with birthday tracking
│   │   ├── subscription.py   # Subscription models
│   │   ├── waitlist.py       # Waitlist models
│   │   └── __init__.py
│   ├── health/                # Health-related models
│   │   ├── health_event.py   # Health event tracking
│   │   ├── medication_reminder.py  # Medication reminders
│   │   └── __init__.py
│   ├── nutrition/             # Nutrition models
│   │   ├── nutrition.py      # Core nutrition models
│   │   ├── advanced_nutrition.py  # Advanced analytics
│   │   ├── food_items.py     # Food database models
│   │   ├── calorie_goals.py  # Calorie goal tracking
│   │   ├── nutritional_standards.py  # Dietary standards
│   │   └── __init__.py
│   └── scanning/              # Scanning models
│       ├── ingredient.py     # Ingredient analysis models
│       ├── scan.py           # Scan processing models
│       └── __init__.py
├── api/v1/
│   ├── auth/                 # Authentication and user management
│   ├── pets/                 # Pet CRUD operations and management
│   ├── ingredients/          # Ingredient analysis and safety data
│   ├── scanning/             # Scan processing and analysis
│   ├── nutrition/            # Structured nutrition API
│   │   ├── analysis/         # Food analysis endpoints
│   │   ├── feeding/          # Feeding log endpoints
│   │   ├── goals/            # Calorie goal endpoints
│   │   ├── requirements/     # Nutritional requirements
│   │   ├── summaries/        # Daily nutrition summaries
│   │   └── advanced/         # Advanced analytics and insights
│   ├── advanced_nutrition/   # Advanced nutrition features
│   │   ├── weight/           # Weight tracking endpoints
│   │   ├── trends/           # Nutritional trends
│   │   ├── comparisons/      # Food comparison endpoints
│   │   └── analytics/            # Health insights and patterns
│   ├── food_management/      # Food database management with barcode
│   ├── health_events/        # Pet health event tracking
│   ├── medication_reminders/ # Medication scheduling and tracking
│   ├── mfa/                  # Multi-factor authentication
│   ├── gdpr/                 # GDPR compliance and data management
│   ├── monitoring/           # Health monitoring and metrics
│   ├── notifications/        # Push notification management
│   ├── subscriptions/        # Subscription management (App Store, RevenueCat)
│   ├── waitlist/             # Waitlist signup management
│   ├── data_quality.py       # Data quality assessment endpoints
│   └── images/               # Image processing and optimization
├── services/
│   ├── analytics/            # Analytics services
│   │   ├── advanced_analytics_service.py  # AI-powered insights
│   │   ├── health_analytics_service.py    # Health trend analysis
│   │   ├── pattern_analytics_service.py   # Pattern detection
│   │   ├── recommendation_service.py      # Personalized recommendations
│   │   ├── trend_analytics_service.py     # Trend analysis
│   │   └── __init__.py
│   ├── health/               # Health services
│   │   ├── health_event_service.py       # Health event management
│   │   ├── medication_reminder_service.py # Medication scheduling
│   │   └── __init__.py
│   ├── nutrition/            # Nutrition services
│   │   ├── nutritional_calculator.py     # Nutritional calculations
│   │   ├── nutritional_trends_service.py # Nutrition trends
│   │   ├── food_comparison_service.py    # Food comparison
│   │   ├── weight_tracking_service.py    # Weight tracking
│   │   └── __init__.py
│   ├── subscription/         # Subscription services
│   │   ├── subscription_service.py           # Subscription management
│   │   ├── subscription_checker.py           # Subscription verification
│   │   ├── revenuecat_service.py            # RevenueCat integration
│   │   ├── revenuecat_api_service.py        # RevenueCat API calls
│   │   ├── revenuecat_subscription_service.py # RC subscription logic
│   │   ├── revenuecat_webhook_service.py    # Webhook handling
│   │   └── __init__.py
│   ├── gdpr_service.py       # GDPR compliance (export/deletion)
│   ├── mfa_service.py        # Multi-factor authentication
│   ├── push_notification_service.py # APNs push notifications
│   ├── monitoring.py         # System monitoring and health checks
│   ├── data_quality_service.py # Data quality assessment
│   ├── image_optimizer.py    # Image processing and optimization
│   ├── storage_service.py    # File storage management
│   └── __init__.py
├── shared/                    # Shared utilities and patterns
│   ├── decorators/           # Reusable decorators
│   │   ├── error_handler.py  # Error handling decorator
│   │   └── __init__.py
│   ├── repositories/         # Repository pattern implementations
│   │   ├── base_repository.py # Base repository class
│   │   └── __init__.py
│   ├── services/             # Shared service utilities
│   │   ├── cache_service.py  # Caching utilities
│   │   ├── database_operation_service.py # DB operations
│   │   ├── query_builder_service.py # Query building
│   │   ├── pagination_service.py # Pagination utilities
│   │   ├── response_utils.py # Response formatting
│   │   ├── supabase_auth_service.py # Auth helpers
│   │   ├── user_data_service.py # User data utilities
│   │   ├── validation_service.py # Validation helpers
│   │   └── [15+ more utilities]
│   └── utils/
│       └── async_supabase.py # Async Supabase utilities
└── utils/
    ├── error_handling.py     # Centralized error management
    ├── logging_config.py     # Structured logging configuration
    └── test_logging.py       # Logging tests
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
- **Framework**: FastAPI 0.115.6
- **Database**: PostgreSQL via Supabase
- **Authentication**: JWT with Supabase Auth (PyJWT 2.10+)
- **Validation**: Pydantic v2.12+
- **Security**: Multi-layer middleware stack
- **Testing**: pytest 8.4+ with async support
- **Deployment**: ASGI with Uvicorn 0.37+
- **Supabase SDK**: 2.9.1 (pinned for stability)

### Website
- **Framework**: Next.js 16.0.10
- **Language**: TypeScript 5.6.0
- **Styling**: Tailwind CSS 3.4.0
- **React**: 19.0.0
- **Icons**: Lucide React 0.548.0, React Icons 5.5.0

### Infrastructure
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime 2.22.0
- **Hosting**: Railway (Backend), Vercel-ready (Website)
- **Rate Limiting**: Redis 5.0+ (optional, falls back to in-memory)
- **Analytics**: PostHog (user behavior tracking)
- **Subscriptions**: RevenueCat (subscription management)

### Key Dependencies & Versions

#### Backend (Python)
- **FastAPI**: 0.115.6 (pinned for stability)
- **Supabase**: 2.9.1 (exact version, 2.22.0+ has breaking changes)
- **Pydantic**: 2.12+ (data validation)
- **PyJWT**: 2.10+ (JWT tokens, replaces python-jose)
- **Pillow**: 11.0+ (image processing)
- **SQLAlchemy**: 2.0.44+ (ORM features)
- **Uvicorn**: 0.37+ (ASGI server)
- **pytest**: 8.4+ (testing framework)

**Note**: Dependencies are carefully pinned for compatibility. FastAPI 0.115.6 has starlette version constraints that prevent upgrading to newer versions with CVE fixes. Mitigation middleware is in place for known vulnerabilities.

#### iOS (Swift)
- **Swift**: 5.9+
- **SwiftUI**: Native framework
- **iOS**: 17.0+ minimum deployment target
- **Combine**: Reactive programming
- **AVFoundation**: Camera and OCR

#### Website (TypeScript/React)
- **Next.js**: 16.0.10
- **React**: 19.0.0
- **TypeScript**: 5.6.0
- **Tailwind CSS**: 3.4.0
- **Lucide React**: 0.548.0 (icons)
- **React Icons**: 5.5.0 (additional icons)

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
- **Node.js**: 18+ (required for website)
- **npm**: 9+ (included with Node.js)
- **Git**: Latest version

### Accounts Required
- **Apple Developer Account**: For iOS app distribution (paid)
- **Supabase Account**: For backend services (free tier available)
- **RevenueCat Account**: For subscription management (optional)
- **Railway Account**: For backend hosting (optional, free tier available)
- **Vercel Account**: For website hosting (optional, free tier available)
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
# Create .env file with your Supabase credentials
python start.py
```

### 3. iOS App Setup (5 minutes)
```bash
cd pet-allergy-scanner
open SniffTest.xcodeproj
# Update API_BASE_URL in Info.plist
# Build and run in Xcode (Cmd + R)
```

### 4. Website Setup (Optional - 3 minutes)
```bash
cd website
npm install
npm run dev
# Visit http://localhost:3000
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
   # Run the complete schema in Supabase SQL Editor:
   # server/database_schemas/01_complete_database_schema.sql
   ```

3. **Security Fixes** (Recommended):
   ```bash
   # Apply security hardening for database functions:
   # server/scripts/fix_function_search_path_security.sql
   # 
   # Fix authentication errors if needed:
   # server/scripts/fix_auth_user_grant_error.sql
   ```

4. **Authentication Setup**:
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

**Key Dependencies:**
- FastAPI 0.115.6 (pinned for stability)
- Supabase 2.9.1 (exact version for compatibility)
- Pydantic 2.12+ (validation)
- PyJWT 2.10+ (authentication)
- Pillow 11.0+ (image processing)
- pytest 8.4+ (testing)
- uvicorn 0.37+ (ASGI server)

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
- **Function Search Path Security**: All SECURITY DEFINER functions use explicit search_path to prevent injection attacks
- **Performance Optimizations**: Auth RLS patterns optimized with `(select auth.uid())` for better performance
- **Security Linter Compliance**: All Supabase linter warnings addressed (2025-11-26)

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

## Website Setup

The project includes a Next.js landing page with support pages for terms, privacy, and waitlist functionality.

### 1. Install Dependencies

```bash
cd website
npm install
```

### 2. Development Server

```bash
npm run dev
```

The website will be available at `http://localhost:3000`

### 3. Build for Production

```bash
npm run build
npm start
```

### Website Structure

```
website/
├── app/
│   ├── page.tsx              # Landing page
│   ├── layout.tsx            # Root layout
│   ├── privacy/page.tsx      # Privacy policy
│   ├── terms/page.tsx        # Terms of service
│   └── support/              # Support pages
├── components/               # Reusable React components
├── contexts/                 # React contexts (waitlist)
├── lib/                      # Utilities
└── public/                   # Static assets
```

### Key Features
- **Landing Page**: Modern, responsive design showcasing app features
- **Legal Pages**: Privacy policy and terms of service
- **Support**: Help and support resources
- **Waitlist**: Pre-launch email signup system
- **SEO**: Built-in sitemap and robots.txt
- **Responsive**: Mobile-first design with Tailwind CSS

## iOS App Setup

### 1. Xcode Configuration

1. **Open Project**:
   ```bash
   cd pet-allergy-scanner
   open pet-allergy-scanner.xcodeproj
   ```

2. **Update API Configuration**:
   - Open `Info.plist` in Xcode
   - **Current Production Settings**:
     - Bundle ID: `com.snifftest.app`
     - Version: `1.0.0` (Pre-release)
     - API_BASE_URL: `https://snifftest-api-production.up.railway.app/api/v1`
     - Supabase URL: `https://oxjywpearruxtnysoyuf.supabase.co`
   - **For Local Development**:
     - Change `API_BASE_URL` to `http://localhost:8000/api/v1`
     - Ensure backend server is running locally
     - Use iOS Simulator (physical devices require HTTPS)

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

Complete API reference is available in **[API_DOCS.md](API_DOCS.md)**.

### Interactive API Documentation

The FastAPI backend provides interactive API documentation:

- **Swagger UI**: `http://localhost:8000/docs` (development)
- **ReDoc**: `http://localhost:8000/redoc` (alternative documentation)
- **Production Docs**: `https://snifftest-api-production.up.railway.app/docs` (when DEBUG=true)

### Quick API Overview

- **Authentication**: JWT-based with MFA support
- **Pet Management**: CRUD operations for pet profiles
- **Scan Processing**: Ingredient analysis and safety assessment
- **Nutrition API**: Comprehensive nutrition tracking and analysis
  - `/nutrition/analysis` - Food analysis endpoints
  - `/nutrition/feeding` - Feeding log endpoints
  - `/nutrition/goals` - Calorie goal endpoints
  - `/nutrition/requirements` - Nutritional requirements
  - `/nutrition/summaries` - Daily nutrition summaries
  - `/nutrition/advanced` - Advanced analytics and insights
- **Advanced Nutrition**: Weight tracking, trends, and food comparisons
  - `/advanced-nutrition/weight` - Weight tracking endpoints
  - `/advanced-nutrition/trends` - Nutritional trends
  - `/advanced-nutrition/comparisons` - Food comparison endpoints
  - `/advanced-nutrition/analytics` - Health insights and patterns
- **Food Management**: Searchable food database with barcode lookup
- **Health Events**: Pet health tracking and medical event logging
- **Medication Reminders**: Schedule and track pet medications
- **Subscriptions**: App Store and RevenueCat subscription management with webhook support
- **Waitlist**: Email signup for pre-launch users
- **Data Quality**: Food item data quality assessment and improvement recommendations
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
| `health_events` | Health tracking | Vet visits, medical events, health notes |
| `medication_reminders` | Medication tracking | Scheduled medication reminders |
| `subscriptions` | User subscriptions | Premium subscription management (App Store & RevenueCat) |
| `waitlist` | Email waitlist | Pre-launch email signups |
| `data_quality` | Data quality | Food item quality assessment and analysis |
| `visit_summaries` | Vet summaries | Generated health summaries for veterinary visits |

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
- `fix_function_search_path_security.sql` - Security hardening for database functions (2025-11-26)
- `fix_auth_user_grant_error.sql` - Authentication error fixes and diagnostics
- `create_device_tokens_temp_table.sql` - Anonymous device token storage

See `database_schemas/01_complete_database_schema.sql` for complete schema.

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
- **Database Function Security**: Explicit search_path for all SECURITY DEFINER functions to prevent search path injection
- **SQL Injection Protection**: Parameterized queries and explicit schema qualification

### 📊 Monitoring
- **Health Checks**: Real-time system monitoring
- **Security Events**: Automated logging and alerting
- **Performance Metrics**: Response time and throughput tracking

## Development

### Prerequisites
- **macOS**: 13.0+ (for iOS development)
- **Xcode**: 15.0+
- **Python**: 3.9+
- **Node.js**: 18+ (for website)
- **Supabase Account**: For backend services

### Development Setup
1. **Clone Repository**: `git clone <repo-url> && cd SniffTest`
2. **Backend Setup**: 
   ```bash
   cd server
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   # Create .env file with credentials
   python start.py
   ```
3. **Website Setup** (optional):
   ```bash
   cd website
   npm install
   npm run dev
   ```
4. **iOS Setup**: 
   ```bash
   cd pet-allergy-scanner
   open SniffTest.xcodeproj
   # Update API_BASE_URL in Info.plist
   # Cmd + R to run
   ```

### Development Workflow
- **Backend**: Hot reload enabled in development mode
- **Website**: Next.js hot reload on save
- **iOS**: Xcode live previews for SwiftUI components
- **API Testing**: Use Swagger UI at `http://localhost:8000/docs`

### Repository Organization

This is a **monorepo** containing three main applications:

- **`server/`** - Python FastAPI backend (deployed to Railway)
- **`pet-allergy-scanner/`** - iOS app (Swift/SwiftUI)
- **`website/`** - Next.js landing page (deployable to Vercel)

Each component is independently deployable but shares common design patterns and data models through the Supabase backend.

### Project Structure
```
SniffTest/
├── server/                     # FastAPI backend
│   ├── app/                   # Application code
│   │   ├── api/v1/           # API v1 endpoints
│   │   │   ├── auth/         # Authentication
│   │   │   ├── pets/         # Pet management
│   │   │   ├── scanning/     # Ingredient scanning
│   │   │   ├── nutrition/    # Nutrition tracking
│   │   │   ├── advanced_nutrition/ # Analytics & trends
│   │   │   ├── food_management/  # Food database
│   │   │   ├── health_events/    # Health tracking
│   │   │   ├── medication_reminders/ # Medication scheduling
│   │   │   ├── subscriptions/    # Subscription management
│   │   │   ├── notifications/    # Push notifications
│   │   │   ├── mfa/          # Multi-factor auth
│   │   │   ├── gdpr/         # GDPR compliance
│   │   │   ├── monitoring/   # System monitoring
│   │   │   ├── waitlist/     # Waitlist management
│   │   │   └── data_quality.py # Data quality endpoints
│   │   ├── core/             # Config, security, middleware
│   │   ├── models/           # Pydantic models (organized by domain)
│   │   ├── services/         # Business logic (organized by domain)
│   │   ├── shared/           # Shared utilities & patterns
│   │   └── utils/            # General utilities
│   ├── database_schemas/     # Database migration scripts
│   ├── scripts/              # Utility scripts
│   │   ├── admin/            # Admin tools
│   │   ├── database/         # DB maintenance
│   │   ├── deployment/       # Deployment helpers
│   │   └── testing/          # Test utilities
│   ├── tests/                # Backend tests
│   ├── importing/            # Data import utilities
│   ├── standardizor/         # Data standardization tools
│   ├── requirements.txt      # Python dependencies
│   ├── requirements-lock.txt # Locked dependency versions
│   ├── Procfile             # Railway deployment config
│   └── railway.toml         # Railway configuration
├── pet-allergy-scanner/      # iOS app (Swift/SwiftUI)
│   ├── SniffTest/           # Source code
│   │   ├── Features/        # Feature modules (Auth, Scanning, Pets, etc.)
│   │   ├── Shared/          # Shared components
│   │   ├── Utils/           # Utilities
│   │   └── Assets.xcassets/ # App icons, images, colors
│   └── SniffTest.xcodeproj  # Xcode project
├── website/                  # Next.js landing page
│   ├── app/                 # Next.js 14+ app directory
│   │   ├── page.tsx         # Landing page
│   │   ├── layout.tsx       # Root layout
│   │   ├── privacy/         # Privacy policy
│   │   ├── terms/           # Terms of service
│   │   └── support/         # Support pages
│   ├── components/          # React components
│   ├── contexts/            # React contexts
│   ├── lib/                 # Utility libraries
│   ├── public/              # Static assets
│   ├── package.json         # Node dependencies
│   ├── tailwind.config.ts   # Tailwind configuration
│   └── tsconfig.json        # TypeScript config
├── images/                  # Project documentation images
└── .cursor/                 # Cursor AI rules and settings
    └── rules/               # Project-specific coding rules
```

### Testing

#### Backend (FastAPI)
```bash
cd server
pytest tests/ -v                    # Run all tests
pytest tests/unit/ -v               # Unit tests only
pytest tests/notifications/ -v      # Notification tests
python -m pytest --cov=app         # With coverage
```

#### iOS App (Swift)
- **Unit Tests**: `Cmd + U` in Xcode
- **UI Tests**: Configure and run UI test targets
- **Test Plans**: Use Xcode test plans for organized testing

#### Website (Next.js)
```bash
cd website
npm run lint                       # ESLint checks
npm run build                      # Build verification
```

#### Security & Quality
```bash
cd server
pip-audit                          # Security vulnerability scan
python scripts/deployment/check-deployment-ready.py  # Deployment readiness
```

### Utility Scripts

The `server/scripts/` directory contains utility scripts organized by category:

#### Deployment Scripts (`scripts/deployment/`)
- `railway_start.py` - Production startup script for Railway
- `check-deployment-ready.py` - Validates deployment readiness
- `generate-railway-vars.py` - Generates Railway environment variables
- `pre_production_check.py` - Pre-deployment validation checklist

#### Database Scripts (`scripts/database/`)
- `analyze_database_tables.py` - Analyzes database structure and performance
- `cleanup_database.py` - Database maintenance and cleanup
- `backfill_nutritional_trends.py` - Backfills nutritional trend data
- `fix_function_search_path_security.sql` - Security hardening for DB functions
- `fix_auth_user_grant_error.sql` - Authentication error diagnostics
- `create_debug_function.sql` - Debug utilities for troubleshooting

#### Admin Scripts (`scripts/admin/`)
- `set_premium_account.py` - Grant premium access to users

#### Testing Scripts (`scripts/testing/`)
- `setup_test_data.py` - Populates test data for development
- `test_config.py` - Tests configuration settings
- `test_health_endpoint.py` - Validates health endpoints
- `test_jwt_debug.py` - JWT token debugging utilities

See `server/scripts/dev/README.md` and `PRE_PRODUCTION_CHECKLIST.md` for detailed usage.

## Deployment

### Backend (FastAPI)

#### Production (Railway)
- **API URL**: `https://snifftest-api-production.up.railway.app`
- **Health Check**: `https://snifftest-api-production.up.railway.app/health`
- **Interactive Docs**: `https://snifftest-api-production.up.railway.app/docs` (when DEBUG=true)
- **Platform**: Railway deployment with automatic HTTPS
- **Configuration**: Uses `Procfile` and `railway.toml`

#### Development
- **Local Server**: `python start.py` (in `/workspace/server/`)
- **API URL**: `http://localhost:8000/api/v1`
- **Docs**: `http://localhost:8000/docs`
- **Port**: 8000 (configurable)

#### Deployment Options
- **Railway**: Currently deployed ✅
- **Vercel**: Serverless deployment ready
- **Heroku**: Platform as a Service ready
- **Docker**: Containerized deployment ready

### Website (Next.js)

#### Production
- **Vercel**: Recommended (optimized for Next.js)
  ```bash
  cd website
  vercel --prod
  ```
- **Other Platforms**: Compatible with any Node.js hosting
  ```bash
  npm run build
  npm start
  ```

#### Development
- **Local Server**: `npm run dev` (in `/workspace/website/`)
- **URL**: `http://localhost:3000`
- **Hot Reload**: Enabled by default

### iOS App
- **Development**: Xcode simulator or device
- **API Configuration**: Update `API_BASE_URL` in `Info.plist`
  - Development: `http://localhost:8000/api/v1`
  - Production: `https://snifftest-api-production.up.railway.app/api/v1`
- **Bundle ID**: `com.snifftest.app`
- **Distribution**: TestFlight for beta testing
- **App Store**: Production release via App Store Connect
- **Analytics**: PostHog integration (configure via `POSTHOG_API_KEY` in Info.plist)
- **Subscriptions**: RevenueCat integration (configure via `REVENUECAT_PUBLIC_SDK_KEY` in Info.plist)

### Deployment Checklist
- [ ] Configure environment variables for all services
- [ ] Set up Supabase project and database schema
- [ ] Configure CORS origins for your domains
- [ ] Set up APNs certificates for push notifications
- [ ] Configure RevenueCat for subscriptions (optional)
- [ ] Test API health endpoints
- [ ] Verify database migrations
- [ ] Run security audit: `pip-audit` in server directory

## Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow
1. **Fork** the repository
2. **Create** feature branch: `git checkout -b feature/amazing-feature`
3. **Make** your changes following code style guidelines
4. **Test** your changes thoroughly
5. **Commit** with clear messages: `git commit -m 'Add amazing feature'`
6. **Push** to your fork: `git push origin feature/amazing-feature`
7. **Open** a Pull Request with detailed description

### Code Style Guidelines
- **Python**: Follow PEP 8, use type hints, async/await patterns
- **Swift**: Follow Swift API Design Guidelines, use SwiftUI best practices
- **TypeScript**: Use ESLint config, prefer functional components
- **Documentation**: Update README and inline comments for changes
- **Testing**: Add tests for new features

### Before Submitting PR
- [ ] Code follows project style guidelines (SOLID, DRY, KISS principles)
- [ ] All tests pass (`pytest` for backend, Xcode tests for iOS)
- [ ] No linter errors (`eslint` for website, SwiftLint for iOS)
- [ ] Documentation updated if needed
- [ ] Security considerations addressed
- [ ] Files kept under 500 lines (split into modules if needed)

---

## Known Issues & Important Notes

### Security & Dependencies
- **FastAPI Version Constraint**: Currently pinned to 0.115.6 due to dependency chain (httpx 0.27.2 → postgrest 0.17.2 → supabase 2.9.1). This prevents upgrading to starlette 0.49.1+ which includes CVE-2025-62727 (Range header ReDoS) fix.
  - **Mitigation**: `RangeHeaderValidationMiddleware` validates/rejects problematic Range headers
  - **TODO**: Upgrade when supabase SDK supports newer versions

### iOS Compatibility
- **iOS 18.6.2**: All interactive elements, form inputs, and navigation issues resolved as of December 2025
- **Minimum iOS**: 17.0+ required for SwiftUI features

### Deployment
- **Railway**: Backend deployed with optimized logging (access logs disabled to avoid rate limits)
- **Supabase**: All RLS policies optimized and security linter warnings resolved (2025-11-26)

## Version History

### v1.0.0 (Current - December 2025)

#### Latest Updates (December 2025)
- **iOS 18.6.2 Compatibility**: Fixed interactive elements, form inputs, and navigation freezes
- **Nutritional Data**: Enhanced feeding record calculations and consistency
- **Weight Calculations**: Improved veterinary weight tracking accuracy
- **Website Performance**: Optimized Next.js 16.0.10 landing page
- **Dependencies**: Updated to Next.js 16.0.10, urllib3 2.6.0 for security patches
- **TrackersView**: Replaced HistoryView with centralized tracking hub for health events
- **Visit Summaries**: Added vet-readable health summary generation feature
- **PostHog Analytics**: Integrated PostHog for comprehensive user behavior tracking
- **Enhanced Caching**: Multi-layer caching system with automatic sync and memory optimization
- **Subscription Tiers**: Defined free (5 scans/day, 1 pet) and premium (unlimited) tiers

#### Core Features
- **Nutrition Tracking**: Complete feeding logs, calorie goals, and weight management
- **Food Database**: Searchable database with barcode scanning and nutritional info
- **Advanced Analytics**: AI-powered nutritional insights and health trend analysis
- **Food Comparison**: Side-by-side comparison of multiple pet foods
- **Multi-Pet Support**: Track nutrition and health across all pets
- **Medication Reminders**: Comprehensive scheduling system with customizable frequencies
- **Subscription System**: Full App Store & RevenueCat integration with webhook support
- **Waitlist**: Pre-launch email signup system with notification queue
- **Data Quality**: Assessment endpoints for food item quality and improvement recommendations

#### Security & Infrastructure
- **Authentication**: Robust JWT validation with multi-strategy support
- **Database Security**: Row Level Security (RLS) with optimized performance patterns
- **Function Hardening**: All SECURITY DEFINER functions secured against search path injection
- **Supabase Linter**: All security warnings resolved (as of 2025-11-26)
- **Device Tokens**: Anonymous device registration for push notifications
- **Trailing Slash Support**: Consistent routing across all API endpoints
- **Error Handling**: Enhanced debugging with comprehensive error messages

#### Technical Stack
- **iOS**: Swift 5.9+, SwiftUI, iOS 17.0+
- **Backend**: Python 3.9+, FastAPI 0.115.6, Uvicorn 0.37+
- **Database**: Supabase 2.9.1, PostgreSQL with RLS
- **Website**: Next.js 16.0.10, React 19.0.0, TypeScript 5.6.0
- **Deployment**: Railway (API), Vercel-ready (Website)
- **Analytics**: PostHog (user behavior tracking)
- **Subscriptions**: RevenueCat (subscription management)

## Environment Variables Reference

### Required Variables (Backend)
```bash
# Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_JWT_SECRET=your_jwt_secret

# Security
SECRET_KEY=your_secret_key_min_32_chars
ALGORITHM=HS256

# Database
DATABASE_URL=postgresql://...
```

### Optional Variables
```bash
# Push Notifications
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_BUNDLE_ID=com.snifftest.app
APNS_PRIVATE_KEY=your_private_key_p8

# RevenueCat (Subscriptions)
REVENUECAT_API_KEY=your_api_key
REVENUECAT_WEBHOOK_SECRET=your_webhook_secret

# PostHog (Analytics) - Optional
POSTHOG_API_KEY=your_posthog_api_key
POSTHOG_HOST=https://us.i.posthog.com

# Redis (Rate Limiting)
REDIS_URL=redis://localhost:6379

# Environment
ENVIRONMENT=development|staging|production
DEBUG=true|false
LOG_LEVEL=INFO|DEBUG|WARNING|ERROR
```

See the [Server Setup](#server-setup) section for complete `.env` file example.

## Support & Resources

### Documentation
- **README**: This file - comprehensive project overview
- **API Documentation**: [API_DOCS.md](API_DOCS.md) - complete API reference
- **Scripts README**: `server/scripts/dev/README.md` - utility scripts guide
- **Pre-Production Checklist**: `server/scripts/deployment/PRE_PRODUCTION_CHECKLIST.md`

### Getting Help
- **Issues**: Report bugs or request features via GitHub Issues
- **Support Page**: Website support section for user-facing help
- **Health Endpoint**: `GET /health` - API health check and status

### Useful Commands
```bash
# Backend
cd server
python start.py                    # Start server
pytest tests/ -v                   # Run tests
pip-audit                          # Security scan

# iOS
cd pet-allergy-scanner
open SniffTest.xcodeproj          # Open in Xcode
# Cmd + B to build, Cmd + R to run

# Website
cd website
npm run dev                        # Development server
npm run build                      # Production build
npm run lint                       # Run linter
```

---

**Built with ❤️ for pet owners everywhere**

*Last updated: December 2025*
*iOS App Version: 1.0.0 (Pre-release)*
*API Version: 1.0.0*
*Website Version: 1.0.0*
*Database Schema: Updated 2025-11-26 with security hardening*
*Next.js: 16.0.10 | React: 19.0.0 | TypeScript: 5.6.0*