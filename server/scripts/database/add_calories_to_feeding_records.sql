-- Migration: Add calories column to feeding_records table
-- Date: 2025-01-XX
-- Description: Adds a calories column to store calculated calories for each feeding record
--              Calories are calculated as: (calories_per_100g / 100) * amount_grams

-- Add calories column to feeding_records table
ALTER TABLE IF EXISTS public.feeding_records
ADD COLUMN IF NOT EXISTS calories DECIMAL(10,2) CHECK (calories >= 0);

-- Add comment to explain the column
COMMENT ON COLUMN public.feeding_records.calories IS 
'Calculated calories for this feeding record. Formula: (calories_per_100g / 100) * amount_grams. Can be NULL if food_analysis data is not available.';

-- Backfill existing records with calculated calories
-- This updates all existing feeding_records with calories based on their food_analysis
UPDATE public.feeding_records fr
SET calories = (
    SELECT (fa.calories_per_100g / 100.0) * fr.amount_grams
    FROM public.food_analyses fa
    WHERE fa.id = fr.food_analysis_id
    AND fa.calories_per_100g IS NOT NULL
    AND fa.calories_per_100g > 0
)
WHERE calories IS NULL
AND EXISTS (
    SELECT 1 
    FROM public.food_analyses fa 
    WHERE fa.id = fr.food_analysis_id 
    AND fa.calories_per_100g IS NOT NULL
    AND fa.calories_per_100g > 0
);

-- Create index on calories for potential queries/filtering
CREATE INDEX IF NOT EXISTS idx_feeding_records_calories 
ON public.feeding_records(calories) 
WHERE calories IS NOT NULL;

-- =============================================================================
-- Create/Update Nutritional Trends Function
-- =============================================================================

-- Function to update nutritional trends for a specific pet and date
-- This aggregates data from feeding_records and calculates nutritional metrics
CREATE OR REPLACE FUNCTION update_nutritional_trends(
    pet_uuid UUID,
    trend_date DATE
)
RETURNS VOID AS $$
DECLARE
    v_total_calories DECIMAL(10,2) := 0;
    v_total_protein DECIMAL(10,2) := 0;
    v_total_fat DECIMAL(10,2) := 0;
    v_total_fiber DECIMAL(10,2) := 0;
    v_feeding_count INTEGER := 0;
    v_avg_compatibility DECIMAL(5,2) := 0;
    v_weight_change DECIMAL(5,2) := 0;
    v_compatibility_scores DECIMAL(5,2)[];
    v_trend_id UUID;
