-- =============================================================================
-- 03: GENERATE SYNTHETIC DATA (SQL GENERATOR)
-- WKS Restaurant Group SI Demo
--
-- FIXES applied vs v1:
--   - RESTAURANTS: state/region/district/city derived consistently from a
--     single state roll — no more independent random draws per field
--   - TRANSACTIONS: check amount and order channel vary by brand (via
--     restaurant ID range). Denny's transactions have no DRIVE_THRU channel.
--
-- Load order: REGIONS → STATES → BRANDS → DEPARTMENTS → JOB_POSITIONS →
--             DISTRICTS → RESTAURANTS → TRANSACTIONS
--
-- EMPLOYEES and EMPLOYEE_EVENTS are generated in script 04 (Faker + numpy).
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

-- ---------------------------------------------------------------------------
-- REGIONS (5 rows)
-- ---------------------------------------------------------------------------
INSERT INTO REGIONS (REGION_NAME) VALUES
    ('Pacific'),
    ('Mountain'),
    ('Southwest'),
    ('Southeast'),
    ('Central');

-- ---------------------------------------------------------------------------
-- STATES (19 rows, western and central US — WKS footprint)
-- ---------------------------------------------------------------------------
INSERT INTO STATES (STATE_CODE, STATE_NAME, REGION_ID) VALUES
    -- Pacific   (REGION_ID 1)
    ('CA', 'California',    1),
    ('OR', 'Oregon',        1),
    ('WA', 'Washington',    1),
    -- Mountain  (REGION_ID 2)
    ('CO', 'Colorado',      2),
    ('UT', 'Utah',          2),
    ('AZ', 'Arizona',       2),
    ('NV', 'Nevada',        2),
    -- Southwest (REGION_ID 3)
    ('TX', 'Texas',         3),
    ('NM', 'New Mexico',    3),
    ('OK', 'Oklahoma',      3),
    ('AR', 'Arkansas',      3),
    ('LA', 'Louisiana',     3),
    -- Southeast (REGION_ID 4)
    ('GA', 'Georgia',       4),
    ('FL', 'Florida',       4),
    ('NC', 'North Carolina',4),
    ('SC', 'South Carolina',4),
    ('TN', 'Tennessee',     4),
    -- Central   (REGION_ID 5)
    ('MO', 'Missouri',      5),
    ('ID', 'Idaho',         5);

-- ---------------------------------------------------------------------------
-- BRANDS (5 rows)
-- ---------------------------------------------------------------------------
INSERT INTO BRANDS (BRAND_NAME, BRAND_CODE, BRAND_TYPE, BRAND_COLOR) VALUES
    ('Wendy''s',       'WEN', 'QSR',    '#E2231A'),
    ('Denny''s',       'DEN', 'DINER',  '#FF9900'),
    ('El Pollo Loco',  'EPL', 'QSR',    '#E85C14'),
    ('Krispy Kreme',   'KK',  'BAKERY', '#00A0B0'),
    ('Blaze Pizza',    'BLZ', 'CASUAL', '#EF3F23');

-- ---------------------------------------------------------------------------
-- DEPARTMENTS (8 rows)
-- ---------------------------------------------------------------------------
INSERT INTO DEPARTMENTS (DEPARTMENT_NAME, DEPARTMENT_TYPE) VALUES
    ('Front of House',         'FOH'),
    ('Back of House',          'BOH'),
    ('Restaurant Management',  'MGMT'),
    ('District Operations',    'MGMT'),
    ('Regional Operations',    'MGMT'),
    ('Human Resources',        'CORPORATE'),
    ('Finance & Accounting',   'CORPORATE'),
    ('Information Technology', 'CORPORATE');

