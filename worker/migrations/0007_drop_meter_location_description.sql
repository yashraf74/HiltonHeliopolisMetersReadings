-- v2.0.1: meters lose `location` (redundant with `area`) and `description`
-- (unused). Meters whose area was empty take their location as the area
-- first, so no meter loses where it is.

UPDATE meters SET area = location WHERE area = '';
ALTER TABLE meters DROP COLUMN location;
ALTER TABLE meters DROP COLUMN description;
