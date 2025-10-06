-- Migration: Fix RLS Performance Issues
-- Optimizes Row Level Security policies for better performance
-- Addresses Supabase Security Advisor warnings for:
-- - Auth RLS Initialization Plan (auth.uid() re-evaluation)
-- - Multiple Permissive Policies (consolidation)

-- ============================================================================
-- 1. FIX AUTH RLS INITIALIZATION PLAN ISSUES
-- ============================================================================
-- Replace auth.uid() with (SELECT auth.uid()) to prevent re-evaluation per row

-- Drop existing policies for pet_weight_records
DROP POLICY IF EXISTS "Users can view their pet weight records" ON pet_weight_records;
DROP POLICY IF EXISTS "Users can insert their pet weight records" ON pet_weight_records;
DROP POLICY IF EXISTS "Users can update their pet weight records" ON pet_weight_records;
DROP POLICY IF EXISTS "Users can delete their pet weight records" ON pet_weight_records;

-- Create optimized policies for pet_weight_records
CREATE POLICY "Users can view their pet weight records" ON pet_weight_records
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
    );

CREATE POLICY "Users can insert their pet weight records" ON pet_weight_records
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
    );

CREATE POLICY "Users can update their pet weight records" ON pet_weight_records
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
    );

CREATE POLICY "Users can delete their pet weight records" ON pet_weight_records
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
    );

-- Drop existing policies for pet_weight_goals
DROP POLICY IF EXISTS "Users can view their pet weight goals" ON pet_weight_goals;
DROP POLICY IF EXISTS "Users can manage their pet weight goals" ON pet_weight_goals;

-- Create optimized policies for pet_weight_goals (consolidated)
CREATE POLICY "Users can manage their pet weight goals" ON pet_weight_goals
    FOR ALL USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
    );

-- Drop existing policies for calorie_goals
DROP POLICY IF EXISTS "Users can view their own pet's calorie goals" ON public.calorie_goals;
DROP POLICY IF EXISTS "Users can insert calorie goals for their pets" ON public.calorie_goals;
DROP POLICY IF EXISTS "Users can update their own pet's calorie goals" ON public.calorie_goals;
DROP POLICY IF EXISTS "Users can delete their own pet's calorie goals" ON public.calorie_goals;

-- Create optimized policies for calorie_goals (consolidated)
CREATE POLICY "Users can manage their pet calorie goals" ON public.calorie_goals
    FOR ALL USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())
        )
    );

-- Drop existing policies for food_items
DROP POLICY IF EXISTS "Authenticated users can insert food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can update food items" ON public.food_items;
DROP POLICY IF EXISTS "Authenticated users can delete food items" ON public.food_items;

-- Create optimized policies for food_items (consolidated)
CREATE POLICY "Authenticated users can manage food items" ON public.food_items
    FOR ALL USING ((SELECT auth.role()) = 'authenticated');

-- ============================================================================
-- 2. FIX MULTIPLE PERMISSIVE POLICIES ISSUES
-- ============================================================================
-- Consolidate multiple policies into single optimized policies

-- Drop existing policies for nutritional_trends
DROP POLICY IF EXISTS "Users can view their pet nutritional trends" ON nutritional_trends;
DROP POLICY IF EXISTS "System can manage nutritional trends" ON nutritional_trends;

-- Create consolidated policy for nutritional_trends
CREATE POLICY "Users and system can manage nutritional trends" ON nutritional_trends
    FOR ALL USING (
        -- Allow users to access their own pet's data
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
        OR
        -- Allow system service account (authenticator role)
        (SELECT auth.role()) = 'authenticator'
    );

-- Drop existing policies for nutritional_analytics_cache
DROP POLICY IF EXISTS "Users can view their pet analytics" ON nutritional_analytics_cache;
DROP POLICY IF EXISTS "System can manage analytics cache" ON nutritional_analytics_cache;

-- Create consolidated policy for nutritional_analytics_cache
CREATE POLICY "Users and system can manage analytics cache" ON nutritional_analytics_cache
    FOR ALL USING (
        -- Allow users to access their own pet's data
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
        OR
        -- Allow system service account (authenticator role)
        (SELECT auth.role()) = 'authenticator'
    );

-- Drop existing policies for nutritional_recommendations
DROP POLICY IF EXISTS "Users can view their pet recommendations" ON nutritional_recommendations;
DROP POLICY IF EXISTS "System can manage recommendations" ON nutritional_recommendations;

-- Create consolidated policy for nutritional_recommendations
CREATE POLICY "Users and system can manage recommendations" ON nutritional_recommendations
    FOR ALL USING (
        -- Allow users to access their own pet's data
        pet_id IN (
            SELECT id FROM pets WHERE user_id = (SELECT auth.uid())
        )
        OR
        -- Allow system service account (authenticator role)
        (SELECT auth.role()) = 'authenticator'
    );

-- ============================================================================
-- 3. ADD MISSING POLICIES FOR FOOD_COMPARISONS
-- ============================================================================
-- Create optimized policy for food_comparisons if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'food_comparisons') THEN
        -- Drop existing policy if it exists
        DROP POLICY IF EXISTS "Users can manage their food comparisons" ON food_comparisons;
        
        -- Create optimized policy for food_comparisons (uses user_id directly)
        CREATE POLICY "Users can manage their food comparisons" ON food_comparisons
            FOR ALL USING (
                user_id = (SELECT auth.uid())
            );
    END IF;
END $$;

-- ============================================================================
-- 4. ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON POLICY "Users can view their pet weight records" ON pet_weight_records IS 
'Optimized RLS policy using subquery to prevent auth.uid() re-evaluation per row';

COMMENT ON POLICY "Users can manage their pet weight goals" ON pet_weight_goals IS 
'Consolidated RLS policy for all weight goal operations with optimized auth.uid() call';

COMMENT ON POLICY "Users can manage their pet calorie goals" ON public.calorie_goals IS 
'Consolidated RLS policy for all calorie goal operations with optimized auth.uid() call';

COMMENT ON POLICY "Authenticated users can manage food items" ON public.food_items IS 
'Consolidated RLS policy for food item management with optimized auth.role() call';

COMMENT ON POLICY "Users and system can manage nutritional trends" ON nutritional_trends IS 
'Consolidated RLS policy allowing both user access and system management with optimized auth calls';

COMMENT ON POLICY "Users and system can manage analytics cache" ON nutritional_analytics_cache IS 
'Consolidated RLS policy allowing both user access and system management with optimized auth calls';

COMMENT ON POLICY "Users and system can manage recommendations" ON nutritional_recommendations IS 
'Consolidated RLS policy allowing both user access and system management with optimized auth calls';

-- ============================================================================
-- 5. PERFORMANCE OPTIMIZATION NOTES
-- ============================================================================
-- This migration addresses the following performance issues:
-- 1. Auth RLS Initialization Plan: Replaced auth.uid() with (SELECT auth.uid())
--    to prevent re-evaluation for each row, improving query performance at scale
-- 2. Multiple Permissive Policies: Consolidated multiple policies into single
--    policies per table, reducing policy evaluation overhead
-- 3. System Account Access: Maintained system service account access while
--    optimizing user access patterns
-- 4. Query Optimization: Used subqueries to cache auth function results
--    and prevent repeated function calls during policy evaluation
