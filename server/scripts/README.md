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

### Security & Database Fixes
- **`fix_function_search_path_security.sql`** - Security hardening for database functions (fixes search path injection vulnerabilities)
- **`fix_auth_user_grant_error.sql`** - Diagnoses and fixes authentication errors ("Database error granting user")

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

### Security & Database Fixes

#### Function Search Path Security Fix
Fixes security vulnerabilities in SECURITY DEFINER functions by setting explicit search_path. This prevents search path injection attacks.

**When to run**: After Supabase linter reports security warnings about mutable search_path in functions.

**How to run**:
1. Open Supabase SQL Editor
2. Copy and paste the contents of `fix_function_search_path_security.sql`
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
2. Copy and paste the contents of `fix_auth_user_grant_error.sql`
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

