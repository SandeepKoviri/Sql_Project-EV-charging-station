-- ============================================================================
-- SCRIPT: 05_stored_procedures.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Easy-to-understand stored procedures for booking and charging.
-- ============================================================================

USE ev_charging_db;

DROP PROCEDURE IF EXISTS sp_create_booking;
DROP PROCEDURE IF EXISTS sp_cancel_booking;
DROP PROCEDURE IF EXISTS sp_start_charging_session;
DROP PROCEDURE IF EXISTS sp_end_charging_session;
DROP PROCEDURE IF EXISTS sp_get_session_summary;

DELIMITER $$

-- ============================================================================
-- 1. PROCEDURE: sp_create_booking
-- Creates a new slot booking if the charger is free and vehicle belongs to user.
-- ============================================================================
CREATE PROCEDURE sp_create_booking(
    IN  p_user_id     INT,
    IN  p_vehicle_id  INT,
    IN  p_charger_id  INT,
    IN  p_start_time  DATETIME,
    IN  p_end_time    DATETIME,
    OUT p_booking_id  INT
)
BEGIN
    DECLARE v_owner_id INT;
    DECLARE v_overlap_count INT;

    -- Step 1 [Rule 3: Valid Booking Time]: Make sure end time is strictly after start time
    IF p_end_time <= p_start_time THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Booking end time must be after start time';
    END IF;

    -- Step 2 [Rule 1: Vehicle Ownership]: Verify vehicle belongs to this user
    SELECT user_id INTO v_owner_id
    FROM vehicles
    WHERE vehicle_id = p_vehicle_id;

    IF v_owner_id IS NULL OR v_owner_id != p_user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Vehicle does not belong to this user';
    END IF;

    -- Step 3 [Rule 2: No Double-Booking]: Check if charger has an overlapping reservation
    -- Overlap formula: new_start < existing_end AND new_end > existing_start
    SELECT COUNT(*) INTO v_overlap_count
    FROM bookings
    WHERE charger_id = p_charger_id
      AND status = 'BOOKED'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Charger is already booked for this time slot';
    END IF;

    -- Step 4: Insert the booking
    INSERT INTO bookings (user_id, vehicle_id, charger_id, start_time, end_time, status)
    VALUES (p_user_id, p_vehicle_id, p_charger_id, p_start_time, p_end_time, 'BOOKED');

    -- Return the new booking ID
    SET p_booking_id = LAST_INSERT_ID();
END$$

-- ============================================================================
-- 2. PROCEDURE: sp_cancel_booking
-- Cancels a booking if it belongs to the user and is not already completed.
-- ============================================================================
CREATE PROCEDURE sp_cancel_booking(
    IN p_booking_id INT,
    IN p_user_id    INT
)
BEGIN
    DECLARE v_booking_user INT;
    DECLARE v_status VARCHAR(20);

    -- Step 1: Find booking
    SELECT user_id, status INTO v_booking_user, v_status
    FROM bookings
    WHERE booking_id = p_booking_id;

    IF v_booking_user IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Booking does not exist';
    END IF;

    -- Step 2: Check ownership
    IF v_booking_user != p_user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: You do not own this booking';
    END IF;

    -- Step 3: Check if already completed or cancelled
    IF v_status = 'COMPLETED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Cannot cancel a completed booking';
    END IF;

    IF v_status = 'CANCELLED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Booking is already cancelled';
    END IF;

    -- Step 4: Cancel the booking
    UPDATE bookings
    SET status = 'CANCELLED',
        cancelled_at = CURRENT_TIMESTAMP
    WHERE booking_id = p_booking_id;
END$$

