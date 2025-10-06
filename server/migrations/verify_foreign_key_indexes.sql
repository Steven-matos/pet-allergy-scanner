-- Verification Script: Check Foreign Key Indexes
-- Description: Verifies that foreign key indexes are properly created and functioning
-- Date: 2025-01-15

-- ============================================================================
-- CHECK FOREIGN KEY CONSTRAINTS AND THEIR INDEXES
-- ============================================================================
-- This script helps verify that all foreign key constraints have supporting indexes

-- Check foreign key constraints and their supporting indexes
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.column_name,
    kcu.ordinal_position,
    i.indexname,
    i.indexdef
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
LEFT JOIN pg_indexes i ON i.tablename = tc.table_name 
    AND i.indexdef LIKE '%' || tc.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN (
        'food_comparisons',
        'nutritional_analytics_cache', 
        'nutritional_recommendations',
        'pet_weight_records'
    )
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- ============================================================================
-- CHECK SPECIFIC FOREIGN KEY INDEXES
-- ============================================================================
-- Verify that the required foreign key indexes exist

SELECT 
    'Foreign Key Indexes Status:' as status,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE indexname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id',
    'idx_nutritional_recommendations_pet_id',
    'idx_pet_weight_records_recorded_by_user_id'
)
ORDER BY tablename, indexname;

-- ============================================================================
-- CHECK COMPOSITE INDEXES
-- ============================================================================
-- Verify that the strategic composite indexes exist

SELECT 
    'Composite Indexes Status:' as status,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE indexname IN (
    'idx_food_comparisons_user_created',
    'idx_nutritional_analytics_cache_pet_created',
    'idx_nutritional_recommendations_pet_status'
)
ORDER BY tablename, indexname;

-- ============================================================================
-- CHECK INDEX USAGE STATISTICS
-- ============================================================================
-- This query shows index usage statistics to confirm they are being used
-- Note: This requires the pg_stat_user_indexes view to be available

SELECT 
    schemaname,
    relname as table_name,
    indexrelname as index_name,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE indexrelname IN (
    'idx_food_comparisons_user_id',
    'idx_nutritional_analytics_cache_pet_id',
    'idx_nutritional_recommendations_pet_id',
    'idx_pet_weight_records_recorded_by_user_id',
    'idx_food_comparisons_user_created',
    'idx_nutritional_analytics_cache_pet_created',
    'idx_nutritional_recommendations_pet_status'
)
ORDER BY relname, indexrelname;

-- ============================================================================
-- CHECK FOREIGN KEY CONSTRAINT DETAILS
-- ============================================================================
-- Get detailed information about foreign key constraints

SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    CASE 
        WHEN i.indexname IS NOT NULL THEN 'INDEXED'
        ELSE 'NOT INDEXED'
    END as index_status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name 
    AND ccu.table_schema = tc.table_schema
LEFT JOIN pg_indexes i ON i.tablename = tc.table_name 
    AND i.indexdef LIKE '%' || tc.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN (
        'food_comparisons',
        'nutritional_analytics_cache', 
        'nutritional_recommendations',
        'pet_weight_records'
    )
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- SUMMARY QUERIES
-- ============================================================================

-- Count total indexes per table
SELECT 
    tablename,
    count(*) as total_indexes,
    string_agg(indexname, ', ' ORDER BY indexname) as index_names
FROM pg_indexes 
WHERE schemaname = 'public'
    AND tablename IN (
        'food_comparisons',
        'nutritional_analytics_cache', 
        'nutritional_recommendations',
        'pet_weight_records'
    )
GROUP BY tablename
ORDER BY tablename;

-- Check for any missing foreign key indexes
SELECT 
    'Missing Foreign Key Indexes:' as status,
    tc.table_name,
    tc.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
LEFT JOIN pg_indexes i ON i.tablename = tc.table_name 
    AND i.indexdef LIKE '%' || tc.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN (
        'food_comparisons',
        'nutritional_analytics_cache', 
        'nutritional_recommendations',
        'pet_weight_records'
    )
    AND i.indexname IS NULL
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- PERFORMANCE IMPACT ANALYSIS
-- ============================================================================
-- Check the size of indexes to estimate storage impact

SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    pg_relation_size(indexrelid) as size_bytes
FROM pg_indexes 
WHERE schemaname = 'public'
    AND indexname IN (
        'idx_food_comparisons_user_id',
        'idx_nutritional_analytics_cache_pet_id',
        'idx_nutritional_recommendations_pet_id',
        'idx_pet_weight_records_recorded_by_user_id',
        'idx_food_comparisons_user_created',
        'idx_nutritional_analytics_cache_pet_created',
        'idx_nutritional_recommendations_pet_status'
    )
ORDER BY pg_relation_size(indexrelid) DESC;
