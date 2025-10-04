-- Add nutrition-related tables for pet nutrition tracking
-- This migration adds comprehensive nutrition tracking capabilities

-- Create nutritional_requirements table
CREATE TABLE IF NOT EXISTS public.nutritional_requirements (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    daily_calories DECIMAL(10,2) NOT NULL CHECK (daily_calories > 0),
    protein_percentage DECIMAL(5,2) NOT NULL CHECK (protein_percentage >= 0 AND protein_percentage <= 100),
    fat_percentage DECIMAL(5,2) NOT NULL CHECK (fat_percentage >= 0 AND fat_percentage <= 100),
    fiber_percentage DECIMAL(5,2) NOT NULL CHECK (fiber_percentage >= 0 AND fiber_percentage <= 100),
    moisture_percentage DECIMAL(5,2) NOT NULL CHECK (moisture_percentage >= 0 AND moisture_percentage <= 100),
    life_stage TEXT NOT NULL CHECK (life_stage IN ('puppy', 'adult', 'senior', 'pregnant', 'lactating')),
    activity_level TEXT NOT NULL CHECK (activity_level IN ('low', 'moderate', 'high')),
    calculated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(pet_id) -- Each pet can only have one set of requirements
);

-- Create food_analyses table
CREATE TABLE IF NOT EXISTS public.food_analyses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    food_name TEXT NOT NULL CHECK (LENGTH(food_name) > 0 AND LENGTH(food_name) <= 200),
    brand TEXT CHECK (LENGTH(brand) <= 100),
    calories_per_100g DECIMAL(8,2) NOT NULL CHECK (calories_per_100g >= 0),
    protein_percentage DECIMAL(5,2) NOT NULL CHECK (protein_percentage >= 0 AND protein_percentage <= 100),
    fat_percentage DECIMAL(5,2) NOT NULL CHECK (fat_percentage >= 0 AND fat_percentage <= 100),
    fiber_percentage DECIMAL(5,2) NOT NULL CHECK (fiber_percentage >= 0 AND fiber_percentage <= 100),
    moisture_percentage DECIMAL(5,2) NOT NULL CHECK (moisture_percentage >= 0 AND moisture_percentage <= 100),
    ingredients TEXT[] DEFAULT '{}',
    allergens TEXT[] DEFAULT '{}',
    analyzed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create feeding_records table
