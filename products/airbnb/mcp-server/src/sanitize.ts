// 사용자 작성 텍스트(후기, 소개글)를 "신뢰하지 않는 자료"로 다룬다 (MCP_BASELINE M1).
// 이것만으로 인젝션이 막히는 것은 아니다. 길이 제한 + 링크 제거 + 표시가 목적이다.

const URL_RE = /\b(?:https?:\/\/|www\.)\S+/gi;
const HTML_RE = /<[^>]*>/g;
// 흔한 지시문 패턴. 완벽하지 않은 탐지용이며 차단이 아니라 표시에 쓴다.
const INSTRUCTION_RE =
  /(ignore (all|any|previous)|system prompt|you must|assistant:|이전 지시|지시를 무시|반드시 .{0,20}(추천|예약))/i;

export interface Untrusted {
  text: string;
  untrusted: true;
  flagged: boolean;
}

export function clip(s: string, max: number): string {
  const t = [...s].slice(0, max).join("");
  return t.length < s.length ? `${t}…` : t;
}

export function toUntrusted(raw: unknown, max: number): Untrusted {
  const s = typeof raw === "string" ? raw : "";
  const flagged = INSTRUCTION_RE.test(s);
  const cleaned = s.replace(HTML_RE, " ").replace(URL_RE, "[링크 제거]").replace(/\s+/g, " ").trim();
  return { text: clip(cleaned, max), untrusted: true, flagged };
}

export function pick<T extends string>(obj: unknown, keys: readonly T[]): Partial<Record<T, unknown>> {
  const out: Partial<Record<T, unknown>> = {};
  if (obj && typeof obj === "object") {
    for (const k of keys) {
      if (k in (obj as Record<string, unknown>)) out[k] = (obj as Record<string, unknown>)[k];
    }
  }
  return out;
}
