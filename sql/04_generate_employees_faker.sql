-- =============================================================================
-- 04: GENERATE EMPLOYEES (Faker + numpy) + EMPLOYEE_EVENTS
-- WKS Restaurant Group SI Demo
--
-- FIXES applied vs v1:
--   1. Two-phase employee generation:
--        Phase 1: active employees (IS_ACTIVE=TRUE, TERM_DATE=NULL)
--                 Builds a current workforce of ~8-11 per restaurant.
--        Phase 2: 2,000 terminated employees (IS_ACTIVE=FALSE)
--                 2 years of historical turnover (~83 separations/month =
--                 ~33% annualized rate, realistic for a managed QSR group).
--      Phase 1 never randomly terminates anyone.
--      Phase 2 always sets a valid TERM_DATE in the past.
--   2. Snowpark write uses column_order='name' to avoid positional mismatch
--      with the EMPLOYEE_ID autoincrement column.
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

CREATE OR REPLACE PROCEDURE CUSTOMER_DEMOS.WKS.GENERATE_EMPLOYEES()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python', 'faker', 'numpy', 'pandas')
HANDLER = 'generate_employees'
AS
$$
import numpy as np
import pandas as pd
from faker import Faker
from datetime import date, timedelta
import random

def generate_employees(session):
    fake = Faker(['en_US'])
    fake.seed_instance(42)
    np.random.seed(42)
    random.seed(42)

    brands_df      = session.sql("SELECT BRAND_ID FROM CUSTOMER_DEMOS.WKS.BRANDS").to_pandas()
    depts_df       = session.sql("SELECT DEPARTMENT_ID, DEPARTMENT_TYPE FROM CUSTOMER_DEMOS.WKS.DEPARTMENTS").to_pandas()
    positions_df   = session.sql("SELECT POSITION_ID, DEPARTMENT_ID, POSITION_LEVEL, HOURLY_RATE_MIN, HOURLY_RATE_MAX FROM CUSTOMER_DEMOS.WKS.JOB_POSITIONS").to_pandas()
    restaurants_df = session.sql("SELECT RESTAURANT_ID, BRAND_ID FROM CUSTOMER_DEMOS.WKS.RESTAURANTS").to_pandas()

    brand_ids     = brands_df['BRAND_ID'].tolist()
    corp_dept_ids = depts_df[depts_df['DEPARTMENT_TYPE'] == 'CORPORATE']['DEPARTMENT_ID'].tolist()
    rest_dept_ids = depts_df[depts_df['DEPARTMENT_TYPE'] != 'CORPORATE']['DEPARTMENT_ID'].tolist()
    corp_pos      = positions_df[positions_df['DEPARTMENT_ID'].isin(corp_dept_ids)].reset_index(drop=True)
    rest_pos      = positions_df[positions_df['DEPARTMENT_ID'].isin(rest_dept_ids)].reset_index(drop=True)

    level_map   = {'CREW': 8, 'SHIFT_LEAD': 3, 'MANAGER': 2, 'DIRECTOR': 1, 'CORPORATE': 1}
    weights     = rest_pos['POSITION_LEVEL'].map(level_map).fillna(1).values.astype(float)
    probs       = weights / weights.sum()

    today = date.today()
    rows  = []

    def pick_pos(df, p):
        return df.iloc[np.random.choice(len(df), p=p)]

    def make_row(rest_id, brand_id, pos, hire_ago, is_active, term_date):
        rate      = round(random.uniform(float(pos['HOURLY_RATE_MIN']), float(pos['HOURLY_RATE_MAX'])), 2)
        hire_date = today - timedelta(days=int(hire_ago))
        emp_type  = 'PART_TIME' if (pos['POSITION_LEVEL'] == 'CREW' and random.random() < 0.4) else 'FULL_TIME'
        return {
            'RESTAURANT_ID':  None if rest_id is None else int(rest_id),
            'BRAND_ID':       int(brand_id),
            'DEPARTMENT_ID':  int(pos['DEPARTMENT_ID']),
            'POSITION_ID':    int(pos['POSITION_ID']),
            'FIRST_NAME':     fake.first_name(),
            'LAST_NAME':      fake.last_name(),
            'EMAIL':          f"{fake.user_name()}{random.randint(1,9999)}@wksusa.com",
            'HIRE_DATE':      hire_date.isoformat(),
            'TERM_DATE':      term_date.isoformat() if term_date else None,
            'EMPLOYMENT_TYPE': emp_type,
            'HOURLY_RATE':    rate,
            'IS_ACTIVE':      bool(is_active),
        }

    # Phase 1a: 150 corporate active employees
    for _ in range(150):
        p        = corp_pos.iloc[random.randrange(len(corp_pos))]
        hire_ago = max(30, min(int(np.random.exponential(600)), 3650))
        rows.append(make_row(None, random.choice(brand_ids), p, hire_ago, True, None))

    # Phase 1b: active restaurant employees (~8-11 per restaurant)
    for _, rest_row in restaurants_df.iterrows():
        n        = random.randint(8, 11)
        brand_id = int(rest_row['BRAND_ID'])
        rest_id  = int(rest_row['RESTAURANT_ID'])
        for _ in range(n):
            p        = pick_pos(rest_pos, probs)
            hire_ago = max(14, min(int(np.random.exponential(500)), 2555))
            rows.append(make_row(rest_id, brand_id, p, hire_ago, True, None))

    # Phase 2: terminated employees
    # EPL (brand_id=3) gets 3× more per restaurant to tell the high-turnover story.
    # Target: EPL ~45% annualized, all others ~15–20%.
    # Distribution: EPL (65 rests × 8-10) ≈ 585 | Others (285 rests × 2-4) ≈ 855
    for _, rest_row in restaurants_df.iterrows():
        brand_id = int(rest_row['BRAND_ID'])
        rest_id  = int(rest_row['RESTAURANT_ID'])
        p        = pick_pos(rest_pos, probs)
        # EPL gets significantly more historical terminations per location
        n_term   = random.randint(8, 10) if brand_id == 3 else random.randint(2, 4)
        for _ in range(n_term):
            hire_ago = random.randint(90, 730)
            tenure   = random.randint(30, max(30, hire_ago - 7))
            term_dt  = today - timedelta(days=hire_ago) + timedelta(days=tenure)
            rows.append(make_row(rest_id, brand_id, p, hire_ago, False, term_dt))

    df = pd.DataFrame(rows)
    # column_order='name' prevents EMPLOYEE_ID autoincrement position mismatch
    session.create_dataframe(df).write.mode('append').save_as_table(
        'CUSTOMER_DEMOS.WKS.EMPLOYEES',
        column_order='name'
    )

    active = sum(1 for r in rows if r['IS_ACTIVE'])
    return f"Inserted {len(rows)} employees ({active} active, {len(rows)-active} terminated)."
