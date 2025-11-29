#!/bin/bash

# Centralization Check Script
# Run this script to check for violations of centralization principles

echo "🔍 Checking for centralization violations..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VIOLATIONS=0

# Check for datetime.utcnow() or datetime.now(timezone.utc) (excluding DateTimeService)
echo "📅 Checking for datetime.utcnow() or datetime.now(timezone.utc) calls..."
DATETIME_VIOLATIONS=$(grep -r "datetime\.utcnow()\|datetime\.now(timezone\.utc)" server/app --include="*.py" | grep -v "datetime_service.py" | grep -v "__pycache__" | wc -l)

if [ "$DATETIME_VIOLATIONS" -gt 0 ]; then
    echo -e "${RED}❌ Found $DATETIME_VIOLATIONS datetime violations${NC}"
    grep -r "datetime\.utcnow()\|datetime\.now(timezone\.utc)" server/app --include="*.py" | grep -v "datetime_service.py" | grep -v "__pycache__"
    VIOLATIONS=$((VIOLATIONS + DATETIME_VIOLATIONS))
else
    echo -e "${GREEN}✅ No datetime violations found${NC}"
fi

echo ""

# Check for direct service role client creation
echo "🔐 Checking for direct service role client creation..."
SERVICE_ROLE_VIOLATIONS=$(grep -r "create_client.*service_role\|create_client.*SERVICE_ROLE" server/app --include="*.py" | grep -v "__pycache__" | wc -l)

if [ "$SERVICE_ROLE_VIOLATIONS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $SERVICE_ROLE_VIOLATIONS potential service role client violations${NC}"
    grep -r "create_client.*service_role\|create_client.*SERVICE_ROLE" server/app --include="*.py" | grep -v "__pycache__"
    VIOLATIONS=$((VIOLATIONS + SERVICE_ROLE_VIOLATIONS))
else
    echo -e "${GREEN}✅ No service role client violations found${NC}"
fi

echo ""

# Check for direct user role updates (excluding UserRoleManager)
echo "👤 Checking for direct user role updates..."
ROLE_UPDATE_VIOLATIONS=$(grep -r '\.table("users")\.update.*"role"' server/app --include="*.py" | grep -v "user_role_manager.py" | grep -v "__pycache__" | wc -l)

if [ "$ROLE_UPDATE_VIOLATIONS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $ROLE_UPDATE_VIOLATIONS potential direct role update violations${NC}"
    grep -r '\.table("users")\.update.*"role"' server/app --include="*.py" | grep -v "user_role_manager.py" | grep -v "__pycache__"
    VIOLATIONS=$((VIOLATIONS + ROLE_UPDATE_VIOLATIONS))
else
    echo -e "${GREEN}✅ No direct role update violations found${NC}"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$VIOLATIONS" -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! No violations found.${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $VIOLATIONS total violations${NC}"
    echo ""
    echo "💡 Tips:"
    echo "   - Use DateTimeService for all datetime operations"
    echo "   - Use DatabaseOperationService for database operations with timestamps"
    echo "   - Use UserRoleManager for user role updates"
    echo "   - Use get_supabase_service_role_client() for service role clients"
    echo ""
    echo "📚 See docs/DEVELOPER_GUIDELINES.md for more information"
    exit 1
fi

