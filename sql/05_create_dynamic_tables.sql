-- =============================================================================
-- 05: CREATE DYNAMIC TABLE PIPELINE (8 DTs, 5 layers)
-- WKS Restaurant Group SI Demo
--
-- LAG DESIGN:
--   Snowflake requires downstream TARGET_LAG >= upstream TARGET_LAG.
--   Using TARGET_LAG = DOWNSTREAM on every intermediate DT.
--   Only leaf nodes carry explicit timers:
--     DT_EMPLOYEES_ENRICHED → 1 hour  (HR leaf, no downstream DT)
--     DT_HR_BRAND_METRICS   → 1 hour  (HR leaf for the turnover chain)
--     DT_CURRENT_SNAPSHOT   → 1 min   (sales leaf at end of the cascade)
--
--   DOWNSTREAM tells Snowflake: "refresh me as soon as the thing downstream
--   of me is due." One 1-minute timer at DT_CURRENT_SNAPSHOT drives the entire
--   sales pipeline in cascade. Demo talking point:
--     "One timer runs the whole chain. Snowflake resolves the order, skips
--      any DT whose upstream hasn't changed, and only burns credits on real work."
--
-- CURRENT_DATE() / CURRENT_TIMESTAMP() in SELECT:
--   Snowflake forbids non-deterministic functions in the SELECT list of a
--   dynamic table (only WHERE/HAVING/QUALIFY are allowed).
--   Affected tables that have been fixed:
--     DT_EMPLOYEES_ENRICHED   — tenure columns removed (computed at query time)
--     DT_MONTHLY_BRAND_TURNOVER — calendar spine now derived from actual
--                                 HIRE_DATE/EVENT_DATE ranges, not CURRENT_DATE()
--
-- GRAIN CONTRACT (unchanged):
--   Sales → restaurant × week.   HR → brand × month.
--   Never physically joined in a DT — the semantic view bridges via BRANDS.
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

-- ============================================================================
-- LAYER 1 — BRONZE CLEAN (DOWNSTREAM lag)
-- ============================================================================

-- DT 1: Clean and enrich raw transactions
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_TRANSACTIONS_CLEAN
    TARGET_LAG  = DOWNSTREAM
    WAREHOUSE   = WKS_WH
AS
SELECT
    TRANSACTION_ID,
    RESTAURANT_ID,
    TRANSACTION_DATE,
    TRANSACTION_HOUR,
    DAY_OF_WEEK,
    CHECK_AMOUNT,
    ITEM_COUNT,
    PAYMENT_TYPE,
    ORDER_CHANNEL,
    DATE_TRUNC('week',  TRANSACTION_DATE)::DATE AS WEEK_START_DATE,
    DATE_TRUNC('month', TRANSACTION_DATE)::DATE AS MONTH_START_DATE,
    CASE
        WHEN TRANSACTION_HOUR BETWEEN  6 AND 10 THEN 'BREAKFAST'
        WHEN TRANSACTION_HOUR BETWEEN 11 AND 15 THEN 'LUNCH'
        WHEN TRANSACTION_HOUR BETWEEN 16 AND 20 THEN 'DINNER'
        ELSE 'LATE_NIGHT'
    END                                         AS MEAL_PERIOD,
    CASE
        WHEN DAYOFWEEK(TRANSACTION_DATE) IN (0, 6) THEN TRUE
        ELSE FALSE
    END                                         AS IS_WEEKEND,
    CASE
        WHEN CHECK_AMOUNT BETWEEN 0.50 AND 300 AND ITEM_COUNT BETWEEN 1 AND 20 THEN TRUE
        ELSE FALSE
    END                                         AS IS_VALID
FROM CUSTOMER_DEMOS.WKS.TRANSACTIONS
WHERE CHECK_AMOUNT > 0;


