-- ============================================================================
-- SCRIPT: 07_views.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: High-value database views providing operational visibility,
--              real-time availability, financial summaries, and user history.
--
-- VIEWS INCLUDED:
--   1. vw_active_bookings
--   2. vw_charger_availability_live
--   3. vw_completed_session_details
--   4. vw_station_revenue_summary
--   5. vw_user_charging_history
--   6. vw_current_active_sessions
--   7. vw_tariff_schedule_active
--   8. vw_charger_maintenance_history (Weak Entity Operational View)
-- ============================================================================

USE ev_charging_db;

-- ----------------------------------------------------------------------------
-- Drop existing views for clean re-creation
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_charger_maintenance_history;
DROP VIEW IF EXISTS vw_current_active_sessions;
DROP VIEW IF EXISTS vw_user_charging_history;
DROP VIEW IF EXISTS vw_station_revenue_summary;
DROP VIEW IF EXISTS vw_completed_session_details;
DROP VIEW IF EXISTS vw_charger_availability_live;
DROP VIEW IF EXISTS vw_active_bookings;
DROP VIEW IF EXISTS vw_tariff_schedule_active;

-- ============================================================================
-- 1. VIEW: vw_active_bookings
-- Lists all upcoming and active bookings with complete customer, vehicle,
-- charger, and station context.
-- ============================================================================
CREATE VIEW vw_active_bookings AS
SELECT 
    b.booking_id,
    b.status AS booking_status,
    u.user_id,
    u.name AS customer_name,
    u.phone AS customer_phone,
    u.email AS customer_email,
    v.vehicle_id,
    v.vehicle_number,
    CONCAT(v.brand, ' ', v.model) AS vehicle_name,
    v.connector_type,
    s.station_id,
    s.station_name,
    s.city,
    s.address,
    c.charger_id,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    b.start_time,
    b.end_time,
    TIMESTAMPDIFF(MINUTE, b.start_time, b.end_time) AS duration_minutes,
    b.created_at AS booked_at
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN vehicles v ON b.vehicle_id = v.vehicle_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
WHERE b.status = 'BOOKED'
ORDER BY b.start_time ASC;

-- ============================================================================
-- 2. VIEW: vw_charger_availability_live
-- Real-time operational status of every charger across all stations.
-- Displays whether a charger is physically free, occupied, or under maintenance.
-- ============================================================================
CREATE VIEW vw_charger_availability_live AS
SELECT 
    s.station_id,
    s.station_name,
    s.city,
    s.state,
    s.status AS station_status,
    c.charger_id,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    c.status AS charger_status,
    CASE 
        WHEN s.status != 'ACTIVE' THEN 'STATION_OFFLINE'
        WHEN c.status = 'MAINTENANCE' THEN 'MAINTENANCE'
        WHEN c.status = 'INACTIVE' THEN 'INACTIVE'
        WHEN c.status = 'OCCUPIED' THEN 'CHARGING_IN_PROGRESS'
        WHEN EXISTS (
            SELECT 1 FROM bookings b
            WHERE b.charger_id = c.charger_id
              AND b.status = 'BOOKED'
              AND CURRENT_TIMESTAMP BETWEEN b.start_time AND b.end_time
        ) THEN 'RESERVED_CURRENT_SLOT'
        ELSE 'AVAILABLE_FOR_USE'
    END AS operational_state,
    (
        SELECT COUNT(*)
        FROM bookings b
        WHERE b.charger_id = c.charger_id
          AND b.status = 'BOOKED'
          AND b.start_time >= CURRENT_TIMESTAMP
    ) AS upcoming_bookings_count
FROM stations s
JOIN chargers c ON s.station_id = c.station_id
ORDER BY s.city, s.station_name, c.power_kw DESC;

-- ============================================================================
-- 3. VIEW: vw_completed_session_details
-- Comprehensive report of all finalized charging sessions with energy telemetry,
-- duration, tariff breakdown, and billed amount.
-- ============================================================================
CREATE VIEW vw_completed_session_details AS
SELECT 
    cs.session_id,
    b.booking_id,
    u.user_id,
    u.name AS customer_name,
    v.vehicle_number,
    CONCAT(v.brand, ' ', v.model) AS vehicle_model,
    v.battery_capacity_kwh,
    s.station_id,
    s.station_name,
    s.city,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    cs.start_time,
    cs.end_time,
    TIMESTAMPDIFF(MINUTE, cs.start_time, cs.end_time) AS duration_minutes,
    cs.energy_consumed_kwh,
    ROUND(cs.energy_consumed_kwh / (TIMESTAMPDIFF(MINUTE, cs.start_time, cs.end_time) / 60.0), 2) AS effective_delivery_rate_kw,
    cs.pricing_period,
    cs.price_per_kwh,
    cs.total_cost,
    cs.created_at AS session_logged_at
FROM charging_sessions cs
JOIN bookings b ON cs.booking_id = b.booking_id
JOIN users u ON b.user_id = u.user_id
JOIN vehicles v ON b.vehicle_id = v.vehicle_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
WHERE cs.status = 'COMPLETED'
ORDER BY cs.end_time DESC;

-- ============================================================================
-- 4. VIEW: vw_station_revenue_summary
-- Aggregated operational and financial performance by station.
-- ============================================================================
CREATE VIEW vw_station_revenue_summary AS
SELECT 
    s.station_id,
    s.station_name,
    s.city,
    u.name AS owner_name,
    s.status AS station_status,
    COUNT(DISTINCT c.charger_id) AS total_chargers_installed,
    COUNT(DISTINCT cs.session_id) AS total_completed_sessions,
    COALESCE(SUM(cs.energy_consumed_kwh), 0.00) AS total_energy_dispensed_kwh,
    COALESCE(SUM(cs.total_cost), 0.00) AS total_revenue_inr,
    COALESCE(ROUND(AVG(cs.total_cost), 2), 0.00) AS avg_revenue_per_session_inr,
    COALESCE(ROUND(AVG(cs.energy_consumed_kwh), 2), 0.00) AS avg_energy_per_session_kwh
