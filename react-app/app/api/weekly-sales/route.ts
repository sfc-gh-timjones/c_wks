import { NextResponse } from "next/server";
import { sfQuery } from "@/lib/snowflake";

// Query DT_BRAND_WEEKLY_SUMMARY (not restaurant-level) so WoW% and YoY% are
// brand-level figures weighted by revenue, not a simple restaurant average.
// Filter to COMPLETED weeks only — exclude the current partial week so the
// chart does not show a cliff on the rightmost data point.
export async function GET() {
  const sql = `
    SELECT
      BRAND_NAME,
      WEEK_START_DATE,
      BRAND_WEEKLY_SALES,
      BRAND_TRANSACTIONS,
      BRAND_AVG_CHECK,
      BRAND_WOW_PCT,
      BRAND_YOY_PCT,
      ACTIVE_RESTAURANTS
    FROM CUSTOMER_DEMOS.WKS.DT_BRAND_WEEKLY_SUMMARY
    WHERE WEEK_START_DATE <  DATE_TRUNC('week', CURRENT_DATE())
      AND WEEK_START_DATE >= DATEADD('week', -13, DATE_TRUNC('week', CURRENT_DATE()))
    ORDER BY WEEK_START_DATE, BRAND_NAME
  `;
  try {
    const rows = await sfQuery(sql);
    return NextResponse.json(rows);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
