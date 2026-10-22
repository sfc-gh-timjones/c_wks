-- =============================================================================
-- 09: CORTEX AGENT
-- WKS Restaurant Group SI Demo
--
-- Creates WKS_AGENT and registers it with Snowflake Intelligence so it
-- appears in the CoWork UI.
--
-- Tools:
--   Analyst    — Cortex Analyst text-to-SQL over WKS_SEMANTIC_VIEW
--   HRSearch   — Cortex Search over HR policies and brand standards
--   data_to_chart — Renders query results as charts
--   SendEmail  — Calls WKS_SEND_EMAIL stored procedure
--
-- CRITICAL SYNTAX NOTES:
--   - Use FROM SPECIFICATION (not AGENT_SPECIFICATION) for SI UI visibility
--   - Model name uses dashes: claude-sonnet-4-6
--   - Every tool_spec requires a description: field
--   - execution_environment is required under Analyst tool_resources
--   - After CREATE: ALTER SNOWFLAKE INTELLIGENCE ... ADD AGENT ...
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

CREATE OR REPLACE AGENT CUSTOMER_DEMOS.WKS.WKS_AGENT
FROM SPECIFICATION $$
models:
  orchestration: claude-sonnet-4-6

orchestration:
  budget:
    seconds: 360
    tokens: 32000

instructions:
  system: >
    You are the WKS Restaurant Group data assistant. WKS is a family-owned restaurant
    group that operates five iconic brands — Wendy's, Denny's, El Pollo Loco,
    Krispy Kreme, and Blaze Pizza — across approximately 350 locations in 19 US states.
    Help users analyze weekly sales performance, brand and regional comparisons,
    HR headcount, and employee turnover metrics. Be concise and business-focused.
    Always surface the brand name and time period when answering sales questions.
    IMPORTANT: HR policy and brand standards documents are synthetic sample materials
    for this demonstration. When answering policy questions, frame responses as
    "the sample policy shows..." rather than stating them as authoritative WKS documents.

  orchestration: >
    For any quantitative question about sales, revenue, transactions, average check,
    headcount, turnover rates, or workforce metrics: use the Analyst tool.
    For questions about policies, procedures, brand operating standards, attendance,
    dress code, benefits, food safety, or HR guidelines: use HRSearch.
    For any request to send a report, summary, or alert by email: use SendEmail.
    For any request for a chart, graph, or visualization: use data_to_chart after
    getting data from Analyst. Default to horizontal bar charts for category
    comparisons (brands, regions, states).

  response: >
    When generating a bar chart, default to horizontal orientation unless the x-axis
    represents time or dates, or there are 3 or fewer categories. Horizontal bars make
    brand and region labels much easier to read.

  sample_questions:
    - "What are the top 10 restaurants by weekly sales?"
    - "How are weekly sales trending by brand over the last 13 weeks?"
    - "Which brand has the highest turnover rate this year?"
    - "Show me current headcount by brand as a horizontal bar chart"
    - "What is our week-over-week sales change by region?"
    - "What does the WKS attendance policy say about calling out?"
    - "What is the average check size by brand?"
    - "Show me monthly turnover trends for Wendy's over the last 6 months"
    - "Which states have the highest quarterly sales?"
    - "Email me a weekly sales summary to t.jones@snowflake.com"

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Analyst
      description: >
        Text-to-SQL analytics over WKS weekly restaurant sales, brand performance,
        regional trends, and HR workforce metrics including headcount and turnover.

  - tool_spec:
      type: cortex_search
      name: HRSearch
      description: >
        Search WKS HR policies, brand operating standards, attendance guidelines,
        dress code, PTO benefits, food safety standards, and onboarding materials.

  - tool_spec:
      type: data_to_chart
      name: data_to_chart
      description: >
        Render Analyst query results as a chart or visualization.
        Use after Analyst returns data when the user asks for a chart or graph.

  - tool_spec:
      type: generic
      name: SendEmail
      description: >
        Send an HTML-formatted email report to a recipient email address.
        Use for distributing weekly sales summaries, HR reports, or any
        data summary a user wants emailed. Always format the body as clean HTML.

tool_resources:
  Analyst:
    semantic_view: "CUSTOMER_DEMOS.WKS.WKS_SEMANTIC_VIEW"
    execution_environment:
      type: warehouse
      warehouse: WKS_WH

  HRSearch:
    name: "CUSTOMER_DEMOS.WKS.WKS_HR_SEARCH"
    max_results: "10"
    title_column: "TITLE"
    id_column: "DOC_ID"

  SendEmail:
    type: procedure
    identifier: "CUSTOMER_DEMOS.WKS.WKS_SEND_EMAIL"
    execution_environment:
      type: warehouse
      warehouse: WKS_WH
$$
PROFILE = '{"display_name": "WKS Assistant", "color": "blue"}';

-- Register with Snowflake Intelligence (makes it appear in CoWork UI)
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT CUSTOMER_DEMOS.WKS.WKS_AGENT;
