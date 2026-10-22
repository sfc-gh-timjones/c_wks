-- =============================================================================
-- 07: CORTEX SEARCH SERVICE
-- WKS Restaurant Group SI Demo
--
-- Synthetic HR policies and brand operating standards (no PDFs required).
-- One table, one search service. Agent routes policy questions here instead
-- of generating SQL.
-- =============================================================================

USE DATABASE CUSTOMER_DEMOS;
USE SCHEMA CUSTOMER_DEMOS.WKS;
USE WAREHOUSE WKS_WH;

CREATE OR REPLACE TABLE CUSTOMER_DEMOS.WKS.WKS_HR_DOCS (
    DOC_ID       INT AUTOINCREMENT PRIMARY KEY,
    TITLE        VARCHAR(200)  NOT NULL,
    CATEGORY     VARCHAR(50)   NOT NULL,
    BRAND        VARCHAR(50)   NOT NULL,   -- brand name or 'ALL' for company-wide
    CONTENT      TEXT          NOT NULL,
    LAST_UPDATED DATE
);

INSERT INTO CUSTOMER_DEMOS.WKS.WKS_HR_DOCS (TITLE, CATEGORY, BRAND, CONTENT, LAST_UPDATED) VALUES

-- ── HR Policies (company-wide) ──────────────────────────────────────────────
-- Note: all documents are synthetic sample materials for demonstration.
-- Titles include "(Sample)" to make this clear during the demo.

('[Sample] WKS Attendance and Punctuality Policy', 'HR_POLICY', 'ALL',
'OVERVIEW
WKS Restaurant Group expects all team members to report to work on time, ready to perform their duties. Reliable attendance is essential to our guests, our teams, and our business.

REPORTING TO WORK
Team members must clock in no earlier than 5 minutes before their scheduled shift and no later than their scheduled start time. Arriving more than 7 minutes after the scheduled start time is considered a tardy occurrence.

CALLING OUT
If a team member is unable to report for a scheduled shift, they must notify their direct supervisor at least 2 hours before the shift begins. Notification must be by phone call — text messages alone are not accepted. Failure to provide adequate notice will result in an unexcused absence.

OCCURRENCE SYSTEM
WKS uses a point-based occurrence system:
- Tardy (7–30 min late): 0.5 points
- Tardy (31–60 min late): 1 point
- Unexcused absence: 2 points
- No-call, no-show: 3 points
Points reset after 6 consecutive months of perfect attendance.

THRESHOLDS
- 4 points within 6 months: Written warning
- 6 points within 6 months: Final written warning
- 8 points within 6 months: Separation

DISTRICT LEADER ACCESS
District leaders have access to attendance dashboards for all restaurants within their district via the WKS data platform. Store-level email summaries are distributed weekly.',
'2025-03-01'),

('[Sample] WKS Dress Code and Uniform Standards', 'HR_POLICY', 'ALL',
'PURPOSE
A professional, consistent appearance reinforces our brand identity and builds guest trust. All team members must follow uniform standards appropriate to their brand and role.

UNIFORM REQUIREMENTS
Each brand provides a brand-specific uniform package to team members at hire. Uniforms must be clean, pressed, and in good repair. Wearing items from a different brand uniform is not permitted.

GENERAL STANDARDS
- Non-slip, closed-toe shoes are mandatory in all kitchen and service areas
- Hair must be restrained with a hat or hair net in all food preparation areas
- Visible tattoos must be reviewed by the General Manager — offensive content is not permitted
- Jewelry is limited to a plain band ring and small stud earrings for team members handling food
- Nail polish and artificial nails are prohibited for all back-of-house team members

MANAGEMENT AND CORPORATE
Managers are issued brand-appropriate polo shirts. Corporate support center team members follow a business casual dress code. WKS-branded attire is encouraged at the support center.',
'2025-01-15'),

