# Frontend Folder Structure Documentation

## iOS App Architecture Overview

The SniffTest iOS application follows a **feature-based architecture** with **MVVM pattern**, organized to maximize maintainability, scalability, and developer productivity. This structure adheres to SOLID principles, DRY methodology, and KISS design philosophy.

## Project Structure

```
SniffTest/                           # iOS App Root
├── App/                            # Application Entry Point
│   ├── SniffTestApp.swift          # Main app entry point & lifecycle
│   ├── ContentView.swift           # Root view coordinator
│   ├── Info.plist                  # App configuration & permissions
│   └── Resources/                  # Localized strings & assets
│       └── Localizable.strings     # Internationalization strings
│
├── Core/                           # Core Infrastructure (Cross-cutting concerns)
│   ├── Analytics/                  # Analytics & tracking
│   │   ├── AnalyticsManager.swift  # Centralized analytics service
│   │   └── PostHogAnalytics.swift  # PostHog analytics integration
│   ├── Configuration/              # App configuration management
│   │   ├── Configuration.swift     # App-wide configuration
│   │   ├── CacheConfiguration.swift # Cache settings & policies
│   │   ├── RevenueCatConfigurator.swift # RevenueCat subscription setup
│   │   └── PostHogConfigurator.swift # PostHog analytics setup
│   ├── Performance/                # Performance optimization
│   │   ├── PerformanceOptimizer.swift # Memory & performance utilities
│   │   ├── ModernPerformanceOptimizer.swift # Modern performance optimizations
│   │   ├── GraphicsOptimizer.swift # Graphics rendering optimization
│   │   └── MemoryMonitor.swift     # Memory monitoring utilities
│   └── Security/                   # Security infrastructure
│       ├── SecurityManager.swift   # Security policy enforcement
│       ├── SecureDataManager.swift # Secure data storage
│       └── CertificatePinning.swift # SSL certificate validation
│
├── Features/                       # Feature Modules (MVVM Architecture)
│   ├── Authentication/             # User authentication & security
│   │   ├── Models/                 # Authentication data models
│   │   │   ├── User.swift          # User profile model
│   │   │   └── MFAModels.swift     # Multi-factor auth models
│   │   ├── Services/               # Authentication business logic
│   │   │   ├── AuthService.swift   # Core authentication service
│   │   │   ├── AuthService+SessionRecovery.swift # Session recovery
│   │   │   ├── CachedAuthService.swift # Cached auth operations
│   │   │   ├── KeychainHelper.swift # Secure credential storage
│   │   │   └── SessionLifecycleManager.swift # Session lifecycle management
│   │   └── Views/                  # Authentication UI
│   │       ├── AuthenticationView.swift # Login/signup interface
│   │       └── ForgotPasswordView.swift # Password recovery
│   │
│   ├── Pets/                       # Pet management feature
│   │   ├── Models/                 # Pet data models
│   │   │   └── Pet.swift           # Pet profile & allergy data
│   │   ├── Services/               # Pet business logic
│   │   │   ├── CachedPetService.swift # Cached pet operations
│   │   │   ├── PetDataAggregator.swift # Pet data aggregation
│   │   │   └── PetDataPDFService.swift # PDF export service
│   │   └── Views/                  # Pet management UI
│   │       ├── PetsView.swift      # Pet list & management
│   │       ├── AddPetView.swift    # Add new pet
│   │       ├── EditPetView.swift   # Edit pet details
│   │       ├── PetSelectionView.swift # Pet selection interface
│   │       └── PetImagePickerView.swift # Pet photo selection
│   │
│   ├── Scanning/                   # Food scanning & analysis
│   │   ├── Models/                 # Scanning data models
│   │   │   ├── Scan.swift          # Scan result model
│   │   │   └── Ingredient.swift    # Ingredient analysis model
│   │   ├── Services/               # Scanning business logic
│   │   │   ├── ScanService.swift   # Core scanning operations
│   │   │   ├── CachedScanService.swift # Cached scan operations
│   │   │   ├── OCRService.swift    # Optical character recognition
│   │   │   ├── CameraPermissionService.swift # Camera access
│   │   │   ├── BarcodeService.swift # Barcode scanning
│   │   │   └── HybridScanService.swift # Hybrid OCR/Barcode scanning
│   │   ├── Utils/                  # Scanning utilities
│   │   │   └── OCRSpellChecker.swift # OCR text correction
│   │   └── Views/                  # Scanning UI
│   │       ├── ScanView.swift      # Main scanning interface
│   │       ├── CameraView.swift    # Camera capture
│   │       ├── ModernCameraView.swift # Modern camera UI
│   │       ├── SimpleCameraView.swift # Simple camera interface
│   │       ├── CameraControlsView.swift # Camera controls
│   │       ├── ScanResultView.swift # Scan results display
│   │       ├── ScanOverlayView.swift # Scanning overlay UI
│   │       ├── ScanComponents.swift # Reusable scan components
│   │       ├── ScanAccessibility.swift # Accessibility helpers
│   │       ├── ImagePickerView.swift # Image selection
│   │       ├── NutritionalLabelScanView.swift # Nutrition label scanning
│   │       ├── NutritionalLabelResultView.swift # Nutrition label results
│   │       ├── ProductFoundView.swift # Product found display
│   │       ├── ProductNotFoundView.swift # Product not found display
│   │       └── SensitivityAssessmentCard.swift # Sensitivity assessment UI
│   │
│   ├── Nutrition/                  # Nutritional analysis feature
│   │   ├── Models/                 # Nutrition data models
│   │   │   ├── NutritionModels.swift # Nutrition & dietary data
│   │   │   ├── FoodComparisonModels.swift # Food comparison models
│   │   │   └── NutritionTrendsModels.swift # Trends and analytics models
│   │   ├── Services/               # Nutrition business logic
│   │   │   ├── NutritionService.swift # Core nutrition API integration
│   │   │   ├── CachedNutritionService.swift # Cached nutrition operations
│   │   │   ├── WeightTrackingService.swift # Pet weight management
│   │   │   ├── CachedWeightTrackingService.swift # Cached weight tracking
│   │   │   ├── FoodService.swift # Food database operations
│   │   │   ├── CachedFoodService.swift # Cached food operations
│   │   │   ├── CalorieGoalsService.swift # Calorie goal management
│   │   │   ├── FeedingLogService.swift # Feeding log tracking
│   │   │   ├── CachedFoodComparisonService.swift # Cached food comparison
│   │   │   ├── CachedNutritionalTrendsService.swift # Cached trends
│   │   │   └── NutritionPetSelectionService.swift # Pet selection for nutrition
│   │   ├── ViewModels/             # Nutrition view models
│   │   │   └── NutritionActivityViewModel.swift # Activity tracking
│   │   └── Views/                  # Nutrition UI
│   │       ├── NutritionDashboardView.swift # Nutrition overview
│   │       ├── AdvancedNutritionView.swift # Advanced nutrition analytics
│   │       ├── WeightManagementView.swift # Weight tracking interface
│   │       ├── CalorieGoalsView.swift # Calorie goal management
│   │       ├── FeedingLogView.swift # Feeding log interface
│   │       ├── FoodComparisonView.swift # Food comparison UI
│   │       ├── FoodSelectionView.swift # Food selection interface
│   │       ├── NutritionalTrendsView.swift # Trends visualization
│   │       ├── AddFoodView.swift # Add food item interface
│   │       └── EnhancedFoodSearchView.swift # Enhanced food search
│   │
│   ├── Notifications/              # Push & local notifications
│   │   ├── Services/               # Notification business logic
│   │   │   ├── NotificationManager.swift # Central notification manager
│   │   │   ├── NotificationService.swift # Core notification service
│   │   │   ├── NotificationSettingsManager.swift # Settings management
│   │   │   ├── PushNotificationService.swift # Push notification handling
│   │   │   └── MealReminderService.swift # Meal reminder scheduling
│   │   └── Views/                  # Notification UI
│   │       ├── NotificationSettingsView.swift # Settings interface
│   │       ├── NotificationTestView.swift # Testing interface
│   │       └── NotificationSystemTestView.swift # System testing
│   │
│   ├── Profile/                    # User profile management
│   │   ├── Services/               # Profile business logic
│   │   │   ├── StorageService.swift # Profile data storage
│   │   │   └── CachedProfileService.swift # Cached profile operations
│   │   └── Views/                  # Profile UI
│   │       ├── ProfileSettingsView.swift # Profile settings
│   │       ├── EditProfileView.swift # Profile editing
│   │       └── BirthdayCelebrationView.swift # Special celebrations
│   │
│   ├── History/                    # Scan history feature
│   │   └── Views/
│   │       └── HistoryView.swift   # Scan history display
│   │
│   ├── Help/                       # Help & support
│   │   └── Views/
│   │       └── HelpSupportView.swift # Help interface
│   │
│   ├── Subscription/               # Subscription management
│   │   ├── Models/                 # Subscription data models
│   │   │   ├── SubscriptionProduct.swift # Product model
│   │   │   └── SubscriptionTier.swift # Subscription tier model
│   │   ├── Services/               # Subscription business logic
│   │   │   ├── RevenueCatSubscriptionProvider.swift # RevenueCat integration
│   │   │   └── DailyScanCounter.swift # Scan limit tracking
│   │   ├── ViewModels/             # Subscription view models
│   │   │   └── SubscriptionViewModel.swift # Subscription state management
│   │   └── Views/                  # Subscription UI
│   │       ├── SubscriptionView.swift # Main subscription interface
│   │       ├── PaywallView.swift # Premium paywall
│   │       ├── UpgradePromptView.swift # Upgrade prompts
│   │       ├── ScanLimitIndicator.swift # Scan limit display
│   │       ├── PremiumBadge.swift # Premium badge component
│   │       └── CustomerCenterExtension.swift # Customer center integration
│   │
│   ├── Tracking/                   # Health & medication tracking
│   │   ├── Models/                 # Tracking data models
│   │   │   ├── HealthEvent.swift  # Health event model
│   │   │   └── MedicationReminder.swift # Medication reminder model
│   │   ├── Services/               # Tracking business logic
│   │   │   ├── HealthEventService.swift # Health event management
│   │   │   └── MedicationReminderService.swift # Medication scheduling
│   │   └── Views/                  # Tracking UI
│   │       ├── TrackersView.swift # Main tracking hub
│   │       ├── HealthEventListView.swift # Health events list
│   │       ├── HealthEventDetailView.swift # Health event details
│   │       ├── AddHealthEventView.swift # Add health event
│   │       └── DocumentPickerView.swift # Document attachment
│   │
│   ├── Onboarding/                 # First-time user experience
│   │   ├── LaunchScreenView.swift  # Launch screen
│   │   └── Views/
│   │       └── OnboardingView.swift # User onboarding flow
│   │
│   └── Settings/                   # App settings management
│       └── Services/
│           └── WeightUnitPreferenceService.swift # Weight unit preferences
│
├── Shared/                         # Shared Components (Cross-feature)
│   ├── Models/                     # Shared data models
│   │   ├── GDPRModels.swift        # GDPR compliance models
│   │   ├── MonitoringModels.swift  # App monitoring models
│   │   ├── CacheModels.swift       # Caching data models
│   │   ├── FoodProduct.swift       # Food product data model
│   │   └── MockData.swift          # Test & development data
│   ├── Services/                   # Shared business services
│   │   ├── APIService.swift        # Core API communication
│   │   ├── APIError.swift          # API error handling
│   │   ├── CacheManager.swift      # Centralized caching
│   │   ├── EnhancedCacheManager.swift # Enhanced multi-layer caching
│   │   ├── CacheService.swift      # Cache operations
│   │   ├── CacheAnalyticsService.swift # Cache analytics
│   │   ├── CacheHydrationService.swift # Cache warming & hydration
│   │   ├── DataQualityService.swift # Data quality assessment
│   │   ├── MemoryEfficientImageProcessor.swift # Memory-optimized image processing
│   │   ├── PetSensitivityService.swift # Pet sensitivity analysis
│   │   ├── GDPRService.swift       # GDPR compliance
│   │   ├── MonitoringService.swift # App monitoring
│   │   └── URLHandler.swift        # Deep linking & URL handling
│   ├── Utils/                      # Shared utilities
│   │   ├── ModernDesignSystem.swift # Design system & theming
│   │   ├── InputValidator.swift    # Input validation utilities
│   │   ├── LocalizationHelper.swift # Internationalization
│   │   ├── HapticFeedback.swift    # Haptic feedback utilities
│   │   ├── ImageLoader.swift       # Image loading utilities
│   │   ├── ImageOptimizer.swift    # Image optimization
│   │   ├── UIImage+MemoryOptimization.swift # UIImage memory extensions
│   │   ├── KeyboardManager.swift   # Keyboard handling utilities
│   │   ├── OrientationManager.swift # Device orientation management
│   │   ├── SystemWarningSuppressionHelper.swift # Console warning suppression
│   │   ├── SettingsManager.swift   # App settings management
│   │   └── BundleExtension.swift   # Bundle utility extensions
│   └── Views/                      # Shared UI components
│       ├── MainTabView.swift       # Main tab navigation
│       ├── EmptyPetsView.swift     # Empty state components
│       ├── GDPRView.swift          # GDPR compliance UI
│       ├── LegalViews.swift        # Legal & terms views
│       ├── NutritionComponents.swift # Reusable nutrition components
│       ├── CacheHydrationProgressView.swift # Cache warming progress
│       ├── SafeTextField.swift     # Safe text input component
│       ├── ModernSwiftUIAnimations.swift # Modern animation utilities
│       └── ModernSwiftUIConcurrency.swift # Concurrency helpers
│
├── Assets.xcassets/                # App assets & resources
│   ├── AppIcon.appiconset/         # App icons
│   ├── AccentColor.colorset/       # Accent color definition
│   ├── softCream.colorset/         # Soft cream color
│   ├── Branding/                   # Brand assets
│   │   ├── app-logo.imageset/      # App logo
│   │   └── launch-icon.imageset/   # Launch screen icon
│   ├── Icons/                      # Icon assets
│   ├── Illustrations/              # Illustration assets
│   │   ├── cat-scale.imageset/     # Cat scale illustration
│   │   ├── cat-scanning.imageset/   # Cat scanning illustration
│   │   ├── cat-tracking.imageset/   # Cat tracking illustration
│   │   ├── chi-chi-tracking.imageset/ # Dog tracking illustration
│   │   ├── dog-scale.imageset/     # Dog scale illustration
│   │   ├── dog-scanning.imageset/   # Dog scanning illustration
│   │   ├── premium-feature.imageset/ # Premium feature illustration
│   │   ├── running.imageset/       # Running illustration
│   │   └── welcome.imageset/       # Welcome illustration
│   ├── Placeholders/               # Placeholder images
│   │   ├── cat-placeholder.imageset/ # Cat placeholder
│   │   └── dog-placeholder.imageset/ # Dog placeholder
│   └── Contents.json               # Asset catalog configuration
│
├── Configuration.storekit          # StoreKit configuration for testing
├── SniffTest.entitlements         # App capabilities & permissions
├── LaunchScreen.storyboard        # Launch screen interface
└── Tests/                          # Test Suite
    └── SniffTestTests/             # Unit & integration tests
        ├── APIErrorTests.swift     # API error handling tests
        ├── APIServiceTests.swift   # API service tests
        ├── AuthServiceTests.swift  # Authentication tests
        ├── PetModelTests.swift     # Pet model tests
        ├── UserModelTests.swift    # User model tests
        └── SettingsPersistenceTest.swift # Settings persistence tests
```

