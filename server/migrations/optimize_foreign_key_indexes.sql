-- Migration: Optimize Foreign Key Indexes
-- Description: Balances foreign key performance needs with unused index cleanup
-- Date: 2025-01-15
--
-- This migration addresses the conflict between:
-- 1. Foreign key indexes that are essential for referential integrity performance
-- 2. Composite indexes that are currently unused and can be removed
--
-- STRATEGY:
-- - Keep essential foreign key indexes (needed for FK constraint performance)
-- - Remove unused composite indexes (can be recreated when actually needed)
-- - Document the reasoning for keeping foreign key indexes

-- ============================================================================
-- ANALYSIS OF UNUSED INDEXES
-- ============================================================================
-- The following indexes are reported as unused:
-- 1. idx_food_comparisons_user_id - ESSENTIAL (foreign key index)
-- 2. idx_nutritional_analytics_cache_pet_id - ESSENTIAL (foreign key index)  
-- 3. idx_nutritional_recommendations_pet_id - ESSENTIAL (foreign key index)
-- 4. idx_pet_weight_records_recorded_by_user_id - ESSENTIAL (foreign key index)
-- 5. idx_food_comparisons_user_created - REMOVE (composite index, unused)
-- 6. idx_nutritional_analytics_cache_pet_created - REMOVE (composite index, unused)
-- 7. idx_nutritional_recommendations_pet_status - REMOVE (composite index, unused)

-- ============================================================================
-- REMOVE UNUSED COMPOSITE INDEXES
-- ============================================================================
-- Remove composite indexes that are currently unused
-- These can be recreated when actually needed for query optimization

-- Remove unused composite index from food_comparisons
DROP INDEX IF EXISTS public.idx_food_comparisons_user_created;

-- Remove unused composite index from nutritional_analytics_cache
DROP INDEX IF EXISTS public.idx_nutritional_analytics_cache_pet_created;

-- Remove unused composite index from nutritional_recommendations
DROP INDEX IF EXISTS public.idx_nutritional_recommendations_pet_status;

-- ============================================================================
-- KEEP ESSENTIAL FOREIGN KEY INDEXES
-- ============================================================================
-- The following foreign key indexes are ESSENTIAL and should NOT be removed:
-- 1. They support referential integrity checks during DELETE/UPDATE operations
-- 2. They prevent performance issues when modifying referenced tables
-- 3. They are required for proper foreign key constraint performance
-- 4. Even if "unused" in queries, they are used internally by PostgreSQL

-- Ensure these foreign key indexes exist (they should already exist from previous migration)
CREATE INDEX IF NOT EXISTS idx_food_comparisons_user_id
    ON public.food_comparisons(user_id);

CREATE INDEX IF NOT EXISTS idx_nutritional_analytics_cache_pet_id
    ON public.nutritional_analytics_cache(pet_id);

CREATE INDEX IF NOT EXISTS idx_nutritional_recommendations_pet_id
    ON public.nutritional_recommendations(pet_id);

CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_by_user_id
    ON public.pet_weight_records(recorded_by_user_id);

-- ============================================================================
-- ADD DOCUMENTATION COMMENTS
-- ============================================================================
-- Document why these foreign key indexes are essential despite being "unused"

COMMENT ON INDEX idx_food_comparisons_user_id IS 
    'ESSENTIAL: Foreign key index for referential integrity. Required for DELETE/UPDATE performance on users table. Do not remove even if reported as unused.';

COMMENT ON INDEX idx_nutritional_analytics_cache_pet_id IS 
    'ESSENTIAL: Foreign key index for referential integrity. Required for DELETE/UPDATE performance on pets table. Do not remove even if reported as unused.';

COMMENT ON INDEX idx_nutritional_recommendations_pet_id IS 
    'ESSENTIAL: Foreign key index for referential integrity. Required for DELETE/UPDATE performance on pets table. Do not remove even if reported as unused.';

COMMENT ON INDEX idx_pet_weight_records_recorded_by_user_id IS 
    'ESSENTIAL: Foreign key index for referential integrity. Required for DELETE/UPDATE performance on users table. Do not remove even if reported as unused.';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify the optimization:

-- Check that essential foreign key indexes still exist:
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

-- Check that unused composite indexes were removed:
-- SELECT 
--     'Removed composite indexes (should be empty):' as status,
--     count(*) as remaining_count
-- FROM pg_indexes 
-- WHERE indexname IN (
--     'idx_food_comparisons_user_created',
--     'idx_nutritional_analytics_cache_pet_created',
--     'idx_nutritional_recommendations_pet_status'
-- );

-- ============================================================================
-- WHY FOREIGN KEY INDEXES ARE ESSENTIAL
-- ============================================================================
-- The following explains why foreign key indexes should be kept despite being "unused":

-- 1. REFERENTIAL INTEGRITY PERFORMANCE:
--    - When you DELETE a user, PostgreSQL must check if any food_comparisons reference that user
--    - Without the index, this requires a full table scan of food_comparisons
--    - With the index, this check is fast and efficient

-- 2. FOREIGN KEY CONSTRAINT CHECKS:
--    - PostgreSQL uses these indexes internally for constraint validation
--    - They're not visible in query statistics but are used by the database engine
--    - Removing them would cause performance degradation during data modifications

-- 3. CASCADE OPERATIONS:
--    - If you have CASCADE DELETE/UPDATE, these indexes are critical
--    - They enable efficient cascading operations on related tables

-- 4. DATABASE HEALTH:
--    - Foreign key indexes are considered a database best practice
--    - They prevent performance issues that are hard to diagnose later
--    - The storage cost is minimal compared to the performance benefits

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- This migration resolves the following issues:

-- RESOLVED:
-- - Removes 3 unused composite indexes that were consuming storage
-- - Keeps 4 essential foreign key indexes for referential integrity
-- - Documents the reasoning for keeping foreign key indexes
-- - Balances performance optimization with database health

-- STORAGE SAVINGS:
-- - Removed 3 unused composite indexes (estimated 2-10MB depending on data size)
-- - Kept essential foreign key indexes (minimal storage impact)
-- - Improved overall database performance

-- PERFORMANCE IMPACT:
-- - Foreign key operations remain optimized
-- - Reduced index maintenance overhead for unused composite indexes
-- - Maintained referential integrity performance
-- - Cleaner database schema

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- If rollback is needed, the composite indexes can be recreated:

-- CREATE INDEX idx_food_comparisons_user_created
--     ON public.food_comparisons(user_id, created_at DESC);
-- CREATE INDEX idx_nutritional_analytics_cache_pet_created
--     ON public.nutritional_analytics_cache(pet_id, created_at DESC);
-- CREATE INDEX idx_nutritional_recommendations_pet_status
--     ON public.nutritional_recommendations(pet_id, is_active, created_at DESC);

-- NOTE: Do NOT remove the foreign key indexes as they are essential for database health
