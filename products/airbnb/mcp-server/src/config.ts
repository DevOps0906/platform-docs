// 환경 변수. service_role 키는 읽지 않는다 (MCP_BASELINE 4절).
export interface Config {
  supabaseUrl: string;
  supabaseAnonKey: string;
  webBaseUrl: string;
  ipHmacSecret: string;
  port: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  if (env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY must not be set for the MCP server");
  }
  const need = (k: string): string => {
    const v = env[k];
    if (!v) throw new Error(`Missing env ${k}`);
    return v;
  };
  return {
    supabaseUrl: need("SUPABASE_URL"),
    supabaseAnonKey: need("SUPABASE_ANON_KEY"),
    webBaseUrl: env.STAY_WEB_BASE_URL ?? "http://localhost:3000",
    ipHmacSecret: need("STAY_IP_HMAC_SECRET"),
    port: Number(env.PORT ?? 8787),
  };
}
