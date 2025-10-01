-- Supabase Storage Setup for User and Pet Images
-- This script sets up storage buckets and security policies
-- Created: 2025-10-01

-- =============================================================================
-- BUCKET CREATION
-- =============================================================================
-- Note: Buckets are typically created via Supabase Dashboard or API
-- Uncomment below if running directly in database with appropriate permissions

-- Create storage bucket for user profile images
-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES (
--   'user-images',
--   'user-images',
--   true,
--   5242880, -- 5MB limit
--   ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
-- )
-- ON CONFLICT (id) DO NOTHING;

-- Create storage bucket for pet images
-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES (
--   'pet-images',
--   'pet-images',
--   true,
--   5242880, -- 5MB limit
--   ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
-- )
-- ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- USER IMAGES BUCKET POLICIES
-- =============================================================================

-- Drop existing policies if they exist (for idempotent runs)
DROP POLICY IF EXISTS "Users can upload their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their profile image" ON storage.objects;
DROP POLICY IF EXISTS "Public can view user profile images" ON storage.objects;

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
-- PET IMAGES BUCKET POLICIES
-- =============================================================================

-- Drop existing policies if they exist (for idempotent runs)
DROP POLICY IF EXISTS "Users can upload their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;

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
-- This enables sharing and viewing pet images without authentication
CREATE POLICY "Public can view pet images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'pet-images');

-- =============================================================================
-- POLICY COMMENTS
-- =============================================================================

-- User Images Comments
COMMENT ON POLICY "Users can upload their profile image" ON storage.objects IS 
'Allows authenticated users to upload their profile image to their user folder';

COMMENT ON POLICY "Users can view their profile image" ON storage.objects IS 
'Allows authenticated users to view their profile image';

COMMENT ON POLICY "Users can update their profile image" ON storage.objects IS 
'Allows authenticated users to update their profile image';

COMMENT ON POLICY "Users can delete their profile image" ON storage.objects IS 
'Allows authenticated users to delete their profile image';

COMMENT ON POLICY "Public can view user profile images" ON storage.objects IS 
'Allows public access to view user profile images via public URLs';

-- Pet Images Comments
COMMENT ON POLICY "Users can upload their pet images" ON storage.objects IS 
'Allows authenticated users to upload images to their user folder in the pet-images bucket';

COMMENT ON POLICY "Users can view their pet images" ON storage.objects IS 
'Allows authenticated users to view images in their user folder';

COMMENT ON POLICY "Users can delete their pet images" ON storage.objects IS 
'Allows authenticated users to delete images from their user folder';

COMMENT ON POLICY "Public can view pet images" ON storage.objects IS 
'Allows public access to view pet images via public URLs';

