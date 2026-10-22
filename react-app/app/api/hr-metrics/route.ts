import { NextResponse } from "next/server";
import { sfQuery } from "@/lib/snowflake";

export async function GET() {
  const sql = `
    SELECT
      h.BRAND_NAME,
      h.YEAR_MONTH,
      h.HIRES,
      h.SEPARATIONS,
      h.ENDING_HEADCOUNT,
      h.HEADCOUNT_CHANGE,
      h.ANNUALIZED_TURNOVER_RATE
    FROM CUSTOMER_DEMOS.WKS.DT_HR_BRAND_METRICS h
    WHERE h.YEAR_MONTH >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
      AND h.ENDING_HEADCOUNT > 0
    ORDER BY h.BRAND_NAME, h.YEAR_MONTH
  `;
  try {
    const rows = await sfQuery(sql);
    return NextResponse.json(rows);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
