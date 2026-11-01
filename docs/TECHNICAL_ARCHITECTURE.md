# 🏛️ TECHNICAL ARCHITECTURE — 기술 아키텍처 및 시스템 설계 명세

> **작성 기준일:** 2026-11-01  
> **엔진:** Godot Engine 4.3 Stable (Compatibility / OpenGL 3.3)  
> **언어:** GDScript 2.0 (정적 타입 엄격 준수)  
> **상태 관리:** 불변식 기반 상태 머신 (Pure State Machine)

---

## 1. 아키텍처 계층 구조 및 단방향 원칙

본 프로젝트는 고전적인 게임 엔진의 UI-로직 강결합 문제를 원천 차단하기 위해 **5개 계층(Platform, UI, Controller, AI, Engine)의 엄격한 단방향 분리**를 채택하고 있다.

```text
┌────────────────────────────────────────────────────────┐
│  Platform Layer (AutoLoad: SteamDeckManager / Input)   │
├────────────────────────────────────────────────────────┤
│  UI Layer (Single Scene: main.tscn + Procedural Views) │
├────────────────────────────────────────────────────────┤
│  Controller Layer (MatchController: 비동기 턴 중재자)   │
├────────────────────────────────────────────────────────┤
│  AI Layer (Heuristics: EASY / NORMAL / HARD 휴리스틱)  │
├────────────────────────────────────────────────────────┤
│  Engine Layer (Pure State Machine: engine.gd, RNG)     │
└────────────────────────────────────────────────────────┘
```

### 계층별 의존성 규칙 (Dependency Invariants)
1. **Engine Layer (`engine/`):**
   - Godot의 `Node`, `SceneTree`, `Control` 등 UI 객체를 일절 참조하지 않는 순수 GDScript `RefCounted`.
   - 결정론적 의사난수(`Mulberry32`)만을 사용하며 엔진 내부에서 `randi()`, `randf()` 사용을 엄격히 금지함.
   - 모든 상태 전이는 순수 함수적이며, `events` 배열에 발생한 사건 로그를 누적함.
2. **AI Layer (`ai/`):**
   - 전체 엔진 상태에 직접 접근할 수 없으며, 반드시 `Eng.get_public_view()`로 마스킹된 시야 정보만 수신 (안티치트 보장).
   - 상대방의 미공개 패 및 덱의 남은 카드를 볼 수 없음.
3. **Controller Layer (`controller/`):**
   - 엔진 상태 머신과 비동기 프레젠테이션(UI 애니메이션) 사이의 중재자.
   - AI 의사결정의 지연 시간(타이밍 딜레이)을 주입하고 플레이어 액션을 검증하여 엔진에 디스패치함.
4. **UI Layer (`ui/`):**
   - 단 하나의 루트 씬(`main.tscn`)을 기반으로 모든 뷰가 코드로 동적 생성(Procedural Generation).
   - UI는 어떠한 게임 규칙도 스스로 결정하지 않음 (`RULE-034`). 엔진이 발생시킨 `events`를 시각적으로 리플레이할 뿐임.
5. **Platform Layer (`platform/`):**
   - `SteamDeckManager.gd` 및 `InputModeManager.gd`가 오토로드로 등록되어 입력 장치(마우스, 터치, 게임패드)와 디스플레이 프로파일을 전역 관리.

---

## 2. 엔진 상태 머신 및 데이터 흐름

### 2.1 라운드 라이프사이클 흐름도
```mermaid
graph TD
    A[라운드 시작: CROUPIER_SETUP] --> B[머니 카드 분배 & 크루피에 보너스 선택]
    B --> C[비밀 카드 선택: CARD_SELECTION]
    C --> D[동시 공개: CARDS_REVEALED]
    D --> E[6대 주점 순차 정산: 1 to 6]
    E --> F{주점 내 카드 구성}
    F -->|단독 도박꾼| G[판돈 전액 지급]
    F -->|도박꾼 경쟁| H[협상 슬라이더 제안]
    H -->|합의 성립| I[제안 금액 분배]
    H -->|합의 결렬| J[주사위 결투: D6 + Pip]
    F -->|경찰 단속| K[도박꾼 $0 퇴출 & 단속 보상]
    F -->|빈 주점| L[판돈 이월]
    G --> M[암시장 상점 (유물 모드)]
    I --> M
    J --> M
    K --> M
    L --> M
    M --> N{머니 카드 덱 소진?}
    N -->|No| A
    N -->|Yes| O[최종 결과: GAME_ENDED]
```

### 2.2 핵심 수학적 불변식 (Engine Invariants)
- **INV-001 (카드 보존의 법칙):**
  $\sum (\text{플레이어 손패}) + \text{드로우 덱} + \text{버린 카드} + \text{테이블에 낸 카드} = \text{초기 덱 총수}$
