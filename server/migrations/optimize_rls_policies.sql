-- Migration: Optimize RLS Policies for Performance
-- Date: 2025-10-01
-- Description: Wraps auth.uid() calls in subqueries to prevent re-evaluation per row
-- Reference: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- ============================================================================
-- USERS TABLE POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

-- Recreate with optimized auth calls
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING ((SELECT auth.uid()) = id);

-- ============================================================================
-- PETS TABLE POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can insert own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can update own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can delete own pets" ON public.pets;

-- Recreate with optimized auth calls
CREATE POLICY "Users can view own pets" ON public.pets
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own pets" ON public.pets
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own pets" ON public.pets
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own pets" ON public.pets
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- SCANS TABLE POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can insert own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can update own scans" ON public.scans;
DROP POLICY IF EXISTS "Users can delete own scans" ON public.scans;

-- Recreate with optimized auth calls
CREATE POLICY "Users can view own scans" ON public.scans
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own scans" ON public.scans
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own scans" ON public.scans
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own scans" ON public.scans
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- FAVORITES TABLE POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can insert own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can update own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can delete own favorites" ON public.favorites;

-- Recreate with optimized auth calls
CREATE POLICY "Users can view own favorites" ON public.favorites
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own favorites" ON public.favorites
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own favorites" ON public.favorites
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own favorites" ON public.favorites
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify all policies are in place
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename IN ('users', 'pets', 'scans', 'favorites');
    
    RAISE NOTICE 'Total RLS policies after optimization: %', policy_count;
    
    IF policy_count < 14 THEN
        RAISE WARNING 'Expected at least 14 policies, found %', policy_count;
    ELSE
        RAISE NOTICE 'RLS policy optimization completed successfully';
    END IF;
END $$;

