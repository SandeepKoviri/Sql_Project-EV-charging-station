-- ============================================================================
-- SCRIPT: 03_sample_data.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Populates ev_charging_db with a concise, clean, and focused
--              sample dataset (approx 10-15 records per entity) strictly
--              maintaining all foreign keys, unique constraints, and domain rules.
--
-- DATASET SUMMARY (Concise 10-15 Scale):
--   - 12 Users (8 Customers, 3 Station Owners, 1 Admin)
--   - 14 Vehicles (Realistic Indian EV models with battery & connector specs)
--   - 5 Stations (Metro hubs across Bengaluru, Hyderabad, Mumbai)
--   - 14 Chargers (AC, DC_FAST, DC_ULTRA_FAST with mixed statuses)
--   - 12 Tariffs (Peak & Off-Peak schedules with time windows)
--   - 15 Bookings (COMPLETED, BOOKED, CANCELLED, NO_SHOW)
--   - 12 Charging Sessions (10 COMPLETED with ToU settlement, 2 ACTIVE)
--   - 15 Charger Maintenance Logs (WEAK ENTITY: scoped 1..N per charger)
-- ============================================================================

USE ev_charging_db;

-- ----------------------------------------------------------------------------
-- 1. USERS DATA (12 Users: 8 Customers, 3 Owners, 1 Admin)
-- ----------------------------------------------------------------------------
INSERT INTO users (user_id, name, email, phone, role, status, created_at) VALUES
-- Customers (EV Drivers)
(1, 'Rajesh Sharma', 'rajesh.sharma@example.in', '+91-98201-12345', 'CUSTOMER', 'ACTIVE', '2025-01-10 08:30:00'),
(2, 'Priya Sundaram', 'priya.sundaram@example.in', '+91-98450-23456', 'CUSTOMER', 'ACTIVE', '2025-01-12 09:15:00'),
(3, 'Amit Patel', 'amit.patel@example.in', '+91-98791-34567', 'CUSTOMER', 'ACTIVE', '2025-01-15 11:45:00'),
(4, 'Ananya Iyer', 'ananya.iyer@example.in', '+91-98840-45678', 'CUSTOMER', 'ACTIVE', '2025-01-18 14:20:00'),
(5, 'Vikram Malhotra', 'vikram.malhotra@example.in', '+91-98110-56789', 'CUSTOMER', 'ACTIVE', '2025-01-20 16:10:00'),
(6, 'Sneha Reddy', 'sneha.reddy@example.in', '+91-98490-67890', 'CUSTOMER', 'ACTIVE', '2025-01-22 10:00:00'),
(7, 'Rohan Verma', 'rohan.verma@example.in', '+91-99300-78901', 'CUSTOMER', 'ACTIVE', '2025-01-25 17:35:00'),
(8, 'Divya Nair', 'divya.nair@example.in', '+91-97450-89012', 'CUSTOMER', 'ACTIVE', '2025-02-01 12:40:00'),

-- Station Owners (CPOs)
(9, 'Suresh Singhania', 'suresh.singhania@voltinfra.in', '+91-98200-55501', 'OWNER', 'ACTIVE', '2024-12-01 10:00:00'),
(10, 'Venkat Raman', 'venkat.raman@cybervolt.in', '+91-98480-55502', 'OWNER', 'ACTIVE', '2024-12-05 11:30:00'),
(11, 'Farhan Merchant', 'farhan.merchant@bkcenergy.in', '+91-98210-55503', 'OWNER', 'ACTIVE', '2024-12-10 14:15:00'),

-- System Administrator
(12, 'Aditya Chopra', 'aditya.admin@evnetwork.in', '+91-98200-99901', 'ADMIN', 'ACTIVE', '2024-11-01 08:00:00');

