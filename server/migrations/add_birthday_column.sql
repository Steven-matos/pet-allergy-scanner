-- Add birthday column to pets table and remove age_months
-- This migration converts the age_months field to a birthday field

-- Add birthday column
ALTER TABLE public.pets
ADD COLUMN birthday DATE;

-- Note: We cannot automatically convert age_months to birthday since we don't know the exact birth date
-- Existing pets will have NULL birthday values
-- Users can update their pet's birthday through the app

-- Remove age_months column (uncomment when ready to remove)
-- ALTER TABLE public.pets DROP COLUMN age_months;

-- Add comment explaining the change
COMMENT ON COLUMN public.pets.birthday IS 'Pet birth date - used to calculate age automatically';
