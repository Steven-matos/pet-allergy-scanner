-- Migration: Add documents field to health_events table for vet paperwork
-- Issue: #27 - Medical records upload feature

-- Add documents column to health_events table
-- Documents are stored as array of URLs (TEXT[])
ALTER TABLE public.health_events 
ADD COLUMN IF NOT EXISTS documents TEXT[] DEFAULT '{}';

-- Add comment for documentation
COMMENT ON COLUMN public.health_events.documents IS 'Array of document URLs for vet paperwork and medical records';

-- Create index for better query performance when filtering by documents
CREATE INDEX IF NOT EXISTS idx_health_events_documents ON public.health_events USING GIN(documents);