('[Sample] WKS Code of Conduct', 'HR_POLICY', 'ALL',
'WKS Restaurant Group is committed to maintaining a respectful, ethical, and legally compliant workplace. This Code of Conduct applies to all team members, managers, and contractors.

RESPECT AND INCLUSION
WKS prohibits discrimination or harassment based on race, color, national origin, religion, sex, age, disability, sexual orientation, gender identity, or any other protected status. All team members are entitled to a work environment free from intimidation, hostility, and offensive behavior.

GUEST INTERACTIONS
All guests are to be treated with courtesy and respect. Disputes with guests must be escalated to a manager — team members should never argue with or belittle a guest. Social media complaints about individual guests are strictly prohibited.

CONFIDENTIALITY
Sales data, labor metrics, and financial results are confidential to WKS. Sharing operational data outside of authorized systems or with unauthorized personnel, including posting data in third-party AI tools without IT approval, is a policy violation.

DATA AND AI TOOLS
Team members may use approved AI tools with company data only through platforms authorized by IT. Sharing Snowflake credentials, Domo credentials, or data exports with personal AI accounts (e.g., personal ChatGPT or Claude accounts) constitutes a security violation.

REPORTING CONCERNS
Team members may report concerns anonymously through the WKS Ethics Hotline.',
'2025-06-01'),

('[Sample] WKS PTO and Benefits Guide', 'HR_POLICY', 'ALL',
'PAID TIME OFF (PTO)
Full-time team members accrue PTO based on tenure:
- Year 1: 40 hours / year (accrued at 1.54 hrs/bi-weekly pay period)
- Years 2–4: 80 hours / year
- Year 5+: 120 hours / year

Part-time team members below 30 hours/week are not eligible for PTO accrual.

PTO REQUESTS
PTO must be requested at least 2 weeks in advance through the scheduling system. Requests during peak periods (Memorial Day, 4th of July, Labor Day, Thanksgiving week, Christmas Eve/Day) require 30 days advance notice and are subject to business needs.

BENEFITS ENROLLMENT
Benefits-eligible team members (full-time, minimum 90-day tenure) may enroll in:
- Medical, dental, and vision insurance
- 401(k) with 3% company match after 1 year of service
- Employee assistance program (EAP)
- Discounted meals at all WKS brands

HOLIDAYS
WKS recognizes 7 paid holidays for salaried management and corporate staff. Hourly team members receive a 1.5× pay multiplier when working on Thanksgiving and Christmas Day.',
'2025-04-01'),

('[Sample] WKS Safety and Incident Reporting Procedures', 'HR_POLICY', 'ALL',
'WORKPLACE SAFETY COMMITMENT
WKS is committed to providing a safe working environment for all team members. All injuries, illnesses, and safety hazards must be reported promptly regardless of severity.

INJURY REPORTING
Any work-related injury must be reported to the immediate supervisor and General Manager within 4 hours of the incident. A Workers'' Compensation First Report of Injury form must be completed before the end of the shift. Failure to report injuries in a timely manner may affect claim eligibility.

SLIP, TRIP, AND FALL PREVENTION
All spills must be cleaned immediately and wet-floor signs placed until the area is dry. Non-slip mats must be used in all kitchen areas. Boxes and supplies must not be stored in walking paths.

FOOD SAFETY
Team members must not work while experiencing symptoms of illness (vomiting, diarrhea, jaundice, or sore throat with fever). A signed health screening must be completed at the start of each shift in brands with health screening requirements.

REPORTING A SAFETY HAZARD
Safety hazards can be reported to the General Manager, District Manager, or anonymously through the WKS Safety Hotline. The District Manager must be notified within 24 hours of any OSHA-recordable incident.',
'2025-02-15'),