-- ----------------------------------------------------------------------------
-- 2. VEHICLES DATA (14 Vehicles belonging to Customers 1 to 8)
-- ----------------------------------------------------------------------------
INSERT INTO vehicles (vehicle_id, user_id, vehicle_number, brand, model, battery_capacity_kwh, connector_type, created_at) VALUES
(1, 1, 'MH-02-EV-1001', 'Tata', 'Nexon EV Max', 40.50, 'CCS', '2025-01-11 10:00:00'),
(2, 1, 'MH-02-EV-1002', 'MG', 'Comet EV', 17.30, 'TYPE_2', '2025-02-01 11:30:00'),
(3, 2, 'KA-01-EV-2001', 'Tata', 'Tiago EV', 24.00, 'CCS', '2025-01-13 14:20:00'),
(4, 2, 'KA-01-EV-2002', 'Hyundai', 'Ioniq 5', 72.60, 'CCS', '2025-02-10 15:00:00'),
(5, 3, 'GJ-01-EV-3001', 'MG', 'ZS EV', 50.30, 'CCS', '2025-01-16 12:00:00'),
(6, 4, 'TN-09-EV-4001', 'Mahindra', 'XUV400', 39.40, 'CCS', '2025-01-19 16:30:00'),
(7, 5, 'DL-01-EV-5001', 'Kia', 'EV6', 77.40, 'CCS', '2025-01-21 09:10:00'),
(8, 5, 'DL-01-EV-5002', 'BMW', 'i4 eDrive40', 83.90, 'CCS', '2025-02-15 10:45:00'),
(9, 6, 'TS-09-EV-6001', 'Tata', 'Nexon EV Prime', 30.20, 'CCS', '2025-01-23 11:15:00'),
(10, 6, 'TS-09-EV-6002', 'BYD', 'Atto 3', 60.48, 'CCS', '2025-02-18 14:00:00'),
(11, 7, 'MH-12-EV-7001', 'Hyundai', 'Kona Electric', 39.20, 'CCS', '2025-01-26 13:20:00'),
(12, 8, 'KL-07-EV-8001', 'Tata', 'Punch EV', 35.00, 'CCS', '2025-02-02 10:30:00'),
(13, 3, 'GJ-01-EV-3002', 'Tata', 'Nexon EV Prime', 30.20, 'CCS', '2025-02-25 10:00:00'),
(14, 7, 'MH-12-EV-7002', 'Nissan', 'Leaf (Import)', 40.00, 'CHADEMO', '2025-02-27 12:10:00');

-- ----------------------------------------------------------------------------
-- 3. STATIONS DATA (5 Stations in Major Indian Metros)
-- ----------------------------------------------------------------------------
INSERT INTO stations (station_id, owner_id, station_name, address, city, state, latitude, longitude, status, created_at) VALUES
(1, 9, 'AuraCharge Indiranagar Hub', '100 Feet Road, HAL 2nd Stage, Indiranagar', 'Bengaluru', 'Karnataka', 12.9718915, 77.6411545, 'ACTIVE', '2025-01-01 08:00:00'),
(2, 9, 'GreenVolt Electronic City Supercharger', 'Hosur Road, Phase 1, Near Toll Plaza', 'Bengaluru', 'Karnataka', 12.8452140, 77.6601680, 'ACTIVE', '2025-01-05 09:30:00'),
(3, 10, 'CyberCharge Hitec City Plaza', 'Mindspace Circle, Hitec City, Madhapur', 'Hyderabad', 'Telangana', 17.4474120, 78.3762300, 'ACTIVE', '2025-01-08 10:15:00'),
(4, 10, 'DeccanPower Gachibowli Station', 'ISB Road, Financial District, Gachibowli', 'Hyderabad', 'Telangana', 17.4123480, 78.3411200, 'MAINTENANCE', '2025-01-10 11:00:00'),
(5, 11, 'EcoDrive BKC Central', 'G Block, Bandra Kurla Complex, Bandra East', 'Mumbai', 'Maharashtra', 19.0657120, 72.8687350, 'ACTIVE', '2025-01-12 14:00:00');

