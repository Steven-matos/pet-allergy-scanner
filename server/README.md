# SniffTest Backend API 🐾

FastAPI backend for the SniffTest pet food allergy scanner iOS app.

## 🏗️ Architecture

- **Framework**: FastAPI (Python 3.11+)
- **Database**: PostgreSQL via Supabase
- **Authentication**: Supabase Auth + JWT
- **Push Notifications**: Apple Push Notification service (APNs)
- **Storage**: Supabase Storage for images

## 📋 Features

- ✅ User authentication with MFA support
- ✅ Pet profile management
- ✅ Ingredient scanning and analysis
- ✅ Nutritional analysis and tracking
- ✅ Food item management with calorie tracking
- ✅ Push notifications for iOS
- ✅ GDPR compliance (data export/deletion)
- ✅ Rate limiting and security middleware
- ✅ Audit logging
- ✅ Comprehensive API documentation

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
├── app/
│   ├── core/              # Configuration and settings
│   ├── middleware/        # Security, rate limiting, audit logging
│   ├── models/            # Pydantic models and schemas
│   ├── routers/           # API endpoints
│   ├── services/          # Business logic
│   └── utils/             # Helper functions
├── migrations/            # Database migrations
├── tests/                 # Unit and integration tests
├── main.py                # FastAPI application entry point
├── start.py               # Development server script
├── requirements.txt       # Python dependencies
├── Procfile               # Railway/Heroku process file
├── railway.toml           # Railway configuration
└── RAILWAY_DEPLOYMENT.md  # Deployment guide
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

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app tests/

# Run specific test file
pytest tests/test_auth.py
```

## 📊 API Endpoints

### Authentication
- `POST /api/v1/auth/signup` - Create new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh token
- `POST /api/v1/mfa/setup` - Setup MFA
- `POST /api/v1/mfa/verify` - Verify MFA code

### Pets
- `GET /api/v1/pets` - List user's pets
- `POST /api/v1/pets` - Create pet profile
- `GET /api/v1/pets/{pet_id}` - Get pet details
- `PUT /api/v1/pets/{pet_id}` - Update pet
- `DELETE /api/v1/pets/{pet_id}` - Delete pet

### Scanning
- `POST /api/v1/scans` - Create new ingredient scan
- `GET /api/v1/scans` - List user's scans
- `GET /api/v1/scans/{scan_id}` - Get scan details

### Nutrition
- `POST /api/v1/nutrition/analyze` - Analyze ingredients
- `GET /api/v1/nutrition/recommendations` - Get recommendations
- `POST /api/v1/food-items` - Log food item
- `GET /api/v1/calorie-goals` - Get calorie tracking goals

### Notifications
- `POST /api/v1/notifications/register` - Register device for push
- `POST /api/v1/notifications/send` - Send notification (admin)

### GDPR
- `GET /api/v1/gdpr/export` - Export user data
- `DELETE /api/v1/gdpr/delete-account` - Delete account

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

## 🐛 Troubleshooting

### Database Connection Issues
- Verify `DATABASE_URL` is correct
- Check Supabase connection pooler settings
- Ensure connection pool size is appropriate

### APNs Certificate Issues
- Verify `.p8` file format
- Check `APNS_KEY_ID` matches certificate
- Ensure proper newlines in `APNS_PRIVATE_KEY`

### CORS Errors
- Update `ALLOWED_ORIGINS_STR` with your frontend URL
- Include protocol (http:// or https://)
- Don't include trailing slashes

### 500 Errors
- Check Railway logs: `railway logs`
- Verify all environment variables are set
- Check database migrations are applied

## 📚 Documentation

- [API Documentation](./API_DOCS.md) - Detailed API reference
- [Railway Deployment](./RAILWAY_DEPLOYMENT.md) - Deployment guide
- [FastAPI Docs](https://fastapi.tiangolo.com/) - Framework documentation

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run tests: `pytest`
4. Submit pull request

## 📄 License

Proprietary - All rights reserved

## 📞 Support

For issues or questions, contact the development team.

---

Built with ❤️ for pet owners everywhere 🐶🐱
