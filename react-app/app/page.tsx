"use client";

import { useState } from "react";
import SalesDashboard from "@/components/SalesDashboard";
import HRDashboard from "@/components/HRDashboard";
import ChatPanel from "@/components/ChatPanel";

export default function Home() {
  const [tab, setTab] = useState<"sales" | "hr">("sales");

  return (
    <div className="flex h-screen bg-slate-50 font-sans text-sm overflow-hidden">
      {/* Left panel: dashboard */}
      <div className="flex flex-col flex-1 min-w-0">
        {/* Top bar */}
        <header className="flex items-center px-6 py-3 bg-white border-b border-slate-200 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded bg-blue-600 flex items-center justify-center text-white font-bold text-xs">
              WKS
            </div>
            <div>
              <p className="font-semibold text-slate-800 text-sm">WKS Restaurant Group</p>
              <p className="text-xs text-slate-500">Snowflake Platform Demo</p>
            </div>
          </div>

          {/* Tab nav */}
          <nav className="ml-8 flex gap-1">
            {(["sales", "hr"] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`px-4 py-1.5 rounded text-xs font-medium transition-colors ${
                  tab === t
                    ? "bg-blue-600 text-white"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                {t === "sales" ? "Sales Analytics" : "HR & Workforce"}
              </button>
            ))}
          </nav>

          <div className="ml-auto flex items-center gap-4">
            <span className="text-xs text-slate-400">
              Data via Dynamic Tables · Semantic View · Cortex Agent
            </span>
          </div>
        </header>

        {/* Dashboard content */}
        <main className="flex-1 overflow-y-auto px-6 py-5">
          {tab === "sales" ? <SalesDashboard /> : <HRDashboard />}
        </main>
      </div>

      {/* Right panel: chat (fixed width) */}
      <div className="w-80 flex-shrink-0 flex flex-col">
        <ChatPanel />
      </div>
    </div>
  );
}
