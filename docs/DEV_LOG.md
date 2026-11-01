# 개발 기록 (Phase 1–26)

> 이 파일은 예전 README.md 전체입니다. 단계별로 무엇을 왜 바꿨는지 시간 순서대로 남긴 기록이라 그대로 보존합니다. 현재 프로젝트 안내는 루트의 README.md를 보세요.

# Razzia Mobile — Godot 4 port (engine, AI, controller)

1992 Ravensburger *Razzia* (Stefan Dorra) 모바일 판. 이 폴더는 **규칙 엔진 + AI + 컨트롤러의 GDScript 이식**과,
JS 레퍼런스 구현과 한 비트도 다르지 않다는 것을 보장하는 테스트입니다. 화면(UI)은 `ui/`에 있습니다(아래 UI Phase 섹션 참고).

## 실행

```bash
./run_tests.sh /path/to/Godot_v4.3-stable_linux.x86_64      # 또는 GODOT=... ./run_tests.sh
# 직접: godot --headless --path . --script res://tests/run_tests.gd
```

종료 코드 0 = 전부 통과. (Godot 4.3 기준 약 10초)

## 구조

```
engine/engine.gd      규칙 엔진 (노드 없음). 상태 = Dictionary, 키 이름은 JS와 동일(camelCase) → 세이브/로그 호환
engine/rng.gd         32비트 mulberry32를 JS와 비트 단위로 재현 (|0, >>>, Math.imul 에뮬레이션)
engine/util.gd        normalize(JSON float→int), canonical(키 정렬 JSON 비교)
ai/ai.gd              규칙 기반 AI (EASY/NORMAL, 3가지 성향), 공개 뷰만 읽음
controller/match_controller.gd   UI ↔ 엔진 사이 액션 계층. AI 차례를 자동 진행하고 사람 입력에서 멈춤
tests/run_tests.gd    테스트 러너
tests/golden/         JS 엔진이 만든 정답 로그 52판 (3~8인 × EASY/NORMAL) + RNG 벡터
tools/js/             레퍼런스 JS(engine/ai/controller)와 정답 로그 생성 스크립트
```

## UI에서 쓰는 법 (docs/07 §8: UI는 결과를 결정하지 않는다)

```gdscript
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")

var state = Eng.create_game({"playerCount": 4, "seed": 123, "humanPlayerId": "P1", "aiDifficulty": "NORMAL"})
var ctl = Ctl.new(state)
var pending = ctl.run()                       # AI가 둘 수 있는 만큼 진행, 사람이 할 일을 돌려줌 (없으면 null)
# pending["type"] ∈ PLACE_EXTRA_MONEY | SELECT_CARD | MAKE_PROPOSAL | RESPOND
var r = ctl.submit({"type": "SELECT_CARD", "playerId": "P1", "cardId": card_id})   # {ok, pending, error}
for ev in ctl.drain_events():                 # 엔진이 이미 확정한 사건들 → 연출만 재생
    await board.play(ev)
var view = Eng.get_public_view(state, "P1")   # 화면에 그릴 때 읽는 공개 정보
```

액션: `PLACE_EXTRA_MONEY{playerId,barId}`, `SELECT_CARD{playerId,cardId}`, `MAKE_PROPOSAL{playerId,allocations}`, `RESPOND{playerId,response:"ACCEPT"|"DUEL"}`.
잘못된 액션은 예외가 아니라 `{ok:false, error:{category,message}}`로 돌아오고 상태는 바뀌지 않습니다.
저장: `Eng.serialize_game(state)` / `Eng.load_game(text)`. JSON은 숫자를 전부 float로 읽으므로 `load_game`이 `Util.normalize`로 정수를 복원합니다.

## 검증 내용

| 섹션 | 내용 |
|---|---|
| 1 | RNG: 시드 10개 × 64샘플이 JS와 정확히 일치 (2³¹ 이상 시드 포함) |
| 2 | 정답 로그의 액션을 엔진에 재생 → 이벤트 로그/최종 요약이 52판 모두 동일, 매 액션 뒤 불변식(INV-001~005) 확인 |
| 3 | 시드만으로 AI+컨트롤러를 돌려 → AI가 고른 카드·제안·응답과 이벤트가 52판 모두 동일 |
| 4 | 중간 저장→불러오기→끝까지 진행해도 정답 로그와 동일, 잘못된 세이브 버전 거부 |
| 5 | 규칙서 기준 시나리오(JS와 무관하게 손으로 만든 상황): RULE-011/012/013/014/017/018/019/020/021/022, 세팅(029/030/031), 최종 동점 |
| 6 | 잘못된 액션 거부, 공개 뷰/이벤트에 숨은 카드 미노출, AI 안티치트(사람의 숨은 선택을 바꿔도 AI 결정 동일), 추가 AI 180판 |

정답 로그가 지나가는 분기: 2/3/4/5인 협상, DEAL·DUEL·ONE_REJECTS·BOTH_REJECT·TOURNAMENT 전부, 동점 결투 44회, 같은 눈금 우선권 동점 27회, 덱 재활용 68회, 3인 마지막 라운드 2장 분배.
일부러 버그 12종(정수 나눗셈, 동점 처리, RNG 상수, 토너먼트 순서, 숨은 정보 누출 등)을 넣어 모두 테스트가 잡는 것을 확인했습니다.

## 이식할 때 주의한 점 (같은 함정을 UI 쪽에서 피하세요)

- GDScript `int / int`는 정수 나눗셈 → AI의 모든 나눗셈은 `float`로 계산.
- `Math.round`는 반올림(half up), GDScript `round()`는 half away → `floor(x + 0.5)` 사용.
- JS `Array.sort`는 안정 정렬, `sort_custom`은 불안정 → 최종 순위는 삽입 정렬, AI의 "최대값 찾기"는 첫 번째 최대 선택.
- JS 객체의 정수형 키는 오름차순으로 순회됨 → 금액 카드 생성 순서(섞기 결과에 영향)를 상수로 고정.
- `randi()`/`randf()` 금지. 난수는 전부 `Rng` 경유(시드 재현·리플레이·버그 신고용).
- 예외가 없으므로 엔진 내부 불변식 파괴는 `state["fatal"]`에 기록되고 액션이 `STATE_ERROR`로 거부됩니다.

## 문서와 코드 사이에 남아 있는 불일치 (문서 07 "충돌하면 멈추고 보고")

1. **RULE-021(4인 이상)**: `02_RULEBOOK.md`와 JS 엔진은 토너먼트로 구현돼 있는데, `03_GAME_FLOW.md` §14와 `08_ASSUMPTIONS.md`는 아직 "미검증, UnsupportedRuleError"라고 적혀 있습니다. 엔진 주석이 가리키는 `ASSUMPTION-021-*`(특히 동점 심볼 도전 순서 `ASSUMPTION-021-ORDER`)도 08에 없습니다. → 03/08 갱신 + CHANGELOG 기록 필요.
2. **ASSUMPTION-019**: 02는 이미 딴 돈으로 지급 가능, 03은 총액이 상금을 넘지 못함. 코드는 더 엄격하게 "합계 = 상금"만 허용합니다 (이식도 동일하게 유지).
3. 08의 가정들(카드 눈금 분포, 3인전 총 15라운드 등)은 실물 규칙서로 아직 확인되지 않았습니다. 확정되면 JS를 고치고 `tools/regenerate_golden.sh`로 정답 로그를 다시 만든 뒤 Godot 테스트를 돌리세요.

## 다음 단계

UI(보드 가로/세로 레이아웃, 카드/바 컴포넌트, 이벤트 재생 큐, 협상·결투·RAZZIA 연출)는 이 컨트롤러 위에 얹습니다. 엔진 쪽은 건드릴 필요가 없습니다.


## UI (board screen)

`godot --path .` opens the menu (`ui/main.tscn`): player count 3-8, AI difficulty, animation speed, reduced motion, CONTINUE (autosave).
Landscape (1280x720 base) = table mode, portrait (720x1280 base) = comfortable mode; `ui/main.gd` switches `content_scale_size` by window orientation.

- `ui/game_screen.gd` board; replays engine events as animation, never decides outcomes (controller runs the AI).
- `ui/nego_panel.gd` negotiation / duel panel, `ui/card_view.gd`, `ui/bar_view.gd`, `ui/widgets.gd` custom-drawn components (placeholder procedural art, no image assets).
- Fonts in `assets/fonts` (Cinzel, Playfair Display, Rye, Noto Sans KR; SIL OFL, see OFL-*.txt).
- Bot-driven UI smoke test: `godot --headless --path . --script res://tests/ui_smoke.gd -- players=4 seed=7`
  (add `shots=<dir> w=1280 h=720` under xvfb with `--rendering-driver opengl3` for screenshots).

### UI tests
- `tests/ui_smoke.gd` bot plays a full game through the board (hidden-info + invariant checks).
- `tests/ui_input_test.gd` plays a full game with keyboard/gamepad actions only (`ui_left/right`, `ui_accept`, `ui_cancel`).
- Controls: ←/→ (D-pad) move focus (cream ring), Accept selects (gold ring), Accept again plays, Cancel deselects;
  extra-money phase: ←/→ choose bar, Accept places.

### Art (assets/art)
- `bars/<BAR_ID>.jpg` venue posters (card art window on the board, icon plate in portrait rows).
- `cards/zocker_<BAR_ID>.jpg` gambler portraits, `cards/razzia.jpg` police portrait (hand cards). Jazz House has no own gambler
  portrait yet: it uses a crop of its poster. Drop a replacement file with the same name to swap art; if a file is missing the
  procedural drawing is used automatically (`ui/tokens.gd: art()`).

### Layout policy
- Landscape (table mode): left info rail (round, deck, table money, every opponent always visible, my money), venues in the centre,
  my hand ~27% of the height with the PLAY button right beside it. Content block is capped at ~2.05:1 and centred (ultrawide).