-- ----------------------------------------------------------------------------
-- 4. CHARGERS DATA (14 Chargers across 5 Stations)
-- ----------------------------------------------------------------------------
INSERT INTO chargers (charger_id, station_id, charger_number, charger_type, power_kw, status, created_at) VALUES
-- Station 1: AuraCharge Indiranagar (4 chargers)
(1, 1, 'IND-AC-01', 'AC', 22.00, 'AVAILABLE', '2025-01-02 09:00:00'),
(2, 1, 'IND-DC-02', 'DC_FAST', 50.00, 'AVAILABLE', '2025-01-02 09:00:00'),
(3, 1, 'IND-DC-03', 'DC_FAST', 60.00, 'OCCUPIED', '2025-01-02 09:00:00'),
(4, 1, 'IND-UDC-04', 'DC_ULTRA_FAST', 120.00, 'AVAILABLE', '2025-01-02 09:00:00'),

-- Station 2: GreenVolt Electronic City (3 chargers)
(5, 2, 'EC-AC-01', 'AC', 11.00, 'AVAILABLE', '2025-01-06 10:00:00'),
(6, 2, 'EC-DC-02', 'DC_FAST', 60.00, 'AVAILABLE', '2025-01-06 10:00:00'),
(7, 2, 'EC-UDC-03', 'DC_ULTRA_FAST', 150.00, 'OCCUPIED', '2025-01-06 10:00:00'),

-- Station 3: CyberCharge Hitec City (3 chargers)
(8, 3, 'HTC-AC-01', 'AC', 22.00, 'AVAILABLE', '2025-01-09 11:00:00'),
(9, 3, 'HTC-DC-02', 'DC_FAST', 60.00, 'AVAILABLE', '2025-01-09 11:00:00'),
(10, 3, 'HTC-UDC-03', 'DC_ULTRA_FAST', 120.00, 'AVAILABLE', '2025-01-09 11:00:00'),

-- Station 4: DeccanPower Gachibowli (2 chargers - Maintenance)
(11, 4, 'GCB-AC-01', 'AC', 22.00, 'MAINTENANCE', '2025-01-11 12:00:00'),
(12, 4, 'GCB-DC-02', 'DC_FAST', 60.00, 'MAINTENANCE', '2025-01-11 12:00:00'),

-- Station 5: EcoDrive BKC Mumbai (2 chargers)
(13, 5, 'BKC-DC-01', 'DC_FAST', 60.00, 'AVAILABLE', '2025-01-13 15:00:00'),
(14, 5, 'BKC-UDC-02', 'DC_ULTRA_FAST', 150.00, 'AVAILABLE', '2025-01-13 15:00:00');

-- ----------------------------------------------------------------------------
-- 5. TARIFFS DATA (12 Tariffs across Stations and Charger Types)
-- ----------------------------------------------------------------------------
INSERT INTO tariffs (tariff_id, station_id, charger_type, peak_price_per_kwh, off_peak_price_per_kwh, peak_start_time, peak_end_time, effective_from, effective_to, status) VALUES
-- Station 1 (AuraCharge BLR)
(1, 1, 'AC', 12.00, 8.50, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),
(2, 1, 'DC_FAST', 18.00, 13.00, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),
(3, 1, 'DC_ULTRA_FAST', 24.00, 17.50, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),

-- Station 2 (GreenVolt BLR)
(4, 2, 'AC', 11.50, 8.00, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),
(5, 2, 'DC_FAST', 17.50, 12.50, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),
(6, 2, 'DC_ULTRA_FAST', 23.00, 16.50, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),

-- Station 3 (CyberCharge HYD)
(7, 3, 'AC', 12.50, 9.00, '07:00:00', '19:00:00', '2025-01-01', NULL, 'ACTIVE'),
(8, 3, 'DC_FAST', 18.50, 13.50, '07:00:00', '19:00:00', '2025-01-01', NULL, 'ACTIVE'),
(9, 3, 'DC_ULTRA_FAST', 25.00, 18.00, '07:00:00', '19:00:00', '2025-01-01', NULL, 'ACTIVE'),

