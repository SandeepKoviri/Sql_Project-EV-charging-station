-- ============================================================================
-- SCRIPT: 06_triggers.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Automated triggers enforcing the 5 core business rules:
--              - Rule 1 (Vehicle Ownership) & Rule 2 (No Double-Booking) on insert
--              - Rule 5 (Auto Charger Status: AVAILABLE <-> OCCUPIED) on session lifecycle
-- ============================================================================

USE ev_charging_db;

DROP TRIGGER IF EXISTS trg_bookings_before_insert;
DROP TRIGGER IF EXISTS trg_bookings_before_update;
DROP TRIGGER IF EXISTS trg_sessions_after_insert;
DROP TRIGGER IF EXISTS trg_sessions_after_update;

DELIMITER $$

-- ============================================================================
-- 1. TRIGGER: trg_bookings_before_insert
-- Enforces Rule 1 (Vehicle Ownership) and Rule 2 (No Double-Booking / Overlap Guard).
-- ============================================================================
CREATE TRIGGER trg_bookings_before_insert
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_overlap INT;

    -- Check: Does the vehicle belong to this user?
    SELECT user_id INTO v_owner_id
    FROM vehicles
    WHERE vehicle_id = NEW.vehicle_id;

    IF v_owner_id IS NULL OR v_owner_id != NEW.user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Trigger Error: Vehicle does not belong to user';
    END IF;

    -- Check: Is there an existing overlapping booking for this charger?
    IF NEW.status = 'BOOKED' THEN
        SELECT COUNT(*) INTO v_overlap
        FROM bookings
        WHERE charger_id = NEW.charger_id
          AND status = 'BOOKED'
          AND NEW.start_time < end_time
          AND NEW.end_time > start_time;

        IF v_overlap > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Trigger Error: Conflicting booking already exists';
        END IF;
    END IF;
END$$

-- ============================================================================
-- 2. TRIGGER: trg_bookings_before_update
-- If a booking is cancelled, automatically set cancelled_at to the current time.
-- ============================================================================
CREATE TRIGGER trg_bookings_before_update
BEFORE UPDATE ON bookings
FOR EACH ROW
BEGIN
    IF NEW.status = 'CANCELLED' AND OLD.status != 'CANCELLED' AND NEW.cancelled_at IS NULL THEN
        SET NEW.cancelled_at = CURRENT_TIMESTAMP;
    END IF;
END$$

-- ============================================================================
-- 3. TRIGGER: trg_sessions_after_insert
-- Enforces Business Rule 5: Auto Charger Status (AVAILABLE -> OCCUPIED when charging begins).
-- ============================================================================
CREATE TRIGGER trg_sessions_after_insert
AFTER INSERT ON charging_sessions
FOR EACH ROW
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        UPDATE chargers
        SET status = 'OCCUPIED'
        WHERE charger_id = (SELECT charger_id FROM bookings WHERE booking_id = NEW.booking_id);
    END IF;
END$$

-- ============================================================================
-- 4. TRIGGER: trg_sessions_after_update
-- Enforces Business Rule 5: Auto Charger Status (OCCUPIED -> AVAILABLE when charging finishes).
-- ============================================================================
CREATE TRIGGER trg_sessions_after_update
AFTER UPDATE ON charging_sessions
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status = 'ACTIVE' THEN
        UPDATE chargers
        SET status = 'AVAILABLE'
        WHERE charger_id = (SELECT charger_id FROM bookings WHERE booking_id = NEW.booking_id);
    END IF;
END$$

DELIMITER ;
