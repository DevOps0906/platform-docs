// RPC SQLSTATE → 사용자 문구. 내부 오류 원문은 응답하지 않는다 (04_API 1절, 7절).
const MAP: Record<string, string> = {
  SY001: "대상을 찾을 수 없거나 공개되지 않았습니다.",
  SY002: "날짜 또는 범위가 올바르지 않습니다.",
  SY003: "선택한 날짜는 사용할 수 없습니다.",
  SY004: "인원 값이 올바르지 않거나 최대 인원을 넘습니다.",
  SY005: "최소·최대 숙박일 조건에 맞지 않습니다.",
  SY429: "요청이 너무 많습니다. 잠시 후 다시 시도하세요.",
  "42501": "권한이 없습니다.",
};

export interface ToolError {
  code: string;
  message: string;
}

export function mapError(err: unknown): ToolError {
  const code = typeof err === "object" && err && "code" in err ? String((err as { code: unknown }).code) : "";
  if (code in MAP) return { code, message: MAP[code]! };
  return { code: "INTERNAL", message: "일시적인 오류입니다. 잠시 후 다시 시도하세요." };
}

export function toolErrorResult(e: ToolError) {
  return { isError: true as const, content: [{ type: "text" as const, text: JSON.stringify({ ok: false, error: e }) }] };
}

export function toolOk(data: unknown, summary: string) {
  return {
    content: [{ type: "text" as const, text: `${summary}\n${JSON.stringify({ ok: true, data })}` }],
  };
}