-- Station 4 (DeccanPower HYD)
(10, 4, 'AC', 12.00, 8.50, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),
(11, 4, 'DC_FAST', 18.00, 13.00, '06:00:00', '18:00:00', '2025-01-01', NULL, 'ACTIVE'),

-- Station 5 (EcoDrive BKC Mumbai)
(12, 5, 'DC_FAST', 19.50, 14.50, '08:00:00', '20:00:00', '2025-01-01', NULL, 'ACTIVE');

-- ----------------------------------------------------------------------------
-- 6. BOOKINGS DATA (15 Bookings)
-- 1-10: COMPLETED (corresponds to completed charging sessions)
-- 11-12: BOOKED (active ongoing charging sessions)
-- 13: BOOKED (future reservation)
-- 14: CANCELLED (cancelled slot)
-- 15: NO_SHOW (missed slot)
-- ----------------------------------------------------------------------------
INSERT INTO bookings (booking_id, user_id, vehicle_id, charger_id, start_time, end_time, status, created_at, cancelled_at) VALUES
-- Completed Bookings (1 to 10)
(1, 1, 1, 2, '2025-02-01 10:00:00', '2025-02-01 11:00:00', 'COMPLETED', '2025-01-31 18:00:00', NULL),
(2, 2, 3, 5, '2025-02-01 20:00:00', '2025-02-01 22:00:00', 'COMPLETED', '2025-02-01 15:30:00', NULL),
(3, 3, 5, 2, '2025-02-02 11:30:00', '2025-02-02 12:30:00', 'COMPLETED', '2025-02-02 08:00:00', NULL),
(4, 4, 6, 1, '2025-02-02 14:00:00', '2025-02-02 16:00:00', 'COMPLETED', '2025-02-01 20:00:00', NULL),
(5, 5, 7, 4, '2025-02-03 09:00:00', '2025-02-03 09:45:00', 'COMPLETED', '2025-02-02 19:15:00', NULL),
(6, 6, 10, 9, '2025-02-03 15:00:00', '2025-02-03 16:00:00', 'COMPLETED', '2025-02-03 10:00:00', NULL),
(7, 7, 11, 13, '2025-02-04 10:30:00', '2025-02-04 11:30:00', 'COMPLETED', '2025-02-03 21:00:00', NULL),
(8, 8, 12, 6, '2025-02-04 19:30:00', '2025-02-04 20:30:00', 'COMPLETED', '2025-02-04 12:00:00', NULL),
(9, 1, 1, 4, '2025-02-05 17:00:00', '2025-02-05 17:45:00', 'COMPLETED', '2025-02-05 11:00:00', NULL),
(10, 2, 4, 7, '2025-02-05 21:00:00', '2025-02-05 22:00:00', 'COMPLETED', '2025-02-05 14:00:00', NULL),

-- Active Ongoing Bookings (11 and 12)
(11, 1, 1, 3, '2026-09-30 19:00:00', '2026-09-30 20:30:00', 'BOOKED', '2026-09-30 18:00:00', NULL),
(12, 6, 10, 7, '2026-09-30 19:15:00', '2026-09-30 20:15:00', 'BOOKED', '2026-09-30 18:30:00', NULL),

-- Upcoming Reservation (13)
(13, 3, 5, 2, '2026-10-01 10:00:00', '2026-10-01 11:00:00', 'BOOKED', '2026-09-30 14:00:00', NULL),

-- Cancelled Reservation (14)
(14, 5, 7, 4, '2025-02-06 14:00:00', '2025-02-06 15:00:00', 'CANCELLED', '2025-02-05 19:00:00', '2025-02-06 08:30:00'),

