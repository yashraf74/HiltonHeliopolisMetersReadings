-- v2.0: meters lose floor_number (old floors become the meter number when
-- it was empty) and gain to-do / export order numbers; readings gain a
-- `gain` column (difference from the previous reading of the same meter,
-- NULL for the first). Meters is a parent of readings, so readings is
-- backed up and rebuilt after it.

CREATE TABLE readings_backup AS SELECT * FROM readings;
DROP TABLE readings;

CREATE TABLE meters_new (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('electricity', 'water', 'gas')),
  location TEXT NOT NULL,
  area TEXT NOT NULL DEFAULT '',
  number TEXT,
  description TEXT,
  photo_key TEXT,
  todo_order INTEGER,
  export_order INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO meters_new (id, name, type, location, area, number, description, photo_key, todo_order, export_order, is_active, created_by, created_at, updated_at)
  SELECT id, name, type, location, area,
         COALESCE(NULLIF(number, ''), CAST(floor_number AS TEXT)),
         description, photo_key, NULL, NULL, is_active, created_by, created_at, updated_at
  FROM meters;
DROP TABLE meters;
ALTER TABLE meters_new RENAME TO meters;
CREATE INDEX idx_meters_type_active ON meters(type, is_active);
CREATE UNIQUE INDEX idx_meters_identity_active
  ON meters(name COLLATE NOCASE, COALESCE(number, '') COLLATE NOCASE, area COLLATE NOCASE)
  WHERE is_active = 1;

CREATE TABLE readings (
  id TEXT PRIMARY KEY,
  meter_id TEXT NOT NULL REFERENCES meters(id),
  value REAL NOT NULL,
  gain REAL,
  photo_key TEXT,
  logged_by TEXT NOT NULL REFERENCES users(id),
  logged_at TEXT NOT NULL,
  synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO readings (id, meter_id, value, gain, photo_key, logged_by, logged_at, synced_at, created_at)
  SELECT id, meter_id, value, NULL, photo_key, logged_by, logged_at, synced_at, created_at FROM readings_backup;
DROP TABLE readings_backup;
CREATE INDEX idx_readings_meter ON readings(meter_id);
CREATE INDEX idx_readings_logged_by ON readings(logged_by);
CREATE INDEX idx_readings_logged_at ON readings(logged_at);
CREATE INDEX idx_readings_photo_purge ON readings(logged_at) WHERE photo_key IS NOT NULL;

-- Backfill gains: difference from the previous reading of the same meter.
UPDATE readings SET gain = g.gain
FROM (
  SELECT id, value - LAG(value) OVER (PARTITION BY meter_id ORDER BY logged_at, id) AS gain
  FROM readings
) AS g
WHERE readings.id = g.id;
