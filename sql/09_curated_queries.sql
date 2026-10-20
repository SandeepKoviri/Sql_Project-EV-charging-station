-- ============================================================================
-- SCRIPT: 09_curated_queries.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Curated 40 Essential SQL Queries (Q01 to Q40)
--              A comprehensive showcase spanning 4 difficulty tiers:
--                - TIER 1: Simple / Basic Queries (Q01 - Q12)
--                - TIER 2: Moderate / Intermediate Queries (Q13 - Q24)
--                - TIER 3: Hard / Advanced Queries (Q25 - Q36)
--                - TIER 4: Weak Entity Operational & Audit Queries (Q37 - Q40)
-- ============================================================================

USE ev_charging_db;

-- ============================================================================
-- TIER 1: SIMPLE / BASIC QUERIES (Q01 - Q12)
-- Topics: Filtering, Pattern Matching, Date/String Functions, Basic Aggregation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q01: Active Customer Directory
-- Description: Retrieve active EV drivers (CUSTOMER) sorted alphabetically.
-- Concepts: SELECT, WHERE, ORDER BY
-- ----------------------------------------------------------------------------
SELECT user_id, name, email, phone 
FROM users 
WHERE role = 'CUSTOMER' AND status = 'ACTIVE' 
ORDER BY name ASC;

-- ----------------------------------------------------------------------------
-- Q02: Formatted Vehicle Summary
-- Description: Display vehicle registration, brand, and connector specifications.
-- Concepts: CONCAT, Column Aliasing, String Formatting
-- ----------------------------------------------------------------------------
SELECT vehicle_id, vehicle_number, 
       CONCAT(brand, ' ', model) AS vehicle_model,
       CONCAT('Connector: ', connector_type, ' (', battery_capacity_kwh, ' kWh)') AS specs
FROM vehicles 
ORDER BY brand ASC;

-- ----------------------------------------------------------------------------
-- Q03: High-Power Fast Charger Lookup
-- Description: Identify high-output chargers (50+ kW) ordered by power capacity.
-- Concepts: Numeric comparison (>=), ORDER BY DESC
-- ----------------------------------------------------------------------------
SELECT charger_id, station_id, charger_number, charger_type, power_kw 
FROM chargers 
WHERE power_kw >= 50.00 
ORDER BY power_kw DESC;

-- ----------------------------------------------------------------------------
-- Q04: Compatible Vehicle Connector Filter
-- Description: Find vehicles supporting fast charging standards (CCS or TYPE_2).
-- Concepts: Set membership (IN operator)
-- ----------------------------------------------------------------------------
SELECT vehicle_id, vehicle_number, brand, model, connector_type 
FROM vehicles 
WHERE connector_type IN ('CCS', 'TYPE_2');

-- ----------------------------------------------------------------------------
-- Q05: Real-Time Hardware Availability
-- Description: List all chargers currently available for booking.
-- Concepts: Status filtering, Exact matching
-- ----------------------------------------------------------------------------
SELECT charger_id, station_id, charger_number, charger_type, power_kw, status 
FROM chargers 
WHERE status = 'AVAILABLE';

-- ----------------------------------------------------------------------------
-- Q06: Peak-Hours Tariff Pricing & Surcharge Analysis
-- Description: Find tariffs where peak price exceeds ₹15.00 and compute peak premium.
-- Concepts: WHERE filter, Arithmetic expression, Derived columns
-- ----------------------------------------------------------------------------
SELECT tariff_id, station_id, charger_type, peak_price_per_kwh, off_peak_price_per_kwh,
       (peak_price_per_kwh - off_peak_price_per_kwh) AS peak_surcharge
FROM tariffs 
WHERE peak_price_per_kwh > 15.00 
ORDER BY peak_surcharge DESC;

-- ----------------------------------------------------------------------------
-- Q07: Booking Date & Time Extraction
-- Description: Extract date, start time, weekday name, and duration in minutes.
-- Concepts: DATE(), TIME(), DAYNAME(), TIMESTAMPDIFF(MINUTE, ...)
-- ----------------------------------------------------------------------------
SELECT booking_id, user_id, 
       DATE(start_time) AS booking_date, 
       TIME(start_time) AS start_time_only, 
       DAYNAME(start_time) AS day_of_week, 
       TIMESTAMPDIFF(MINUTE, start_time, end_time) AS duration_minutes, 
       status 