-- No-Show Reservation (15)
(15, 4, 6, 1, '2025-02-07 13:00:00', '2025-02-07 15:00:00', 'NO_SHOW', '2025-02-06 20:00:00', NULL);

-- ----------------------------------------------------------------------------
-- 7. CHARGING SESSIONS DATA (12 Sessions: 10 COMPLETED, 2 ACTIVE)
-- Exact calculation: total_cost = ROUND(energy_consumed_kwh * price_per_kwh, 2)
-- Peak window: Stn 1,2,4 (06:00-18:00); Stn 3 (07:00-19:00); Stn 5 (08:00-20:00)
-- ----------------------------------------------------------------------------
INSERT INTO charging_sessions (session_id, booking_id, start_time, end_time, energy_consumed_kwh, price_per_kwh, pricing_period, total_cost, status, created_at) VALUES
-- S01: Booking 1 (Stn 1, Charger 2 DC_FAST, 10:05 PEAK -> ₹18.00)
(1, 1, '2025-02-01 10:05:00', '2025-02-01 10:55:00', 32.50, 18.00, 'PEAK', 585.00, 'COMPLETED', '2025-02-01 10:05:00'),

-- S02: Booking 2 (Stn 2, Charger 5 AC, 20:10 OFF_PEAK -> ₹8.00)
(2, 2, '2025-02-01 20:10:00', '2025-02-01 21:50:00', 18.40, 8.00, 'OFF_PEAK', 147.20, 'COMPLETED', '2025-02-01 20:10:00'),

-- S03: Booking 3 (Stn 1, Charger 2 DC_FAST, 11:32 PEAK -> ₹18.00)
(3, 3, '2025-02-02 11:32:00', '2025-02-02 12:25:00', 38.20, 18.00, 'PEAK', 687.60, 'COMPLETED', '2025-02-02 11:32:00'),

-- S04: Booking 4 (Stn 1, Charger 1 AC, 14:05 PEAK -> ₹12.00)
(4, 4, '2025-02-02 14:05:00', '2025-02-02 15:50:00', 22.00, 12.00, 'PEAK', 264.00, 'COMPLETED', '2025-02-02 14:05:00'),

-- S05: Booking 5 (Stn 1, Charger 4 DC_ULTRA_FAST, 09:02 PEAK -> ₹24.00)
(5, 5, '2025-02-03 09:02:00', '2025-02-03 09:42:00', 48.60, 24.00, 'PEAK', 1166.40, 'COMPLETED', '2025-02-03 09:02:00'),

-- S06: Booking 6 (Stn 3, Charger 9 DC_FAST, 15:08 PEAK -> ₹18.50)
(6, 6, '2025-02-03 15:08:00', '2025-02-03 15:58:00', 25.40, 18.50, 'PEAK', 469.90, 'COMPLETED', '2025-02-03 15:08:00'),

-- S07: Booking 7 (Stn 5, Charger 13 DC_FAST, 10:35 PEAK -> ₹19.50)
(7, 7, '2025-02-04 10:35:00', '2025-02-04 11:25:00', 31.80, 19.50, 'PEAK', 620.10, 'COMPLETED', '2025-02-04 10:35:00'),

-- S08: Booking 8 (Stn 2, Charger 6 DC_FAST, 19:35 OFF_PEAK -> ₹12.50)
(8, 8, '2025-02-04 19:35:00', '2025-02-04 20:25:00', 28.00, 12.50, 'OFF_PEAK', 350.00, 'COMPLETED', '2025-02-04 19:35:00'),

-- S09: Booking 9 (Stn 1, Charger 4 DC_ULTRA_FAST, 17:02 PEAK -> ₹24.00)
(9, 9, '2025-02-05 17:02:00', '2025-02-05 17:40:00', 34.00, 24.00, 'PEAK', 816.00, 'COMPLETED', '2025-02-05 17:02:00'),

