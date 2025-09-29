-- Add onboarded column to users table
-- This migration adds an onboarded boolean column to track if a user has completed onboarding

-- Add the onboarded column with default value false
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS onboarded BOOLEAN DEFAULT FALSE;

-- Update existing users to have onboarded = true if they have pets
-- This ensures existing users don't get stuck in onboarding
UPDATE public.users 
SET onboarded = TRUE 
WHERE id IN (
    SELECT DISTINCT user_id 
    FROM public.pets 
    WHERE user_id IS NOT NULL
);

-- Add a comment to document the column
COMMENT ON COLUMN public.users.onboarded IS 'Indicates if the user has completed the initial onboarding process';
