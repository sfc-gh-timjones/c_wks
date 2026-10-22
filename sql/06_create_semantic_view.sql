-- =============================================================================
-- 06: CREATE SEMANTIC VIEW + VALIDATED QUERIES (VQRs)
-- WKS Restaurant Group SI Demo
--
-- Three source tables:
--   DT_WEEKLY_RESTAURANT_SALES  (alias: sales) — primary fact, restaurant × week grain
--   DT_HR_BRAND_METRICS         (alias: hr)    — secondary fact, brand × month grain
--   BRANDS                      (alias: brand) — shared dimension bridge
--
-- Grain contract: sales and hr are NEVER joined in a DT.
-- The semantic view bridges them via BRANDS.BRAND_ID.
-- Cortex Analyst generates SQL that groups by brand to make the grains compatible.
--
-- CRITICAL DDL RULE:
--   Left of AS = semantic name = MUST match physical column name exactly (case-insensitive)
--   Right of AS = physical column or expression
--   Mismatch causes: invalid identifier '__TABLE.COLUMN' (double-underscore prefix)
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER_DEMOS.WKS.WKS_SEMANTIC_VIEW
TABLES (
    CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES AS sales,
    CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS        AS hr,
    CUSTOMER_DEMOS.WKS.BRANDS                     AS brand
)
RELATIONSHIPS (
    -- Both fact tables join to BRANDS as the shared dimension bridge
    sales ( BRAND_ID ) REFERENCES brand ( BRAND_ID ),
    hr    ( BRAND_ID ) REFERENCES brand ( BRAND_ID )
)
FACTS (
    -- Sales facts (restaurant × week grain)
    sales.weekly_sales         AS WEEKLY_SALES,
    sales.transaction_count    AS TRANSACTION_COUNT,
    sales.avg_check            AS AVG_CHECK,
    sales.wow_change_pct       AS WOW_CHANGE_PCT,
    sales.yoy_change_pct       AS YOY_CHANGE_PCT,
    sales.rolling_4wk_avg      AS ROLLING_4WK_AVG,
    -- HR facts (brand × month grain)
    hr.hires                   AS HIRES,
    hr.separations             AS SEPARATIONS,
    hr.ending_headcount        AS ENDING_HEADCOUNT,
    hr.annualized_turnover_rate AS ANNUALIZED_TURNOVER_RATE
)
DIMENSIONS (
    -- Sales dimensions
    sales.restaurant_id        AS RESTAURANT_ID,
    sales.restaurant_name      AS RESTAURANT_NAME,
    sales.state_code           AS STATE_CODE,
    sales.region_name          AS REGION_NAME,
    sales.week_start_date      AS WEEK_START_DATE,
    -- HR dimensions
    hr.year_month              AS YEAR_MONTH,
    -- Shared brand dimension (comes from BRANDS table)
    brand.brand_name           AS BRAND_NAME,
    brand.brand_type           AS BRAND_TYPE
)
METRICS (
    -- Sales aggregates
    sales.total_weekly_sales   AS SUM(sales.WEEKLY_SALES),
    sales.total_transactions   AS SUM(sales.TRANSACTION_COUNT),
    sales.avg_check_size       AS AVG(sales.AVG_CHECK),
    sales.avg_wow_change       AS AVG(sales.WOW_CHANGE_PCT),
    sales.avg_yoy_change       AS AVG(sales.YOY_CHANGE_PCT),
    -- HR aggregates
    hr.total_hires             AS SUM(hr.HIRES),
    hr.total_separations       AS SUM(hr.SEPARATIONS),
    hr.max_headcount           AS MAX(hr.ENDING_HEADCOUNT),
    hr.avg_turnover_rate       AS AVG(hr.ANNUALIZED_TURNOVER_RATE)
)
AI_VERIFIED_QUERIES (
    -- VQR 1: Top 10 restaurants by sales this month
    -- Validates that RESTAURANT_NAME is preserved through the gold DT (grain check)
    VERIFIED_QUERY (
        name => 'top_restaurants_by_sales',
        question => 'What are the top 10 restaurants by total sales this month?',
        verified_query => '
            SELECT
                s.RESTAURANT_NAME,
                b.BRAND_NAME,
                s.STATE_CODE,
                s.REGION_NAME,
                SUM(s.WEEKLY_SALES) AS TOTAL_MONTHLY_SALES,
                SUM(s.TRANSACTION_COUNT) AS TOTAL_TRANSACTIONS
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
            WHERE s.WEEK_START_DATE >= DATE_TRUNC(''month'', CURRENT_DATE())
            GROUP BY s.RESTAURANT_NAME, b.BRAND_NAME, s.STATE_CODE, s.REGION_NAME
            ORDER BY TOTAL_MONTHLY_SALES DESC
            LIMIT 10
        '
    ),
    -- VQR 2: 13-week sales trend by brand
    VERIFIED_QUERY (
        name => 'weekly_sales_trend_by_brand',
        question => 'How are weekly sales trending by brand over the last 13 weeks?',
        verified_query => '
            SELECT
                b.BRAND_NAME,
                s.WEEK_START_DATE,
                SUM(s.WEEKLY_SALES)       AS BRAND_WEEKLY_SALES,
                SUM(s.TRANSACTION_COUNT)  AS BRAND_TRANSACTIONS,
                ROUND(AVG(s.AVG_CHECK),2) AS BRAND_AVG_CHECK
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
            WHERE s.WEEK_START_DATE >= DATEADD(''week'', -13, CURRENT_DATE())
            GROUP BY b.BRAND_NAME, s.WEEK_START_DATE
            ORDER BY s.WEEK_START_DATE, b.BRAND_NAME
        '
    ),
    -- VQR 3: Current headcount by brand (most recent month)
    VERIFIED_QUERY (
        name => 'headcount_by_brand',
        question => 'What is our current headcount by brand?',
        verified_query => '
            SELECT
                h.BRAND_NAME,
                h.YEAR_MONTH,
                h.ENDING_HEADCOUNT,
                h.HIRES,
                h.SEPARATIONS
            FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS h
            WHERE h.YEAR_MONTH = (
                SELECT MAX(YEAR_MONTH)
                FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
                WHERE ENDING_HEADCOUNT > 0
            )
            ORDER BY h.ENDING_HEADCOUNT DESC
        '
    ),
    -- VQR 4: Annualized turnover rate by brand (trailing 3 months average)
    VERIFIED_QUERY (
        name => 'turnover_rate_by_brand',
        question => 'Which brands have the highest annualized turnover rate?',
        verified_query => '
            SELECT
                h.BRAND_NAME,
                ROUND(AVG(h.ANNUALIZED_TURNOVER_RATE), 1) AS AVG_TURNOVER_RATE_PCT,
                SUM(h.SEPARATIONS)                        AS TOTAL_SEPARATIONS,
                MAX(h.ENDING_HEADCOUNT)                   AS LATEST_HEADCOUNT
            FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS h
            WHERE h.YEAR_MONTH >= DATEADD(''month'', -3, DATE_TRUNC(''month'', CURRENT_DATE()))
              AND h.ENDING_HEADCOUNT > 0
            GROUP BY h.BRAND_NAME
            ORDER BY AVG_TURNOVER_RATE_PCT DESC
        '
    ),
    -- VQR 5: Week-over-week sales change by region (revenue-weighted, not store average)
    VERIFIED_QUERY (
        name => 'wow_sales_by_region',
        question => 'What is our week-over-week sales change by region?',
        verified_query => '
            WITH week_agg AS (
                SELECT
                    REGION_NAME,
                    WEEK_START_DATE,
                    SUM(WEEKLY_SALES) AS REGION_SALES,
                    COUNT(DISTINCT RESTAURANT_ID) AS RESTAURANT_COUNT
                FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
                WHERE WEEK_START_DATE >= DATEADD(''week'', -5, DATE_TRUNC(''week'', CURRENT_DATE()))
                  AND WEEK_START_DATE <  DATE_TRUNC(''week'', CURRENT_DATE())
                GROUP BY REGION_NAME, WEEK_START_DATE
            )
            SELECT
                curr.REGION_NAME,
                curr.WEEK_START_DATE,
                curr.REGION_SALES,
                prev.REGION_SALES                                     AS PRIOR_WEEK_SALES,
                ROUND(
                    (curr.REGION_SALES - prev.REGION_SALES)
                    / NULLIF(prev.REGION_SALES, 0) * 100
                , 1)                                                  AS WOW_CHANGE_PCT,
                curr.RESTAURANT_COUNT
            FROM week_agg curr
            LEFT JOIN week_agg prev
              ON curr.REGION_NAME = prev.REGION_NAME
             AND prev.WEEK_START_DATE = DATEADD(''week'', -1, curr.WEEK_START_DATE)
            WHERE curr.WEEK_START_DATE = DATEADD(''week'', -1, DATE_TRUNC(''week'', CURRENT_DATE()))
            ORDER BY WOW_CHANGE_PCT DESC
        '
    ),
    -- VQR 6: Top 5 states by total sales this quarter
    VERIFIED_QUERY (
        name => 'top_states_by_sales',
        question => 'What are our top 5 performing states by total revenue this quarter?',
        verified_query => '
            SELECT
                s.STATE_CODE,
                s.REGION_NAME,
                SUM(s.WEEKLY_SALES)              AS QUARTERLY_SALES,
                SUM(s.TRANSACTION_COUNT)         AS QUARTERLY_TRANSACTIONS,
                COUNT(DISTINCT s.RESTAURANT_ID)  AS RESTAURANT_COUNT
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            WHERE s.WEEK_START_DATE >= DATE_TRUNC(''quarter'', CURRENT_DATE())
            GROUP BY s.STATE_CODE, s.REGION_NAME
            ORDER BY QUARTERLY_SALES DESC
            LIMIT 5
        '
    ),
    -- VQR 7: Average check size by brand
    VERIFIED_QUERY (
        name => 'avg_check_by_brand',
        question => 'What is the average check size by brand?',
        verified_query => '
            SELECT
                b.BRAND_NAME,
                b.BRAND_TYPE,
                ROUND(AVG(s.AVG_CHECK), 2)    AS AVG_CHECK_SIZE,
                SUM(s.TRANSACTION_COUNT)      AS TOTAL_TRANSACTIONS,
                COUNT(DISTINCT s.RESTAURANT_ID) AS RESTAURANT_COUNT
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
            WHERE s.WEEK_START_DATE >= DATEADD(''week'', -4, CURRENT_DATE())
            GROUP BY b.BRAND_NAME, b.BRAND_TYPE
            ORDER BY AVG_CHECK_SIZE DESC
        '
    ),
    -- VQR 8: Month-over-month headcount change by brand
    VERIFIED_QUERY (
        name => 'headcount_trend_by_brand',
        question => 'How has headcount changed month-over-month by brand over the last 6 months?',
        verified_query => '
            SELECT
                BRAND_NAME,
                YEAR_MONTH,
                ENDING_HEADCOUNT,
                HIRES,
                SEPARATIONS,
                HEADCOUNT_CHANGE
            FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
            WHERE YEAR_MONTH >= DATEADD(''month'', -6, DATE_TRUNC(''month'', CURRENT_DATE()))
              AND ENDING_HEADCOUNT > 0
            ORDER BY BRAND_NAME, YEAR_MONTH
        '
    ),
    -- VQR 9: Cross-domain — brand growing sales while also losing the most people
    -- Compares first 4 weeks vs last 4 weeks for sales growth (avoids the
    -- "flat 13-week average" problem). Includes separations and headcount
    -- explicitly so the answer names both the growth metric and the people loss.
    VERIFIED_QUERY (
        name => 'brand_sales_vs_turnover',
        question => 'Which brand is growing sales while also losing the most people?',
        verified_query => '
            WITH
            recent_4w AS (
                SELECT BRAND_ID, SUM(WEEKLY_SALES) AS RECENT_SALES
                FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
                WHERE WEEK_START_DATE >= DATEADD(''week'', -4, DATE_TRUNC(''week'', CURRENT_DATE()))
                  AND WEEK_START_DATE <  DATE_TRUNC(''week'', CURRENT_DATE())
                GROUP BY BRAND_ID
            ),
            prior_4w AS (
                SELECT BRAND_ID, SUM(WEEKLY_SALES) AS PRIOR_SALES
                FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
                WHERE WEEK_START_DATE >= DATEADD(''week'', -13, DATE_TRUNC(''week'', CURRENT_DATE()))
                  AND WEEK_START_DATE <  DATEADD(''week'',  -9, DATE_TRUNC(''week'', CURRENT_DATE()))
                GROUP BY BRAND_ID
            ),
            hr_recent AS (
                SELECT BRAND_ID,
                       SUM(SEPARATIONS)                        AS RECENT_SEPARATIONS,
                       MAX(ENDING_HEADCOUNT)                   AS LATEST_HEADCOUNT,
                       ROUND(AVG(ANNUALIZED_TURNOVER_RATE), 1) AS AVG_TURNOVER_RATE
                FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
                WHERE YEAR_MONTH >= DATEADD(''month'', -3, DATE_TRUNC(''month'', CURRENT_DATE()))
                  AND ENDING_HEADCOUNT > 0
                GROUP BY BRAND_ID
            )
            SELECT
                b.BRAND_NAME,
                ROUND(r.RECENT_SALES,     0) AS RECENT_4W_SALES,
                ROUND(p.PRIOR_SALES,      0) AS PRIOR_4W_SALES,
                ROUND((r.RECENT_SALES - p.PRIOR_SALES)
                      / NULLIF(p.PRIOR_SALES, 0) * 100, 1) AS SALES_GROWTH_PCT,
                hr.LATEST_HEADCOUNT,
                hr.RECENT_SEPARATIONS,
                hr.AVG_TURNOVER_RATE
            FROM CUSTOMER_DEMOS.WKS.BRANDS b
            JOIN recent_4w  r  ON b.BRAND_ID = r.BRAND_ID
            JOIN prior_4w   p  ON b.BRAND_ID = p.BRAND_ID
            JOIN hr_recent  hr ON b.BRAND_ID = hr.BRAND_ID
            ORDER BY hr.RECENT_SEPARATIONS DESC, SALES_GROWTH_PCT DESC
        '
    )
);

