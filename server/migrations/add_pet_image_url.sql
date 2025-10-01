-- Add image_url column to pets table
-- Migration: Add pet photo support
-- Created: 2025-10-01

-- Add image_url column to store local file paths or remote URLs
ALTER TABLE pets 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment to column
COMMENT ON COLUMN pets.image_url IS 'URL or file path to pet photo image';

