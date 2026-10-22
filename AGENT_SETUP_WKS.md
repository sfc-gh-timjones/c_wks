# WKS Assistant — Agent Setup and Demo Questions

## Agent Details

| Field | Value |
|-------|-------|
| FQN | `CUSTOMER_DEMOS.WKS.WKS_AGENT` |
| Display Name | WKS Assistant |
| Model | claude-sonnet-4-6 |
| Semantic View | `CUSTOMER_DEMOS.WKS.WKS_SEMANTIC_VIEW` |
| Search Service | `CUSTOMER_DEMOS.WKS.WKS_HR_SEARCH` |
| Email Proc | `CUSTOMER_DEMOS.WKS.WKS_SEND_EMAIL` |

---

## Adding / Removing the Agent from Snowflake Intelligence

```sql
-- Add (run after CREATE AGENT)
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT CUSTOMER_DEMOS.WKS.WKS_AGENT;

-- Remove (run in 99_teardown.sql before DROP AGENT)
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    DROP AGENT CUSTOMER_DEMOS.WKS.WKS_AGENT;
```

---

## 35 Demo Questions by Category

### Sales Analytics
1. What are the top 10 restaurants by total sales this month?
2. How are weekly sales trending by brand over the last 13 weeks?
3. What is our week-over-week sales change by region?
4. What are our top 5 performing states by total revenue this quarter?
5. What is the average check size by brand?
6. Which regions are showing the strongest sales growth right now?
7. Show weekly sales for Wendy's over the last 13 weeks as a line chart.
8. Which restaurants are underperforming their 4-week rolling average?
9. What is the total transaction count by order channel this month?
10. Compare Wendy's and El Pollo Loco weekly sales side by side for the last quarter.

### HR & Workforce
11. What is our current headcount by brand?
12. Which brands have the highest annualized turnover rate?
13. How has headcount changed month-over-month by brand?
14. How many hires and separations did we have last month?
15. Show me annualized turnover rate by brand as a bar chart.
16. Which brand has the most full-time employees?
17. What was our total headcount 6 months ago compared to today?
18. Show the trend in separations by brand over the last 6 months.
19. How many employees are part-time vs full-time by brand?
20. Which month had the highest number of new hires in the last year?

### Cross-Domain (Sales + HR)
21. Which brand is growing sales while losing the most people?
22. Show me sales per employee by brand as a horizontal bar chart.
23. Which brands have both high turnover and declining sales?
24. Compare Denny's headcount trend alongside its weekly sales trend.
25. Which region has the best sales performance relative to its headcount?

### Cortex Search (Policies & Standards)
26. What does the WKS attendance policy say about calling out of a shift?
27. How do I report a workplace injury at WKS?
28. What are the Wendy's speed-of-service targets?
29. What is the hold time for El Pollo Loco grilled chicken after it comes off the grill?
30. What benefits are available to full-time WKS employees?
31. What are the Krispy Kreme Hot Light production schedule guidelines?
32. What is the WKS policy on sharing company data with AI tools?

### Email & Reporting
33. Email me a weekly sales summary for all brands to [email address].
34. Send a turnover report for the last 3 months to [email address].
35. Email the top 10 restaurant rankings for this week to [email address].

---

## VQR Validation Query

Run this after creating the semantic view to confirm all 9 VQRs return data:

```sql
SELECT
    (SELECT COUNT(*) FROM (
        SELECT s.RESTAURANT_NAME, SUM(s.WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATE_TRUNC('month', CURRENT_DATE())
        GROUP BY s.RESTAURANT_NAME ORDER BY 2 DESC LIMIT 10
    )) AS vqr1_top_restaurants,
    (SELECT COUNT(*) FROM (
        SELECT b.BRAND_NAME, s.WEEK_START_DATE, SUM(s.WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATEADD('week', -13, CURRENT_DATE())
        GROUP BY 1, 2
    )) AS vqr2_sales_trend,
    (SELECT COUNT(*) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
     WHERE YEAR_MONTH = (SELECT MAX(YEAR_MONTH) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS WHERE ENDING_HEADCOUNT > 0)
    ) AS vqr3_headcount,
    (SELECT COUNT(*) FROM (
        SELECT BRAND_NAME, AVG(ANNUALIZED_TURNOVER_RATE)
        FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
        WHERE YEAR_MONTH >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
          AND ENDING_HEADCOUNT > 0
        GROUP BY 1
    )) AS vqr4_turnover,
    (SELECT COUNT(*) FROM (
        SELECT REGION_NAME, WEEK_START_DATE, SUM(WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        WHERE WEEK_START_DATE >= DATEADD('week', -4, CURRENT_DATE())
          AND WOW_CHANGE_PCT IS NOT NULL
        GROUP BY 1, 2
    )) AS vqr5_wow_region,
    (SELECT COUNT(*) FROM (
        SELECT STATE_CODE, SUM(WEEKLY_SALES)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
        WHERE WEEK_START_DATE >= DATE_TRUNC('quarter', CURRENT_DATE())
        GROUP BY 1 ORDER BY 2 DESC LIMIT 5
    )) AS vqr6_top_states,
    (SELECT COUNT(*) FROM (
        SELECT b.BRAND_NAME, AVG(s.AVG_CHECK)
        FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
        JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
        WHERE s.WEEK_START_DATE >= DATEADD('week', -4, CURRENT_DATE())
        GROUP BY 1
    )) AS vqr7_avg_check,
    (SELECT COUNT(*) FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS
     WHERE YEAR_MONTH >= DATEADD('month', -6, DATE_TRUNC('month', CURRENT_DATE()))
       AND ENDING_HEADCOUNT > 0
    ) AS vqr8_headcount_trend;
```