-- ---------------------------------------------------------------------------
-- VQR VALIDATION — run all 9 as a batch after semantic view creation.
-- Every result must be > 0. If any is 0, check the source DTs have data.
-- ---------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM (
        SELECT s.RESTAURANT_NAME, SUM(s.WEEKLY_SALES) FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATE_TRUNC('month', CURRENT_DATE())
        GROUP BY s.RESTAURANT_NAME ORDER BY 2 DESC LIMIT 10
    ))                                                          AS vqr1_top_restaurants,
    (SELECT COUNT(*) FROM (
        SELECT b.BRAND_NAME, s.WEEK_START_DATE, SUM(s.WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATEADD('week', -13, CURRENT_DATE())
        GROUP BY 1, 2
    ))                                                          AS vqr2_sales_trend,
    (SELECT COUNT(*) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
     WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS WHERE ENDING_HEADCOUNT > 0))
                                                                AS vqr3_headcount,
    (SELECT COUNT(*) FROM (
        SELECT BRAND_NAME, AVG(ANNUALIZED_TURNOVER_RATE)
        FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
        WHERE YEAR_MONTH >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE())) AND ENDING_HEADCOUNT > 0
        GROUP BY 1
    ))                                                          AS vqr4_turnover,
    (SELECT COUNT(*) FROM (
        SELECT REGION_NAME, WEEK_START_DATE, SUM(WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        WHERE WEEK_START_DATE >= DATEADD('week', -4, CURRENT_DATE()) AND WOW_CHANGE_PCT IS NOT NULL
        GROUP BY 1, 2
    ))                                                          AS vqr5_wow_region,
    (SELECT COUNT(*) FROM (
        SELECT STATE_CODE, SUM(WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        WHERE WEEK_START_DATE >= DATE_TRUNC('quarter', CURRENT_DATE())
        GROUP BY 1 ORDER BY 2 DESC LIMIT 5
    ))                                                          AS vqr6_top_states,
    (SELECT COUNT(*) FROM (
        SELECT b.BRAND_NAME, AVG(s.AVG_CHECK)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATEADD('week', -4, CURRENT_DATE())
        GROUP BY 1
    ))                                                          AS vqr7_avg_check,
    (SELECT COUNT(*) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
     WHERE YEAR_MONTH >= DATEADD('month', -6, DATE_TRUNC('month', CURRENT_DATE())) AND ENDING_HEADCOUNT > 0)
                                                                AS vqr8_headcount_trend,
    -- VQR 9: run the actual query to confirm EPL leads on separations + both brands show growth
    (SELECT COUNT(*) FROM (
        WITH
        recent_4w AS (
            SELECT BRAND_ID, SUM(WEEKLY_SALES) AS RECENT_SALES
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
            WHERE WEEK_START_DATE >= DATEADD('week', -4, DATE_TRUNC('week', CURRENT_DATE()))
              AND WEEK_START_DATE <  DATE_TRUNC('week', CURRENT_DATE())
            GROUP BY BRAND_ID
        ),
        prior_4w AS (
            SELECT BRAND_ID, SUM(WEEKLY_SALES) AS PRIOR_SALES
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
            WHERE WEEK_START_DATE >= DATEADD('week', -13, DATE_TRUNC('week', CURRENT_DATE()))
              AND WEEK_START_DATE <  DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE()))
            GROUP BY BRAND_ID
        ),
        hr_recent AS (
            SELECT BRAND_ID, SUM(SEPARATIONS) AS RECENT_SEPARATIONS,
                   MAX(ENDING_HEADCOUNT) AS LATEST_HEADCOUNT,
                   ROUND(AVG(ANNUALIZED_TURNOVER_RATE),1) AS AVG_TURNOVER_RATE
            FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
            WHERE YEAR_MONTH >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
              AND ENDING_HEADCOUNT > 0
            GROUP BY BRAND_ID
        )
        SELECT b.BRAND_NAME,
               ROUND((r.RECENT_SALES - p.PRIOR_SALES)/NULLIF(p.PRIOR_SALES,0)*100,1) AS SALES_GROWTH_PCT,
               hr.RECENT_SEPARATIONS, hr.AVG_TURNOVER_RATE
        FROM CUSTOMER_DEMOS.WKS.BRANDS b
        JOIN recent_4w r ON b.BRAND_ID = r.BRAND_ID
        JOIN prior_4w  p ON b.BRAND_ID = p.BRAND_ID
        JOIN hr_recent hr ON b.BRAND_ID = hr.BRAND_ID
        ORDER BY hr.RECENT_SEPARATIONS DESC, SALES_GROWTH_PCT DESC
    ))                                                          AS vqr9_brand_sales_vs_turnover;
