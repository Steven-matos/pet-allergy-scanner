-- =============================================================================
-- COMPLETE DATABASE SCHEMA - SniffTest Pet Allergy Scanner
-- =============================================================================
-- This is the single source of truth for the complete database schema
-- Run this ONCE in Supabase SQL Editor for fresh installations
-- Created: 2025-01-15
-- Updated: 2025-01-15

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- CORE TABLES
-- =============================================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE,
    first_name TEXT,
    last_name TEXT,
    role TEXT DEFAULT 'free' CHECK (role IN ('free', 'premium')),
    onboarded BOOLEAN DEFAULT FALSE,
    device_token TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pets table
CREATE TABLE IF NOT EXISTS public.pets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,    name TEXT NOT NULL CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 100),
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat')),
    breed TEXT,
    birthday DATE,
    weight_kg DECIMAL(5,2) CHECK (weight_kg >= 0.1 AND weight_kg <= 200.0),
    activity_level TEXT CHECK (activity_level IN ('low', 'moderate', 'high')),
    known_sensitivities TEXT[] DEFAULT '{}',
    vet_name TEXT,
    vet_phone TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ingredients table
CREATE TABLE IF NOT EXISTS public.ingredients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 200),
    aliases TEXT[] DEFAULT '{}',
    safety_level TEXT DEFAULT 'unknown' CHECK (safety_level IN ('safe', 'caution', 'unsafe', 'unknown')),
    species_compatibility TEXT DEFAULT 'both' CHECK (species_compatibility IN ('dog_only', 'cat_only', 'both', 'neither')),
    description TEXT,
    common_allergen BOOLEAN DEFAULT FALSE,
    nutritional_value JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Scans table
CREATE TABLE IF NOT EXISTS public.scans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT,
    raw_text TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Favorites table
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    product_name TEXT NOT NULL,
    brand TEXT,
    ingredients TEXT[],
    safety_status TEXT CHECK (safety_status IN ('safe', 'caution', 'unsafe')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, pet_id, product_name, brand)
);

-- =============================================================================
-- FOOD ITEMS TABLE (Pet Food Database)
-- =============================================================================

-- Food items table (comprehensive pet food database)
CREATE TABLE IF NOT EXISTS public.food_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 200),
    brand TEXT CHECK (LENGTH(brand) <= 100),
    barcode TEXT UNIQUE CHECK (LENGTH(barcode) <= 50),
    category TEXT CHECK (LENGTH(category) <= 50),
    species TEXT CHECK (species IN ('dog', 'cat', 'both', 'unknown')),
    life_stage TEXT CHECK (life_stage IN ('puppy', 'kitten', 'adult', 'senior', 'all', 'unknown')),
    product_type TEXT CHECK (product_type IN ('dry', 'wet', 'treat', 'supplement', 'unknown')),
    quantity TEXT,
    quantity_value DECIMAL(10,2),
    quantity_unit TEXT,
    country TEXT,
    language TEXT DEFAULT 'en',
    image_url TEXT,
    ingredients_image_url TEXT,
    nutrition_image_url TEXT,
    data_completeness DECIMAL(3,2) CHECK (data_completeness >= 0 AND data_completeness <= 1),
    last_updated_external TIMESTAMP WITH TIME ZONE,
    external_source TEXT DEFAULT 'openpetfoodfacts',
    external_id TEXT,
    keywords TEXT[],
    categories_hierarchy TEXT[],
    brands_hierarchy TEXT[],
    allergens_hierarchy TEXT[],
    additives_tags TEXT[],
    vitamins_tags TEXT[],
    minerals_tags TEXT[],
    nova_group INTEGER,
    nutrition_grade TEXT,
    nutrient_levels JSONB DEFAULT '{}',
    packaging_info JSONB DEFAULT '{}',
    manufacturing_info JSONB DEFAULT '{}',
    nutritional_info JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- NUTRITION TABLES
-- =============================================================================

-- Nutritional requirements table
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
    UNIQUE(pet_id)
);

-- Food analyses table
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

-- Feeding records table
CREATE TABLE IF NOT EXISTS public.feeding_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    food_analysis_id UUID REFERENCES public.food_analyses(id) ON DELETE CASCADE NOT NULL,
    amount_grams DECIMAL(8,2) NOT NULL CHECK (amount_grams > 0),
    feeding_time TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT CHECK (LENGTH(notes) <= 500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Daily nutrition summaries table
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
    UNIQUE(pet_id, date)
);

-- Nutrition recommendations table
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

