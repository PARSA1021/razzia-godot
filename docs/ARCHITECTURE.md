# Razzia Mobile — Architecture & Project Structure Guide

이 문서는 Razzia Mobile 프로젝트의 전체 소프트웨어 구조, 계층별 책임, 파일 배치 규칙 및 테스트·CI 검증 가이드라인을 정의합니다.

---

## 1. 아키텍처 핵심 원칙

1. **엄격한 단방향 계층 분리 (Strict Unidirectional Layering)**:
   - `engine/`은 순수 게임 룰과 상태 머신, 결정적 Mulberry32 RNG만을 다루며, UI 노드나 컨트롤러, 오디오, 렌더링에 일체 의존하지 않습니다.
   - `ai/`는 엔진 상태만을 관찰하여 의사결정(카드 선택, 목표 술집, 협상 제안/수락, 결투 반응)을 계산하며 UI에 의존하지 않습니다.
   - `controller/`는 엔진과 비동기 UI 흐름, AI 턴 디스패치를 중재합니다.
   - `ui/`는 화면 렌더링, 사용자 입력 처리, 시각·음향 피드백을 담당하며 게임 규칙을 독자적으로 재계산하지 않습니다.
   - `platform/`은 Steam Deck, 터치, 게임패드, 마우스 등 하드웨어 입력 모드와 디스플레이 프로파일을 전역 관리합니다.

2. **결정적 난수 및 규칙 보존 (Deterministic RNG & Golden Replays)**:
   - 52개 시드 골든 리플레이 검증(`tests/run_tests.gd`)을 통해 엔진 상태 전이와 불변식이 항상 100% 동일함을 보장합니다.

3. **샌드박스 저장소 및 하위 호환성 (Zero-Pollution Persistence)**:
   - 런타임 게임 데이터는 `user://settings.cfg`, `user://autosave.json`, `user://records.json`에 저장됩니다.
   - 테스트 실행 시 자동으로 `user://test_<pid>_*`로 격리되어 유저 실데이터 오염을 방지합니다.

---

## 2. 전체 디렉토리 구조 및 역할

