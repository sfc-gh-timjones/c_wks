import { NextResponse } from "next/server";
import { sfQuery } from "@/lib/snowflake";

// Top 10 restaurants by sales — use the last COMPLETED week (not current
// partial week) so rankings are based on a full 7-day period.
export async function GET() {
  const sql = `
    SELECT
      s.RESTAURANT_NAME,
      b.BRAND_NAME,
      s.STATE_CODE,
      s.REGION_NAME,
      SUM(s.WEEKLY_SALES)      AS WEEKLY_SALES,
      SUM(s.TRANSACTION_COUNT) AS WEEKLY_TRANSACTIONS
    FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES s
    JOIN CUSTOMER_DEMOS.WKS.BRANDS b ON s.BRAND_ID = b.BRAND_ID
    WHERE s.WEEK_START_DATE = (
      SELECT MAX(WEEK_START_DATE)
      FROM CUSTOMER_DEMOS.WKS.DT_WEEKLY_RESTAURANT_SALES
      WHERE WEEK_START_DATE < DATE_TRUNC('week', CURRENT_DATE())
    )
    GROUP BY s.RESTAURANT_NAME, b.BRAND_NAME, s.STATE_CODE, s.REGION_NAME
    ORDER BY WEEKLY_SALES DESC
    LIMIT 10
  `;
  try {
    const rows = await sfQuery(sql);
    return NextResponse.json(rows);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
