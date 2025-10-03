-- Add device_token column to users table for push notifications
-- Run this migration in your Supabase SQL editor

-- Add device_token column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS device_token TEXT;

-- Add index for device_token lookups
CREATE INDEX IF NOT EXISTS idx_users_device_token ON public.users(device_token);

-- Add comment for documentation
COMMENT ON COLUMN public.users.device_token IS 'Device token for push notifications via APNs';
