import type { SupabaseClient } from "@supabase/supabase-js";
import type { Config } from "../config.js";

export interface ToolContext {
  cfg: Config;
  db: SupabaseClient;
}

// 출력 허용 목록. 여기에 없는 필드는 어떤 도구에서도 나가지 않는다.
// listing_private(상세주소, 정확 좌표, 체크인 안내), org_id, 호스트 id는 의도적으로 없다.
export const CARD_FIELDS = [
  "id", "title", "room_type", "building_type", "city", "district",
  "public_lat", "public_lng", "price_per_night", "rating_avg", "review_count",
  "max_guests", "bedroom_count", "bed_count", "bathroom_count",
  "cover_photo_path", "host_display_name",
] as const;

export const DETAIL_FIELDS = [
  ...CARD_FIELDS,
  "bathroom_type", "amenities", "conveniences", "house_rules", "cleaning_fee",
  "min_nights", "max_nights", "check_in_time", "check_out_time", "instant_book",
  "available_from", "available_to",
] as const;

export const FORBIDDEN_KEYS = [
  "address", "address_line", "detail_address", "street", "postcode",
  "lat", "lng", "latitude", "longitude", "checkin_guide", "org_id", "owner_id",
  "email", "phone", "listing_private",
] as const;

export function listingUrl(cfg: Config, id: unknown): string {
  return `${cfg.webBaseUrl}/listings/${encodeURIComponent(String(id))}`;
}
