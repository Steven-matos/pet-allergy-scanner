# SniffTest Backend API 🐾

FastAPI backend for the SniffTest pet food allergy scanner iOS app. Production-ready API with advanced nutrition analytics, food comparison, and comprehensive pet health tracking.

## 🚀 Quick Reference

```bash
# Development
python start.py                           # Start dev server
python scripts/test_config.py            # Test configuration
pytest                                    # Run tests

# Deployment
railway login                             # Login to Railway
railway up                                # Deploy
railway logs                              # View logs

# Documentation
open http://localhost:8000/docs          # API docs (local)
open http://localhost:8000/redoc         # ReDoc (local)
```

## 🏗️ Architecture

- **Framework**: FastAPI 0.115.6 (Python 3.11+)
- **Database**: PostgreSQL via Supabase with async connection pooling
- **Authentication**: Supabase Auth + JWT with MFA support
- **Push Notifications**: Apple Push Notification service (APNs)
- **Storage**: Supabase Storage for images and file uploads
- **Deployment**: Railway with automated startup checks and health monitoring
- **Security**: Multi-layer middleware with rate limiting, request validation, and audit logging

## 📋 Features

### Core Features
- ✅ User authentication with MFA support
- ✅ Pet profile management with species-specific validation
- ✅ Ingredient scanning and OCR analysis
- ✅ Push notifications for iOS devices
- ✅ Image optimization and storage
- ✅ GDPR compliance (data export/deletion)
- ✅ Subscription management (App Store & RevenueCat)
- ✅ Waitlist signup functionality
- ✅ Health event tracking
- ✅ Medication reminder scheduling

### Nutrition & Analytics
- ✅ Advanced nutritional analysis with species-specific standards
- ✅ Food comparison engine
- ✅ Calorie tracking and daily goals
- ✅ Weight tracking with trend analysis
- ✅ Nutritional trend monitoring
- ✅ Ingredient allergen detection
- ✅ Data quality assessment for food items
- ✅ Comprehensive feeding logs
- ✅ Multi-pet nutrition insights

### Security & Compliance
- ✅ Rate limiting and security middleware
- ✅ Audit logging with rotation
- ✅ Request validation and sanitization
- ✅ CORS and security headers
- ✅ Comprehensive error handling

## 🚀 Quick Start (Local Development)

### Prerequisites
- Python 3.11+
- PostgreSQL (via Supabase)
- Apple Developer Account (for APNs)

### Setup

1. **Install dependencies**:
```bash
pip install -r requirements.txt
```

2. **Configure environment variables**:
```bash
cp env.example .env
# Edit .env with your actual values
```

3. **Run the server**:
```bash
python start.py
```

4. **Access API documentation**:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 🚂 Railway Deployment

### Quick Deploy (Recommended)

1. **Install Railway CLI**:
```bash
npm install -g @railway/cli
# or
brew install railway
```

2. **Login and initialize**:
```bash
railway login
railway init
```

3. **Set environment variables** (automated):
```bash
./railway-setup.sh
```

Or manually:
```bash
railway variables set SUPABASE_URL="your-value"
# ... see RAILWAY_DEPLOYMENT.md for all variables
```

4. **Deploy**:
```bash
railway up
```

5. **Get your URL**:
```bash
railway domain
```

### Detailed Instructions

See [RAILWAY_DEPLOYMENT.md](./RAILWAY_DEPLOYMENT.md) for comprehensive deployment guide.

## 📁 Project Structure

