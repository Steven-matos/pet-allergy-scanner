-- Migration: Fix Unindexed Foreign Keys
-- Description: Adds missing indexes for foreign key constraints to improve database performance
-- Date: 2025-01-15
--
-- This migration addresses the following unindexed foreign keys:
-- 1. food_comparisons.user_id -> users.id
-- 2. nutritional_analytics_cache.pet_id -> pets.id  
-- 3. nutritional_recommendations.pet_id -> pets.id
-- 4. pet_weight_records.recorded_by_user_id -> users.id

-- ============================================================================
-- PERFORMANCE IMPACT ANALYSIS
-- ============================================================================
-- BENEFITS:
-- 1. Improves DELETE/UPDATE performance on referenced tables
-- 2. Enables efficient referential integrity checks
-- 3. Optimizes JOIN operations on foreign key columns
-- 4. Reduces query planning time for foreign key operations

-- QUERY PERFORMANCE:
-- - Foreign key constraint checks will be faster
-- - DELETE operations on referenced tables will be optimized
-- - JOIN queries using these foreign keys will be more efficient
-- - Reduces sequential scans during referential integrity checks

-- ============================================================================
-- ADD MISSING FOREIGN KEY INDEXES
-- ============================================================================

-- 1. Fix food_comparisons.user_id foreign key index
-- This index supports referential integrity checks when deleting/updating users
CREATE INDEX IF NOT EXISTS idx_food_comparisons_user_id
    ON public.food_comparisons(user_id);

-- 2. Fix nutritional_analytics_cache.pet_id foreign key index  
-- This index supports referential integrity checks when deleting/updating pets
CREATE INDEX IF NOT EXISTS idx_nutritional_analytics_cache_pet_id
    ON public.nutritional_analytics_cache(pet_id);

-- 3. Fix nutritional_recommendations.pet_id foreign key index
-- This index supports referential integrity checks when deleting/updating pets
CREATE INDEX IF NOT EXISTS idx_nutritional_recommendations_pet_id
    ON public.nutritional_recommendations(pet_id);

-- 4. Fix pet_weight_records.recorded_by_user_id foreign key index
-- This index supports referential integrity checks when deleting/updating users
-- Note: This may already exist from previous migrations, but we ensure it's present
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_by_user_id
    ON public.pet_weight_records(recorded_by_user_id);

-- ============================================================================
-- ADD STRATEGIC COMPOSITE INDEXES
-- ============================================================================
-- Add composite indexes for common query patterns that use these foreign keys

-- Composite index for food_comparisons queries by user and creation date
CREATE INDEX IF NOT EXISTS idx_food_comparisons_user_created
    ON public.food_comparisons(user_id, created_at DESC);

-- Composite index for nutritional_analytics_cache queries by pet and cache date
CREATE INDEX IF NOT EXISTS idx_nutritional_analytics_cache_pet_created
    ON public.nutritional_analytics_cache(pet_id, created_at DESC);

-- Composite index for nutritional_recommendations queries by pet and status
CREATE INDEX IF NOT EXISTS idx_nutritional_recommendations_pet_status
    ON public.nutritional_recommendations(pet_id, is_active, created_at DESC);

-- ============================================================================
-- ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON INDEX idx_food_comparisons_user_id IS 
    'Foreign key index for food_comparisons.user_id to support referential integrity checks';

COMMENT ON INDEX idx_nutritional_analytics_cache_pet_id IS 
    'Foreign key index for nutritional_analytics_cache.pet_id to support referential integrity checks';

COMMENT ON INDEX idx_nutritional_recommendations_pet_id IS 
    'Foreign key index for nutritional_recommendations.pet_id to support referential integrity checks';

COMMENT ON INDEX idx_pet_weight_records_recorded_by_user_id IS 
    'Foreign key index for pet_weight_records.recorded_by_user_id to support referential integrity checks';

COMMENT ON INDEX idx_food_comparisons_user_created IS 
    'Composite index for food comparison queries by user and creation date';