-- DT 2: Enrich employee records with dimensional context
-- CURRENT_DATE() removed from SELECT list — tenure columns are omitted;
-- compute DATEDIFF(HIRE_DATE, CURRENT_DATE()) at query time as needed.
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_EMPLOYEES_ENRICHED
    TARGET_LAG  = '1 hour'   -- leaf node (no downstream DT); needs explicit lag
    WAREHOUSE   = WKS_WH
AS
SELECT
    e.EMPLOYEE_ID,
    e.RESTAURANT_ID,
    e.BRAND_ID,
    e.DEPARTMENT_ID,
    e.POSITION_ID,
    b.BRAND_NAME,
    d.DEPARTMENT_NAME,
    d.DEPARTMENT_TYPE,
    p.POSITION_TITLE,
    p.POSITION_LEVEL,
    r.RESTAURANT_NAME,
    r.STATE_CODE,
    rg.REGION_NAME,
    TRIM(e.FIRST_NAME || ' ' || e.LAST_NAME) AS FULL_NAME,
    e.HIRE_DATE,
    e.TERM_DATE,
    e.EMPLOYMENT_TYPE,
    e.HOURLY_RATE,
    e.IS_ACTIVE
FROM CUSTOMER_DEMOS.WKS.EMPLOYEES        e
JOIN CUSTOMER_DEMOS.WKS.BRANDS           b  ON e.BRAND_ID      = b.BRAND_ID
JOIN CUSTOMER_DEMOS.WKS.DEPARTMENTS      d  ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
JOIN CUSTOMER_DEMOS.WKS.JOB_POSITIONS    p  ON e.POSITION_ID   = p.POSITION_ID
LEFT JOIN CUSTOMER_DEMOS.WKS.RESTAURANTS r  ON e.RESTAURANT_ID = r.RESTAURANT_ID
LEFT JOIN CUSTOMER_DEMOS.WKS.REGIONS     rg ON r.REGION_ID     = rg.REGION_ID;


-- ============================================================================
-- LAYER 2 — SILVER (DOWNSTREAM lag)
-- ============================================================================

-- DT 3: Aggregate cleaned transactions to restaurant-day grain
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_DAILY_RESTAURANT_SALES
    TARGET_LAG  = DOWNSTREAM
    WAREHOUSE   = WKS_WH
AS
SELECT
    tc.RESTAURANT_ID,
    tc.TRANSACTION_DATE,
    tc.WEEK_START_DATE,
    tc.MONTH_START_DATE,
    COUNT(*)                        AS DAILY_TRANSACTIONS,
    SUM(tc.CHECK_AMOUNT)            AS DAILY_SALES,
    ROUND(AVG(tc.CHECK_AMOUNT), 2)  AS AVG_CHECK,
    SUM(tc.ITEM_COUNT)              AS DAILY_ITEMS,
    SUM(CASE WHEN tc.ORDER_CHANNEL = 'DRIVE_THRU' THEN 1 ELSE 0 END) AS DRIVE_THRU_COUNT,
    SUM(CASE WHEN tc.ORDER_CHANNEL = 'MOBILE'     THEN 1 ELSE 0 END) AS MOBILE_COUNT,
    SUM(CASE WHEN tc.ORDER_CHANNEL = 'DELIVERY'   THEN 1 ELSE 0 END) AS DELIVERY_COUNT,
    MAX(tc.IS_WEEKEND::INT)::BOOLEAN                                  AS IS_WEEKEND
FROM CUSTOMER_DEMOS.WKS.DT_TRANSACTIONS_CLEAN tc
WHERE tc.IS_VALID = TRUE
GROUP BY
    tc.RESTAURANT_ID,
    tc.TRANSACTION_DATE,
    tc.WEEK_START_DATE,
    tc.MONTH_START_DATE;


-- DT 4: Brand-month turnover staging
-- CURRENT_DATE() removed from SELECT list — month spine derived from actual
-- HIRE_DATE and EVENT_DATE ranges in the source tables.
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_MONTHLY_BRAND_TURNOVER
    TARGET_LAG   = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE    = WKS_WH