- Portrait (comfortable mode): stacked venue rows, opponents behind a dropdown, full-width PLAY button under the hand.

### Card animation system (ui/game_screen.gd, ui/card_view.gd)
- Hand = fan (`_hand_target` computes position/rotation/lift, `_layout_hand` tweens towards it): hover / selection / keyboard focus lift
  and straighten the card and draw it in front; removing a card closes the fan smoothly.
- Deal: cards spin / scale in from the deck corner with a stagger. Submit: my card leaves the hand, flies to my table slot, flips face-down
  and bumps on landing. Reveal: simultaneous flip, then flight into the venue, venue pulse. Score: floating "+$", chip/venue pop.
- The engine decides everything; animations only replay events. Skip button / tap, and "reduce motion" (Settings) collapse every tween.


## Balatro reference round (felt / lift / hint)
- `ui/felt.gdshader`: original felt cloth shader. State tint (RAZZIA blue, negotiation amber, game end gold) is tweened from `game_screen._set_felt`; static under reduce-motion.
- `CardView.lift`: shadow depth tweened together with the hand fan.
- Contextual card hint in the narration line (hover / focus / selection), worded after the engine rules.
- Classification table: `docs/balatro_reference.md`.

## UI phase 2 (core play screen)
- Text policy (`tokens.gd`): `T.fs()` raises small text so it is never below 11 real px on screen (bounded growth; texts shrink back to fit their box). `T.screen_scale` is set by the game screen on resize.
- Landscape: hand keeps a bottom safe margin (fan dip + rotation), submission row scales with screen height, empty landing zones under each venue, hint line clear of lifted cards.
- Portrait: submission cards sized to the row (up to 84u), name tag drawn inside the card, wider top chips, skip button moved to the hint row.
- PLAY button shows PICK A CARD (disabled) / PLAY CARD (enabled). `ui_input_test.gd shots=DIR` also writes state_hover / state_focus / state_selected / state_cancelled.
- Screenshot sheet: `docs/phase2_resolutions.png`.

## UI phase 3 (deck pile, money flight, PLAY states)
- `W.PileView` (widgets.gd): the money deck as a stack of card backs in the table area (landscape); count = real deck size from the display model. Portrait keeps the MONEY DECK stat.
- `_fly_money_card`: a face-down card flies deck -> venue on every MONEY_PLACED event (skipped by SKIP / reduce motion).
- Hand cards come from the player's own supply (not the money deck), so the deal-in starts at the player's chip.
- PLAY button: PICK A CARD (disabled) / PLAY CARD (enabled) / PLAYED (processing, no double submit).
- Tests: `ui_smoke.gd flight=1 shots=DIR` writes money_flight.png; tablet sizes 1024x768 and 768x1024 are covered. Sheet: `docs/phase3_resolutions.png`.

## UI phase 4 (no tray panel)
- The brown tray band behind the hand and the dark table panel in portrait are no longer drawn: the felt shader fills the whole screen and the hand lies directly on it. The hint line has a dark outline instead of a panel; PLAY CARD / SKIP are free-standing buttons (disabled PLAY is translucent).
- Before/after sheet for 7 sizes: `docs/phase4_before_after.png`.

## UI phase 4 — structural redesign of the play screen (layout B, "card-centred")
Two layouts were compared on paper first (`docs/phase4_layout_sketches.png`, schematic only):
A "table-centred" (posters + landing slots + row as table areas) vs B "card-centred" (no landing slots, bigger row and hand).
B was implemented: the empty landing rectangles under the venues are gone (played cards land on the lower poster),
posters grow to ~37 % of the height, the submission row is ~19 % with large face cards, the hand ~29 %, and the deck pile
sits at the end of the submission row. Rules, engine, AI, input, card flight and save are untouched.
Before/after: `docs/phase4_before_after.png` (same game state: 5 players, seed 5).

## UI phase 5 — portrait layout + readable revealed cards
- Portrait now uses the same venue cards as landscape in a poster grid (3x2, or 6x1 / 2x3 if it scores bigger); the old list rows are no longer used.
- Cards lying on a poster use a new "poster face" (`CardView.art_mini`): art + ZOCKER/RAZZIA + die + player name. They are placed in a
  2-column grid that never overlaps (3 columns only for >6 cards on one bar) and grows as large as the poster allows.
- Root cause of the old overlap: every card flying to the same bar targeted the same slot. `BarView.expected` + `slot_global_rect(i, total)` now
  give every card its final slot before the flight starts.
- Tablet hand width capped at 140u so the hand does not eat the posters. Before/after: `docs/phase5_before_after.png`.

## UI phase 6 — play flow polish
- Negotiation / duel panel: portrait docks it under the venue grid (no dim, venues stay visible); landscape parks it on the side away from the
  target venue, which is lifted above the dim. (`NegoPanel.dock_limit_y / side`, `GameScreen._ev_negotiation_started`)
- Tapping / clicking the selected hand card again deselects it (same as Esc); submit is still single-shot (button disabled + `_awaiting_select`).
- Settlement: every award is announced in the hint line ("Vito +$55,000 <- JAZZ HOUSE"), floats over the venue and the visible player chip;
  with reduced motion the amount stays for 1.2 s without moving. The round board shows my before -> after and the venues I won from.
- All of it is display only (engine events replayed as before); reduce-motion run and normal run produce identical event logs.
Before/after: `docs/phase6_nego_before_after.png`.

## UI phase 6 (approved implementation: 6A-6D)
- 6A: buttons get a 4 % press squash (skipped with reduced motion); selected card toggles off on a second tap.
- 6B: the negotiation / duel panel slides up from below (0.25 s) and slides out (0.18 s); both are visual only (`NegoPanel._present`),
  the engine flow never awaits them. Portrait: always docked under the venue grid. Landscape: docked under the venue row (compact one-line
  header) when the text would stay >= 70 % of its designed size, otherwise parked at the side away from the target venue (phone landscape).
  The target venue is lit above the dim, the hint line shows "협상 · VENUE $prize".
- 6C: round board = venue lines (who got what, and why: from MONEY_AWARDED / BAR_RESOLVED), per-player gain + total (counted up), my before -> after.
  ~1.2 s, a press or tap finishes it at once, reduced motion / skip show everything immediately, numbers always land on the engine values.
  `GameScreen.settle_mismatch` cross-checks the venue lines against ROUND_ENDED; `ui_smoke` fails if it is not 0.
- 6D: RAZZIA wash: exactly one red and one blue flash (was two each).

## UI Phase 7 — 게임 흐름 통합
- 단독 도박꾼/RAZZIA 단독 청구 결과 문구 중복 덮어쓰기 제거 (한 줄로 병합).
- 협상/결투: 대상 술집을 먼저 강조(0.25초) 후 패널 등장. 협상 보상은 패널 상태줄에 표기.
- RAZZIA: 화면 암전 완화, 단속 대상 술집을 암전 위로 올림 (붉은/푸른 플래시 각 1회 유지).
- 정산 보드: T.fs 기반 글자 크기, 가로 화면 2열(술집·이유 | 플레이어 잔액), 세로 화면 1열.
- 검증: 엔진 109, 자동플레이 6, 키보드 3, 모션 줄이기 해시 동일. 실제 기기는 미검증.

## UI Phase 8A — 규칙 안내·입력·이어하기 안정화
- 규칙 안내: 메뉴 도움말과 RAZZIA 카드 힌트를 RULE-013/014/015 및 엔진(`_resolve_bar`)에 맞춤 — RAZZIA 1장 이상 + 도박꾼 1장 이상이면 단속, 도박꾼은 쫓겨나고 RAZZIA를 낸 사람이 돈을 가져감(여럿이면 그들끼리 협상), 도박꾼 없이 RAZZIA만 있으면 돈은 남음.
- `skip`은 이벤트 재생 중(SKIP 버튼이 보일 때)에만 켜짐. 카드/바/협상 응답을 고르는 중의 빈 곳 탭(터치·마우스)이 다음 재생에 남지 않음. `_play_events`는 시작 시 `skip=false`.
- 이어하기: `begin()`이 `_relayout()` 이후에 화면을 복원함(이전: 치수표가 비어 오류 3건, 안내 라벨이 폭 0에서 높이 459로 커짐). 베뉴 위 머니카드 개수는 엔진 이벤트 로그로 복원(이전: 추정값).
- 추가 머니카드 단계 버튼: "PICK A BAR"(선택 중) / "PLACED"(이후). 이전엔 "PLAYED".
- (해결됨: Phase 8A-1) 카드를 낸 뒤 나가서 이어하기를 하면 제출 이전으로 돌아가 카드를 다시 고를 수 있던 문제 — 아래 8A-1 섹션 참고.

### 새 테스트 (프로젝트 루트에서)
```bash
godot --headless --path . --script res://tests/ui_touch_skip_test.gd -- seed=5 [w=1280 h=720]   # 터치/마우스 skip 잔류 + 중복 제출
godot --headless --path . --script res://tests/ui_resume_test.gd -- w=1280 h=720               # 이어하기 5+1 시나리오, w/h: 430x932, 844x390 ...
```
출력에 `SCRIPT ERROR`가 없는지도 확인할 것(GDScript에서 잡을 수 없음): `... 2>&1 | grep -E "TEST:|SCRIPT ERROR"`.

