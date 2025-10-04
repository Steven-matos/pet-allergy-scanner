-- Add activity_level column to pets table
-- This migration adds activity level support for nutritional recommendations

-- Add activity_level column to pets table
ALTER TABLE public.pets 
ADD COLUMN IF NOT EXISTS activity_level TEXT CHECK (activity_level IN ('low', 'moderate', 'high'));

-- Add comment to clarify the activity_level column
COMMENT ON COLUMN public.pets.activity_level IS 'Pet activity level for nutritional calculations: low (indoor, minimal exercise), moderate (regular walks, some play), high (very active, lots of exercise)';

-- Update existing pets to have moderate activity level as default
UPDATE public.pets 
SET activity_level = 'moderate' 
WHERE activity_level IS NULL;
