import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Config } from "./config.js";
import { anonClient } from "./supabase.js";
import { searchDescription, searchInput, searchListings } from "./tools/search.js";
import { getListing, listingDescription, listingInput } from "./tools/listing.js";
import { getUnavailable, unavailableDescription, unavailableInput } from "./tools/unavailable.js";
import { getReviews, reviewsDescription, reviewsInput } from "./tools/reviews.js";
import type { ToolContext } from "./tools/shared.js";

const READ_ONLY = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false } as const;

// MVP: R0 도구 4개만 등록한다 (MCP.md 2절).
// 로그인 도구(stay_my_trips 등)와 stay_prepare_reservation은 D-M1 결정 후 추가.
// 예약 확정·승인·취소 도구는 만들지 않는다 (MCP_BASELINE 2절 W2).
export function buildServer(cfg: Config, ctx?: ToolContext): McpServer {
  const server = new McpServer({ name: "stay-mcp", version: "0.1.0" });
  const c: ToolContext = ctx ?? { cfg, db: anonClient(cfg) };

  server.registerTool(
    "stay_search_listings",
    { title: "숙소 검색", description: searchDescription, inputSchema: searchInput, annotations: READ_ONLY },
    async (a) => searchListings(c, a),
  );
  server.registerTool(
    "stay_get_listing",
    { title: "숙소 상세", description: listingDescription, inputSchema: listingInput, annotations: READ_ONLY },
    async (a) => getListing(c, a),
  );
  server.registerTool(
    "stay_get_unavailable_dates",
    { title: "예약 불가 날짜", description: unavailableDescription, inputSchema: unavailableInput, annotations: READ_ONLY },
    async (a) => getUnavailable(c, a),
  );
  server.registerTool(
    "stay_get_listing_reviews",
    { title: "숙소 후기", description: reviewsDescription, inputSchema: reviewsInput, annotations: READ_ONLY },
    async (a) => getReviews(c, a),
  );
  return server;
}
