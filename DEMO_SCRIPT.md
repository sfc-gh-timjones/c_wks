# WKS Demo Script — Five Talk Tracks

Concise talking points for the four people in the room: Grace (data, buyer), AI Labs partner, SVP of IT, and the software engineer who owns the databases.

---

## Before You Start

- Open Snowsight with `CUSTOMER_DEMOS.WKS` selected
- Open the Snowflake Intelligence UI and confirm **WKS Assistant** is listed
- Have the React dashboard URL ready
- Have the Snowsight DT graph open on `DT_CURRENT_SNAPSHOT`

---

## Talk Track 1 — The Pipeline Is in GitHub

**Audience:** software engineer, SVP of IT  
**When to use:** when showing the DT graph or the SQL

> "Every SQL transformation is a file committed to GitHub. Your software engineer can fork the repo, change a formula, open a pull request, and when that pull request merges, a redeploy of the script updates the dynamic table. It is not automatic pickup — you run the deploy. But the code is in a repo everyone can read, review, and diff. No Magic ETL GUI, no black box."

**Show:** Click into `DT_WEEKLY_RESTAURANT_SALES` → View Definition. Point to the self-join for WoW%. Say: "That's readable SQL. A new data engineer six months from now can understand every step by reading the repo."

---

## Talk Track 2 — Cost Is Visible and Controllable

**Audience:** SVP of IT, Grace  
**When to use:** after showing the warehouse or before the demo ends

> "The SQL pipeline runs on one XSmall warehouse that auto-suspends in 30 seconds. Credits run while queries execute — idle time costs nothing. The React dashboard needs a small SPCS compute pool that you suspend between demos; that bills by the node-hour while it's running. Snowflake has a native budget feature where you set a credit threshold and it sends you an email alert — separate from the agent's email tool, but the same idea: you get notified before you're surprised at month end."

**What not to say:** "credits run on the query, not the clock" — that's accurate for the warehouse but not for the SPCS compute pool, which bills by node-hour regardless of query activity. Keep them separate in the explanation.

---

## Talk Track 3 — District Leaders See Only Their Stores

**Audience:** Grace, SVP of IT  
**When to use:** when they ask about row-level security or access control

> "One row access policy, one table. Attach it to the table that Snowflake Intelligence reads, and a district leader's question automatically filters to their stores — the semantic view, the verified queries, and the agent all respect it. You write the policy once."

**Be precise:** the policy is on `DT_WEEKLY_RESTAURANT_SALES`. That covers every Snowflake Intelligence question that goes through the semantic view. It does not apply to the React dashboard (which reads `DT_BRAND_WEEKLY_SUMMARY`, a brand-level rollup with no district column) or to the service role running the app. Say: "the policy applies to Intelligence queries on the restaurant detail table." Leave the dashboard out of that sentence.

**Show:** `sql/10_row_access_policy.sql` — the policy DDL is 15 lines. The attach to `DT_WEEKLY_RESTAURANT_SALES` is one ALTER TABLE statement.

---

## Talk Track 4 — Wendy's and Denny's Are Already Here

**Audience:** Grace  
**When to use:** when she asks about data sharing or the two brands on Snowflake

> "Two of your brands are already on Snowflake. If they ever say yes to a share, you add one line to script 01 — a `CREATE DATABASE FROM SHARE` — and that brand's POS data drops directly into the bronze layer of this exact pipeline as a live table. No SFTP. No ETL. No email connector. Your pipeline doesn't change; the data source does."

**Do not build this today.** One sentence is enough. She already knows the value; she just needs to know the mechanism is ready when the brands cooperate.

---

## Talk Track 5 — Domo Stays (at Least for Year One)

**Audience:** Grace, SVP of IT  
**When to use:** if anyone raises the 200-dashboard question

> "We are not proposing you rebuild 200 dashboards. This is your warehouse layer. Domo on Cloud Amplifier connects directly to these same Snowflake tables — same data, same freshness, same permissions. You get the year you asked for to make that decision. The difference is that your AI questions now run next to the data, on the same semantic view your dashboard uses, with the same governance your row access policy defines. That's what Grace's team couldn't get inside Claude today."

**The incident reference:** earlier in the call Grace described users pasting Domo credentials into Claude artifacts and permissions breaking. You can name it directly: "What happened this morning — that can't happen here. Snowflake Intelligence runs as the user's session, inside the account, with all the same access controls applied. Nothing leaves the platform."

---

## Suggested Demo Flow (60 minutes)

| Time | What | Talking point |
|------|------|---------------|
| 0–5 min | Intro + agenda | Set up the three personas: Grace as data lead, software engineer as pipeline owner, SVP as platform decision maker |
| 5–12 min | Show the DT graph in Snowsight | Talk Track 1 (GitHub + pipeline) |
| 12–18 min | Ask 2 VQR questions in Snowflake Intelligence | The "aha" — same pattern as Claude + Domo, but in the platform |
| 18–24 min | Cross-domain question (sales + HR) | "Which brand is growing revenue and losing people?" — this is the Domo-across-datasets pain |
| 24–28 min | Search question (policy) | "What does the attendance policy say?" — shows multi-modal agent |
| 28–32 min | Send email from agent | "Email me that summary" — familiar workflow, native to the platform |
| 32–38 min | React dashboard | Show the visual layer; frame it as *one option* next to Domo on Amplifier. The embedded chat panel handles text questions and shows "open Snowflake Intelligence for interactive charts" for chart requests — be upfront about that. Full chart rendering in the chat is in Snowflake Intelligence, not the React app. |
| 38–42 min | Row access policy | Talk Track 3 (district security) |
| 42–46 min | Cost and budgets | Talk Track 2 |
| 46–50 min | Data sharing one-liner | Talk Track 4 (Wendy's / Denny's) |
| 50–55 min | Domo positioning | Talk Track 5 |
| 55–60 min | Q&A, next steps | Leave 5 minutes for the SVP and software engineer to ask |
