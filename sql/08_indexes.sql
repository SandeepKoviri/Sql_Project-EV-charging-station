-- ============================================================================
-- SCRIPT: 08_indexes.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Creates simple indexes to speed up searches and queries.
-- ============================================================================

USE ev_charging_db;

-- ----------------------------------------------------------------------------
-- What is an Index?
-- An index is like an index at the back of a book.
-- Instead of reading the entire book from page 1 to find a word (Table Scan),
-- MySQL uses the index to jump straight to the exact page in milliseconds!
-- ----------------------------------------------------------------------------

-- 1. Speed up checking if a charger is already booked at a certain time
CREATE INDEX idx_bookings_charger_time 
ON bookings (charger_id, status, start_time, end_time);

-- 2. Speed up finding all bookings for a user
CREATE INDEX idx_bookings_user 
ON bookings (user_id);

-- 3. Speed up finding chargers at a station by type
CREATE INDEX idx_chargers_station 
ON chargers (station_id, charger_type);

-- 4. Speed up finding tariffs for a station and charger type
CREATE INDEX idx_tariffs_lookup 
ON tariffs (station_id, charger_type, status);

-- 5. Speed up finding stations by city
CREATE INDEX idx_stations_city 
ON stations (city);

-- 6. Speed up finding maintenance logs for a charger by status and date (Weak Entity Index)
CREATE INDEX idx_maintenance_charger_status 
ON charger_maintenance_logs (charger_id, status, maintenance_date);

-- ----------------------------------------------------------------------------
-- How to test if an index is working? Use EXPLAIN!
-- The EXPLAIN command tells you if MySQL is using the index.
-- ----------------------------------------------------------------------------
EXPLAIN
SELECT booking_id
FROM bookings
WHERE charger_id = 2
  AND status = 'BOOKED'
  AND '2026-10-01 10:00:00' < end_time
  AND '2026-10-01 11:00:00' > start_time;

EXPLAIN
SELECT log_seq, issue_type, technician_name, cost, status
FROM charger_maintenance_logs
WHERE charger_id = 11
  AND status = 'IN_PROGRESS';