AS
WITH
-- Month universe from actual data (no CURRENT_DATE() in SELECT)
months_hires AS (
    SELECT DISTINCT BRAND_ID, DATE_TRUNC('month', HIRE_DATE)::DATE AS YEAR_MONTH
    FROM CUSTOMER_DEMOS.WKS.EMPLOYEES
),
months_terms AS (
    SELECT DISTINCT e.BRAND_ID, DATE_TRUNC('month', ev.EVENT_DATE)::DATE AS YEAR_MONTH
    FROM CUSTOMER_DEMOS.WKS.EMPLOYEE_EVENTS ev
    JOIN CUSTOMER_DEMOS.WKS.EMPLOYEES e ON ev.EMPLOYEE_ID = e.EMPLOYEE_ID
    WHERE ev.EVENT_TYPE = 'TERMINATION'
),
months AS (
    SELECT BRAND_ID, YEAR_MONTH FROM months_hires
    UNION
    SELECT BRAND_ID, YEAR_MONTH FROM months_terms
),
hires AS (
    SELECT BRAND_ID, DATE_TRUNC('month', HIRE_DATE)::DATE AS YEAR_MONTH, COUNT(*) AS HIRES
    FROM CUSTOMER_DEMOS.WKS.EMPLOYEES
    GROUP BY 1, 2
),
separations AS (
    SELECT e.BRAND_ID, DATE_TRUNC('month', ev.EVENT_DATE)::DATE AS YEAR_MONTH,
           COUNT(*) AS SEPARATIONS
    FROM CUSTOMER_DEMOS.WKS.EMPLOYEE_EVENTS ev
    JOIN CUSTOMER_DEMOS.WKS.EMPLOYEES e ON ev.EMPLOYEE_ID = e.EMPLOYEE_ID
    WHERE ev.EVENT_TYPE = 'TERMINATION'
    GROUP BY 1, 2
),
-- Ending headcount: employees active at month-end (LAST_DAY is deterministic)
headcount AS (
    SELECT m.BRAND_ID, m.YEAR_MONTH, COUNT(*) AS ENDING_HEADCOUNT
    FROM months m
    JOIN CUSTOMER_DEMOS.WKS.EMPLOYEES e
      ON m.BRAND_ID = e.BRAND_ID
     AND e.HIRE_DATE <= LAST_DAY(m.YEAR_MONTH)
     AND (e.TERM_DATE IS NULL OR e.TERM_DATE > LAST_DAY(m.YEAR_MONTH))
    GROUP BY m.BRAND_ID, m.YEAR_MONTH
)
SELECT
    m.BRAND_ID,
    b.BRAND_NAME,
    m.YEAR_MONTH,
    COALESCE(h.HIRES,            0) AS HIRES,
    COALESCE(s.SEPARATIONS,      0) AS SEPARATIONS,
    COALESCE(hc.ENDING_HEADCOUNT,0) AS ENDING_HEADCOUNT
FROM months m
JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON m.BRAND_ID = b.BRAND_ID
LEFT JOIN hires       h  ON m.BRAND_ID = h.BRAND_ID AND m.YEAR_MONTH = h.YEAR_MONTH
LEFT JOIN separations s  ON m.BRAND_ID = s.BRAND_ID AND m.YEAR_MONTH = s.YEAR_MONTH
LEFT JOIN headcount  hc  ON m.BRAND_ID = hc.BRAND_ID AND m.YEAR_MONTH = hc.YEAR_MONTH;


-- ============================================================================
-- LAYER 3 — GOLD ENRICHED (DOWNSTREAM lag, FULL REFRESH for window functions)
-- ============================================================================

-- DT 5: Restaurant-week sales with WoW%, YoY%, rolling 4-week average
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
    TARGET_LAG   = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE    = WKS_WH
