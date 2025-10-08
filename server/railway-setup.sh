#!/bin/bash

# Railway Environment Variables Setup Script
# This script helps you set all required environment variables for Railway deployment

echo "🚂 Railway Setup Script for SniffTest API"
echo "=========================================="
echo ""

# Check if railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    echo "Please run: npm install -g @railway/cli"
    echo "or: brew install railway"
    exit 1
fi

echo "✅ Railway CLI found"
echo ""

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo "🔐 Please login to Railway first:"
    railway login
fi

echo ""

# Check if service is linked
if ! railway service 2>&1 | grep -q "Service:"; then
    echo "⚠️  No service linked to Railway!"
    echo ""
    echo "Please complete Railway setup first:"
    echo ""
    echo "1. Create/link a project:"
    echo "   railway init"
    echo ""
    echo "2. Link to a service (if not auto-created):"
    echo "   railway service"
    echo ""
    echo "3. Then run this script again:"
    echo "   ./railway-setup.sh"
    echo ""
    exit 1
fi

echo "✅ Railway service linked"
echo ""
echo "📋 Reading variables from .env file..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please create it first."
    exit 1
fi

# Function to read .env file properly (handles multi-line values)
read_env() {
    local key=$1
    local value=$(grep "^${key}=" .env | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
    echo "$value"
}

echo "🔧 Setting Railway environment variables..."
echo ""

# Read variables from .env
SUPABASE_URL=$(read_env "SUPABASE_URL")
SUPABASE_KEY=$(read_env "SUPABASE_KEY")
SUPABASE_SERVICE_ROLE_KEY=$(read_env "SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_JWT_SECRET=$(read_env "SUPABASE_JWT_SECRET")
DATABASE_URL=$(read_env "DATABASE_URL")
SECRET_KEY=$(read_env "SECRET_KEY")
ALGORITHM=$(read_env "ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES=$(read_env "ACCESS_TOKEN_EXPIRE_MINUTES")
RATE_LIMIT_PER_MINUTE=$(read_env "RATE_LIMIT_PER_MINUTE")
AUTH_RATE_LIMIT_PER_MINUTE=$(read_env "AUTH_RATE_LIMIT_PER_MINUTE")
DATABASE_POOL_SIZE=$(read_env "DATABASE_POOL_SIZE")
DATABASE_TIMEOUT=$(read_env "DATABASE_TIMEOUT")
MAX_FILE_SIZE_MB=$(read_env "MAX_FILE_SIZE_MB")
MAX_REQUEST_SIZE_MB=$(read_env "MAX_REQUEST_SIZE_MB")
ENABLE_MFA=$(read_env "ENABLE_MFA")
ENABLE_AUDIT_LOGGING=$(read_env "ENABLE_AUDIT_LOGGING")
SESSION_TIMEOUT_MINUTES=$(read_env "SESSION_TIMEOUT_MINUTES")
DATA_RETENTION_DAYS=$(read_env "DATA_RETENTION_DAYS")
ENABLE_DATA_EXPORT=$(read_env "ENABLE_DATA_EXPORT")
ENABLE_DATA_DELETION=$(read_env "ENABLE_DATA_DELETION")
APNS_KEY_ID=$(read_env "APNS_KEY_ID")
APNS_TEAM_ID=$(read_env "APNS_TEAM_ID")
APNS_BUNDLE_ID=$(read_env "APNS_BUNDLE_ID")
APNS_PRIVATE_KEY=$(read_env "APNS_PRIVATE_KEY")

# Set all variables using Railway CLI
railway variables --set "SUPABASE_URL=$SUPABASE_URL"
railway variables --set "SUPABASE_KEY=$SUPABASE_KEY"
railway variables --set "SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY"
railway variables --set "SUPABASE_JWT_SECRET=$SUPABASE_JWT_SECRET"
railway variables --set "DATABASE_URL=$DATABASE_URL"
railway variables --set "SECRET_KEY=$SECRET_KEY"
railway variables --set "ALGORITHM=$ALGORITHM"
railway variables --set "ACCESS_TOKEN_EXPIRE_MINUTES=$ACCESS_TOKEN_EXPIRE_MINUTES"
railway variables --set "RATE_LIMIT_PER_MINUTE=$RATE_LIMIT_PER_MINUTE"
railway variables --set "AUTH_RATE_LIMIT_PER_MINUTE=$AUTH_RATE_LIMIT_PER_MINUTE"
railway variables --set "DATABASE_POOL_SIZE=$DATABASE_POOL_SIZE"
railway variables --set "DATABASE_TIMEOUT=$DATABASE_TIMEOUT"
railway variables --set "MAX_FILE_SIZE_MB=$MAX_FILE_SIZE_MB"
railway variables --set "MAX_REQUEST_SIZE_MB=$MAX_REQUEST_SIZE_MB"
railway variables --set "ENABLE_MFA=$ENABLE_MFA"
railway variables --set "ENABLE_AUDIT_LOGGING=$ENABLE_AUDIT_LOGGING"
railway variables --set "SESSION_TIMEOUT_MINUTES=$SESSION_TIMEOUT_MINUTES"
railway variables --set "DATA_RETENTION_DAYS=$DATA_RETENTION_DAYS"
railway variables --set "ENABLE_DATA_EXPORT=$ENABLE_DATA_EXPORT"
railway variables --set "ENABLE_DATA_DELETION=$ENABLE_DATA_DELETION"
railway variables --set "APNS_KEY_ID=$APNS_KEY_ID"
railway variables --set "APNS_TEAM_ID=$APNS_TEAM_ID"
railway variables --set "APNS_BUNDLE_ID=$APNS_BUNDLE_ID"
railway variables --set "APNS_PRIVATE_KEY=$APNS_PRIVATE_KEY"

# Set production-specific variables
echo ""
echo "⚠️  Setting PRODUCTION environment variables..."
railway variables --set "ENVIRONMENT=production"
railway variables --set "DEBUG=false"
railway variables --set "LOG_LEVEL=INFO"
railway variables --set "VERBOSE_LOGGING=false"
railway variables --set "APNS_URL=https://api.push.apple.com"

echo ""
echo "⚠️  IMPORTANT: Update these variables after deployment:"
echo "1. Get your Railway URL: railway domain"
echo "2. Update CORS settings:"
echo "   railway variables --set ALLOWED_ORIGINS_STR=https://your-app.up.railway.app,https://api.petallergyscanner.com"
echo "   railway variables --set ALLOWED_HOSTS_STR=your-app.up.railway.app,api.petallergyscanner.com"
echo ""
echo "✅ Railway environment variables configured!"
echo ""
echo "🚀 Next steps:"
echo "1. Deploy: railway up"
echo "2. Check logs: railway logs"
echo "3. Get domain: railway domain"
echo "4. Update CORS settings with your domain"
echo ""
