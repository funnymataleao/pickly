-- Create Demo Account for App Store Review
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/bslsanvmkwjzbjerpzpi/sql

-- Step 1: Create demo user with email/password authentication
-- Email: demo@pickly.app
-- Password: generate a unique value in a password manager; never store it here

-- Note: You need to create this user through Supabase Dashboard instead:
-- 1. Go to Authentication → Users
-- 2. Click "Add User" → "Create new user"
-- 3. Email: demo@pickly.app
-- 4. Password: paste it directly from the password manager
-- 5. Auto Confirm User: YES (important!)
-- 6. Click "Create user"

-- After creating the user in Dashboard, run this SQL to add demo data:

-- Get the demo user ID (you'll need this)
-- SELECT id FROM auth.users WHERE email = 'demo@pickly.app';

-- Step 2: Create profile for demo user (replace YOUR_DEMO_USER_ID with actual UUID)
-- INSERT INTO public.profiles (id, display_name)
-- VALUES ('YOUR_DEMO_USER_ID', 'Demo User')
-- ON CONFLICT (id) DO NOTHING;

-- Saved products and history are local-only in the current app, so they are
-- created by using the demo account on the review device rather than by SQL.

-- Step 4: Set demo user preferences (replace YOUR_DEMO_USER_ID)
/*
INSERT INTO public.user_preferences (user_id, low_sugar, low_sodium, sensitive_digestion)
VALUES ('YOUR_DEMO_USER_ID', true, false, true)
ON CONFLICT (user_id) DO UPDATE SET
  low_sugar = EXCLUDED.low_sugar,
  low_sodium = EXCLUDED.low_sodium,
  sensitive_digestion = EXCLUDED.sensitive_digestion;
*/

-- Verification queries:
-- SELECT * FROM auth.users WHERE email = 'demo@pickly.app';
-- SELECT * FROM public.profiles WHERE id IN (SELECT id FROM auth.users WHERE email = 'demo@pickly.app');
-- SELECT * FROM public.user_preferences WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'demo@pickly.app');