-- S10: Booking 10 (Stn 2, Charger 7 DC_ULTRA_FAST, 21:05 OFF_PEAK -> ₹16.50)
(10, 10, '2025-02-05 21:05:00', '2025-02-05 21:55:00', 52.00, 16.50, 'OFF_PEAK', 858.00, 'COMPLETED', '2025-02-05 21:05:00'),

-- Active Ongoing Charging Sessions (11 and 12)
(11, 11, '2026-09-30 19:05:00', NULL, NULL, NULL, NULL, NULL, 'ACTIVE', '2026-09-30 19:05:00'),
(12, 12, '2026-09-30 19:20:00', NULL, NULL, NULL, NULL, NULL, 'ACTIVE', '2026-09-30 19:20:00');

-- ----------------------------------------------------------------------------
-- 8. CHARGER MAINTENANCE LOGS DATA (15 Records - Weak Entity)
-- Notice that log_seq (the partial key) restarts at 1 for each charger!
-- ----------------------------------------------------------------------------
INSERT INTO charger_maintenance_logs (charger_id, log_seq, maintenance_date, issue_type, description, technician_name, cost, status, resolution_notes, created_at) VALUES
-- Charger 1 (Stn 1 - Indiranagar AC 22kW)
(1, 1, '2025-01-05', 'ROUTINE_INSPECTION', 'Initial commissioning, Earth resistance and RCD trip timing test', 'Ramesh Kumar', 1200.00, 'RESOLVED', 'All safety interlocks functioning within OEM specifications', '2025-01-05 09:00:00'),
(1, 2, '2025-02-18', 'CALIBRATION', 'Periodic revenue-grade energy meter re-calibration for billing accuracy', 'Prakash Joshi', 1500.00, 'RESOLVED', 'Class 1.0 bidirectional meter certified within +/- 0.5% tolerance', '2025-02-18 10:30:00'),

-- Charger 2 (Stn 1 - Indiranagar DC_FAST 60kW)
(2, 1, '2025-01-08', 'FIRMWARE_UPDATE', 'Firmware patch v2.4.1 applied to resolve CAN-bus communication drops on Tata EVs', 'Prakash Joshi', 500.00, 'RESOLVED', 'Firmware flashed; 3 handshake test cycles completed successfully', '2025-01-08 16:00:00'),

-- Charger 3 (Stn 1 - Indiranagar DC_ULTRA_FAST 150kW)
(3, 1, '2025-01-22', 'CABLE_REPAIR', 'Heavy-duty CCS2 liquid-cooled cable sheath re-sleeving and strain relief replacement', 'Ramesh Kumar', 3200.00, 'RESOLVED', 'Cable strain relief re-sleeved; pressure and insulation tested', '2025-01-22 13:15:00'),

-- Charger 4 (Stn 1 - Indiranagar DC_ULTRA_FAST 120kW)
(4, 1, '2025-02-05', 'ROUTINE_INSPECTION', 'Air intake ventilation filter vacuuming and cooling fan bearing lubrication', 'Suresh Babu', 800.00, 'RESOLVED', 'Air intake flow restored to 450 CFM baseline', '2025-02-05 11:00:00'),

-- Charger 6 (Stn 2 - Electronic City DC_FAST 60kW)
(6, 1, '2025-01-18', 'CONNECTOR_FAULT', 'CCS2 gun mechanical latch sticking intermittently during decoupling', 'Suresh Babu', 1800.00, 'RESOLVED', 'Latch mechanism lubricated and return spring replaced', '2025-01-18 15:30:00'),

-- Charger 7 (Stn 2 - Electronic City DC_ULTRA_FAST 150kW)
(7, 1, '2025-01-28', 'FIRMWARE_UPDATE', 'OCPP 2.0.1 protocol stack upgrade for dynamic ToU price signalling', 'Prakash Joshi', 600.00, 'RESOLVED', 'OCPP JSON WebSocket connection verified with central server', '2025-01-28 10:00:00'),