-- ============================================================================
-- 3. PROCEDURE: sp_start_charging_session
-- Starts the charging process for a booking and marks the charger OCCUPIED.
-- ============================================================================
CREATE PROCEDURE sp_start_charging_session(
    IN  p_booking_id INT,
    OUT p_session_id INT
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_charger_id INT;

    -- Step 1: Verify the booking exists and is in BOOKED status
    SELECT status, charger_id INTO v_status, v_charger_id
    FROM bookings
    WHERE booking_id = p_booking_id;

    IF v_status IS NULL OR v_status != 'BOOKED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Booking is not in BOOKED status';
    END IF;

    -- Step 2: Insert the active charging session
    INSERT INTO charging_sessions (booking_id, start_time, status)
    VALUES (p_booking_id, CURRENT_TIMESTAMP, 'ACTIVE');

    SET p_session_id = LAST_INSERT_ID();

    -- Step 3 [Rule 5: Auto Charger Status]: Change charger status to OCCUPIED
    UPDATE chargers
    SET status = 'OCCUPIED'
    WHERE charger_id = v_charger_id;
END$$

-- ============================================================================
-- 4. PROCEDURE: sp_end_charging_session
-- Ends the session, calculates the cost using the tariff table, and frees the charger.
-- ============================================================================
CREATE PROCEDURE sp_end_charging_session(
    IN p_session_id          INT,
    IN p_energy_consumed_kwh DECIMAL(8,2),
    IN p_end_time            DATETIME
)
BEGIN
    DECLARE v_booking_id INT;
    DECLARE v_charger_id INT;
    DECLARE v_station_id INT;
    DECLARE v_charger_type VARCHAR(20);
    DECLARE v_start_time DATETIME;
    DECLARE v_peak_price DECIMAL(8,2);
    DECLARE v_off_peak_price DECIMAL(8,2);
    DECLARE v_peak_start TIME;
    DECLARE v_peak_end TIME;
    DECLARE v_price DECIMAL(8,2);
    DECLARE v_period VARCHAR(10);
    DECLARE v_total_cost DECIMAL(10,2);

    -- Step 1: Find session details
    SELECT cs.booking_id, cs.start_time, b.charger_id, c.station_id, c.charger_type
    INTO v_booking_id, v_start_time, v_charger_id, v_station_id, v_charger_type
    FROM charging_sessions cs
    JOIN bookings b ON cs.booking_id = b.booking_id
    JOIN chargers c ON b.charger_id = c.charger_id
    WHERE cs.session_id = p_session_id AND cs.status = 'ACTIVE';

    IF v_booking_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Active charging session not found';
    END IF;

    -- Step 2-4 [Rule 4: Dynamic Pricing]: Resolve Peak vs Off-Peak rate and compute total cost
    -- Step 2: Fetch tariff for this station and charger type
    SELECT peak_price_per_kwh, off_peak_price_per_kwh, peak_start_time, peak_end_time
    INTO v_peak_price, v_off_peak_price, v_peak_start, v_peak_end
    FROM tariffs
    WHERE station_id = v_station_id 
      AND charger_type = v_charger_type 
      AND status = 'ACTIVE'
    LIMIT 1;

    -- Step 3: Check if session started during PEAK hours
    IF TIME(v_start_time) >= v_peak_start AND TIME(v_start_time) < v_peak_end THEN
        SET v_period = 'PEAK';
        SET v_price = v_peak_price;
    ELSE
        SET v_period = 'OFF_PEAK';
        SET v_price = v_off_peak_price;
    END IF;

    -- Step 4: Calculate total cost = energy * price
    SET v_total_cost = ROUND(p_energy_consumed_kwh * v_price, 2);

    -- Step 5: Update session to COMPLETED
    UPDATE charging_sessions
    SET end_time = p_end_time,
        energy_consumed_kwh = p_energy_consumed_kwh,
        price_per_kwh = v_price,
        pricing_period = v_period,
        total_cost = v_total_cost,
        status = 'COMPLETED'
    WHERE session_id = p_session_id;

    -- Step 6: Mark booking as COMPLETED
    UPDATE bookings
    SET status = 'COMPLETED'
    WHERE booking_id = v_booking_id;

    -- Step 7 [Rule 5: Auto Charger Status]: Release charger back to AVAILABLE
    UPDATE chargers
    SET status = 'AVAILABLE'
    WHERE charger_id = v_charger_id;
END$$

-- ============================================================================
-- 5. PROCEDURE: sp_get_session_summary
-- Prints invoice details for a session.
-- ============================================================================
CREATE PROCEDURE sp_get_session_summary(
    IN p_session_id INT
)
BEGIN
    SELECT 
        cs.session_id,
        u.name AS customer_name,
        v.vehicle_number,
        s.station_name,
        c.charger_number,
        c.charger_type,
        cs.energy_consumed_kwh,
        cs.price_per_kwh,
        cs.pricing_period,
        cs.total_cost,
        cs.status
    FROM charging_sessions cs
    JOIN bookings b ON cs.booking_id = b.booking_id
    JOIN users u ON b.user_id = u.user_id
    JOIN vehicles v ON b.vehicle_id = v.vehicle_id
    JOIN chargers c ON b.charger_id = c.charger_id
    JOIN stations s ON c.station_id = s.station_id
    WHERE cs.session_id = p_session_id;
END$$

DELIMITER ;