-- ---------------------------------------------------------------------------
-- JOB_POSITIONS (24 rows)
-- ---------------------------------------------------------------------------
INSERT INTO JOB_POSITIONS (POSITION_TITLE, POSITION_LEVEL, DEPARTMENT_ID, HOURLY_RATE_MIN, HOURLY_RATE_MAX) VALUES
    ('Cashier',                  'CREW',       1,  12.00,  16.00),
    ('Drive-Thru Operator',      'CREW',       1,  12.00,  16.00),
    ('Customer Service Lead',    'SHIFT_LEAD', 1,  16.00,  20.00),
    ('Line Cook',                'CREW',       2,  13.00,  17.00),
    ('Prep Cook',                'CREW',       2,  12.00,  15.00),
    ('Grill Operator',           'CREW',       2,  13.00,  17.00),
    ('Kitchen Lead',             'SHIFT_LEAD', 2,  16.50,  21.00),
    ('Shift Manager',            'MANAGER',    3,  18.00,  24.00),
    ('Assistant Manager',        'MANAGER',    3,  22.00,  30.00),
    ('General Manager',          'MANAGER',    3,  28.00,  42.00),
    ('District Trainer',         'MANAGER',    4,  24.00,  32.00),
    ('District Manager',         'DIRECTOR',   4,  35.00,  55.00),
    ('Regional Director',        'DIRECTOR',   5,  50.00,  80.00),
    ('VP of Operations',         'CORPORATE',  5,  75.00, 120.00),
    ('HR Coordinator',           'CORPORATE',  6,  22.00,  30.00),
    ('HR Business Partner',      'CORPORATE',  6,  30.00,  45.00),
    ('HR Director',              'CORPORATE',  6,  45.00,  70.00),
    ('Accounts Payable Clerk',   'CORPORATE',  7,  20.00,  28.00),
    ('Financial Analyst',        'CORPORATE',  7,  30.00,  50.00),
    ('Controller',               'CORPORATE',  7,  55.00,  90.00),
    ('IT Support Specialist',    'CORPORATE',  8,  22.00,  32.00),
    ('Data Engineer',            'CORPORATE',  8,  35.00,  60.00),
    ('Data Intelligence Lead',   'CORPORATE',  8,  45.00,  75.00),
    ('Software Engineer',        'CORPORATE',  8,  40.00,  70.00);

-- ---------------------------------------------------------------------------
-- DISTRICTS (20 rows)
-- Districts are inserted in region order so DISTRICT_ID ranges are predictable:
--   Pacific   (region 1): IDs 1–5
--   Mountain  (region 2): IDs 6–9
--   Southwest (region 3): IDs 10–14
--   Southeast (region 4): IDs 15–18
--   Central   (region 5): IDs 19–20
-- ---------------------------------------------------------------------------
INSERT INTO DISTRICTS (DISTRICT_NAME, REGION_ID) VALUES
    -- Pacific (region 1)
    ('LA Metro',          1),
    ('San Diego',         1),
    ('Central Valley',    1),
    ('Bay Area',          1),
    ('Pacific Northwest', 1),
    -- Mountain (region 2)
    ('Denver Metro',      2),
    ('Phoenix Metro',     2),
    ('Las Vegas',         2),
    ('Salt Lake City',    2),
    -- Southwest (region 3)
    ('Dallas-Ft Worth',   3),
    ('Houston',           3),
    ('San Antonio',       3),
    ('Oklahoma City',     3),
    ('Gulf Coast',        3),
    -- Southeast (region 4)
    ('Atlanta',           4),
    ('Florida',           4),
    ('Carolinas',         4),
    ('Tennessee',         4),
    -- Central (region 5)
    ('Kansas City',       5),
    ('Mountain West',     5);

-- ---------------------------------------------------------------------------
-- RESTAURANTS (350 rows)
-- State, region, district, and city are derived from a SINGLE state roll so
-- they are always internally consistent. No more independent random draws.
--
-- Brand distribution: Wendy's 140 (IDs 1–140), Denny's 105 (141–245),
--   EPL 65 (246–310), Krispy Kreme 25 (311–335), Blaze Pizza 15 (336–350)
--
-- District ID ranges derived from region:
--   Region 1 → UNIFORM(1,5)  Region 2 → UNIFORM(6,9)
--   Region 3 → UNIFORM(10,14) Region 4 → UNIFORM(15,18)
--   Region 5 → UNIFORM(19,20)
-- ---------------------------------------------------------------------------

-- Macro CTE pattern used for each brand — pick state once, derive everything else.