FROM stations s
JOIN users u ON s.owner_id = u.user_id
LEFT JOIN chargers c ON s.station_id = c.station_id
LEFT JOIN bookings b ON c.charger_id = b.charger_id
LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id AND cs.status = 'COMPLETED'
GROUP BY 
    s.station_id,
    s.station_name,
    s.city,
    u.name,
    s.status
ORDER BY total_revenue_inr DESC;

-- ============================================================================
-- 5. VIEW: vw_user_charging_history
-- Customer summary displaying EV adoption metrics and lifetime charging totals.
-- ============================================================================
CREATE VIEW vw_user_charging_history AS
SELECT 
    u.user_id,
    u.name AS customer_name,
    u.email,
    u.phone,
    COUNT(DISTINCT v.vehicle_id) AS vehicles_registered,
    COUNT(DISTINCT b.booking_id) AS total_slots_booked,
    COUNT(DISTINCT CASE WHEN b.status = 'COMPLETED' THEN b.booking_id END) AS completed_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'CANCELLED' THEN b.booking_id END) AS cancelled_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'NO_SHOW' THEN b.booking_id END) AS no_show_bookings,
    COALESCE(SUM(cs.energy_consumed_kwh), 0.00) AS lifetime_energy_kwh,
    COALESCE(SUM(cs.total_cost), 0.00) AS lifetime_expenditure_inr,
    MAX(cs.end_time) AS last_charged_at
FROM users u
LEFT JOIN vehicles v ON u.user_id = v.user_id
LEFT JOIN bookings b ON u.user_id = b.user_id
LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id AND cs.status = 'COMPLETED'
WHERE u.role = 'CUSTOMER'
GROUP BY 
    u.user_id,
    u.name,
    u.email,
    u.phone
ORDER BY lifetime_expenditure_inr DESC;

-- ============================================================================
-- 6. VIEW: vw_current_active_sessions
-- Live telemetry monitor for ongoing charging sessions in progress.
-- ============================================================================
CREATE VIEW vw_current_active_sessions AS
SELECT 
    cs.session_id,
    b.booking_id,
    u.name AS customer_name,
    u.phone AS customer_phone,
    v.vehicle_number,
    CONCAT(v.brand, ' ', v.model) AS vehicle_model,
    s.station_name,
    s.city,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    cs.start_time AS session_start_time,
    TIMESTAMPDIFF(MINUTE, cs.start_time, CURRENT_TIMESTAMP) AS elapsed_minutes,
    cs.status AS session_status
FROM charging_sessions cs
JOIN bookings b ON cs.booking_id = b.booking_id
JOIN users u ON b.user_id = u.user_id
JOIN vehicles v ON b.vehicle_id = v.vehicle_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
WHERE cs.status = 'ACTIVE'
ORDER BY cs.start_time ASC;

-- ============================================================================
-- 7. VIEW: vw_tariff_schedule_active
-- Published active tariff rates across network stations.
-- ============================================================================
CREATE VIEW vw_tariff_schedule_active AS
SELECT 
    t.tariff_id,
    s.station_name,
    s.city,
    t.charger_type,
    CONCAT('₹', FORMAT(t.peak_price_per_kwh, 2)) AS peak_rate_per_kwh,
    CONCAT('₹', FORMAT(t.off_peak_price_per_kwh, 2)) AS off_peak_rate_per_kwh,
    TIME_FORMAT(t.peak_start_time, '%H:%i') AS peak_window_start,
    TIME_FORMAT(t.peak_end_time, '%H:%i') AS peak_window_end,
    t.effective_from,
    COALESCE(DATE_FORMAT(t.effective_to, '%Y-%m-%d'), 'Ongoing') AS effective_until
FROM tariffs t
JOIN stations s ON t.station_id = s.station_id
WHERE t.status = 'ACTIVE'
ORDER BY s.city, s.station_name, t.charger_type;

-- ============================================================================
-- 8. VIEW: vw_charger_maintenance_history (Weak Entity Reporting View)
-- Comprehensive operational audit trail linking the weak entity
-- 'charger_maintenance_logs' with its identifying parent 'chargers' and 'stations'.
-- ============================================================================
CREATE VIEW vw_charger_maintenance_history AS
SELECT 
    s.station_id,
    s.station_name,
    s.city,
    c.charger_id,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    c.status AS current_charger_status,
    cml.log_seq,
    cml.maintenance_date,
    cml.issue_type,
    cml.description AS issue_description,
    cml.technician_name,
    cml.cost AS maintenance_cost,
    cml.status AS maintenance_status,
    cml.resolution_notes,
    cml.created_at AS logged_at
FROM charger_maintenance_logs cml
JOIN chargers c ON cml.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
ORDER BY s.station_name, c.charger_number, cml.log_seq;

-- ----------------------------------------------------------------------------
-- Confirmation Query: List created views
-- ----------------------------------------------------------------------------
SELECT 
    TABLE_NAME AS view_name,
    TABLE_TYPE
FROM 
    information_schema.TABLES
WHERE 
    TABLE_SCHEMA = 'ev_charging_db'
    AND TABLE_TYPE = 'VIEW'
ORDER BY 
    view_name;