-- Nutrition goals table
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

-- =============================================================================
-- ADVANCED NUTRITION TABLES
-- =============================================================================

-- Pet weight records table
CREATE TABLE IF NOT EXISTS public.pet_weight_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    weight_kg DECIMAL(5,2) NOT NULL CHECK (weight_kg > 0),
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT,
    recorded_by_user_id UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pet weight goals table
CREATE TABLE IF NOT EXISTS public.pet_weight_goals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    goal_type TEXT NOT NULL CHECK (goal_type IN ('weight_loss', 'weight_gain', 'maintenance', 'health_improvement')),
    target_weight_kg DECIMAL(5,2),
    current_weight_kg DECIMAL(5,2),
    target_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nutritional trends table
CREATE TABLE IF NOT EXISTS public.nutritional_trends (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
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

-- Food comparisons table
CREATE TABLE IF NOT EXISTS public.food_comparisons (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    comparison_name TEXT NOT NULL,
    food_ids UUID[] NOT NULL,
    comparison_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nutritional analytics cache table
CREATE TABLE IF NOT EXISTS public.nutritional_analytics_cache (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pet_id UUID REFERENCES public.pets(id) ON DELETE CASCADE NOT NULL,
    analysis_type TEXT NOT NULL,
    analysis_data JSONB NOT NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Core table indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_user_id ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_pet_id ON public.scans(pet_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_pet_id ON public.favorites(pet_id);

-- Food items table indexes
CREATE INDEX IF NOT EXISTS idx_food_items_name ON public.food_items(name);
CREATE INDEX IF NOT EXISTS idx_food_items_brand ON public.food_items(brand);
CREATE INDEX IF NOT EXISTS idx_food_items_barcode ON public.food_items(barcode);
CREATE INDEX IF NOT EXISTS idx_food_items_category ON public.food_items(category);
CREATE INDEX IF NOT EXISTS idx_food_items_species ON public.food_items(species);
CREATE INDEX IF NOT EXISTS idx_food_items_life_stage ON public.food_items(life_stage);
CREATE INDEX IF NOT EXISTS idx_food_items_product_type ON public.food_items(product_type);
CREATE INDEX IF NOT EXISTS idx_food_items_country ON public.food_items(country);
CREATE INDEX IF NOT EXISTS idx_food_items_language ON public.food_items(language);
CREATE INDEX IF NOT EXISTS idx_food_items_external_id ON public.food_items(external_id);
CREATE INDEX IF NOT EXISTS idx_food_items_external_source ON public.food_items(external_source);
CREATE INDEX IF NOT EXISTS idx_food_items_nova_group ON public.food_items(nova_group);
CREATE INDEX IF NOT EXISTS idx_food_items_nutrition_grade ON public.food_items(nutrition_grade);

-- GIN indexes for array fields
CREATE INDEX IF NOT EXISTS idx_food_items_keywords ON public.food_items USING GIN (keywords);
CREATE INDEX IF NOT EXISTS idx_food_items_categories_hierarchy ON public.food_items USING GIN (categories_hierarchy);
CREATE INDEX IF NOT EXISTS idx_food_items_brands_hierarchy ON public.food_items USING GIN (brands_hierarchy);
CREATE INDEX IF NOT EXISTS idx_food_items_allergens_hierarchy ON public.food_items USING GIN (allergens_hierarchy);
CREATE INDEX IF NOT EXISTS idx_food_items_additives_tags ON public.food_items USING GIN (additives_tags);
CREATE INDEX IF NOT EXISTS idx_food_items_vitamins_tags ON public.food_items USING GIN (vitamins_tags);
CREATE INDEX IF NOT EXISTS idx_food_items_minerals_tags ON public.food_items USING GIN (minerals_tags);

-- GIN indexes for JSONB fields
CREATE INDEX IF NOT EXISTS idx_food_items_nutrient_levels ON public.food_items USING GIN (nutrient_levels);
CREATE INDEX IF NOT EXISTS idx_food_items_packaging_info ON public.food_items USING GIN (packaging_info);
CREATE INDEX IF NOT EXISTS idx_food_items_manufacturing_info ON public.food_items USING GIN (manufacturing_info);
CREATE INDEX IF NOT EXISTS idx_food_items_nutritional_info ON public.food_items USING GIN (nutritional_info);

-- Nutrition table indexes
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

-- Advanced nutrition indexes
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_pet_id ON public.pet_weight_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_at ON public.pet_weight_records(recorded_at);
CREATE INDEX IF NOT EXISTS idx_pet_weight_records_recorded_by_user_id ON public.pet_weight_records(recorded_by_user_id);
CREATE INDEX IF NOT EXISTS idx_pet_weight_goals_pet_id ON public.pet_weight_goals(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_weight_goals_active ON public.pet_weight_goals(pet_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_nutritional_trends_pet_date ON public.nutritional_trends(pet_id, trend_date);
CREATE INDEX IF NOT EXISTS idx_food_comparisons_user_id ON public.food_comparisons(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_pet_type ON public.nutritional_analytics_cache(pet_id, analysis_type);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_expires ON public.nutritional_analytics_cache(expires_at);

-- =============================================================================
-- TRIGGERS AND FUNCTIONS
-- =============================================================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER SET search_path = public;

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pets_updated_at BEFORE UPDATE ON public.pets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ingredients_updated_at BEFORE UPDATE ON public.ingredients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scans_updated_at BEFORE UPDATE ON public.scans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_favorites_updated_at BEFORE UPDATE ON public.favorites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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

CREATE TRIGGER update_pet_weight_records_updated_at
    BEFORE UPDATE ON public.pet_weight_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pet_weight_goals_updated_at
    BEFORE UPDATE ON public.pet_weight_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_nutritional_trends_updated_at
    BEFORE UPDATE ON public.nutritional_trends
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_comparisons_updated_at
    BEFORE UPDATE ON public.food_comparisons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_food_items_updated_at
    BEFORE UPDATE ON public.food_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutritional_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feeding_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_nutrition_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_weight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_weight_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutritional_trends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutritional_analytics_cache ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING ((SELECT auth.uid()) = id);

-- Pets policies
CREATE POLICY "Users can view own pets" ON public.pets
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own pets" ON public.pets
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own pets" ON public.pets
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own pets" ON public.pets
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- Scans policies
CREATE POLICY "Users can view own scans" ON public.scans
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own scans" ON public.scans
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own scans" ON public.scans
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own scans" ON public.scans
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- Favorites policies
CREATE POLICY "Users can view own favorites" ON public.favorites
    FOR SELECT USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own favorites" ON public.favorites
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own favorites" ON public.favorites
    FOR UPDATE USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own favorites" ON public.favorites
    FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- Ingredients are public (read-only for users)
CREATE POLICY "Anyone can view ingredients" ON public.ingredients
    FOR SELECT USING (true);

-- Food items are public (read-only for users)
CREATE POLICY "Anyone can view food items" ON public.food_items
    FOR SELECT USING (true);

-- Nutrition policies (all follow same pattern - users can only access their own pets' data)
CREATE POLICY "Users can view their pets' nutritional requirements" ON public.nutritional_requirements
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create nutritional requirements for their pets" ON public.nutritional_requirements
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update their pets' nutritional requirements" ON public.nutritional_requirements
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete their pets' nutritional requirements" ON public.nutritional_requirements
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Food analyses policies
CREATE POLICY "Users can view food analyses for their pets" ON public.food_analyses
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create food analyses for their pets" ON public.food_analyses
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update food analyses for their pets" ON public.food_analyses
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete food analyses for their pets" ON public.food_analyses
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Feeding records policies
CREATE POLICY "Users can view feeding records for their pets" ON public.feeding_records
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create feeding records for their pets" ON public.feeding_records
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update feeding records for their pets" ON public.feeding_records
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete feeding records for their pets" ON public.feeding_records
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Daily summaries policies
CREATE POLICY "Users can view daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete daily summaries for their pets" ON public.daily_nutrition_summaries
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Nutrition recommendations policies
CREATE POLICY "Users can view nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete nutrition recommendations for their pets" ON public.nutrition_recommendations
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Nutrition goals policies
CREATE POLICY "Users can view nutrition goals for their pets" ON public.nutrition_goals
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can create nutrition goals for their pets" ON public.nutrition_goals
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update nutrition goals for their pets" ON public.nutrition_goals
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete nutrition goals for their pets" ON public.nutrition_goals
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Pet weight records policies
CREATE POLICY "Users can view their pet weight records" ON public.pet_weight_records
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can insert their pet weight records" ON public.pet_weight_records
    FOR INSERT WITH CHECK (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can update their pet weight records" ON public.pet_weight_records
    FOR UPDATE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can delete their pet weight records" ON public.pet_weight_records
    FOR DELETE USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Pet weight goals policies
CREATE POLICY "Users can view their pet weight goals" ON public.pet_weight_goals
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "Users can manage their pet weight goals" ON public.pet_weight_goals
    FOR ALL USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

-- Nutritional trends policies
CREATE POLICY "Users can view their pet nutritional trends" ON public.nutritional_trends
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "System can manage nutritional trends" ON public.nutritional_trends
    FOR ALL USING (true);

-- Food comparisons policies
CREATE POLICY "Users can manage their food comparisons" ON public.food_comparisons
    FOR ALL USING (user_id = (SELECT auth.uid()));

-- Analytics cache policies
CREATE POLICY "Users can view their pet analytics" ON public.nutritional_analytics_cache
    FOR SELECT USING (pet_id IN (SELECT id FROM public.pets WHERE user_id = (SELECT auth.uid())));

CREATE POLICY "System can manage analytics cache" ON public.nutritional_analytics_cache
    FOR ALL USING (true);

-- =============================================================================
-- INITIAL DATA
-- =============================================================================

-- Insert initial ingredient data
INSERT INTO public.ingredients (name, aliases, safety_level, species_compatibility, description, common_allergen) VALUES
('chicken', ARRAY['chicken meat', 'chicken breast', 'chicken thigh'], 'caution', 'both', 'Common protein source, but frequent allergen', true),
('beef', ARRAY['beef meat', 'ground beef', 'beef liver'], 'caution', 'both', 'Common protein source, but frequent allergen', true),
('fish', ARRAY['fish meal', 'fish oil', 'salmon', 'tuna'], 'caution', 'both', 'High-quality protein, but common allergen', true),
('corn', ARRAY['corn meal', 'corn gluten', 'maize'], 'caution', 'both', 'Common filler ingredient, frequent allergen', true),
('wheat', ARRAY['wheat flour', 'wheat gluten', 'wheat bran'], 'caution', 'both', 'Common grain, frequent allergen', true),
('soy', ARRAY['soybean meal', 'soy protein', 'soy flour'], 'caution', 'both', 'Plant protein source, common allergen', true),
('dairy', ARRAY['milk', 'cheese', 'yogurt', 'whey'], 'caution', 'both', 'Dairy products, common allergen', true),
('eggs', ARRAY['egg', 'egg whites', 'egg yolks'], 'caution', 'both', 'High-quality protein, common allergen', true),
('chocolate', ARRAY['cocoa', 'cacao'], 'unsafe', 'both', 'Toxic to pets, contains theobromine', true),
('grapes', ARRAY['raisins', 'grape juice'], 'unsafe', 'both', 'Toxic to dogs, can cause kidney failure', true),
('onions', ARRAY['onion powder', 'garlic', 'chives'], 'unsafe', 'both', 'Toxic to pets, causes hemolytic anemia', true),
('xylitol', ARRAY['artificial sweetener'], 'unsafe', 'both', 'Artificial sweetener, extremely toxic to dogs', true),
('lamb', ARRAY['lamb meal', 'lamb liver'], 'safe', 'both', 'Novel protein source, generally well-tolerated', false),
('turkey', ARRAY['turkey meal', 'ground turkey'], 'safe', 'both', 'Lean protein source, good alternative to chicken', false),
('duck', ARRAY['duck meal', 'duck liver'], 'safe', 'both', 'Novel protein source, good for sensitive pets', false),
('sweet potato', ARRAY['sweet potato meal'], 'safe', 'both', 'Nutritious carbohydrate source, rich in fiber', false),
('brown rice', ARRAY['rice', 'rice meal'], 'safe', 'both', 'Whole grain carbohydrate, easily digestible', false),
('oats', ARRAY['oatmeal', 'oat flour'], 'safe', 'both', 'Whole grain, good source of fiber', false),
('quinoa', ARRAY['quinoa meal'], 'safe', 'both', 'Complete protein grain, highly nutritious', false),
('salmon', ARRAY['salmon meal', 'salmon oil'], 'safe', 'both', 'High-quality protein and omega-3 fatty acids', false)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Complete database schema created successfully!';
  RAISE NOTICE '📊 Tables: 17 total (core + food_items + nutrition + advanced)';
  RAISE NOTICE '🔒 RLS: Enabled on all tables with optimized policies';
  RAISE NOTICE '📈 Indexes: 30+ performance indexes created';
  RAISE NOTICE '🔄 Triggers: Updated_at triggers for all tables';
  RAISE NOTICE '🌱 Data: Initial ingredient data inserted';
  RAISE NOTICE '🍽️  Food Items: Comprehensive pet food database ready';
END $$;
