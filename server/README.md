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

- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL via Supabase
- **Authentication**: Supabase Auth + JWT with MFA
- **Push Notifications**: Apple Push Notification service (APNs)
- **Storage**: Supabase Storage for images
- **Deployment**: Railway with automated startup checks

## 📋 Features

### Core Features
- ✅ User authentication with MFA support
- ✅ Pet profile management with species-specific validation
- ✅ Ingredient scanning and OCR analysis
- ✅ Push notifications for iOS devices
- ✅ Image optimization and storage
- ✅ GDPR compliance (data export/deletion)

### Nutrition & Analytics
- ✅ Advanced nutritional analysis with species-specific standards
- ✅ Food comparison engine
- ✅ Calorie tracking and daily goals
- ✅ Weight tracking with trend analysis
- ✅ Nutritional trend monitoring
- ✅ Ingredient allergen detection

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
│   │   └── monitoring.py          # Health checks & metrics
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
│   │   └── monitoring.py
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
│   └── FULL_IMPORT_GUIDE.md      # Import documentation
├── keys/                          # APNs certificates (gitignored)
│   └── AuthKey_*.p8              # Apple Push keys
├── logs/                          # Application logs (gitignored)
│   └── audit.log                 # Security audit log
├── scripts/                       # Utility scripts
│   ├── railway_start.py          # Railway startup
│   ├── test_config.py            # Config testing
│   ├── check-deployment-ready.py # Deployment checks
│   └── generate-railway-vars.py  # Env generator
├── standardizor/                  # Data standardization
│   └── update_nutritional_info.py # Nutrition updates
├── tests/                         # Test suite
│   ├── database/                 # Database tests
│   ├── integration/              # Integration tests
│   ├── notifications/            # APNs tests
│   ├── nutrition/                # Nutrition tests
│   ├── security/                 # Security tests
│   └── unit/                     # Unit tests
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

## 🧪 Testing

Run the comprehensive test suite:

```bash
# All tests
pytest

# With coverage
pytest --cov=app --cov-report=html tests/

# Specific test categories
pytest tests/nutrition/           # Nutrition tests
pytest tests/security/            # Security audit
pytest tests/notifications/       # APNs tests
pytest tests/database/            # Database policy tests

# Run test utility
python tests/run_tests.py
```

## 🛠️ Utility Scripts

The `scripts/` directory contains helpful utilities:

### Configuration Testing
```bash
# Test environment configuration
python scripts/test_config.py

# Generate secure secret key
python scripts/test_config.py --generate-key
```

### Deployment Preparation
```bash
# Check if ready for Railway deployment
python scripts/check-deployment-ready.py

# Generate Railway environment variable commands
python scripts/generate-railway-vars.py
```

### Production Startup
```bash
# Railway uses this automatically (via railway.toml)
python scripts/railway_start.py
```

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
- `POST /api/v1/scans/{scan_id}/analyze` - Analyze scanned ingredients
- `GET /api/v1/ingredients/search` - Search ingredient database

### Nutritional Analysis
- `POST /api/v1/nutrition/analyze` - Analyze ingredient nutrition
- `GET /api/v1/nutrition/recommendations` - Get pet-specific recommendations
- `GET /api/v1/nutrition/standards/{species}` - Get nutritional standards
- `POST /api/v1/nutrition/compare` - Compare multiple products

### Advanced Nutrition & Analytics
- `GET /api/v1/advanced-nutrition/trends` - Get nutritional trends
- `GET /api/v1/advanced-nutrition/insights` - Get nutritional insights
- `POST /api/v1/advanced-nutrition/analysis` - Advanced nutritional analysis
- `POST /api/v1/food-comparison` - Compare food products
- `GET /api/v1/weight-tracking` - Get weight history
- `POST /api/v1/weight-tracking` - Log weight entry
- `GET /api/v1/weight-tracking/trends` - Get weight trends

### Food & Calorie Management
- `POST /api/v1/food-items` - Log food item
- `GET /api/v1/food-items` - List logged food items
- `PUT /api/v1/food-items/{item_id}` - Update food item
- `DELETE /api/v1/food-items/{item_id}` - Delete food item
- `GET /api/v1/calorie-goals` - Get calorie tracking goals
- `POST /api/v1/calorie-goals` - Set calorie goals
- `GET /api/v1/calorie-goals/progress` - Get daily progress

### Push Notifications
- `POST /api/v1/notifications/register` - Register device for push notifications
- `PUT /api/v1/notifications/preferences` - Update notification preferences
- `POST /api/v1/notifications/test` - Send test notification
- `DELETE /api/v1/notifications/unregister` - Unregister device

### Image Management
- `POST /api/v1/images/upload` - Upload and optimize image
- `GET /api/v1/images/{image_id}` - Get image
- `DELETE /api/v1/images/{image_id}` - Delete image

### GDPR & Privacy
- `GET /api/v1/gdpr/export` - Export all user data (JSON)
- `DELETE /api/v1/gdpr/delete-account` - Permanently delete account
- `GET /api/v1/gdpr/data-summary` - Get data summary

### Monitoring & Health
- `GET /health` - Basic health check
- `GET /api/v1/monitoring/metrics` - System metrics
- `GET /api/v1/monitoring/status` - Detailed status check

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

- ✅ Rate limiting (60 req/min, 5 req/min for auth)
- ✅ CORS protection
- ✅ Security headers (CSP, HSTS, etc.)
- ✅ Request size limits
- ✅ SQL injection protection (via SQLAlchemy)
- ✅ XSS protection
- ✅ Audit logging
- ✅ MFA support
- ✅ JWT token validation
- ✅ Input validation (Pydantic)

## 📥 Data Import

The server includes utilities for importing pet food data:

```bash
cd importing/

# Count products in JSONL file
python count_products.py

# Import data (skips duplicates)
python import_no_duplicates.py

# Analyze skipped products
python analyze_skipped_products.py
```

See `importing/FULL_IMPORT_GUIDE.md` for detailed instructions.

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
- Consider connection pooling adjustments
- Enable query logging for slow queries

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

- [`API_DOCS.md`](../API_DOCS.md) - Comprehensive API reference
- [`importing/FULL_IMPORT_GUIDE.md`](./importing/FULL_IMPORT_GUIDE.md) - Data import guide
- [`standardizor/NUTRITIONAL_INFO_API_REFERENCE.md`](./standardizor/NUTRITIONAL_INFO_API_REFERENCE.md) - Nutrition standards
- [FastAPI Docs](https://fastapi.tiangolo.com/) - Framework documentation
- [Supabase Docs](https://supabase.com/docs) - Database & Auth

## 🤝 Contributing

1. Create feature branch: `git checkout -b feature/your-feature`
2. Follow SOLID, DRY, and KISS principles
3. Keep files under 500 lines
4. Add docstrings to all functions
5. Run tests: `pytest`
6. Submit pull request

## 📄 License

Proprietary - All rights reserved

---

Built with ❤️ for pet owners everywhere 🐶🐱
