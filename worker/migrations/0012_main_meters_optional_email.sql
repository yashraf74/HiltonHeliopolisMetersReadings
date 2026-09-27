-- Meters that represent a whole supply rather than a sub-meter. Only these
-- count towards the dashboard's consumption, cost and top-consumer views,
-- so sub-meters don't double-count what a main meter already measured.
ALTER TABLE meters ADD COLUMN is_main INTEGER NOT NULL DEFAULT 0;

-- Email is optional again. Accounts created before emails existed carry a
-- placeholder that the app already treats as "no email"; blank it so the
-- profile page and the export options tell the truth.
UPDATE users SET email = '' WHERE email = 'null@hilton.com';
