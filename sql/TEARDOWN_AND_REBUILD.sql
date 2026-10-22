-- =============================================================================
-- TEARDOWN AND REBUILD
-- WKS Restaurant Group SI Demo
--
-- One-click idempotent rebuild from the GitHub Git Repository object.
-- Runs in Snowsight Worksheet or via the snow CLI.
--
-- DESIGN:
--   This script does NOT call 99_teardown.sql. That script drops the schema,
--   which destroys WKS_REPO, making the subsequent EXECUTE IMMEDIATE FROM
--   statements impossible. Instead, this script inlines a soft teardown that
--   preserves the schema, warehouse, and WKS_REPO, then rebuilds from the repo.
--
--   99_teardown.sql is a standalone full cleanup. Run it manually when you
--   want to completely remove the WKS demo from an account.
--
-- PREREQUISITES (run once per account — see README Quick Start Step 1):
--   CREATE API INTEGRATION IF NOT EXISTS GIT_HUB_INTEGRATION ...;
--   CREATE DATABASE IF NOT EXISTS CUSTOMER_DEMOS;
--   CREATE SCHEMA  IF NOT EXISTS CUSTOMER_DEMOS.WKS;
--   CREATE OR REPLACE GIT REPOSITORY CUSTOMER_DEMOS.WKS.WKS_REPO
--     API_INTEGRATION = GIT_HUB_INTEGRATION
--     ORIGIN = 'https://github.com/sfc-gh-timjones/c_wks';
--
-- ERROR HANDLING:
--   The soft teardown wraps error-prone statements (agent deregister, policy
--   detach) in anonymous Snowflake Scripting blocks. Errors are caught and
--   silently ignored — they mean the object did not exist yet, which is fine
--   on a first run or any run where teardown is partial.
--   All DROP ... IF EXISTS statements never error.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ── Fetch latest from GitHub before doing anything ────────────────────────
ALTER GIT REPOSITORY CUSTOMER_DEMOS.WKS.WKS_REPO FETCH;

-- ══════════════════════════════════════════════════════════════════════════
-- SOFT TEARDOWN — preserves schema, warehouse, and WKS_REPO
-- ══════════════════════════════════════════════════════════════════════════

-- Agent deregistration (errors if not registered — ignore)
BEGIN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
        DROP AGENT CUSTOMER_DEMOS.WKS.WKS_AGENT;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

DROP AGENT         IF EXISTS CUSTOMER_DEMOS.WKS.WKS_AGENT;
DROP SEMANTIC VIEW IF EXISTS CUSTOMER_DEMOS.WKS.WKS_SEMANTIC_VIEW;

-- RAP detach from DT (errors if DT or policy does not exist — ignore)
BEGIN
    ALTER DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        DROP ROW ACCESS POLICY CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

-- RAP detach from base table (errors if table or policy does not exist — ignore)
BEGIN
    ALTER TABLE CUSTOMER_DEMOS.WKS.RESTAURANTS
        DROP ROW ACCESS POLICY CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

DROP ROW ACCESS POLICY IF EXISTS CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY;

-- Dynamic tables — deepest chain first
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_CURRENT_SNAPSHOT;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_BRAND_WEEKLY_SUMMARY;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_DAILY_RESTAURANT_SALES;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_MONTHLY_BRAND_TURNOVER;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_EMPLOYEES_ENRICHED;
DROP DYNAMIC TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DT_TRANSACTIONS_CLEAN;

DROP CORTEX SEARCH SERVICE IF EXISTS CUSTOMER_DEMOS.WKS.WKS_HR_SEARCH;
DROP PROCEDURE  IF EXISTS CUSTOMER_DEMOS.WKS.WKS_SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR);
DROP INTEGRATION IF EXISTS WKS_EMAIL_INTEGRATION;

DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.EMPLOYEE_EVENTS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.TRANSACTIONS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.EMPLOYEES;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.WKS_HR_DOCS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.WKS_DISTRICT_USER_MAP;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.RESTAURANTS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DISTRICTS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.JOB_POSITIONS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.DEPARTMENTS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.BRANDS;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.STATES;
DROP TABLE IF EXISTS CUSTOMER_DEMOS.WKS.REGIONS;
-- Schema, warehouse, and WKS_REPO are NOT dropped.

-- ══════════════════════════════════════════════════════════════════════════
-- REBUILD — run all scripts from the repo in order
-- ══════════════════════════════════════════════════════════════════════════

EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/01_database_and_schema.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/02_create_tables.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/03_generate_synthetic_data.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/04_generate_employees_faker.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/05_create_dynamic_tables.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/06_create_semantic_view.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/07_create_cortex_search.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/08_create_email_proc.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/09_create_agent.sql;
EXECUTE IMMEDIATE FROM @CUSTOMER_DEMOS.WKS.WKS_REPO/branches/main/sql/10_row_access_policy.sql;
