#!/usr/bin/env bash
# Linux CI 점검 (Steam Deck / SteamOS 대비). Linux 에서 헤드리스로 돌립니다.
#   GODOT=/path/to/godot ./tools/ci_check.sh          (Godot 4.3)
#   QUICK=1 ./tools/ci_check.sh                       (경로·파싱·부팅만)
# 단계:
#   1) 대소문자 경로 검사          tools/check_paths.py
#   2) 리소스 임포트              godot --headless --import
#   3) 전체 스크립트 파싱          tools/parse_all.gd
#   4) 헤드리스 부팅 (메인 씬 120프레임, 오류 로그 0건)
#   5) 규칙/엔진 테스트            tests/run_tests.gd
#   6) 컨트롤러 전용 플레이스루     tests/qa_gamepad_playthrough_test.gd
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0

if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
else
  TIMEOUT_CMD=""
fi

_timeout() {
  local to="$1"; shift
  if [ -n "$TIMEOUT_CMD" ]; then
    "$TIMEOUT_CMD" "$to" "$@"
  else
    "$@"
  fi
}

step() { echo; echo "== $1"; }
run() { if "$@"; then echo "   -> PASS"; else echo "   -> FAIL"; fail=1; fi; }

step "1) case-sensitive paths"
run python3 tools/check_paths.py

step "2) import"
run _timeout 600 "$GODOT" --headless --path . --import

step "3) parse all scripts"
run _timeout 300 "$GODOT" --headless --path . --script res://tools/parse_all.gd

step "4) headless boot of res://ui/main.tscn"
log=$(mktemp)
_timeout 120 "$GODOT" --headless --path . --quit-after 120 > "$log" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file" "$log" > /dev/null; then
  grep -E "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file" "$log" | head -20; echo "   -> FAIL"; fail=1
else
  grep -E "\[SteamDeckManager\] ready" "$log" | head -1; echo "   -> PASS"
fi
rm -f "$log"

if [ "${QUICK:-0}" != "1" ]; then
  step "5) rules / engine tests"
  run _timeout 900 "$GODOT" --headless --path . --script res://tests/run_tests.gd

  step "6a) tutorial table still stages as planned (seed + scripted AI)"
  run _timeout 300 "$GODOT" --headless --path . --script res://tools/find_tutorial_seed.gd -- check=23

  step "6b) tutorial with the controller only"
  run _timeout 900 "$GODOT" --headless --fixed-fps 60 --path . --script res://tests/qa_tutorial_test.gd -- pad=1

  step "6) controller-only playthrough"
  run _timeout 1200 "$GODOT" --headless --fixed-fps 60 --path . --script res://tests/qa_gamepad_playthrough_test.gd -- w=1280 h=800
fi

echo
[ $fail -eq 0 ] && echo "CI: PASS" || echo "CI: FAIL"
exit $fail
