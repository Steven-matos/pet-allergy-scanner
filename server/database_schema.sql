-- Pet Allergy Scanner Database Schema
-- This schema should be run in your Supabase SQL editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    first_name TEXT,
    last_name TEXT,
    role TEXT DEFAULT 'free' CHECK (role IN ('free', 'premium')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create pets table
CREATE TABLE IF NOT EXISTS public.pets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL CHECK (LENGTH(name) > 0 AND LENGTH(name) <= 100),
    species TEXT NOT NULL CHECK (species IN ('dog', 'cat')),
    breed TEXT,
    age_months INTEGER CHECK (age_months >= 0 AND age_months <= 300),
    weight_kg DECIMAL(5,2) CHECK (weight_kg >= 0.1 AND weight_kg <= 200.0),
    known_allergies TEXT[] DEFAULT '{}',
    vet_name TEXT,
    vet_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create ingredients table
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

-- Create scans table
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

-- Create favorites table
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_pets_species ON public.pets(species);
CREATE INDEX IF NOT EXISTS idx_scans_user_id ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_pet_id ON public.scans(pet_id);
CREATE INDEX IF NOT EXISTS idx_scans_status ON public.scans(status);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_pet_id ON public.favorites(pet_id);
CREATE INDEX IF NOT EXISTS idx_ingredients_name ON public.ingredients(name);
CREATE INDEX IF NOT EXISTS idx_ingredients_safety_level ON public.ingredients(safety_level);

-- Create updated_at trigger function
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

-- Row Level Security (RLS) policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Pets policies
CREATE POLICY "Users can view own pets" ON public.pets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pets" ON public.pets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pets" ON public.pets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own pets" ON public.pets
    FOR DELETE USING (auth.uid() = user_id);

-- Scans policies
CREATE POLICY "Users can view own scans" ON public.scans
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own scans" ON public.scans
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own scans" ON public.scans
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own scans" ON public.scans
    FOR DELETE USING (auth.uid() = user_id);

-- Favorites policies
CREATE POLICY "Users can view own favorites" ON public.favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites" ON public.favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own favorites" ON public.favorites
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites" ON public.favorites
    FOR DELETE USING (auth.uid() = user_id);

-- Ingredients are public (read-only for users)
CREATE POLICY "Anyone can view ingredients" ON public.ingredients
    FOR SELECT USING (true);

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
