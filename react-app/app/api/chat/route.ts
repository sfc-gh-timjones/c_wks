import { NextRequest } from "next/server";

const SF_HOST = process.env.SNOWFLAKE_HOST || process.env.SF_HOST || "";
const AGENT_URL = `https://${SF_HOST}/api/v2/databases/CUSTOMER_DEMOS/schemas/WKS/agents/WKS_AGENT:run`;

function getToken(): string {
  if (process.env.SF_TOKEN) return process.env.SF_TOKEN;
  try {
    const { readFileSync } = require("fs");
    return readFileSync("/snowflake/session/token", "utf8").trim();
  } catch {
    throw new Error("No Snowflake token available");
  }
}

export async function POST(req: NextRequest) {
  const { messages } = await req.json();
  const token = getToken();

  const agentRes = await fetch(AGENT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "text/event-stream",
    },
    body: JSON.stringify({
      messages: messages.map((m: { role: string; content: string }) => ({
        role: m.role,
        // content MUST be an array — plain string causes error 390142
        content: [{ type: "text", text: m.content }],
      })),
    }),
  });

  if (!agentRes.ok) {
    const err = await agentRes.text();
    return new Response(
      `data: ${JSON.stringify({ error: `Agent error ${agentRes.status}: ${err}` })}\n\ndata: [DONE]\n\n`,
      {
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
        },
      }
    );
  }

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const reader = agentRes.body!.getReader();
      const decoder = new TextDecoder();
      let buffer = "";           // incomplete-line buffer across chunks
      let lastContent = "";
      let highestIndex = -1;

      function enqueue(payload: object) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
      }

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          // Accumulate decoded bytes; only process complete \n-terminated lines.
          // This prevents silent drops when a network chunk splits a data: line.
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          // Keep the last potentially-incomplete line in the buffer
          buffer = lines.pop() ?? "";

          for (const line of lines) {
            if (!line.startsWith("data:")) continue;
            const raw = line.slice(5).trim();
            if (raw === "[DONE]") {
              if (lastContent) enqueue({ text: lastContent });
              enqueue({ done: true });
              controller.close();
              return;
            }
            try {
              const parsed = JSON.parse(raw);

              // Tool-call indicator — show "thinking" status in the UI
              if (parsed.type === "tool_use" || parsed.tool_use?.name) {
                const toolName = parsed.tool_use?.name ?? "data";
                enqueue({ status: `Querying ${toolName}...` });
                continue;
              }

              const delta = parsed?.delta;
              if (!delta) continue;

              // Use content_index >= 0 (NOT > 0) — VQR answers land at index 0
              const idx = parsed.content_index ?? 0;
              if (idx >= 0 && idx >= highestIndex) {
                highestIndex = idx;
                const content = delta.content;
                if (Array.isArray(content)) {
                  for (const block of content) {
                    if (block.type === "text" && block.text) {
                      lastContent += block.text;
                    }
                    // data_to_chart: forward raw block for frontend to inspect
                    if (block.type === "tool_result" || block.type === "chart") {
                      enqueue({ block });
                    }
                  }
                }
                enqueue({ text: lastContent });
              }
            } catch {
              // Skip malformed lines
            }
          }
        }
        // Process any remaining buffer content after the stream ends
        if (buffer.startsWith("data:")) {
          const raw = buffer.slice(5).trim();
          if (raw && raw !== "[DONE]") {
            try {
              const parsed = JSON.parse(raw);
              const content = parsed?.delta?.content;
              if (Array.isArray(content)) {
                for (const block of content) {
                  if (block.type === "text" && block.text) lastContent += block.text;
                }
              }
            } catch { /* ignore */ }
          }
        }
        if (lastContent) enqueue({ text: lastContent });
        enqueue({ done: true });
      } catch (err) {
        enqueue({ error: String(err) });
      } finally {
        reader.releaseLock();
        try { controller.close(); } catch { /* already closed */ }
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
