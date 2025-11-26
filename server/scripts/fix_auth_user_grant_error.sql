-- =============================================================================
-- FIX: "Database error granting user" - Authentication Error
-- =============================================================================
-- This script diagnoses and fixes common causes of the "Database error granting user" error
-- Run this in Supabase SQL Editor if users are unable to log in
-- =============================================================================

-- Step 1: Check for orphaned or duplicate user records
-- Find users in auth.users that don't have a corresponding public.users record
SELECT 
    au.id as auth_id,
    au.email as auth_email,
    au.created_at as auth_created_at,
    pu.id as public_id,
    pu.email as public_email,
    CASE 
        WHEN pu.id IS NULL THEN 'MISSING in public.users'
        WHEN au.id != pu.id THEN 'ID MISMATCH'
        WHEN au.email != pu.email THEN 'EMAIL MISMATCH'
        ELSE 'EXISTS' 
    END as status
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id OR au.email = pu.email
WHERE pu.id IS NULL 
   OR au.id != pu.id 
   OR au.email != pu.email
ORDER BY au.created_at DESC
LIMIT 20;

-- Step 2: Check for duplicate emails in public.users (should be unique)
SELECT 
    email,
    COUNT(*) as count,
    array_agg(id::text) as user_ids
FROM public.users
GROUP BY email
HAVING COUNT(*) > 1;

-- Step 3: Check for users with NULL or empty emails (violates NOT NULL constraint)
SELECT 
    id,
    email,
    created_at
FROM public.users
WHERE email IS NULL OR email = '';

-- Step 4: Check if there are any triggers on auth.users that might be failing
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users';

-- Step 4b: Check for specific user that's having issues
-- Replace 'steven_matos@ymail.com' with the actual email having issues
SELECT 
    'auth.users' as source,
    id::text as id,
    email,
    created_at::text as created_at,
    email_confirmed_at::text as email_confirmed_at,
    raw_user_meta_data::text as raw_user_meta_data,
    (raw_user_meta_data->>'role')::text as role
FROM auth.users
WHERE email = 'steven_matos@ymail.com'
UNION ALL
SELECT 
    'public.users' as source,
    id::text as id,
    email,
    created_at::text as created_at,
    NULL::text as email_confirmed_at,
    NULL::text as raw_user_meta_data,
    role::text as role
FROM public.users
WHERE email = 'steven_matos@ymail.com';

-- Step 4c: Check for metadata mismatches between auth.users and public.users
SELECT 
    au.id,
    au.email,
    (au.raw_user_meta_data->>'role')::text as auth_role,
    pu.role as public_role,
    (au.raw_user_meta_data->>'username')::text as auth_username,
    pu.username as public_username,
    (au.raw_user_meta_data->>'first_name')::text as auth_first_name,
    pu.first_name as public_first_name,
    (au.raw_user_meta_data->>'last_name')::text as auth_last_name,
    pu.last_name as public_last_name,
    CASE 
        WHEN (au.raw_user_meta_data->>'role')::text != pu.role THEN 'ROLE MISMATCH'
        WHEN (au.raw_user_meta_data->>'username')::text != pu.username THEN 'USERNAME MISMATCH'
        WHEN (au.raw_user_meta_data->>'first_name')::text != pu.first_name THEN 'FIRST_NAME MISMATCH'
        WHEN (au.raw_user_meta_data->>'last_name')::text != pu.last_name THEN 'LAST_NAME MISMATCH'
        ELSE 'OK'
    END as mismatch_status
FROM auth.users au
INNER JOIN public.users pu ON au.id = pu.id
WHERE (au.raw_user_meta_data->>'role')::text != pu.role
   OR (au.raw_user_meta_data->>'username')::text != pu.username
   OR (au.raw_user_meta_data->>'first_name')::text != pu.first_name
   OR (au.raw_user_meta_data->>'last_name')::text != pu.last_name;

-- =============================================================================
-- FIXES
-- =============================================================================

-- Fix 1: Create missing public.users records for existing auth.users
-- This will create records for users that exist in auth.users but not in public.users
INSERT INTO public.users (id, email, role, onboarded, bypass_subscription, created_at, updated_at)
SELECT 
    au.id,
    au.email,
    COALESCE((au.raw_user_meta_data->>'role')::text, 'free') as role,
    FALSE as onboarded,
    FALSE as bypass_subscription,
    au.created_at,
    NOW() as updated_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Fix 1b: Fix ID mismatches - if auth.users and public.users have same email but different IDs