('[Sample] WKS New Employee Onboarding Guide', 'HR_POLICY', 'ALL',
'WELCOME TO WKS RESTAURANT GROUP
Congratulations on joining the WKS family. WKS Restaurant Group operates Wendy''s, Denny''s, El Pollo Loco, Krispy Kreme, and Blaze Pizza across 19 states. We are in the people business — our team members are our competitive advantage.

FIRST WEEK CHECKLIST
Day 1: Complete I-9 and W-4 forms, receive uniform package, complete food handler certification (if required by state), review safety procedures, take the WKS Values orientation.
Days 2–5: Complete brand-specific training modules in the Learning Management System (LMS). Shadow a tenured team member for each station in your role.

SYSTEM ACCESS
Team members receive access to the following systems based on role:
- Scheduling portal (all team members)
- LMS training portal (all team members)
- Payroll portal (all team members)
Data and reporting platforms (Domo, Snowflake Intelligence) are provisioned for management and above upon request from the District Manager.

YOUR DISTRICT LEADER
Your District Manager is your escalation point for operational questions, safety concerns, and career development. District leaders conduct monthly restaurant visits and are accessible by phone for urgent matters.',
'2025-01-01'),

-- ── Brand Operating Standards ────────────────────────────────────────────────

('[Sample] Wendy''s Quality and Service Standards', 'BRAND_STANDARDS', 'Wendy''s',
'QUALITY IS OUR RECIPE
At Wendy''s, Dave Thomas'' founding principle was simple: fresh, never-frozen beef and ingredients you can see. WKS upholds this commitment at every location.

FRESH BEEF STANDARD
Wendy''s beef patties must never be frozen. Refrigerated fresh beef must be used within 3 days of delivery. Every patty is prepared fresh on the grill per order — pre-staging patties is a critical food safety violation.

SPEED OF SERVICE TARGETS
- Drive-thru window time: under 3 minutes from order to delivery
- In-restaurant order-to-tray: under 2 minutes
- Mobile order pickup: staged within 5 minutes of order notification

FROSTY MACHINE MAINTENANCE
Frosty machines must be cleaned and sanitized according to the Wendy''s Frosty machine cleaning schedule (daily flush, weekly deep clean). Out-of-compliance machines must be taken offline until cleaned.

WEEKLY SALES METRICS
District leaders review the following at every restaurant visit: weekly sales vs. prior year, average check, drive-thru speed, and customer satisfaction scores. These metrics flow into the WKS data platform from Wendy''s POS and are available in Snowflake Intelligence.',
'2025-05-01'),

('[Sample] Denny''s Guest Experience Guidelines', 'BRAND_STANDARDS', 'Denny''s',
'AMERICA''S DINER — EVERY GUEST, EVERY TIME
Denny''s has been serving guests around the clock for over 60 years. Our team members create experiences that make guests feel welcome, seen, and satisfied.

GREETING AND SEATING
Guests must be acknowledged within 30 seconds of entering. All tables must be bussed and reset within 5 minutes of a guest departure. No guest should wait more than 2 minutes to be seated during non-peak hours.

24/7 OPERATIONS
Denny''s operates 24 hours a day, 7 days a year. Late-night staffing levels must meet the minimum floor staffing schedule provided by District Operations. Unapproved early closures are a critical violation.

MENU KNOWLEDGE
All team members must pass a menu knowledge certification within 30 days of hire. The Denny''s menu changes seasonally — team members receive updated training materials with each menu rotation.

SALES AND LABOR TARGETS
Key metrics reviewed by District Leaders: same-store sales growth, table turn time, check average, and labor cost as a percentage of sales. Denny''s average check typically runs higher than QSR brands due to full-service dining and alcohol offerings at select locations.',
'2025-05-01'),

('[Sample] El Pollo Loco Food Safety Standards', 'BRAND_STANDARDS', 'El Pollo Loco',
'FIRE-GRILLED, FRESHLY MADE
El Pollo Loco''s brand promise is fire-grilled chicken served fresh. Food safety and freshness standards are non-negotiable and are directly linked to guest experience scores.

CHICKEN MARINATION AND COOKING
Chicken must marinate for a minimum of 12 hours. Grill temperatures must be verified with a calibrated thermometer at the start of each shift. Internal chicken temperature must reach 165°F at the thickest point before serving.

FRESHNESS WINDOWS
Prepared items have strict freshness windows that must be logged and enforced:
- Grilled chicken: 30 minutes hold time (discard after)
- Tortillas: same-day baked, not held overnight
- Salsa and guacamole: made fresh daily, discarded at close

ALLERGEN MANAGEMENT
El Pollo Loco locations serve guests with common allergens including wheat (tortillas), soy (marinated chicken), and tree nuts (select menu items). Team members must be trained on cross-contamination prevention. Allergen information is available on the EPL Guest Information Card.

DISTRICT OVERSIGHT
Food safety audit scores are reported to District Managers weekly through the WKS data platform. Locations with two consecutive failing scores trigger a mandatory retraining event.',
'2025-04-15'),

