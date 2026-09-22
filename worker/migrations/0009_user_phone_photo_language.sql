-- v2.4.0: optional mobile number and photo per user, and the user's saved
-- app language (NULL = the role default: English for moderators, Arabic for
-- everyone else).

ALTER TABLE users ADD COLUMN phone TEXT;
ALTER TABLE users ADD COLUMN photo_key TEXT;
ALTER TABLE users ADD COLUMN language TEXT CHECK (language IN ('ar', 'en'));
