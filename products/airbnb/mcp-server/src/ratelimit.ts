import { createHmac } from "node:crypto";

// MVP: 단일 인스턴스 메모리 창. 여러 인스턴스면 DB 버킷(stay_rate_limit)이나 Redis로 교체 (미결정).
export class RateLimiter {
  private hits = new Map<string, number[]>();
  constructor(private readonly limit: number, private readonly windowMs: number) {}

  allow(key: string, now = Date.now()): boolean {
    const arr = (this.hits.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (arr.length >= this.limit) {
      this.hits.set(key, arr);
      return false;
    }
    arr.push(now);
    this.hits.set(key, arr);
    return true;
  }
}

// 원문 IP를 저장하지 않는다. 날짜가 섞인 HMAC만 키로 쓴다 (04_API 1절).
export function ipKey(ip: string, secret: string, now = new Date()): string {
  const day = now.toISOString().slice(0, 10);
  return "stay:mcp:" + createHmac("sha256", secret).update(`${day}${ip}`).digest("hex").slice(0, 32);
}