## UI Phase 8A-1 — 카드 제출 후 저장/이어하기
- 문제: 자동저장이 "카드를 물어보는 순간"에만 써져서, 카드를 낸 뒤 나가서 이어하기를 하면 제출 전 상태로 돌아가 카드를 바꿀 수 있었음(AI 선택은 동일).
- 저장 파일 `{version, gameState, aiRngState, actions?}` — `version`은 그대로(1). `actions`는 선택 필드: 체크포인트 이후 엔진이 받아들인 사람의 행동(카드/추가 머니/제안/응답) 목록. 없으면 `[]`(이전 파일 그대로 읽힘, 이전 앱이 새 파일을 읽어도 추가 필드는 무시).
- 이어하기: 체크포인트 화면을 복원한 뒤 `SaveStore.replay()`가 기록된 행동을 컨트롤러에 다시 적용하고, 보드는 그 이벤트를 평소처럼 재생. 이미 낸 카드·제안·응답은 다시 묻지 않음. AI 시드가 저장돼 있어 결과가 동일.
- 쓰기는 임시 파일 → 이름 교체(원자적). 읽을 수 없는 파일은 삭제하지 않고 `autosave.corrupt.<시각>.json`으로 보관. 잘못된 `actions`는 버리고 체크포인트부터 이어감.
- 테스트: `tests/save_resume_test.gd`(엔진 수준: 모든 중단 지점에서 저장→복원→끝까지 진행 후 무중단 결과와 전체 상태·이벤트 기록 비교, 옛 파일 `tests/fixtures/autosave_v1_before_8a1.json`, 손상 필드, 반복 로드), `tests/ui_resume_test.gd` 시나리오 3(실제 GameScreen).
```bash
godot --headless --path . --script res://tests/save_resume_test.gd                  # PASS 기대 (손상 JSON 입력 시 "Parse JSON failed" 로그는 정상)
godot --headless --path . --script res://tests/save_resume_test.gd -- norecord=1    # 음성 대조: 옛 방식이면 FAIL 해야 함
```

## UI Phase 8B-2 — RAZZIA SKIP 수정 + FAST 일관성
- P1: `_fx_razzia`가 SKIP/탭에 즉시 반응함. 이전엔 고정 `create_timer(2.5s)`를 끝까지 기다려 SKIP을 눌러도 최대 2.75초 남았음. 이제 대기를 프레임 루프로 바꿔 skip이면 즉시 끝내고, 아직 도는 트윈(사이렌/도장)을 kill한 뒤 오버레이를 제거함(페이드 중 skip 포함). skip 없는 NORMAL 타이밍은 그대로(2.75초 → 측정 2.78초, 프레임 양자화 2프레임).
- P2: 라운드 결과 보드의 상수 트윈(0.25/0.2/0.14/0.45초, 단계 간격)과 RAZZIA의 와시 페이드·도장·유지·페이드를 `Settings.dur()`로 통일(NORMAL=×1.0 동일, FAST=×0.5). 사이렌 점멸(빨강 1회·파랑 1회, 각 0.12초)은 광과민 규칙 때문에 어떤 속도에서도 길이를 줄이지 않음 — 그래서 FAST의 RAZZIA는 절반이 아님(2.1초 → 1.75초). `_float_text`는 이미 `Settings.dur`를 쓰고 있었고(고정 1.2초 타이머는 모션 줄이기 경로 전용 정책), 변경하지 않음.
- 새 테스트: `godot --headless --fixed-fps 60 --path . --script res://tests/ui_razzia_skip_test.gd` (A: fx 단독 시나리오, B: 전체 게임 + skip 스케줄. `--fixed-fps 60`을 붙여야 가상 시계가 정확하고 몇 초 만에 끝남). `SCRIPT ERROR` grep 필수.

## UI Phase 8B-4 — 라운드 시작 연출 압축 (P6)
- `ROUND_STARTED` 배너 대기 0.5초 → 0.25초, 머니카드 순차 간격 0.16초 → 0.10초(추가 머니카드의 0.6초는 그대로). 비행 트윈(0.32초)은 그대로이고 모두 `Settings.dur()`를 거치므로 FAST/SLOW 배율은 일관, 모션 줄이기는 기존대로 0.
- 안전장치: 머니카드가 날아가는 중이면 `_play_events` 끝에서 `_settle_money_flights()`가 착지를 기다린 뒤에 사람에게 카드를 묻는다(최대 `dur(0.6)`초, skip이면 즉시). 대부분의 라운드는 AI 카드 선택 이벤트가 뒤따라 대기 시간이 0이고, 추가 머니카드 직후처럼 비행이 남은 경우에만 최대 약 0.28초 기다린다.
- 새 테스트: `godot --headless --fixed-fps 60 --path . --script res://tests/ui_round_start_test.gd` (4·8인 × NORMAL/FAST/SLOW/모션 줄이기 전체 게임; 모든 카드 프롬프트에서 비행 카드 없음·덱/술집 금액/머니카드 더미가 엔진과 일치, 이벤트 시퀀스 동일).

## UI Phase 8B-5 — 카드 착지 펄스 FAST 일관성 + 마우스 클릭 막힘 수정
- 펄스: `_ev_cards_revealed`의 `fl[2].pulse(0.5)` → `pulse(Settings.dur(0.5))`. NORMAL 동일(측정 0.483초 = 30프레임), FAST 0.233초, SLOW 0.783초. 모션 줄이기에서는 측정상 착지 펄스 없음(이전과 동일).
- 마우스(실제 사용 중 발견): Godot의 GUI 피킹은 `z_index`가 아니라 **트리 순서**를 따른다. 화면에 "보여주기만" 하는 카드(협상/결과 보드 동안의 손패 등, `interactive=false`)가 `mouse_filter=PASS`라서 뒤에 있는 협상 버튼(−20k/−5k/+5k/+20k/SUGGESTED/MAKE OFFER/ACCEPT/CALL DUEL/ROLL THE DIE)과 NEXT ROUND 버튼의 일부 영역 클릭을 가로챘음. 이제 `interactive=false` 카드는 `MOUSE_FILTER_IGNORE`(고를 수 있는 카드만 PASS).
- 마우스: 손패 카드에 올리면 카드가 12~22px 떠오르는데, 포인터가 카드 아래쪽 가장자리에 있으면 떠오른 카드 밖으로 밀려나 hover가 끊기고(내려갔다 다시 올라오는 떨림) 클릭이 유실됐음. 떠오른 카드는 원래 자리 아래 띠(`hit_extend`)까지 히트 영역에 포함.
- 새 테스트: `godot --headless --fixed-fps 60 --path . --script res://tests/ui_mouse_hit_test.gd [-- w=430 h=932]` (실제 `InputEventMouseMotion`을 주입해 뷰포트가 보고하는 "포인터 아래 컨트롤"이 기대한 컨트롤인지 검사 + 카드 아래 가장자리 실제 클릭).

## UI Phase 9A — 사운드 적용
- 파일(`assets/audio/`): `noir_jazz_loop.ogg`(배경음악, 원본 WAV 16MB를 OGG로 변환해 1.1MB, 런타임에 `loop=true`), `click.mp3`, `taking_card.mp3`, `rolling_dice.mp3`, `cashier_ching.mp3`, `police_siren.mp3`.
- `ui/audio.gd`: 정적 진입점(`Audio.play/start_music/siren_start/siren_stop`)이 SceneTree 루트에 호스트 노드 하나를 지연 생성 → 메뉴↔게임 사이에도 음악이 끊기지 않음. 스트림이 없거나 호스트를 못 만들면 아무 일도 하지 않음(테스트/미임포트 안전). 엔진/컨트롤러/이벤트는 변경 없음.
- 연결: 모든 버튼·손패 선택·술집 선택 = click / 손패 지급·카드 제출·공개·착지 = take(0.07초 간격 제한) / DICE_ROLLED = dice / 내가 돈을 받을 때(MONEY_AWARDED) = ching / RAZZIA 연출 = siren(연출 시작에 재생, 끝·SKIP에서 페이드아웃, 재생 중 음악 볼륨 낮춤; SKIP·모션 줄이기로 연출을 건너뛰면 재생 안 함). 사이렌 음향은 화면 점멸 규칙과 무관하며 점멸은 그대로.
- 설정: 메뉴의 "배경음악 ON/OFF", "효과음 ON/OFF"(`user://settings.cfg`의 `[audio]`). 애니메이션 속도·모션 줄이기는 소리에 영향 없음.
- 새 임포트가 필요하므로 에디터로 한 번 열거나 `godot --headless --path . --import`를 실행할 것. 테스트: `godot --headless --fixed-fps 60 --path . --script res://tests/ui_audio_test.gd` (더미 오디오 드라이버: 연결만 검증, 실제 음질/음량은 검증 불가).

## UI Phase 8B-6 (P7) — RAZZIA 연출 압축
- 사이렌 점멸은 그대로(빨강 1회 + 파랑 1회, 각 0.12초, 어떤 속도에서도 단축 없음). 도장 등장 시점 `1.0초 → 0.72초`(사이렌 종료 0.66초 직후), 유지 시간 `2.5초 → 2.0초`. 도장이 최소 0.5초는 읽히도록 유지 시간 하한(`도장 시점 + 0.22 + 0.5초`)을 둠 → FAST는 이전과 사실상 같은 길이.
- 측정(가상 시계, 중단 없음): NORMAL 2.78초 → 2.28초, SLOW 4.4초대 → 3.63초, FAST 1.39초 → 1.42초(변화 없음에 가까움). SKIP은 즉시 종료(0.02초 이내) 그대로. `ui_razzia_skip_test`의 기대 범위를 새 길이로 갱신.

## UI Phase 9B — 게임 중 소리 설정 + 사운드 확장
- 인게임 메뉴(⎋ 버튼)에 "배경음악 / 효과음" 줄 추가: ON/OFF 토글 + 음량 슬라이더(0~1, 1.0 = 기존 음량). 즉시 반영·저장(`user://settings.cfg [audio] music_vol / sfx_vol`). **M 키** = 음악+효과음 전체 음소거/해제. 메뉴 화면은 ON/OFF만(음량은 게임 중).
- 새 큐(직접 합성한 임시 음원, 같은 이름 파일로 교체 가능): `offer.ogg`(제안), `accept.ogg`(수락), `duel.ogg`(결투 선언), `round_end.ogg`(라운드 종료), `game_end.ogg`(게임 종료). 연결: PROPOSAL_MADE / PROPOSAL_ACCEPTED / DUEL_CALLED / ROUND_ENDED / GAME_ENDED. 재생 간격 제한 있음(SKIP 중 연타 방지).
- 테스트: `ui_audio_test`가 44개로 확장(음량 스케일·0일 때 무음, 새 큐가 한 판에서 호출되는지, 인게임 메뉴의 토글/슬라이더를 실제 마우스 클릭으로 조작, M 키).

