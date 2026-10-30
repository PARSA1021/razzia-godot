#!/usr/bin/env python3
"""Linux 대소문자 경로 검사 (Steam Deck / SteamOS 는 대소문자를 구분하는 파일 시스템을 씁니다).

Windows / macOS 에서는 "res://Assets/Foo.PNG" 가 "res://assets/foo.png" 로 열리지만 Linux 에서는 열리지 않습니다.
이 스크립트는 프로젝트의 모든 res:// 참조가 *정확한 대소문자*로 존재하는지 확인합니다.

  1) 정적 경로: .gd .tscn .tres .gdshader project.godot 안의 "res://..." 문자열
  2) 동적 경로: "res://.../%s.png" 형식 문자열 + 그 자리에 들어가는 실제 ID (술집 ID, 캐릭터 이름)
  3) .import 파일이 가리키는 원본(source_file)

종료 코드: 0 = 문제 없음, 1 = 문제 있음.   사용법: python3 tools/check_paths.py [프로젝트 경로]
"""
import os
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
EXTS = (".gd", ".tscn", ".tres", ".gdshader", ".godot", ".cfg")
SKIP_DIRS = {".godot", ".git", "node_modules", "js"}
RES_RE = re.compile(r'res://[^"\'\s)\]]+')

problems = []
checked = 0


def exact_exists(rel: str):
    """rel 의 각 구성 요소가 정확한 대소문자로 존재하는지. (ok, 대소문자만 다른 실제 경로 또는 None)"""
    cur = ROOT
    actual = []
    for part in [p for p in rel.split("/") if p]:
        try:
            names = os.listdir(cur)
        except OSError:
            return False, None
        if part in names:
            actual.append(part)
            cur = os.path.join(cur, part)
            continue
        low = {n.lower(): n for n in names}
        if part.lower() in low:
            actual.append(low[part.lower()])
            rest = rel.split("/")[len(actual):]
            return False, "/".join(actual + rest)
        return False, None
    return True, None


def check(path: str, where: str, optional: bool = False):
    global checked
    rel = path[len("res://"):]
    if rel.startswith("tests/fixtures/"):
        pass
    checked += 1
    ok, case_hit = exact_exists(rel)
    if ok:
        return
    if case_hit:
        problems.append(f"[대소문자] {where}: {path}  -> 실제 파일은 res://{case_hit}")
    elif not optional:
        problems.append(f"[없음] {where}: {path}")


def source_files():
    for d, dirs, files in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in files:
            if f.endswith(EXTS):
                yield os.path.join(d, f)


# 동적 경로 패턴 -> 들어가는 ID 목록 (엔진/UI 소스에서 직접 읽습니다)
def read_ids():
    eng = open(os.path.join(ROOT, "engine/engine.gd"), encoding="utf-8").read()
    bars = re.findall(r'\{"id": "([A-Z_]+)", "name"', eng)
    tok = open(os.path.join(ROOT, "ui/tokens.gd"), encoding="utf-8").read()
    names = re.findall(r'"([A-Za-z]+)"', re.search(r"const AI_NAMES := \[([^\]]*)\]", tok).group(1))
    return bars, names


BARS, AI_NAMES = read_ids()
DYNAMIC = {
    "res://assets/art/bars/%s.jpg": (BARS, False),
    "res://assets/art/cards/zocker_%s.jpg": (BARS, False),
    "res://assets/art/cards/razzia_%s.jpg": (BARS, False),
    "res://assets/characters/%s.png": (AI_NAMES, False),
    "res://assets/characters_full/%s.png": (AI_NAMES, False),
    "res://assets/audio/barks/%s_%s": ([], True),
}

dyn_seen = set()
for fp in source_files():
    relf = os.path.relpath(fp, ROOT)
    text = open(fp, encoding="utf-8", errors="replace").read()
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in RES_RE.finditer(line):
            p = m.group(0).rstrip(".,;:")
            where = f"{relf}:{lineno}"
            if "<" in p:
                continue                # 주석 속 설명용 경로 (res://.../<name>.png)
            if "%" in p or p.endswith("/"):
                if p in DYNAMIC:
                    dyn_seen.add(p)
                elif "%" in p:
                    problems.append(f"[미등록 동적 경로] {where}: {p}  (tools/check_paths.py 의 DYNAMIC 에 ID 목록을 추가하세요)")
                continue
            if relf.startswith("tests/") and ("user://" in line or "/tmp" in p):
                continue
            check(p, where)

for pat, (ids, optional) in DYNAMIC.items():
    if pat not in dyn_seen:
        continue
    for i in ids:
        check(pat % i, f"동적 {pat} [{i}]", optional)

# .import 파일의 원본 경로
for d, dirs, files in os.walk(ROOT):
    dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
    for f in files:
        if f.endswith(".import"):
            t = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
            m = re.search(r'source_file="(res://[^"]+)"', t)
            if m:
                check(m.group(1), os.path.relpath(os.path.join(d, f), ROOT))

print(f"check_paths: {checked} paths checked, {len(problems)} problem(s)  (bars={len(BARS)}, characters={len(AI_NAMES)})")
for p in problems:
    print("  " + p)
sys.exit(1 if problems else 0)
