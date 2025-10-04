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
│   │   └── AnalyticsManager.swift  # Centralized analytics service
│   ├── Configuration/              # App configuration management
│   │   ├── Configuration.swift     # App-wide configuration
│   │   └── CacheConfiguration.swift # Cache settings & policies
│   ├── Performance/                # Performance optimization
│   │   └── PerformanceOptimizer.swift # Memory & performance utilities
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
│   │   │   ├── CachedAuthService.swift # Cached auth operations
│   │   │   ├── MFAService.swift    # MFA implementation
│   │   │   └── KeychainHelper.swift # Secure credential storage
│   │   └── Views/                  # Authentication UI
│   │       ├── AuthenticationView.swift # Login/signup interface
│   │       ├── ForgotPasswordView.swift # Password recovery
│   │       └── MFASetupView.swift  # MFA configuration
│   │
│   ├── Pets/                       # Pet management feature
│   │   ├── Models/                 # Pet data models
│   │   │   └── Pet.swift           # Pet profile & allergy data
│   │   ├── Services/               # Pet business logic
│   │   │   ├── PetService.swift    # Core pet operations
│   │   │   └── CachedPetService.swift # Cached pet operations
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
│   │   │   └── CameraPermissionService.swift # Camera access
│   │   └── Views/                  # Scanning UI
│   │       ├── ScanView.swift      # Main scanning interface
│   │       ├── CameraView.swift    # Camera capture
│   │       ├── ScanResultView.swift # Scan results display
│   │       └── ImagePickerView.swift # Image selection
│   │
│   ├── Nutrition/                  # Nutritional analysis feature
│   │   ├── Models/                 # Nutrition data models
│   │   │   └── NutritionModels.swift # Nutrition & dietary data
│   │   ├── Services/               # Nutrition business logic
│   │   │   └── NutritionService.swift # Nutrition API integration
│   │   ├── ViewModels/             # Nutrition view models
│   │   │   └── NutritionActivityViewModel.swift # Activity tracking
│   │   └── Views/                  # Nutrition UI
│   │       └── NutritionDashboardView.swift # Nutrition overview
│   │
│   ├── Notifications/              # Push & local notifications
│   │   ├── Services/               # Notification business logic
│   │   │   ├── NotificationManager.swift # Central notification manager
│   │   │   ├── NotificationService.swift # Core notification service
│   │   │   ├── NotificationSettingsManager.swift # Settings management
│   │   │   └── PushNotificationService.swift # Push notification handling
│   │   └── Views/                  # Notification UI
│   │       ├── NotificationSettingsView.swift # Settings interface
│   │       ├── NotificationTestView.swift # Testing interface
│   │       └── NotificationSystemTestView.swift # System testing
│   │
│   ├── Profile/                    # User profile management
│   │   ├── Services/               # Profile business logic
│   │   │   └── StorageService.swift # Profile data storage
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
│   │   └── Views/
│   │       └── SubscriptionView.swift # Subscription interface
│   │
│   ├── Onboarding/                 # First-time user experience
│   │   └── Views/
│   │       └── OnboardingView.swift # User onboarding flow
│   │
│   └── Favorites/                  # Favorites management
│       └── Views/                  # (Empty - to be implemented)
│
├── Shared/                         # Shared Components (Cross-feature)
│   ├── Models/                     # Shared data models
│   │   ├── GDPRModels.swift        # GDPR compliance models
│   │   ├── MonitoringModels.swift  # App monitoring models
│   │   ├── CacheModels.swift       # Caching data models
│   │   └── MockData.swift          # Test & development data
│   ├── Services/                   # Shared business services
│   │   ├── APIService.swift        # Core API communication
│   │   ├── APIError.swift          # API error handling
│   │   ├── CacheManager.swift      # Centralized caching
│   │   ├── CacheService.swift      # Cache operations
│   │   ├── CacheAnalyticsService.swift # Cache analytics
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
│   │   └── SettingsManager.swift   # App settings management
│   └── Views/                      # Shared UI components
│       ├── MainTabView.swift       # Main tab navigation
│       ├── EmptyPetsView.swift     # Empty state components
│       ├── GDPRView.swift          # GDPR compliance UI
│       └── APNTestView.swift       # Push notification testing
│
├── Assets.xcassets/                # App assets & resources
│   ├── AppIcon.appiconset/         # App icons
│   ├── AccentColor.colorset/       # Accent color definition
│   └── Contents.json               # Asset catalog configuration
│
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
- **Analytics**: Centralized tracking and metrics
- **Configuration**: App-wide settings and environment management
- **Performance**: Memory optimization and performance monitoring
- **Security**: Authentication, encryption, and security policies

### **Features/ Directory**
Self-contained feature modules following MVVM:
- Each feature has its own `Models/`, `Services/`, and `Views/` subdirectories
- Features can optionally include `ViewModels/` for complex state management
- Features are loosely coupled and communicate through shared services

### **Shared/ Directory**
Cross-feature components and utilities:
- **Models**: Common data structures used by multiple features
- **Services**: Reusable business services and API clients
- **Utils**: Helper functions, validators, and design system
- **Views**: Reusable UI components and common layouts

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

**Total: 86 files reorganized**

### Key Movements:
- **Authentication**: 9 files (models, services, views)
- **Pets**: 8 files (models, services, views)
- **Scanning**: 8 files (models, services, views)
- **Nutrition**: 4 files (models, services, view models, views)
- **Notifications**: 7 files (services, views)
- **Profile**: 4 files (services, views)
- **Core**: 7 files (security, configuration, analytics, performance)
- **Shared**: 19 files (models, services, utilities, views)
- **Tests**: 6 files (unit tests)

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
- Lazy loading capabilities for features
- Centralized caching and performance optimization
- Efficient memory management through proper architecture

## Getting Started

### **For New Developers**
1. Review this folder structure documentation
2. Start with `App/` directory to understand app entry point
3. Explore `Features/` to understand feature organization
4. Check `Shared/` for common utilities and components
5. Review `Core/` for infrastructure components

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

**Documentation Updated**: January 2025  
**Architecture**: Feature-based MVVM with SOLID principles  
**Status**: Production-ready structure