-- Wendy's (brand_id=1): 140 restaurants, strong CA/TX/FL/AZ footprint
INSERT INTO RESTAURANTS (RESTAURANT_NAME, BRAND_ID, STATE_CODE, REGION_ID, DISTRICT_ID, CITY, IS_ACTIVE, OPEN_DATE, SEATING_CAPACITY, HAS_DRIVE_THRU)
WITH base AS (
    SELECT SEQ4() AS N, UNIFORM(1,100,RANDOM()) AS SR, UNIFORM(1,100,RANDOM()) AS CR
    FROM TABLE(GENERATOR(ROWCOUNT => 140))
),
geo AS (
    SELECT N, CR,
        CASE WHEN SR<=25 THEN 'CA' WHEN SR<=42 THEN 'TX' WHEN SR<=50 THEN 'FL'
             WHEN SR<=57 THEN 'AZ' WHEN SR<=63 THEN 'CO' WHEN SR<=68 THEN 'GA'
             WHEN SR<=73 THEN 'OR' WHEN SR<=78 THEN 'WA' WHEN SR<=82 THEN 'NV'
             WHEN SR<=86 THEN 'TN' WHEN SR<=89 THEN 'NC' WHEN SR<=92 THEN 'MO'
             WHEN SR<=95 THEN 'OK' WHEN SR<=97 THEN 'UT' ELSE 'SC' END AS ST
    FROM base
),
full_geo AS (
    SELECT N, ST,
        CASE ST WHEN 'CA' THEN 1 WHEN 'OR' THEN 1 WHEN 'WA' THEN 1
                WHEN 'CO' THEN 2 WHEN 'UT' THEN 2 WHEN 'AZ' THEN 2 WHEN 'NV' THEN 2
                WHEN 'TX' THEN 3 WHEN 'NM' THEN 3 WHEN 'OK' THEN 3 WHEN 'AR' THEN 3 WHEN 'LA' THEN 3
                WHEN 'GA' THEN 4 WHEN 'FL' THEN 4 WHEN 'NC' THEN 4 WHEN 'SC' THEN 4 WHEN 'TN' THEN 4
                ELSE 5 END AS RID,
        CASE ST WHEN 'CA' THEN CASE WHEN CR<=35 THEN 'Los Angeles' WHEN CR<=65 THEN 'San Diego' WHEN CR<=80 THEN 'Sacramento' ELSE 'Riverside' END
                WHEN 'TX' THEN CASE WHEN CR<=40 THEN 'Houston' WHEN CR<=70 THEN 'Dallas' WHEN CR<=85 THEN 'San Antonio' ELSE 'Austin' END
                WHEN 'FL' THEN CASE WHEN CR<=55 THEN 'Orlando' WHEN CR<=80 THEN 'Miami' ELSE 'Tampa' END
                WHEN 'AZ' THEN CASE WHEN CR<=80 THEN 'Phoenix' ELSE 'Tucson' END
                WHEN 'CO' THEN 'Denver' WHEN 'GA' THEN 'Atlanta' WHEN 'OR' THEN 'Portland'
                WHEN 'WA' THEN 'Seattle' WHEN 'NV' THEN 'Las Vegas'
                WHEN 'TN' THEN CASE WHEN CR<=60 THEN 'Nashville' ELSE 'Memphis' END
                WHEN 'NC' THEN 'Charlotte' WHEN 'MO' THEN 'Kansas City'
                WHEN 'OK' THEN 'Oklahoma City' WHEN 'UT' THEN 'Salt Lake City'
                ELSE 'Greenville' END AS CITY
    FROM geo
)
SELECT
    'Wendy''s #' || LPAD(N+1, 4, '0'),  1,  ST,  RID,
    CASE RID WHEN 1 THEN UNIFORM(1,5,RANDOM()) WHEN 2 THEN UNIFORM(6,9,RANDOM())
             WHEN 3 THEN UNIFORM(10,14,RANDOM()) WHEN 4 THEN UNIFORM(15,18,RANDOM())
             ELSE UNIFORM(19,20,RANDOM()) END,
    CITY, TRUE,
    DATEADD('day', -UNIFORM(365,3650,RANDOM()), CURRENT_DATE()),
    UNIFORM(40,80,RANDOM()),
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 8 THEN TRUE ELSE FALSE END
FROM full_geo;

