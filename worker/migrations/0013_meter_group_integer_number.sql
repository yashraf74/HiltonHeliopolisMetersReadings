-- Meters get an optional group (the header a meter sits under in the
-- transposed Excel export; blank = no group), and the meter number becomes
-- a whole number instead of free text.
--
-- Guard first: if any existing number is not a plain whole number (letters,
-- symbols, more than 9 digits, or a leading zero that converting would
-- drop), this insert breaks the CHECK and the migration stops here, before
-- anything has changed. Fix those meters' numbers, then apply it again.
CREATE TABLE _meter_number_guard (unconvertible INTEGER NOT NULL CHECK (unconvertible = 0));
INSERT INTO _meter_number_guard
  SELECT COUNT(*) FROM meters
  WHERE number IS NOT NULL AND TRIM(number) <> ''
    AND (TRIM(number) GLOB '*[^0-9]*'
         OR LENGTH(TRIM(number)) > 9
         OR (LENGTH(TRIM(number)) > 1 AND TRIM(number) GLOB '0*'));
DROP TABLE _meter_number_guard;

-- The identity index covers number, so it goes first and comes back on the
-- new column. Readings are not touched: the column is swapped in place
-- rather than rebuilding the table.
DROP INDEX idx_meters_identity_active;
ALTER TABLE meters ADD COLUMN number_int INTEGER CHECK (number_int >= 0);
UPDATE meters SET number_int = CAST(TRIM(number) AS INTEGER)
  WHERE number IS NOT NULL AND TRIM(number) <> '';
ALTER TABLE meters DROP COLUMN number;
ALTER TABLE meters RENAME COLUMN number_int TO number;
CREATE UNIQUE INDEX idx_meters_identity_active
  ON meters(name COLLATE NOCASE, COALESCE(number, -1), area COLLATE NOCASE)
  WHERE is_active = 1;

ALTER TABLE meters ADD COLUMN group_name TEXT;
