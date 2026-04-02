-- Add avatar_url column to users table
-- This column stores the URL of the user's profile picture
-- The URL typically points to the B2 proxy endpoint: /api/upload/file/avatars/<user_id>.<ext>
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Optional: backfill from role-specific photo_url columns
-- UPDATE users u SET avatar_url = s.photo_url FROM students s WHERE s.user_id = u.id AND s.photo_url IS NOT NULL AND u.avatar_url IS NULL;
-- UPDATE users u SET avatar_url = t.photo_url FROM teachers t WHERE t.user_id = u.id AND t.photo_url IS NOT NULL AND u.avatar_url IS NULL;
