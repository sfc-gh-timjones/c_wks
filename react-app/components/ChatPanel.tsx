"use client";

import { useState, useRef, useEffect } from "react";
import { Send, Bot, User, Loader2 } from "lucide-react";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export default function ChatPanel() {
  const [messages, setMessages] = useState<Message[]>([
    {
      role: "assistant",
      content:
        "Hi! I'm the WKS data assistant. Ask me about weekly sales, brand performance, headcount, turnover, or company policies.",
    },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [toolStatus, setToolStatus] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function send() {
    const text = input.trim();
    if (!text || loading) return;

    const userMsg: Message = { role: "user", content: text };
    const history = [...messages, userMsg];
    setMessages(history);
    setInput("");
    setLoading(true);
    setToolStatus(null);

    // Append a placeholder assistant message we'll update as SSE arrives
    setMessages((prev) => [...prev, { role: "assistant", content: "" }]);

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: history }),
      });

      if (!res.body) throw new Error("No response stream");

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let sseBuffer = ""; // retain incomplete lines across network chunks

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        // Accumulate decoded bytes; only process complete \n-terminated lines
        sseBuffer += decoder.decode(value, { stream: true });
        const lines = sseBuffer.split("\n");
        sseBuffer = lines.pop() ?? ""; // keep last (potentially incomplete) line

        for (const line of lines) {
          if (!line.startsWith("data:")) continue;
          const data = line.slice(5).trim();
          if (data === "[DONE]") continue;
          try {
            const parsed = JSON.parse(data);
            if (parsed.error) {
              setMessages((prev) => {
                const updated = [...prev];
                updated[updated.length - 1] = {
                  role: "assistant",
                  content: `Error: ${parsed.error}`,
                };
                return updated;
              });
            }
            if (parsed.status) {
              setToolStatus(parsed.status);
            }
            // block = data_to_chart or other non-text tool result
            if (parsed.block) {
              setToolStatus(null);
              setMessages((prev) => {
                const updated = [...prev];
                const current = updated[updated.length - 1].content;
                const notice = current.endsWith("chart")
                  ? ""
                  : "\n\n*(Chart generated — open Snowflake Intelligence for interactive view)*";
                updated[updated.length - 1] = {
                  role: "assistant",
                  content: current + notice,
                };
                return updated;
              });
            }
            if (parsed.text !== undefined) {
              setToolStatus(null);
              setMessages((prev) => {
                const updated = [...prev];
                updated[updated.length - 1] = {
                  role: "assistant",
                  content: parsed.text,
                };
                return updated;
              });
            }
          } catch {
            // skip malformed line
          }
        }
      }
    } catch (err) {
      setMessages((prev) => {
        const updated = [...prev];
        updated[updated.length - 1] = {
          role: "assistant",
          content: `Sorry, something went wrong: ${err}`,
        };
        return updated;
      });
    } finally {
      setLoading(false);
      setToolStatus(null);
    }
  }

  return (
    <div className="flex flex-col h-full bg-white border-l border-slate-200">
      {/* Header */}
      <div className="px-4 py-3 border-b border-slate-200 bg-slate-50">
        <div className="flex items-center gap-2">
          <Bot size={18} className="text-blue-600" />
          <span className="text-sm font-semibold text-slate-700">WKS Assistant</span>
          <span className="ml-auto text-xs text-slate-400">Powered by Snowflake Intelligence</span>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex gap-3 ${msg.role === "user" ? "flex-row-reverse" : ""}`}
          >
            <div
              className={`flex-shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-white text-xs ${
                msg.role === "user" ? "bg-blue-600" : "bg-slate-600"
              }`}
            >
              {msg.role === "user" ? <User size={14} /> : <Bot size={14} />}
            </div>
            <div
              className={`max-w-[85%] rounded-lg px-3 py-2 text-sm whitespace-pre-wrap ${
                msg.role === "user"
                  ? "bg-blue-600 text-white"
                  : "bg-slate-100 text-slate-800"
              }`}
            >
              {msg.content || (loading && i === messages.length - 1 ? (
                <Loader2 size={14} className="animate-spin" />
              ) : "")}
            </div>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Tool status indicator */}
      {toolStatus && (
        <div className="px-4 py-1.5 border-t border-slate-100 bg-slate-50">
          <p className="text-xs text-slate-500 flex items-center gap-1.5">
            <Loader2 size={11} className="animate-spin" />
            {toolStatus}
          </p>
        </div>
      )}

      {/* Input */}
      <div className="px-4 py-3 border-t border-slate-200">
        <form
          className="flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            send();
          }}
        >
          <input
            type="text"
            className="flex-1 text-sm border border-slate-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Ask about sales, HR, or policies…"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !input.trim()}
            className="bg-blue-600 text-white rounded-lg px-3 py-2 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
          </button>
        </form>
      </div>
    </div>
  );
}
