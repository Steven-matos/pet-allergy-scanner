-- Debug function to bypass RLS and query feeding_records directly
-- This helps diagnose if RLS or query builder is affecting the calories column
--
-- USAGE: Run this in Supabase SQL Editor to create the function
--
-- To use from Python:
-- result = supabase.rpc('get_feeding_records_raw', {'p_pet_id': 'some-uuid'}).execute()

CREATE OR REPLACE FUNCTION get_feeding_records_raw(p_pet_id UUID)
RETURNS TABLE (
    id UUID,
    pet_id UUID,
    food_analysis_id UUID,
    amount_grams DECIMAL,
    feeding_time TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    calories DECIMAL,
    created_at TIMESTAMP WITH TIME ZONE
) 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fr.id,
        fr.pet_id,
        fr.food_analysis_id,
        fr.amount_grams,
        fr.feeding_time,
        fr.notes,
        fr.calories,
        fr.created_at
    FROM feeding_records fr
    WHERE fr.pet_id = p_pet_id
    ORDER BY fr.created_at DESC
    LIMIT 10;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_feeding_records_raw(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_feeding_records_raw(UUID) TO service_role;
