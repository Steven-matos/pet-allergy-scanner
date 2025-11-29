# Scripts Directory

This directory contains utility scripts for the Pet Allergy Scanner backend, organized by purpose.

## 📁 Directory Structure

```
scripts/
├── deployment/     - Deployment & production checks
├── database/       - Database maintenance & fixes
├── testing/       - Test setup & configuration
├── admin/         - Admin utilities
└── dev/           - Development tools
```

## 🚀 Active Scripts

### Deployment & Configuration (`deployment/`)
- **`railway_start.py`** - Production startup script for Railway deployment (REQUIRED)
- **`pre_production_check.py`** - Pre-production validation checks
- **`check-deployment-ready.py`** - Validates deployment readiness
- **`generate-railway-vars.py`** - Generates Railway environment variable commands from .env
- **`PRE_PRODUCTION_CHECKLIST.md`** - Deployment checklist

### Database Maintenance (`database/`)
- **`analyze_database_tables.py`** - Analyzes database table structure and statistics
- **`cleanup_database.py`** - Database cleanup utility (removes food items without ingredients)
- **`fix_function_search_path_security.sql`** - Security hardening for database functions
- **`fix_auth_user_grant_error.sql`** - Diagnoses and fixes authentication errors

### Testing (`testing/`)
- **`test_config.py`** - Configuration testing utility for Railway deployment
- **`setup_test_data.py`** - Sets up test data for development/testing
- **`test_health_endpoint.py`** - Tests health endpoint response time and functionality
- **`test_jwt_debug.py`** - Debug utility for JWT token validation

### Admin (`admin/`)
- **`set_premium_account.py`** - Admin utility to set user accounts to premium status

### Development (`dev/`)
- **`check_centralization.sh`** - Code quality tool to check for centralization violations

## Usage

### Railway Deployment
```bash
# Test configuration before deploying
python scripts/testing/test_config.py

# Check deployment readiness
python scripts/deployment/check-deployment-ready.py

# Generate Railway env vars
python scripts/deployment/generate-railway-vars.py

# Pre-production validation
python scripts/deployment/pre_production_check.py
```

### Development
```bash
# Check for centralization violations
./scripts/dev/check_centralization.sh

# Setup test data
python scripts/testing/setup_test_data.py

# Test health endpoint
python scripts/testing/test_health_endpoint.py

# Debug JWT tokens
python scripts/testing/test_jwt_debug.py
```

### Admin Utilities
```bash
# Set user to premium (admin)
python scripts/admin/set_premium_account.py user@example.com
```

### Database Maintenance
```bash
# Cleanup database (dry run first)
python scripts/database/cleanup_database.py --dry-run
python scripts/database/cleanup_database.py            # Actual cleanup

# Analyze database tables
python scripts/database/analyze_database_tables.py
```

### Security & Database Fixes

#### Function Search Path Security Fix
Fixes security vulnerabilities in SECURITY DEFINER functions by setting explicit search_path. This prevents search path injection attacks.

**When to run**: After Supabase linter reports security warnings about mutable search_path in functions.

**How to run**:
1. Open Supabase SQL Editor
2. Copy and paste the contents of `scripts/database/fix_function_search_path_security.sql`
3. Review the diagnostic queries (Step 1) to see current function definitions
4. Execute the fix statements
5. Verify the fixes using the verification queries at the end of the script

**What it fixes**:
- `cleanup_expired_device_tokens_temp()` function
- `prevent_bypass_user_downgrade()` function
- Sets explicit `search_path = public, pg_temp` for security

**Reference**: [Supabase Database Linter - Function Search Path](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable)

#### Authentication Error Fix
Diagnoses and fixes common causes of "Database error granting user" authentication errors.

**When to run**: If users are experiencing login issues or authentication errors.

**How to run**:
1. Open Supabase SQL Editor
2. Copy and paste the contents of `scripts/database/fix_auth_user_grant_error.sql`
3. Review the diagnostic queries to identify the specific issue:
   - Step 1: Check for orphaned or duplicate user records
   - Step 2: Check for duplicate emails
   - Step 3: Check for constraint violations
4. Execute the appropriate fix based on the diagnostics
5. Verify the fix worked

**What it fixes**:
- Missing user records in `public.users` (orphaned auth.users)
- Duplicate email addresses
- ID or email mismatches between `auth.users` and `public.users`
- Constraint violations preventing user creation

**Note**: This script includes comprehensive diagnostic queries to help identify the root cause before applying fixes.

## 🗑️ Removed Scripts (One-Time Migrations - Already Completed)

The following scripts were removed as they were one-time migrations that have already been completed:
- `migrate_datetime_calls.py` - Datetime migration (complete - DateTimeService is now used)
- `apply_database_schema.py` - Schema migration (complete - schema already applied)
- `run_scan_migration.py` - Scan table migration (complete - columns already exist)
