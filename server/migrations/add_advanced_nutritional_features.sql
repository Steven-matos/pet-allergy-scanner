-- Phase 3: Advanced Nutritional Analysis Features
-- Database schema for weight tracking, trends, and advanced analytics

-- Weight tracking table for pets
CREATE TABLE IF NOT EXISTS pet_weight_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    weight_kg DECIMAL(5,2) NOT NULL CHECK (weight_kg > 0),
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT,
    recorded_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Weight goals for pets
CREATE TABLE IF NOT EXISTS pet_weight_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    goal_type VARCHAR(20) NOT NULL CHECK (goal_type IN ('weight_loss', 'weight_gain', 'maintenance', 'health_improvement')),
    target_weight_kg DECIMAL(5,2),
    current_weight_kg DECIMAL(5,2),
    target_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nutritional trends and analytics
CREATE TABLE IF NOT EXISTS nutritional_trends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    trend_date DATE NOT NULL,
    total_calories DECIMAL(8,2) DEFAULT 0,
    total_protein_g DECIMAL(8,2) DEFAULT 0,
    total_fat_g DECIMAL(8,2) DEFAULT 0,
    total_fiber_g DECIMAL(8,2) DEFAULT 0,
    feeding_count INTEGER DEFAULT 0,
    average_compatibility_score DECIMAL(5,2) DEFAULT 0,
    weight_change_kg DECIMAL(5,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(pet_id, trend_date)
);

-- Food comparison data
CREATE TABLE IF NOT EXISTS food_comparisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comparison_name VARCHAR(200) NOT NULL,
    food_ids UUID[] NOT NULL, -- Array of food analysis IDs
    comparison_data JSONB NOT NULL, -- Comparison metrics and analysis
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Advanced analytics cache
CREATE TABLE IF NOT EXISTS nutritional_analytics_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    analysis_type VARCHAR(50) NOT NULL, -- 'weekly_summary', 'monthly_trends', 'health_insights'
    analysis_data JSONB NOT NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nutritional recommendations based on trends
CREATE TABLE IF NOT EXISTS nutritional_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    recommendation_type VARCHAR(50) NOT NULL, -- 'diet_adjustment', 'feeding_schedule', 'supplement', 'weight_management'
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    category VARCHAR(30) NOT NULL CHECK (category IN ('diet', 'feeding', 'supplement', 'warning', 'weight')),
    is_active BOOLEAN DEFAULT TRUE,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_pet_id ON pet_weight_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_at ON pet_weight_records(recorded_at);
CREATE INDEX IF NOT EXISTS idx_pet_weight_goals_pet_id ON pet_weight_goals(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_weight_goals_active ON pet_weight_goals(pet_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_nutritional_trends_pet_date ON nutritional_trends(pet_id, trend_date);
CREATE INDEX IF NOT EXISTS idx_food_comparisons_user_id ON food_comparisons(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_pet_type ON nutritional_analytics_cache(pet_id, analysis_type);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_expires ON nutritional_analytics_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_nutritional_recommendations_pet_id ON nutritional_recommendations(pet_id);
CREATE INDEX IF NOT EXISTS idx_nutritional_recommendations_active ON nutritional_recommendations(pet_id, is_active) WHERE is_active = TRUE;

-- RLS policies for security
ALTER TABLE pet_weight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_weight_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutritional_trends ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutritional_analytics_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutritional_recommendations ENABLE ROW LEVEL SECURITY;

-- Weight records policies
CREATE POLICY "Users can view their pet weight records" ON pet_weight_records
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert their pet weight records" ON pet_weight_records
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their pet weight records" ON pet_weight_records
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their pet weight records" ON pet_weight_records
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

-- Weight goals policies
CREATE POLICY "Users can view their pet weight goals" ON pet_weight_goals
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can manage their pet weight goals" ON pet_weight_goals
    FOR ALL USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

-- Nutritional trends policies
CREATE POLICY "Users can view their pet nutritional trends" ON nutritional_trends
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "System can manage nutritional trends" ON nutritional_trends
    FOR ALL USING (true); -- System service account

-- Food comparisons policies
CREATE POLICY "Users can manage their food comparisons" ON food_comparisons
    FOR ALL USING (user_id = auth.uid());

-- Analytics cache policies
CREATE POLICY "Users can view their pet analytics" ON nutritional_analytics_cache
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "System can manage analytics cache" ON nutritional_analytics_cache
    FOR ALL USING (true); -- System service account

-- Recommendations policies
CREATE POLICY "Users can view their pet recommendations" ON nutritional_recommendations
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "System can manage recommendations" ON nutritional_recommendations
    FOR ALL USING (true); -- System service account

-- Functions for automatic weight trend calculations
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
$$ LANGUAGE plpgsql;

-- Function to update nutritional trends
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
    JOIN food_analyses fa ON fr.food_analysis_id = fa.id
    LEFT JOIN nutrition_compatibilities nc ON fa.id = nc.food_analysis_id
    WHERE fr.pet_id = pet_uuid
    AND DATE(fr.feeding_time) = trend_date;
    
    -- Calculate weight change from previous day
    SELECT 
        COALESCE(
            (SELECT weight_kg FROM pet_weight_records 
             WHERE pet_id = pet_uuid AND DATE(recorded_at) = trend_date 
             ORDER BY recorded_at DESC LIMIT 1) -
            (SELECT weight_kg FROM pet_weight_records 
             WHERE pet_id = pet_uuid AND DATE(recorded_at) = trend_date - INTERVAL '1 day' 
             ORDER BY recorded_at DESC LIMIT 1), 0
        )
    INTO weight_change;
    
    -- Insert or update trend record
    INSERT INTO nutritional_trends (
        pet_id, trend_date, total_calories, total_protein_g, 
        total_fat_g, total_fiber_g, feeding_count, 
        average_compatibility_score, weight_change_kg
    ) VALUES (
        pet_uuid, trend_date, daily_calories, daily_protein,
        daily_fat, daily_fiber, feeding_count,
        avg_compatibility, weight_change
    )
    ON CONFLICT (pet_id, trend_date) 
    DO UPDATE SET
        total_calories = EXCLUDED.total_calories,
        total_protein_g = EXCLUDED.total_protein_g,
        total_fat_g = EXCLUDED.total_fat_g,
        total_fiber_g = EXCLUDED.total_fiber_g,
        feeding_count = EXCLUDED.feeding_count,
        average_compatibility_score = EXCLUDED.average_compatibility_score,
        weight_change_kg = EXCLUDED.weight_change_kg,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE pet_weight_records IS 'Tracks pet weight measurements over time for weight management';
COMMENT ON TABLE pet_weight_goals IS 'Stores weight management goals and targets for pets';
COMMENT ON TABLE nutritional_trends IS 'Daily aggregated nutritional data for trend analysis';
COMMENT ON TABLE food_comparisons IS 'Stores food comparison analyses and metrics';
COMMENT ON TABLE nutritional_analytics_cache IS 'Cached analytics data for performance optimization';
COMMENT ON TABLE nutritional_recommendations IS 'AI-generated nutritional recommendations based on trends';