-- Denny's (brand_id=2): 105 restaurants, CA/AZ/NV/TX/FL focus
INSERT INTO RESTAURANTS (RESTAURANT_NAME, BRAND_ID, STATE_CODE, REGION_ID, DISTRICT_ID, CITY, IS_ACTIVE, OPEN_DATE, SEATING_CAPACITY, HAS_DRIVE_THRU)
WITH base AS (
    SELECT SEQ4() AS N, UNIFORM(1,100,RANDOM()) AS SR, UNIFORM(1,100,RANDOM()) AS CR
    FROM TABLE(GENERATOR(ROWCOUNT => 105))
),
geo AS (
    SELECT N, CR,
        CASE WHEN SR<=30 THEN 'CA' WHEN SR<=45 THEN 'TX' WHEN SR<=55 THEN 'AZ'
             WHEN SR<=65 THEN 'NV' WHEN SR<=73 THEN 'FL' WHEN SR<=80 THEN 'CO'
             WHEN SR<=86 THEN 'GA' WHEN SR<=91 THEN 'TN' WHEN SR<=95 THEN 'OR'
             ELSE 'WA' END AS ST
    FROM base
),
full_geo AS (
    SELECT N, ST,
        CASE ST WHEN 'CA' THEN 1 WHEN 'OR' THEN 1 WHEN 'WA' THEN 1
                WHEN 'CO' THEN 2 WHEN 'AZ' THEN 2 WHEN 'NV' THEN 2
                WHEN 'TX' THEN 3
                WHEN 'GA' THEN 4 WHEN 'FL' THEN 4 WHEN 'TN' THEN 4
                ELSE 5 END AS RID,
        CASE ST WHEN 'CA' THEN CASE WHEN CR<=40 THEN 'Los Angeles' WHEN CR<=70 THEN 'San Diego' ELSE 'Sacramento' END
                WHEN 'TX' THEN CASE WHEN CR<=50 THEN 'Houston' ELSE 'Dallas' END
                WHEN 'AZ' THEN 'Phoenix' WHEN 'NV' THEN 'Las Vegas'
                WHEN 'FL' THEN CASE WHEN CR<=55 THEN 'Miami' ELSE 'Orlando' END
                WHEN 'CO' THEN 'Denver' WHEN 'GA' THEN 'Atlanta'
                WHEN 'TN' THEN 'Nashville' WHEN 'OR' THEN 'Portland'
                ELSE 'Seattle' END AS CITY
    FROM geo
)
SELECT
    'Denny''s #' || LPAD(N+1, 4, '0'),  2,  ST,  RID,
    CASE RID WHEN 1 THEN UNIFORM(1,5,RANDOM()) WHEN 2 THEN UNIFORM(6,9,RANDOM())
             WHEN 3 THEN UNIFORM(10,14,RANDOM()) WHEN 4 THEN UNIFORM(15,18,RANDOM())
             ELSE UNIFORM(19,20,RANDOM()) END,
    CITY, TRUE,
    DATEADD('day', -UNIFORM(365,5475,RANDOM()), CURRENT_DATE()),
    UNIFORM(80,160,RANDOM()),
    FALSE   -- Denny's is a full-service diner; no drive-thru
FROM full_geo;

