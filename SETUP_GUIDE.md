# Pet Allergy Scanner - Complete Setup Guide

This guide will walk you through setting up both the backend server and iOS frontend for the Pet Allergy Scanner application.

## 📋 Prerequisites

### Backend Requirements
- Python 3.9 or higher
- Git
- Supabase account (free tier available)

### iOS Requirements
- macOS with Xcode 15.0 or higher
- iOS 17.0 or higher target
- Apple Developer Account (for device testing)

## 🚀 Backend Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new account
2. Create a new project:
   - Project name: `pet-allergy-scanner`
   - Database password: Choose a strong password
   - Region: Select closest to your location

### 2. Get Supabase Credentials

1. In your Supabase dashboard, go to **Settings > API**
2. Copy the following values:
   - **Project URL** (e.g., `https://your-project.supabase.co`)
   - **anon public** key
   - **service_role** key (keep this secret!)

### 3. Set Up Backend Environment

```bash
# Navigate to server directory
cd /Users/stevenmatos/Code/pet-allergy-scanner/server

# Create virtual environment
python -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create environment file
cp env.example .env
```

### 4. Configure Environment Variables

Edit the `.env` file with your Supabase credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
SECRET_KEY=your_secret_key_here
DATABASE_URL=postgresql://postgres:your_password@db.your-project.supabase.co:5432/postgres
ENVIRONMENT=development
```

**Important:** Generate a strong secret key for JWT signing:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 5. Set Up Database Schema

1. In your Supabase dashboard, go to **SQL Editor**
2. Copy the entire contents of `database_schema.sql`
3. Paste and run the SQL to create tables, indexes, and policies

### 6. Start the Backend Server

```bash
# Start the development server
python start.py
```

The API will be available at `http://localhost:8000`

**Test the API:**
- Visit `http://localhost:8000/docs` for interactive API documentation
- Visit `http://localhost:8000/health` for health check

## 📱 iOS Frontend Setup

### 1. Open Xcode Project

```bash
# Navigate to iOS project
cd /Users/stevenmatos/Code/pet-allergy-scanner/pet-allergy-scanner

# Open in Xcode
open pet-allergy-scanner.xcodeproj
```

### 2. Configure Project Settings

1. **Select your development team:**
   - In Xcode, select the project in the navigator
   - Go to "Signing & Capabilities"
   - Select your Apple Developer team

2. **Update bundle identifier:**
   - Change from `com.yourname.pet-allergy-scanner` to your unique identifier
   - Example: `com.yourcompany.petallergyscanner`

3. **Add camera permission:**
   - The app already includes camera usage description in `Info.plist`

### 3. Update API Configuration

The iOS app is configured to connect to `http://localhost:8000` by default. For production, you'll need to update the API URL in `APIService.swift`:

```swift
private let baseURL = "https://your-production-api.com/api/v1"
```

### 4. Build and Run

1. **Select your target device:**
   - Choose iPhone simulator or connected device
   - iOS 17.0 or higher required

2. **Build and run:**
   - Press `Cmd + R` or click the play button
   - The app will launch on your selected device

## 🔧 Development Workflow

### Backend Development

```bash
# Start development server with auto-reload
python start.py

# Check logs
tail -f logs/app.log  # If you add logging

# Test API endpoints
curl http://localhost:8000/health
```

### iOS Development

1. **Make changes in Xcode**
2. **Build and run** (`Cmd + R`)
3. **Test on device or simulator**

### Database Management

- **View data:** Use Supabase dashboard > Table Editor
- **Run queries:** Use Supabase dashboard > SQL Editor
- **Monitor:** Use Supabase dashboard > Logs

## 🧪 Testing the Application

### 1. Backend API Testing

```bash
# Test health endpoint
curl http://localhost:8000/health

# Test user registration
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","first_name":"Test","last_name":"User","role":"free"}'
```

### 2. iOS App Testing

1. **Launch the app**
2. **Register a new account**
3. **Add a pet profile**
4. **Test camera scanning:**
   - Take a photo of a pet food ingredient list
   - Verify OCR text extraction
   - Check ingredient analysis results

## 🚀 Production Deployment

### Backend Deployment

1. **Choose a hosting platform:**
   - **Recommended:** Railway, Render, or Heroku
   - **Alternative:** AWS, Google Cloud, or DigitalOcean

2. **Set environment variables:**
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SECRET_KEY`
   - `DATABASE_URL`
   - `ENVIRONMENT=production`

3. **Update CORS settings:**
   - Allow your iOS app's bundle identifier
   - Configure for production domain

### iOS App Deployment

1. **Update API URL** in `APIService.swift`
2. **Configure App Store Connect:**
   - Create app listing
   - Upload screenshots
   - Set app metadata

3. **Build for distribution:**
   - Archive the app in Xcode
   - Upload to App Store Connect
   - Submit for review

## 🔍 Troubleshooting

### Common Backend Issues

**Database connection error:**
```bash
# Check Supabase credentials
# Verify database URL format
# Ensure RLS policies are set up correctly
```

**Authentication issues:**
```bash
# Verify JWT secret key
# Check Supabase auth configuration
# Ensure proper CORS settings
```

### Common iOS Issues

**Build errors:**
- Clean build folder (`Cmd + Shift + K`)
- Check iOS deployment target
- Verify all dependencies are installed

**Camera not working:**
- Check device permissions
- Ensure running on physical device (camera not available in simulator)
- Verify Info.plist camera usage description

**API connection issues:**
- Check network connectivity
- Verify API URL in `APIService.swift`
- Ensure backend server is running

## 📚 Additional Resources

### Backend Documentation
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

### iOS Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Vision Framework](https://developer.apple.com/documentation/vision/)
- [Combine Framework](https://developer.apple.com/documentation/combine/)

### Project Structure

```
pet-allergy-scanner/
├── server/                 # FastAPI backend
│   ├── app/
│   │   ├── core/          # Configuration
│   │   ├── models/        # Data models
│   │   └── routers/       # API endpoints
│   ├── main.py            # FastAPI app
│   ├── requirements.txt   # Python dependencies
│   └── database_schema.sql # Database setup
└── pet-allergy-scanner/   # iOS app
    ├── Models/            # Swift data models
    ├── Services/          # API and business logic
    ├── Views/             # SwiftUI views
    └── ContentView.swift  # Main app view
```

## 🎯 Next Steps

1. **Test the complete flow:**
   - User registration → Pet profile creation → Ingredient scanning → Analysis results

2. **Customize the app:**
   - Update branding and colors
   - Add more ingredient data
   - Implement premium features

3. **Deploy to production:**
   - Set up production backend
   - Submit iOS app to App Store
   - Configure monitoring and analytics

4. **Gather user feedback:**
   - Test with real pet owners
   - Iterate on features
   - Plan future enhancements

## 🆘 Support

If you encounter issues:

1. **Check the logs** in both backend and iOS app
2. **Verify all environment variables** are set correctly
3. **Test API endpoints** using the interactive docs at `/docs`
4. **Review the database schema** in Supabase dashboard
5. **Check iOS device logs** in Xcode console

For additional help, refer to the individual README files in the `server/` directory and the inline code comments throughout the project.
