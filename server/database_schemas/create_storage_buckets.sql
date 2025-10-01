-- Create Storage Buckets for User and Pet Images
-- Run this in Supabase SQL Editor
-- Created: 2025-10-01

-- =============================================================================
-- CREATE STORAGE BUCKETS
-- =============================================================================

-- Create user-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-images',
  'user-images',
  true,                          -- Public bucket (enables public URLs)
  5242880,                       -- 5MB file size limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create pet-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pet-images',
  'pet-images',
  true,                          -- Public bucket (enables public URLs)
  5242880,                       -- 5MB file size limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =============================================================================
-- VERIFY BUCKETS WERE CREATED
-- =============================================================================

-- Show created buckets
SELECT 
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at
FROM storage.buckets
WHERE id IN ('user-images', 'pet-images')
ORDER BY name;

