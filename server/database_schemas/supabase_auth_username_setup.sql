-- Supabase Auth Username Setup
-- This approach uses Supabase Auth user_metadata to store usernames
-- No schema changes needed - username is stored in auth.users.user_metadata

-- 1. Enable RLS on auth.users if not already enabled
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- 2. Create a function to validate username uniqueness
CREATE OR REPLACE FUNCTION check_username_unique(username_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if username exists in any user's metadata
    RETURN NOT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE raw_user_meta_data->>'username' = username_to_check
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create a function to update username in user metadata
CREATE OR REPLACE FUNCTION update_user_username(user_id UUID, new_username TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Validate username is unique
    IF NOT check_username_unique(new_username) THEN
        RAISE EXCEPTION 'Username already exists';
    END IF;
    
    -- Update user metadata
    UPDATE auth.users 
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object('username', new_username)
    WHERE id = user_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create a view to easily access usernames
CREATE OR REPLACE VIEW user_profiles AS
SELECT 
    id,
    email,
    raw_user_meta_data->>'username' as username,
    raw_user_meta_data->>'first_name' as first_name,
    raw_user_meta_data->>'last_name' as last_name,
    created_at,
    updated_at
FROM auth.users;

-- 5. Grant necessary permissions
GRANT SELECT ON user_profiles TO authenticated;
GRANT EXECUTE ON FUNCTION check_username_unique(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_username(UUID, TEXT) TO authenticated;
