-- =============================================================================
-- 10: ROW ACCESS POLICY — DISTRICT-LEVEL SECURITY
-- WKS Restaurant Group SI Demo
--
-- Policy coverage:
--   RESTAURANTS table           — base table queries
--   DT_WEEKLY_RESTAURANT_SALES  — what the semantic view and agent read
--
-- ⚠️  ALTER DYNAMIC TABLE (not ALTER TABLE) for DTs.
--     ALTER TABLE is correct only for base tables.
--
-- What this covers vs what it does not:
--   ✅ Snowflake Intelligence questions routed through the semantic view
--   ✅ Direct queries to RESTAURANTS or DT_WEEKLY_RESTAURANT_SALES
--   ❌ DT_BRAND_WEEKLY_SUMMARY (brand-level rollup — no district column)
--   ❌ The React dashboard (reads DT_BRAND_WEEKLY_SUMMARY; service role not in map)
--
-- Talk track: "The policy applies to Intelligence queries on the restaurant
--   detail table — which is everything the agent reads. The dashboard shows
--   brand-level aggregates, which don't have district granularity."
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

CREATE OR REPLACE TABLE CUSTOMER_DEMOS.WKS.WKS_DISTRICT_USER_MAP (
    SNOWFLAKE_USER  VARCHAR(100) NOT NULL,
    DISTRICT_ID     INT          NOT NULL,
    DISTRICT_NAME   VARCHAR(60),
    ASSIGNED_DATE   DATE         DEFAULT CURRENT_DATE()
);

INSERT INTO CUSTOMER_DEMOS.WKS.WKS_DISTRICT_USER_MAP
    (SNOWFLAKE_USER, DISTRICT_ID, DISTRICT_NAME)
VALUES
    ('DISTRICT_MGR_LA',   1, 'LA Metro'),
    ('DISTRICT_MGR_DFW', 11, 'Dallas-Ft Worth');

CREATE OR REPLACE ROW ACCESS POLICY CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY
    AS (p_district_id INT) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN')
        OR NOT EXISTS (
            SELECT 1 FROM CUSTOMER_DEMOS.WKS.WKS_DISTRICT_USER_MAP
            WHERE SNOWFLAKE_USER = CURRENT_USER()
        )
        OR EXISTS (
            SELECT 1 FROM CUSTOMER_DEMOS.WKS.WKS_DISTRICT_USER_MAP
            WHERE SNOWFLAKE_USER = CURRENT_USER()
              AND DISTRICT_ID    = p_district_id
        );

-- Attach to the base RESTAURANTS table
ALTER TABLE CUSTOMER_DEMOS.WKS.RESTAURANTS
    ADD ROW ACCESS POLICY CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY ON (DISTRICT_ID);

-- Attach to DT_WEEKLY_RESTAURANT_SALES — requires ALTER DYNAMIC TABLE, not ALTER TABLE
ALTER DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
    ADD ROW ACCESS POLICY CUSTOMER_DEMOS.WKS.WKS_DISTRICT_ACCESS_POLICY ON (DISTRICT_ID);
