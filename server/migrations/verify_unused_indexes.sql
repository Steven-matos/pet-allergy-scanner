-- Verification Script: Check Unused Indexes Status
-- Description: Verifies the current state of indexes before and after removal
-- Date: 2025-01-15

-- ============================================================================
-- CHECK CURRENT INDEX STATUS
-- ============================================================================
-- This script helps verify which indexes exist before removal

-- Check if the unused indexes currently exist
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE indexname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id', 
    'idx_nutritional_recommendations_pet_id',
    'idx_food_items_search_optimized',
    'idx_pet_weight_records_pet_date_optimized',
    'idx_pet_weight_records_recorded_by_user_id',
    'idx_pet_weight_records_user_id_recorded_at',
    'idx_pet_weight_records_recorded_by_user_not_null',
    'idx_scans_user_status_optimized',
    'idx_ingredients_safety_optimized'
)
ORDER BY tablename, indexname;

-- ============================================================================
-- CHECK INDEX USAGE STATISTICS
-- ============================================================================
-- This query shows index usage statistics to confirm they are truly unused
-- Note: This requires the pg_stat_user_indexes view to be available

SELECT 
    schemaname,
    relname as table_name,
    indexrelname as index_name,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes 
WHERE indexrelname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id', 
    'idx_nutritional_recommendations_pet_id',
    'idx_food_items_search_optimized',
    'idx_pet_weight_records_pet_date_optimized',
    'idx_pet_weight_records_recorded_by_user_id',
    'idx_pet_weight_records_user_id_recorded_at',
    'idx_pet_weight_records_recorded_by_user_not_null',
    'idx_scans_user_status_optimized',
    'idx_ingredients_safety_optimized'
)
ORDER BY relname, indexrelname;

-- ============================================================================
-- CHECK TABLE SIZES AND INDEX SIZES
-- ============================================================================
-- This query shows the size of tables and their indexes to estimate storage savings

SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_indexes 
WHERE indexname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id', 
    'idx_nutritional_recommendations_pet_id',
    'idx_food_items_search_optimized',
    'idx_pet_weight_records_pet_date_optimized',
    'idx_pet_weight_records_recorded_by_user_id',
    'idx_pet_weight_records_user_id_recorded_at',
    'idx_pet_weight_records_recorded_by_user_not_null',
    'idx_scans_user_status_optimized',
    'idx_ingredients_safety_optimized'
)
ORDER BY tablename, indexname;

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
-- Run this after applying the migration to verify indexes were removed

-- Check that unused indexes were successfully removed
SELECT 
    'Indexes still exist (should be empty):' as status,
    count(*) as remaining_count
FROM pg_indexes 
WHERE indexname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id', 
    'idx_nutritional_recommendations_pet_id',
    'idx_food_items_search_optimized',
    'idx_pet_weight_records_pet_date_optimized',
    'idx_pet_weight_records_recorded_by_user_id',
    'idx_pet_weight_records_user_id_recorded_at',
    'idx_pet_weight_records_recorded_by_user_not_null',
    'idx_scans_user_status_optimized',
    'idx_ingredients_safety_optimized'
);

-- ============================================================================
-- SUMMARY QUERIES
-- ============================================================================

-- Count total indexes per table (before and after)
SELECT 
    tablename,
    count(*) as total_indexes
FROM pg_indexes 
WHERE schemaname = 'public'
    AND tablename IN (
        'food_comparisons',
        'nutritional_analytics_cache',
        'nutritional_recommendations', 
        'food_items',
        'pet_weight_records',
        'scans',
        'ingredients'
    )
GROUP BY tablename
ORDER BY tablename;

-- Check for any remaining unused indexes (run after migration)
SELECT 
    'Remaining indexes on affected tables:' as status,
    tablename,
    indexname
FROM pg_indexes 
WHERE schemaname = 'public'
    AND tablename IN (
        'food_comparisons',
        'nutritional_analytics_cache',
        'nutritional_recommendations', 
        'food_items',
        'pet_weight_records',
        'scans',
        'ingredients'
    )
ORDER BY tablename, indexname;