FROM bookings;

-- ----------------------------------------------------------------------------
-- Q08: Booking Cancellations Audit
-- Description: Retrieve cancelled bookings along with cancellation timestamp.
-- Concepts: IS NOT NULL, Status matching
-- ----------------------------------------------------------------------------
SELECT booking_id, user_id, charger_id, start_time, cancelled_at 
FROM bookings 
WHERE status = 'CANCELLED' AND cancelled_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Q09: High-Energy Charging Sessions
-- Description: Find completed sessions consuming over 30 kWh, rounding total billing.
-- Concepts: ROUND(), Multiple conditions (AND), Threshold filtering
-- ----------------------------------------------------------------------------
SELECT session_id, booking_id, energy_consumed_kwh, price_per_kwh, 
       ROUND(total_cost) AS rounded_cost_inr 
FROM charging_sessions 
WHERE energy_consumed_kwh > 30.00 AND status = 'COMPLETED';

-- ----------------------------------------------------------------------------
-- Q10: Network KPI Summary (Aggregations)
-- Description: Compute total energy dispensed, total platform revenue, and average bill.
-- Concepts: COUNT(), SUM(), AVG(), Aggregations with ROUND()
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS completed_sessions, 
       ROUND(SUM(energy_consumed_kwh), 2) AS total_energy_dispensed_kwh, 
       ROUND(SUM(total_cost), 2) AS gross_revenue_inr, 
       ROUND(AVG(total_cost), 2) AS avg_session_cost_inr 
FROM charging_sessions 
WHERE status = 'COMPLETED';

-- ----------------------------------------------------------------------------
-- Q11: Vehicle Fleet Distribution by Brand
-- Description: Count registered electric vehicles and average battery size per brand.
-- Concepts: GROUP BY, COUNT(*), AVG()
-- ----------------------------------------------------------------------------
SELECT brand, 
       COUNT(*) AS total_registered, 
       ROUND(AVG(battery_capacity_kwh), 1) AS avg_battery_kwh 
FROM vehicles 
GROUP BY brand 
ORDER BY total_registered DESC;

-- ----------------------------------------------------------------------------
-- Q12: Charger Hardware Inventory Breakdown
-- Description: Count chargers and show capacity range (min, max, avg) per charger type.
-- Concepts: GROUP BY, MIN(), MAX(), AVG()
-- ----------------------------------------------------------------------------
SELECT charger_type, 
       COUNT(*) AS charger_count, 
       ROUND(AVG(power_kw), 1) AS avg_power_kw, 
       MIN(power_kw) AS min_kw, 
       MAX(power_kw) AS max_kw 
FROM chargers 
GROUP BY charger_type 
ORDER BY charger_count DESC;


-- ============================================================================
-- TIER 2: MODERATE / INTERMEDIATE QUERIES (Q13 - Q24)
-- Topics: Multi-Table JOINs, LEFT JOINs, GROUP BY with HAVING, Subqueries, CASE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q13: Full 5-Table Booking Audit Join
-- Description: Comprehensive log linking session, driver, vehicle, charger, and station.
-- Concepts: Multi-table INNER JOIN across 5 entities
-- ----------------------------------------------------------------------------
SELECT cs.session_id, 
       u.name AS customer_name, 
       v.vehicle_number, 
       s.station_name, 
       c.charger_number, 
       cs.energy_consumed_kwh, 
       cs.total_cost 
FROM charging_sessions cs 
JOIN bookings b ON cs.booking_id = b.booking_id 
JOIN users u ON b.user_id = u.user_id 
JOIN vehicles v ON b.vehicle_id = v.vehicle_id 
JOIN chargers c ON b.charger_id = c.charger_id 
JOIN stations s ON c.station_id = s.station_id 
WHERE cs.status = 'COMPLETED';

-- ----------------------------------------------------------------------------
-- Q14: Charger Utilization & Unbooked Asset Detection
-- Description: List all chargers and count total bookings received, including zero.
-- Concepts: LEFT JOIN, Aggregation across optional relationships
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       c.charger_number, 
       c.charger_type, 
       c.power_kw, 
       COUNT(b.booking_id) AS total_bookings_received 
