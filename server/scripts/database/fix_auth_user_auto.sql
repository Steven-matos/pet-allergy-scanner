-- =============================================================================
-- AUTO-FIX FUNCTION: Fix "Database error granting user" during login
-- =============================================================================
-- This function can be called via RPC from the API to automatically fix
-- authentication issues when a user exists in public.users but login fails.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fix_auth_user_login(user_email TEXT)
RETURNS JSONB AS $$
DECLARE
    auth_user_id UUID;
    public_user_id UUID;
    fix_result JSONB;
    created_count INTEGER := 0;
    updated_count INTEGER := 0;
BEGIN
    -- Find the user in auth.users by email
    SELECT id INTO auth_user_id
    FROM auth.users
    WHERE email = user_email
    LIMIT 1;
    
    -- If user doesn't exist in auth.users, return error
    IF auth_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found in auth.users',
            'email', user_email
        );
    END IF;
    
    -- Check if user exists in public.users
    SELECT id INTO public_user_id
    FROM public.users
    WHERE email = user_email OR id = auth_user_id
    LIMIT 1;
    
    -- Case 1: User doesn't exist in public.users - create it
    IF public_user_id IS NULL THEN
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
        WHERE au.id = auth_user_id
        ON CONFLICT (id) DO NOTHING;
        
        GET DIAGNOSTICS created_count = ROW_COUNT;
        
        RETURN jsonb_build_object(
            'success', true,
            'action', 'created',
            'user_id', auth_user_id,
            'email', user_email,
            'created', created_count > 0
        );
    END IF;
    
    -- Case 2: User exists but ID mismatch - fix it
    IF public_user_id != auth_user_id THEN
        -- Delete the old record with mismatched ID
        DELETE FROM public.users WHERE id = public_user_id;
        
        -- Create new record with correct ID from auth.users
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
        WHERE au.id = auth_user_id
        ON CONFLICT (id) DO NOTHING;
        
        GET DIAGNOSTICS updated_count = ROW_COUNT;
        
        RETURN jsonb_build_object(
            'success', true,
            'action', 'fixed_id_mismatch',
            'old_id', public_user_id,
            'new_id', auth_user_id,
            'email', user_email,
            'updated', updated_count > 0
        );
    END IF;
    
    -- Case 3: User exists with correct ID but email mismatch - fix email
    UPDATE public.users pu
    SET email = au.email,
        updated_at = NOW()
    FROM auth.users au
    WHERE pu.id = au.id 
      AND au.id = auth_user_id
      AND pu.email != au.email;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    IF updated_count > 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'action', 'fixed_email_mismatch',
            'user_id', auth_user_id,
            'email', user_email,
            'updated', true
        );
    END IF;
    
    -- Case 4: User exists and looks correct - try to force refresh
    -- First, try to update the record to trigger any necessary triggers
    UPDATE public.users
    SET updated_at = NOW()
    WHERE id = auth_user_id;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    -- Ensure email matches exactly
    UPDATE public.users pu
    SET email = au.email
    FROM auth.users au
    WHERE pu.id = au.id 
      AND au.id = auth_user_id
      AND pu.email IS DISTINCT FROM au.email;
    
    -- If we got here, the update succeeded - return success
    RETURN jsonb_build_object(
        'success', true,
        'action', 'refreshed',
        'user_id', auth_user_id,
        'email', user_email,
        'message', 'User record refreshed. Try logging in again.'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'email', user_email
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.fix_auth_user_login(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fix_auth_user_login(TEXT) TO service_role;

-- =============================================================================
-- USAGE
-- =============================================================================
-- Call from API via RPC:
-- supabase.rpc('fix_auth_user_login', {'user_email': 'user@example.com'})
--
-- Or from SQL:
-- SELECT public.fix_auth_user_login('user@example.com');
-- =============================================================================

