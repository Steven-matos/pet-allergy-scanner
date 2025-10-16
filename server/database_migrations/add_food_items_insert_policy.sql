-- Add INSERT policy for food_items table to allow authenticated users to create food items
-- This fixes the RLS policy violation when users try to upload new food items

-- Add INSERT policy for food_items table
CREATE POLICY "Authenticated users can insert food items" ON public.food_items
    FOR INSERT 
    TO authenticated 
    WITH CHECK (true);

-- Verify the policy was created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'food_items' 
AND schemaname = 'public'
AND cmd = 'INSERT'
ORDER BY policyname;
