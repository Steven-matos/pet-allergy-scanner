-- Migration: Add Calorie Goals and Food Items Tables
-- Description: Adds tables for calorie goals management and food items database
-- Date: 2025-01-15

-- Create calorie_goals table
CREATE TABLE IF NOT EXISTS public.calorie_goals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    daily_calories DECIMAL(8,2) NOT NULL CHECK (daily_calories > 0),
    notes TEXT CHECK (LENGTH(notes) <= 500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one goal per pet
    UNIQUE(pet_id)
);

-- Create food_items table
CREATE TABLE IF NOT EXISTS public.food_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 200),
    brand TEXT CHECK (LENGTH(brand) <= 100),
    barcode TEXT CHECK (LENGTH(barcode) <= 50),
    category TEXT CHECK (LENGTH(category) <= 50),
    description TEXT CHECK (LENGTH(description) <= 500),
    
    -- Nutritional information (JSONB for flexibility)
    nutritional_info JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    
    -- Index for barcode lookups (will be created separately)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_calorie_goals_pet_id ON public.calorie_goals(pet_id);
CREATE INDEX IF NOT EXISTS idx_food_items_name ON public.food_items(name);
CREATE INDEX IF NOT EXISTS idx_food_items_brand ON public.food_items(brand);
CREATE INDEX IF NOT EXISTS idx_food_items_category ON public.food_items(category);
CREATE INDEX IF NOT EXISTS idx_food_items_barcode ON public.food_items(barcode);

-- Create partial unique constraint for barcode (only when barcode is not null)
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_items_barcode_unique 
    ON public.food_items(barcode) 
    WHERE barcode IS NOT NULL;

-- Add RLS policies for calorie_goals
ALTER TABLE public.calorie_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own pet's calorie goals" ON public.calorie_goals
    FOR SELECT USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert calorie goals for their pets" ON public.calorie_goals
    FOR INSERT WITH CHECK (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own pet's calorie goals" ON public.calorie_goals
    FOR UPDATE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their own pet's calorie goals" ON public.calorie_goals
    FOR DELETE USING (
        pet_id IN (
            SELECT id FROM public.pets WHERE user_id = auth.uid()
        )
    );

-- Add RLS policies for food_items (read-only for users)
ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all food items" ON public.food_items
    FOR SELECT USING (true);

-- Only authenticated users can manage food items (admin functionality)
CREATE POLICY "Authenticated users can insert food items" ON public.food_items
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update food items" ON public.food_items
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete food items" ON public.food_items
    FOR DELETE USING (auth.role() = 'authenticated');

-- Create updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_calorie_goals_updated_at 
    BEFORE UPDATE ON public.calorie_goals 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_items_updated_at 
    BEFORE UPDATE ON public.food_items 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE public.calorie_goals IS 'Stores daily calorie goals for pets set by users';
COMMENT ON TABLE public.food_items IS 'Database of food items with nutritional information';

COMMENT ON COLUMN public.calorie_goals.daily_calories IS 'Daily calorie goal in kcal';
COMMENT ON COLUMN public.calorie_goals.notes IS 'Optional notes about the calorie goal';

COMMENT ON COLUMN public.food_items.nutritional_info IS 'JSONB containing nutritional information like calories_per_100g, protein_percentage, etc.';
COMMENT ON COLUMN public.food_items.barcode IS 'Barcode/UPC for product identification';
COMMENT ON COLUMN public.food_items.category IS 'Food category (e.g., Dry Food, Wet Food, Treats)';