```text
razzia-godot/
├── project.godot                  # Godot 4.3 프로젝트 설정 및 AutoLoad 정의
├── README.md                      # 프로젝트 개요 및 빌드 가이드
├── run_tests.sh                   # 헤드리스 테스트 간이 실행 셸
│
├── engine/                        # [엔진 계층] 순수 게임 룰 및 상태 머신 (UI 무의존)
│   ├── engine.gd                  # 핵심 게임 루프, 카드 분배, 술집 입찰, 단속 정산, 결투 판정
│   ├── relic_manager.gd           # 로그라이크 유물 정의, 구매 상태, 규칙 훅 인터셉터
│   ├── rng.gd                     # JS mulberry32 호환 32-bit 결정적 난수 생성기
│   └── util.gd                    # 정규 직렬화 및 배열 유틸리티
│
├── controller/                    # [컨트롤러 계층] 엔진-UI 비동기 턴 중재자
│   └── match_controller.gd       # AI 비동기 행동 타이밍, 사용자 액션 디스패치, 이벤트 포워딩
│
├── ai/                            # [AI 계층] 컴퓨터 플레이어 휴리스틱
│   └── ai.gd                      # 난이도별(EASY/NORMAL/HARD), 성향별(보수/공격/기회) 의사결정
│
├── platform/                      # [플랫폼 계층] 하드웨어 및 입력 추상화 (AutoLoad)
│   ├── input_mode_manager.gd      # TOUCH / MOUSE / GAMEPAD / KEYBOARD 실시간 자동 전환
│   └── steam_deck_manager.gd      # SteamOS 감지, 배터리 절약(30fps), 전원 및 화면 모드
│
├── i18n/                          # [현지화 계층] 다국어 런타임 테이블
│   └── en.gd                      # 한국어 키 -> 영어 번역 매핑 테이블 (자동 생성)
│
├── ui/                            # [UI 계층] 사용자 인터페이스, 렌더링 및 프레젠테이션
│   ├── main.tscn                  # 게임의 유일한 씬 루트 노드 (Control)
│   ├── main.gd                    # 화면 전환 라우터 (Menu <-> Game <-> Tutorial <-> Records <-> Help)
│   ├── menu_screen.gd             # 메인 메뉴 (클래식/유물 모드 선택, 인원, 난이도, 새 게임, 이어하기)
│   ├── game_screen.gd             # 메인 게임 테이블 컨테이너 및 컨트롤러 바인딩
│   ├── help_screen.gd             # 인게임 룰북, 바 카드 도감, 조작 가이드
│   ├── records_screen.gd          # 역대 전적 및 13종 업적 오버레이
│   ├── summary_screen.gd          # 라운드 및 최종 결산 스크린
│   ├── game_summary.gd            # 최종 랭킹 및 통계 포맷팅
│   ├── nego_panel.gd              # 협상 모달 팝업 및 주사위 결투 연출
│   ├── settings_panel.gd          # 환경 설정 탭 패널 (게임 / 소리 / 화면)
│   ├── sound_panel.gd             # 퀵 사운드 조절 토글
│   ├── dialogue_scene.gd          # 캐릭터 컷씬 대사 연출 및 타이핑 이펙트
│   ├── bar_view.gd                # 술집 카드, 금고 플라크, 판돈 칩 렌더링
│   ├── card_view.gd               # 플레이어 손패, 머니카드, 조커 및 바 전용 단속 카드
│   ├── money_card_view.gd         # 바 중앙 판돈 스택 표시
│   ├── portrait.gd                # 감정 상태별 틴트 및 호흡 애니메이션 아바타
│   ├── characters.gd              # 캐릭터 성향, 이름, 감정 팔레트 정의
│   ├── tokens.gd                  # 아르데코 프로시저럴 토큰 렌더링 및 에셋 로더
│   ├── widgets.gd                 # 아르데코 표준 UI 위젯 (버튼, 라벨, 세그먼트, 모달)
│   ├── raid_fx.gd                 # 경찰 단속 사이렌 및 서치라이트 시각 효과
│   ├── audio.gd                   # BGM 믹서, 프로시저럴 SFX 신디사이저, 보이스 바크
│   ├── save_store.gd              # 게임 슬롯 1/2 자동 저장, 직렬화, 복구 로직
│   ├── records.gd                 # 유저 전적 및 업적 저장소
│   ├── settings.gd                # 유저 환경 설정 관리자 (user://settings.cfg)
│   ├── i18n.gd                    # 텍스트 현지화 룩업 및 슬롯 포맷터
│   ├── tutorial_director.gd       # 튜토리얼 시퀀스 연출 감독
│   ├── tutorial_plan.gd           # 튜토리얼 전용 스크립트 덱 및 결정론 시나리오
│   ├── flow_trace.gd              # 런타임 상태머신 추적 디버거
│   ├── felt.gdshader              # 프로시저럴 펠트 테이블 셰이더
│   ├── felt_static.gdshader       # 저사양 정적 펠트 셰이더
│   └── board/                     # 게임 테이블 서브시스템
│       ├── board_base.gd          # 테이블 베이스 컨트롤
│       ├── board_layout.gd        # 카드/바 좌표 배치 및 황동 레일 드로잉
│       ├── board_input.gd         # 마우스/터치/패드 입력 라우터
│       ├── board_replay.gd        # 엔진 이벤트 애니메이션 재생기
│       ├── board_results.gd       # 단속 및 결투 정산 오케스트레이터
│       ├── board_fx.gd            # 부유 숫자, 카메라 셰이크, 파티클 효과
│       ├── board_scenes.gd        # 시네마틱 카메라 전환
│       ├── board_info.gd          # 바 툴팁 및 라운드 노트
│       └── black_market_panel.gd  # 암시장 상점 모달 UI
│
├── assets/                        # [에셋 리소스] 게임 내 그래픽, 오디오, 폰트
│   ├── art/
│   │   ├── bars/                  # 6개 클럽 포스터 (.jpg)
│   │   └── cards/                 # 조커 카드 및 클럽별 특화 단속 카드 (.jpg)
│   ├── audio/                     # BGM 루프 및 SFX 사운드 (.ogg, .mp3)
│   ├── characters/                # 소형 캐릭터 아바타 (.png)
│   ├── characters_full/           # 대형 컷씬용 캐릭터 전신 일러스트 (.png)
│   └── fonts/                     # 게임 폰트 (.ttf) 및 라이선스 (.txt)
│
├── tests/                         # [테스트 스위트] 자동화 검증 도구
│   ├── run_tests.gd               # 핵심 골든 엔진 테스트 (52개 시드, 불변식, 109 체크)
│   ├── relic_system_test.gd       # 유물 시스템 단위/불변식 테스트 (61 체크)
│   ├── black_market_test.gd       # 암시장 상점 및 경제 보존 테스트 (44 체크)
│   ├── ui_duel_stage_test.gd      # 주사위 결투 스테이지 및 역전승 테스트 (25 체크)
│   ├── ui_character_alive_test.gd # 캐릭터 감정 및 호흡 애니메이션 테스트 (19 체크)
│   ├── ui_dialogue_test.gd        # 다이얼로그 컷씬 흐름 테스트 (19 체크)
│   ├── ui_ux_audit_test.gd        # UI/UX 카드 가시성 및 입력 가드 테스트 (8 체크)
│   ├── i18n_slots_test.gd         # 다국어 및 세이브 슬롯 무결성 테스트 (60 체크)
│   ├── qa_playthrough_test.gd     # 1280x800 풀 자동화 플레이스루
│   ├── qa_gamepad_playthrough_test.gd # 가상 패드 기반 풀 플레이스루 (한/영)
│   ├── qa_tutorial_test.gd        # 튜토리얼 엔드투엔드 테스트
│   ├── golden/                    # JS 원작 레퍼런스 골든 리플레이 54개 (.json)
│   └── fixtures/                  # 하위 호환 테스트용 세이브 픽스처 (.json)
│
├── tools/                         # [개발 및 CI 도구]
│   ├── ci_check.sh                # Linux / macOS / Steam Deck CI 점검 스크립트
│   ├── run_all_tests.sh           # 전체 테스트 자동화 러너 (QUICK 모드 지원)
│   ├── check_paths.py             # Linux 대소문자 경로 및 동적 경로 정밀 검사
│   ├── parse_all.gd               # 전체 GDScript 컴파일 구문 파싱 검사
│   ├── find_tutorial_seed.gd      # 튜토리얼 시나리오 시드 검증기
│   ├── i18n/                      # 영어 사전 모듈 및 빌더 (`build_en.py`)
│   └── js/                        # 원작 JavaScript 레퍼런스 엔진 및 골든 생성기
│
└── docs/                          # [기획 및 개발 문서]
    ├── .gdignore                  # Godot 리소스 스캐너 제외 설정 (30MB 이미지 임포트 방지)
    ├── ARCHITECTURE.md            # 본 아키텍처 및 폴더 구조 가이드
    ├── 01_GAME_OVERVIEW.md        # 게임 개요
    ├── 02_RULEBOOK.md             # 공식 규칙서
    ├── 03_GAME_FLOW.md            # 턴 진행 흐름
    ├── 04_GAME_DATA.md            # 게임 데이터 명세
    ├── 05_UI_UX.md                # UI/UX 명세
    ├── 06_AI_DESIGN.md            # AI 설계 명세
    └── 07_DEVELOPMENT_RULES.md    # 개발 규칙
```

