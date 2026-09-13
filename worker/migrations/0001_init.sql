CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('engineer', 'technician')),
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE meters (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('electricity', 'water', 'gas')),
  location TEXT NOT NULL,
  floor_number INTEGER NOT NULL,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_meters_type_active ON meters(type, is_active);
CREATE INDEX idx_meters_floor ON meters(floor_number);

CREATE TABLE readings (
  id TEXT PRIMARY KEY,
  meter_id TEXT NOT NULL REFERENCES meters(id),
  value REAL NOT NULL,
  photo_key TEXT NOT NULL,
  logged_by TEXT NOT NULL REFERENCES users(id),
  logged_by_name TEXT NOT NULL,
  logged_at TEXT NOT NULL,
  synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_readings_meter ON readings(meter_id);
CREATE INDEX idx_readings_logged_by ON readings(logged_by);
CREATE INDEX idx_readings_logged_at ON readings(logged_at);