-- El Pollo Loco (brand_id=3): 65 restaurants, CA/AZ/TX/NV dominant
INSERT INTO RESTAURANTS (RESTAURANT_NAME, BRAND_ID, STATE_CODE, REGION_ID, DISTRICT_ID, CITY, IS_ACTIVE, OPEN_DATE, SEATING_CAPACITY, HAS_DRIVE_THRU)
WITH base AS (
    SELECT SEQ4() AS N, UNIFORM(1,100,RANDOM()) AS SR, UNIFORM(1,100,RANDOM()) AS CR
    FROM TABLE(GENERATOR(ROWCOUNT => 65))
),
geo AS (
    SELECT N, CR,
        CASE WHEN SR<=45 THEN 'CA' WHEN SR<=65 THEN 'AZ' WHEN SR<=80 THEN 'TX'
             WHEN SR<=90 THEN 'NV' ELSE 'CO' END AS ST
    FROM base
),
full_geo AS (
    SELECT N, ST,
        CASE ST WHEN 'CA' THEN 1 WHEN 'AZ' THEN 2 WHEN 'NV' THEN 2 WHEN 'CO' THEN 2
                ELSE 3 END AS RID,
        CASE ST WHEN 'CA' THEN CASE WHEN CR<=40 THEN 'Los Angeles' WHEN CR<=65 THEN 'Riverside' WHEN CR<=80 THEN 'Anaheim' ELSE 'Long Beach' END
                WHEN 'AZ' THEN 'Phoenix' WHEN 'NV' THEN 'Las Vegas' WHEN 'CO' THEN 'Denver'
                ELSE CASE WHEN CR<=55 THEN 'Houston' ELSE 'Dallas' END END AS CITY
    FROM geo
)
SELECT
    'El Pollo Loco #' || LPAD(N+1, 4, '0'),  3,  ST,  RID,
    CASE RID WHEN 1 THEN UNIFORM(1,5,RANDOM()) WHEN 2 THEN UNIFORM(6,9,RANDOM())
             ELSE UNIFORM(10,14,RANDOM()) END,
    CITY, TRUE,
    DATEADD('day', -UNIFORM(365,3650,RANDOM()), CURRENT_DATE()),
    UNIFORM(50,90,RANDOM()),
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 7 THEN TRUE ELSE FALSE END
FROM full_geo;

-- Krispy Kreme (brand_id=4): 25 restaurants, southeast and sunbelt
INSERT INTO RESTAURANTS (RESTAURANT_NAME, BRAND_ID, STATE_CODE, REGION_ID, DISTRICT_ID, CITY, IS_ACTIVE, OPEN_DATE, SEATING_CAPACITY, HAS_DRIVE_THRU)
WITH base AS (
    SELECT SEQ4() AS N, UNIFORM(1,100,RANDOM()) AS SR, UNIFORM(1,100,RANDOM()) AS CR
    FROM TABLE(GENERATOR(ROWCOUNT => 25))
),
geo AS (
    SELECT N, CR,
        CASE WHEN SR<=20 THEN 'CA' WHEN SR<=36 THEN 'TX' WHEN SR<=50 THEN 'GA'
             WHEN SR<=64 THEN 'NC' WHEN SR<=75 THEN 'FL' WHEN SR<=85 THEN 'TN'
             WHEN SR<=92 THEN 'AZ' ELSE 'CO' END AS ST
    FROM base
),
full_geo AS (
    SELECT N, ST,
        CASE ST WHEN 'CA' THEN 1 WHEN 'CO' THEN 2 WHEN 'AZ' THEN 2
                WHEN 'TX' THEN 3 WHEN 'GA' THEN 4 WHEN 'FL' THEN 4
                WHEN 'NC' THEN 4 WHEN 'TN' THEN 4 ELSE 4 END AS RID,
        CASE ST WHEN 'CA' THEN 'Los Angeles' WHEN 'TX' THEN CASE WHEN CR<=55 THEN 'Dallas' ELSE 'Houston' END
                WHEN 'GA' THEN 'Atlanta' WHEN 'NC' THEN 'Charlotte' WHEN 'FL' THEN 'Orlando'
                WHEN 'TN' THEN 'Nashville' WHEN 'AZ' THEN 'Phoenix' ELSE 'Denver' END AS CITY
    FROM geo
)
SELECT
    'Krispy Kreme #' || LPAD(N+1, 4, '0'),  4,  ST,  RID,
    CASE RID WHEN 1 THEN UNIFORM(1,5,RANDOM()) WHEN 2 THEN UNIFORM(6,9,RANDOM())
             WHEN 3 THEN UNIFORM(10,14,RANDOM()) ELSE UNIFORM(15,18,RANDOM()) END,
    CITY, TRUE,
    DATEADD('day', -UNIFORM(365,3650,RANDOM()), CURRENT_DATE()),
    UNIFORM(20,40,RANDOM()),
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 9 THEN TRUE ELSE FALSE END
FROM full_geo;

