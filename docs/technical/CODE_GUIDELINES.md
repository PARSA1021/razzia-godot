# 📝 CODE GUIDELINES — 코드 작성 및 개발 규칙 가이드

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/technical/PROJECT_ARCHITECTURE.md`](PROJECT_ARCHITECTURE.md), [`docs/development/TESTING_GUIDE.md`](../development/TESTING_GUIDE.md)

---

## 1. 정적 타이핑 및 명명 규칙 (Static Typing & Naming Conventions)

모든 신규 및 유지보수 코드는 Godot 4.3 GDScript의 정적 타입을 필수로 명시해야 합니다.

### 1.1 변수 및 함수 시그니처
```gdscript
# 올바른 예: 정적 타입 명시
var current_croupier: int = 0
var is_active: bool = false
const MAX_PLAYERS: int = 8

func resolve_bar(bar_id: String, state: Dictionary) -> Dictionary:
    # ...
    return state
```

### 1.2 명명 규칙 (Naming Conventions)
- **클래스 및 커스텀 타입:** `PascalCase` (예: `MatchController`, `SteamDeckManager`)
- **함수 및 변수명:** `snake_case` (예: `choose_card()`, `bar_money`)
- **상수:** `UPPER_SNAKE_CASE` (예: `MIN_SCREEN_PX`, `BG_PANEL`)
- **프라이빗 내부 함수/변수:** 언더스코어 접두사 `_` (예: `_load_font_file()`, `_on_card_clicked()`)
- **파일 및 디렉토리명:** `snake_case.gd`, `snake_case.tscn` (단, 에셋 및 바 고유 ID는 규칙에 따름)

---

## 2. 결정론적 난수 및 엔진 무결성 원칙

### ⚠️ 절대 규칙: `engine/` 내에서 `randi()` / `randf()` 사용 금지
엔진 계층에서는 Godot 내장 난수 함수를 절대로 호출해서는 안 됩니다.
- 모든 난수는 오직 `s["rng"]`에 보관된 32-bit 정수 시드를 `Rng.next32(s["rng"])`로 전이시키는 방식으로만 생성해야 합니다.
- 시스템 타임스탬프(`Time.get_ticks_msec()`), OS 고유값 등을 엔진의 승패 결정 로직에 개입시키는 행위는 엄격히 금지됩니다.

---

## 3. AI 안티치트 차단 원칙 (Anti-Cheat Isolation)

`ai/ai.gd`가 의사결정을 내릴 때 절대로 전체 `state` 원본을 직접 전달해서는 안 됩니다.
- 반드시 `Eng.player_view(state, player_id)`를 통과한 **합법적 정보 투영본**만을 AI에게 전달해야 합니다.
- **차단되는 비공개 정보:**
  - 다른 플레이어들의 비공개 손패 카드 목록
  - 다른 플레이어가 비밀리에 고른 뒷면 카드
  - 머니 덱과 카드 덱의 다음 뽑을 카드 순서

---

## 4. UI-엔진 분리 원칙 (RULE-034 준수)

- UI 위젯(`ui/*.gd`) 내에서 게임의 규칙(누가 이겼는지, 판돈이 얼마가 되어야 하는지, 경찰이 출동했는지)을 임의로 판정하거나 상태를 직접 수정하지 마십시오.
- 모든 상태 변경은 `controller.dispatch({"type": "ACTION"})`을 통해서만 이루어져야 합니다.
- UI는 단지 엔진이 전달한 이벤트와 렌더링 상태를 그리는 뷰포트에 불과합니다.

---

## 5. 풀 리퀘스트(PR) 및 커밋 체크리스트

코드를 커밋하거나 병합하기 전에 다음 항목을 통과해야 합니다:
1. `tests/run_tests.gd` 헤드리스 테스트를 실행하여 **109 checks, 0 failed** 통과 확인.
2. `tools/check_paths.py`를 실행하여 누락된 리소스 경로(`res://`)가 없는지 확인.
3. GDScript 경고(Warning) 및 린트 에러가 발생하지 않는지 확인.
