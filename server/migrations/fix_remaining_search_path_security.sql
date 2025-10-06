-- Migration: Fix Remaining Function Search Path Security Warnings
-- Sets search_path parameter on functions to prevent SQL injection attacks
-- This addresses Supabase Security Advisor warnings for:
-- - calculate_weight_trend
-- - update_nutritional_trends  
-- - update_updated_at_column

-- 1. Fix calculate_weight_trend function
CREATE OR REPLACE FUNCTION calculate_weight_trend(pet_uuid UUID, days_back INTEGER DEFAULT 30)
RETURNS TABLE (
    trend_direction VARCHAR(10),
    weight_change_kg DECIMAL(5,2),
    average_daily_change DECIMAL(5,2),
    trend_strength VARCHAR(10)
) AS $$
DECLARE
    current_weight DECIMAL(5,2);
    old_weight DECIMAL(5,2);
    weight_change DECIMAL(5,2);
    daily_change DECIMAL(5,2);
BEGIN
    -- Get most recent weight
    SELECT weight_kg INTO current_weight
    FROM pet_weight_records
    WHERE pet_id = pet_uuid
    ORDER BY recorded_at DESC
    LIMIT 1;
    
    -- Get weight from days_back ago
    SELECT weight_kg INTO old_weight
    FROM pet_weight_records
    WHERE pet_id = pet_uuid
    AND recorded_at <= NOW() - INTERVAL '1 day' * days_back
    ORDER BY recorded_at DESC
    LIMIT 1;
    
    -- Calculate trend
    IF current_weight IS NULL OR old_weight IS NULL THEN
        RETURN;
    END IF;
    
    weight_change := current_weight - old_weight;
    daily_change := weight_change / days_back;
    
    RETURN QUERY SELECT
        CASE 
            WHEN weight_change > 0.5 THEN 'increasing'
            WHEN weight_change < -0.5 THEN 'decreasing'
            ELSE 'stable'
        END as trend_direction,
        weight_change,
        daily_change,
        CASE 
            WHEN ABS(weight_change) > 2.0 THEN 'strong'
            WHEN ABS(weight_change) > 0.5 THEN 'moderate'
            ELSE 'weak'
        END as trend_strength;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public;

-- 2. Fix update_nutritional_trends function
CREATE OR REPLACE FUNCTION update_nutritional_trends(pet_uuid UUID, trend_date DATE)
RETURNS VOID AS $$
DECLARE
    daily_calories DECIMAL(8,2) := 0;
    daily_protein DECIMAL(8,2) := 0;
    daily_fat DECIMAL(8,2) := 0;
    daily_fiber DECIMAL(8,2) := 0;
    feeding_count INTEGER := 0;
    avg_compatibility DECIMAL(5,2) := 0;
    weight_change DECIMAL(5,2) := 0;
BEGIN
    -- Calculate daily nutritional totals from feeding records
    SELECT 
        COALESCE(SUM(fr.amount_grams * fa.calories_per_100g / 100), 0),
        COALESCE(SUM(fr.amount_grams * fa.protein_percentage / 100), 0),
        COALESCE(SUM(fr.amount_grams * fa.fat_percentage / 100), 0),
        COALESCE(SUM(fr.amount_grams * fa.fiber_percentage / 100), 0),
        COUNT(fr.id),
        COALESCE(AVG(nc.score), 0)
    INTO daily_calories, daily_protein, daily_fat, daily_fiber, feeding_count, avg_compatibility
    FROM feeding_records fr
    JOIN food_analysis fa ON fr.food_item_id = fa.food_item_id
    LEFT JOIN nutritional_compatibility nc ON fr.pet_id = nc.pet_id AND fr.food_item_id = nc.food_item_id
    WHERE fr.pet_id = pet_uuid 
    AND DATE(fr.fed_at) = trend_date;
    
    -- Calculate weight change for the day
    SELECT 
        COALESCE(
            (SELECT weight_kg FROM pet_weight_records 
             WHERE pet_id = pet_uuid AND DATE(recorded_at) = trend_date 
             ORDER BY recorded_at DESC LIMIT 1) -
            (SELECT weight_kg FROM pet_weight_records 
             WHERE pet_id = pet_uuid AND DATE(recorded_at) < trend_date 
             ORDER BY recorded_at DESC LIMIT 1), 0
        )
    INTO weight_change;
    
    -- Insert or update nutritional trends record
    INSERT INTO nutritional_trends (
        pet_id,
        trend_date,
        daily_calories,
        daily_protein,
        daily_fat,
        daily_fiber,
        feeding_count,
        avg_compatibility_score,
        weight_change_kg,
        created_at,
        updated_at
    ) VALUES (
        pet_uuid,
        trend_date,
        daily_calories,
        daily_protein,
        daily_fat,
        daily_fiber,
        feeding_count,
        avg_compatibility,
        weight_change,
        NOW(),
        NOW()
    )
    ON CONFLICT (pet_id, trend_date) 
    DO UPDATE SET
        daily_calories = EXCLUDED.daily_calories,
        daily_protein = EXCLUDED.daily_protein,
        daily_fat = EXCLUDED.daily_fat,
        daily_fiber = EXCLUDED.daily_fiber,
        feeding_count = EXCLUDED.feeding_count,
        avg_compatibility_score = EXCLUDED.avg_compatibility_score,
        weight_change_kg = EXCLUDED.weight_change_kg,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public;

-- 3. Fix update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public;

-- Add comments for documentation
COMMENT ON FUNCTION calculate_weight_trend(UUID, INTEGER) IS 
'Calculates weight trend for a pet over specified days. Returns trend direction, weight change, daily change, and trend strength.';

COMMENT ON FUNCTION update_nutritional_trends(UUID, DATE) IS 
'Updates nutritional trends for a pet on a specific date. Calculates daily nutritional totals and weight changes.';

COMMENT ON FUNCTION update_updated_at_column() IS 
'Trigger function to automatically update the updated_at timestamp when records are modified.';
