-- =============================================================================
-- 06: CREATE SEMANTIC VIEW + VALIDATED QUERIES (VQRs)
-- WKS Restaurant Group SI Demo
--
-- SYNTAX NOTES (learned from deployment):
--   TABLES clause:  alias AS full_table_name [PRIMARY KEY (col)]
--                   (NOT full_table_name AS alias)
--   VQRs:           name AS (QUESTION '...' SQL '...')
--                   (NOT VERIFIED_QUERY (name => ..., question => ...))
--   PK RELY required on BRANDS before creating this view.
--
-- Grain contract:
--   DT_WEEKLY_RESTAURANT_SALES → restaurant × week (sales facts)
--   DT_HR_BRAND_METRICS        → brand × month     (HR facts)
--   BRANDS                     → shared dimension bridge
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

-- Required: BRANDS.BRAND_ID must have RELY=TRUE for the relationship to be valid
ALTER TABLE CUSTOMER_DEMOS.WKS.BRANDS MODIFY PRIMARY KEY RELY;

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER_DEMOS.WKS.WKS_SEMANTIC_VIEW
TABLES (
    -- Alias FIRST, then AS, then fully qualified table name
    sales AS CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES,
    hr    AS CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS,
    brand AS CUSTOMER_DEMOS.WKS.BRANDS PRIMARY KEY (BRAND_ID)
)
RELATIONSHIPS (
    sales ( BRAND_ID ) REFERENCES brand ( BRAND_ID ),
    hr    ( BRAND_ID ) REFERENCES brand ( BRAND_ID )
)
FACTS (
    sales.weekly_sales              AS WEEKLY_SALES,
    sales.transaction_count         AS TRANSACTION_COUNT,
    sales.avg_check                 AS AVG_CHECK,
    sales.wow_change_pct            AS WOW_CHANGE_PCT,
    sales.yoy_change_pct            AS YOY_CHANGE_PCT,
    sales.rolling_4wk_avg           AS ROLLING_4WK_AVG,
    hr.hires                        AS HIRES,
    hr.separations                  AS SEPARATIONS,
    hr.ending_headcount             AS ENDING_HEADCOUNT,
    hr.annualized_turnover_rate     AS ANNUALIZED_TURNOVER_RATE
)
DIMENSIONS (
    sales.restaurant_id             AS RESTAURANT_ID,
    sales.restaurant_name           AS RESTAURANT_NAME,
    sales.state_code                AS STATE_CODE,
    sales.region_name               AS REGION_NAME,
    sales.week_start_date           AS WEEK_START_DATE,
    hr.year_month                   AS YEAR_MONTH,
    brand.brand_name                AS BRAND_NAME,
    brand.brand_type                AS BRAND_TYPE
)
METRICS (
    -- Metric names must not duplicate fact names
    sales.sum_weekly_sales          AS SUM(sales.WEEKLY_SALES),
    sales.sum_transactions          AS SUM(sales.TRANSACTION_COUNT),
    sales.mean_check_size           AS AVG(sales.AVG_CHECK),
    sales.mean_wow_change           AS AVG(sales.WOW_CHANGE_PCT),
    sales.mean_yoy_change           AS AVG(sales.YOY_CHANGE_PCT),
    hr.sum_hires                    AS SUM(hr.HIRES),
    hr.sum_separations              AS SUM(hr.SEPARATIONS),
    hr.peak_headcount               AS MAX(hr.ENDING_HEADCOUNT),
    hr.mean_turnover_rate           AS AVG(hr.ANNUALIZED_TURNOVER_RATE)
)
AI_VERIFIED_QUERIES (
    -- VQR syntax: name AS (QUESTION '...' SQL '...')
    top_restaurants_by_sales AS (
        QUESTION 'What are the top 10 restaurants by total sales this month?'
        SQL '
            SELECT
                s.RESTAURANT_NAME,
                b.BRAND_NAME,
                s.STATE_CODE,
                s.REGION_NAME,
                SUM(s.WEEKLY_SALES)      AS TOTAL_MONTHLY_SALES,
                SUM(s.TRANSACTION_COUNT) AS TOTAL_TRANSACTIONS
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
            WHERE s.WEEK_START_DATE >= DATE_TRUNC(''month'', CURRENT_DATE())
            GROUP BY s.RESTAURANT_NAME, b.BRAND_NAME, s.STATE_CODE, s.REGION_NAME
            ORDER BY TOTAL_MONTHLY_SALES DESC
            LIMIT 10
        '
    ),
    weekly_sales_trend_by_brand AS (
        QUESTION 'How are weekly sales trending by brand over the last 13 weeks?'
        SQL '
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
    headcount_by_brand AS (
        QUESTION 'What is our current headcount by brand?'
        SQL '
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
    turnover_rate_by_brand AS (
        QUESTION 'Which brands have the highest annualized turnover rate?'
        SQL '
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
    wow_sales_by_region AS (
        QUESTION 'What is our week-over-week sales change by region?'
        SQL '
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
    top_states_by_sales AS (
        QUESTION 'What are our top 5 performing states by total revenue this quarter?'
        SQL '
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
    avg_check_by_brand AS (
        QUESTION 'What is the average check size by brand?'
        SQL '
            SELECT
                b.BRAND_NAME,
                b.BRAND_TYPE,
                ROUND(AVG(s.AVG_CHECK), 2)      AS AVG_CHECK_SIZE,
                SUM(s.TRANSACTION_COUNT)         AS TOTAL_TRANSACTIONS,
                COUNT(DISTINCT s.RESTAURANT_ID)  AS RESTAURANT_COUNT
            FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
            JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
            WHERE s.WEEK_START_DATE >= DATEADD(''week'', -4, CURRENT_DATE())
            GROUP BY b.BRAND_NAME, b.BRAND_TYPE
            ORDER BY AVG_CHECK_SIZE DESC
        '
    ),
    headcount_trend_by_brand AS (
        QUESTION 'How has headcount changed month-over-month by brand over the last 6 months?'
        SQL '
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
    brand_sales_vs_turnover AS (
        QUESTION 'Which brand is growing sales while also losing the most people?'
        SQL '
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
-- VQR VALIDATION — run all 9 as a batch. Every result must be > 0.
-- ---------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM (
        SELECT s.RESTAURANT_NAME, SUM(s.WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
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
     WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS WHERE ENDING_HEADCOUNT > 0)
    )                                                           AS vqr3_headcount,
    (SELECT COUNT(*) FROM (
        SELECT BRAND_NAME, AVG(ANNUALIZED_TURNOVER_RATE)
        FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
        WHERE YEAR_MONTH >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
          AND ENDING_HEADCOUNT > 0
        GROUP BY 1
    ))                                                          AS vqr4_turnover,
    (SELECT COUNT(*) FROM (
        SELECT REGION_NAME, WEEK_START_DATE, SUM(WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        WHERE WEEK_START_DATE >= DATEADD('week', -4, CURRENT_DATE())
          AND WOW_CHANGE_PCT IS NOT NULL
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
     WHERE YEAR_MONTH >= DATEADD('month', -6, DATE_TRUNC('month', CURRENT_DATE()))
       AND ENDING_HEADCOUNT > 0
    )                                                           AS vqr8_headcount_trend,
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