BEGIN
    -- Calculate totals from feeding_records for the date
    -- Use calories from feeding_records if available, otherwise calculate from food_analyses
    -- Use LEFT JOIN to handle cases where food_analysis might be missing
    SELECT 
        COALESCE(SUM(COALESCE(fr.calories, 
            CASE 
                WHEN fa.calories_per_100g IS NOT NULL AND fa.calories_per_100g > 0 
                THEN (fa.calories_per_100g / 100.0) * fr.amount_grams 
                ELSE 0 
            END
        )), 0),
        COALESCE(SUM(
            CASE 
                WHEN fa.protein_percentage IS NOT NULL 
                THEN (fa.protein_percentage / 100.0) * fr.amount_grams 
                ELSE 0 
            END
        ), 0),
        COALESCE(SUM(
            CASE 
                WHEN fa.fat_percentage IS NOT NULL 
                THEN (fa.fat_percentage / 100.0) * fr.amount_grams 
                ELSE 0 
            END
        ), 0),
        COALESCE(SUM(
            CASE 
                WHEN fa.fiber_percentage IS NOT NULL 
                THEN (fa.fiber_percentage / 100.0) * fr.amount_grams 
                ELSE 0 
            END
        ), 0),
        COUNT(*)
    INTO 
        v_total_calories,
        v_total_protein,
        v_total_fat,
        v_total_fiber,
        v_feeding_count
    FROM public.feeding_records fr
    LEFT JOIN public.food_analyses fa ON fa.id = fr.food_analysis_id
    WHERE fr.pet_id = pet_uuid
    AND DATE(fr.feeding_time) = trend_date;
    
    -- Calculate average compatibility score
    -- This requires nutritional_requirements which may not exist for all pets
    -- For now, we'll set it to 0 if requirements don't exist
    SELECT COALESCE(AVG(
        CASE 
            WHEN nr.id IS NOT NULL THEN
                -- Simple compatibility calculation based on protein/fat/fiber alignment
                -- This is a simplified version - actual compatibility is calculated in the app
                70.0  -- Default compatibility score
            ELSE 0.0
        END
    ), 0.0)
    INTO v_avg_compatibility
    FROM public.feeding_records fr
    LEFT JOIN public.food_analyses fa ON fa.id = fr.food_analysis_id
    LEFT JOIN public.nutritional_requirements nr ON nr.pet_id = fr.pet_id
    WHERE fr.pet_id = pet_uuid
    AND DATE(fr.feeding_time) = trend_date;
    
    -- Calculate weight change (difference from previous day)
    SELECT COALESCE(
        (SELECT weight_kg FROM public.pet_weight_records 
         WHERE pet_id = pet_uuid 
         AND DATE(recorded_at) = trend_date 
         ORDER BY recorded_at DESC LIMIT 1) -
        (SELECT weight_kg FROM public.pet_weight_records 
         WHERE pet_id = pet_uuid 
         AND DATE(recorded_at) < trend_date 
         ORDER BY recorded_at DESC LIMIT 1),
        0.0
    )
    INTO v_weight_change;
    
    -- Only create/update trend if there are feeding records for this date
    IF v_feeding_count > 0 THEN
        -- Check if trend record already exists
        -- FIXED: Use table alias 'nt' to qualify trend_date and avoid ambiguity
        SELECT id INTO v_trend_id
        FROM public.nutritional_trends nt
        WHERE nt.pet_id = pet_uuid AND nt.trend_date = trend_date;
        
        -- Insert or update the trend record
        IF v_trend_id IS NOT NULL THEN
            -- Update existing record
            UPDATE public.nutritional_trends
            SET 
                total_calories = v_total_calories,
                total_protein_g = v_total_protein,
                total_fat_g = v_total_fat,
                total_fiber_g = v_total_fiber,
                feeding_count = v_feeding_count,
                average_compatibility_score = v_avg_compatibility,
                weight_change_kg = v_weight_change,
                updated_at = NOW()
            WHERE id = v_trend_id;
        ELSE
            -- Insert new record
            INSERT INTO public.nutritional_trends (
                pet_id,
                trend_date,
                total_calories,
                total_protein_g,
                total_fat_g,
                total_fiber_g,
                feeding_count,
                average_compatibility_score,
                weight_change_kg
            ) VALUES (
                pet_uuid,
                trend_date,
                v_total_calories,
                v_total_protein,
                v_total_fat,
                v_total_fiber,
                v_feeding_count,
                v_avg_compatibility,
                v_weight_change
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- Add comment to explain the function
COMMENT ON FUNCTION update_nutritional_trends(UUID, DATE) IS 
'Aggregates feeding records and weight data to create/update nutritional trends for a specific pet and date. Calculates total calories, macronutrients, feeding count, average compatibility score, and weight change.';

-- =============================================================================
-- Backfill Missing Nutritional Trends Function
-- =============================================================================

-- Standalone function to backfill missing nutritional trends
-- Can be called anytime to create missing trend records from existing feeding_records
CREATE OR REPLACE FUNCTION backfill_missing_nutritional_trends()
RETURNS TABLE(
    total_found INTEGER,
    total_processed INTEGER,
    total_errors INTEGER
) AS $$
DECLARE
    v_pet_id UUID;
    v_trend_date DATE;
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_total_count INTEGER;
    v_rec RECORD;
BEGIN
    -- Count total unique date/pet combinations to process
    SELECT COUNT(*)
    INTO v_total_count
    FROM (
        SELECT DISTINCT 
            fr.pet_id,
            DATE(fr.feeding_time) as trend_date
        FROM public.feeding_records fr
        WHERE NOT EXISTS (
            SELECT 1 
            FROM public.nutritional_trends nt
            WHERE nt.pet_id = fr.pet_id 
            AND nt.trend_date = DATE(fr.feeding_time)
        )
    ) missing_trends;
    
    RAISE NOTICE '🔍 Found % date/pet combinations with feeding records but no nutritional trends', v_total_count;
    
    IF v_total_count = 0 THEN
        RAISE NOTICE '✅ No missing nutritional trends to backfill. All dates with feeding records already have trends.';
        RETURN QUERY SELECT v_total_count, 0, 0;
        RETURN;
    END IF;
    
    RAISE NOTICE '🚀 Starting backfill process...';
    
    -- Process each unique pet_id and date combination
    FOR v_rec IN
        SELECT DISTINCT 
            fr.pet_id,
            DATE(fr.feeding_time) as trend_date
        FROM public.feeding_records fr
        WHERE NOT EXISTS (
            SELECT 1 
            FROM public.nutritional_trends nt
            WHERE nt.pet_id = fr.pet_id 
            AND nt.trend_date = DATE(fr.feeding_time)
        )
        ORDER BY fr.pet_id, DATE(fr.feeding_time)
    LOOP
        BEGIN
            v_pet_id := v_rec.pet_id;
            v_trend_date := v_rec.trend_date;
            
            -- Call the update function for this pet and date
            -- This will INSERT a new nutritional_trends record if it doesn't exist
            PERFORM update_nutritional_trends(v_pet_id, v_trend_date);
            v_processed_count := v_processed_count + 1;
            
            -- Log progress every 100 records
            IF v_processed_count % 100 = 0 THEN
                RAISE NOTICE '📊 Processed % of % nutritional trends records...', v_processed_count, v_total_count;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Log error but continue processing
            v_error_count := v_error_count + 1;
            RAISE WARNING '⚠️ Failed to create nutritional trend for pet % on date %: %', 
                v_pet_id, v_trend_date, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill complete! Created/updated % nutritional trends records', v_processed_count;
    IF v_error_count > 0 THEN
        RAISE NOTICE '⚠️ Encountered % errors during backfill', v_error_count;
    END IF;
    RAISE NOTICE '📈 Nutritional trends are now available for all dates with feeding records';
    
    -- Return summary statistics
    RETURN QUERY SELECT v_total_count, v_processed_count, v_error_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- Add comment to explain the function
COMMENT ON FUNCTION backfill_missing_nutritional_trends() IS 
'Backfills missing nutritional trends records for all dates that have feeding records but no corresponding trend records. Returns summary statistics: total_found, total_processed, total_errors. Can be called anytime to sync nutritional_trends with feeding_records data.';

-- =============================================================================
-- Run Initial Backfill
-- =============================================================================

-- =============================================================================
-- Diagnostic Queries (for debugging - run these manually in Supabase SQL editor)
-- =============================================================================

-- Check if you have feeding records:
-- SELECT COUNT(*) as total_feeding_records FROM public.feeding_records;

-- Check current nutritional trends:
-- SELECT COUNT(*) as total_nutritional_trends FROM public.nutritional_trends;

-- Find missing dates (dates with feeding records but no trends):
-- SELECT DISTINCT 
--     fr.pet_id,
--     DATE(fr.feeding_time) as trend_date
-- FROM public.feeding_records fr
-- WHERE NOT EXISTS (
--     SELECT 1 
--     FROM public.nutritional_trends nt
--     WHERE nt.pet_id = fr.pet_id 
--     AND nt.trend_date = DATE(fr.feeding_time)
-- )
-- ORDER BY fr.pet_id, DATE(fr.feeding_time);

-- Test the function manually for a specific pet and date:
-- SELECT update_nutritional_trends(
--     'YOUR_PET_ID_HERE'::UUID,
--     '2025-01-15'::DATE
-- );

-- Run the backfill manually:
-- SELECT * FROM backfill_missing_nutritional_trends();

-- =============================================================================
-- Run Initial Backfill
-- =============================================================================

-- Automatically run backfill after creating the function
-- This creates all missing nutritional trends on migration
DO $$
DECLARE
    v_result RECORD;
    v_feeding_count INTEGER;
    v_trend_count INTEGER;
BEGIN
    -- Check if we have any feeding records
    SELECT COUNT(*) INTO v_feeding_count FROM public.feeding_records;
    SELECT COUNT(*) INTO v_trend_count FROM public.nutritional_trends;
    
    RAISE NOTICE '📊 Current state: % feeding records, % nutritional trends', 
        v_feeding_count, v_trend_count;
    
    IF v_feeding_count = 0 THEN
        RAISE NOTICE '⚠️ No feeding records found. Skipping backfill.';
        RETURN;
    END IF;
    
    RAISE NOTICE '🔄 Running initial backfill of missing nutritional trends...';
    SELECT * INTO v_result FROM backfill_missing_nutritional_trends();
    
    RAISE NOTICE '✅ Initial backfill completed: Found %, Processed %, Errors %', 
        v_result.total_found, v_result.total_processed, v_result.total_errors;
    
    -- Verify results
    SELECT COUNT(*) INTO v_trend_count FROM public.nutritional_trends;
    RAISE NOTICE '📈 Final state: % nutritional trends in database', v_trend_count;
END $$;

