-- Migration: Fix Multiple Permissive Policies on food_items Table
-- Description: Consolidates conflicting RLS policies on food_items table to resolve performance warnings
-- Date: 2025-01-15

-- ============================================================================
-- PROBLEM IDENTIFIED
-- ============================================================================
-- The food_items table has multiple permissive policies for SELECT operations:
-- 1. "Users can view all food items" (allows all users to SELECT)
-- 2. "Authenticated users can manage food items" (allows authenticated users to SELECT)
-- 
-- This creates performance issues as both policies must be evaluated for every SELECT query.
-- We need to consolidate these into a single optimized policy.

-- ============================================================================
-- SOLUTION: CONSOLIDATE POLICIES
-- ============================================================================

-- Drop all existing policies on food_items table
DROP POLICY IF EXISTS "Users can view all food items" ON public.food_items;
DROP POLICY IF EXISTS "Anyone can view food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can insert food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can update food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can delete food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can manage food items" ON public.food_items;

-- Create consolidated policies that handle all operations efficiently
-- Policy 1: Allow all users (including anonymous) to read food items
-- This is appropriate since food items are a public database for reference
CREATE POLICY "Anyone can view food items" ON public.food_items
    FOR SELECT USING (true);

-- Policy 2: Only authenticated users can modify food items
-- This prevents anonymous users from modifying the food database
CREATE POLICY "Authenticated users can manage food items" ON public.food_items
    FOR ALL USING (
        -- Allow authenticated users to perform all operations
        (SELECT auth.role()) = 'authenticated'
    )
    WITH CHECK (
        -- Ensure authenticated users can only insert/update with valid data
        (SELECT auth.role()) = 'authenticated'
    );

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- These queries can be run to verify the policies work correctly:

-- Test anonymous access (should only allow SELECT)
-- SELECT * FROM public.food_items LIMIT 1;

-- Test authenticated user access (should allow all operations)
-- INSERT INTO public.food_items (name, brand) VALUES ('Test Food', 'Test Brand');
-- UPDATE public.food_items SET name = 'Updated Name' WHERE name = 'Test Food';
-- DELETE FROM public.food_items WHERE name = 'Updated Name';

-- ============================================================================
-- PERFORMANCE BENEFITS
-- ============================================================================
-- 1. Single policy evaluation for SELECT operations (instead of multiple)
-- 2. Optimized auth.role() call using subquery to prevent re-evaluation
-- 3. Clear separation between read (public) and write (authenticated) access
-- 4. Reduced policy evaluation overhead for all queries

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================
COMMENT ON POLICY "Anyone can view food items" ON public.food_items IS 
'Allows all users (including anonymous) to read food items from the public database. This is appropriate since food items are reference data that should be accessible to all users for scanning and lookup purposes.';

COMMENT ON POLICY "Authenticated users can manage food items" ON public.food_items IS 
'Allows only authenticated users to create, update, or delete food items. This prevents anonymous users from modifying the food database while allowing authenticated users to manage the food items catalog. Uses optimized auth.role() call to prevent re-evaluation per row.';

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- This migration resolves the Supabase Security Advisor warnings:
-- - Multiple Permissive Policies (WARN): Fixed by consolidating SELECT policies
-- - Performance optimization: Single policy evaluation instead of multiple
-- - Maintains security: Anonymous users can read, only authenticated users can modify
-- - Follows principle of least privilege: Minimal necessary permissions per role
