-- Migration: Validate Foreign Key Indexes
-- Description: Comprehensive check for missing foreign key indexes across all tables
-- Date: 2025-01-15

-- ============================================================================
-- FOREIGN KEY INDEX VALIDATION
-- ============================================================================
-- This migration validates that all foreign key columns have appropriate indexes
-- to ensure optimal performance for referential integrity checks.

-- ============================================================================
-- QUERY TO IDENTIFY MISSING FOREIGN KEY INDEXES
-- ============================================================================
-- Run this query to identify foreign key columns that lack supporting indexes:

/*
WITH fk_columns AS (
    SELECT 
        tc.table_schema,
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        tc.constraint_name
    FROM information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
),
existing_indexes AS (
    SELECT 
        schemaname,
        tablename,
        indexname,
        indexdef
    FROM pg_indexes 
    WHERE schemaname = 'public'
)
SELECT 
    fk.table_name,
    fk.column_name,
    fk.foreign_table_name,
    fk.foreign_column_name,
    fk.constraint_name,
    CASE 
        WHEN ei.indexname IS NULL THEN 'MISSING INDEX'
        ELSE 'INDEX EXISTS'
    END as index_status
FROM fk_columns fk
LEFT JOIN existing_indexes ei ON (
    ei.tablename = fk.table_name 
    AND ei.indexdef LIKE '%' || fk.column_name || '%'
)
ORDER BY fk.table_name, fk.column_name;
*/

-- ============================================================================
-- KNOWN FOREIGN KEY COLUMNS AND THEIR INDEX STATUS
-- ============================================================================

-- Core tables (from database_schema.sql):
-- ✅ pets.user_id -> users(id) - HAS INDEX: idx_pets_user_id
-- ✅ scans.user_id -> users(id) - HAS INDEX: idx_scans_user_id  
-- ✅ scans.pet_id -> pets(id) - HAS INDEX: idx_scans_pet_id
-- ✅ favorites.user_id -> users(id) - HAS INDEX: idx_favorites_user_id
-- ✅ favorites.pet_id -> pets(id) - HAS INDEX: idx_favorites_pet_id

-- Nutrition tables (from add_nutrition_tables.sql):
-- ✅ nutritional_requirements.pet_id -> pets(id) - HAS INDEX: idx_nutritional_requirements_pet_id
-- ✅ food_analyses.pet_id -> pets(id) - HAS INDEX: idx_food_analyses_pet_id
-- ✅ feeding_records.pet_id -> pets(id) - HAS INDEX: idx_feeding_records_pet_id
-- ✅ feeding_records.food_analysis_id -> food_analyses(id) - HAS INDEX: idx_feeding_records_food_analysis_id
-- ✅ daily_nutrition_summaries.pet_id -> pets(id) - HAS INDEX: idx_daily_summaries_pet_id
-- ✅ nutrition_recommendations.pet_id -> pets(id) - HAS INDEX: idx_nutrition_recommendations_pet_id
-- ✅ nutrition_goals.pet_id -> pets(id) - HAS INDEX: idx_nutrition_goals_pet_id

-- Advanced nutrition tables (from add_advanced_nutritional_features.sql):
-- ✅ pet_weight_records.pet_id -> pets(id) - HAS INDEX: idx_pet_weight_records_pet_id
-- ❌ pet_weight_records.recorded_by_user_id -> users(id) - MISSING INDEX (being fixed)
-- ✅ pet_weight_goals.pet_id -> pets(id) - HAS INDEX: idx_pet_weight_goals_pet_id
-- ✅ nutritional_trends.pet_id -> pets(id) - HAS INDEX: idx_nutritional_trends_pet_date
-- ✅ food_comparisons.user_id -> users(id) - HAS INDEX: idx_food_comparisons_user_id
-- ✅ nutritional_analytics_cache.pet_id -> pets(id) - HAS INDEX: idx_nutritional_analytics_cache_pet_type
-- ✅ nutritional_recommendations.pet_id -> pets(id) - HAS INDEX: idx_nutritional_recommendations_pet_id

-- Calorie goals and food items (from add_calorie_goals_and_food_items.sql):
-- ✅ calorie_goals.pet_id -> pets(id) - HAS INDEX: idx_calorie_goals_pet_id

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Only ONE foreign key column is missing an index:
-- - pet_weight_records.recorded_by_user_id -> users(id)
-- 
-- This is being addressed in the fix_pet_weight_records_fk_index.sql migration.

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check that the pet_weight_records foreign key index exists:
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'pet_weight_records' 
  AND indexname = 'idx_pet_weight_records_recorded_by_user_id';

-- Check all foreign key constraints in the database:
SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
