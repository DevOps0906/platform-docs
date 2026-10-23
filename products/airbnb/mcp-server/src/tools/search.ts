import { z } from "zod";
import { mapError, toolErrorResult, toolOk } from "../errors.js";
import { pick, clip } from "../sanitize.js";
import { CARD_FIELDS, listingUrl, type ToolContext } from "./shared.js";

export const searchInput = {
  sw_lat: z.number().min(-90).max(90).optional().describe("지도 남서쪽 위도. 경계 4개는 모두 주거나 모두 생략"),
  sw_lng: z.number().min(-180).max(180).optional(),
  ne_lat: z.number().min(-90).max(90).optional(),
  ne_lng: z.number().min(-180).max(180).optional(),
  city: z.string().max(60).optional().describe("도시 이름, 예: 제주시"),
  check_in: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().describe("체크인 YYYY-MM-DD. check_out과 함께"),
  check_out: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().describe("체크아웃 YYYY-MM-DD"),
  guests: z.number().int().min(1).max(16).default(1),
  min_price: z.number().int().min(0).optional().describe("1박 최소 가격(원)"),
  max_price: z.number().int().min(0).optional().describe("1박 최대 가격(원)"),
  room_type: z.enum(["entire", "private", "shared"]).optional(),
  limit: z.number().int().min(1).max(20).default(10),
  offset: z.number().int().min(0).max(1000).default(0),
};

export const searchDescription =
  "숙소를 검색한다. 도시나 지도 경계, 날짜, 인원, 가격으로 거른다. " +
  "가격은 원화이고 예약 가능 여부의 최종 판정은 예약 화면에서 한다. " +
  "정확한 주소와 좌표는 제공하지 않는다.";

export async function searchListings(ctx: ToolContext, a: z.infer<z.ZodObject<typeof searchInput>>) {
  const bounds = [a.sw_lat, a.sw_lng, a.ne_lat, a.ne_lng];
  const given = bounds.filter((v) => v !== undefined).length;
  if (given !== 0 && given !== 4) return toolErrorResult({ code: "SY002", message: "지도 경계는 4개를 모두 주거나 모두 생략하세요." });
  if ((a.check_in === undefined) !== (a.check_out === undefined)) {
    return toolErrorResult({ code: "SY002", message: "체크인과 체크아웃은 함께 주세요." });
  }
  const { data, error } = await ctx.db.rpc("search_listings", {
    p_sw_lat: a.sw_lat ?? null, p_sw_lng: a.sw_lng ?? null,
    p_ne_lat: a.ne_lat ?? null, p_ne_lng: a.ne_lng ?? null,
    p_city: a.city ?? null, p_check_in: a.check_in ?? null, p_check_out: a.check_out ?? null,
    p_guests: a.guests, p_min_price: a.min_price ?? null, p_max_price: a.max_price ?? null,
    p_room_type: a.room_type ?? null, p_limit: a.limit, p_offset: a.offset,
  });
  if (error) return toolErrorResult(mapError(error));
  const items = (Array.isArray(data) ? data : []).slice(0, a.limit).map((row) => {
    const card = pick(row, CARD_FIELDS);
    return { ...card, title: clip(String(card.title ?? ""), 80), url: listingUrl(ctx.cfg, card.id) };
  });
  return toolOk({ items, next_offset: a.offset + items.length }, `숙소 ${items.length}건`);
}
