-- =============================================================================
-- FIX: Function Search Path Security Vulnerability
-- =============================================================================
-- This script fixes security warnings about functions with mutable search_path
-- Run this in Supabase SQL Editor to fix the security linter warnings
-- =============================================================================
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
-- Security Best Practice: Set explicit search_path to prevent search path injection
-- =============================================================================

-- Step 1: Check current function definitions (for review)
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as current_definition
FROM pg_proc
WHERE proname IN ('cleanup_expired_device_tokens_temp', 'prevent_bypass_user_downgrade')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

-- =============================================================================
-- FIXES
-- =============================================================================

-- Fix 1: cleanup_expired_device_tokens_temp
-- Sets explicit search_path to prevent search path injection attacks
-- Using 'public, pg_temp' allows access to public schema tables while remaining secure
CREATE OR REPLACE FUNCTION cleanup_expired_device_tokens_temp()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.device_tokens_temp
    WHERE expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Fix 2: prevent_bypass_user_downgrade
-- This function may exist as a database trigger function
-- IMPORTANT: If this function exists with different logic, you may need to
-- preserve that logic. Review the output of Step 1 before running this fix.
-- 
-- This creates/updates the function with proper security settings.
-- The function prevents downgrading users with bypass_subscription flag enabled.
CREATE OR REPLACE FUNCTION prevent_bypass_user_downgrade()
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent downgrading users with bypass_subscription flag
    IF OLD.bypass_subscription = TRUE AND NEW.role = 'free' AND OLD.role = 'premium' THEN
        RAISE EXCEPTION 'Cannot downgrade user with bypass_subscription flag enabled';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Step 2: Verify functions have been updated correctly
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    CASE 
        WHEN prosecdef THEN 'YES (SECURITY DEFINER)'
        ELSE 'NO'
    END as security_status
FROM pg_proc
WHERE proname IN ('cleanup_expired_device_tokens_temp', 'prevent_bypass_user_downgrade')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

-- Step 3: Check if prevent_bypass_user_downgrade is used by any triggers
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as is_enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'public.users'::regclass
  AND tgname LIKE '%bypass%' OR tgname LIKE '%downgrade%';

-- Step 4: Show updated function definitions (with search_path setting)
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as updated_definition
FROM pg_proc
WHERE proname IN ('cleanup_expired_device_tokens_temp', 'prevent_bypass_user_downgrade')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

-- =============================================================================
-- NOTES
-- =============================================================================
-- 1. The search_path setting prevents search path injection attacks by:
--    - Explicitly defining which schemas to search for unqualified names
--    - Using 'public, pg_temp' ensures functions can access public schema
--      and temporary objects without being vulnerable to malicious schema injection
--    - This is critical for SECURITY DEFINER functions which run with elevated privileges
--
-- 2. Security Best Practices (2025):
--    - Always set explicit search_path for SECURITY DEFINER functions
--    - Use fully qualified names (schema.table) in function bodies
--    - Restrict search_path to only necessary schemas (public, pg_temp)
--    - Never leave search_path unset or mutable for security-sensitive functions
--
-- 3. After running this script:
--    - The Supabase linter should no longer report these security warnings
--    - Functions will be protected against search path injection attacks
--    - If prevent_bypass_user_downgrade is used by a trigger, ensure the trigger
--      is properly configured after this update
--
-- 4. If prevent_bypass_user_downgrade function had different logic:
--    - Review Step 1 output to see the original definition
--    - Adjust the function body in Fix 2 to preserve original behavior
--    - The search_path fix can be applied regardless of function logic
-- =============================================================================

