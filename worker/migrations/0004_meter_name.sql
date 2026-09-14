-- Meters get a required name, unique per floor among active meters.
-- Existing rows are backfilled from location; duplicates on the same floor
-- get a numeric suffix so the unique index can be created.
ALTER TABLE meters ADD COLUMN name TEXT NOT NULL DEFAULT '';
UPDATE meters SET name = location WHERE name = '';
UPDATE meters SET name = name || ' (' || d.rn || ')'
FROM (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY floor_number, lower(name) ORDER BY created_at, id) AS rn
  FROM meters
) AS d
WHERE meters.id = d.id AND d.rn > 1;
CREATE UNIQUE INDEX idx_meters_floor_name_active ON meters(floor_number, name COLLATE NOCASE) WHERE is_active = 1;