```
server/
├── app/                           # Main application code
│   ├── api/v1/                    # API version 1 endpoints
│   ├── core/                      # Configuration and core settings
│   │   ├── config.py              # Environment configuration
│   │   ├── database/              # Database connection pooling
│   │   ├── middleware/            # Core middleware components
│   │   ├── security/              # Auth, JWT, password hashing
│   │   └── validation/            # Request validation utilities
│   ├── middleware/                # Request/response middleware
│   │   ├── audit.py               # Audit logging
│   │   ├── request_limits.py     # Rate limiting
│   │   └── security.py            # Security headers
│   ├── models/                    # SQLAlchemy ORM models
│   │   ├── user.py                # User and auth models
│   │   ├── pet.py                 # Pet profiles
│   │   ├── scan.py                # Ingredient scans
│   │   ├── ingredient.py          # Ingredient database
│   │   ├── nutrition.py           # Nutritional data
│   │   ├── advanced_nutrition.py  # Advanced analytics
│   │   ├── food_items.py          # Food logging
│   │   └── calorie_goals.py       # Calorie tracking
│   ├── routers/                   # API route handlers
│   │   ├── auth.py                # Authentication
│   │   ├── mfa.py                 # Multi-factor auth
│   │   ├── pets.py                # Pet management
│   │   ├── scans.py               # Scanning endpoints
│   │   ├── ingredients.py         # Ingredient lookup
│   │   ├── nutritional_analysis.py # Nutrition analysis
│   │   ├── advanced_nutrition.py  # Advanced analytics
│   │   ├── food_management.py     # Food logging
│   │   ├── notifications.py       # Push notifications
│   │   ├── gdpr.py                # GDPR compliance
│   │   ├── images.py              # Image upload/processing
│   │   ├── monitoring.py          # Health checks & metrics
│   │   ├── subscriptions.py      # Subscription management
│   │   ├── health_events.py       # Health event tracking
│   │   ├── medication_reminders.py # Medication scheduling
│   │   ├── waitlist.py            # Waitlist signup
│   │   └── data_quality.py       # Data quality assessment
│   ├── services/                  # Business logic layer
│   │   ├── analytics/             # Analytics services
│   │   ├── advanced_analytics_service.py
│   │   ├── food_comparison_service.py
│   │   ├── nutritional_calculator.py
│   │   ├── nutritional_trends_service.py
│   │   ├── weight_tracking_service.py
│   │   ├── gdpr_service.py
│   │   ├── image_optimizer.py
│   │   ├── mfa_service.py
│   │   ├── push_notification_service.py
│   │   ├── storage_service.py
│   │   ├── monitoring.py
│   │   ├── subscription_service.py # App Store subscription verification
│   │   ├── revenuecat_service.py   # RevenueCat integration
│   │   ├── health_event_service.py # Health event management
│   │   ├── medication_reminder_service.py # Medication scheduling
│   │   └── data_quality_service.py # Data quality assessment
│   ├── shared/                    # Shared utilities
│   │   ├── repositories/          # Data access layer
│   │   └── services/              # Shared services
│   └── utils/                     # Helper functions
│       ├── error_handling.py      # Error handlers
│       └── logging_config.py      # Logging setup
├── database_schemas/              # SQL schema files
│   ├── 01_complete_database_schema.sql
│   └── 02_storage_setup.sql
├── importing/                     # Data import utilities
│   ├── import_no_duplicates.py   # Main import script
│   ├── count_products.py         # Product counting utility
│   └── README.md                 # Import documentation
├── keys/                          # APNs certificates (gitignored)
│   └── AuthKey_*.p8              # Apple Push keys
├── logs/                          # Application logs (gitignored)
│   └── audit.log                 # Security audit log
├── scripts/                       # Utility scripts
│   ├── README.md                  # Scripts documentation
│   ├── railway_start.py          # Railway startup (production)
│   ├── test_config.py            # Configuration testing
│   ├── check-deployment-ready.py # Deployment readiness checks
│   ├── generate-railway-vars.py  # Railway env var generator
│   ├── check_centralization.sh   # Code quality checker
│   ├── set_premium_account.py    # Admin: set premium status
│   ├── setup_test_data.py        # Test data setup
│   ├── analyze_database_tables.py # Database analysis
│   ├── cleanup_database.py       # Database cleanup utility
│   ├── fix_function_search_path_security.sql # Security fix
│   └── fix_auth_user_grant_error.sql # Auth error fix
├── standardizor/                  # Data standardization
│   ├── update_nutritional_info.py # Nutrition updates
│   └── README.md                  # Standardization docs
├── tests/                         # Test suite
│   ├── unit/                     # Unit tests
│   ├── run_tests.py              # Test runner
│   └── README.md                 # Test documentation
├── main.py                        # FastAPI app entry
├── start.py                       # Development server
├── requirements.txt               # Dependencies
├── requirements-lock.txt          # Locked versions
├── Procfile                       # Railway process
├── railway.toml                   # Railway config
└── env.example                    # Environment template
```

## 🔐 Environment Variables

