-- =============================================================================
-- STORAGE SETUP - SniffTest Pet Allergy Scanner
-- =============================================================================
-- Complete storage configuration for image uploads
-- Run this ONCE in Supabase SQL Editor after the main schema
-- Created: 2025-01-15

-- =============================================================================
-- CREATE STORAGE BUCKETS
-- =============================================================================

-- Create user-images bucket (profile pictures)
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
-- DROP EXISTING STORAGE POLICIES (if any)
-- =============================================================================

-- Drop user-images policies
DROP POLICY IF EXISTS "Users can upload their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Public can view user profile images" ON storage.objects;

-- Drop pet-images policies
DROP POLICY IF EXISTS "Users can upload their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;

-- =============================================================================
-- CREATE USER IMAGES STORAGE POLICIES
-- =============================================================================

-- Policy: Users can upload their own profile image
CREATE POLICY "Users can upload their profile image"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'user-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can view their own profile image
CREATE POLICY "Users can view their profile image"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'user-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own profile image
CREATE POLICY "Users can update their profile image"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'user-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own profile image
CREATE POLICY "Users can delete their profile image"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'user-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow public read access to user profile images
CREATE POLICY "Public can view user profile images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'user-images');

-- =============================================================================
-- CREATE PET IMAGES STORAGE POLICIES
-- =============================================================================

-- Policy: Users can upload images to their own folder
CREATE POLICY "Users can upload their pet images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pet-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can view their own pet images
CREATE POLICY "Users can view their pet images"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pet-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own pet images
CREATE POLICY "Users can update their pet images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'pet-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own pet images
CREATE POLICY "Users can delete their pet images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'pet-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow public read access to pet images
CREATE POLICY "Public can view pet images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'pet-images');

-- =============================================================================
-- VERIFY SETUP
-- =============================================================================

-- Show created buckets
SELECT 
  id AS bucket_name,
  public,
  file_size_limit / 1024 / 1024 AS size_limit_mb,
  array_length(allowed_mime_types, 1) AS allowed_types_count,
  created_at
FROM storage.buckets
WHERE id IN ('user-images', 'pet-images')
ORDER BY id;

-- Show storage policies
SELECT 
  policyname,
  cmd AS operation,
  CASE 
    WHEN policyname LIKE '%profile%' THEN 'user-images'
    WHEN policyname LIKE '%pet%' THEN 'pet-images'
    ELSE 'unknown'
  END AS bucket
FROM pg_policies 
WHERE tablename = 'objects' 
  AND (policyname LIKE '%profile%' OR policyname LIKE '%pet%')
ORDER BY bucket, policyname;

-- Show image columns
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'pets')
  AND column_name = 'image_url'
ORDER BY table_name;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Storage setup complete!';
  RAISE NOTICE '📦 Buckets: user-images, pet-images';
  RAISE NOTICE '🔒 Policies: 10 total (5 per bucket)';
  RAISE NOTICE '💾 Database: image_url columns already exist';
END $$;
