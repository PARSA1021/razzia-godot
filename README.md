# Razzia Mobile

1920년대 금주법 시대의 밤거리. 술집 여섯 곳에 돈이 쌓이고, 도박꾼은 판돈을 노리고, 경찰은 단속을 노립니다.
**Razzia Mobile**은 Stefan Dorra의 보드게임 *Razzia*(Ravensburger, 1992)를 Godot 4.3으로 옮긴 1인용 카드 게임입니다.
사람 1명과 AI 2~7명이 함께 하고, 데스크톱·Steam Deck·휴대폰(가로/세로) 화면을 모두 지원합니다.

- 엔진: Godot **4.3** (GDScript, 렌더러 Forward+ / 호환 모드 OpenGL 3)
- 언어: 한국어 UI (일부 버튼·제목은 영어 표기를 함께 씀)
- 상태: 한 판 전체를 처음부터 끝까지 플레이할 수 있습니다. 마우스·터치·키보드·게임패드로 모두 플레이할 수 있고 자동 테스트도 갖췄습니다.
  출시 전 남은 일은 [알려진 문제와 다음 할 일](#알려진-문제와-다음-할-일)에 정리했습니다.

---

## 목차

1. [빠른 시작](#빠른-시작)
2. [게임 규칙 요약](#게임-규칙-요약)
3. [주요 기능](#주요-기능)
4. [조작법](#조작법)
5. [설정](#설정)
6. [프로젝트 구조](#프로젝트-구조)
7. [아키텍처](#아키텍처)
8. [자산과 라이선스](#자산과-라이선스)
9. [개발 도구](#개발-도구)
10. [테스트](#테스트)
11. [저장 파일](#저장-파일)
12. [문서](#문서)
13. [개발 규칙](#개발-규칙)
14. [알려진 문제와 다음 할 일](#알려진-문제와-다음-할-일)

---

## 빠른 시작

### 필요한 것

| 항목 | 버전 / 비고 |
|---|---|
| Godot | 4.3 stable (표준 빌드, .NET 아님) |
| (선택) Python 3 | 경로 검사 `tools/check_paths.py`, 음악 생성 `tools/make_music.py` |
| (선택) Node.js 18+ | 정답 로그 재생성 `tools/regenerate_golden.sh` |
| (선택) xvfb | Linux에서 화면이 필요한 테스트·스크린샷 |

### 실행

```bash
# 에디터로 열기
godot --editor --path .

# 바로 플레이 (메인 씬: res://ui/main.tscn)
godot --path .

# 규칙 엔진 테스트 (약 10초, 종료 코드 0 = 통과)
./run_tests.sh /path/to/godot          # 또는 GODOT=/path/to/godot ./run_tests.sh
```

처음 NEW GAME을 누르면 **Sal의 튜토리얼**(3라운드, 약 5분)을 할지 묻습니다. 건너뛰어도 메뉴의 "튜토리얼" 버튼으로 언제든 다시 할 수 있습니다.

---

## 게임 규칙 요약

규칙의 원본은 [`docs/02_RULEBOOK.md`](docs/02_RULEBOOK.md)(RULE-001 ~ RULE-035)이고, 엔진(`engine/engine.gd`)이 그대로 구현합니다.

**목표:** 마지막 라운드가 끝났을 때 돈을 가장 많이 가진 사람이 이깁니다.

**한 라운드의 흐름**

1. **분배:** 술집마다 머니카드 1장이 놓입니다. 남은 1장은 **딜러**가 원하는 술집에 얹습니다(추가 머니카드). 딜러는 라운드마다 돌아갑니다.
2. **카드 내기:** 모두 손패 5장 중 1장을 동시에 엎어서 냅니다. 카드에는 술집 이름이 적혀 있고, 그 술집에만 낼 수 있습니다.
   - **도박꾼(ZOCKER)**: 그 술집의 돈을 노립니다.
   - **경찰(RAZZIA)**: 그 술집을 단속합니다.
   - 모든 카드에는 주사위 눈(1~6)이 있습니다.
3. **술집별 정산:**
   - 도박꾼이 혼자면 그 술집 돈을 **전부** 가져갑니다.
   - 도박꾼이 여럿이면 **협상**합니다. 눈이 가장 높은 사람이 나눌 몫을 제안하고, 나머지가 받아들이거나 거절합니다. 거절하면 **결투**입니다(카드 눈 + 주사위 1개, 높은 쪽이 전부, 동점이면 결투를 건 사람이 이김).
   - 도박꾼과 경찰이 함께 있으면 **단속(RAZZIA)**: 도박꾼은 쫓겨나고 경찰을 낸 사람들이 같은 방식으로 돈을 나눕니다.
   - 경찰만 있거나 아무도 없으면 돈은 그대로 남아 다음 라운드에 쌓입니다.
4. 낸 카드는 버림 더미로 갑니다. 손패를 5장까지 다시 채웁니다. 덱이 떨어지면 버림 더미를 섞어 새 덱을 만듭니다.

**게임 끝:** 머니카드 덱에 남은 카드가 한 라운드 분량 이하가 되면 그 라운드가 마지막(FINAL ROUND)입니다.

**인원별 구성**

| 인원 | 술집 | 라운드당 머니카드 | 카드 덱 |
|---|---|---|---|
| 3인 | 4곳 (Lincoln's, Jazz House 제외) | 5장 | 해당 술집 카드만, 머니카드 일부 제외 (RULE-030) |
| 4~6인 | 6곳 | 7장 | 경찰 눈 5와 도박꾼 눈 3·4 한 장씩 제외 (RULE-029) |
| 7~8인 | 6곳 | 7장 | 전체 (RULE-031) |

머니카드는 $5,000~$50,000 여덟 종류, 총 84장(RULE-003)입니다. 실물 규칙서로 아직 확인하지 못한 값(술집별 카드 눈 분포 등)은
[`docs/08_ASSUMPTIONS.md`](docs/08_ASSUMPTIONS.md)와 코드의 `ASSUMPTION-xxx` 주석에 표시했습니다.

---

## 주요 기능

### 플레이
- **3~8인**, AI 난이도 **쉬움 / 보통 / 어려움**. 어려움은 4인전에서 보통 AI 셋을 상대로 약 31% 승률을 냅니다(공정 몫 25%, `tools/ai_sim.gd`로 측정).
- AI 성격 3가지(신중파·공격파·기회주의자)와 캐릭터 7명(Vito, Lola, Mack, Dutch, Rosie, Sal, Nico). 캐릭터마다 초상화와 고유 대사가 있습니다.
- **저장 슬롯 2개와 이어하기:**
  - 새 게임을 시작할 때 슬롯 1·2 중 하나를 고르고, 그 게임은 카드를 고르는 시점마다 그 슬롯에 자동 저장됩니다.
  - CONTINUE를 누르면 두 슬롯의 내용(인원, 라운드, 저장 시각, 이름)을 보고 고를 수 있습니다.
  - 이미 게임이 있는 슬롯에 새 게임을 시작하면 먼저 묻습니다. 다른 슬롯은 건드리지 않습니다.
  - 엔진이 받아들인 결정은 이어하기 후에도 되돌릴 수 없고, 두 번 반영되지도 않습니다.
- **내 이름:** 게임 준비 카드에서 입력합니다(최대 12자, 한글·영문·기호 가능). 비워 두면 "나"(영어 "You")입니다. AI 캐릭터와 규칙에는 영향이 없습니다.
- **한국어 / English:** 메뉴 오른쪽 위와 멈춤 패널에서 언제든 바꿉니다. 게임 중에 바꿔도 판은 그대로입니다([`docs/I18N.md`](docs/I18N.md)).
- **기록과 업적:** 누적 전적과 업적 13개(첫 승리, 경찰을 불러라, 무패의 결투사, 역전극 등).
- **게임 요약:** 판이 끝나면 라운드별 돈 변화, 결투·단속 내역, 최고 수입을 보여 줍니다.

### 화면과 연출
- **가로(테이블 모드)와 세로(편한 모드)** 레이아웃이 화면 방향에 따라 자동으로 바뀝니다. 기준 해상도는 1280×720 / 720×1280입니다.
- 아르데코·느와르 스타일로 직접 그린 UI입니다. 술집 포스터, 도박꾼·경찰 초상, 캐릭터 그림을 씁니다.
- **술집 정보 카드:** 술집을 누르면 그 술집 카드가 표로 나옵니다. 전체 = 이미 나옴 + 내 손 + 남은 카드로 나뉘고, 남은 도박꾼 눈 목록과 지금까지 낸 기록도 보여 줍니다. 화면에 이미 공개된 정보만 씁니다.
- **추가 머니카드:** 금액이 적힌 카드가 딜러에게서 술집으로 날아갑니다. 그 라운드 동안 술집 위에 금색 표시가 남고, 내가 딜러면 금액을 미리 볼 수 있습니다.
- **협상·결투:** 협상 패널에서 제안 금액을 고르고, 상대 응답과 결투를 진행합니다. 결투는 화면 전체를 쓰는 무대 연출입니다.
- **RAZZIA 연출:** 거리가 어두워지면 빨강·파랑 탐조등이 술집에 멈춥니다. 경찰 카드가 내리꽂히고, 고무도장이 찍히며 판이 흔들리고, 단속 결과가 한 줄로 나옵니다. 깜빡임 없이 처리했습니다(광과민성 규칙).
- **대화 장면(컷신):** 시작, 마지막 라운드, 큰 결투, 큰 단속, 선두 교체, 게임 종료에 나옵니다. 판돈·술집·차이 같은 그 순간의 정보를 담고, 중간 장면은 한 게임에 최대 3번입니다.
- **라운드 장부:** 라운드가 끝나면 누가 어디서 얼마를 왜 벌었는지 보여 주고, 내 라운드를 한 줄로 요약합니다.
- **멈춤:** 진짜로 멈춥니다(AI 차례와 애니메이션 모두 정지). 멈춤 패널에서 설정을 바로 바꿀 수 있습니다.
- **스크롤 없음(Phase 29):** 어떤 화면도 위아래로 밀어 볼 필요가 없습니다.
  - 설정(메뉴·멈춤 패널)은 `게임 진행 / 소리 / 화면 / 조작` 탭으로 나뉘고, 각 탭이 화면에 들어옵니다.
  - 기록은 `전적 / 업적 / 최근 게임`, 게임 요약은 `흐름 / 하이라이트 / 플레이어별` 탭입니다.
  - 게임 방법의 긴 쪽은 `(1/2)`처럼 나뉘어 화살표로 넘깁니다.
  - 메뉴와 술집 정보 카드는 화면이 낮으면 통째로 조금 작아집니다(`W.FitBox`).
- **폰 가로 전용 배치(Phase 29):** 높이 390pt 안팎의 가로 화면에서 자동으로 쓰입니다.
  - 낸 카드 줄을 없애고, 각 플레이어가 낸 뒷면 카드를 그 사람 칩 바로 옆에 둡니다.
  - 그만큼 손패(화면 높이의 41%)·칩·PLAY 버튼을 키웠고, 덱은 PLAY 버튼 위로 옮겼습니다.
  - 칩이 좁으면 DEALER 표시 대신 얼굴에 D 배지를 붙여 이름을 지킵니다.

### 처음 하는 사람을 위해
- **Sal의 튜토리얼:** 정해진 판에서 진짜 규칙으로 3라운드를 직접 해 봅니다.
  1. 혼자 들어가 독식하고, 술집 정보 카드를 봅니다.
  2. 제안 → 거절 → 결투를 겪습니다.
  3. 내가 딜러가 되고, 경찰로 단속합니다.
  - 설명하는 곳만 밝히고, 직접 해 볼 때는 밝힌 곳만 누를 수 있습니다.
- **처음 안내:** 튜토리얼을 건너뛴 사람에게는 필요한 순간에 짧은 안내 상자가 뜹니다. 게임을 방해하지 않으며, 한 판을 끝내면 꺼집니다.
- **게임 방법** 화면에서는 규칙을 엔진의 실제 수치로 설명합니다.

### 소리
- 이 게임을 위해 새로 작곡한 **느와르 재즈 3곡**이 상황에 따라 바뀝니다. 모두 D단조라 이어질 때 조가 튀지 않고, 이음매 없이 반복됩니다.
  | 곡 | 쓰이는 곳 | 성격 |
  |---|---|---|
  | `menu_theme.ogg` | 메뉴, 게임 결과 화면 | 72 BPM 발라드, 피아노 아르페지오·현악 패드·먼 트럼펫 (53초) |
  | `noir_jazz_loop.ogg` | 보통 라운드 | 88 BPM 스윙, 워킹 베이스·브러시 (87초) |
  | `final_round_loop.ogg` | 마지막 라운드 | 116 BPM, 더 빠른 베이스·스틱 라이드·트롬본 오스티나토 (66초) |
- 곡이 바뀔 때는 짧게 교차 페이드합니다. 같은 곡을 다시 요청하면 처음부터 다시 틀지 않고, 한꺼번에 두 곡이 크게 겹치지 않습니다. 곡 파일이 없으면 보통 라운드 곡으로 대신하고, 그것도 없으면 조용히 진행합니다.
- **적응형 믹스:**
  - 카드를 고를 때, 글을 읽을 때, 협상·결투 중에는 음악이 자동으로 물러나거나 먹먹해집니다.
  - 결투·단속 때는 같은 조의 긴장 레이어가 깔립니다.
  - 큰 효과음이 나오면 음악이 잠깐 작아집니다.
- 볼륨 4종(전체·배경음악·효과음·버튼 소리)과 **전체 음소거**(전체 음량 줄의 ON/OFF, M 키, 보기 버튼). 메뉴의 "환경 설정"과 멈춤 패널의 "소리" 탭에서 바꿀 수 있고 저장됩니다.

### 플랫폼과 접근성
- **Steam Deck 대응:**
  - Steam Deck이면 자동으로 감지해 전체 화면과 균형 프리셋을 씁니다(`SteamDeck=1` 또는 기기 정보로 확인). 일반 Linux를 Deck으로 오인하지 않습니다.
  - 성능 프리셋: 고품질 / 균형(60fps) / 배터리 절약(30fps, 화면 변화 없으면 다시 그리지 않음).
  - 게임패드만으로 메뉴부터 게임 끝까지 플레이할 수 있고, 버튼 표시가 쓰는 장치에 맞게 바뀝니다.
- 마우스·터치·키보드·게임패드를 오가면 입력 장치를 자동으로 바꿔 인식합니다.
- 애니메이션 속도(느리게·보통·빠르게), **모션 줄이기**(모든 트윈 생략), 정보를 색으로만 구분하지 않음(이름·글자·주사위 눈을 항상 표시).
- **글자 크기:** 작은 글자는 실제 화면 크기에 맞춰 키웁니다(`T.fs`, 메뉴 포함).
  - 좁은 카드에서는 술집 이름을 줄여(COTTON, HAVANA, JUNGLE, JAZZ) 더 크게 씁니다.
  - 경찰 카드가 너무 작아 글자를 못 쓰면 빨간 띠와 별 모양으로 표시합니다.
  - 측정값은 아래 "알려진 문제"에 있습니다(`tests/text_audit.gd`).

---

## 조작법

| 동작 | 마우스 / 터치 | 키보드 | 게임패드 |
|---|---|---|---|
| 카드·술집 고르기 | 클릭 / 탭 | ← → (↑ ↓) | 십자키 / 왼쪽 스틱 |
| 선택 / 내기 / 확인 | 클릭, PLAY CARD | Enter, Space | A |
| 선택 취소 / 닫기 | 바깥 클릭, 닫기 | Esc | B |
| 멈춤 패널 | 왼쪽 위 ⎋ 버튼 | Esc | 메뉴(Start) |
| 고른 카드의 술집 정보 | 술집 탭 | I | Y |
| 연출 건너뛰기 | SKIP 또는 빈 탁자 탭 | S | X |
| 음소거 | 설정 | M | 보기(Back) |
| 긴 화면 스크롤 | 드래그 / 휠 | – | 오른쪽 스틱 |
| 대화 장면 넘기기 / 끝내기 | 탭 / SKIP | Enter·Space / Esc | A / B |

- 카드를 고른 직후 들어온 Enter 같은 실수 입력은 무시합니다(프롬프트마다 짧은 입력 보호).
- 포커스를 잃어도 방향키나 A를 누르면 가장 위의 버튼으로 포커스가 돌아옵니다.

---

## 설정

메뉴의 "환경 설정 ▸"(따로 열리는 탭 패널)과 게임 중 멈춤 패널의 탭에서 바꿉니다. 저장 위치는 `user://settings.cfg`입니다.

| 항목 | 값 | 기본값 |
|---|---|---|
| 애니메이션 속도 | SLOW ×1.6 / NORMAL / FAST ×0.5 | NORMAL |
| 모션 줄이기 | OFF / ON | OFF |
| 대화 장면 | 전체 / 핵심만(시작·마지막 라운드·종료) / OFF | 전체 |
| 처음 안내 | ON / OFF (한 판을 끝내면 자동 OFF) | ON |
| 언어 | 한국어 / English | 기존 사용자 한국어, 새 설치는 시스템 언어(한국어가 아니면 English) |
| 내 이름 | 최대 12자. 비우면 "나" / "You" | 비어 있음 |
| 전체 음소거 | ON / OFF (M 키) | OFF |
| 분위기 프리셋 | 몰입 / 차분 / 효과음만 | – |
| 볼륨 | 전체·배경음악·효과음·버튼 소리 | 1.0 / 1.0 / 1.0 / 0.8 |
| 창이 비활성이면 음소거 | ON / OFF | ON |
| 성능 | 자동 / 고품질 / 균형 / 배터리 절약 | 자동(휴대용 = 균형, 데스크톱 = 고품질) |
| 화면 | 자동 / 전체 화면 / 창 | 자동(휴대용 = 전체 화면) |
| (내부) 튜토리얼 완료 | – | false |

---

## 프로젝트 구조

```
razzia-godot/
├─ project.godot            메인 씬 ui/main.tscn, 1280×720 기준, stretch canvas_items/expand, 오토로드 2개
├─ run_tests.sh             규칙 엔진 테스트 실행
├─ engine/                  규칙 엔진 (노드 없음, 순수 함수 + Dictionary 상태)
│  ├─ engine.gd             규칙 전부 (RULE-xxx 주석), 액션 처리, 이벤트 로그, 공개 뷰, 저장/불러오기
│  ├─ rng.gd                시드 난수 (JS 레퍼런스와 비트 단위로 같음)
│  └─ util.gd               JSON 정수 복원, 정렬된 비교
├─ ai/ai.gd                 규칙 기반 AI (쉬움/보통/어려움 × 성격 3종), 공개 뷰만 읽음
├─ controller/
│  └─ match_controller.gd   UI ↔ 엔진 사이: AI 차례 진행, 사람 입력에서 멈춤, 이벤트 모으기 (튜토리얼용 AI 대본 연결점)
├─ platform/                오토로드
│  ├─ steam_deck_manager.gd 실행 환경 감지, 화면 모드, 성능 프리셋
│  └─ input_mode_manager.gd 입력 장치 감지, 패드 바인딩, 포커스 복구, 버튼 이름
├─ ui/
│  ├─ main.gd / main.tscn   메뉴 ↔ 게임 ↔ 튜토리얼 전환, 화면 방향에 따른 기준 해상도
│  ├─ menu_screen.gd        메인 메뉴, 게임 준비(인원·난이도), 환경 설정, 튜토리얼 제안
│  ├─ game_screen.gd        게임 보드 최종 클래스: 시작·흐름·사람 입력 대기·이벤트 재생 루프·튜토리얼 연결 (약 250줄)
│  ├─ board/                game_screen을 주제별로 나눈 파일 (각 파일이 앞 파일을 상속하는 사슬)
│  │  ├─ board_base.gd      공유 상태·변수·상수·신호, 작은 도우미, 뒤 파일 함수의 빈 자리(stub)
│  │  ├─ board_layout.gd    화면 만들기, 가로/세로 배치, 손패 부채꼴, 상대 레일, 펠트
│  │  ├─ board_info.gd      술집 정보 카드 집계(화면 기준), 플레이 기록, 이어하기 화면 복원
│  │  ├─ board_input.gd     키·패드·마우스, 손패 선택, 멈춤 패널, 처음 안내 팁
│  │  ├─ board_scenes.gd    대화 장면과 횟수 제한
│  │  ├─ board_fx.gd        머니카드·추가 머니카드 비행, 카드 이동, RAZZIA 연출
│  │  ├─ board_replay.gd    이벤트 하나씩 연출 (라운드, 카드 공개, 술집 정산, 협상, 결투, 지급)
│  │  └─ board_results.gd   라운드 장부, 라운드 한 줄 요약, 게임 끝
│  ├─ nego_panel.gd         협상·결투 패널 (제안 입력, 응답 카드, 결투 무대)
│  ├─ bar_view.gd           술집 카드 (포스터, 돈, 머니카드 수, 놓인 카드, 추가 머니카드 금색 표시)
│  ├─ card_view.gd          손패·미니 카드 (도박꾼/경찰, 주사위 눈)
│  ├─ money_card_view.gd    앞면 머니카드 (추가 머니카드 연출)
│  ├─ raid_fx.gd            RAZZIA 연출 레이어
│  ├─ dialogue_scene.gd     대화 장면 (레터박스, 서류 사진, 이름표)
│  ├─ characters.gd         캐릭터·성격 정보와 대사 (상황별 템플릿)
│  ├─ tutorial_plan.gd      튜토리얼 판 (시드 23, AI 대본)
│  ├─ tutorial_director.gd  튜토리얼 연출 (Sal 말풍선, 스포트라이트, 단계 진행)
│  ├─ help_screen.gd        게임 방법
│  ├─ records.gd / records_screen.gd   전적·업적
│  ├─ game_summary.gd / summary_screen.gd   게임 요약
│  ├─ save_store.gd         저장 슬롯 2개 (체크포인트 + 이후 결정 기록, 직전 사본 .bak, 슬롯 정보)
│  ├─ settings_panel.gd     설정 탭(게임 진행·소리·화면), 메뉴와 멈춤 패널이 함께 씀
│  ├─ settings.gd           설정 저장/불러오기 (언어, 이름, 음소거 포함), 테스트용 파일 분리
│  ├─ i18n.gd               언어 적용·번역 (TranslationServer, 키 = 한국어 원문)
│  ├─ audio.gd              사운드 호스트 (볼륨 그룹, 적응형 믹스, 사이렌)
│  ├─ sound_panel.gd        소리 설정 UI
│  ├─ portrait.gd           캐릭터 초상 (원형)
│  ├─ widgets.gd / tokens.gd   공용 위젯, 색·글꼴·금액 표기·그림 불러오기
│  ├─ flow_trace.gd         입력 흐름 추적 로그 (디버그)
│  └─ felt.gdshader / felt_static.gdshader   테이블 펠트 (배터리 절약 모드는 정지판)
├─ i18n/en.gd               영어 표 (tools/i18n/build_en.py가 생성)
├─ assets/
│  ├─ art/bars/             술집 포스터 6장
│  ├─ art/cards/            도박꾼 초상 6장 + 경찰 1장
│  ├─ characters/ characters_full/   캐릭터 7명 (얼굴 / 상반신)
│  ├─ audio/                배경 음악·긴장·소음 루프, 효과음 (총 43개)
│  └─ fonts/                Cinzel, Playfair Display, Rye, Noto Sans KR (+ OFL 라이선스)
├─ tests/                   자동 테스트 (아래 표), golden/ 정답 로그 52판, fixtures/
├─ tools/                   개발 도구 (아래 표), js/ 레퍼런스 JS 구현
└─ docs/                    설계 문서, 개발 기록, 분석 자료
```

---

## 아키텍처

```
 사람 입력 ──▶ game_screen ──action──▶ MatchController ──▶ Engine.reduce_in_place(state, action)
                 ▲                        │  (AI 차례는 여기서 자동 진행)        │
                 │                        ▼                                    ▼
                 └──── 이벤트 재생 ◀── drain_events() ◀──────────── state["events"] (확정된 사건)
```

1. **엔진이 모든 결과를 정합니다.** UI는 결과를 계산하지 않고 엔진이 확정한 이벤트(`MONEY_PLACED`, `CARDS_REVEALED`, `DUEL_RESOLVED`, `MONEY_AWARDED` 등)를 차례로 연출할 뿐입니다(RULE-034).
2. **재현 가능성:** 난수는 전부 `state["rngState"]`의 시드 RNG를 거칩니다(`randi()` 사용 금지). 같은 시드와 같은 결정이면 같은 게임이 나옵니다.
   - 덕분에 튜토리얼 판을 고정할 수 있고, 이어하기 재생과 버그 재현이 됩니다.
3. **숨은 정보:** AI와 UI는 `Engine.get_public_view(state, pid)`만 읽습니다. 테스트가 공개 뷰와 이벤트에 남의 손패가 새지 않는지 확인합니다.
4. **화면 기준 상태:** 엔진은 연출보다 앞서 있습니다. 술집 정보 카드 같은 "지금 보이는 것" 기준 정보는 화면이 재생한 이벤트로 따로 계산합니다(`_track_cards`).
5. **오류 처리:** 잘못된 액션은 예외 없이 `{ok:false, error:{category, message}}`로 돌아오고 상태는 바뀌지 않습니다. 엔진 불변식이 깨지면 `state["fatal"]`에 기록됩니다.
6. **JS 레퍼런스와 동일:** `tools/js/`의 JS 엔진이 만든 정답 로그 52판(3~8인 × 난이도)과 이벤트가 한 비트도 다르지 않음을 테스트로 보장합니다.

UI에서 엔진을 쓰는 법:

```gdscript
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")

var state = Eng.create_game({"playerCount": 4, "seed": 123, "humanPlayerId": "P1", "aiDifficulty": "NORMAL"})
var ctl = Ctl.new(state)
var pending = ctl.run()          # AI가 둘 수 있는 만큼 진행 → 사람이 할 일 (없으면 null)
# pending["type"] ∈ PLACE_EXTRA_MONEY | SELECT_CARD | MAKE_PROPOSAL | RESPOND
var r = ctl.submit({"type": "SELECT_CARD", "playerId": "P1", "cardId": card_id})   # {ok, pending, error}
for ev in ctl.drain_events():
    await board.play(ev)         # 연출만
```

액션 형식: `PLACE_EXTRA_MONEY{playerId,barId}`, `SELECT_CARD{playerId,cardId}`, `MAKE_PROPOSAL{playerId,allocations}`,
`RESPOND{playerId,response:"ACCEPT"|"DUEL"}`. 저장은 `Eng.serialize_game(state)` / `Eng.load_game(text)`입니다.

GDScript로 옮기면서 주의한 점은 다음과 같습니다. 정수 나눗셈, `round`의 반올림 방향, 불안정 정렬, JS 객체 키 순서를 모두 JS와 같게 맞췄습니다. 자세한 내용은 [`docs/DEV_LOG.md`](docs/DEV_LOG.md) 앞부분을 보세요.

---

## 자산과 라이선스

| 자산 | 출처 / 라이선스 |
|---|---|
| 글꼴 Cinzel, Playfair Display, Rye, Noto Sans KR | SIL Open Font License (`assets/fonts/OFL-*.txt`) |
| 배경 음악 `noir_jazz_loop.ogg`, 긴장 레이어 `tension_loop.ogg` | 이 프로젝트용으로 작곡(`tools/make_music.py`). 악기 소리는 FluidR3_GM 사운드폰트(MIT) |
| 술집 포스터, 카드 초상, 캐릭터 그림 (`assets/art`, `assets/characters*`) | **출처·라이선스 기록 필요** (출시 전 확인) |
| 효과음 (`assets/audio/*.ogg, *.mp3`) | **출처·라이선스 기록 필요** (출시 전 확인) |
| 원작 보드게임 *Razzia* | © Ravensburger / Stefan Dorra. 상업적 배포 전 권리 확인 필요 |

그림 파일이 없으면 코드로 그린 대체 그림이 자동으로 쓰입니다(`ui/tokens.gd: art()`). 같은 이름의 파일을 넣으면 그림이 바뀝니다.

---

## 개발 도구

| 도구 | 하는 일 | 실행 |
|---|---|---|
| `tools/run_all_tests.sh` | 테스트 전부를 차례로 돌리고 결과 표 출력 | `GODOT=... ./tools/run_all_tests.sh` (빠르게: `QUICK=1`) |
| `tools/ci_check.sh` | CI용: 대소문자 경로 → 임포트 → 전체 파싱 → 헤드리스 부팅 → 엔진 테스트 → 튜토리얼 판 → 컨트롤러 플레이 | `GODOT=... ./tools/ci_check.sh` |
| `tools/check_paths.py` | 모든 `res://` 경로가 정확한 대소문자로 있는지 검사 (Linux/SteamOS 대비) | `python3 tools/check_paths.py` |
| `tools/parse_all.gd` | 모든 GDScript 컴파일 검사 | `godot --headless --path . --script res://tools/parse_all.gd` |
| `tools/find_tutorial_seed.gd` | 튜토리얼 판이 계획대로 흘러가는지 검사 / 새 시드 찾기 | `... --script res://tools/find_tutorial_seed.gd -- check=23` |
| `tools/ai_sim.gd` | AI끼리 수천 판: 난이도 사다리, 성격별 성향 측정 | `... --script res://tools/ai_sim.gd` |
| `tools/make_music.py` | 배경 음악 3곡·긴장 레이어 생성 (mido + FluidSynth + FluidR3_GM, ffmpeg) | `python3 tools/make_music.py` |
| `tools/ui_shots.gd` | 메뉴·설정 탭·게임 방법 전 쪽·기록 탭을 찍고, 스크롤 영역이나 화면 밖 글자·버튼이 있으면 실패 | `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/ui_shots.gd -- w=844 h=390 out=/tmp/s lang=en` |
| `tools/i18n/build_en.py` | 코드의 한국어 문장과 영어 표를 맞춰 보고 `i18n/en.gd` 생성(빠진 번역·자리 표시 불일치 = 실패) | `python3 tools/i18n/build_en.py` |
| `tools/regenerate_golden.sh` | JS 레퍼런스로 정답 로그 재생성 (Node 18+) | `./tools/regenerate_golden.sh` |
| `tests/ui_gallery.gd` | UI 부품 견본 이미지 | `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/ui_gallery.gd -- out.png` |

---

## 테스트

모든 테스트는 Godot 스크립트(`extends SceneTree`)이고 종료 코드 0이면 통과입니다. 연출 시간이 정확하도록 `--fixed-fps 60`으로 돌립니다.
테스트는 실제 설정·저장·전적 파일을 건드리지 않습니다. 테스트로 실행되면(`res://tests/`·`res://tools/` 스크립트이거나 `RAZZIA_TEST=1`)
`Settings.test_file()`이 `user://test_<pid>_settings.cfg`처럼 프로세스별 파일을 쓰고, 끝날 때 지웁니다. 그래서 테스트는 늘 기본 설정에서 시작합니다.
연출 시간 측정이 흔들리지 않도록 `tools/run_all_tests.sh`는 테스트를 차례로 실행합니다.
`RAZZIA_NO_DIALOGUE=1`이면 대화 장면을 끕니다(연출 타이밍 테스트용).

| 분류 | 테스트 | 확인하는 것 |
|---|---|---|
| 규칙 엔진 | `run_tests.gd` | RNG, 정답 로그 52판 재생, AI 결정 일치, 저장/불러오기, 규칙 시나리오, 숨은 정보, 안티치트 |
| AI | `ai_levels_test.gd` | 난이도마다 완주, 쉬움 < 보통 < 어려움 |
| 실제 입력 QA | `qa_playthrough_test.gd` | 메인 씬부터 마우스·터치·키로 한 판 끝까지 |
| | `qa_gamepad_playthrough_test.gd` | 게임패드만으로 한 판 끝까지, 포커스 끊김 없음 (`audit=1`: 글자 크기 감사) |
| | `qa_tutorial_test.gd` | 튜토리얼 끝까지 (`pad=1`, `skip=1`, 세로 화면) |
| | `qa_resume_test.gd` / `qa_stability_test.gd` | 중간에 나갔다 이어하기, 반복 전환 시 노드 누수 없음 |
| 화면 흐름 | `ui_smoke.gd`, `ui_input_test.gd` | 봇/키보드로 한 판 (xvfb) |
| | `ui_mouse_hit_test.gd`, `ui_touch_skip_test.gd`, `ui_enter_flow_test.gd`, `ui_exit_menu_test.gd`, `ui_pad_menu_test.gd` | 클릭 막힘, 실수 입력, 메뉴 조작 |
| | `ui_pause_test.gd`, `ui_round_start_test.gd`, `ui_razzia_skip_test.gd` | 멈춤, 라운드 시작, 단속 연출 길이와 SKIP |
| 정보 표시 | `ui_venue_info_test.gd`, `ui_extra_money_census_test.gd` | 술집 정보 카드 집계가 실제 덱·손패와 일치, 추가 머니카드 표시 |
| | `ui_round_note_test.gd`, `rules_help_test.gd`, `summary_test.gd`, `records_test.gd` | 라운드 한 줄 요약, 게임 방법 수치, 요약·기록 정확도 |
| 협상·결투 | `ui_nego_choice_test.gd`, `ui_duel_stage_test.gd`, `ui_duel_flow_test.gd` | 응답 카드 수치, 결투 단계, 튜토리얼 판으로 실제 제안→결투→결과까지 |
| 이야기 | `ui_dialogue_test.gd`, `ui_scene_story_test.gd`, `ui_coach_test.gd` | 대화 장면 조작, 대사 빈칸·조사·길이, 처음 안내 |
| 저장 | `save_resume_test.gd`, `ui_resume_test.gd` | 받아들인 결정은 되돌릴 수 없음, 이어하기 화면 = 새 게임 화면 |
| 언어·이름·슬롯 | `i18n_slots_test.gd`, `restart_test.gd` (두 프로세스) | 번역 표, 영어 메뉴 전 화면, 이름 정리·저장, 슬롯 2개 독립·덮어쓰기 확인·손상 파일·.bak 복구·예전 파일, 게임 중 언어 변경, 재실행 후 유지 |
| 스크롤 없음 | `tools/ui_shots.gd` (4개 해상도·두 언어), 코드에 `ScrollContainer` 없음 검사 | 어느 화면에도 스크롤 영역이 없고 모든 글자·버튼이 화면 안 |
| 영어 전체 플레이 | `qa_gamepad_playthrough_test.gd -- lang=en`, `qa_tutorial_test.gd -- lang=en`, `qa_playthrough_test.gd -- lang=en` | 한 판(튜토리얼 포함) 동안 화면에 한글이 하나도 남지 않음 |
| 소리 | `ui_audio_test.gd`, `ui_audio_mix_test.gd`, `audio_cue_test.gd` | 스트림·루프·볼륨 그룹, 적응형 믹스, 곡 전환(재시작 없음·겹침 없음·파일 없음 대체), 음소거 |
| 플랫폼 | `platform_test.gd` (`SteamDeck=1 ... -- expect=deck`), `perf_idle_test.gd` | 환경 감지, 프리셋, 입력 모드, 대기 화면 그리기 횟수 |

화면 캡처: 대부분의 QA 테스트는 `shots=/경로/접두사`를 주면 단계별 PNG를 저장합니다(`xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 ...`).

---

## 저장 파일

`user://`는 OS별 Godot 사용자 폴더입니다(Linux: `~/.local/share/godot/app_userdata/Razzia Mobile/`).

| 파일 | 내용 |
|---|---|
| `settings.cfg` | 설정 (`[general]` 언어·이름, `[anim]`, `[audio]`, `[display]`). 테스트 실행 중에는 `test_<pid>_*` 파일을 따로 쓰고 지움 |
| `autosave.json` | **슬롯 1** (예전 버전의 자동 저장 파일 그대로): 체크포인트 상태 + 이후 확정된 결정 목록 + AI 난수 상태 + `format`·`savedAt`(없어도 읽힘) |
| `autosave_2.json` | **슬롯 2** (형식은 슬롯 1과 같음) |
| `*.json.bak` | 각 슬롯의 직전 저장. 본 파일이 손상되면 이것으로 이어하기 |
| `*.corrupt.<시각>.json` | 읽을 수 없는 저장은 지우지 않고 이 이름으로 보관 |
| `records.json` | 전적·업적·최근 20판 기록 |

---

## 문서

| 문서 | 내용 |
|---|---|
| [`docs/01_GAME_OVERVIEW.md`](docs/01_GAME_OVERVIEW.md) | 게임 개요와 방향 |
| [`docs/02_RULEBOOK.md`](docs/02_RULEBOOK.md) | 규칙 원본 (RULE-001~035) |
| [`docs/03_GAME_FLOW.md`](docs/03_GAME_FLOW.md) | 상태 기계와 흐름 |
| [`docs/04_GAME_DATA.md`](docs/04_GAME_DATA.md) | 데이터 구조 |
| [`docs/05_UI_UX.md`](docs/05_UI_UX.md), [`docs/UI_UX_DESIGN.md`](docs/UI_UX_DESIGN.md) | UI/UX 원칙과 디자인 |
| [`docs/06_AI_DESIGN.md`](docs/06_AI_DESIGN.md) | AI 설계 |
| [`docs/07_DEVELOPMENT_RULES.md`](docs/07_DEVELOPMENT_RULES.md) | 개발 규칙 |
| [`docs/08_ASSUMPTIONS.md`](docs/08_ASSUMPTIONS.md) | 미확정 규칙 가정 |
| [`docs/RULES_CHANGELOG.md`](docs/RULES_CHANGELOG.md) | 규칙 문서 변경 기록 |
| [`docs/I18N.md`](docs/I18N.md) | 다국어 구조, 문장 추가 방법, 번역하지 않는 것 |
| [`docs/DEV_LOG.md`](docs/DEV_LOG.md) | 개발 단계별 기록 (Phase 1~29, 예전 README) |
| `docs/balatro_reference.md`, `docs/phase6_1_analysis.md` | 참고 분석 |

---

## 개발 규칙

자세한 내용은 [`docs/07_DEVELOPMENT_RULES.md`](docs/07_DEVELOPMENT_RULES.md)에 있습니다. 핵심은 다음과 같습니다.

- **UI는 결과를 정하지 않습니다.** 규칙은 엔진에만 두고, 화면은 이벤트를 재생합니다.
- 난수는 시드 RNG로만 씁니다. 숨은 정보는 공개 뷰로만 읽습니다.
- 엔진이나 AI를 바꾸면 정답 로그가 달라질 수 있습니다.
  - JS 레퍼런스를 함께 고치고 `tools/regenerate_golden.sh`로 정답 로그를 다시 만듭니다.
  - 튜토리얼 판 검사(`find_tutorial_seed.gd -- check=23`)도 다시 확인합니다.
- 연출을 추가할 때는 SKIP, 모션 줄이기, 속도 설정을 모두 지원하고, 끝나면 남는 노드나 트윈이 없어야 합니다. 깜빡임은 금지입니다.
- 마우스 클릭 판정은 z_index가 아니라 **트리 순서**를 따릅니다. 화면을 덮는 노드는 나중에 추가하거나 `_add_below_overlays`를 쓰세요.
- 글자는 1280×800 기준 최소 10px 이상, 버튼·라벨은 12px 이상을 목표로 합니다.
- 바꾼 뒤에는 `tools/run_all_tests.sh`(최소 `QUICK=1`)를 돌립니다.

---

## 알려진 문제와 다음 할 일

중요도 순입니다. 상세 분석은 개발 기록과 함께 관리합니다.

**출시 전에 꼭 해야 할 일**
- 그림·효과음의 출처와 라이선스 확인, 원작 상표·권리 확인.
- Steam Deck 실기기 검증(성능·배터리·발열·절전 복귀·Proton). 내보내기 설정(`export_presets.cfg`)이 아직 없습니다.
- 실물 규칙서로 미확정 가정(`docs/08_ASSUMPTIONS.md`, 카드 눈 분포 등)을 확인하고, 규칙 문서 03·08과 엔진 사이의 남은 불일치(RULE-021, ASSUMPTION-019)를 정리.

**코드·테스트 정비**
- (Phase 27에서 해결) `game_screen.gd` 나누기, `ui_duel_flow_test` 다시 쓰기, 테스트용 설정 경로 분리.
- `ui/board/` 파일들은 서로의 함수를 이름으로 부릅니다. 뒤 파일 함수를 앞 파일에서 부르려면 `board_base.gd`에 빈 자리(stub)를 두어야 합니다.

**플레이 경험**
- 휴대폰 가로 화면의 글자 크기. 화면 전체가 1280×720 기준으로 비례 축소되므로 폰 가로(844×390)에서는 작은 글자가 여전히 작습니다.
  Phase 28 측정값(`qa_gamepad_playthrough_test.gd -- audit=1`, 한 판 전체에서 가장 작은 값):

  | 화면 | 버튼·라벨 최소 (전 → 후) | 직접 그린 글자 최소 (전 → 후) |
  |---|---|---|
  | 1280×720 | 12.0 → 12.0px | 9.0 → 10.0px |
  | 1280×800 (Steam Deck) | 11.6 → 11.6px | 10.0 → 10.0px |
  | 2560×1080 | 12.0 → 12.0px | 10.5 → 10.5px |
  | 1024×768 | 10.4 → 10.4px (PICK A CARD 잘림 해결) | 8.0 → 8.0px |
  | 800×600 | 8.1 → 10.0px | 6.2 → 6.9px |
  | 430×932 (폰 세로) | 6.9 → 10.7px | 5.0 → 6.6px |
  | 844×390 (폰 가로) | 7.0 → 8.2 → 8.5px (Phase 29) | 4.3 → 4.9 → 6.5px (Phase 29, 폰 가로 배치) |

  Phase 29의 폰 가로 배치로 손패 카드가 크게 커졌습니다(화면 높이의 41%). 가장 작은 글자는 이제 술집 포스터 위 미니카드의 ZOCKER 글자(6.5px)입니다.
- Steam Deck·휴대폰 실기기에서는 아직 확인하지 않았습니다(해상도 흉내만 냄).
