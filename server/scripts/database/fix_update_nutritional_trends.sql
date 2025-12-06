-- Fix the update_nutritional_trends function to resolve ambiguous column reference
-- Run this in Supabase SQL Editor to fix the function

-- First, drop the existing function to allow parameter name change
DROP FUNCTION IF EXISTS update_nutritional_trends(UUID, DATE);

-- Now create the function with the new parameter name to avoid ambiguity
CREATE FUNCTION update_nutritional_trends(
    pet_uuid UUID,
    p_trend_date DATE  -- Renamed parameter to avoid ambiguity with table column
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
    AND DATE(fr.feeding_time) = p_trend_date;  -- Use renamed parameter
    
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
    AND DATE(fr.feeding_time) = p_trend_date;  -- Use renamed parameter
    
    -- Calculate weight change (difference from previous day)
    SELECT COALESCE(
        (SELECT weight_kg FROM public.pet_weight_records 
         WHERE pet_id = pet_uuid 
         AND DATE(recorded_at) = p_trend_date  -- Use renamed parameter
         ORDER BY recorded_at DESC LIMIT 1) -
        (SELECT weight_kg FROM public.pet_weight_records 
         WHERE pet_id = pet_uuid 
         AND DATE(recorded_at) < p_trend_date  -- Use renamed parameter
         ORDER BY recorded_at DESC LIMIT 1),
        0.0
    )
    INTO v_weight_change;
    
    -- Only create/update trend if there are feeding records for this date
    IF v_feeding_count > 0 THEN
        -- Check if trend record already exists
        -- FIXED: Use renamed parameter p_trend_date to avoid all ambiguity
        SELECT id INTO v_trend_id
        FROM public.nutritional_trends nt
        WHERE nt.pet_id = pet_uuid AND nt.trend_date = p_trend_date;  -- Use renamed parameter
        
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
                p_trend_date,  -- Use renamed parameter
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

-- Verify the function was created
SELECT 'Function update_nutritional_trends has been updated successfully!' as status;