Required variables (see `env.example` for complete list):

### Supabase
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_KEY` - Supabase anon key
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key
- `SUPABASE_JWT_SECRET` - JWT secret for token validation
- `DATABASE_URL` - PostgreSQL connection string

### Security
- `SECRET_KEY` - Application secret key (min 32 chars)
- `ALGORITHM` - JWT algorithm (HS256)
- `ACCESS_TOKEN_EXPIRE_MINUTES` - Token expiration time

### APNs (Apple Push Notifications)
- `APNS_URL` - APNs server URL (sandbox or production)
- `APNS_KEY_ID` - APNs key ID from Apple Developer
- `APNS_TEAM_ID` - Apple Team ID
- `APNS_BUNDLE_ID` - iOS app bundle identifier
- `APNS_PRIVATE_KEY` - APNs private key (P8 format)

### CORS & Hosts
- `ALLOWED_ORIGINS_STR` - Comma-separated allowed origins
- `ALLOWED_HOSTS_STR` - Comma-separated trusted hosts

### RevenueCat (Subscription Management)
- `REVENUECAT_API_KEY` - RevenueCat API key for subscription management
- `REVENUECAT_WEBHOOK_SECRET` - Secret for webhook signature verification

### Rate Limiting
- `RATE_LIMIT_PER_MINUTE` - General rate limit (default: 60)
- `AUTH_RATE_LIMIT_PER_MINUTE` - Auth endpoint rate limit (default: 5)

### Database Configuration
- `DATABASE_POOL_SIZE` - Connection pool size (default: 10)
- `DATABASE_TIMEOUT` - Connection timeout in seconds (default: 30)

### File Upload Limits
- `MAX_FILE_SIZE_MB` - Maximum file size for uploads (default: 10)
- `MAX_REQUEST_SIZE_MB` - Maximum request size (default: 50)

### Security Features
- `ENABLE_MFA` - Enable multi-factor authentication (default: true)
- `ENABLE_AUDIT_LOGGING` - Enable security audit logging (default: true)
- `SESSION_TIMEOUT_MINUTES` - Session timeout in minutes (default: 480)

### GDPR Compliance
- `DATA_RETENTION_DAYS` - Data retention period in days (default: 365)
- `ENABLE_DATA_EXPORT` - Enable data export functionality (default: true)
- `ENABLE_DATA_DELETION` - Enable account deletion (default: true)

### Logging & Environment
- `LOG_LEVEL` - Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `VERBOSE_LOGGING` - Enable detailed debug logging (default: false)
- `DEBUG` - General debug mode (default: false)
- `ENVIRONMENT` - Environment type (development, staging, production)

## 🧪 Testing

Run the comprehensive test suite:

```bash
# All tests
pytest

# With coverage
pytest --cov=app --cov-report=html tests/

# Specific test categories
pytest tests/unit/                # Unit tests
pytest tests/                     # All working tests

# Run test utility
python tests/run_tests.py
```

## 🛠️ Utility Scripts

The `scripts/` directory contains helpful utilities for deployment, development, and maintenance. See [`scripts/README.md`](./scripts/README.md) for detailed documentation.

### Deployment & Configuration
```bash
# Test environment configuration
python scripts/test_config.py

# Generate secure secret key
python scripts/test_config.py --generate-key

# Check if ready for Railway deployment
python scripts/check-deployment-ready.py

# Generate Railway environment variable commands
python scripts/generate-railway-vars.py

# Production startup (Railway uses this automatically via railway.toml)
python scripts/railway_start.py
```

### Development & Maintenance
```bash
# Check for centralization violations (code quality)
./scripts/check_centralization.sh

# Set user to premium status (admin utility)
python scripts/set_premium_account.py user@example.com

# Setup test data for development/testing
python scripts/setup_test_data.py
```

### Database Maintenance
```bash
# Analyze database table structure and statistics
python scripts/analyze_database_tables.py

