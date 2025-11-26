# Scripts Directory

This directory contains utility scripts for the Pet Allergy Scanner backend.

## 🚀 Active Scripts (Keep These)

### Deployment & Configuration
- **`railway_start.py`** - Production startup script for Railway deployment (REQUIRED)
- **`test_config.py`** - Configuration testing utility for Railway deployment
- **`check-deployment-ready.py`** - Validates deployment readiness
- **`generate-railway-vars.py`** - Generates Railway environment variable commands from .env

### Development & Maintenance
- **`check_centralization.sh`** - Code quality tool to check for centralization violations
- **`set_premium_account.py`** - Admin utility to set user accounts to premium status
- **`setup_test_data.py`** - Sets up test data for development/testing
- **`cleanup_database.py`** - Database cleanup utility (removes food items without ingredients)
- **`analyze_database_tables.py`** - Analyzes database table structure and statistics

## 🗑️ Removed Scripts (One-Time Migrations - Already Completed)

The following scripts were removed as they were one-time migrations that have already been completed:
- `migrate_datetime_calls.py` - Datetime migration (complete - DateTimeService is now used)
- `apply_database_schema.py` - Schema migration (complete - schema already applied)
- `run_scan_migration.py` - Scan table migration (complete - columns already exist)

## Usage

### Railway Deployment
```bash
# Test configuration before deploying
python scripts/test_config.py

# Check deployment readiness
python scripts/check-deployment-ready.py

# Generate Railway env vars
python scripts/generate-railway-vars.py
```

### Development
```bash
# Check for centralization violations
./scripts/check_centralization.sh

# Set user to premium (admin)
python scripts/set_premium_account.py user@example.com

# Setup test data
python scripts/setup_test_data.py
```

### Database Maintenance
```bash
# Cleanup database (dry run first)
python scripts/cleanup_database.py --dry-run

# Analyze database tables
python scripts/analyze_database_tables.py
```