AS
WITH weekly_base AS (
    SELECT
        d.RESTAURANT_ID,
        r.RESTAURANT_NAME,
        r.BRAND_ID,
        b.BRAND_NAME,
        b.BRAND_TYPE,
        r.STATE_CODE,
        rg.REGION_NAME,
        r.DISTRICT_ID,
        d.WEEK_START_DATE,
        SUM(d.DAILY_SALES)        AS WEEKLY_SALES,
        SUM(d.DAILY_TRANSACTIONS) AS TRANSACTION_COUNT,
        ROUND(SUM(d.DAILY_SALES) / NULLIF(SUM(d.DAILY_TRANSACTIONS), 0), 2) AS AVG_CHECK,
        SUM(d.DAILY_ITEMS)        AS WEEKLY_ITEM_COUNT,
        SUM(d.DRIVE_THRU_COUNT)   AS DRIVE_THRU_TRANSACTIONS,
        SUM(d.MOBILE_COUNT)       AS MOBILE_TRANSACTIONS
    FROM CUSTOMER_DEMOS.WKS.DT_DAILY_RESTAURANT_SALES d
    JOIN CUSTOMER_DEMOS.WKS.RESTAURANTS r  ON d.RESTAURANT_ID = r.RESTAURANT_ID
    JOIN CUSTOMER_DEMOS.WKS.BRANDS      b  ON r.BRAND_ID      = b.BRAND_ID
    JOIN CUSTOMER_DEMOS.WKS.REGIONS     rg ON r.REGION_ID     = rg.REGION_ID
    GROUP BY
        d.RESTAURANT_ID, r.RESTAURANT_NAME, r.BRAND_ID, b.BRAND_NAME, b.BRAND_TYPE,
        r.STATE_CODE, rg.REGION_NAME, r.DISTRICT_ID, d.WEEK_START_DATE
)
SELECT
    w.RESTAURANT_ID,
    w.RESTAURANT_NAME,
    w.BRAND_ID,
    w.BRAND_NAME,
    w.BRAND_TYPE,
    w.STATE_CODE,
    w.REGION_NAME,
    w.DISTRICT_ID,
    w.WEEK_START_DATE,
    w.WEEKLY_SALES,
    w.TRANSACTION_COUNT,
    w.AVG_CHECK,
    w.WEEKLY_ITEM_COUNT,
    w.DRIVE_THRU_TRANSACTIONS,
    w.MOBILE_TRANSACTIONS,
    LAG(w.WEEKLY_SALES, 1) OVER (
        PARTITION BY w.RESTAURANT_ID ORDER BY w.WEEK_START_DATE
    )                                                                   AS PREV_WEEK_SALES,
    ROUND(
        (w.WEEKLY_SALES - LAG(w.WEEKLY_SALES, 1) OVER (
            PARTITION BY w.RESTAURANT_ID ORDER BY w.WEEK_START_DATE))
        / NULLIF(LAG(w.WEEKLY_SALES, 1) OVER (
            PARTITION BY w.RESTAURANT_ID ORDER BY w.WEEK_START_DATE), 0) * 100
    , 1)                                                                AS WOW_CHANGE_PCT,
    ROUND(
        (w.WEEKLY_SALES - LAG(w.WEEKLY_SALES, 52) OVER (
            PARTITION BY w.RESTAURANT_ID ORDER BY w.WEEK_START_DATE))
        / NULLIF(LAG(w.WEEKLY_SALES, 52) OVER (
            PARTITION BY w.RESTAURANT_ID ORDER BY w.WEEK_START_DATE), 0) * 100
    , 1)                                                                AS YOY_CHANGE_PCT,
    ROUND(
        AVG(w.WEEKLY_SALES) OVER (
            PARTITION BY w.RESTAURANT_ID
            ORDER BY w.WEEK_START_DATE
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        )
    , 2)                                                                AS ROLLING_4WK_AVG
FROM weekly_base w;


-- DT 6: Brand-month HR metrics with annualized turnover rate
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
    TARGET_LAG   = '1 hour'   -- explicit leaf for HR chain
    REFRESH_MODE = FULL
    WAREHOUSE    = WKS_WH