# Cleanup database (removes food items without ingredients)
python scripts/cleanup_database.py --dry-run  # Dry run first
python scripts/cleanup_database.py            # Actual cleanup
```

### Security & Database Fixes

#### Function Search Path Security Fix
Fixes security vulnerabilities in SECURITY DEFINER functions by setting explicit search_path to prevent search path injection attacks.

**Usage**: Copy contents of `scripts/fix_function_search_path_security.sql` to Supabase SQL Editor and execute.

**When to run**: After Supabase linter reports security warnings about mutable search_path in functions.

#### Authentication Error Fix
Diagnoses and fixes common causes of "Database error granting user" authentication errors.

**Usage**: Copy contents of `scripts/fix_auth_user_grant_error.sql` to Supabase SQL Editor, review diagnostics, then execute appropriate fixes.

**When to run**: If users are experiencing login issues or authentication errors.

For detailed instructions on security fixes, see [`scripts/README.md`](./scripts/README.md).

## 📊 API Endpoints

### Authentication & Security
- `POST /api/v1/auth/signup` - Create new user account
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Logout user
- `POST /api/v1/mfa/setup` - Setup multi-factor authentication
- `POST /api/v1/mfa/verify` - Verify MFA code
- `POST /api/v1/mfa/disable` - Disable MFA

### Pet Management
- `GET /api/v1/pets` - List user's pets
- `POST /api/v1/pets` - Create pet profile
- `GET /api/v1/pets/{pet_id}` - Get pet details
- `PUT /api/v1/pets/{pet_id}` - Update pet profile
- `DELETE /api/v1/pets/{pet_id}` - Delete pet
- `GET /api/v1/pets/{pet_id}/allergies` - Get pet allergies

### Ingredient Scanning
- `POST /api/v1/scans` - Create new ingredient scan
- `GET /api/v1/scans` - List user's scans
- `GET /api/v1/scans/{scan_id}` - Get scan details
- `PUT /api/v1/scans/{scan_id}` - Update scan
- `DELETE /api/v1/scans/{scan_id}` - Delete scan
- `POST /api/v1/scans/analyze` - Analyze ingredients
- `GET /api/v1/ingredients` - Search ingredients
- `GET /api/v1/ingredients/common-allergens` - Get common allergens
- `GET /api/v1/ingredients/safe-alternatives` - Get safe alternatives

### Nutritional Analysis
- `POST /api/v1/nutrition/analysis/analyze` - Analyze food nutrition
- `GET /api/v1/nutrition/analysis/analyses/{pet_id}` - Get food analyses
- `POST /api/v1/nutrition/analysis/compatibility` - Check nutrition compatibility
- `GET /api/v1/nutrition/requirements/{pet_id}` - Get nutritional requirements
- `POST /api/v1/nutrition/requirements` - Create nutritional requirements
- `POST /api/v1/nutrition/feeding` - Log feeding record
- `GET /api/v1/nutrition/feeding/{pet_id}` - Get feeding history
- `GET /api/v1/nutrition/feeding/daily-summary/{pet_id}` - Get daily nutrition summary
- `POST /api/v1/nutrition/goals/calorie-goals` - Create calorie goal
- `GET /api/v1/nutrition/goals/calorie-goals` - Get calorie goals
- `GET /api/v1/nutrition/goals/calorie-goals/{pet_id}` - Get pet's active calorie goal
- `GET /api/v1/nutrition/summaries/insights/multi-pet` - Multi-pet nutrition insights
- `GET /api/v1/nutrition/advanced/analytics/overview` - Advanced nutrition analytics
- `GET /api/v1/nutrition/advanced/insights/{pet_id}` - Nutrition insights
- `GET /api/v1/nutrition/advanced/patterns/{pet_id}` - Nutrition patterns
- `GET /api/v1/nutrition/advanced/trends/{pet_id}` - Nutrition trends
- `GET /api/v1/nutrition/advanced/recommendations/{pet_id}` - Nutrition recommendations

### Advanced Nutrition & Analytics
- `POST /api/v1/advanced-nutrition/weight/record` - Record pet weight
- `GET /api/v1/advanced-nutrition/weight/history/{pet_id}` - Get weight history
- `POST /api/v1/advanced-nutrition/weight/goals` - Create weight goal
- `PUT /api/v1/advanced-nutrition/weight/goals` - Update weight goal
- `GET /api/v1/advanced-nutrition/weight/goals/{pet_id}/active` - Get active weight goal
- `GET /api/v1/advanced-nutrition/weight/trend/{pet_id}` - Get weight trend analysis
- `GET /api/v1/advanced-nutrition/weight/dashboard/{pet_id}` - Weight management dashboard
- `GET /api/v1/advanced-nutrition/trends/{pet_id}` - Get nutritional trends
- `GET /api/v1/advanced-nutrition/trends/dashboard/{pet_id}` - Nutritional trends dashboard
- `POST /api/v1/advanced-nutrition/comparisons` - Create food comparison
- `GET /api/v1/advanced-nutrition/comparisons/{comparison_id}` - Get food comparison
- `GET /api/v1/advanced-nutrition/comparisons` - List food comparisons
- `GET /api/v1/advanced-nutrition/comparisons/dashboard/{comparison_id}` - Comparison dashboard
- `DELETE /api/v1/advanced-nutrition/comparisons/{comparison_id}` - Delete food comparison
- `POST /api/v1/advanced-nutrition/analytics/generate` - Generate nutritional analytics
- `GET /api/v1/advanced-nutrition/analytics/health-insights/{pet_id}` - Get health insights
- `GET /api/v1/advanced-nutrition/analytics/patterns/{pet_id}` - Get nutritional patterns
- `GET /api/v1/advanced-nutrition/analytics/dashboard/{pet_id}` - Advanced nutrition dashboard

### Food Management
- `GET /api/v1/food-management/search` - Search foods
- `GET /api/v1/food-management/barcode/{barcode}` - Get food by barcode
- `GET /api/v1/food-management/recent` - Get recent foods
- `GET /api/v1/food-management/{food_id}` - Get food item
- `POST /api/v1/food-management` - Create food item
- `PUT /api/v1/food-management/{food_id}` - Update food item
- `DELETE /api/v1/food-management/{food_id}` - Delete food item
- `GET /api/v1/food-management/categories` - Get food categories
- `GET /api/v1/food-management/brands` - Get food brands

### Push Notifications
- `POST /api/v1/notifications/register` - Register device for push notifications
- `PUT /api/v1/notifications/preferences` - Update notification preferences
- `POST /api/v1/notifications/test` - Send test notification
- `DELETE /api/v1/notifications/unregister` - Unregister device

### Image Management
- `POST /api/v1/images/upload` - Upload and optimize image
- `GET /api/v1/images/{image_id}` - Get image
- `DELETE /api/v1/images/{image_id}` - Delete image

### Subscriptions
- `POST /api/v1/subscriptions/verify` - Verify App Store receipt
- `GET /api/v1/subscriptions/status` - Get subscription status
- `POST /api/v1/subscriptions/restore` - Restore purchases
- `POST /api/v1/subscriptions/webhook` - App Store webhook (internal)
- `POST /api/v1/subscriptions/revenuecat/webhook` - RevenueCat webhook
- `GET /api/v1/subscriptions/revenuecat/subscription-info/{user_id}` - Get RevenueCat subscription info

### Health Events & Medication
- `POST /api/v1/health-events` - Create health event
- `GET /api/v1/health-events` - List health events
- `GET /api/v1/health-events/{event_id}` - Get health event
- `PUT /api/v1/health-events/{event_id}` - Update health event
- `DELETE /api/v1/health-events/{event_id}` - Delete health event
- `POST /api/v1/medication-reminders` - Create medication reminder
- `GET /api/v1/medication-reminders/pet/{pet_id}` - Get reminders by pet
- `GET /api/v1/medication-reminders/{reminder_id}` - Get reminder
- `PUT /api/v1/medication-reminders/{reminder_id}` - Update reminder
- `DELETE /api/v1/medication-reminders/{reminder_id}` - Delete reminder
- `POST /api/v1/medication-reminders/{reminder_id}/activate` - Activate reminder
- `POST /api/v1/medication-reminders/{reminder_id}/deactivate` - Deactivate reminder
- `GET /api/v1/medication-reminders/frequencies/list` - Get available frequencies

### Waitlist
- `POST /api/v1/waitlist` - Sign up to waitlist

### Data Quality
- `GET /api/v1/data-quality/assess/{food_item_id}` - Assess food item quality
- `POST /api/v1/data-quality/assess/batch` - Batch quality assessment
- `GET /api/v1/data-quality/stats/overview` - Get quality statistics
- `GET /api/v1/data-quality/recommendations/{food_item_id}` - Get quality recommendations
- `GET /api/v1/data-quality/low-quality` - Get low quality items

### GDPR & Privacy
- `GET /api/v1/gdpr/export` - Export all user data (JSON)
- `DELETE /api/v1/gdpr/delete-account` - Permanently delete account
- `GET /api/v1/gdpr/data-summary` - Get data summary

### Monitoring & Health
- `GET /health` - Basic health check
- `GET /api/v1/monitoring/health` - Detailed health check
- `GET /api/v1/monitoring/metrics` - System metrics

## 🔍 Monitoring

### Health Check
```bash
curl https://your-app.up.railway.app/health
```

### Logs (Railway)
```bash
railway logs
```

### Metrics
- View in Railway dashboard
- CPU, Memory, Network usage
- Request counts and response times

## 🛡️ Security Features

### Request Protection
- ✅ Rate limiting (60 req/min general, 5 req/min for auth endpoints)
- ✅ Request size limits (configurable max file/request size)
- ✅ Range header validation (mitigates CVE-2025-62727 ReDoS vulnerability)
- ✅ Request timeout protection
- ✅ API version middleware

### Network Security
- ✅ CORS protection with configurable allowed origins
- ✅ Security headers (CSP, HSTS, X-Frame-Options, etc.)
- ✅ Trusted host middleware
- ✅ Referrer policy enforcement
- ✅ Cross-origin resource policy

### Authentication & Authorization
- ✅ JWT token validation with configurable expiration
- ✅ Multi-factor authentication (MFA) support
- ✅ Secure password hashing (bcrypt)
- ✅ Session timeout management
- ✅ Token refresh mechanism

### Data Protection
- ✅ SQL injection protection (via SQLAlchemy parameterized queries)
- ✅ XSS protection with input sanitization
- ✅ Input validation (Pydantic models)
- ✅ File upload validation (type, size, content)
- ✅ Audit logging for security events

### Database Security
- ✅ Row Level Security (RLS) policies in Supabase
- ✅ Function search path security (prevents injection)
- ✅ Secure connection pooling
- ✅ Database function security hardening

## 📥 Data Import

The server includes utilities for importing pet food data:

```bash
cd importing/