FROM chargers c 
JOIN stations s ON c.station_id = s.station_id 
LEFT JOIN bookings b ON c.charger_id = b.charger_id 
GROUP BY s.station_id, s.station_name, c.charger_id, c.charger_number, c.charger_type, c.power_kw 
ORDER BY total_bookings_received DESC, s.station_name ASC;

-- ----------------------------------------------------------------------------
-- Q15: Station Revenue & Energy Performance
-- Description: Aggregate completed sessions by station: total energy sold and gross revenue.
-- Concepts: Multi-table JOIN with GROUP BY and SUM/AVG aggregations
-- ----------------------------------------------------------------------------
SELECT s.station_id, 
       s.station_name, 
       s.city, 
       COUNT(cs.session_id) AS sessions_completed, 
       ROUND(SUM(cs.energy_consumed_kwh), 2) AS total_kwh_sold, 
       ROUND(SUM(cs.total_cost), 2) AS gross_revenue_inr, 
       ROUND(AVG(cs.total_cost), 2) AS avg_charge_cost 
FROM stations s 
JOIN chargers c ON s.station_id = c.station_id 
JOIN bookings b ON c.charger_id = b.charger_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
GROUP BY s.station_id, s.station_name, s.city 
ORDER BY gross_revenue_inr DESC;

-- ----------------------------------------------------------------------------
-- Q16: Customer Lifetime Value (CLV) & Spend Profile
-- Description: Summarize completed sessions, energy drawn, and spend per user.
-- Concepts: GROUP BY on customer attributes, Multiple aggregations
-- ----------------------------------------------------------------------------
SELECT u.user_id, 
       u.name AS customer_name, 
       u.phone, 
       COUNT(cs.session_id) AS total_sessions, 
       ROUND(SUM(cs.energy_consumed_kwh), 2) AS total_kwh_consumed, 
       ROUND(SUM(cs.total_cost), 2) AS total_spent_inr 
FROM users u 
JOIN bookings b ON u.user_id = b.user_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
GROUP BY u.user_id, u.name, u.phone 
ORDER BY total_spent_inr DESC;

-- ----------------------------------------------------------------------------
-- Q17: High-Volume Stations via HAVING Filter
-- Description: Identify top stations that delivered > 50 kWh AND generated > ₹800.
-- Concepts: GROUP BY with multi-condition HAVING clause
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       s.city, 
       COUNT(cs.session_id) AS sessions_handled, 
       ROUND(SUM(cs.energy_consumed_kwh), 2) AS total_energy_kwh, 
       ROUND(SUM(cs.total_cost), 2) AS total_revenue_inr 
FROM stations s 
JOIN chargers c ON s.station_id = c.station_id 
JOIN bookings b ON c.charger_id = b.charger_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
GROUP BY s.station_id, s.station_name, s.city 
HAVING SUM(cs.energy_consumed_kwh) > 50.00 AND SUM(cs.total_cost) > 800.00;

-- ----------------------------------------------------------------------------
-- Q18: Idle Hardware Detection (Subquery with NOT IN)
-- Description: Find chargers that have never been reserved by any customer.
-- Concepts: NOT IN with independent subquery
-- ----------------------------------------------------------------------------
SELECT c.charger_id, 
       s.station_name, 
       c.charger_number, 
       c.charger_type, 
       c.power_kw 
FROM chargers c 
JOIN stations s ON c.station_id = s.station_id 
WHERE c.charger_id NOT IN (
    SELECT DISTINCT charger_id 
    FROM bookings
);

-- ----------------------------------------------------------------------------
-- Q19: Inactive Driver Discovery (Correlated Subquery with NOT EXISTS)
-- Description: List registered drivers who have never made a booking reservation.
-- Concepts: NOT EXISTS, Correlated subquery
-- ----------------------------------------------------------------------------
SELECT u.user_id, u.name, u.email, u.phone, u.created_at 
FROM users u 
WHERE u.role = 'CUSTOMER' 
  AND NOT EXISTS (
      SELECT 1 
      FROM bookings b 
      WHERE b.user_id = u.user_id
  );

-- ----------------------------------------------------------------------------
-- Q20: Above-Average Energy Sessions (Scalar Subquery)
-- Description: Find charging sessions that drew more energy than network average.
-- Concepts: Scalar subquery comparison, Subquery in WHERE clause
-- ----------------------------------------------------------------------------
SELECT cs.session_id, 
       u.name AS driver, 
       cs.energy_consumed_kwh, 
       cs.total_cost, 
       ROUND((SELECT AVG(energy_consumed_kwh) FROM charging_sessions WHERE status = 'COMPLETED'), 2) AS network_avg_kwh 
