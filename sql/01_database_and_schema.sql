-- =============================================================================
-- 01: DATABASE, SCHEMA, AND WAREHOUSE
-- WKS Restaurant Group SI Demo
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS CUSTOMER_DEMOS;
CREATE SCHEMA IF NOT EXISTS CUSTOMER_DEMOS.WKS;

CREATE OR REPLACE WAREHOUSE WKS_WH
    WAREHOUSE_SIZE    = 'XSMALL'
    AUTO_SUSPEND      = 30
    AUTO_RESUME       = TRUE
    COMMENT           = 'WKS Restaurant Group demo warehouse';

-- Enable cross-region Cortex AI inference
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;
