-- Supabase Migration: Add username field to users table
-- Run this in your Supabase SQL editor

-- Add username column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;

-- Create index for username field for better query performance
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);

-- Add comment to document the column
COMMENT ON COLUMN public.users.username IS 'Unique username for the user account';

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
AND column_name = 'username';
