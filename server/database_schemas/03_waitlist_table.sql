-- =============================================================================
-- WAITLIST TABLE - SniffTest Pet Allergy Scanner
-- =============================================================================
-- Created: 2025-01-15
-- Purpose: Store email addresses for waitlist signups

-- Waitlist table (no authentication required for signup)
CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    email TEXT UNIQUE NOT NULL CHECK (LENGTH(email) > 0 AND LENGTH(email) <= 255),
    notified BOOLEAN DEFAULT FALSE,
    notified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on email for fast lookups
CREATE INDEX IF NOT EXISTS idx_waitlist_email ON public.waitlist(email);
CREATE INDEX IF NOT EXISTS idx_waitlist_created_at ON public.waitlist(created_at);

-- Enable RLS (Row Level Security)
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotent migration)
DROP POLICY IF EXISTS "Allow public waitlist signups" ON public.waitlist;
DROP POLICY IF EXISTS "Service role can read all waitlist entries" ON public.waitlist;

-- Policy: Allow anyone to insert (for public signup)
CREATE POLICY "Allow public waitlist signups"
    ON public.waitlist
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Policy: Allow service role to read all entries (for admin use)
CREATE POLICY "Service role can read all waitlist entries"
    ON public.waitlist
    FOR SELECT
    TO service_role
    USING (true);

-- Drop existing trigger and function if they exist (for idempotent migration)
DROP TRIGGER IF EXISTS update_waitlist_updated_at ON public.waitlist;
DROP FUNCTION IF EXISTS update_waitlist_updated_at();

-- Add updated_at trigger
-- SET search_path = pg_catalog to prevent SQL injection via search_path manipulation
-- pg_catalog contains only system functions and is safe
CREATE OR REPLACE FUNCTION update_waitlist_updated_at()
RETURNS TRIGGER 
SET search_path = pg_catalog
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_waitlist_updated_at
    BEFORE UPDATE ON public.waitlist
    FOR EACH ROW
    EXECUTE FUNCTION update_waitlist_updated_at();