FROM charging_sessions cs 
JOIN bookings b ON cs.booking_id = b.booking_id 
JOIN users u ON b.user_id = u.user_id 
WHERE cs.status = 'COMPLETED' 
  AND cs.energy_consumed_kwh > (
      SELECT AVG(energy_consumed_kwh) 
      FROM charging_sessions 
      WHERE status = 'COMPLETED'
  )
ORDER BY cs.energy_consumed_kwh DESC;

-- ----------------------------------------------------------------------------
-- Q21: Charger Speed Classification (CASE WHEN)
-- Description: Categorize chargers into business speed tiers based on kW rating.
-- Concepts: Searched CASE statement, Categorical grouping
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       c.charger_number, 
       c.power_kw, 
       CASE 
           WHEN c.power_kw >= 100.00 THEN 'Ultra-Fast Tier (100+ kW)' 
           WHEN c.power_kw >= 50.00  THEN 'Fast Charger (50-99 kW)' 
           ELSE 'Standard AC (<50 kW)' 
       END AS speed_tier 
FROM chargers c 
JOIN stations s ON c.station_id = s.station_id 
ORDER BY c.power_kw DESC;

-- ----------------------------------------------------------------------------
-- Q22: Peak vs Off-Peak Revenue Split (Conditional Aggregation)
-- Description: Break down revenue and session counts by pricing period per station.
-- Concepts: SUM(CASE WHEN ...), Conditional aggregation
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       SUM(CASE WHEN cs.pricing_period = 'PEAK' THEN 1 ELSE 0 END) AS peak_sessions, 
       ROUND(SUM(CASE WHEN cs.pricing_period = 'PEAK' THEN cs.total_cost ELSE 0 END), 2) AS peak_revenue_inr, 
       SUM(CASE WHEN cs.pricing_period = 'OFF_PEAK' THEN 1 ELSE 0 END) AS off_peak_sessions, 
       ROUND(SUM(CASE WHEN cs.pricing_period = 'OFF_PEAK' THEN cs.total_cost ELSE 0 END), 2) AS off_peak_revenue_inr, 
       ROUND(SUM(cs.total_cost), 2) AS gross_revenue_inr 
FROM stations s 
JOIN chargers c ON s.station_id = c.station_id 
JOIN bookings b ON c.charger_id = b.charger_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
GROUP BY s.station_id, s.station_name 
ORDER BY gross_revenue_inr DESC;

-- ----------------------------------------------------------------------------
-- Q23: Commercial Payout Split: Owner Share vs Platform Fee
-- Description: Calculate 85% station owner payout and 15% platform commission.
-- Concepts: Multi-table join, Financial settlement math, Revenue share modeling
-- ----------------------------------------------------------------------------
SELECT u.name AS station_owner, 
       s.station_name, 
       ROUND(SUM(cs.total_cost), 2) AS gross_revenue, 
       ROUND(SUM(cs.total_cost) * 0.85, 2) AS owner_payout_85pct, 
       ROUND(SUM(cs.total_cost) * 0.15, 2) AS platform_commission_15pct 
FROM users u 
JOIN stations s ON u.user_id = s.owner_id 
JOIN chargers c ON s.station_id = c.station_id 
JOIN bookings b ON c.charger_id = b.charger_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
GROUP BY u.user_id, u.name, s.station_id, s.station_name 
ORDER BY gross_revenue DESC;

-- ----------------------------------------------------------------------------
-- Q24: System-Wide Entity Rollup (UNION ALL)
-- Description: Single-table operational summary showing row counts for all tables.
-- Concepts: UNION ALL, Metadata query, Executive KPI view
-- ----------------------------------------------------------------------------
SELECT 'Registered Users' AS entity, COUNT(*) AS total_count FROM users 
UNION ALL 
SELECT 'Electric Vehicles', COUNT(*) FROM vehicles 
UNION ALL 
SELECT 'Station Locations', COUNT(*) FROM stations 
UNION ALL 
SELECT 'Charger Bays', COUNT(*) FROM chargers 
UNION ALL 
SELECT 'Slot Reservations', COUNT(*) FROM bookings 
UNION ALL 
SELECT 'Charging Sessions', COUNT(*) FROM charging_sessions;