## UI Phase 9C — 카드 선택/돈 받기 소리 + 추가 큐
- 카드 선택: 손패에 포인터를 올리거나 키보드/패드로 포커스를 옮기면 `hover`(짧은 틱), 카드를 고르면 `pick`(카드 튕기는 소리), 다시 눌러 취소하면 기존 `click`. 내 차례가 되면 `your_turn`(부드러운 핑).
- 돈 받기: 내가 받으면 `ching`(캐셔), **다른 사람이 받으면 `coin`(작은 동전 소리, 더 작은 음량)**. 라운드 시작 머니카드 배치에도 `coin`(0.09초 간격 제한).
- 추가 큐(직접 합성한 임시 음원, 같은 이름으로 교체 가능): `stamp`(RAZZIA 도장), `denied`(내 카드가 RAZZIA에 쫓겨날 때), `final_round`(마지막 라운드 공지), `shuffle`(덱 재셔플), `duel_win`/`duel_lose`(내가 참가한 결투 결과), `win`(내가 우승하면 `game_end` 대신).
- 테스트: `ui_audio_test` 59개(실제 마우스 hover/클릭이 hover/pick을 내는지, 다른 사람 지급 coin, 새 에셋 로드 등).

## UI Phase 10 — 메인 화면 · 게임 방법 · 협상 UX

- **메인 화면** (`ui/menu_screen.gd`): 술집 포스터 배경 + 타이틀, 이어하기/새 게임/게임 방법, 우측 "GAME SETUP" 카드(인원, AI 난이도, 속도, 모션 줄이기, 배경음악/효과음). 세로 화면은 스크롤 단일 컬럼.
- **게임 방법** (`ui/help_screen.gd`): 7페이지 일러스트 가이드(목표·라운드 흐름·카드 읽는 법·겹치면 협상·RAZZIA·협상과 결투·요약/팁). 메인 메뉴와 게임 중 ⎋ 패널에서 열 수 있고, ←/→/Esc 키 지원.
- **협상 패널** (`ui/nego_panel.gd`): 제안→응답→결투→정산 단계 표시, 제안 시 슬라이더 + 프리셋(추천/균등/내가 많이) + 상대별 결투 기대값 힌트(수락 가능성 색상), 응답 시 "지금 받기 vs 결투 기대값" 비교, 결투 화면에 승률 표시, 한국어 상태 문구.
- 엔진/AI/규칙/세이브 포맷은 변경 없음 (기대값은 `Eng.duel_win_probability` 읽기 전용 사용).

## UI Phase 11 — 사운드 믹스 업그레이드 (몰입감 · 방해 최소화)

- **음량 4그룹** (`ui/sound_panel.gd`, `ui/settings.gd`): 전체 / 배경음악 / 효과음 / 버튼 소리, 각각 슬라이더, 음악·효과음은 ON/OFF. "분위기" 프리셋(몰입 · 차분 · 효과음만), "창이 비활성이면 음소거" 옵션. 게임 중 ⎋ 패널에는 전체, 메인 메뉴에는 프리셋 + 전체 음량.
- **믹스** (`ui/audio.gd`): Music / SFX 버스 + 마스터 리미터(소리가 겹쳐도 깨지지 않음). 배경음악 기본 레벨을 낮추고 은은한 분위기음(룸 톤)을 함께 재생. 라운드 종료·승리·결투 결과 등 스팅어와 사이렌이 음악을 자동으로 낮춤(덕킹).
- **협상·결투 집중 효과**: 협상 패널이 열려 있는 동안 음악이 먹먹해지고(로우패스) 살짝 작아지며, 결투가 시작되면 느린 긴장 레이어가 서서히 들어옴. 닫히면 원래대로 복귀.
- **변주**: 동전 소리 4종 랜덤, 클릭/틱/카드 소리는 피치를 미세하게 흔들어 기계적인 반복감을 줄임.
- **새 소리 20여 종**: 토글 on/off, 슬라이더 틱, 패널 열기/닫기, 페이지 넘김, 확정, 카드 뒤집기, 카드 배분, 큰 금액 지급, 협상 시작, 단계 진행, 결투 드럼롤, 동점, 게임 시작, 긴장 루프, 분위기음 루프 (직접 합성, 스크립트는 저장소 밖).
- 테스트: `tests/ui_audio_test.gd` 93개 검사(그룹 음량, 마스터, 버스/리미터, 포커스 로우패스, 긴장 레이어, 변주, 프리셋/패널).
- 청각 품질(음색·믹스 밸런스)은 자동 테스트로 검증할 수 없습니다 — 실제 기기에서 들어 보고 조정이 필요할 수 있습니다.

## UI Phase 12 — Enter 입력 흐름 진단 · 보호 · 추적 로그

**증상(사용자 보고):** 카드를 고르고 Enter를 누르면 라운드가 바로 끝나는 것처럼 보임.

**진단 (실제 입력 이벤트로 재현, `tests/ui_enter_flow_test.gd`):**
- 확정된 카드 이후의 재생 순서(카드 공개 → 바 정산/RAZZIA → 돈 지급 → 라운드 결과판)는 Enter로 건너뛰어지지 않는다. Enter가 `skip` 플래그를 건드리는 경로는 없고, 트레이스에도 `skip` 변경이 한 번도 찍히지 않았다.
- **확인된 결함 1:** 라운드 결과판의 NEXT ROUND 버튼이 나타나자마자 키보드 포커스를 받아, 카드 제출 뒤에도 Enter를 계속 누르던 사용자의 입력이 결과판을 즉시 닫았다 (가드를 끄면 테스트가 실패함 — 음성 대조 확인).
- **확인된 결함 2:** 마우스로 카드를 고른 뒤 Enter를 누르면 선택한 카드를 확정하지 않고 "키보드 포커스가 있는 첫 카드"를 다시 선택했다.
- **결함 3 (Phase 10에서 내가 만든 것):** 협상 응답창에서 결투가 유리해 보이면 DUEL 버튼이 기본 포커스를 받아, Enter 한 번이 도박(결투)을 선언할 수 있었다.
- Git 이력/이전 백업이 없어 "문제 직전 커밋과의 비교"는 하지 못했다. 현재 코드의 호출 경로와 실행 결과만 근거로 삼았다.

**수정:**
- `ui/widgets.gd`: `W.arm_focus(button, secs)` — 프롬프트가 뜬 직후 `secs`초 동안은 버튼이 키보드/패드 포커스를 받지 못한다(마우스·터치는 항상 가능). 이후 포커스를 가져간다.
- 적용: 라운드 결과판(0.6 s), 게임 종료 화면, 협상의 제안/응답/굴리기(0.5 s). 응답창 기본 포커스는 항상 ACCEPT.
- `ui/game_screen.gd`: Enter = 선택된 카드가 있으면 그 카드를 확정, 없으면 포커스된 카드를 선택(한 번에 한 동작). 마우스로 고른 카드가 키보드 포커스도 가져간다.
- **상태 전환 로그** (`ui/flow_trace.gd`): 최근 500줄을 메모리에 보관(`RAZZIA_TRACE=1`이면 콘솔 + `user://flow_trace.log`에도 기록). 기록 대상: 키 입력(상태 플래그·포커스 소유자), 카드 선택/확정, `skip` 플래그 변경(호출 함수 포함), 이벤트 재생 시작/종료와 각 이벤트, 사용자에게 묻는 시점.

**테스트:** `tests/ui_enter_flow_test.gd` — mode `enter | hold | mash | mouse_enter | confirm_click`. Input 이벤트(키/마우스)를 실제 입력 경로로 주입해 카드 선택 → 확정 → 공개 → 정산 → 결과판 → 다음 라운드까지 확인하고, 연타 시 결과판·협상 프롬프트가 즉시 닫히지 않는지 검사.

**Phase 12b — 화면 녹화 분석 (모션 줄이기):** 녹화 두 개 모두 메뉴의 "모션 줄이기"가 ON이었고, 그 상태에서는 `Settings.dur()`가 0이라 카드 공개·바 정산 연출의 *대기 시간*까지 사라져, 카드를 내면 약 0.3초 만에 결과판이 떴다 (같은 조건으로 재현: 수정 전 0.3 s → 수정 후 3.1 s; 모션 줄이기 OFF는 9.3 s). 수정: `Settings.hold()` — 읽을 시간은 유지(모션 줄이기 시 ×0.55)하고 움직임/깜빡임만 제거. 메뉴에 설명 문구, 게임 중 ⎋ 메뉴에 모션 줄이기 스위치 추가. 테스트 갱신: `ui_round_start_test`(모션 줄이기는 짧지만 0이 아님), `ui_razzia_skip_test`(결과판 버튼을 포커스가 아닌 텍스트로 탐색), `ui_enter_flow_test rm=1`.

## Phase 13 — 요약·기록·AI 성격, 규칙 안내 개편, 결투 확인, 추가 머니카드 표시
- 게임 요약 화면(`ui/game_summary.gd`, `summary_screen.gd`), 기록/업적 13종(`ui/records.gd`, `records_screen.gd`, `user://records.json`), AI 성격 라벨(`ui/characters.gd`; 엔진의 CONSERVATIVE/AGGRESSIVE/OPPORTUNIST를 표시만 함, AI 로직 변경 없음).
- 규칙 안내 10개 주제로 개편. 카드의 점은 "주사위 눈"(별 ★ 아님)으로 용어 통일(협상/결투 화면 포함). 엔진·규칙서(RULE-008, 011–023)와 대조.
- 결투: 사람이 참여한 결투는 결과 화면(승/패 글자 + ▲▼, 점수 계산)이 "결과 확인 · 계속"을 누를 때까지 유지. SKIP은 사용자가 고른 경우만 건너뜀.
- 딜러의 추가 머니카드: "딜러 → 술집: 전 → +금액 → 후" 표시(MONEY_PLACED extra 이벤트 기준). 플레이어별 개인 기여/술집별 기여 내역은 엔진 데이터에 없어 표시하지 않음.
- 테스트: `records_test`(34), `rules_help_test`(12), `ui_duel_flow_test`(9, 시드 6·10).

