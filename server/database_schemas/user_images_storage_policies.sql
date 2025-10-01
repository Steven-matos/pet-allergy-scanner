-- User Images Storage Policies (Supabase)
-- This script adds storage policies for user profile pictures
-- Created: 2025-10-01
--
-- IMPORTANT: Run this via Supabase SQL Editor, NOT via psql
-- The postgres user doesn't have permission to modify storage policies directly

-- =============================================================================
-- USER IMAGES BUCKET POLICIES
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
-- POLICY COMMENTS
-- =============================================================================

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

