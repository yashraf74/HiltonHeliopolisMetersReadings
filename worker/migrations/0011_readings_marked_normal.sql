-- v2.6.x: a moderator or engineer can mark an unusual reading as normal, so
-- it stops being flagged. Editing the reading's value clears the mark (see
-- readings PUT), so a changed reading is judged again.

ALTER TABLE readings ADD COLUMN normal_at TEXT;
ALTER TABLE readings ADD COLUMN normal_by TEXT REFERENCES users(id);