-- ============================================================================
-- TIER 3: HARD / ADVANCED QUERIES (Q25 - Q36)
-- Topics: Window Functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE, LAG, LEAD),
--         CTEs, Running Totals, Moving Averages, Pivoting, RFM Segmentation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q25: Top-1 Revenue Session per Station (ROW_NUMBER & CTE)
-- Description: Identify the single most profitable session for each station.
-- Concepts: Common Table Expression (CTE), ROW_NUMBER() with PARTITION BY
-- ----------------------------------------------------------------------------
WITH RankedSessions AS (
    SELECT s.station_name, 
           cs.session_id, 
           u.name AS customer_name, 
           cs.energy_consumed_kwh, 
           cs.total_cost, 
           ROW_NUMBER() OVER (PARTITION BY s.station_id ORDER BY cs.total_cost DESC) AS rn 
    FROM stations s 
    JOIN chargers c ON s.station_id = c.station_id 
    JOIN bookings b ON c.charger_id = b.charger_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    JOIN users u ON b.user_id = u.user_id 
    WHERE cs.status = 'COMPLETED'
)
SELECT station_name, session_id, customer_name, energy_consumed_kwh, total_cost AS highest_session_cost 
FROM RankedSessions 
WHERE rn = 1;

-- ----------------------------------------------------------------------------
-- Q26: Dense Ranking of Stations by Total Revenue
-- Description: Rank all stations by gross revenue without gaps in rank numbers.
-- Concepts: DENSE_RANK() OVER (ORDER BY ... DESC), Aggregation inside CTE
-- ----------------------------------------------------------------------------
WITH StationTotals AS (
    SELECT s.station_name, 
           s.city, 
           ROUND(SUM(cs.total_cost), 2) AS total_revenue, 
           COUNT(cs.session_id) AS total_sessions 
    FROM stations s 
    JOIN chargers c ON s.station_id = c.station_id 
    JOIN bookings b ON c.charger_id = b.charger_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    WHERE cs.status = 'COMPLETED' 
    GROUP BY s.station_id, s.station_name, s.city
)
SELECT station_name, city, total_revenue, total_sessions, 
       DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank 
FROM StationTotals;

-- ----------------------------------------------------------------------------
-- Q27: Customer Energy Consumption Leaderboard (RANK)
-- Description: Rank customers by cumulative energy consumed, handling ties gracefully.
-- Concepts: Standard RANK() OVER (ORDER BY ... DESC)
-- ----------------------------------------------------------------------------
WITH DriverEnergy AS (
    SELECT u.user_id, 
           u.name, 
           ROUND(SUM(cs.energy_consumed_kwh), 2) AS total_kwh, 
           ROUND(SUM(cs.total_cost), 2) AS total_spent 
    FROM users u 
    JOIN bookings b ON u.user_id = b.user_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    WHERE cs.status = 'COMPLETED' 
    GROUP BY u.user_id, u.name
)
SELECT name, total_kwh, total_spent, 
       RANK() OVER (ORDER BY total_kwh DESC) AS consumption_rank 
FROM DriverEnergy;

-- ----------------------------------------------------------------------------
-- Q28: Charger Hardware Power Stratification (NTILE Bucketing)
-- Description: Divide chargers into 3 equal statistical power tiers using NTILE(3).
-- Concepts: NTILE(3) window function, CASE mapping over window quantiles
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       c.charger_number, 
       c.charger_type, 
       c.power_kw, 
       NTILE(3) OVER (ORDER BY c.power_kw ASC) AS power_tier_bucket,
       CASE NTILE(3) OVER (ORDER BY c.power_kw ASC)
           WHEN 1 THEN 'Tier 1: Standard AC'
           WHEN 2 THEN 'Tier 2: Fast DC'
           WHEN 3 THEN 'Tier 3: Ultra-Fast DC'
       END AS tier_description
FROM chargers c 
JOIN stations s ON c.station_id = s.station_id;

