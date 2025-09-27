# Pet Allergy Scanner Backend

FastAPI backend for the Pet Allergy Scanner iOS application.

## Features

- **User Authentication**: Secure user registration and login with Supabase Auth
- **Pet Profile Management**: Create and manage multiple pet profiles
- **Ingredient Analysis**: AI-powered ingredient analysis with species-specific logic
- **Scan Processing**: OCR text extraction and ingredient analysis
- **Favorites System**: Save approved products for future reference
- **Species-Specific Logic**: Different nutritional requirements for dogs vs cats

## Tech Stack

- **FastAPI**: High-performance Python web framework
- **Supabase**: Backend-as-a-Service for database and authentication
- **PostgreSQL**: Relational database for data storage
- **Pydantic**: Data validation and serialization
- **Python 3.9+**: Modern Python with type hints

## Setup Instructions

### 1. Prerequisites

- Python 3.9 or higher
- Supabase account and project
- Git

### 2. Environment Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd pet-allergy-scanner/server
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

### 3. Supabase Configuration

1. Create a new Supabase project at [supabase.com](https://supabase.com)

2. Get your project credentials:
   - Go to Settings > API
   - Copy your Project URL and anon key

3. Create environment file:
```bash
cp env.example .env
```

4. Update `.env` with your Supabase credentials:
```env
SUPABASE_URL=your_supabase_url_here
SUPABASE_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here
SECRET_KEY=your_secret_key_here
DATABASE_URL=your_database_url_here
ENVIRONMENT=development
```

### 4. Database Setup

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `database_schema.sql`
4. Run the SQL to create tables, indexes, and policies

### 5. Run the Application

```bash
python start.py
```

The API will be available at `http://localhost:8000`

### 6. API Documentation

Once running, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - User login
- `GET /api/v1/auth/me` - Get current user
- `PUT /api/v1/auth/me` - Update user profile
- `POST /api/v1/auth/logout` - User logout

### Pets
- `POST /api/v1/pets/` - Create pet profile
- `GET /api/v1/pets/` - Get user's pets
- `GET /api/v1/pets/{pet_id}` - Get specific pet
- `PUT /api/v1/pets/{pet_id}` - Update pet profile
- `DELETE /api/v1/pets/{pet_id}` - Delete pet profile

### Ingredients
- `GET /api/v1/ingredients/` - Get ingredients (with filtering)
- `POST /api/v1/ingredients/analyze` - Analyze ingredients for pet
- `GET /api/v1/ingredients/common-allergens` - Get common allergens
- `GET /api/v1/ingredients/safe-alternatives` - Get safe alternatives

### Scans
- `POST /api/v1/scans/` - Create scan record
- `POST /api/v1/scans/analyze` - Analyze scan text
- `GET /api/v1/scans/` - Get user's scans
- `GET /api/v1/scans/{scan_id}` - Get specific scan

## Database Schema

The application uses the following main tables:

- **users**: User profiles and authentication
- **pets**: Pet profiles with species-specific data
- **ingredients**: Ingredient database with safety information
- **scans**: Scan records and analysis results
- **favorites**: User's saved products

## Security Features

- **Row Level Security (RLS)**: Users can only access their own data
- **JWT Authentication**: Secure token-based authentication
- **Input Validation**: Pydantic models for data validation
- **SQL Injection Protection**: Parameterized queries

## Development

### Code Structure

```
server/
├── app/
│   ├── core/
│   │   └── config.py          # Configuration settings
│   ├── models/
│   │   ├── user.py           # User data models
│   │   ├── pet.py            # Pet data models
│   │   ├── ingredient.py     # Ingredient data models
│   │   └── scan.py           # Scan data models
│   ├── routers/
│   │   ├── auth.py           # Authentication endpoints
│   │   ├── pets.py           # Pet management endpoints
│   │   ├── ingredients.py    # Ingredient analysis endpoints
│   │   └── scans.py          # Scan processing endpoints
│   └── database.py           # Database configuration
├── main.py                   # FastAPI application
├── start.py                  # Startup script
├── requirements.txt          # Python dependencies
├── database_schema.sql       # Database schema
└── README.md                 # This file
```

### Adding New Features

1. Create new models in `app/models/`
2. Add new routers in `app/routers/`
3. Update database schema if needed
4. Add tests for new functionality

## Deployment

### Production Setup

1. Set `ENVIRONMENT=production` in your environment variables
2. Use a production-grade ASGI server like Gunicorn
3. Set up proper logging and monitoring
4. Configure CORS for your iOS app domain
5. Use environment-specific Supabase projects

### Environment Variables

Required for production:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_KEY`: Your Supabase anon key
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key
- `SECRET_KEY`: Strong secret key for JWT signing
- `DATABASE_URL`: PostgreSQL connection string
- `ENVIRONMENT`: Set to "production"

## Troubleshooting

### Common Issues

1. **Database Connection Error**: Check your Supabase credentials
2. **Authentication Issues**: Verify JWT token configuration
3. **CORS Errors**: Update CORS settings for your iOS app
4. **Import Errors**: Ensure all dependencies are installed

### Logs

Check the console output for detailed error messages. The application uses Python's logging module for structured logging.

## Support

For issues and questions:
1. Check the API documentation at `/docs`
2. Review the database schema in `database_schema.sql`
3. Check Supabase logs in your project dashboard
4. Review the application logs for error details