-- This is more complex and requires manual review, but we can identify them:
SELECT 
    au.id as auth_id,
    au.email,
    pu.id as public_id,
    'ID MISMATCH - Manual fix required' as issue
FROM auth.users au
INNER JOIN public.users pu ON au.email = pu.email
WHERE au.id != pu.id;

-- Fix 1c: Fix email mismatches - if IDs match but emails don't
UPDATE public.users pu
SET email = au.email
FROM auth.users au
WHERE pu.id = au.id 
  AND pu.email != au.email;

-- Fix 1d: Sync metadata from public.users to auth.users raw_user_meta_data
-- This ensures auth.users metadata matches public.users (important for triggers)
-- NOTE: This requires superuser/admin privileges. Run with caution.
DO $$
DECLARE
    user_record RECORD;
    updated_count INTEGER := 0;
BEGIN
    FOR user_record IN 
        SELECT 
            au.id,
            au.raw_user_meta_data,
            pu.role,
            pu.username,
            pu.first_name,
            pu.last_name
        FROM auth.users au
        INNER JOIN public.users pu ON au.id = pu.id
        WHERE (au.raw_user_meta_data->>'role')::text != pu.role
           OR (au.raw_user_meta_data->>'username')::text IS DISTINCT FROM pu.username
           OR (au.raw_user_meta_data->>'first_name')::text IS DISTINCT FROM pu.first_name
           OR (au.raw_user_meta_data->>'last_name')::text IS DISTINCT FROM pu.last_name
    LOOP
        -- Update auth.users raw_user_meta_data to match public.users
        UPDATE auth.users
        SET raw_user_meta_data = jsonb_set(
            jsonb_set(
                jsonb_set(
                    jsonb_set(
                        COALESCE(raw_user_meta_data, '{}'::jsonb),
                        '{role}', to_jsonb(user_record.role)
                    ),
                    '{username}', to_jsonb(COALESCE(user_record.username, ''))
                ),
                '{first_name}', to_jsonb(COALESCE(user_record.first_name, ''))
            ),
            '{last_name}', to_jsonb(COALESCE(user_record.last_name, ''))
        ),
        updated_at = NOW()
        WHERE id = user_record.id;
        
        updated_count := updated_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Updated % user(s) metadata in auth.users', updated_count;
END $$;

-- Fix 2: Remove duplicate email entries (keep the oldest one)
-- WARNING: This will delete duplicate records. Review the SELECT above first!
-- Uncomment only after reviewing duplicates:
/*
DELETE FROM public.users
WHERE id IN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at ASC) as rn
        FROM public.users
    ) t
    WHERE rn > 1
);
*/

-- Fix 3: Fix NULL emails (set to a placeholder, but this shouldn't happen)
-- WARNING: This is a last resort. NULL emails shouldn't exist.
-- Uncomment only if Step 3 found NULL emails:
/*
UPDATE public.users
SET email = 'missing_' || id::text || '@placeholder.com'
WHERE email IS NULL OR email = '';
*/

-- Fix 4: Ensure the public.users table has proper constraints
-- This will recreate constraints if they're missing
DO $$
BEGIN
    -- Ensure email is NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'email'
        AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE public.users ALTER COLUMN email SET NOT NULL;
    END IF;
    
    -- Ensure unique constraint on email
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'users_email_key'
    ) THEN
        ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);
    END IF;
END $$;

-- Step 5: Verify fixes
-- Check that all auth.users now have corresponding public.users records
SELECT 
    COUNT(*) as total_auth_users,
    COUNT(pu.id) as users_with_public_record,
    COUNT(*) - COUNT(pu.id) as missing_public_records
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id;

-- =============================================================================
-- NOTES
-- =============================================================================
-- 1. The "Database error granting user" error typically occurs when:
--    - A user exists in auth.users but not in public.users
--    - There's a constraint violation (duplicate email, NULL email)
--    - A trigger on auth.users is failing
--
-- 2. After running this script, users should be able to log in again
--
-- 3. If the error persists, check Supabase Auth logs for more details:
--    Dashboard > Logs > Auth Logs
--
-- 4. To prevent this in the future, ensure your registration endpoint
--    always creates a public.users record when creating auth.users

