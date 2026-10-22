-- =============================================================================
-- 08: EMAIL STORED PROCEDURE
-- WKS Restaurant Group SI Demo
--
-- Creates a notification integration and a Python stored proc that wraps
-- SYSTEM$SEND_EMAIL with HTML mime type. Wired into the agent as the
-- SendEmail tool — used by the agent to distribute sales summaries and
-- HR reports to store leaders and district managers.
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

-- Notification integration (email)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS WKS_EMAIL_INTEGRATION
    TYPE    = EMAIL
    ENABLED = TRUE;

-- Stored procedure: send an HTML email
CREATE OR REPLACE PROCEDURE CUSTOMER_DEMOS.WKS.WKS_SEND_EMAIL(
    TO_EMAIL   VARCHAR,
    SUBJECT    VARCHAR,
    BODY_HTML  VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
AS $$
def send_email(session, to_email: str, subject: str, body_html: str) -> str:
    import snowflake.snowpark.functions as F

    result = session.sql(f"""
        CALL SYSTEM$SEND_EMAIL(
            'WKS_EMAIL_INTEGRATION',
            '{to_email.replace("'", "''")}',
            '{subject.replace("'", "''")}',
            '{body_html.replace("'", "''")}',
            'text/html'
        )
    """).collect()

    return f"Email sent to {to_email}: {subject}"
$$;
