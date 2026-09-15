-- Roles: engineer -> moderator (full), new engineer (readings only).
-- Readings: photo_key becomes nullable (purged after 90 days), notes dropped.
-- Meters: mandatory area, optional number; uniqueness is now the combination
-- of name + floor + number + area among active meters.
--
-- users has a CHECK constraint that must change, so it is rebuilt. Because
-- meters and readings reference users, they are backed up and dropped first,
-- then recreated after users, so no foreign key is ever left dangling.

CREATE TABLE readings_backup AS SELECT * FROM readings;
CREATE TABLE meters_backup AS SELECT * FROM meters;
DROP TABLE readings;
DROP TABLE meters;

CREATE TABLE users_new (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('moderator', 'engineer', 'technician')),
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO users_new (id, username, password_hash, full_name, role, is_active, created_at)
  SELECT id, username, password_hash, full_name,
         CASE role WHEN 'engineer' THEN 'moderator' ELSE role END,
         is_active, created_at
  FROM users;
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;

CREATE TABLE meters (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('electricity', 'water', 'gas')),
  location TEXT NOT NULL,
  area TEXT NOT NULL DEFAULT '',
  number TEXT,
  floor_number INTEGER NOT NULL,
  description TEXT,
  photo_key TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO meters (id, name, type, location, area, number, floor_number, description, photo_key, is_active, created_by, created_at, updated_at)
  SELECT id, name, type, location, '', NULL, floor_number, description, photo_key, is_active, created_by, created_at, updated_at
  FROM meters_backup;
CREATE INDEX idx_meters_type_active ON meters(type, is_active);
CREATE INDEX idx_meters_floor ON meters(floor_number);
CREATE UNIQUE INDEX idx_meters_identity_active
  ON meters(name COLLATE NOCASE, floor_number, COALESCE(number, '') COLLATE NOCASE, area COLLATE NOCASE)
  WHERE is_active = 1;

CREATE TABLE readings (
  id TEXT PRIMARY KEY,
  meter_id TEXT NOT NULL REFERENCES meters(id),
  value REAL NOT NULL,
  photo_key TEXT,
  logged_by TEXT NOT NULL REFERENCES users(id),
  logged_at TEXT NOT NULL,
  synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO readings (id, meter_id, value, photo_key, logged_by, logged_at, synced_at, created_at)
  SELECT id, meter_id, value, photo_key, logged_by, logged_at, synced_at, created_at FROM readings_backup;
CREATE INDEX idx_readings_meter ON readings(meter_id);
CREATE INDEX idx_readings_logged_by ON readings(logged_by);
CREATE INDEX idx_readings_logged_at ON readings(logged_at);
CREATE INDEX idx_readings_photo_purge ON readings(logged_at) WHERE photo_key IS NOT NULL;

DROP TABLE readings_backup;
DROP TABLE meters_backup;
