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

interface HRRow {
  BRAND_NAME: string;
  YEAR_MONTH: string;
  HIRES: number;
  SEPARATIONS: number;
  ENDING_HEADCOUNT: number;
  HEADCOUNT_CHANGE: number;
  ANNUALIZED_TURNOVER_RATE: number;
}

function pivotByMonth(rows: HRRow[], key: keyof HRRow) {
  const map: Record<string, Record<string, number | string>> = {};
  for (const r of rows) {
    if (!map[r.YEAR_MONTH]) map[r.YEAR_MONTH] = { month: r.YEAR_MONTH };
    map[r.YEAR_MONTH][r.BRAND_NAME] = r[key] as number;
  }
  return Object.values(map).sort((a, b) =>
    String(a.month).localeCompare(String(b.month))
  );
}

export default function HRDashboard() {
  const [hrData, setHrData] = useState<HRRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/hr-metrics")
      .then((r) => r.json())
      .then((d) => {
        setHrData(Array.isArray(d) ? d : []);
        setLoading(false);
      });
  }, []);

  const latestMonth = [...new Set(hrData.map((r) => r.YEAR_MONTH))].sort().slice(-1)[0];
  const latestRows  = hrData.filter((r) => r.YEAR_MONTH === latestMonth);
  const totalHC     = latestRows.reduce((s, r) => s + r.ENDING_HEADCOUNT, 0);
  const totalHires  = latestRows.reduce((s, r) => s + r.HIRES, 0);
  const totalSeps   = latestRows.reduce((s, r) => s + r.SEPARATIONS, 0);
  const avgTurnover = latestRows.length
    ? latestRows.reduce((s, r) => s + r.ANNUALIZED_TURNOVER_RATE, 0) / latestRows.length
    : null;

  const headcountByBrand = latestRows
    .map((r) => ({ BRAND_NAME: r.BRAND_NAME, ENDING_HEADCOUNT: r.ENDING_HEADCOUNT }))
    .sort((a, b) => b.ENDING_HEADCOUNT - a.ENDING_HEADCOUNT);

  const turnoverPivoted = pivotByMonth(hrData, "ANNUALIZED_TURNOVER_RATE");

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-slate-400">
      Loading HR data...
    </div>
  );

  return (
    <div className="space-y-6">
      {/* KPI Cards */}
      <div className="grid grid-cols-4 gap-4">
        {[
          { label: "Total Headcount",       value: totalHC.toLocaleString(),                          sub: latestMonth },
          { label: "New Hires MTD",         value: totalHires.toLocaleString(),                       sub: latestMonth },
          { label: "Separations MTD",       value: totalSeps.toLocaleString(),                        sub: latestMonth },
          { label: "Annualized Turnover",   value: avgTurnover != null ? avgTurnover.toFixed(1)+"%" : "—", sub: "avg across brands" },
        ].map((card) => (
          <div key={card.label} className="bg-white rounded-lg border border-slate-200 p-4 shadow-sm">
            <p className="text-xs text-slate-500 mb-1">{card.label}</p>
            <p className="text-2xl font-semibold text-slate-800">{card.value}</p>
            <p className="text-xs text-slate-400 mt-0.5">{card.sub}</p>
          </div>
        ))}
      </div>

      {/* Headcount by Brand — use Cell for brand colors */}
      <div className="bg-white rounded-lg border border-slate-200 p-5 shadow-sm">
        <h3 className="text-sm font-semibold text-slate-700 mb-4">
          Headcount by Brand — {latestMonth}
        </h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={headcountByBrand} margin={{ left: 8, right: 24 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="BRAND_NAME" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} />
            <Tooltip />
            <Bar dataKey="ENDING_HEADCOUNT" name="Headcount" radius={[3, 3, 0, 0]}>
              {headcountByBrand.map((entry) => (
                <Cell key={entry.BRAND_NAME}
                  fill={BRAND_COLORS[entry.BRAND_NAME] ?? "#94a3b8"} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Monthly Turnover Rate by Brand */}
      <div className="bg-white rounded-lg border border-slate-200 p-5 shadow-sm">
        <h3 className="text-sm font-semibold text-slate-700 mb-4">
          Annualized Turnover Rate (%) — Last 12 Months
        </h3>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={turnoverPivoted} margin={{ right: 16, left: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="month" tick={{ fontSize: 11 }}
              tickFormatter={(v) => String(v).slice(0, 7)} />
            <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => v + "%"} />
            <Tooltip formatter={(v: number) => v.toFixed(1) + "%"}
              labelFormatter={(l) => String(l).slice(0, 7)} />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            {BRANDS.map((brand) => (
              <Line key={brand} type="monotone" dataKey={brand}
                stroke={BRAND_COLORS[brand]} strokeWidth={2} dot={false} connectNulls />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