('[Sample] Krispy Kreme Production and Quality Standards', 'BRAND_STANDARDS', 'Krispy Kreme',
'THE HOT LIGHT EXPERIENCE
Krispy Kreme''s signature "Hot Light" signals to guests that fresh glazed doughnuts are coming off the line. The hot light experience is central to our brand and must be protected with disciplined production standards.

PRODUCTION SCHEDULE
Hot Light production runs are scheduled twice daily at most WKS Krispy Kreme locations: morning (6:00–8:00 AM) and afternoon (2:00–4:00 PM). Additional production runs may be approved by the General Manager during peak periods.

DOUGH QUALITY
Dough must be proofed to the correct height before frying. Underproofed dough produces dense doughnuts; overproofed produces ones that collapse. The proofing cabinet temperature must be checked at the start of every production run.

GLAZE STANDARDS
The glaze waterfall must run at the correct viscosity (verified daily with the supplied glaze measurement tool). Glazed doughnuts must be sold within 4 hours of glazing or transferred to discounted day-old display.

SALES METRICS
Krispy Kreme locations track: doughnuts produced per shift, waste percentage, Hot Light sales lift (sales per hour while light is on vs. off), and wholesale/retail mix. These flow into the WKS data platform daily.',
'2025-03-15'),

('[Sample] Blaze Pizza Customization and Service Standards', 'BRAND_STANDARDS', 'Blaze Pizza',
'FAST-FIRE''D SINCE 2012
Blaze Pizza built its brand on the assembly-line model: guests customize every pizza, it goes into a blazing-hot oven for 180 seconds, and they''re on their way. Speed and customization are our two core service pillars.

ASSEMBLY LINE STANDARDS
The assembly line must be fully stocked before opening and restocked proactively — no guest should wait while an ingredient is being refilled. All team members on the line must be able to describe every topping and accommodate common dietary preferences (gluten-sensitive crust, vegan cheese).

OVEN TEMPERATURE AND COOK TIME
The Blaze conveyor oven must maintain 800°F. Every pizza cooks for 180 seconds. DO NOT remove pizzas early. Under-cooked crust is the top guest complaint and is directly tied to oven temperature drift.

CUSTOMIZATION POLICY
Blaze Pizza is a "no limits" customization brand — guests may add as many toppings as they wish for a single price. Team members must honor all reasonable customization requests and never discourage guests from adding ingredients.

BUILD TO ORDER — NO STAGING
Pizzas are never pre-built or pre-staged. All pizzas are built to order from the moment the guest steps up to the line. Pre-staged pizzas that sit before entering the oven are a quality and food safety violation.

SALES AND THROUGHPUT
Key metrics: pizzas per labor hour, average build time (target: under 90 seconds from order to oven entry), topping waste percentage, and dine-in vs. carryout mix.',
'2025-05-01');

-- ---------------------------------------------------------------------------
-- Create Cortex Search Service
-- ---------------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE CUSTOMER_DEMOS.WKS.WKS_HR_SEARCH
    ON CONTENT
    ATTRIBUTES TITLE, CATEGORY, BRAND
    WAREHOUSE = WKS_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT
        DOC_ID,
        TITLE,
        CATEGORY,
        BRAND,
        CONTENT,
        LAST_UPDATED
    FROM CUSTOMER_DEMOS.WKS.WKS_HR_DOCS
);