## Phase 13b — AI 난이도·성격 정밀화
- 난이도 3단계: EASY / NORMAL / HARD(신규). `ai/ai.gd`의 DIFFICULTY 표에 HARD 추가, `riskMul/riskAdd`(기본값은 기존 동작 그대로) 추가. NORMAL·EASY의 동작은 바뀌지 않음.
- HARD는 노이즈 없음, 상대 모델 alpha 2.0, 수락 기준 정확(1.0), 위험 선호(riskAdd −0.3). 시뮬레이션(4인, 1명 대 NORMAL 3명, 3000판)에서 HARD 약 31% / NORMAL 약 23% / EASY 약 14% (공정 25%).
- 성격 말풍선: 제안·수락·결투·승패 대사(`ui/characters.gd`)를 협상 화면에 표시(사람에게는 없음, 이벤트 seq로 결정적). 협상 행에 성격 라벨.
- 성격별 결투 선언률(6인, 보통, 1500판): 신중 51% / 기회 69% / 공격 86% — 도움말 "AI 상대 소개"에 표시.
- `tools/ai_sim.gd`(시뮬레이터), `tests/ai_levels_test.gd`(8).

## Phase 13c — 초상화, 나가기 창 클릭 수정
- 버그 수정: "메뉴로 나갈까요?" 창이 손패 카드와 겹치는 부분에서 클릭/터치를 못 받던 문제. 원인: GUI 입력은 트리 순서를 따르는데 손패/상대 카드가 매 라운드 창보다 뒤에 생성됨. 해결: 카드를 오버레이(dim/협상/모달) 아래에 추가(`_add_below_overlays`). 테스트 `tests/ui_exit_menu_test.gd`(마우스·터치·나가기, 4개 해상도).
- 초상화: `ui/portrait.gd`. 이름별 그림 `assets/characters/<이름>.png`(Vito, Lola, Mack, Dutch, Rosie, Sal, Nico — 사용자가 준 시안에서 잘라냄)이 있으면 사용, 없으면 성격별 임시 그림(`<성격>.png` 또는 코드 드로잉). 테두리 색 = 성격(파랑 신중 / 금색 기회 / 빨강 공격). 플레이어 칩, 협상 행·말풍선, 요약 표, 도움말에 표시.

## Phase 14 — 대화 장면(컷신)
- `ui/dialogue_scene.gd`: 양쪽 초상화 + 이름표 + 대사창. Enter/Space/클릭/터치 = 다음(첫 입력은 글자 타이핑을 끝냄), SKIP/Esc = 나가기. 장면/줄이 뜬 뒤 15프레임은 입력 무시(실수 입력 방지). 모션 줄이기: 타이핑·깜빡임 없음.
- 나오는 때: 게임 시작(AI 소개 2줄), 마지막 라운드 직전, 큰 결투(판돈 ≥ $50,000, 사람 참여, 게임당 최대 2번·연속 라운드 금지), 게임 종료. AI 자리가 없거나 봇 플레이·SKIP 중이면 나오지 않음.
- 설정: "대화 장면 ON/OFF" (메뉴, 게임 중 나가기 창). 저장됨.
- 대사: `ui/characters.gd`의 SCENE_LINES(성격별), 결정적 선택. 이미지: 지금은 `assets/characters_full`(큰 컷) 사용, 같은 이름으로 교체 가능.
- 테스트: `tests/ui_dialogue_test.gd`(19).

### Phase 14b: 소리 정리
- `ui/audio.gd`의 `MUTED` 목록으로 방해되는 효과음 14종을 껐습니다 (hover, tick, toggle, panel_open/close, page, stage, drumroll, your_turn, pick, nego_open, game_start, cash_big). 되살리려면 목록에서 지우면 됩니다.
- 초상화 성격 색 링 제거(골드/브론즈 통일), 대화창 에메랄드·차콜·골드 톤.

### Phase 14c: 결투 주사위 연출
- `DieView`: 회전·튕김·그림자·착지 squash, 대기 중 "?" 숨쉬기, 승자 글로우 펄스, 패자 어둡게. `tumble()/land()` (모션 줄이기·스킵이면 즉시 착지).
- 결투 패널: 걸린 돈 표시(제안 합계, 실제 데이터일 때만), 주사위 A→B 순서로 착지, 점수 팝, 승자 배너 팝인.

### Phase 14d: 결투 무대
- 결투가 시작되면 협상 패널이 가운데 "무대"로 바뀝니다: 제안 행/헤더는 숨기고, 초상화(나는 금색 모노그램), 큰 주사위, 걸린 돈, 점수, 승자 배너. 테이블은 어둡게. 작은 화면은 컴팩트 크기.
- 제안/응답/수락 단계는 기존 도킹 패널 그대로. 결과 확인 버튼을 눌러야 넘어가는 동작도 그대로.

### Phase 14e: 협상 응답 카드
- 응답 화면: 수락/결투가 큰 선택 카드 자체가 버튼(수락=확실한 금액, 결투=승률·이기면/지면·기대값, 유리한 쪽에 태그).
- 결투 무대: 큰 주사위, 승자 "+획득금", 패자 "$0", 굴리기 버튼 펄스.

### Phase 14f: 협상/결투 비주얼 개편
- 협상 패널: 클럽 포스터 배너 + 큰 금액, 아르데코 금색 모서리, 플레이어 색 띠가 있는 좌석 카드(큰 초상화, 주사위 눈 아이콘, 큰 금액, 수락/결투 알약).
- 결투 무대: 에메랄드 펠트 테이블, POT 명판, 플레이어별 카드(승자 금빛 강조, 패자 어둡게).

### Phase 14g: 결투 단계 관리와 반응
- `NegoPanel.DuelPhase`: INTRO → ROLLING → REVEAL → SETTLEMENT → REACTION → WAITING → DONE. 중복 DICE_ROLLED / DUEL_RESOLVED / 확인 프롬프트는 무시(토큰으로 오래된 트윈도 무시).
- 정산: 승자 금액 카운트업 + POT 명판 비움, 승자 카드 강조 / 패자 카드 물러남, 역전승(승률 30% 미만)·큰 판돈(4만 이상) 문구와 번쩍임(모션 줄이기면 생략).
- 반응 대사: 승자·패자 각자 카드 안에 한 줄. `Characters.line_for(이름, 성격, 상황)` — 이름별 대사(BY_NAME)가 성격 대사보다 우선, `win_upset/win_big/lose_big` 상황 추가.
- 테스트: tests/ui_duel_stage_test.gd (25).

### Phase 14h: 협상 선택 입력과 캐릭터 대사
- 응답 카드(수락/결투): 첫 입력으로 두 카드가 잠기고(중복 입력 무시), 선택한 쪽이 켜지며 짧게 보여준 뒤 진행. 좌우/D-pad로 이동, Enter/A로 확정. 기대값 문구는 엔진 확률 계산에서 엄격히 높을 때만 붙음(동률이면 없음).
- 게임패드: 이 환경의 기본 InputMap에 ui_accept의 A 버튼이 없어 `W.ensure_pad_bindings()`로 A=확인, B=취소를 보강(NegoPanel 생성 시).
- 캐릭터별 제안/수락/결투 대사(`Characters.BY_NAME`), 협상 말풍선이 `line_for` 사용.
- 테스트: tests/ui_nego_choice_test.gd (19).

### Phase 15: QA 플레이 테스트 (실행 검증)
실제 진입 씬(`ui/main.tscn`)을 띄우고 마우스·터치·키 입력만으로 한 판을 끝까지 플레이하는 QA 테스트를 추가했습니다. 모두 입력으로만 진행하며(게임 메서드 직접 호출 없음), 진행 멈춤·자동 진행·중복 처리·정산 불일치를 감시합니다.
- `tests/qa_playthrough_test.gd` — 메뉴 → 새 게임 → 라운드(카드/추가 돈/협상/결투/컷신) → 게임 종료 → 요약 → 메뉴 → 재시작. 1280x720 / 430x932 / 844x390 / 1920x1080 / 2560x1080 PASS.
- `tests/qa_resume_test.gd` — 플레이 중 Esc → 나가기 → 메뉴 CONTINUE → 같은 게임(시드·라운드·소지금) 복원 후 계속 플레이. 저장 파일은 프로세스별 경로로 분리.
- `tests/qa_stability_test.gd` — 메뉴↔게임 10회 왕복 후 노드/고아 노드 증가 없음(87 → 87, orphans 0).

수정한 문제
- P2 `FINAL ROUND` 금색 배지가 "ON THE TABLE" 금액을 가림(가로·세로 모두) → 배지를 없애고 ROUND 박스 자체를 "FINAL ROUND 12" + 금색 강조로 바꿈 (`_refresh`).
- P2 Esc(안드로이드 뒤로 가기, 패드 B)로 게임 중 메뉴를 열 수 없었음 → `ui_cancel`로 나가기 패널 열기/닫기. 컷신·도움말·요약·라운드 결과·협상 중에는 동작하지 않음(`_overlay_open`), 카드 선택 중이면 기존처럼 선택 해제 우선.
- P3 좁은 화면에서 "RAZZIA에 쫓겨남"이 단어 중간에서 줄바꿈 → "RAZZIA 단속 시 쫓겨남".
- P3 플레이어 칩: DEALER 알약이 테두리에 붙고, 좁은 칩에서 금액이 ✓와 겹침 → 알약 여백 확보, 이름은 알약만큼 폭 양보, 금액은 잘리지 않고 글자 크기를 줄여 항상 전체 표시.