---

## 3. 새로운 파일 추가 기준 (Placement Rules)

향후 신규 기능 개발 시 다음 기준에 따라 파일을 배치해야 합니다:

| 파일 종류 | 권장 배치 경로 | 주의사항 |
|---|---|---|
| **새 게임 규칙 / 상태 로직** | `engine/` | 절대 UI 노드(`Node`, `Control`)를 상속하거나 `res://ui/`를 임포트하지 말 것. 순수 GDScript(`RefCounted`)로 작성. |
| **새 AI 성향 / 전략 모델** | `ai/` | `engine/`의 공개 인터페이스만 참조할 것. |
| **새 풀스크린 화면** | `ui/` (`*_screen.gd`) | `ui/main.gd`의 화면 전환 시퀀스에 등록할 것. |
| **새 모달 팝업 / 다이얼로그** | `ui/` (`*_panel.gd`) | `ui/widgets.gd`의 표준 아르데코 모달 스타일을 활용할 것. |
| **새 테이블 시각 연출** | `ui/board/` (`board_*.gd`) | `BoardBase`의 서브 컨트롤러 패턴을 따르고, 이벤트 기반으로 구동할 것. |
| **새 카드 / 칩 / 아바타 뷰** | `ui/` (`*_view.gd`) | 자체 `_draw()` 프로시저럴 드로잉과 에셋 로딩 폴백을 모두 갖출 것. |
| **새 사운드 효과 및 음악** | `assets/audio/` | `.ogg`(루프 음악) 또는 `.mp3`(짧은 효과음) 형식 사용. `ui/audio.gd`에 큐 등록. |
| **새 일러스트 에셋** | `assets/art/` | 정확한 대소문자 파일명 유지. `tools/check_paths.py`의 `DYNAMIC`에 ID 패턴 등록. |
| **새 단위/통합 테스트** | `tests/` (`*_test.gd`) | `tools/run_all_tests.sh`에 등록하여 CI에서 상시 자동 검증되도록 할 것. |
| **새 개발용 스크립트** | `tools/` | 런타임 릴리스 빌드에 포함되지 않는 순수 보조 도구로 유지할 것. |
| **새 문서 및 다이어그램** | `docs/` | `docs/.gdignore`가 적용되어 있으므로 엔진 임포트 걱정 없이 자유롭게 추가 가능. |

