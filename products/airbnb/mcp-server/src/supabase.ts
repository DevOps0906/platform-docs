import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Config } from "./config.js";

// 익명 읽기 클라이언트. 요청마다 새로 만들어 전역 상태를 두지 않는다 (CLAUDE.md 2절).
export function anonClient(cfg: Config): SupabaseClient {
  return createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Phase 1.5: 사용자 본인 토큰으로 만든 요청 단위 클라이언트. RLS와 RPC의 auth.uid()가 판정한다.
// 토큰을 다른 서비스에 넘기지 않는다. 토큰 획득 방식은 MCP.md D-M1 미결정.
export function userClient(cfg: Config, accessToken: string): SupabaseClient {
  return createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}
