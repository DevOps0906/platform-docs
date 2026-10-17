"""설득형 랜딩 템플릿 빌드.

data/<제품>.json 하나를 engine.html에 넣어 dist/<제품>.html을 만든다(제품마다 별도 파일).
계산기 식은 이 단계에서 자바스크립트 함수로 바꿔 넣는다(브라우저에서 eval을 쓰지 않도록).

사용:
    python3 build.py              # data/ 아래 전부
    python3 build.py nomad-docs   # 지정한 제품만
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ENGINE = HERE / "engine.html"
DATA = HERE / "data"
DIST = HERE / "dist"

HELP = ["max", "min", "ceil", "floor", "round", "won", "fmt1", "pack", "parseInt"]
MARK_DATA = "/*__PRODUCT_DATA__*/null"
MARK_CALC = "/*__CALC_FN__*/null"
MARK_TITLE = "<title>설득형 랜딩 템플릿</title>"


def js_safe(text: str) -> str:
    """<script> 안에 넣어도 닫는 태그로 읽히지 않게 한다."""
    return text.replace("</", "<\\/").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")


def calc_functions(calc: dict) -> str:
    inputs = [f[0] for g in calc["groups"] for f in g[1]]
    derived = [d[0] for d in calc.get("derived", [])]
    names = HELP + inputs + derived
    for n in inputs + derived:
        if not n.isidentifier():
            raise ValueError(f"계산기 키가 식별자가 아님: {n}")
    params = ",".join(names)

    def fn(expr: str) -> str:
        if "</" in expr:
            raise ValueError(f"식에 '</' 사용 금지: {expr}")
        return f'function({params}){{"use strict";return ({expr});}}'

    d = ",".join(fn(x[1]) for x in calc.get("derived", []))
    r = ",".join("[" + ",".join(fn(e) for e in row[1:4]) + "]" for row in calc["rows"])
    return "{names:" + json.dumps(names) + ",d:[" + d + "],r:[" + r + "]}"


def build(key: str, engine: str) -> pathlib.Path:
    data = json.loads((DATA / f"{key}.json").read_text(encoding="utf-8"))
    if data.get("key") != key:
        raise ValueError(f"{key}.json의 key 값이 파일명과 다름")
    out = engine
    for mark in (MARK_DATA, MARK_CALC, MARK_TITLE):
        if out.count(mark) != 1:
            raise ValueError(f"엔진 표식이 1개가 아님: {mark}")
    out = out.replace(MARK_TITLE, f"<title>{data['short']} 설득형 랜딩 템플릿</title>")
    out = out.replace(MARK_DATA, js_safe(json.dumps(data, ensure_ascii=False)))
    out = out.replace(MARK_CALC, js_safe(calc_functions(data["calc"])))
    DIST.mkdir(exist_ok=True)
    path = DIST / f"{key}.html"
    path.write_text(out, encoding="utf-8")
    return path


def main() -> None:
    engine = ENGINE.read_text(encoding="utf-8")
    keys = sys.argv[1:] or sorted(p.stem for p in DATA.glob("*.json"))
    for key in keys:
        path = build(key, engine)
        print(f"{path.relative_to(HERE)}  {path.stat().st_size // 1024}KB")


if __name__ == "__main__":
    main()
