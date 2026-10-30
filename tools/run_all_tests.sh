#!/usr/bin/env bash
# 전체 테스트를 한 번에 (Linux/macOS, Godot 4.3). 테스트는 user://settings.cfg 를 함께 쓰므로 하나씩 차례로 돌립니다.
#   GODOT=/path/to/godot ./tools/run_all_tests.sh            헤드리스 테스트 전부 (약 30~40분)
#   QUICK=1 ./tools/run_all_tests.sh                         규칙 엔진 + 핵심 UI만 (약 5분)
# xvfb-run 이 있으면 화면이 필요한 테스트(스모크·키보드 입력)도 함께 돌립니다.
# 결과: 테스트별 PASS/FAIL 표와 로그 폴더. 하나라도 실패하면 종료 코드 1.
set -u
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
declare -a NAMES RESULTS
fail=0

if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
else
  TIMEOUT_CMD=""
fi

run() {   # run <name> <timeout> <env...> -- <godot args...>
  local name="$1" to="$2"; shift 2
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  if [ -n "$TIMEOUT_CMD" ]; then
    env "${envs[@]}" "$TIMEOUT_CMD" "$to" "$G" "$@" > "$OUT/$name.log" 2>&1
  else
    env "${envs[@]}" "$G" "$@" > "$OUT/$name.log" 2>&1
  fi
  local rc=$?
  local res="$([ $rc -eq 0 ] && echo PASS || echo "FAIL (rc=$rc)")"
  NAMES+=("$name"); RESULTS+=("$res")
  [ $rc -eq 0 ] || fail=1
  printf "  %-34s %s\n" "$name" "$res"
}
H=(--headless --fixed-fps 60 --path .)
N="RAZZIA_NO_DIALOGUE=1"

echo "logs: $OUT"
echo "== rules engine / AI"
run engine 900 X=1 -- --headless --path . --script res://tests/run_tests.gd
run ai_levels 900 X=1 -- "${H[@]}" --script res://tests/ai_levels_test.gd
run relic_system 300 X=1 -- "${H[@]}" --script res://tests/relic_system_test.gd
run black_market 300 X=1 -- "${H[@]}" --script res://tests/black_market_test.gd
echo "== core UI"
for t in ui_pause_test ui_venue_info_test ui_extra_money_census_test ui_scene_story_test ui_dialogue_test ui_coach_test ui_duel_flow_test i18n_slots_test audio_cue_test ui_character_alive_test ui_ux_audit_test; do
  run "$t" 600 X=1 -- "${H[@]}" --script "res://tests/$t.gd"
