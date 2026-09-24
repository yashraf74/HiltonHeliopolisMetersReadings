-- v2.6.x: a moderator can hide an account from the readings "by user"
-- filter (internal or test accounts). Cosmetic only: their readings stay
-- visible everywhere. Off for everyone until a moderator ticks it.

ALTER TABLE users ADD COLUMN hidden_from_filter INTEGER NOT NULL DEFAULT 0
  CHECK (hidden_from_filter IN (0, 1));