-- Blaze Pizza (brand_id=5): 15 restaurants, CA/TX/CO/GA
INSERT INTO RESTAURANTS (RESTAURANT_NAME, BRAND_ID, STATE_CODE, REGION_ID, DISTRICT_ID, CITY, IS_ACTIVE, OPEN_DATE, SEATING_CAPACITY, HAS_DRIVE_THRU)
WITH base AS (
    SELECT SEQ4() AS N, UNIFORM(1,100,RANDOM()) AS SR, UNIFORM(1,100,RANDOM()) AS CR
    FROM TABLE(GENERATOR(ROWCOUNT => 15))
),
geo AS (
    SELECT N, CR,
        CASE WHEN SR<=40 THEN 'CA' WHEN SR<=60 THEN 'TX' WHEN SR<=73 THEN 'CO'
             WHEN SR<=85 THEN 'GA' ELSE 'AZ' END AS ST
    FROM base
),
full_geo AS (
    SELECT N, ST,
        CASE ST WHEN 'CA' THEN 1 WHEN 'CO' THEN 2 WHEN 'AZ' THEN 2
                WHEN 'TX' THEN 3 ELSE 4 END AS RID,
        CASE ST WHEN 'CA' THEN CASE WHEN CR<=55 THEN 'Los Angeles' ELSE 'San Diego' END
                WHEN 'TX' THEN CASE WHEN CR<=55 THEN 'Houston' ELSE 'Dallas' END
                WHEN 'CO' THEN 'Denver' WHEN 'GA' THEN 'Atlanta' ELSE 'Phoenix' END AS CITY
    FROM geo
)
SELECT
    'Blaze Pizza #' || LPAD(N+1, 4, '0'),  5,  ST,  RID,
    CASE RID WHEN 1 THEN UNIFORM(1,5,RANDOM()) WHEN 2 THEN UNIFORM(6,9,RANDOM())
             WHEN 3 THEN UNIFORM(10,14,RANDOM()) ELSE UNIFORM(15,18,RANDOM()) END,
    CITY, TRUE,
    DATEADD('day', -UNIFORM(365,2190,RANDOM()), CURRENT_DATE()),
    UNIFORM(60,100,RANDOM()),
    FALSE
FROM full_geo;