CREATE TABLE IF NOT EXISTS public.feeding_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    food_analysis_id UUID REFERENCES public.food_analyses(id) ON DELETE CASCADE NOT NULL,
    amount_grams DECIMAL(8,2) NOT NULL CHECK (amount_grams > 0),
    feeding_time TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT CHECK (LENGTH(notes) <= 500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create daily_nutrition_summaries table
CREATE TABLE IF NOT EXISTS public.daily_nutrition_summaries (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    total_calories DECIMAL(10,2) NOT NULL CHECK (total_calories >= 0),
    total_protein DECIMAL(10,2) NOT NULL CHECK (total_protein >= 0),
    total_fat DECIMAL(10,2) NOT NULL CHECK (total_fat >= 0),
    total_fiber DECIMAL(10,2) NOT NULL CHECK (total_fiber >= 0),
    feeding_count INTEGER NOT NULL CHECK (feeding_count >= 0),
    average_compatibility DECIMAL(5,2) NOT NULL CHECK (average_compatibility >= 0 AND average_compatibility <= 100),
    recommendations TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(pet_id, date) -- One summary per pet per day
);

-- Create nutrition_recommendations table
CREATE TABLE IF NOT EXISTS public.nutrition_recommendations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL CHECK (LENGTH(title) > 0),
    description TEXT NOT NULL CHECK (LENGTH(description) > 0),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    category TEXT NOT NULL CHECK (category IN ('diet', 'feeding', 'supplement', 'warning')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create nutrition_goals table
CREATE TABLE IF NOT EXISTS public.nutrition_goals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    goal_type TEXT NOT NULL CHECK (goal_type IN ('weight_loss', 'weight_gain', 'maintenance', 'health_improvement')),
    target_value DECIMAL(8,2),
    current_value DECIMAL(8,2),
    target_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT CHECK (LENGTH(notes) <= 1000),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_nutritional_requirements_pet_id ON public.nutritional_requirements(pet_id);
CREATE INDEX IF NOT EXISTS idx_food_analyses_pet_id ON public.food_analyses(pet_id);
CREATE INDEX IF NOT EXISTS idx_food_analyses_analyzed_at ON public.food_analyses(analyzed_at DESC);
CREATE INDEX IF NOT EXISTS idx_feeding_records_pet_id ON public.feeding_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_feeding_records_feeding_time ON public.feeding_records(feeding_time DESC);
CREATE INDEX IF NOT EXISTS idx_feeding_records_food_analysis_id ON public.feeding_records(food_analysis_id);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_pet_id ON public.daily_nutrition_summaries(pet_id);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_date ON public.daily_nutrition_summaries(date DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_recommendations_pet_id ON public.nutrition_recommendations(pet_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_recommendations_priority ON public.nutrition_recommendations(priority);
CREATE INDEX IF NOT EXISTS idx_nutrition_goals_pet_id ON public.nutrition_goals(pet_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_goals_goal_type ON public.nutrition_goals(goal_type);

-- Enable Row Level Security (RLS) for all nutrition tables
ALTER TABLE public.nutritional_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feeding_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_nutrition_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_goals ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for nutritional_requirements
CREATE POLICY "Users can view their own pets' nutritional requirements" ON public.nutritional_requirements
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create nutritional requirements for their pets" ON public.nutritional_requirements
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their pets' nutritional requirements" ON public.nutritional_requirements
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their pets' nutritional requirements" ON public.nutritional_requirements
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create RLS policies for food_analyses
CREATE POLICY "Users can view food analyses for their pets" ON public.food_analyses
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create food analyses for their pets" ON public.food_analyses
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update food analyses for their pets" ON public.food_analyses
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete food analyses for their pets" ON public.food_analyses
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create RLS policies for feeding_records
CREATE POLICY "Users can view feeding records for their pets" ON public.feeding_records
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create feeding records for their pets" ON public.feeding_records
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update feeding records for their pets" ON public.feeding_records
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete feeding records for their pets" ON public.feeding_records
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create RLS policies for daily_nutrition_summaries
CREATE POLICY "Users can view daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create RLS policies for nutrition_recommendations
CREATE POLICY "Users can view nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create RLS policies for nutrition_goals
CREATE POLICY "Users can view nutrition goals for their pets" ON public.nutrition_goals
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create nutrition goals for their pets" ON public.nutrition_goals
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update nutrition goals for their pets" ON public.nutrition_goals
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete nutrition goals for their pets" ON public.nutrition_goals
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_nutritional_requirements_updated_at
    BEFORE UPDATE ON public.nutritional_requirements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_analyses_updated_at
    BEFORE UPDATE ON public.food_analyses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_nutrition_summaries_updated_at
    BEFORE UPDATE ON public.daily_nutrition_summaries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_nutrition_goals_updated_at
    BEFORE UPDATE ON public.nutrition_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE public.nutritional_requirements IS 'Stores calculated nutritional requirements for each pet based on age, weight, activity level, and life stage';
COMMENT ON TABLE public.food_analyses IS 'Stores nutritional analysis of pet foods including macronutrients and allergen information';
COMMENT ON TABLE public.feeding_records IS 'Tracks individual feeding instances with amount and timing';
COMMENT ON TABLE public.daily_nutrition_summaries IS 'Aggregated daily nutrition data for each pet';
COMMENT ON TABLE public.nutrition_recommendations IS 'Stores personalized nutrition recommendations for pets';
COMMENT ON TABLE public.nutrition_goals IS 'Tracks nutrition-related health goals for pets';

COMMENT ON COLUMN public.nutritional_requirements.daily_calories IS 'Calculated daily calorie requirement based on pet characteristics';
COMMENT ON COLUMN public.nutritional_requirements.protein_percentage IS 'Recommended protein percentage for the pet''s life stage';
COMMENT ON COLUMN public.nutritional_requirements.fat_percentage IS 'Recommended fat percentage for the pet''s life stage';
COMMENT ON COLUMN public.nutritional_requirements.fiber_percentage IS 'Recommended fiber percentage for the pet''s life stage';
COMMENT ON COLUMN public.nutritional_requirements.moisture_percentage IS 'Recommended moisture percentage (typically 10%)';

COMMENT ON COLUMN public.food_analyses.calories_per_100g IS 'Calorie content per 100 grams of food';
COMMENT ON COLUMN public.food_analyses.protein_percentage IS 'Protein percentage in the food';
COMMENT ON COLUMN public.food_analyses.fat_percentage IS 'Fat percentage in the food';
COMMENT ON COLUMN public.food_analyses.fiber_percentage IS 'Fiber percentage in the food';
COMMENT ON COLUMN public.food_analyses.moisture_percentage IS 'Moisture percentage in the food';
COMMENT ON COLUMN public.food_analyses.ingredients IS 'Array of ingredient names in the food';
COMMENT ON COLUMN public.food_analyses.allergens IS 'Array of identified allergens in the food';

COMMENT ON COLUMN public.feeding_records.amount_grams IS 'Amount of food fed in grams';
COMMENT ON COLUMN public.feeding_records.feeding_time IS 'Timestamp when the feeding occurred';

COMMENT ON COLUMN public.daily_nutrition_summaries.total_calories IS 'Total calories consumed on this date';
COMMENT ON COLUMN public.daily_nutrition_summaries.total_protein IS 'Total protein consumed in grams';
COMMENT ON COLUMN public.daily_nutrition_summaries.total_fat IS 'Total fat consumed in grams';
COMMENT ON COLUMN public.daily_nutrition_summaries.total_fiber IS 'Total fiber consumed in grams';
COMMENT ON COLUMN public.daily_nutrition_summaries.feeding_count IS 'Number of feeding instances on this date';
COMMENT ON COLUMN public.daily_nutrition_summaries.average_compatibility IS 'Average nutrition compatibility score for the day';

COMMENT ON COLUMN public.nutrition_recommendations.priority IS 'Priority level: low, medium, high, or critical';
COMMENT ON COLUMN public.nutrition_recommendations.category IS 'Category: diet, feeding, supplement, or warning';

COMMENT ON COLUMN public.nutrition_goals.goal_type IS 'Type of goal: weight_loss, weight_gain, maintenance, or health_improvement';
COMMENT ON COLUMN public.nutrition_goals.target_value IS 'Target value for the goal (e.g., target weight)';
COMMENT ON COLUMN public.nutrition_goals.current_value IS 'Current value (e.g., current weight)';
COMMENT ON COLUMN public.nutrition_goals.target_date IS 'Target date for achieving the goal';