AS
SELECT
    t.BRAND_ID,
    t.BRAND_NAME,
    t.YEAR_MONTH,
    t.HIRES,
    t.SEPARATIONS,
    t.ENDING_HEADCOUNT,
    t.ENDING_HEADCOUNT - LAG(t.ENDING_HEADCOUNT, 1) OVER (
        PARTITION BY t.BRAND_ID ORDER BY t.YEAR_MONTH
    )                                                                   AS HEADCOUNT_CHANGE,
    CASE
        WHEN t.ENDING_HEADCOUNT > 0
        THEN ROUND(
            t.SEPARATIONS::FLOAT
            / NULLIF(
                (t.ENDING_HEADCOUNT +
                 COALESCE(LAG(t.ENDING_HEADCOUNT,1) OVER (
                     PARTITION BY t.BRAND_ID ORDER BY t.YEAR_MONTH),
                 t.ENDING_HEADCOUNT)
                ) / 2.0, 0)
            * 12 * 100, 1)
        ELSE 0
    END                                                                 AS ANNUALIZED_TURNOVER_RATE
FROM CUSTOMER_DEMOS.WKS.DT_MONTHLY_BRAND_TURNOVER t;


-- ============================================================================
-- LAYER 4 — BRAND ROLLUP (DOWNSTREAM lag)
-- ============================================================================

-- DT 7: Brand-week summary rolled up from restaurant-week
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_BRAND_WEEKLY_SUMMARY
    TARGET_LAG   = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE    = WKS_WH
AS
SELECT
    BRAND_ID,
    BRAND_NAME,
    BRAND_TYPE,
    WEEK_START_DATE,
    COUNT(DISTINCT RESTAURANT_ID)          AS ACTIVE_RESTAURANTS,
    SUM(WEEKLY_SALES)                      AS BRAND_WEEKLY_SALES,
    SUM(TRANSACTION_COUNT)                 AS BRAND_TRANSACTIONS,
    ROUND(AVG(AVG_CHECK), 2)               AS BRAND_AVG_CHECK,
    ROUND(
        (SUM(WEEKLY_SALES) - LAG(SUM(WEEKLY_SALES), 1) OVER (
            PARTITION BY BRAND_ID ORDER BY WEEK_START_DATE))
        / NULLIF(LAG(SUM(WEEKLY_SALES), 1) OVER (
            PARTITION BY BRAND_ID ORDER BY WEEK_START_DATE), 0) * 100
    , 1)                                   AS BRAND_WOW_PCT,
    ROUND(
        (SUM(WEEKLY_SALES) - LAG(SUM(WEEKLY_SALES), 52) OVER (
            PARTITION BY BRAND_ID ORDER BY WEEK_START_DATE))
        / NULLIF(LAG(SUM(WEEKLY_SALES), 52) OVER (
            PARTITION BY BRAND_ID ORDER BY WEEK_START_DATE), 0) * 100
    , 1)                                   AS BRAND_YOY_PCT
FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
GROUP BY BRAND_ID, BRAND_NAME, BRAND_TYPE, WEEK_START_DATE;


-- ============================================================================
-- LAYER 5 — HOT SNAPSHOT (1 minute lag — the single explicit sales timer)
-- ============================================================================

-- DT 8: Current 8-week snapshot — thin WHERE filter on DT_BRAND_WEEKLY_SUMMARY
-- CURRENT_DATE() is valid here: it is in the WHERE clause, not the SELECT list.
-- Refreshes every 60 seconds. If nothing upstream has changed since the last
-- bronze refresh, Snowflake skips the recompute — zero credits spent.
CREATE OR REPLACE DYNAMIC TABLE CUSTOMER_DEMOS.WKS.DT_CURRENT_SNAPSHOT
    TARGET_LAG   = '1 minute'   -- explicit leaf; drives the entire sales cascade
    REFRESH_MODE = FULL
    WAREHOUSE    = WKS_WH
AS
SELECT s.*
FROM CUSTOMER_DEMOS.WKS.DT_BRAND_WEEKLY_SUMMARY s
WHERE s.WEEK_START_DATE >= DATEADD('week', -8, CURRENT_DATE());