# Count products in JSONL file
python count_products.py

# Import data (skips duplicates)
python import_no_duplicates.py
```

See `importing/README.md` for detailed instructions.

### Nutritional Data Standardization
```bash
cd standardizor/
python update_nutritional_info.py
```

## 🐛 Troubleshooting

### Database Connection Issues
- Verify `DATABASE_URL` format: `postgresql://user:pass@host:port/db`
- Check Supabase connection pooler settings (use transaction mode)
- Ensure connection pool size: max 20 connections
- Test connection: `python scripts/test_config.py`

### APNs Certificate Issues
- Verify `.p8` file is in `keys/` directory
- Check `APNS_KEY_ID` matches your Apple Developer certificate
- Ensure `APNS_PRIVATE_KEY` has proper newlines (`\n`)
- Test notifications: `python tests/notifications/simple_apn_test.py`
- Use sandbox URL for development: `https://api.sandbox.push.apple.com`

### CORS Errors
- Update `ALLOWED_ORIGINS_STR` with your frontend URL
- Include protocol (http:// or https://)
- Don't include trailing slashes
- Example: `ALLOWED_ORIGINS_STR="https://app.example.com,http://localhost:3000"`

### Rate Limiting Issues
- Default: 60 requests/minute, 5/minute for auth endpoints
- Adjust in `app/middleware/request_limits.py`
- Check `X-RateLimit-*` headers in responses

### Image Upload Failures
- Check Supabase Storage bucket permissions
- Verify max file size (default: 10MB)
- Ensure `SUPABASE_SERVICE_ROLE_KEY` is set
- Check image MIME types (jpg, png, webp supported)

### 500 Internal Server Errors
- Check Railway logs: `railway logs --tail 100`
- Verify all required environment variables are set
- Check database schema is up to date
- Review `logs/audit.log` for security events
- Run deployment checks: `python scripts/check-deployment-ready.py`

### Performance Issues
- Monitor Railway dashboard for CPU/Memory usage
- Check database query performance in Supabase
- Review rate limiting settings
- Consider connection pooling adjustments (default: 10 connections)
- Enable query logging for slow queries
- Use `analyze_database_tables.py` to identify unused tables
- Review connection pool size vs. Supabase limits (max 20 connections)

### Testing Issues
- Install test dependencies: `pip install pytest pytest-asyncio`
- Run specific test: `pytest tests/path/to/test.py -v`
- Check test database connection
- Review `tests/README.md` for test-specific setup

## 📊 Analytics & Insights

The API provides comprehensive analytics for pet nutrition:

### Nutritional Trends
- Track nutrition intake over time (daily, weekly, monthly)
- Identify nutritional gaps and excesses
- Compare against species-specific standards
- Generate actionable recommendations

### Weight Tracking
- Log and monitor pet weight changes
- Calculate trends and growth rates
- Alert on concerning weight changes
- Visualize weight history

### Food Comparison
- Compare multiple food products side-by-side
- Analyze nutritional differences
- Identify best options for specific dietary needs
- Calculate cost-per-nutrient ratios

### Advanced Analytics
- Ingredient frequency analysis
- Allergen exposure tracking
- Nutritional diversity scoring
- Custom nutrition reports

## 📚 Documentation

### Project Documentation
- [`API_DOCS.md`](../API_DOCS.md) - Comprehensive API reference
- [`scripts/README.md`](./scripts/README.md) - Utility scripts documentation
- [`importing/README.md`](./importing/README.md) - Data import guide
- [`standardizor/README.md`](./standardizor/README.md) - Data standardization guide
- [`tests/README.md`](./tests/README.md) - Testing documentation

### External Resources
- [FastAPI Docs](https://fastapi.tiangolo.com/) - Framework documentation
- [Supabase Docs](https://supabase.com/docs) - Database & Auth
- [Railway Docs](https://docs.railway.app/) - Deployment platform
- [Pydantic v2 Docs](https://docs.pydantic.dev/) - Data validation

## 🤝 Contributing

### Development Guidelines

1. **Create feature branch**: `git checkout -b feature/your-feature`

2. **Follow coding principles**:
   - **SOLID** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
   - **DRY** - Don't Repeat Yourself
   - **KISS** - Keep It Simple, Stupid

3. **Code organization**:
   - Keep files under 500 lines (split into modules when needed)
   - Use functional, declarative programming
   - Prefer async/await for I/O operations
   - Use type hints for all function signatures

4. **Documentation**:
   - Add docstrings to all functions (JSDoc-style comments)
   - Document complex logic with inline comments
   - Update README files when adding features

5. **Testing**:
   - Run tests: `pytest`
   - Ensure all tests pass before submitting
   - Add tests for new features

6. **Code quality**:
   - Run `./scripts/check_centralization.sh` to check for violations
   - Follow error handling patterns (early returns, guard clauses)
   - Use Pydantic models for validation

7. **Submit pull request** with clear description of changes

## 📄 License

Proprietary - All rights reserved

## 📦 Dependencies

### Core Framework
- **FastAPI 0.115.6** - Web framework (pinned for compatibility)
- **Uvicorn** - ASGI server with performance improvements
- **Python 3.11+** - Required Python version

### Database & Supabase
- **Supabase 2.9.1** - Supabase client (pinned for stability)
- **SQLAlchemy 2.0+** - ORM with async support
- **asyncpg** - Async PostgreSQL driver
- **Alembic** - Database migrations

### Security & Authentication
- **PyJWT 2.10+** - JWT token handling
- **passlib[bcrypt]** - Password hashing
- **cryptography 46.0+** - Cryptographic operations
- **pyotp** - MFA/TOTP support

### Validation & Data
- **Pydantic 2.12+** - Data validation and settings
- **email-validator** - Email validation

### File Processing
- **Pillow 11.0+** - Image processing
- **python-multipart** - File upload handling
- **bleach** - HTML sanitization

### Performance & Monitoring
- **slowapi** - Rate limiting
- **psutil** - System monitoring

### Testing
- **pytest 8.4+** - Testing framework
- **pytest-asyncio** - Async test support

**Note**: Some dependencies are pinned to specific versions for compatibility. See `requirements.txt` for complete list with version constraints.

---

*Last updated: January 2025*
*API Version: 1.0.0*

Built with ❤️ for pet owners everywhere 🐶🐱
