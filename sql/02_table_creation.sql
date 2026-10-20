-- ============================================================================
-- SCRIPT: 02_table_creation.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Creates the 8 normalized tables (7 Strong Entities + 1 Weak Entity)
--              using clean, standard, beginner-friendly SQL syntax with clear
--              primary keys, foreign keys, weak entity composite keys, and checks.
-- ============================================================================

USE ev_charging_db;

-- ----------------------------------------------------------------------------
-- Drop existing tables if they already exist (reverse dependency order)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS charger_maintenance_logs;
DROP TABLE IF EXISTS charging_sessions;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS tariffs;
DROP TABLE IF EXISTS chargers;
DROP TABLE IF EXISTS stations;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS users;

-- ============================================================================
-- 1. USERS TABLE
-- Stores drivers (CUSTOMER), station owners (OWNER), and admins (ADMIN).
-- ============================================================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    role ENUM('CUSTOMER', 'OWNER', 'ADMIN') NOT NULL DEFAULT 'CUSTOMER',
    status ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. VEHICLES TABLE
-- Stores electric vehicles owned by users.
-- One user can own multiple vehicles.
-- ============================================================================
CREATE TABLE vehicles (
    vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    vehicle_number VARCHAR(20) NOT NULL UNIQUE,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    battery_capacity_kwh DECIMAL(6,2) NOT NULL CHECK (battery_capacity_kwh > 0),
    connector_type ENUM('TYPE_2', 'CCS', 'CHADEMO') NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- ============================================================================
-- 3. STATIONS TABLE
-- Physical charging station hubs owned by station owners.
-- ============================================================================
CREATE TABLE stations (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    owner_id INT NOT NULL,
    station_name VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    status ENUM('ACTIVE', 'INACTIVE', 'MAINTENANCE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (owner_id) REFERENCES users(user_id)
);

-- ============================================================================
-- 4. CHARGERS TABLE
-- Individual charging points/guns installed at stations.
-- One station has multiple chargers.
-- ============================================================================
CREATE TABLE chargers (
    charger_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    charger_number VARCHAR(20) NOT NULL,
    charger_type ENUM('AC', 'DC_FAST', 'DC_ULTRA_FAST') NOT NULL,
    power_kw DECIMAL(6,2) NOT NULL CHECK (power_kw > 0),
    status ENUM('AVAILABLE', 'OCCUPIED', 'MAINTENANCE', 'INACTIVE') NOT NULL DEFAULT 'AVAILABLE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (station_id) REFERENCES stations(station_id),
    UNIQUE (station_id, charger_number)
);

-- ============================================================================
-- 5. TARIFFS TABLE
-- Energy pricing schedules per station and charger type.
-- Has peak hours price and off-peak hours price.
-- ============================================================================
CREATE TABLE tariffs (
    tariff_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    charger_type ENUM('AC', 'DC_FAST', 'DC_ULTRA_FAST') NOT NULL,
    peak_price_per_kwh DECIMAL(8,2) NOT NULL CHECK (peak_price_per_kwh > 0),
    off_peak_price_per_kwh DECIMAL(8,2) NOT NULL CHECK (off_peak_price_per_kwh > 0),
    peak_start_time TIME NOT NULL,
    peak_end_time TIME NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE DEFAULT NULL,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',

    FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- ============================================================================
-- 6. BOOKINGS TABLE
-- Advance reservations made by users for a specific charger slot.
-- ============================================================================
CREATE TABLE bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    charger_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status ENUM('BOOKED', 'CANCELLED', 'COMPLETED', 'NO_SHOW') NOT NULL DEFAULT 'BOOKED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME DEFAULT NULL,

    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    FOREIGN KEY (charger_id) REFERENCES chargers(charger_id),
    CHECK (end_time > start_time)
);

-- ============================================================================
-- 7. CHARGING SESSIONS TABLE
-- Real-time energy dispensing log for each booking.
-- Each booking can have at most one session (booking_id is UNIQUE).
-- ============================================================================
CREATE TABLE charging_sessions (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL UNIQUE,
    start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME DEFAULT NULL,
    energy_consumed_kwh DECIMAL(8,2) DEFAULT NULL CHECK (energy_consumed_kwh IS NULL OR energy_consumed_kwh >= 0),
    price_per_kwh DECIMAL(8,2) DEFAULT NULL CHECK (price_per_kwh IS NULL OR price_per_kwh >= 0),
    pricing_period ENUM('PEAK', 'OFF_PEAK') DEFAULT NULL,
    total_cost DECIMAL(10,2) DEFAULT NULL CHECK (total_cost IS NULL OR total_cost >= 0),
    status ENUM('ACTIVE', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

-- ============================================================================
-- 8. CHARGER_MAINTENANCE_LOGS TABLE (WEAK ENTITY)
-- Represents scheduled inspections, fault tickets, repairs, and service logs.
-- This is a WEAK ENTITY whose existence strictly depends on the identifying
-- strong entity 'chargers'. A maintenance log has no identity without a charger.
--
-- WEAK ENTITY ARCHITECTURAL SPECIFICATION:
--   - Identifying (Strong) Entity : chargers (identified by charger_id)
--   - Identifying Relationship    : maintains_logs (chargers HAS-A maintenance_log)
--   - Partial Key (Discriminator) : log_seq (sequential counter 1, 2, 3... per charger)
--   - Composite Primary Key       : PRIMARY KEY (charger_id, log_seq)
--   - Identifying Foreign Key     : FOREIGN KEY (charger_id) REFERENCES chargers(charger_id)
--                                   ON DELETE CASCADE
--   - Existence Dependency        : Total participation. If a charger is decommissioned
--                                   or deleted, all its maintenance logs are cascade-deleted.
-- ============================================================================
CREATE TABLE charger_maintenance_logs (
    charger_id INT NOT NULL,
    log_seq INT NOT NULL CHECK (log_seq > 0),
    maintenance_date DATE NOT NULL,
    issue_type ENUM('ROUTINE_INSPECTION', 'CONNECTOR_FAULT', 'FIRMWARE_UPDATE', 'CABLE_REPAIR', 'COOLING_FAILURE', 'CALIBRATION') NOT NULL,
    description VARCHAR(255) NOT NULL,
    technician_name VARCHAR(100) NOT NULL,
    cost DECIMAL(8,2) NOT NULL DEFAULT 0.00 CHECK (cost >= 0),
    status ENUM('SCHEDULED', 'IN_PROGRESS', 'RESOLVED') NOT NULL DEFAULT 'SCHEDULED',
    resolution_notes TEXT DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (charger_id, log_seq),
    FOREIGN KEY (charger_id) REFERENCES chargers(charger_id) ON DELETE CASCADE
);

