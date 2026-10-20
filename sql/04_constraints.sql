-- ============================================================================
-- SCRIPT: 04_constraints.sql
-- PROJECT: EV Charging Station Slot Booking & Energy Log
-- DATABASE: MySQL 8.x
-- DESCRIPTION: Explains and checks all database rules and constraints in simple SQL.
-- ============================================================================

USE ev_charging_db;

-- ----------------------------------------------------------------------------
-- What are Constraints?
-- Constraints are simple rules that the database enforces automatically so
-- bad or incorrect data can NEVER enter the tables:
--   1. PRIMARY KEY: Ensures each row has a unique ID (e.g. user_id).
--   2. FOREIGN KEY: Connects tables together (e.g. vehicle points to a real user).
--   3. UNIQUE: Prevents duplicate values (e.g. two users cannot have same email).
--   4. CHECK: Validates values (e.g. battery capacity must be greater than 0).
-- ----------------------------------------------------------------------------

-- 1. View all Foreign Keys and Primary Keys in our database
SELECT 
    TABLE_NAME AS table_name,
    CONSTRAINT_NAME AS constraint_name,
    CONSTRAINT_TYPE AS rule_type
FROM 
    information_schema.TABLE_CONSTRAINTS
WHERE 
    TABLE_SCHEMA = 'ev_charging_db'
ORDER BY 
    TABLE_NAME, CONSTRAINT_TYPE;

-- 2. View all CHECK constraints (the data validation rules)
SELECT 
    CONSTRAINT_NAME AS rule_name,
    CHECK_CLAUSE AS validation_rule
FROM 
    information_schema.CHECK_CONSTRAINTS
WHERE 
    CONSTRAINT_SCHEMA = 'ev_charging_db';

-- 3. Verify Weak Entity Composite Primary Key (charger_id + log_seq)
-- In a weak entity, the primary key MUST be a composite of the identifying
-- strong entity's PK (charger_id) plus its own partial key discriminator (log_seq).
SELECT 
    TABLE_NAME AS table_name,
    COLUMN_NAME AS key_column,
    ORDINAL_POSITION AS position_in_composite_pk,
    CONSTRAINT_NAME AS constraint_name
FROM 
    information_schema.KEY_COLUMN_USAGE
WHERE 
    TABLE_SCHEMA = 'ev_charging_db'
    AND TABLE_NAME = 'charger_maintenance_logs'
    AND CONSTRAINT_NAME = 'PRIMARY'
ORDER BY 
    ORDINAL_POSITION;

-- 4. Verify Identifying Relationship CASCADE Deletion
-- A weak entity cannot exist without its identifying strong entity.
-- Therefore, the foreign key MUST have DELETE_RULE = 'CASCADE'.
SELECT 
    CONSTRAINT_NAME AS foreign_key_name,
    TABLE_NAME AS weak_entity_table,
    REFERENCED_TABLE_NAME AS identifying_strong_table,
    DELETE_RULE AS cascade_action,
    UPDATE_RULE AS update_action
FROM 
    information_schema.REFERENTIAL_CONSTRAINTS
WHERE 
    CONSTRAINT_SCHEMA = 'ev_charging_db'
    AND TABLE_NAME = 'charger_maintenance_logs';