$$;

CALL CUSTOMER_DEMOS.WKS.GENERATE_EMPLOYEES();
DROP PROCEDURE IF EXISTS CUSTOMER_DEMOS.WKS.GENERATE_EMPLOYEES();

-- ---------------------------------------------------------------------------
-- EMPLOYEE_EVENTS (terminations sync with EMPLOYEES.TERM_DATE)
-- ---------------------------------------------------------------------------

INSERT INTO EMPLOYEE_EVENTS (EMPLOYEE_ID, BRAND_ID, RESTAURANT_ID, EVENT_TYPE, EVENT_DATE, OLD_POSITION_ID, NEW_POSITION_ID, IS_VOLUNTARY)
SELECT
    EMPLOYEE_ID, BRAND_ID, RESTAURANT_ID, 'TERMINATION', TERM_DATE, POSITION_ID, NULL,
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 7 THEN TRUE ELSE FALSE END
FROM CUSTOMER_DEMOS.WKS.EMPLOYEES
WHERE TERM_DATE IS NOT NULL;

INSERT INTO EMPLOYEE_EVENTS (EMPLOYEE_ID, BRAND_ID, RESTAURANT_ID, EVENT_TYPE, EVENT_DATE, OLD_POSITION_ID, NEW_POSITION_ID, IS_VOLUNTARY)
SELECT
    e.EMPLOYEE_ID, e.BRAND_ID, e.RESTAURANT_ID, 'PROMOTION',
    DATEADD('day', UNIFORM(90, DATEDIFF('day', e.HIRE_DATE, CURRENT_DATE()), RANDOM()), e.HIRE_DATE),
    e.POSITION_ID, LEAST(e.POSITION_ID + 1, 24), TRUE
FROM CUSTOMER_DEMOS.WKS.EMPLOYEES e
WHERE e.IS_ACTIVE = TRUE
  AND e.RESTAURANT_ID IS NOT NULL
  AND DATEDIFF('day', e.HIRE_DATE, CURRENT_DATE()) > 365
  AND UNIFORM(1,100,RANDOM()) <= 25;

INSERT INTO EMPLOYEE_EVENTS (EMPLOYEE_ID, BRAND_ID, RESTAURANT_ID, EVENT_TYPE, EVENT_DATE, OLD_POSITION_ID, NEW_POSITION_ID, IS_VOLUNTARY)
SELECT
    e.EMPLOYEE_ID, e.BRAND_ID, e.RESTAURANT_ID, 'TRANSFER',
    DATEADD('day', UNIFORM(60, DATEDIFF('day', e.HIRE_DATE, CURRENT_DATE()), RANDOM()), e.HIRE_DATE),
    e.POSITION_ID, e.POSITION_ID, TRUE
FROM CUSTOMER_DEMOS.WKS.EMPLOYEES e
WHERE e.IS_ACTIVE = TRUE
  AND e.RESTAURANT_ID IS NOT NULL
  AND DATEDIFF('day', e.HIRE_DATE, CURRENT_DATE()) > 180
  AND UNIFORM(1,100,RANDOM()) <= 10
LIMIT 400;