done
run qa_playthrough 900 X=1 -- "${H[@]}" --script res://tests/qa_playthrough_test.gd -- w=1280 h=800
run qa_gamepad 900 X=1 -- "${H[@]}" --script res://tests/qa_gamepad_playthrough_test.gd -- w=1280 h=800
run qa_tutorial 900 X=1 -- "${H[@]}" --script res://tests/qa_tutorial_test.gd
run qa_gamepad_en 900 X=1 -- "${H[@]}" --script res://tests/qa_gamepad_playthrough_test.gd -- w=1280 h=800 lang=en
if [ "${QUICK:-0}" != "1" ]; then
  echo "== more UI"
  for t in ui_round_note_test ui_audio_mix_test ui_audio_test ui_duel_stage_test ui_nego_choice_test ui_exit_menu_test ui_enter_flow_test \
           records_test rules_help_test summary_test platform_test ui_pad_menu_test qa_resume_test qa_stability_test; do
    run "$t" 900 X=1 -- "${H[@]}" --script "res://tests/$t.gd"
  done
  run platform_deck 200 SteamDeck=1 -- --headless --path . --script res://tests/platform_test.gd -- expect=deck
  run qa_tutorial_pad 900 X=1 -- "${H[@]}" --script res://tests/qa_tutorial_test.gd -- pad=1
  run qa_tutorial_en 900 X=1 -- "${H[@]}" --script res://tests/qa_tutorial_test.gd -- lang=en
  run qa_playthrough_en 900 X=1 -- "${H[@]}" --script res://tests/qa_playthrough_test.gd -- w=430 h=932 lang=en
  run qa_gamepad_longname 900 X=1 -- "${H[@]}" --script res://tests/qa_gamepad_playthrough_test.gd -- w=430 h=932 name=WWWWWWWWWWWWWWW
  run tutorial_seed 300 X=1 -- --headless --path . --script res://tools/find_tutorial_seed.gd -- check=23
  run save_resume 300 "$N" -- --headless --path . --script res://tests/save_resume_test.gd
  NAMES+=("restart_settings_saves")
  local t120=""
  [ -n "$TIMEOUT_CMD" ] && t120="$TIMEOUT_CMD 120"
  local rs_res="FAIL"
  if RAZZIA_TEST_TAG=rs RAZZIA_TEST_KEEP=1 $t120 "$G" --headless --path . --script res://tests/restart_test.gd -- step=1 > "$OUT/restart.log" 2>&1 \
     && RAZZIA_TEST_TAG=rs $t120 "$G" --headless --path . --script res://tests/restart_test.gd -- step=2 >> "$OUT/restart.log" 2>&1; then
    rs_res="PASS"
  else
    fail=1
  fi
  RESULTS+=("$rs_res")
  printf "  %-34s %s\n" "restart_settings_saves" "$rs_res"
  run razzia_skip 400 "$N" -- "${H[@]}" --script res://tests/ui_razzia_skip_test.gd
  run round_start 400 "$N" -- "${H[@]}" --script res://tests/ui_round_start_test.gd
  for r in "1280 720" "430 932" "844 390"; do set -- $r
    run "mouse_hit_$1x$2" 300 "$N" -- "${H[@]}" --script res://tests/ui_mouse_hit_test.gd -- w=$1 h=$2
    run "resume_$1x$2" 200 "$N" -- --headless --path . --script res://tests/ui_resume_test.gd -- w=$1 h=$2
    run "touch_skip_$1x$2" 200 "$N" -- --headless --path . --script res://tests/ui_touch_skip_test.gd -- seed=5 w=$1 h=$2
  done
  if command -v xvfb-run > /dev/null; then
    echo "== rendered (xvfb)"
    for c in "3 1280 720" "4 430 932" "8 768 1024"; do set -- $c
      NAMES+=("smoke_${1}p_$2x$3")
      if RAZZIA_NO_DIALOGUE=1 timeout 400 xvfb-run -a -s "-screen 0 2700x1500x24" "$G" --path . --rendering-driver opengl3 --script res://tests/ui_smoke.gd -- players=$1 seed=7 w=$2 h=$3 scale=8 > "$OUT/smoke_${1}p.log" 2>&1 \
         && grep -q "errors=0" "$OUT/smoke_${1}p.log"; then RESULTS+=("PASS"); else RESULTS+=("FAIL"); fail=1; fi
      printf "  %-34s %s\n" "smoke_${1}p_$2x$3" "${RESULTS[-1]}"
    done
    for r in "1280 720 ko" "844 390 en" "430 932 ko" "1024 768 en"; do set -- $r
      NAMES+=("no_scroll_$1x$2_$3")
      if timeout 400 xvfb-run -a -s "-screen 0 2700x1500x24" "$G" --path . --rendering-driver opengl3 --script res://tools/ui_shots.gd -- w=$1 h=$2 lang=$3 > "$OUT/no_scroll_$1x$2_$3.log" 2>&1; then RESULTS+=("PASS"); else RESULTS+=("FAIL"); fail=1; fi
      printf "  %-34s %s\n" "no_scroll_$1x$2_$3" "${RESULTS[-1]}"
    done
    for r in "1280 720" "430 932"; do set -- $r
      NAMES+=("input_$1x$2")
      if timeout 400 xvfb-run -a -s "-screen 0 2700x1500x24" "$G" --path . --rendering-driver opengl3 --script res://tests/ui_input_test.gd -- w=$1 h=$2 > "$OUT/input_$1x$2.log" 2>&1; then RESULTS+=("PASS"); else RESULTS+=("FAIL"); fail=1; fi
      printf "  %-34s %s\n" "input_$1x$2" "${RESULTS[-1]}"
    done
  fi
  if grep -rn "ScrollContainer" ui/ > "$OUT/no_scroll_code.log"; then echo "  no_scroll_code                     FAIL"; fail=1; else echo "  no_scroll_code                     PASS"; fi
  python3 tools/i18n/build_en.py > "$OUT/i18n_table.log" 2>&1 && echo "  i18n_table                         PASS" || { echo "  i18n_table                         FAIL"; fail=1; }
  run parse_all 120 X=1 -- --headless --path . --script res://tools/parse_all.gd
  python3 tools/check_paths.py > "$OUT/check_paths.log" 2>&1 && echo "  check_paths                        PASS" || { echo "  check_paths                        FAIL"; fail=1; }
fi
echo
[ $fail -eq 0 ] && echo "ALL TESTS: PASS" || echo "ALL TESTS: FAIL  (logs in $OUT)"
exit $fail