COMMENT ON INDEX idx_nutritional_analytics_cache_pet_created IS 
    'Composite index for analytics cache queries by pet and creation date';

COMMENT ON INDEX idx_nutritional_recommendations_pet_status IS 
    'Composite index for nutritional recommendations by pet, status, and creation date';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify the foreign key indexes were created:

-- Check that foreign key indexes exist:
-- SELECT 
--     schemaname,
--     tablename,
--     indexname,
--     indexdef
-- FROM pg_indexes 
-- WHERE indexname IN (
--     'idx_food_comparisons_user_id',
--     'idx_nutritional_analytics_cache_pet_id',
--     'idx_nutritional_recommendations_pet_id',
--     'idx_pet_weight_records_recorded_by_user_id'
-- )
-- ORDER BY tablename, indexname;

-- Check foreign key constraints and their supporting indexes:
-- SELECT 
--     tc.table_name,
--     tc.constraint_name,
--     tc.column_name,
--     i.indexname
-- FROM information_schema.table_constraints tc
-- LEFT JOIN pg_indexes i ON i.tablename = tc.table_name 
--     AND i.indexdef LIKE '%' || tc.column_name || '%'
-- WHERE tc.constraint_type = 'FOREIGN KEY'
--     AND tc.table_name IN (
--         'food_comparisons',
--         'nutritional_analytics_cache', 
--         'nutritional_recommendations',
--         'pet_weight_records'
--     )
-- ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- PRODUCTION-SAFE ALTERNATIVES FOR LARGE TABLES
-- ============================================================================
-- If you have large tables (>1M rows), consider running these commands manually
-- outside of a transaction block using CONCURRENTLY for zero-downtime:

/*
-- For production environments with large tables, run these commands manually:
-- (Remove the comments and run each command separately)

-- 1. Create foreign key indexes concurrently (zero downtime):
CREATE INDEX CONCURRENTLY idx_food_comparisons_user_id
    ON public.food_comparisons(user_id);

CREATE INDEX CONCURRENTLY idx_nutritional_analytics_cache_pet_id
    ON public.nutritional_analytics_cache(pet_id);

CREATE INDEX CONCURRENTLY idx_nutritional_recommendations_pet_id
    ON public.nutritional_recommendations(pet_id);

CREATE INDEX CONCURRENTLY idx_pet_weight_records_recorded_by_user_id
    ON public.pet_weight_records(recorded_by_user_id);

-- 2. Create composite indexes concurrently:
CREATE INDEX CONCURRENTLY idx_food_comparisons_user_created
    ON public.food_comparisons(user_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_nutritional_analytics_cache_pet_created
    ON public.nutritional_analytics_cache(pet_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_nutritional_recommendations_pet_status
    ON public.nutritional_recommendations(pet_id, is_active, created_at DESC);
*/

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- This migration resolves the following Supabase Database Linter warnings:
-- - Unindexed Foreign Keys (INFO): Adds missing indexes for 4 foreign key constraints
-- - Performance optimization: Improves DELETE/UPDATE performance on referenced tables
-- - Query optimization: Enables efficient JOIN operations on foreign key columns

-- The indexes being added are essential for:
-- 1. Supporting referential integrity checks during DELETE/UPDATE operations
-- 2. Optimizing JOIN queries that use these foreign key columns
-- 3. Improving overall database performance for operations involving these tables

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- If rollback is needed, the indexes can be removed using:
-- (Note: Only remove if you have evidence that these indexes are not needed)

-- DROP INDEX IF EXISTS idx_food_comparisons_user_id;
-- DROP INDEX IF EXISTS idx_nutritional_analytics_cache_pet_id;
-- DROP INDEX IF EXISTS idx_nutritional_recommendations_pet_id;
-- DROP INDEX IF EXISTS idx_pet_weight_records_recorded_by_user_id;
-- DROP INDEX IF EXISTS idx_food_comparisons_user_created;
-- DROP INDEX IF EXISTS idx_nutritional_analytics_cache_pet_created;
-- DROP INDEX IF EXISTS idx_nutritional_recommendations_pet_status;