## Architecture Principles

### 1. **Feature-Based Organization**
Each major feature is self-contained with its own:
- **Models**: Data structures and business entities
- **Services**: Business logic and data operations  
- **Views**: User interface components
- **ViewModels**: (When needed) View-specific logic and state management

**Benefits:**
- Clear separation of concerns
- Independent development and testing
- Easy to locate and modify feature-specific code
- Reduces merge conflicts in team development

### 2. **Core Infrastructure Separation**
Cross-cutting concerns are centralized in the `Core/` directory:
- **Security**: Authentication, encryption, certificate pinning
- **Analytics**: User behavior tracking and metrics
- **Configuration**: App settings and environment management
- **Performance**: Memory management and optimization utilities

**Benefits:**
- Single source of truth for infrastructure concerns
- Consistent implementation across features
- Easy to update security or performance policies globally

### 3. **Shared Components Architecture**
Common functionality is centralized in `Shared/`:
- **Models**: Cross-feature data structures (GDPR, Monitoring, Cache)
- **Services**: Reusable business services (API, Cache, GDPR)
- **Utils**: Helper functions and utilities
- **Views**: Reusable UI components

**Benefits:**
- Promotes DRY (Don't Repeat Yourself) principle
- Consistent user experience across features
- Centralized maintenance of common functionality

### 4. **MVVM Pattern Implementation**
Each feature follows the Model-View-ViewModel pattern:
- **Models**: Pure data structures with business logic
- **Views**: SwiftUI views focused on presentation
- **ViewModels**: (Optional) Complex view logic and state management
- **Services**: Business logic and data operations

**Benefits:**
- Clear separation between UI and business logic
- Testable and maintainable code
- Follows iOS development best practices

## Folder Structure Rationale

### **App/ Directory**
Contains the application entry point and root configuration:
- `SniffTestApp.swift`: Main app lifecycle and dependency injection
- `ContentView.swift`: Root view coordinator and navigation
- `Info.plist`: App permissions and configuration
- `Resources/`: Localization and static assets

### **Core/ Directory**
Infrastructure components used across all features:
- **Analytics**: Centralized tracking and metrics (AnalyticsManager, PostHogAnalytics)
- **Configuration**: App-wide settings and environment management (Configuration, RevenueCatConfigurator, PostHogConfigurator)
- **Performance**: Memory optimization and performance monitoring (PerformanceOptimizer, ModernPerformanceOptimizer, GraphicsOptimizer, MemoryMonitor)
- **Security**: Authentication, encryption, and security policies (SecurityManager, SecureDataManager, CertificatePinning)

### **Features/ Directory**
Self-contained feature modules following MVVM:
- Each feature has its own `Models/`, `Services/`, and `Views/` subdirectories
- Features can optionally include `ViewModels/` for complex state management
- Features are loosely coupled and communicate through shared services

### **Shared/ Directory**
Cross-feature components and utilities:
- **Models**: Common data structures used by multiple features (GDPRModels, MonitoringModels, CacheModels, FoodProduct, MockData)
- **Services**: Reusable business services and API clients (APIService, EnhancedCacheManager, CacheHydrationService, DataQualityService, PetSensitivityService, MemoryEfficientImageProcessor)
- **Utils**: Helper functions, validators, and design system (ModernDesignSystem, InputValidator, KeyboardManager, OrientationManager, SystemWarningSuppressionHelper, UIImage+MemoryOptimization)
- **Views**: Reusable UI components and common layouts (MainTabView, CacheHydrationProgressView, SafeTextField, ModernSwiftUIAnimations, ModernSwiftUIConcurrency)

## Design Patterns Applied

### **SOLID Principles**
- **Single Responsibility**: Each class/file has one clear purpose
- **Open/Closed**: Features are open for extension, closed for modification
- **Liskov Substitution**: Services follow clear protocols/interfaces
- **Interface Segregation**: Small, focused protocols for specific needs
- **Dependency Inversion**: Features depend on abstractions, not concrete implementations

### **DRY (Don't Repeat Yourself)**
- Shared utilities and services are centralized
- Common models are in `Shared/Models`
- Reusable views are in `Shared/Views`
- Consistent patterns across features

### **KISS (Keep It Simple, Stupid)**
- Clear, intuitive folder structure
- Logical grouping by feature domain
- Easy to navigate and understand
- Minimal complexity in file organization

## Development Guidelines

### **File Naming Conventions**
- **Swift Files**: PascalCase (e.g., `PetService.swift`, `AuthenticationView.swift`)
- **Directories**: PascalCase for feature names, lowercase for subdirectories
- **Models**: Descriptive names ending with model type (e.g., `User.swift`, `Pet.swift`)
- **Services**: Descriptive names ending with "Service" (e.g., `AuthService.swift`)
- **Views**: Descriptive names ending with "View" (e.g., `LoginView.swift`)

### **Code Organization Rules**
1. **One Class Per File**: Each Swift file should contain one primary class/struct
2. **Feature Isolation**: Keep feature-specific code within its feature directory
3. **Shared Code**: Place reusable code in `Shared/` directory
4. **Core Infrastructure**: Place cross-cutting concerns in `Core/` directory

### **Import Guidelines**
- Use specific imports when possible
- Group imports: System frameworks, third-party libraries, local modules
- Avoid circular dependencies between features

### **Testing Strategy**
- Unit tests for each service and model
- Integration tests for feature workflows
- UI tests for critical user journeys
- Mock data in `Shared/Models/MockData.swift`

## File Organization Summary

**Total: 103+ Swift files**

### Feature Breakdown:
- **Authentication**: 6 files (1 model, 5 services, 2 views)
- **Pets**: 9 files (1 model, 3 services, 5 views)
- **Scanning**: 24 files (2 models, 6 services, 1 utility, 15 views)
- **Nutrition**: 25 files (3 models, 11 services, 1 view model, 10 views)
- **Notifications**: 6 files (5 services, 1 view)
- **Profile**: 5 files (2 services, 3 views)
- **Subscription**: 12 files (2 models, 2 services, 1 view model, 7 views)
- **Tracking**: 9 files (2 models, 2 services, 5 views)
- **History**: 1 file (1 view)
- **Help**: 1 file (1 view)
- **Onboarding**: 2 files (1 launch screen, 1 view)
- **Settings**: 1 file (1 service)
- **Core**: 10 files (3 security, 4 configuration, 2 analytics, 4 performance)
- **Shared**: 35+ files (5+ models, 13+ services, 12+ utilities, 8+ views)
- **App**: 2 files (main app, content view)
- **Tests**: 6+ files (unit tests)

## Benefits of This Structure

### **Maintainability**
- Clear separation of concerns makes code easier to understand and modify
- Feature isolation reduces the impact of changes
- Consistent patterns across the codebase

### **Scalability**
- Easy to add new features without affecting existing code
- Clear structure supports team growth
- Modular architecture allows for independent feature development

### **Developer Experience**
- Intuitive folder structure reduces onboarding time
- Easy to locate specific functionality
- Clear patterns make code reviews more effective

### **Testing & Quality**
- Feature isolation makes unit testing simpler
- Clear separation between UI and business logic
- Centralized test utilities and mock data

### **Performance**
- Multi-layer caching system (URLSession, memory, disk)
- Enhanced cache manager with automatic invalidation and warming
- Memory-efficient image processing and optimization
- Memory monitoring and performance optimization utilities
- Lazy loading capabilities for features
- Efficient memory management through proper architecture
- Background cache warming on app launch

## App Initialization

The app follows a structured initialization pattern in `SniffTestApp.swift`:

### Startup Sequence
1. **Service Initialization**: Shared service instances created (AuthService, PetService, NotificationManager, CacheManager)
2. **Cache Warming**: Cache manager warms cache on app launch for better performance
3. **Configuration**: RevenueCat and PostHog configured via AppDelegate
4. **Push Notifications**: Push notification delegate configured
5. **System Configuration**: System warning suppression configured

### Key Services
- **AuthService.shared**: Centralized authentication management
- **CachedPetService.shared**: Pet data with caching
- **NotificationManager.shared**: Push and local notifications
- **EnhancedCacheManager.shared**: Multi-layer caching system

### Third-Party Integrations
- **RevenueCat**: Configured via `RevenueCatConfigurator` using Info.plist values
- **PostHog**: Configured via `PostHogConfigurator` using Info.plist values
- **StoreKit**: Configured via `Configuration.storekit` for testing

## Getting Started

### **For New Developers**
1. Review this folder structure documentation
2. Start with `App/` directory to understand app entry point
3. Explore `Features/` to understand feature organization
4. Check `Shared/` for common utilities and components
5. Review `Core/` for infrastructure components
6. Review `SniffTestApp.swift` to understand app initialization

### **For Adding New Features**
1. Create new feature directory in `Features/`
2. Follow MVVM pattern with `Models/`, `Services/`, `Views/` subdirectories
3. Add feature-specific tests in `Tests/`
4. Use shared services and utilities from `Shared/`
5. Follow established naming conventions

### **For Modifying Existing Features**
1. Locate feature in `Features/` directory
2. Make changes within feature boundaries
3. Use shared services for cross-feature functionality
4. Update tests as needed
5. Follow code organization rules

---

## Tech Stack & Dependencies

### Core Frameworks
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for data flow
- **Foundation** - Core system frameworks
- **UIKit** - UI components and system integration

### Third-Party Libraries
- **RevenueCat** - Subscription management and analytics
- **RevenueCatUI** - Pre-built subscription UI components
- **PostHog** - Product analytics and user behavior tracking

### iOS Features
- **StoreKit** - In-app purchases and subscriptions
- **UserNotifications** - Push and local notifications
- **AVFoundation** - Camera and media capture
- **Vision** - OCR and image analysis
- **CoreML** - Machine learning (if applicable)

### Configuration
- **Info.plist** - App configuration and permissions
- **PrivacyInfo.xcprivacy** - Privacy manifest for App Store
- **Configuration.storekit** - StoreKit testing configuration
- **SniffTest.entitlements** - App capabilities (push notifications, etc.)

## Documentation Status

**Last Verified**: January 2025  
**Architecture**: Feature-based MVVM with SOLID principles  
**Status**: ✅ Production-ready - Verified against codebase  
**Total Files**: 103+ Swift files across all features

### Recent Updates (January 2025)
- ✅ Added PostHog analytics integration with PostHogConfigurator
- ✅ Enhanced caching with EnhancedCacheManager (multi-layer caching)
- ✅ Added CacheHydrationService for cache warming
- ✅ Added MemoryEfficientImageProcessor for optimized image handling
- ✅ Added PetSensitivityService for sensitivity analysis
- ✅ Added DataQualityService for data quality assessment
- ✅ Enhanced utilities: KeyboardManager, OrientationManager, SystemWarningSuppressionHelper
- ✅ Added UIImage+MemoryOptimization extension
- ✅ Added ModernSwiftUIAnimations and ModernSwiftUIConcurrency helpers
- ✅ Enhanced Core/Performance with ModernPerformanceOptimizer and MemoryMonitor
- ✅ Updated Subscription feature with SubscriptionBlockerView
- ✅ Enhanced Scanning feature with additional views (15 total views)
- ✅ Updated Nutrition feature with 11 services (including cached variants)
- ✅ All directory structures verified against actual codebase
- ✅ Updated file count to reflect current structure (103+ files)