### Phase 16: 적응형 사운드 믹스
연주되는 음악은 그대로 두고, **언제 얼마나 물러나는지**를 상황에 맞게 바꿨습니다 (`ui/audio.gd`).
- `Audio.thinking(on)` — 내가 카드를 고르거나 추가 머니카드를 놓을 때: 음악 −5 dB, 저역만 남기고(3.2 kHz) 방 소리도 −4 dB. 생각하는 동안 테이블이 조용해집니다.
- `Audio.reading(on)` — 컷신·라운드 결과·게임 종료 화면: 음악 −8 dB + 1.5 kHz. 글을 읽는 동안 더 물러납니다.
- `Audio.intensity(1)` — 마지막 라운드부터 긴장 레이어가 −26 dB로 계속 깔리고, 결투 중에는 −19 dB로 올라갔다가 다시 내려옵니다.
- 덕킹 우선순위(한 번에 하나만): 사이렌 > 스팅어 > 읽기 > 협상 > 생각. 겹쳐서 과하게 작아지지 않습니다.
- `Audio.reset_mood()` — 게임 화면을 떠날 때 호출. 메뉴가 눌린 믹스를 물려받지 않습니다.
- 효과음 레벨 정책: 자주 들리는 소리는 낮추고(카드 집기 +3 → −4 dB, 카드 뒤집기 −6, 카드 나눠주기 −7, 동전 −10에 간격 0.12 s, 금전등록기 −3, 클릭 −8), 드물고 중요한 소리(승리·게임 종료·업적·마지막 라운드·결투 결과)는 그대로 둬서 대비를 만들었습니다.
- 테스트: `tests/ui_audio_mix_test.gd` (23) — 실제 플레이어 볼륨과 필터 값을 읽어 확인.

### Phase 17: 술집 정보 카드
- 술집을 누르면 그 술집의 상태를 보여줍니다: 아직 안 나온 도박꾼/경찰 장수, 남은 도박꾼 중 가장 높은 눈, 내 손패의 해당 술집 카드, 이번 판에 누가 여기 냈는지.
- "남은 카드" = 전체 인쇄 장수 − 이미 본 카드(내 손패 + 버린 패 + 공개된 카드). 즉 덱과 다른 사람 손패의 합이며, 숨은 정보는 절대 구분해서 보여주지 않습니다 (`_venue_census`).
- 추가 머니카드를 놓는 중에는 탭이 기존대로 "여기에 놓기"로 동작합니다. Esc로 닫힙니다.
- 테스트: `tests/ui_venue_info_test.gd` (17) — 정보 누출 여부 포함.

### Phase 18: 라운드 한 줄 피드백
- 라운드 결과에 내 라운드를 한 줄로: 혼자 차지 / 합의 분배(몇 명과) / 결투 패배 / 단속으로 쫓겨남(경찰 몇 장) / 아직 정리 안 됨, 그리고 이번 라운드 최고 수입.
- 모두 방금 보여준 이벤트에서만 만들고, "이랬다면" 같은 가정은 넣지 않습니다 (`_my_round_note`).
- 테스트: `tests/ui_round_note_test.gd` (16).

### Phase 19: 첫 판 안내
- 필요한 순간에만 짧은 안내 카드: 첫 카드 선택, 첫 추가 머니카드, 첫 협상 응답, 첫 단속. 각 한 번씩.
- 카드 본체는 마우스를 통과시켜 보드 클릭을 막지 않고, 해당 행동을 하면 사라집니다.
- 한 판을 끝내면 자동으로 꺼지고(`Settings.coach_on`), 메뉴의 "처음 안내" ON/OFF로 다시 켤 수 있습니다.
- 테스트: `tests/ui_coach_test.gd` (15).

### Phase 20: 디자인 통합 (아르데코 프레임 · 장부 · 멈춤)
감사에서 드러난 가장 큰 문제는 **모든 화면이 같은 물건**이라는 점이었습니다. 메뉴 카드, 일시정지, 라운드 결과, 최종 결과, 기록, 도움말, 요약이 전부 "둥근 모서리 + 황동 테두리" 상자였고, 그 안의 버튼·알약·타일도 같은 규칙을 반복했습니다. 반면 최근에 만든 협상·결투·대화 화면만 고유한 언어(포스터 배너, 펠트, 금색 모서리)를 갖고 있었습니다.

방향: **새 언어를 만들지 않고, 이미 있던 언어를 전 화면으로 넓힌다.**
- `W.DecoBox` (`ui/widgets.gd`): 어두운 면을 황동 ㄱ자 브래킷 네 개가 잡고, 모서리마다 카드 뒷면과 같은 마름모가 박히고, 내용 둘레로 가는 선이 지나가는 프레임. 커스텀 `StyleBox`라 기존 `PanelContainer`를 그대로 쓰면서 교체만 하면 됩니다. **중요한 패널에만** 적용하고 일반 상자는 `sb()`를 유지해 프레임의 무게를 지킵니다.
- `W.rule(u, weight)`: 장부용 가는 선. weight 2는 합계 위의 이중선.
- 적용: 라운드 결과, 최종 결과, 일시정지, 도움말, 기록, 게임 요약, 술집 정보, 첫 판 안내, 메뉴 준비 카드.

화면별
- **라운드 결과 → 장부**: "ROUND 3 / 라운드 정산" 제목, 열 머리글(술집·결과 / 받은 사람, 플레이어 / 이번 라운드 / 보유), 가는 선, 내 잔액 위 이중선.
- **최종 결과 → 최종 정산**: 1위 줄만 크게 + 아래 가는 선으로 분리, 나머지는 작게, 버튼 위 이중선.
- **일시정지**: 제목 "잠시 멈춤", 계속하기·나가기를 맨 위로 올리고 나머지는 "설정" 머리글 아래로. **그리고 실제로 멈춥니다**(아래 참조).
- **메뉴 준비 카드**: 여덟 줄짜리 설정 대시보드를 인원·난이도 두 가지로 줄이고, 나머지는 "환경 설정 ▸" 접기 안으로.
- **기록**: 게임·우승·승률만 큰 틀에 넣고 나머지 수치는 테두리 없이, 달성한 업적만 황동 틀로.
- **도움말**: 짧은 페이지가 위로 쏠리지 않고 가운데 오도록.
- 한국어 줄바꿈: `AUTOWRAP_WORD_SMART`가 "단독 도/박꾼"처럼 단어 중간을 끊어서 전 화면을 `AUTOWRAP_WORD`로 교체.

### Phase 20b: 멈춤이 실제로 멈추도록
감사 중 일시정지 패널을 띄워 둔 채로 라운드가 뒤에서 끝나고 결과 보드가 패널 위에 겹치는 것을 발견했습니다(실제 스크린샷으로 확인).
- `_set_paused()`: `get_tree().paused`를 쓰고 `modal_layer`만 `PROCESS_MODE_ALWAYS`로 둬서 패널은 계속 반응합니다.
- `_wait()`는 멈춘 동안 시간을 세지 않고, `_play_events()`는 멈춘 동안 다음 이벤트를 시작하지 않습니다.
- 게임 화면을 떠날 때 반드시 해제해서 메뉴가 멈춘 채로 남지 않습니다.
- 테스트: `tests/ui_pause_test.gd` (14).


### Phase 22: Steam Deck / 휴대용 대응 (Godot 4.3)
인증(Verified) 판정은 Valve가 실제 기기에서 합니다. 아래는 그 기준에 맞추기 위한 준비이며, 실기기 검증은 아직 하지 않았습니다.
- `platform/steam_deck_manager.gd` (오토로드 `SteamDeckManager`): 실행 환경 감지 — `SteamDeck=1` 환경 변수 또는 DMI(Valve + Jupiter/Galileo)일 때만 `STEAM_DECK_CONFIRMED`. 1280x800 + gamescope/패드는 `LINUX_HANDHELD_CANDIDATE`, 그 밖의 Linux는 `DESKTOP` (Linux = Deck 으로 보지 않음).
  - 화면: 자동이면 휴대용은 전체 화면, 데스크톱은 창. 실패하면 창으로 복구. 설정(메뉴 환경 설정 · 멈춤 패널)에서 변경, `user://settings.cfg [display]`에 저장.
  - 성능 프리셋: 고품질(상한 없음) / 균형(60fps, Deck 기본) / 배터리 절약(30fps + 저전력 렌더링 + 움직이지 않는 펠트). VSync 켬.
- `platform/input_mode_manager.gd` (오토로드 `InputModeManager`): 키보드·마우스 / 게임패드 / 터치 자동 전환(`input_mode_changed`, `gamepad_connected`, `gamepad_disconnected`), 스틱 데드존 0.5, 패드 모드에서 커서 숨김, 포커스가 없을 때 방향키/A 로 자동 복구, 오른쪽 스틱 스크롤, 장치별 버튼 이름(A/B/메뉴 버튼… ↔ Enter/Esc…).
- 컨트롤러 조작: A 확인 · B 취소/닫기 · 메뉴 버튼 멈춤 · Y 고른 카드의 술집 정보 · X 연출 건너뛰기 · 보기 버튼 음소거 · 십자키/왼쪽 스틱 이동. 마우스 없이 메뉴→게임→협상·결투→게임 오버→요약→메뉴 전 과정이 됩니다.
- 화면 크기: 멈춤 패널의 설정 묶음은 스크롤 영역이 되어 세로가 짧은 화면에서도 잘리지 않습니다. 협상 패널은 아래쪽 도킹에서 글자가 너무 작아지면 옆자리로 옮겨 글자 크기를 지킵니다. 카드 위 글자 최소 크기 8→10px.
- 도구: `tools/check_paths.py`(대소문자 경로 검사), `tools/parse_all.gd`(전체 스크립트 파싱), `tools/ci_check.sh`(경로·임포트·파싱·부팅·테스트).
- 테스트: `tests/qa_gamepad_playthrough_test.gd`(컨트롤러만으로 한 판 + 글자 크기 감사 `audit=1`), `tests/platform_test.gd`(`SteamDeck=1` 로 Deck 경로), `tests/perf_idle_test.gd`(대기 화면 그리기 횟수).

