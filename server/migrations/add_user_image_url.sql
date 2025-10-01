-- Add image_url column to users table
-- Migration: Add user profile photo support
-- Created: 2025-10-01

-- Add image_url column to store local file paths or remote URLs
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment to column
COMMENT ON COLUMN users.image_url IS 'URL or file path to user profile photo';