All values should be > 0.

---

## React Dashboard — SPCS Deployment

### 1. Create Snowflake infrastructure

```sql
CREATE IMAGE REPOSITORY IF NOT EXISTS CUSTOMER_DEMOS.WKS.IMAGE_REPO;
CREATE COMPUTE POOL IF NOT EXISTS WKS_DEMO_POOL
    MIN_NODES = 1 MAX_NODES = 2
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_SUSPEND_SECS = 3600
    AUTO_RESUME = TRUE;

SHOW IMAGE REPOSITORIES IN SCHEMA CUSTOMER_DEMOS.WKS;
-- Copy the repository_url value
```

### 2. Build and push

```bash
REGISTRY=<repository_url from above>
IMAGE=$REGISTRY/wks-dashboard

# Login to Snowflake image registry
snow spcs image-registry login --connection <your-connection>

# Build (always linux/amd64 even on Apple Silicon)
cd wks_si/react-app
docker build --no-cache --platform linux/amd64 -t $IMAGE:v1 .
docker push $IMAGE:v1
```

### 3. Create the service

```sql
CREATE SERVICE CUSTOMER_DEMOS.WKS.WKS_DASHBOARD_SVC
    IN COMPUTE POOL WKS_DEMO_POOL
    FROM SPECIFICATION $$
    spec:
      containers:
        - name: wks-dashboard
          image: /customer_demos/wks/image_repo/wks-dashboard:v1
          env:
            SF_DATABASE:  CUSTOMER_DEMOS
            SF_SCHEMA:    WKS
            SF_WAREHOUSE: WKS_WH
            # Do NOT set SNOWFLAKE_HOST — SPCS injects it automatically
          readinessProbe:
            port: 3000
            path: /api/health
      endpoints:
        - name: app
          port: 3000
          public: true
    $$;

-- Check status
SELECT SYSTEM$GET_SERVICE_STATUS('CUSTOMER_DEMOS.WKS.WKS_DASHBOARD_SVC');
SHOW ENDPOINTS IN SERVICE CUSTOMER_DEMOS.WKS.WKS_DASHBOARD_SVC;
```

### 4. Grant access

```sql
-- Other roles that need to reach the public URL
GRANT USAGE ON SERVICE CUSTOMER_DEMOS.WKS.WKS_DASHBOARD_SVC TO ROLE <role>;
```

---

## Row Access Policy — Important Notes

**Coverage:** `RESTAURANTS` (base table) and `DT_WEEKLY_RESTAURANT_SALES` (DT). Covers all Snowflake Intelligence queries through the semantic view. Does **not** cover `DT_BRAND_WEEKLY_SUMMARY` (the React dashboard data source, which has no district column) or the SPCS service role.

**Fail-open behavior:** Users NOT in `WKS_DISTRICT_USER_MAP` see all rows. This is intentional for Grace's team (power users). In a production design you would flip this to deny-by-default. Frame it in the demo as "a starting point" rather than production-ready.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| VQR error: `invalid identifier '__TABLE.COLUMN'` | Semantic name ≠ physical column name | Ensure left of AS matches right of AS exactly (case-insensitive) |
| Agent not in SI UI | CREATE OR REPLACE left stale SI registration | DROP AGENT from SI, then ADD AGENT |
| Dashboard fails SPCS health check | `ENV HOSTNAME` missing in Dockerfile | Ensure `ENV HOSTNAME="0.0.0.0"` is in runner stage |
| Chat panel returns empty | SSE `content_index > 0` filter | Use `>= 0` — VQR answers arrive at index 0 |
| DT stuck in FAILED | Upstream table has no data | Check that scripts 03+04 ran successfully first |
| Cortex Search service not ACTIVE | Still indexing | Wait 1–2 minutes after creation |
