-- Names are no longer denormalised into readings; they are joined from
-- users at read time so a renamed account shows its new name everywhere.
CREATE TABLE readings_new (
  id TEXT PRIMARY KEY,
  meter_id TEXT NOT NULL REFERENCES meters(id),
  value REAL NOT NULL,
  photo_key TEXT NOT NULL,
  notes TEXT,
  logged_by TEXT NOT NULL REFERENCES users(id),
  logged_at TEXT NOT NULL,
  synced_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
INSERT INTO readings_new (id, meter_id, value, photo_key, notes, logged_by, logged_at, synced_at, created_at)
  SELECT id, meter_id, value, photo_key, notes, logged_by, logged_at, synced_at, created_at FROM readings;
DROP TABLE readings;
ALTER TABLE readings_new RENAME TO readings;
CREATE INDEX idx_readings_meter ON readings(meter_id);
CREATE INDEX idx_readings_logged_by ON readings(logged_by);
CREATE INDEX idx_readings_logged_at ON readings(logged_at);
