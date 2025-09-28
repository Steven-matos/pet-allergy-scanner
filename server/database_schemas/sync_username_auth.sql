-- Sync Username between Supabase Auth and Public Users Table
-- This approach keeps username in your public.users table and syncs with auth

-- 1. Create a function to sync username from auth to public.users
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create trigger to automatically sync username changes
DROP TRIGGER IF EXISTS sync_username_trigger ON auth.users;
CREATE TRIGGER sync_username_trigger
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION sync_username_to_public_users();

-- 3. Create function to validate username uniqueness across both tables
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Grant permissions
GRANT EXECUTE ON FUNCTION validate_username_unique(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION sync_username_to_public_users() TO authenticated;
