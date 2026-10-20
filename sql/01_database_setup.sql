-- ============================================================================
-- SCRIPT: 01_database_setup.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Clean and simple database creation script.
-- ============================================================================

-- If the database already exists from a previous run, remove it
DROP DATABASE IF EXISTS ev_charging_db;

-- Create the database
-- In MySQL 8, the default character set is already utf8mb4
CREATE DATABASE ev_charging_db;

-- Select this database for all subsequent queries
USE ev_charging_db;