- **INV-002 (통화량 보존의 법칙):**
  $\sum (\text{플레이어 보유금}) + \sum (\text{6대 바 판돈}) + \text{암시장 금고} + \text{머니 덱 미분배금} = \text{초기 총 통화량}$
- **INV-003 (크루피에 순환 법칙):**
  라운드마다 크루피에 토큰은 $(C + 1) \pmod N$으로 정확히 1칸씩 시계방향 이동.
- **INV-004 (결투 동점 도전자 우위 법칙):**
  주사위 합산 눈이 정확히 동점일 경우, 협상을 거절하고 결투를 선언한 **도전자(Challenger)**가 무조건 승리함 (`RULE-020`).

---

## 3. 저장 및 복원 아키텍처 (`ui/save_store.gd`)

### 3.1 파일 시스템 레이아웃
```text
user://
├── autosave.json           # 슬롯 1 (클래식 모드 진행 데이터)
├── autosave.json.bak       # 슬롯 1 직전 성공 백업본
├── autosave.json.tmp       # 슬롯 1 쓰기 중 임시 파일
├── autosave_2.json         # 슬롯 2 (유물 모드 진행 데이터)
├── autosave_2.json.bak     # 슬롯 2 직전 성공 백업본
├── settings.cfg            # 유저 환경설정 (ConfigFile 포맷)
└── records.json            # 누적 전적 및 13종 도전과제 (JSON)
```

### 3.2 2단계 원자적 교체 쓰기 (Atomic Write Pipeline)
저장 중 전원 종료나 크래시로 인한 세이브 파손을 100% 방지하기 위해 파일 교체 파이프라인을 운영한다:
1. `autosave.json.tmp`에 완전한 JSON 직렬화 수행.
2. 디스크 플러시 및 길이 검증 후, 기존 `autosave.json`을 `autosave.json.bak`으로 백업 복사.
3. OS 레벨 원자적 파일 교체(`DirAccess.rename_absolute`) 실행.
4. 만약 읽기 실패 시 즉시 `.bak` 파일로 복구하며, 둘 다 깨졌을 경우 `.corrupt.<timestamp>.json`으로 격리하고 새 게임으로 복귀.

### 3.3 액션 재실행 아키텍처 (Action Log Replay)
- 플레이어가 카드를 제출하거나 협상에 응답할 때마다 `record_action()`을 통해 해당 액션이 세이브 파일에 추가됨.
- 이어하기(Continue) 시 체크포인트 상태 머신을 로드한 뒤, 기록된 액션들을 순차적으로 엔진에 재주입(`SaveStore.replay`)하여 중간 롤백이나 치팅을 방지함.

---

## 4. UI 렌더링 및 해상도 적응 아키텍처

### 4.1 듀얼 반응형 뷰포트
- **가로 모드 (Landscape, 1280×720 ~ 1280×800):**
  - 와이드 카지노 테이블. 6대 주점이 중앙 가로 1열에 정렬되고 손패 카드는 하단에 배치.
  - Steam Deck의 1280×800(16:10) 환경에서는 상하 황동 레일 여백을 유연하게 늘려 꽉 찬 화면 렌더링.
- **세로 모드 (Portrait, 720×1280):**
  - 스마트폰 한 손 조작 레이아웃. 6대 주점이 2열 3행 그리드로 자동 전환.

### 4.2 수학적 폰트 스케일링 방어 (`T.fs()`)
화면 해상도가 극단적으로 축소되더라도 텍스트가 뭉개져 읽을 수 없게 되는 현상을 방지하기 위해 최소 픽셀 하한선을 강제:
$$\text{Effective FontSize} = \max(\text{Design FontSize} \times \text{Scale}, \text{MIN\_SCREEN\_PX})$$

---

## 5. 입력 및 플랫폼 추상화 (`platform/`)

### 5.1 실시간 무경계 입력 전환 (`InputModeManager.gd`)
- `InputEventJoypadButton`, `InputEventMouseButton`, `InputEventScreenTouch`를 실시간 감지하여 UI 프롬프트 글리프(A/B 버튼 vs 마우스 클릭)를 1프레임 내에 자동 교체.
- 아날로그 스틱 및 트리거에 각각 데드존(0.5)을 두어 오작동 방지.
- 마우스는 12px 이상 이동했을 때만 키보드/마우스 모드로 복귀하여 컨트롤러 플레이 중 책상 떨림으로 인한 모드 튐 방지.

### 5.2 Steam Deck 전력 프로파일 (`SteamDeckManager.gd`)
- Steam Deck 감지 시(`SteamDeck=1` 환경변수 또는 DMI 제조사 `Valve`), 배터리 절약을 위한 `BATTERY_SAVER` 프리셋(30fps 제한, `OS.low_processor_usage_mode = true`, 정적 펠트 셰이더) 활성화 지원.
