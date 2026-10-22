"use client";

import { useEffect, useState } from "react";
import {
  LineChart, Line, BarChart, Bar, Cell, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer
} from "recharts";

const BRAND_COLORS: Record<string, string> = {
  "Wendy's":       "#E2231A",
  "Denny's":       "#FF9900",
  "El Pollo Loco": "#E85C14",
  "Krispy Kreme":  "#00A0B0",
  "Blaze Pizza":   "#EF3F23",
};

const BRANDS = Object.keys(BRAND_COLORS);

interface WeeklySalesRow {
  BRAND_NAME: string;
  WEEK_START_DATE: string;
  BRAND_WEEKLY_SALES: number;
  BRAND_TRANSACTIONS: number;
  BRAND_AVG_CHECK: number;
  BRAND_WOW_PCT: number;
  BRAND_YOY_PCT: number;
  ACTIVE_RESTAURANTS: number;
}

interface TopRestaurantRow {
  RESTAURANT_NAME: string;
  BRAND_NAME: string;
  STATE_CODE: string;
  REGION_NAME: string;
  WEEKLY_SALES: number;
  WEEKLY_TRANSACTIONS: number;
}

function fmtDollar(n: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency", currency: "USD", maximumFractionDigits: 0,
  }).format(n);
}

function fmtPct(n: number | null) {
  if (n == null || isNaN(n)) return "~";
  return (n >= 0 ? "+" : "") + n.toFixed(1) + "%";
}

function pivotByWeek(rows: WeeklySalesRow[]) {
  const map: Record<string, Record<string, number | string>> = {};
  for (const r of rows) {
    if (!map[r.WEEK_START_DATE]) map[r.WEEK_START_DATE] = { week: r.WEEK_START_DATE };
    map[r.WEEK_START_DATE][r.BRAND_NAME] = r.BRAND_WEEKLY_SALES;
  }
  return Object.values(map).sort((a, b) =>
    String(a.week).localeCompare(String(b.week))
  );
}

export default function SalesDashboard() {
  const [weekly, setWeekly]   = useState<WeeklySalesRow[]>([]);
  const [topRest, setTopRest] = useState<TopRestaurantRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch("/api/weekly-sales").then((r) => r.json()),
      fetch("/api/top-restaurants").then((r) => r.json()),
    ]).then(([w, t]) => {
      setWeekly(Array.isArray(w) ? w : []);
      setTopRest(Array.isArray(t) ? t : []);
      setLoading(false);
    });
  }, []);

  const weeks      = Array.from(new Set(weekly.map((r) => r.WEEK_START_DATE))).sort();
  const latestWeek = weeks.slice(-1)[0];
  const last4weeks = weeks.slice(-4);
  const last4Rows  = weekly.filter((r) => last4weeks.includes(r.WEEK_START_DATE));
  const latestRows = weekly.filter((r) => r.WEEK_START_DATE === latestWeek);

  const totalSales = last4Rows.reduce((s, r) => s + r.BRAND_WEEKLY_SALES, 0);
  const avgCheck   = last4Rows.length
    ? last4Rows.reduce((s, r) => s + r.BRAND_AVG_CHECK, 0) / last4Rows.length : null;
  // Use brand-level WoW/YoY from DT_BRAND_WEEKLY_SUMMARY (revenue-weighted)
  const avgWow = latestRows.length
    ? latestRows.reduce((s, r) => s + (r.BRAND_WOW_PCT ?? 0), 0) / latestRows.length : null;
  const avgYoy = latestRows.length
    ? latestRows.reduce((s, r) => s + (r.BRAND_YOY_PCT ?? 0), 0) / latestRows.length : null;

  const pivoted = pivotByWeek(weekly);

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-slate-400">
      Loading sales data...
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: "Total Revenue (4 wks)", value: fmtDollar(totalSales), sub: "all brands", pos: null as number | null },
          { label: "Avg WoW Change",        value: fmtPct(avgWow),         sub: "latest week",  pos: avgWow },
          { label: "Avg YoY Change",        value: fmtPct(avgYoy),         sub: "vs prior year",pos: avgYoy },
          { label: "Avg Check Size",        value: avgCheck != null ? "$" + avgCheck.toFixed(2) : "~", sub: "all brands", pos: null },
        ].map((card) => (
          <div key={card.label} className="bg-white rounded-lg border border-slate-200 p-4 shadow-sm">
            <p className="text-xs text-slate-500 mb-1">{card.label}</p>
            <p className={`text-2xl font-semibold ${
              card.pos == null ? "text-slate-800"
              : card.pos >= 0 ? "text-green-600" : "text-red-600"
            }`}>{card.value}</p>
            <p className="text-xs text-slate-400 mt-0.5">{card.sub}</p>
          </div>
        ))}
      </div>

      <div className="bg-white rounded-lg border border-slate-200 p-5 shadow-sm">
        <h3 className="text-sm font-semibold text-slate-700 mb-4">
          Weekly Sales by Brand — Last 13 Completed Weeks
        </h3>
        <ResponsiveContainer width="100%" height={240}>
          <LineChart data={pivoted} margin={{ right: 16, left: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="week" tick={{ fontSize: 11 }}
              tickFormatter={(v) => String(v).slice(5, 10)} />
            <YAxis tick={{ fontSize: 11 }}
              tickFormatter={(v) => "$" + (v / 1000).toFixed(0) + "k"} />
            <Tooltip formatter={(v: number) => fmtDollar(v)}
              labelFormatter={(l) => "Week of " + l} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            {BRANDS.map((brand) => (
              <Line key={brand} type="monotone" dataKey={brand}
                stroke={BRAND_COLORS[brand]} strokeWidth={2} dot={false} connectNulls />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-lg border border-slate-200 p-5 shadow-sm">
        <h3 className="text-sm font-semibold text-slate-700 mb-4">
          Top 10 Restaurants — Last Completed Week
        </h3>
        <ResponsiveContainer width="100%" height={280}>
          <BarChart data={topRest} layout="vertical"
            margin={{ left: 140, right: 64, top: 4, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" horizontal={false} />
            <XAxis type="number" tick={{ fontSize: 11 }}
              tickFormatter={(v) => "$" + (v / 1000).toFixed(0) + "k"} />
            <YAxis type="category" dataKey="RESTAURANT_NAME"
              tick={{ fontSize: 11 }} width={135} />
            <Tooltip formatter={(v: number) => fmtDollar(v)} />
            <Bar dataKey="WEEKLY_SALES" radius={[0, 3, 3, 0]}
              label={{ position: "right", fontSize: 10,
                formatter: (v: number) => "$" + (v / 1000).toFixed(1) + "k" }}>
              {topRest.map((entry) => (
                <Cell key={entry.RESTAURANT_NAME}
                  fill={BRAND_COLORS[entry.BRAND_NAME] ?? "#2563eb"} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
