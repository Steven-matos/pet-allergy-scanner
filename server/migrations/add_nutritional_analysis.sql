-- Add nutritional analysis support to scans table
-- This migration adds comprehensive nutritional analysis capabilities

-- Add nutritional_analysis JSONB field to scans table
ALTER TABLE public.scans 
ADD COLUMN IF NOT EXISTS nutritional_analysis JSONB;

-- Add index for nutritional analysis queries
CREATE INDEX IF NOT EXISTS idx_scans_nutritional_analysis 
ON public.scans USING GIN (nutritional_analysis);

-- Create nutritional_standards table for species-specific requirements
CREATE TABLE IF NOT EXISTS public.nutritional_standards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat')),
    life_stage TEXT NOT NULL CHECK (life_stage IN ('puppy', 'adult', 'senior', 'pregnant', 'lactating')),
    weight_range_min DECIMAL(5,2) NOT NULL CHECK (weight_range_min >= 0.1),
    weight_range_max DECIMAL(5,2) NOT NULL CHECK (weight_range_max >= weight_range_min),
    activity_level TEXT DEFAULT 'moderate' CHECK (activity_level IN ('low', 'moderate', 'high')),
    calories_per_kg DECIMAL(6,2) NOT NULL CHECK (calories_per_kg > 0),
    protein_min_percent DECIMAL(5,2) NOT NULL CHECK (protein_min_percent >= 0 AND protein_min_percent <= 100),
    fat_min_percent DECIMAL(5,2) NOT NULL CHECK (fat_min_percent >= 0 AND fat_min_percent <= 100),
    fiber_max_percent DECIMAL(5,2) NOT NULL CHECK (fiber_max_percent >= 0 AND fiber_max_percent <= 100),
    moisture_max_percent DECIMAL(5,2) NOT NULL CHECK (moisture_max_percent >= 0 AND moisture_max_percent <= 100),
    ash_max_percent DECIMAL(5,2) NOT NULL CHECK (ash_max_percent >= 0 AND ash_max_percent <= 100),
    calcium_min_percent DECIMAL(5,2) CHECK (calcium_min_percent >= 0 AND calcium_min_percent <= 100),
    phosphorus_min_percent DECIMAL(5,2) CHECK (phosphorus_min_percent >= 0 AND phosphorus_min_percent <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(species, life_stage, weight_range_min, weight_range_max, activity_level)
);

-- Add index for nutritional standards queries
CREATE INDEX IF NOT EXISTS idx_nutritional_standards_species_life_stage 
ON public.nutritional_standards(species, life_stage);

-- Add trigger for nutritional_standards updated_at
CREATE TRIGGER update_nutritional_standards_updated_at 
BEFORE UPDATE ON public.nutritional_standards
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS for nutritional_standards
ALTER TABLE public.nutritional_standards ENABLE ROW LEVEL SECURITY;

-- Nutritional standards are public (read-only for users)
CREATE POLICY "Anyone can view nutritional standards" ON public.nutritional_standards
FOR SELECT USING (true);

-- Insert AAFCO nutritional standards data
INSERT INTO public.nutritional_standards (
    species, life_stage, weight_range_min, weight_range_max, activity_level,
    calories_per_kg, protein_min_percent, fat_min_percent, fiber_max_percent,
    moisture_max_percent, ash_max_percent, calcium_min_percent, phosphorus_min_percent
) VALUES
-- Dog standards
('dog', 'puppy', 0.5, 5.0, 'moderate', 200, 22.0, 8.0, 5.0, 78.0, 6.0, 1.0, 0.8),
('dog', 'puppy', 5.0, 15.0, 'moderate', 180, 20.0, 8.0, 5.0, 78.0, 6.0, 1.0, 0.8),
('dog', 'puppy', 15.0, 30.0, 'moderate', 160, 18.0, 8.0, 5.0, 78.0, 6.0, 1.0, 0.8),
('dog', 'adult', 5.0, 25.0, 'low', 120, 18.0, 5.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('dog', 'adult', 5.0, 25.0, 'moderate', 140, 18.0, 5.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('dog', 'adult', 5.0, 25.0, 'high', 180, 18.0, 5.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('dog', 'senior', 5.0, 25.0, 'low', 100, 18.0, 5.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('dog', 'senior', 5.0, 25.0, 'moderate', 120, 18.0, 5.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('dog', 'pregnant', 5.0, 25.0, 'moderate', 200, 22.0, 8.0, 4.0, 78.0, 6.0, 1.0, 0.8),
('dog', 'lactating', 5.0, 25.0, 'high', 300, 22.0, 8.0, 4.0, 78.0, 6.0, 1.0, 0.8),

-- Cat standards
('cat', 'puppy', 0.5, 2.0, 'moderate', 250, 30.0, 9.0, 4.0, 78.0, 6.0, 1.0, 0.8),
('cat', 'puppy', 2.0, 4.0, 'moderate', 200, 26.0, 9.0, 4.0, 78.0, 6.0, 1.0, 0.8),
('cat', 'adult', 2.0, 8.0, 'low', 120, 26.0, 9.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('cat', 'adult', 2.0, 8.0, 'moderate', 140, 26.0, 9.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('cat', 'adult', 2.0, 8.0, 'high', 180, 26.0, 9.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('cat', 'senior', 2.0, 8.0, 'low', 100, 26.0, 9.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('cat', 'senior', 2.0, 8.0, 'moderate', 120, 26.0, 9.0, 4.0, 78.0, 6.0, 0.6, 0.5),
('cat', 'pregnant', 2.0, 8.0, 'moderate', 250, 30.0, 9.0, 4.0, 78.0, 6.0, 1.0, 0.8),
('cat', 'lactating', 2.0, 8.0, 'high', 350, 30.0, 9.0, 4.0, 78.0, 6.0, 1.0, 0.8)
ON CONFLICT (species, life_stage, weight_range_min, weight_range_max, activity_level) DO NOTHING;

-- Update ingredients table to enhance nutritional_value structure
-- Add comment to clarify the expected JSONB structure
COMMENT ON COLUMN public.ingredients.nutritional_value IS 'JSONB containing nutritional data: {"calories_per_100g": "350", "protein_percent": "25.0", "fat_percent": "12.0", "fiber_percent": "3.0", "moisture_percent": "10.0", "ash_percent": "6.0", "calcium_percent": "1.2", "phosphorus_percent": "0.8"}';

-- Add comment to clarify the nutritional_analysis JSONB structure
COMMENT ON COLUMN public.scans.nutritional_analysis IS 'JSONB containing complete nutritional analysis: {"serving_size_g": 100, "calories_per_serving": 350, "calories_per_100g": 350, "macronutrients": {"protein_percent": 25.0, "fat_percent": 12.0, "fiber_percent": 3.0, "moisture_percent": 10.0, "ash_percent": 6.0}, "minerals": {"calcium_percent": 1.2, "phosphorus_percent": 0.8}, "recommendations": {"suitable_for_pet": true, "daily_servings": 2.5, "calorie_contribution_percent": 15.0}}';