-- Charger 8 (Stn 3 - Hitec City AC 22kW)
(8, 1, '2025-01-12', 'ROUTINE_INSPECTION', 'Quarterly ground loop resistance check and lightning surge arrester audit', 'Vikram Rao', 950.00, 'RESOLVED', 'Earth pit resistance 1.8 Ohms; surge arrester healthy', '2025-01-12 10:00:00'),

-- Charger 9 (Stn 3 - Hitec City DC_FAST 60kW)
(9, 1, '2025-02-12', 'CALIBRATION', 'High-current DC shunt calibration and thermal cut-off sensor verification', 'Vikram Rao', 1600.00, 'RESOLVED', 'Thermal cutoff verified at 65 deg C under simulated load', '2025-02-12 12:00:00'),

-- Charger 10 (Stn 3 - Hitec City DC_ULTRA_FAST 120kW)
(10, 1, '2025-02-20', 'ROUTINE_INSPECTION', 'High-voltage DC contactor inspection and contactless temperature scan', 'Vikram Rao', 1400.00, 'RESOLVED', 'Contactors show zero electrical pitting; infrared thermography clear', '2025-02-20 14:30:00'),

-- Charger 11 (Stn 4 - Gachibowli AC 22kW - Currently in MAINTENANCE status)
(11, 1, '2025-01-15', 'CONNECTOR_FAULT', 'Type 2 connector locking pin damaged by driver drive-away attempt', 'Ramesh Kumar', 2800.00, 'IN_PROGRESS', 'OEM locking pin replacement part ordered; dispatch tracking active', '2025-01-15 10:00:00'),
(11, 2, '2025-02-10', 'ROUTINE_INSPECTION', 'Comprehensive electrical safety check prior to bay re-commissioning', 'Suresh Babu', 750.00, 'SCHEDULED', 'Awaiting replacement connector installation before final sign-off', '2025-02-10 11:30:00'),

-- Charger 12 (Stn 4 - Gachibowli DC_FAST 60kW - Currently in MAINTENANCE status)
(12, 1, '2025-01-20', 'COOLING_FAILURE', 'Liquid coolant circulation pump motor failure triggering hardware thermal fault', 'Vikram Rao', 6500.00, 'IN_PROGRESS', 'Coolant pump replacement in progress; secondary radiator flush pending', '2025-01-20 14:00:00'),

-- Charger 13 (Stn 5 - BKC Mumbai DC_FAST 60kW)
(13, 1, '2025-01-25', 'FIRMWARE_UPDATE', 'Touchscreen display controller firmware upgrade to resolve touch latency', 'Deepak Mehta', 700.00, 'RESOLVED', 'Display UI responsiveness restored to < 50ms latency', '2025-01-25 11:00:00'),

-- Charger 14 (Stn 5 - BKC Mumbai DC_ULTRA_FAST 150kW)
(14, 1, '2025-02-15', 'COOLING_FAILURE', 'Dielectric coolant top-up and pressure relief valve purge', 'Deepak Mehta', 2200.00, 'RESOLVED', 'Cooling loop refilled with OEM dielectric fluid; zero air pockets detected', '2025-02-15 16:00:00');

-- ----------------------------------------------------------------------------
-- Confirmation Summary Count Query
-- ----------------------------------------------------------------------------
SELECT 'users' AS entity, COUNT(*) AS total_count FROM users
UNION ALL
SELECT 'vehicles', COUNT(*) FROM vehicles
UNION ALL
SELECT 'stations', COUNT(*) FROM stations
UNION ALL
SELECT 'chargers', COUNT(*) FROM chargers
UNION ALL
SELECT 'tariffs', COUNT(*) FROM tariffs
UNION ALL
SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL
SELECT 'charging_sessions', COUNT(*) FROM charging_sessions
UNION ALL
SELECT 'charger_maintenance_logs', COUNT(*) FROM charger_maintenance_logs;

