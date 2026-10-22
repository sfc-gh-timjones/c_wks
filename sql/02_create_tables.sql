-- =============================================================================
-- 02: CREATE BASE TABLES
-- WKS Restaurant Group SI Demo
-- Load order: reference dims → entity dims → people dims → facts
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

-- ---------------------------------------------------------------------------
-- Reference dimensions (no FK dependencies)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TABLE REGIONS (
    REGION_ID   INT AUTOINCREMENT PRIMARY KEY,
    REGION_NAME VARCHAR(30) NOT NULL
);

CREATE OR REPLACE TABLE STATES (
    STATE_CODE  VARCHAR(2)  PRIMARY KEY,
    STATE_NAME  VARCHAR(50) NOT NULL,
    REGION_ID   INT         NOT NULL
);

CREATE OR REPLACE TABLE BRANDS (
    BRAND_ID    INT AUTOINCREMENT PRIMARY KEY,
    BRAND_NAME  VARCHAR(50) NOT NULL,
    BRAND_CODE  VARCHAR(5)  NOT NULL,
    BRAND_TYPE  VARCHAR(20) NOT NULL,   -- QSR, DINER, BAKERY, CASUAL
    BRAND_COLOR VARCHAR(10) NOT NULL    -- hex color for the React dashboard
);

CREATE OR REPLACE TABLE DEPARTMENTS (
    DEPARTMENT_ID   INT AUTOINCREMENT PRIMARY KEY,
    DEPARTMENT_NAME VARCHAR(50) NOT NULL,
    DEPARTMENT_TYPE VARCHAR(20) NOT NULL   -- FOH, BOH, MGMT, CORPORATE
);

CREATE OR REPLACE TABLE JOB_POSITIONS (
    POSITION_ID       INT AUTOINCREMENT PRIMARY KEY,
    POSITION_TITLE    VARCHAR(60)    NOT NULL,
    POSITION_LEVEL    VARCHAR(20)    NOT NULL,   -- CREW, SHIFT_LEAD, MANAGER, DIRECTOR, CORPORATE
    DEPARTMENT_ID     INT            NOT NULL,
    HOURLY_RATE_MIN   DECIMAL(6,2)   NOT NULL,
    HOURLY_RATE_MAX   DECIMAL(6,2)   NOT NULL
);

-- ---------------------------------------------------------------------------
-- Entity dimensions (FK to reference dims)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TABLE DISTRICTS (
    DISTRICT_ID   INT AUTOINCREMENT PRIMARY KEY,
    DISTRICT_NAME VARCHAR(60) NOT NULL,
    REGION_ID     INT         NOT NULL
);

CREATE OR REPLACE TABLE RESTAURANTS (
    RESTAURANT_ID    INT AUTOINCREMENT PRIMARY KEY,
    RESTAURANT_NAME  VARCHAR(100) NOT NULL,
    BRAND_ID         INT          NOT NULL,
    STATE_CODE       VARCHAR(2)   NOT NULL,
    REGION_ID        INT          NOT NULL,
    DISTRICT_ID      INT          NOT NULL,
    CITY             VARCHAR(60)  NOT NULL,
    IS_ACTIVE        BOOLEAN      DEFAULT TRUE,
    OPEN_DATE        DATE,
    SEATING_CAPACITY INT,
    HAS_DRIVE_THRU   BOOLEAN      DEFAULT FALSE
);

-- ---------------------------------------------------------------------------
-- People (FK to entity dims — populated by Faker proc in script 04)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TABLE EMPLOYEES (
    EMPLOYEE_ID     INT AUTOINCREMENT PRIMARY KEY,
    RESTAURANT_ID   INT,               -- NULL for corporate/support center staff
    BRAND_ID        INT        NOT NULL,
    DEPARTMENT_ID   INT        NOT NULL,
    POSITION_ID     INT        NOT NULL,
    FIRST_NAME      VARCHAR(50),
    LAST_NAME       VARCHAR(50),
    EMAIL           VARCHAR(100),
    HIRE_DATE       DATE       NOT NULL,
    TERM_DATE       DATE,              -- NULL if currently active
    EMPLOYMENT_TYPE VARCHAR(20),       -- FULL_TIME, PART_TIME
    HOURLY_RATE     DECIMAL(6,2),
    IS_ACTIVE       BOOLEAN    DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- Facts
-- ---------------------------------------------------------------------------

CREATE OR REPLACE TABLE TRANSACTIONS (
    TRANSACTION_ID   INT AUTOINCREMENT PRIMARY KEY,
    RESTAURANT_ID    INT           NOT NULL,
    TRANSACTION_DATE DATE          NOT NULL,
    TRANSACTION_HOUR INT           NOT NULL,   -- 0-23
    DAY_OF_WEEK      VARCHAR(10)   NOT NULL,
    CHECK_AMOUNT     DECIMAL(8,2)  NOT NULL,
    ITEM_COUNT       INT           NOT NULL,
    PAYMENT_TYPE     VARCHAR(20)   NOT NULL,   -- CASH, CREDIT, DEBIT, MOBILE
    ORDER_CHANNEL    VARCHAR(20)   NOT NULL    -- DINE_IN, DRIVE_THRU, MOBILE, DELIVERY
);

CREATE OR REPLACE TABLE EMPLOYEE_EVENTS (
    EVENT_ID        INT AUTOINCREMENT PRIMARY KEY,
    EMPLOYEE_ID     INT         NOT NULL,
    BRAND_ID        INT         NOT NULL,
    RESTAURANT_ID   INT,
    EVENT_TYPE      VARCHAR(20) NOT NULL,   -- HIRE, TERMINATION, PROMOTION, TRANSFER
    EVENT_DATE      DATE        NOT NULL,
    OLD_POSITION_ID INT,
    NEW_POSITION_ID INT,
    IS_VOLUNTARY    BOOLEAN                 -- relevant for terminations
);
