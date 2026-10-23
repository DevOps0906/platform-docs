import { z } from "zod";
import { mapError, toolErrorResult, toolOk } from "../errors.js";
import type { ToolContext } from "./shared.js";

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
export const unavailableInput = { listing_id: z.string().uuid(), from: date, to: date };

export const unavailableDescription =
  "숙소의 예약 불가 날짜 구간을 가져온다(from 이상 to 미만, 400일 이하). 비어 있는 날이 곧 예약 확정은 아니다.";

export async function getUnavailable(ctx: ToolContext, a: { listing_id: string; from: string; to: string }) {
  const { data, error } = await ctx.db.rpc("listing_unavailable_ranges", {
    p_listing_id: a.listing_id, p_from: a.from, p_to: a.to,
  });
  if (error) return toolErrorResult(mapError(error));
  const ranges = (Array.isArray(data) ? data : []).map((r: { start_date?: unknown; end_date?: unknown }) => ({
    start_date: r.start_date, end_date: r.end_date,
  }));
  return toolOk({ ranges }, `불가 구간 ${ranges.length}건`);
}