### Phase 23: 추가 머니카드 표시 · 술집 정보 카드 집계
- 딜러의 추가 머니카드: 금액이 적힌 앞면 카드가 딜러 옆에 나타나 고른 술집으로 날아갑니다(내가 딜러면 고르는 동안 카드가 버튼 위에 보이고, 마우스를 올리거나 포커스한 술집에 "+$25,000 / 놓으면 $75,000" 미리보기). 놓인 술집에는 그 라운드 동안 금색 표시 "추가 +$25,000 · 딜러 Vito"가 남고, 그 술집 돈이 지급되거나 다음 라운드가 시작되면 사라집니다. 이어하기 때도 복원됩니다.
- 기본 머니카드: 라운드마다 "머니카드 분배 — 술집마다 1장씩" 안내와 함께 각 술집 위에 받은 금액(+$5,000 등)이 잠깐 표시됩니다.
- 술집 정보 카드 집계를 화면 진행 기준으로 바꿨습니다. 예전에는 엔진 상태(화면 연출보다 앞서 있음)를 읽어서, 연출 중에 열면 아직 받지 않은 다음 손패가 섞여 보였습니다(검증 스크립트 144회 중 19회 불일치 → 0회). 이어하기 후 사라지던 "낸 카드 기록"도 이벤트 기록에서 복원합니다.
- 표 형식: 도박꾼/경찰 × [전체 · 이미 나옴 · 내 손 · 남은 카드], 항상 전체 = 이미 나옴 + 내 손 + 남은 카드. 남은 도박꾼 눈 목록(가장 높은 눈 강조), 덱을 다시 섞은 횟수와 그 의미 안내, "이번 게임" 기록으로 표기 정리.
- 테스트: `tests/ui_extra_money_census_test.gd` — 사람 딜러(카드·미리보기·비행·표시), 한 판 전체에서 표시 규칙, 모든 카드 선택 시점의 집계를 실제 덱·손패와 대조, 연출 중 손패 누출 없음, 이어하기 후 동일.

### Phase 24: Sal의 튜토리얼 (발라트로식 첫 판)
- 처음 NEW GAME을 누르면 "처음이야, 신입?" 제안(튜토리얼 하기 / 바로 시작). 메뉴의 "튜토리얼 · Sal과 3라운드" 버튼으로 언제든 다시 할 수 있습니다. 끝내거나 건너뛰면 다시 묻지 않습니다(`settings.cfg [anim] tutorial_done`).
- 고정된 판(시드 23, `ui/tutorial_plan.gd`)에서 진짜 규칙으로 3라운드: ① 혼자 들어가 술집 돈 독식 + 술집 정보 카드 보기 ② Vito와 같은 술집 → 내가 제안 → 거절 → 결투(승리) ③ 내가 딜러로 추가 머니카드 배치 + 경찰 카드로 Mack 단속. AI 선택만 대본(`MatchController.script_ai`)으로 정하고, 모든 행동은 엔진 규칙 검사를 그대로 거칩니다.
- 연출(`ui/tutorial_director.gd`): Sal 초상과 말풍선(한 번에 2줄 이내, 타자 효과), 설명 대상만 밝히는 스포트라이트(숨 쉬는 금색 테두리 + 화살표), "말하기" 단계에서는 탁자 입력 차단 / "해 보기" 단계에서는 밝힌 곳만 입력 가능. 말풍선은 밝힌 곳과 관련 패널을 피해 자리를 고릅니다. 멈춤(Esc/Start)은 평소처럼 동작하고 그동안 안내는 물러납니다. 마우스·터치·컨트롤러 모두 같은 흐름.
- 튜토리얼에서 배운 처음 안내(카드 고르기·추가 머니카드)는 이후 게임에서 반복하지 않습니다.
- 도구/테스트: `tools/find_tutorial_seed.gd`(판이 계획대로 흘러가는지 검사, CI 포함), `tests/qa_tutorial_test.gd`(실제 입력으로 끝까지 — 마우스/컨트롤러/세로 화면/건너뛰기).
- 함께 고친 것: 추가 머니카드 금색 표시가 결투 화면 위로 비치던 문제(그리기 순서).

### Phase 25: 컷신·대화 장면 개편
- 연출: 영화식 위아래 검은 띠가 닫히며 시작하고, 탁자는 비네트로 가라앉습니다. 띠 위에 지금 장면의 제목과 걸린 돈이 나옵니다(예: "결투 · COLIBRI · $45,000"). 인물은 둥근 아이콘 대신 금색 액자의 서류 사진처럼 세워지고, 말하는 사람은 앞으로 나오고 듣는 사람은 그늘로 물러납니다. 이름표는 성격 색, 대사 상자는 아르데코 테두리 + "1 / 2" 표시. 장면 동안 게임의 SKIP 버튼은 숨겨 하나만 보입니다.
- 대사: 그 순간의 정보를 담습니다 — 판돈 총액, 술집 이름, 결투·단속에 걸린 돈, 1등과 차이. 게임마다 다른 대사가 나오도록 고르는 방식을 바꿨고(같은 첫 장면 반복 방지), 대사 수를 늘렸습니다. 인물별 고유 대사(Dutch "허허, 젊은이…" 등)가 성격 대사보다 우선합니다. 이름·금액 뒤에 조사가 붙어 어색해지는 문장은 없앴습니다(테스트로 검사).
- 새 장면: 큰 단속(판돈 $40,000 이상, 나와 AI 사이), 내가 처음 1등으로 올라섰을 때(3라운드부터). 마지막 라운드는 1등·차이에 따라, 막상막하면 그에 맞는 대사.
- 흐름: 게임 중간 장면(큰 결투·단속·선두 교체)은 한 게임에 최대 3번, 두 라운드 연속 금지. 설정 "대화 장면"이 전체 / 핵심만(시작·마지막 라운드·종료) / OFF 로 바뀌었습니다.
- 테스트: `tests/ui_scene_story_test.gd`.

### Phase 26: RAZZIA 연출 · 새 배경 음악
- RAZZIA 장면(`ui/raid_fx.gd`): 거리가 어두워지고 단속당한 술집만 빛 속에 남습니다 → 길모퉁이 두 곳에서 경찰 탐조등(빨강·파랑)이 테이블을 가로질러 훑다가 술집에 멈춥니다(빛이 한 번씩 부풀 뿐 깜빡이지 않음: 광과민성 규칙 유지) → 경찰 카드가 술집 위로 내리꽂히고 → 화면 가운데 고무도장 "RAZZIA"(술집 이름, 낡은 잉크 질감)가 찍히며 판이 흔들리고 → 아래에 이번 단속의 의미가 한 줄로 나옵니다("내 경찰 카드! · 도박꾼 2명 퇴장 · 판돈 $45,000 → 경찰 1명"). 쫓겨난 도박꾼 카드는 튕기듯 비뚤어집니다. 길이·SKIP·움직임 줄이기·속도 설정은 그대로(NORMAL 약 2.25초).
- 배경 음악 교체: 예전 곡을 지우고, 이 게임용으로 새로 작곡한 금주법 시대 느와르 재즈(D단조, 88bpm 스윙, AABA 32마디, 87초 루프)를 넣었습니다. 브러시 드럼, 워킹 베이스, 피아노 컴핑, 약음 트럼펫 테마(A1·A3), 브리지의 비브라폰. 카드 게임 내내 깔리는 곡이라 테마는 일부 구간에만 나오고 나머지는 잔잔하게 비워 두었습니다. 같은 조의 긴장 레이어(`tension_loop.ogg`, 박자 없는 트레몰로 현악 + 첼로 지속음 + 먼 팀파니)도 새로 만들었습니다.
- 만드는 법: `python3 tools/make_music.py` (mido + FluidSynth + FluidR3_GM 사운드폰트, MIT 라이선스). 세 번 연속 렌더해 가운데 한 바퀴를 잘라 이음매 없는 루프를 만들고, 음량은 기존 믹스에 맞춰 -18 LUFS(긴장 레이어 -20 LUFS)로 맞춥니다.

### Phase 27: 코드와 테스트 정리
- `ui/game_screen.gd`(약 3,100줄)를 `ui/board/` 8개 파일 + 최종 `game_screen.gd`(약 250줄)로 나눔. GDScript에는 부분 클래스가 없어 상속 사슬
  `board_base → layout → info → input → scenes → fx → replay → results → game_screen`으로 나눔. 함수 본문은 한 줄도 바꾸지 않음(원본 줄 전부가 새 파일에 있는지 기계적으로 확인).
  앞 파일에서 뒤 파일 함수를 부르는 곳은 `board_base.gd`에 빈 함수(stub)를 두고, 실제 구현이 덮어씀. 외부에서 쓰는 이름(`game.ctl`, `game.skip`, 신호 등)은 그대로.
- `tests/ui_duel_flow_test.gd` 다시 씀: 튜토리얼 판(`TutorialPlan.config()` + AI 대본)으로 실제 제안 → 결투 → 결과까지 확인. `run_all_tests.sh`에 포함.
  보드에 `ai_script` 연결점 추가(`begin()`에서 컨트롤러 `script_ai`로 넘김, 테스트 전용).
- 테스트용 설정 경로: `Settings.is_test_run()`(테스트 스크립트 또는 `RAZZIA_TEST=1`)이면 `settings.cfg`·`autosave.json`·`records.json` 대신
  `user://test_<pid>_*`를 쓰고 종료 시 지움. 실제 설정 파일 md5가 테스트 전후로 같음을 확인. `ui_coach_test`는 필요한 설정을 직접 맞춤.
- `tools/run_all_tests.sh`: `OUT` 폴더가 없으면 만듦.

