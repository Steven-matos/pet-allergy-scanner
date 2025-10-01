-- Migration: Fix Function Search Path Security Warnings
-- Sets search_path parameter on all functions to prevent SQL injection attacks
-- This addresses Supabase Security Advisor warnings

-- 1. Fix validate_username_unique function
CREATE OR REPLACE FUNCTION validate_username_unique(username_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if username exists in public.users
    IF EXISTS (SELECT 1 FROM public.users WHERE username = username_to_check) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if username exists in auth.users metadata
    IF EXISTS (SELECT 1 FROM auth.users WHERE raw_user_meta_data->>'username' = username_to_check) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public, auth;

-- 2. Fix sync_username_to_public_users function
CREATE OR REPLACE FUNCTION sync_username_to_public_users()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update username in public.users when auth.users is updated
    INSERT INTO public.users (id, email, username, first_name, last_name, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'first_name',
        NEW.raw_user_meta_data->>'last_name',
        NEW.created_at,
        NEW.updated_at
    )
    ON CONFLICT (id) 
    DO UPDATE SET
        username = EXCLUDED.username,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public, auth;

-- 3. Fix handle_new_user function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert user data into public.users table
    INSERT INTO public.users (
        id,
        email,
        username,
        first_name,
        last_name,
        role,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', NULL),
        COALESCE(NEW.raw_user_meta_data->>'first_name', NULL),
        COALESCE(NEW.raw_user_meta_data->>'last_name', NULL),
        COALESCE(NEW.raw_user_meta_data->>'role', 'free'),
        NEW.created_at,
        NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        username = EXCLUDED.username,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        role = EXCLUDED.role,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public, auth;

-- 4. Fix handle_user_update function
CREATE OR REPLACE FUNCTION handle_user_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user data in public.users table
    UPDATE public.users SET
        email = NEW.email,
        username = COALESCE(NEW.raw_user_meta_data->>'username', username),
        first_name = COALESCE(NEW.raw_user_meta_data->>'first_name', first_name),
        last_name = COALESCE(NEW.raw_user_meta_data->>'last_name', last_name),
        role = COALESCE(NEW.raw_user_meta_data->>'role', role),
        updated_at = NOW()
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public, auth;

-- Note: search_path is set to 'public, auth' because these functions need to access
-- both the public.users table and auth.users table. This prevents SQL injection 
-- attacks while maintaining necessary access.

