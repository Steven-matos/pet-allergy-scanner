-- Migration: Add username column to users table
-- This migration adds the username field to the existing users table

-- Add username column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;

-- Create index for username field for better query performance
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);

-- Add comment to document the column
COMMENT ON COLUMN public.users.username IS 'Unique username for the user account';