-- ----------------------------------------------------------------------------
-- Q29: Cumulative Running Total of Network Revenue
-- Description: Calculate day-by-day cumulative revenue progression across the network.
-- Concepts: SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
-- ----------------------------------------------------------------------------
WITH DailyRevenue AS (
    SELECT DATE(start_time) AS session_date, 
           ROUND(SUM(total_cost), 2) AS daily_rev 
    FROM charging_sessions 
    WHERE status = 'COMPLETED' 
    GROUP BY DATE(start_time)
)
SELECT session_date, 
       daily_rev, 
       ROUND(SUM(daily_rev) OVER (ORDER BY session_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_network_revenue 
FROM DailyRevenue 
ORDER BY session_date;

-- ----------------------------------------------------------------------------
-- Q30: Cumulative Running Revenue Partitioned by Station
-- Description: Calculate cumulative running revenue progression for each station.
-- Concepts: Window aggregate with PARTITION BY and ORDER BY
-- ----------------------------------------------------------------------------
WITH StationDaily AS (
    SELECT s.station_id, 
           s.station_name, 
           DATE(cs.start_time) AS session_date, 
           SUM(cs.total_cost) AS daily_revenue 
    FROM stations s 
    JOIN chargers c ON s.station_id = c.station_id 
    JOIN bookings b ON c.charger_id = b.charger_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    WHERE cs.status = 'COMPLETED' 
    GROUP BY s.station_id, s.station_name, DATE(cs.start_time)
)
SELECT station_name, 
       session_date, 
       ROUND(daily_revenue, 2) AS daily_revenue, 
       ROUND(SUM(daily_revenue) OVER (PARTITION BY station_id ORDER BY session_date), 2) AS station_running_total 
FROM StationDaily 
ORDER BY station_name, session_date;

-- ----------------------------------------------------------------------------
-- Q31: Session Variance & Contribution vs Station Average
-- Description: Compare each session's cost against its station's mean session revenue.
-- Concepts: AVG() OVER (PARTITION BY ...), % of station total via window SUM()
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       cs.session_id, 
       cs.total_cost, 
       ROUND(AVG(cs.total_cost) OVER (PARTITION BY s.station_id), 2) AS station_avg_cost, 
       ROUND(cs.total_cost - AVG(cs.total_cost) OVER (PARTITION BY s.station_id), 2) AS variance_from_station_avg, 
       ROUND(cs.total_cost * 100.0 / SUM(cs.total_cost) OVER (PARTITION BY s.station_id), 1) AS pct_of_station_total 
FROM stations s 
JOIN chargers c ON s.station_id = c.station_id 
JOIN bookings b ON c.charger_id = b.charger_id 
JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
WHERE cs.status = 'COMPLETED' 
ORDER BY s.station_name, cs.total_cost DESC;

-- ----------------------------------------------------------------------------
-- Q32: Charger Turnaround & Idle Interval Analysis (LAG)
-- Description: Calculate idle time in minutes between consecutive charges on the same charger.
-- Concepts: LAG(end_time) OVER (PARTITION BY charger_id ORDER BY start_time), TIMESTAMPDIFF
-- ----------------------------------------------------------------------------
WITH SessionSequence AS (
    SELECT c.charger_number, 
           s.station_name, 
           cs.session_id, 
           cs.start_time, 
           cs.end_time, 
           LAG(cs.end_time) OVER (PARTITION BY c.charger_id ORDER BY cs.start_time) AS prev_session_end 
    FROM chargers c 
    JOIN stations s ON c.station_id = s.station_id 
    JOIN bookings b ON c.charger_id = b.charger_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    WHERE cs.status = 'COMPLETED'
)
SELECT station_name, 
       charger_number, 
       session_id, 
       prev_session_end, 
       start_time AS current_session_start, 
       TIMESTAMPDIFF(MINUTE, prev_session_end, start_time) AS idle_minutes_between_charges 
FROM SessionSequence 
WHERE prev_session_end IS NOT NULL 
ORDER BY station_name, charger_number, current_session_start;

-- ----------------------------------------------------------------------------
-- Q33: Week-Over-Week Revenue Growth Trends (LAG)
-- Description: Measure weekly platform revenue and calculate percentage growth or decline.
-- Concepts: YEARWEEK(), LAG(), Growth percentage formula
-- ----------------------------------------------------------------------------
WITH WeeklyTotals AS (
    SELECT YEARWEEK(start_time, 1) AS calendar_week, 
           ROUND(SUM(total_cost), 2) AS weekly_revenue 
    FROM charging_sessions 
    WHERE status = 'COMPLETED' 
    GROUP BY YEARWEEK(start_time, 1)
)
SELECT calendar_week, 
       weekly_revenue, 
       LAG(weekly_revenue) OVER (ORDER BY calendar_week) AS prior_week_revenue, 
       ROUND(weekly_revenue - LAG(weekly_revenue) OVER (ORDER BY calendar_week), 2) AS net_growth_inr, 
       ROUND((weekly_revenue - LAG(weekly_revenue) OVER (ORDER BY calendar_week)) * 100.0 / LAG(weekly_revenue) OVER (ORDER BY calendar_week), 2) AS wow_growth_rate_pct 
FROM WeeklyTotals;

-- ----------------------------------------------------------------------------
-- Q34: Station Revenue Pivot Matrix by Charger Technology
-- Description: Pivot revenue across AC, DC_FAST, and DC_ULTRA_FAST into separate columns.
-- Concepts: Cross-tabulation / SQL Matrix Pivot using CASE and COALESCE
-- ----------------------------------------------------------------------------
SELECT s.station_name, 
       s.city, 
       ROUND(COALESCE(SUM(CASE WHEN c.charger_type = 'AC' THEN cs.total_cost END), 0), 2) AS ac_revenue_inr, 
       ROUND(COALESCE(SUM(CASE WHEN c.charger_type = 'DC_FAST' THEN cs.total_cost END), 0), 2) AS dc_fast_revenue_inr, 
       ROUND(COALESCE(SUM(CASE WHEN c.charger_type = 'DC_ULTRA_FAST' THEN cs.total_cost END), 0), 2) AS dc_ultra_fast_revenue_inr, 
       ROUND(COALESCE(SUM(cs.total_cost), 0), 2) AS gross_station_revenue_inr 
FROM stations s 
JOIN chargers c ON s.station_id = c.station_id 
LEFT JOIN bookings b ON c.charger_id = b.charger_id 
LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id AND cs.status = 'COMPLETED' 
GROUP BY s.station_id, s.station_name, s.city 
ORDER BY gross_station_revenue_inr DESC;

-- ----------------------------------------------------------------------------
-- Q35: Customer RFM Segmentation & Loyalty Tier Scoring
-- Description: Score drivers on Recency, Frequency, and Monetary value to assign tiers.
-- Concepts: Multi-CTE, NTILE(4) scoring, Segmentation logic with CASE
-- ----------------------------------------------------------------------------
WITH CustomerMetrics AS (
    SELECT u.user_id, 
           u.name, 
           DATEDIFF('2025-03-01', MAX(cs.end_time)) AS recency_days, 
           COUNT(cs.session_id) AS frequency_count, 
           ROUND(SUM(cs.total_cost), 2) AS monetary_total 
    FROM users u 
    JOIN bookings b ON u.user_id = b.user_id 
    JOIN charging_sessions cs ON b.booking_id = cs.booking_id 
    WHERE cs.status = 'COMPLETED' 
    GROUP BY u.user_id, u.name
),
RFMTiles AS (
    SELECT name, recency_days, frequency_count, monetary_total, 
           NTILE(4) OVER (ORDER BY recency_days ASC) AS r_score, 
           NTILE(4) OVER (ORDER BY frequency_count DESC) AS f_score, 
           NTILE(4) OVER (ORDER BY monetary_total DESC) AS m_score 
    FROM CustomerMetrics
)
SELECT name, 
       recency_days, 
       frequency_count, 
       monetary_total, 
       r_score, f_score, m_score, 
       CASE 
           WHEN r_score = 1 AND m_score = 1 THEN 'Platinum Elite' 
           WHEN m_score <= 2 THEN 'Gold Member' 
           ELSE 'Regular Commuter' 
       END AS customer_segment 
FROM RFMTiles 
ORDER BY monetary_total DESC;

-- ----------------------------------------------------------------------------
-- Q36: Algorithmic Slot Collision & Booking Overlap Audit
-- Description: Verify database integrity: detect any concurrent reservations on the same bay.
-- Concepts: Self-join with inequality (`<`), Overlap condition: `start1 < end2 AND end1 > start2`
-- Expected Result: 0 rows (Guaranteed by database triggers and procedural locks)
-- ----------------------------------------------------------------------------
SELECT b1.booking_id AS booking_1, 
       b2.booking_id AS booking_2, 
       b1.charger_id, 
       b1.start_time AS slot1_start, 
       b1.end_time AS slot1_end, 
       b2.start_time AS slot2_start, 
       b2.end_time AS slot2_end 
FROM bookings b1 
JOIN bookings b2 ON b1.charger_id = b2.charger_id AND b1.booking_id < b2.booking_id 
WHERE b1.status = 'BOOKED' AND b2.status = 'BOOKED' 
  AND b1.start_time < b2.end_time AND b1.end_time > b2.start_time;

-- ============================================================================
-- TIER 4 (BONUS): WEAK ENTITY OPERATIONAL & AUDIT QUERIES (Q37 - Q40)
-- Topics: Identifying Relationships, Partial Key Aggregations, Weak Entity Cascades
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q37: Weak Entity Identifying Parent-Child Join
-- Description: Retrieve all maintenance logs joined with their identifying parent (chargers) and grandparent (stations).
-- Concepts: Multi-table INNER JOIN, composite key navigation, formatted currency
-- ----------------------------------------------------------------------------
SELECT 
    s.station_name,
    s.city,
    c.charger_number,
    c.charger_type,
    cml.log_seq,
    cml.maintenance_date,
    cml.issue_type,
    cml.technician_name,
    CONCAT('₹', FORMAT(cml.cost, 2)) AS repair_cost,
    cml.status AS ticket_status
FROM charger_maintenance_logs cml
JOIN chargers c ON cml.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
ORDER BY cml.maintenance_date DESC;

-- ----------------------------------------------------------------------------
-- Q38: Cumulative Maintenance Expenditure per Station & Hardware Bay
-- Description: Calculate total maintenance overhead per station and per charging bay.
-- Concepts: GROUP BY WITH ROLLUP / Aggregation, SUM, COUNT
-- ----------------------------------------------------------------------------
SELECT 
    COALESCE(s.station_name, '--- ALL STATIONS TOTAL ---') AS station_name,
    COALESCE(c.charger_number, 'ALL CHARGERS') AS charger_number,
    COUNT(cml.log_seq) AS total_maintenance_events,
    CONCAT('₹', FORMAT(SUM(cml.cost), 2)) AS total_maintenance_spend
FROM stations s
JOIN chargers c ON s.station_id = c.station_id
JOIN charger_maintenance_logs cml ON c.charger_id = cml.charger_id
GROUP BY s.station_name, c.charger_number WITH ROLLUP;

-- ----------------------------------------------------------------------------
-- Q39: Active Hardware Fault Isolation (chargers in MAINTENANCE with open logs)
-- Description: Correlate chargers with status = 'MAINTENANCE' against active/in-progress maintenance logs.
-- Concepts: INNER JOIN, Filter on ENUM status, Subquery / In-flight work order tracking
-- ----------------------------------------------------------------------------
SELECT 
    s.station_name,
    c.charger_id,
    c.charger_number,
    c.charger_type,
    c.power_kw,
    cml.log_seq,
    cml.issue_type,
    cml.description AS active_issue,
    cml.technician_name,
    cml.status AS work_order_status
FROM chargers c
JOIN stations s ON c.station_id = s.station_id
JOIN charger_maintenance_logs cml ON c.charger_id = cml.charger_id
WHERE c.status = 'MAINTENANCE'
  AND cml.status IN ('SCHEDULED', 'IN_PROGRESS');

-- ----------------------------------------------------------------------------
-- Q40: Weak Entity Partial Key Sequence Audit
-- Description: Verify that the partial key (log_seq) correctly sequences 1..N for each identifying charger.
-- Concepts: Window function ROW_NUMBER(), verification of partial key integrity
-- ----------------------------------------------------------------------------
SELECT 
    cml.charger_id,
    c.charger_number,
    cml.log_seq AS stored_partial_key,
    ROW_NUMBER() OVER (PARTITION BY cml.charger_id ORDER BY cml.maintenance_date ASC) AS calculated_sequence,
    cml.issue_type,
    cml.maintenance_date
FROM charger_maintenance_logs cml
JOIN chargers c ON cml.charger_id = c.charger_id
ORDER BY cml.charger_id, cml.log_seq;

