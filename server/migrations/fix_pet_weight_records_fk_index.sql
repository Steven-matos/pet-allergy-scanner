-- Fix missing foreign key index on pet_weight_records.recorded_by_user_id
-- This migration addresses the performance issue where DELETE/UPDATE operations
-- on the referenced users table require sequential scans on pet_weight_records
-- without a supporting index on the foreign key column.
--
-- IMPORTANT: This index was incorrectly removed in a previous migration as "unused"
-- but it's actually essential for foreign key constraint performance.

-- Create index on the foreign key column to support referential integrity checks
-- Note: Using regular CREATE INDEX instead of CONCURRENTLY due to transaction block limitations
-- For production environments with large tables, consider running these commands manually
-- outside of a transaction block using CONCURRENTLY for zero-downtime index creation
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_by_user_id
  ON public.pet_weight_records (recorded_by_user_id);

-- Create a composite index for common query patterns
-- This covers queries that filter by user and sort by recorded_at
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_user_id_recorded_at
  ON public.pet_weight_records (recorded_by_user_id, recorded_at DESC);

-- Create a partial index for non-null recorded_by_user_id values
-- This optimizes for queries that filter by users who actually recorded weights
-- Note: Using a simple condition instead of date-based filtering since functions in index predicates must be immutable
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_by_user_not_null
  ON public.pet_weight_records (recorded_by_user_id)
  WHERE recorded_by_user_id IS NOT NULL;

-- Add comments for documentation
COMMENT ON INDEX idx_pet_weight_records_recorded_by_user_id IS 
  'Index on foreign key column to support referential integrity checks and improve DELETE/UPDATE performance on users table';

COMMENT ON INDEX idx_pet_weight_records_user_id_recorded_at IS 
  'Composite index for queries filtering by user and sorting by recorded_at timestamp';

COMMENT ON INDEX idx_pet_weight_records_recorded_by_user_not_null IS 
  'Partial index for non-null recorded_by_user_id values to optimize user-based queries';

-- ============================================================================
-- PRODUCTION-SAFE ALTERNATIVES FOR LARGE TABLES
-- ============================================================================
-- If you have a large pet_weight_records table (>1M rows), consider running
-- these commands manually outside of a transaction block to avoid blocking:

/*
-- For production environments with large tables, run these commands manually:
-- (Remove the comments and run each command separately)

-- 1. Create the foreign key index concurrently (zero downtime):
CREATE INDEX CONCURRENTLY idx_pet_weight_records_recorded_by_user_id
  ON public.pet_weight_records (recorded_by_user_id);

-- 2. Create the composite index concurrently:
CREATE INDEX CONCURRENTLY idx_pet_weight_records_user_id_recorded_at
  ON public.pet_weight_records (recorded_by_user_id, recorded_at DESC);

-- 3. Create the partial index concurrently:
CREATE INDEX CONCURRENTLY idx_pet_weight_records_recorded_by_user_not_null
  ON public.pet_weight_records (recorded_by_user_id)
  WHERE recorded_by_user_id IS NOT NULL;
*/

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Verify the indexes were created successfully
-- This query will show the new indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'pet_weight_records' 
  AND indexname LIKE 'idx_pet_weight_records%'
ORDER BY indexname;