### Phase 28: 언어 · 음악 · 이름 · 저장 슬롯 · 가독성
- **버그 수정 (Phase 27 검증 누락):** `Settings.path`가 `_test_run`보다 먼저 초기화되어, 테스트가 실제 `settings.cfg`를 계속 쓰고 있었음.
  `_test_run` 선언을 앞으로 옮겨 해결. `i18n_slots_test` A에서 경로를 확인. 이 수정으로 테스트가 기본 설정(처음 안내·대화 장면 켜짐)에서
  돌게 되어 드러난 문제도 고침: 대화 장면이 `ui_accept` 액션 입력(리매핑·Steam Input)으로 넘어가지 않던 것.
- **다국어:** `ui/i18n.gd` + `i18n/en.gd`(704문장) + `tools/i18n/build_en.py`. 키 = 한국어 원문, 대체 언어 ko(`project.godot`).
  - Label/Button은 자동 번역, 조합 문장·직접 그린 글자는 `tr()`/`T.t()`.
  - 기본 이름 "나"는 화면에서만 "You"로 바뀌고, 저장 데이터는 그대로.
  - 영어 한 판·튜토리얼·마우스 플레이 동안 화면 전체를 몇 프레임마다 검사해 한글이 0개임을 확인(`lang=en`).
  - 장면 대사는 상자 폭(픽셀) 검사. 문맥이 다른 같은 단어("전체")는 둘 다 맞는 번역("All")으로 함. 자세한 내용은 `docs/I18N.md`.
- **음악:** 메뉴 곡(72 BPM)과 마지막 라운드 곡(116 BPM)을 같은 조로 새로 작곡(`tools/make_music.py`). `Audio.cue()`가 두 플레이어로 교차 페이드.
  - 같은 곡은 다시 틀지 않음. 파일이 없으면 보통 곡으로 대신함.
  - 마지막 라운드는 긴장 레이어 대신 전용 곡을 씀. 게임 결과 화면은 메뉴 곡.
  - 전체 음소거(`mute_all`, M 키 = 이 스위치)를 추가하고, 메뉴에도 볼륨 전체를 둠.
- **이름:** 게임 준비 카드의 입력칸. `Settings.clean_name`(제어문자·대괄호 제거, 공백 정리, 12자). 엔진에는 기존 `names`로만 전달.
  - "(나)" 표시는 이름을 바꾼 경우에만 붙임("나 (YOU)" 중복 제거). 대사에서는 기본이면 "신입/Rookie", 아니면 이름으로 부름.
  - 칩에서 긴 이름은 "…"로 줄임.
- **저장 슬롯 2개:** 슬롯 1 = 기존 `autosave.json`(호환), 슬롯 2 = `autosave_2.json`. `format`·`savedAt`는 선택 필드.
  - 쓰기 전 크기를 확인하고, 직전 저장을 `.bak`로 둠. 손상되면 `.bak`로 이어하기.
  - 메뉴: 게임 준비에서 슬롯 선택(덮어쓰기 확인, 취소가 기본 포커스), CONTINUE → 슬롯 목록.
  - 멈춤 패널에 "슬롯 N에 자동 저장 중"을 표시.
- **가독성:**
  - 1024×768에서 PICK A CARD 버튼이 화면 밖으로 나가던 문제 수정(버튼은 글자 폭을 지키고 손패가 줄어듦).
  - `T.screen_scale`을 메뉴에서도 계산해 작은 글자 키우기를 메뉴·버튼에도 적용.
  - 좁은 카드·포스터에는 짧은 술집 이름을 크게 씀. 너무 작은 경찰 미니카드는 띠+별로 표시.
  - 라운드 장부: 술집/결과 두 줄, 받은 사람 한 줄에 한 명.
  - 협상 응답 카드의 긴 문장을 카드 아래 한 줄로 옮김.
- **테스트:** `i18n_slots_test`(59), `audio_cue_test`(20), `restart_test`(두 프로세스), `lang=en` 세 판, `name=` 긴 이름 한 판.
  기존 테스트는 M 키(마스터 음소거), 협상 카드 표시, 이어하기(슬롯 목록)에 맞게 고침.

### Phase 29: 스크롤 없애기 · 폰 가로 배치 · 진행 문구 즉시 번역 · 영어 교정
- **스크롤 없음:** UI 코드에서 `ScrollContainer`를 모두 없앰(6곳).
  - `W.FitBox`: 내용이 칸보다 크면 통째로 줄여서 보여 줌. 줄일 때도 내용 폭은 그대로 둠(폭이 배율에 따라 바뀌면 줄바꿈 → 높이 → 배율이 끝없이 바뀌는 문제가 있었음, 실제로 메시지 큐가 넘쳐 Godot가 멈춤).
  - `W.tabs`: 탭 버튼 + 탭마다 FitBox. 모든 탭이 가장 큰 탭의 높이를 써서 패널 크기가 흔들리지 않음.
  - `ui/settings_panel.gd`: 설정을 `게임 진행 / 소리 / 화면` 탭으로 나눔. 메뉴는 따로 여는 패널로, 멈춤 패널은 `조작` 탭을 더함.
  - 기록·게임 요약도 탭으로 나눔. 게임 방법은 긴 쪽을 실제로 그려 본 뒤 나눔(85%까지 줄여서 들어가면 나누지 않고, 제목 줄은 다음 덩어리와 붙여 둠).
  - 술집 정보 카드와 메뉴는 FitBox로 처리.
  - 메뉴: B/Esc로 설정·슬롯·덮어쓰기 창을 닫음. 언어 스위치는 오른쪽 위에서 왼쪽으로 자라게 고정(1280×720에서 10px 넘치던 것 수정).
  - 검사 도구 `tools/ui_shots.gd`: 보이는 스크롤 영역, 화면 밖 글자·버튼을 찾으면 실패. 4개 해상도·두 언어로 전체 테스트에 포함.
- **폰 가로 배치:** `T.screen_scale < 0.75`인 가로 화면(844×390 0.54, 800×600 0.63)에서 씀.
  - 낸 카드 줄을 없애고 뒷면 카드를 레일 칩 옆에 둠. 손패를 화면 높이의 41%로 키우고, 칩은 ×1.3, 덱은 PLAY 버튼 위.
  - 작은 미니카드의 글자는 읽을 수 없으면 그리지 않음(경찰은 띠+별).
  - 칩이 좁으면 DEALER 표시 대신 얼굴에 D 배지.
  - 협상 응답 카드는 내용 높이만큼 커짐.
- **진행 문구 즉시 번역:** 값을 끼워 만드는 진행 문구 11곳을 `_now_live(Callable)`로 바꿈. 언어를 바꾸면 `_refresh_now()`가 다시 만듦.
- **영어 교정:** `tools/i18n/en_zz_polish.py`(약 60문장).
  - `(s)` 복수형을 없앰. 어색한 직역과 어순을 고침("%s — %s at %s" → "%s — %s, %s").
  - UI 용어를 통일함(Cutscenes, Key moments, Battery saver, Round payout). 캐릭터 대사를 다듬음.
  - "게임" 키 충돌(기록 Games ↔ 설정 탭)은 설정 탭 키를 "게임 진행"으로 나눠 해결.
- **테스트 수정:** `ui_pad_menu_test`(설정 패널·탭을 패드로), `ui_audio_test`(소리 탭 선택), `ui_scene_story_test`(영어 대사 폭).
- **게임패드 버그 수정(폰 세로에서 가끔 재현):**
  - 증상: 협상 응답 카드가 0.5초 동안 입력을 막는(arm) 사이에 십자키를 누르면 포커스가 ⎋ 버튼으로 갔고, 거기서 협상 카드로 돌아올 길이 없었음. 430×932에서 4판 중 3판 재현.
  - 수정: 협상 패널이 열려 있는데 포커스가 패널 밖에 있으면, 십자키나 A가 패널의 기본 버튼으로 포커스를 되돌림(`nego.default_focus_target()`). 수정 후 6판 연속 통과.

### Phase 30: Steam 상용화 출시 감사 및 마스터 문서 체계 구축
- **출시 준비 실사 (Conditional Go 판정):**
  - TD / Game Director / QA Lead / Steam 출시 담당 관점에서 프로젝트 전수 조사.
  - 109종 엔진 골든 테스트(PASS), 240개 중단점 6,442개 세이브 체크(PASS), Steam Deck 1280×800 네이티브 호환 확인.
  - P0 긴급 수정 과제 3건(i18n 누락 4문장, QA 라운드 전환 버튼 매칭, tools 경로 검사기) 도출.
- **Steam 상용화 9대 마스터 문서 신규 수립:**
  - `docs/STEAM_RELEASE_AUDIT.md`: 스팀 출시 종합 감사 및 조건부 출시 판정서.
  - `docs/TECHNICAL_ARCHITECTURE.md`: 5계층 단방향 아키텍처 및 4대 불변식 명세.
  - `docs/STEAM_INTEGRATION.md`: GodotSteam GDExtension, 13종 업적, AutoCloud 세이브 전략.
  - `docs/STEAM_DECK_COMPATIBILITY.md`: Steam Deck Verified 4대 기준 및 절전 프로파일 가이드.
  - `docs/GAME_DESIGN_REVIEW.md`: 코어 루프, 7인 AI 라이벌, 8종 유물 상업성 평가.
  - `docs/QA_TEST_PLAN.md`: 품질 보증 및 테스트 자동화 진단 보고서.
  - `docs/LEGAL_AND_ASSET_AUDIT.md`: 독자 브랜드 리브랜딩 권고 및 에셋 라이선스 실사.
  - `docs/STEAM_RELEASE_ROADMAP.md`: Phase 1~5 마일스톤 및 P0/P1 작업 명세표.
  - `docs/CHANGELOG.md`: Phase 1~30 마스터 체인지로그 통합.
- **문서 포털 및 README 동기화:**
  - 루트 `README.md` 및 `docs/README.md` 전면 개편.
  - `docs/development/DEVELOPMENT_STATUS.md`, `ROADMAP.md`, `KNOWN_ISSUES.md` 최신 동기화 완료.