---

## 4. 다국어 및 텍스트 관리 가이드

1. **한국어가 기본 키**: 소스 코드 내 모든 사용자 노출 텍스트는 한국어 문자열 리터럴로 작성하며, `T.t("텍스트")` 또는 `I18n.t("텍스트")`로 감쌉니다.
2. **영어 사전 등록**: 새 텍스트가 추가되면 `tools/i18n/en_zz_polish.py`에 영어 번역을 추가합니다.
3. **사전 컴파일**: `python3 tools/i18n/build_en.py`를 실행하여 누락된 번역이 없는지(problems: 0) 확인하고 `i18n/en.gd`를 재생성합니다.

---

## 5. 자동화 검증 명령어 요약

| 검증 단계 | 명령어 | 점검 내용 |
|---|---|---|
| **경로 검사** | `python3 tools/check_paths.py` | Linux 대소문자 및 동적 리소스 경로 일치 검사 |
| **스크립트 파싱** | `godot --headless --path . --script res://tools/parse_all.gd` | 95개 전체 GDScript 컴파일 및 문법 오류 검사 |
| **골든 엔진 테스트** | `godot --headless --path . --script res://tests/run_tests.gd` | 52개 시드 골든 리플레이, RNG 결정론, 109개 불변식 |
| **유물/암시장 테스트**| `godot --headless --fixed-fps 60 --path . --script res://tests/relic_system_test.gd`<br>`godot --headless --fixed-fps 60 --path . --script res://tests/black_market_test.gd` | 유물 3종 효과, 자금 보존 법칙, 세이브/로드 무결성 |
| **다국어/세이브 검사**| `godot --headless --fixed-fps 60 --path . --script res://tests/i18n_slots_test.gd` | 영문 모드 시 한글 잔존 여부, 세이브 손상 복구 |
| **CI 쾌속 검증** | `GODOT="/path/to/godot" QUICK=1 ./tools/ci_check.sh` | 경로, 임포트, 전체 파싱, 메인씬 부팅(120프레임) |
| **통합 쾌속 검증** | `GODOT="/path/to/godot" QUICK=1 ./tools/run_all_tests.sh` | 엔진, AI, 유물, 암시장, 핵심 UI 및 게임패드 플레이스루 |
