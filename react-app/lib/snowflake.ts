import { readFileSync } from "fs";

const SF_HOST = process.env.SNOWFLAKE_HOST || process.env.SF_HOST || "";
const SF_DATABASE = process.env.SF_DATABASE || "CUSTOMER_DEMOS";
const SF_SCHEMA = process.env.SF_SCHEMA || "WKS";
const SF_WAREHOUSE = process.env.SF_WAREHOUSE || "WKS_WH";

// SPCS injects a session token at this path inside the container.
// For local dev, set SF_TOKEN in your environment:
//   export SF_TOKEN="your-PAT-here"
function getToken(): string {
  if (process.env.SF_TOKEN) return process.env.SF_TOKEN;
  try {
    return readFileSync("/snowflake/session/token", "utf8").trim();
  } catch {
    throw new Error(
      "No Snowflake token found. Set SF_TOKEN for local dev or deploy to SPCS."
    );
  }
}

export interface QueryRow {
  [key: string]: string | number | null;
}

export async function sfQuery(
  sql: string,
  warehouse = SF_WAREHOUSE
): Promise<QueryRow[]> {
  const token = getToken();
  const url = `https://${SF_HOST}/api/v2/statements`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      statement: sql,
      warehouse,
      database: SF_DATABASE,
      schema: SF_SCHEMA,
      timeout: 60,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Snowflake SQL API error ${res.status}: ${err}`);
  }

  const data = await res.json();

  // Handle async / still-running statements
  if (data.status === "running" || data.status === "queued") {
    const statementHandle = data.statementHandle;
    return await pollStatement(statementHandle, token);
  }

  return parseRows(data);
}

async function pollStatement(
  handle: string,
  token: string
): Promise<QueryRow[]> {
  const url = `https://${SF_HOST}/api/v2/statements/${handle}`;
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const data = await res.json();
    if (data.status === "success") return parseRows(data);
    if (data.status === "failed") throw new Error(data.message);
  }
  throw new Error("Statement polling timed out after 60s");
}

function parseRows(data: {
  resultSetMetaData?: { rowType: { name: string }[] };
  data?: (string | null)[][];
}): QueryRow[] {
  const cols = data.resultSetMetaData?.rowType?.map((c) => c.name) ?? [];
  const rows = data.data ?? [];
  return rows.map((row) => {
    const obj: QueryRow = {};
    cols.forEach((col, i) => {
      const val = row[i];
      obj[col] = val === null ? null : isNaN(Number(val)) ? val : Number(val);
    });
    return obj;
  });
}