-- ---------------------------------------------------------------------------
-- TRANSACTIONS (1,500,000 rows — 2 years of completed-week POS history)
--
-- DEMO STORY baked into the data:
--   Wendy's (1–140):      checks grow +20% over 2 years → visible rising trend
--   El Pollo Loco (246–310): checks grow +15% → growing brand with a people problem
--   Denny's (141–245):    checks drift -10% → mature brand, slight decline
--   KK and Blaze:         flat
--
-- Hour distribution covers all 100 rolls: 6am=1%, 12pm=12%, 6–7pm=18% peak,
-- 11pm=2%. Previous version mapped rolls 40–100 to hour 23 (11pm).
-- ---------------------------------------------------------------------------
INSERT INTO TRANSACTIONS (
    RESTAURANT_ID, TRANSACTION_DATE, TRANSACTION_HOUR,
    DAY_OF_WEEK, CHECK_AMOUNT, ITEM_COUNT, PAYMENT_TYPE, ORDER_CHANNEL
)
WITH base AS (
    SELECT
        UNIFORM(1, 350, RANDOM())   AS RID,
        DATEADD('day',
            -UNIFORM(1, 730, RANDOM()),
            DATEADD('day', -1, DATE_TRUNC('week', CURRENT_DATE())::DATE)
        )                           AS TXN_DATE,
        UNIFORM(1, 100, RANDOM())   AS HOUR_ROLL,
        UNIFORM(1, 100, RANDOM())   AS CHAN_ROLL,
        UNIFORM(1, 10,  RANDOM())   AS PAY_ROLL
    FROM TABLE(GENERATOR(ROWCOUNT => 1500000))
),
enriched AS (
    SELECT *,
        -- days since oldest data point; 730=oldest record, 1=most recent
        DATEDIFF('day', TXN_DATE,
            DATEADD('day', -1, DATE_TRUNC('week', CURRENT_DATE())::DATE)
        ) AS DAYS_AGO
    FROM base
)
SELECT
    RID,
    TXN_DATE,
    -- Realistic hourly distribution — all 100 rolls covered (total = 100%)
    -- 6am:1  7am:2  8am:3  9am:2  10am:3  11am:8  12pm:12  1pm:10  2pm:5
    -- 3pm:4  4pm:4  5pm:6  6pm:9  7pm:9   8pm:8   9pm:7    10pm:5  11pm:2
    CASE
        WHEN HOUR_ROLL = 1                 THEN 6
        WHEN HOUR_ROLL BETWEEN  2 AND  3   THEN 7
        WHEN HOUR_ROLL BETWEEN  4 AND  6   THEN 8
        WHEN HOUR_ROLL BETWEEN  7 AND  8   THEN 9
        WHEN HOUR_ROLL BETWEEN  9 AND 11   THEN 10
        WHEN HOUR_ROLL BETWEEN 12 AND 19   THEN 11
        WHEN HOUR_ROLL BETWEEN 20 AND 31   THEN 12   -- lunch peak
        WHEN HOUR_ROLL BETWEEN 32 AND 41   THEN 13
        WHEN HOUR_ROLL BETWEEN 42 AND 46   THEN 14
        WHEN HOUR_ROLL BETWEEN 47 AND 50   THEN 15
        WHEN HOUR_ROLL BETWEEN 51 AND 54   THEN 16
        WHEN HOUR_ROLL BETWEEN 55 AND 60   THEN 17
        WHEN HOUR_ROLL BETWEEN 61 AND 69   THEN 18   -- dinner peak
        WHEN HOUR_ROLL BETWEEN 70 AND 78   THEN 19   -- dinner peak
        WHEN HOUR_ROLL BETWEEN 79 AND 86   THEN 20
        WHEN HOUR_ROLL BETWEEN 87 AND 93   THEN 21
        WHEN HOUR_ROLL BETWEEN 94 AND 98   THEN 22
        ELSE                                    23   -- 2%
    END                                                                         AS TRANSACTION_HOUR,
    DAYNAME(TXN_DATE)                                                           AS DAY_OF_WEEK,
    -- Brand-aware check with time-based trend (factor goes from <1 oldest to 1.0 recent)
    ROUND(
        CASE
            WHEN RID BETWEEN   1 AND 140 THEN  -- Wendy's: +20% growth
                UNIFORM(8.0,  18.0, RANDOM()) * (0.80 + 0.20 * (1.0 - DAYS_AGO / 730.0))
            WHEN RID BETWEEN 141 AND 245 THEN  -- Denny's: -10% decline
                UNIFORM(14.0, 32.0, RANDOM()) * (1.05 - 0.10 * (1.0 - DAYS_AGO / 730.0))
            WHEN RID BETWEEN 246 AND 310 THEN  -- El Pollo Loco: +15% growth
                UNIFORM(10.0, 20.0, RANDOM()) * (0.85 + 0.15 * (1.0 - DAYS_AGO / 730.0))
            WHEN RID BETWEEN 311 AND 335 THEN  -- Krispy Kreme: flat
                UNIFORM(4.0,  12.0, RANDOM())
            ELSE                               -- Blaze Pizza: flat
                UNIFORM(12.0, 24.0, RANDOM())
        END::DECIMAL(8,2)
    , 2)                                                                        AS CHECK_AMOUNT,
    UNIFORM(1, 6, RANDOM())                                                     AS ITEM_COUNT,
    CASE PAY_ROLL
        WHEN 1 THEN 'CASH'   WHEN 2 THEN 'CASH'
        WHEN 3 THEN 'CREDIT' WHEN 4 THEN 'CREDIT' WHEN 5 THEN 'CREDIT'
        WHEN 6 THEN 'DEBIT'  WHEN 7 THEN 'DEBIT'
        ELSE 'MOBILE'
    END                                                                         AS PAYMENT_TYPE,
    CASE
        WHEN RID BETWEEN 141 AND 245 THEN  -- Denny's: full-service diner, no drive-thru
            CASE WHEN CHAN_ROLL <= 60 THEN 'DINE_IN'
                 WHEN CHAN_ROLL <= 80 THEN 'MOBILE'
                 ELSE 'DELIVERY' END
        ELSE
            CASE WHEN CHAN_ROLL <= 30 THEN 'DINE_IN'
                 WHEN CHAN_ROLL <= 60 THEN 'DRIVE_THRU'
                 WHEN CHAN_ROLL <= 80 THEN 'MOBILE'
                 ELSE 'DELIVERY' END
    END                                                                         AS ORDER_CHANNEL
FROM enriched;
