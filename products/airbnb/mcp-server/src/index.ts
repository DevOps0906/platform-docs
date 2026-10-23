import { createServer } from "node:http";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { loadConfig } from "./config.js";
import { RateLimiter, ipKey } from "./ratelimit.js";
import { buildServer } from "./server.js";

async function main() {
  const cfg = loadConfig();
  if (process.argv.includes("--stdio")) {
    await buildServer(cfg).connect(new StdioServerTransport());
    return;
  }

  // 원격(Streamable HTTP). 익명 R0 전용 MVP. 요청마다 서버·전송을 새로 만든다(무상태).
  const limiter = new RateLimiter(30, 60_000); // 익명 30회/분 (제안, MCP.md 4절)
  const host = process.env.HOST ?? "127.0.0.1"; // 로컬 개발은 루프백만 (MCP_BASELINE M7)
  const allowedOrigins = new Set((process.env.MCP_ALLOWED_ORIGINS ?? "").split(",").filter(Boolean));

  const http = createServer(async (req, res) => {
    if (req.url !== "/mcp") {
      res.writeHead(404).end();
      return;
    }
    const origin = req.headers.origin;
    if (origin && !allowedOrigins.has(origin)) {
      res.writeHead(403).end();
      return;
    }
    const ip = String(req.headers["x-forwarded-for"] ?? req.socket.remoteAddress ?? "").split(",")[0]!.trim();
    if (!limiter.allow(ipKey(ip, cfg.ipHmacSecret))) {
      res.writeHead(429, { "Retry-After": "60" }).end();
      return;
    }
    const server = buildServer(cfg);
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    res.on("close", () => {
      void transport.close();
      void server.close();
    });
    await server.connect(transport);
    await transport.handleRequest(req, res);
  });
  http.listen(cfg.port, host, () => console.error(`stay-mcp listening on ${host}:${cfg.port}/mcp`));
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : "fatal");
  process.exit(1);
});
