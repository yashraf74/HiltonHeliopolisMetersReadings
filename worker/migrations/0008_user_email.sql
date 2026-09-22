-- v2.3.0: every user has an email (exports can be sent to it). Existing
-- users get a placeholder until a moderator fills in the real address.

ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT 'null@hilton.com';
