# 🍸 RAZZIA — The 1927 Chicago Underground

<p align="center">
  <strong>1927년 시카고, 금주법 시대의 밤거리를 지배하라.</strong><br>
  1992년 Stefan Dorra의 전설적인 보드게임 <em>Razzia</em>를 완벽하게 디지털로 계승한 동시 카드 선택 심리 베팅 게임
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Engine-Godot%204.3%20Stable-478cbf?logo=godotengine&logoColor=white" alt="Godot Engine">
  <img src="https://img.shields.io/badge/Language-GDScript%202.0-blue" alt="GDScript">
  <img src="https://img.shields.io/badge/Renderer-OpenGL%20Compatibility-green" alt="OpenGL Compatibility">
  <img src="https://img.shields.io/badge/Tests-109%20Checks%20PASS-brightgreen" alt="109 Checks Pass">
  <img src="https://img.shields.io/badge/Platform-PC%20%7C%20Steam%20Deck%20%7C%20Mobile-orange" alt="Platforms">
  <img src="https://img.shields.io/badge/Steam%20Status-Release%20Audit%20Complete-purple" alt="Steam Release Audit">
</p>

---

## 📑 목차 (Table of Contents)

1. [게임 소개 (Introduction)](#1-게임-소개-introduction)
2. [게임 핵심 특징 (Core Features)](#2-게임-핵심-특징-core-features)
3. [게임 플레이 방법 (How to Play)](#3-게임-플레이-방법-how-to-play)
4. [기술 스택 및 아키텍처 (Technology Stack)](#4-기술-스택-및-아키텍처-technology-stack)
5. [프로젝트 실행 및 테스트 가이드 (Getting Started)](#5-프로젝트-실행-및-테스트-가이드-getting-started)
6. [Steam 출시 준비 현황 (Steam Release Status)](#6-steam-출시-준비-현황-steam-release-status)
7. [디렉터리 구조 (Directory Structure)](#7-디렉터리-구조-directory-structure)
8. [공식 개발 및 출시 문서 포털 (Documentation Portal)](#8-공식-개발-및-출시-문서-포털-documentation-portal)

---

## 1. 게임 소개 (Introduction)

### 1.1 기본 정보
- **공식 명칭:** RAZZIA (부제: The 1927 Chicago Underground) — *Steam 출시 시 독자 브랜드 리브랜딩 예정*
- **원작 영감:** 1992년 Stefan Dorra 설계, Ravensburger 출판의 고전 보드게임 *Razzia*의 동시 선택 심리 베팅 메커니즘
- **장르:** 동시 선택 심리 베팅 보드게임 (Simultaneous Card Action) / 로그라이크 카드 전략
- **플레이어 수:** 3인 ~ 8인 지원 (1인 플레이어 vs 2~7인 AI 라이벌)
- **플레이 타임:** 매치당 약 10분 ~ 15분
- **목표 플랫폼:** PC (Windows, Linux, macOS), Steam Deck (SteamOS Verified) 및 모바일 (Android, iOS)

### 1.2 게임 콘셉트 및 세계관
1927년 미국 시카고, 금주법(Prohibition)의 시대. 합법적인 술이 사라진 도시의 밤거리는 마피아 패밀리들이 운영하는 6개의 비밀 주점(**스피크이지, Speakeasy**)으로 번영을 누립니다.  
플레이어는 시카고 암흑가에 이름을 떨치기 시작한 야심 찬 도박꾼이 되어, 매일 밤 비밀 주점 지하 금고에 쌓이는 수만 달러의 검은 돈을 차지하기 위해 7인의 개성 넘치는 마피아 라이벌들과 치열한 수 싸움을 벌입니다.

### 1.3 플레이어가 경험하는 핵심 재미
1. **블러핑과 예측의 스릴:** 모든 플레이어가 손패 중 1장을 비밀리에 내려놓고 동시에 공개(Reveal)합니다. 상대의 목적지를 꿰뚫고 홀로 빈 술집을 털어먹을 때의 쾌감!
2. **협상과 배짱의 줄타기:** 같은 술집에 여러 도박꾼이 겹치면 제안 슬라이더를 통해 판돈을 나눕니다. 욕심을 부리다 거절당하면 모든 것을 잃는 주사위 결투로 이어집니다.
3. **건곤일척의 주사위 결투:** 6면체 주사위를 굴려 승자가 판돈을 독식합니다. 동점 시 목숨을 걸고 거절한 도전자(Challenger)에게 승리가 주어지는 극적인 역전의 묘미!
4. **경찰 급습(RAZZIA)의 공포와 통쾌함:** 도박꾼들이 몰린 바에 경찰 카드가 등장하면 도박꾼들은 단 한 푼도 건지지 못하고 쫓겨납니다. 경찰 카드를 낸 자들이 판돈을 압류해 챙깁니다.

---

## 2. 게임 핵심 특징 (Core Features)

| 핵심 시스템 | 구현 여부 | 설명 |
|---|:---:|---|
| **클래식 모드 (Classic)** | **구현 완료** | 원작 룰 100% 준수 (3~8인, 크루피에 로테이션, 109종 불변식 통과) |
| **유물 모드 (Relic Mode)** | **구현 완료** | 스타터 드래프트 + 8종 고유 유물 + 라운드 간 암시장 상점 (로그라이크) |
| **3단계 AI 시스템** | **구현 완료** | EASY(입문), NORMAL(표준), HARD(카운팅 및 1위 추구 기댓값 역산) |
| **7인의 개성파 AI 라이벌** | **구현 완료** | Vito, Lola, Mack, Dutch, Rosie, Sal, Nico (3대 성향 및 실시간 대사) |
| **듀얼 반응형 레이아웃** | **구현 완료** | PC/스팀덱 가로 와이드(1280×720) / 스마트폰 세로 모바일(720×1280) 동시 지원 |
| **스팀덱 최적화 (Steam Deck)** | **구현 완료** | 1280×800 꽉 찬 화면, XInput 컨트롤러 네이티브, 30/60fps 절전 프로파일 |
| **원자적 듀얼 슬롯 저장** | **구현 완료** | 클래식/유물 2슬롯 분리, 임시파일 교체 원자적 세이브 (240개 중단점 검증 완료) |
| **실시간 다국어 지원** | **구현 완료** | 한국어 / English 인게임 즉시 원터치 전환 지원 |
| **13종 도전과제 & 전적** | **구현 완료** | 누적 승률, 최고 판돈 기록, 13종 로컬 업적 완비 (Steam 연동 대기) |

---

## 3. 게임 플레이 방법 (How to Play)

### 3.1 승리 조건
머니 카드 덱이 고갈되어 마지막 라운드가 끝났을 때, **총 획득 상금이 가장 높은 플레이어가 최종 승리**합니다.

### 3.2 핵심 플레이 루프
```text
[1. 크루피에 판돈 분배] ──> [2. 비밀 카드 선택] ──> [3. 동시 공개 (Reveal)]
         │                                                    │
         ▼                                                    ▼
[6. 손패 보충 및 라운드 전환] <── [5. 암시장 상점] <── [4. 6대 주점 순차 정산]
                               (유물 모드 전용)        (단독수령 / 협상 / 결투 / 단속)
```

### 3.3 조작 체계
- **마우스 / 터치:** 카드 탭 시 위로 살짝 들어 올려지며(Lift), [확인] 클릭 시 제출.
- **게임패드 / 스팀덱:** D-Pad 좌우로 카드 포커스 이동, A로 확정, B로 취소, X로 연출 건너뛰기, Y로 주점 정보.
- **일시정지/메뉴:** 우측 상단 ≡ 아이콘 또는 Start/Esc 키로 환경설정 진입.

---

## 4. 기술 스택 및 아키텍처 (Technology Stack)

### 4.1 엔진 사양
- **게임 엔진:** Godot Engine 4.3 Stable (Standard 64-bit)
- **프로그래밍 언어:** GDScript 2.0 (정적 타입 엄격 준수)
- **렌더링 드라이버:** Compatibility (OpenGL 3.3 / OpenGL ES 3.0) — 구형 PC 및 Steam Deck에서 안정적인 60fps 보장
- **기준 해상도:** 1280×720 (16:9, `canvas_items` stretch, `expand` aspect)
- **오디오 포맷:** Ogg Vorbis (D단조 누아르 재즈 BGM 루프) / WAV & MP3 (절차적 합성 SFX)

### 4.2 아키텍처 계층 구조
- **엄격한 단방향 분리:** `engine/`은 순수 상태 머신으로 UI 노드에 일절 의존하지 않습니다.
- **결정론적 난수(Mulberry32):** 모든 게임은 초기 시드값만으로 100% 동일하게 재현됩니다.
- **안티치트 보호:** AI에게는 `Eng.get_public_view()`를 통해 상대의 비공개 손패를 마스킹하여 전달합니다.

---

## 5. 프로젝트 실행 및 테스트 가이드 (Getting Started)

### 5.1 개발 환경 요구사항
- Godot Engine 4.3 Stable (Standard 64-bit)
- Python 3.10+ (에셋 검증 및 보조 도구 실행 시)

### 5.2 프로젝트 실행
```bash
# 에디터 실행
godot --editor --path .

# 게임 즉시 실행
godot --path .
```

### 5.3 자동화 테스트 실행 (QA)
```bash
# 109종 엔진 불변식 및 골든 리플레이 검증 (17.6초 소요, 100% PASS)
godot --headless --path . --script res://tests/run_tests.gd

# 듀얼 슬롯 세이브 무결성 전수 검증 (6,442 체크, 100% PASS)
godot --headless --path . --script res://tests/save_resume_test.gd

# 간이 셸 스크립트 실행
./run_tests.sh
```

---

## 6. Steam 출시 준비 현황 (Steam Release Status)

2026년 11월 기준, 전문가 그룹(TD, Game Director, QA Lead, Steam Specialist)의 정밀 감사가 완료되었습니다.

- **종합 판정:** **조건부 출시 가능 (Conditional Go)** — 코어 룰과 세이브 무결성은 완벽하며, 리브랜딩 및 Steamworks SDK 통합 후 정식 출시 진행.
- **해결 중인 주요 과제:**
  1. [P0] 상표권 분쟁 방지를 위한 독자 명칭 리브랜딩 (*The Speakeasy 1927* 검토).
  2. [P0] `export_presets.cfg` 작성 및 플랫폼별(Windows, Linux, macOS) 빌드 파이프라인 수립.
  3. [P1] GodotSteam GDExtension 연동 (Steam 13종 업적 및 AutoCloud 세이브).
  4. [P1] 설정창 신규 항목 4종 영문 번역 등록 (`tests/i18n_slots_test.gd` 정상화).
  5. [P1] UI 플레이스루 테스트 매처 문자열 보강 (`"다음 라운드로 ▸"` 매칭).

---

## 7. 디렉터리 구조 (Directory Structure)

```text
razzia-godot/
├── project.godot                  # Godot 4.3 프로젝트 설정 및 AutoLoad 정의
├── README.md                      # [현재 파일] 프로젝트 공식 소개 및 개발 포털
├── CREDITS.md                     # 원작 저작권, 오픈폰트, CC BY 3.0 아이콘 라이선스
├── run_tests.sh                   # 헤드리스 테스트 실행 셸 스크립트
│
├── engine/                        # [엔진 계층] 순수 게임 룰, 결정론적 Mulberry32 RNG (UI 무의존)
│   ├── engine.gd                  # 핵심 상태 머신, 카드 분배, 술집 정산, 결투 판정
│   ├── relic_manager.gd           # 8종 유물 정의 및 규칙 훅 인터셉터
│   ├── rng.gd                     # JS mulberry32 호환 32-bit 결정적 난수 생성기
│   └── util.gd                    # 정규 직렬화 및 배열 유틸리티
│
├── controller/                    # [컨트롤러 계층] 엔진-UI 비동기 턴 중재자
│   └── match_controller.gd       # AI 비동기 행동 타이밍, 액션 디스패치, 이벤트 포워딩
│
├── ai/                            # [AI 계층] 컴퓨터 플레이어 휴리스틱 (EASY/NORMAL/HARD)
│   └── ai.gd                      # 성향별(보수/공격/기회) 기댓값 역산 알고리즘
│
├── platform/                      # [플랫폼 계층] 하드웨어 및 입력 추상화 (AutoLoad)
│   ├── input_mode_manager.gd      # TOUCH / MOUSE / GAMEPAD / KEYBOARD 실시간 자동 전환
│   └── steam_deck_manager.gd      # SteamOS 감지, 1280x800 화면, 30/60fps 절전 프로파일
│
├── i18n/                          # [현지화 계층] 다국어 런타임 테이블
│   └── en.gd                      # 한국어 키 -> 영어 번역 매핑 테이블 (자동 생성)
│
├── ui/                            # [UI 계층] 사용자 인터페이스, 렌더링 및 프레젠테이션
│   ├── main.tscn                  # 유일한 루트 씬 노드 (Control)
│   ├── main.gd                    # 화면 라우터 (Menu <-> Game <-> Tutorial <-> Records <-> Help)
│   ├── game_screen.gd             # 메인 게임 테이블 컨테이너 및 뷰포트
│   ├── menu_screen.gd             # 메인 메뉴 (클래식/유물 모드, 인원, 난이도, 이어하기)
│   ├── records.gd                 # 역대 전적 통계 및 13종 도전과제 관리
│   ├── save_store.gd              # 듀얼 슬롯 자동 저장 및 원자적 쓰기 로직
│   └── board/                     # 게임 테이블 서브시스템 (레이아웃, 입력, 리플레이, 암시장)
│
├── assets/                        # [에셋 리소스] 6대 주점 포스터, 104종 오디오, 폰트, 벡터 아이콘
├── tests/                         # [테스트 계층] 109종 골든 테스트, 세이브 검증, UI 스모크
├── tools/                         # [개발 도구] 파이썬 경로 검사기, 오디오/SFX 합성기, 폰트 서브셋
└── docs/                          # [공식 문서] Steam 출시 전략 및 6대 도메인 상세 문서 포털
```

---

## 8. 공식 개발 및 출시 문서 포털 (Documentation Portal)

### 🚀 Steam 상용화 필수 전략 문서 (New)
- 🔍 [스팀 출시 종합 감사 보고서](docs/STEAM_RELEASE_AUDIT.md) — `docs/STEAM_RELEASE_AUDIT.md`
- 🏛️ [기술 아키텍처 및 시스템 설계](docs/TECHNICAL_ARCHITECTURE.md) — `docs/TECHNICAL_ARCHITECTURE.md`
- 🎮 [Steamworks 연동 및 플랫폼 계획](docs/STEAM_INTEGRATION.md) — `docs/STEAM_INTEGRATION.md`
- 📟 [Steam Deck 호환성 및 Verified 가이드](docs/STEAM_DECK_COMPATIBILITY.md) — `docs/STEAM_DECK_COMPATIBILITY.md`
- 🎲 [게임 기획, 재미 및 AI 품질 평가](docs/GAME_DESIGN_REVIEW.md) — `docs/GAME_DESIGN_REVIEW.md`
- 🧪 [QA 종합 테스트 계획 및 결함 진단](docs/QA_TEST_PLAN.md) — `docs/QA_TEST_PLAN.md`
- ⚖️ [지식재산권, 상표권 및 에셋 라이선스 실사](docs/LEGAL_AND_ASSET_AUDIT.md) — `docs/LEGAL_AND_ASSET_AUDIT.md`
- 🗺️ [5단계 개발 우선순위 및 상용화 로드맵](docs/STEAM_RELEASE_ROADMAP.md) — `docs/STEAM_RELEASE_ROADMAP.md`
- 📜 [프로젝트 마스터 체인지로그](docs/CHANGELOG.md) — `docs/CHANGELOG.md`

### 📚 상세 도메인 개발 문서
- 🎲 [게임 상세 기획서 (GDD)](docs/game-design/GAME_DESIGN_DOCUMENT.md)
- 📜 [공식 규칙서 (RULE-001 ~ 036)](docs/game-design/GAME_RULES.md)
- 🏛️ [소프트웨어 아키텍처 가이드](docs/technical/PROJECT_ARCHITECTURE.md)
- 📱 [UI/UX 디자인 가이드라인](docs/design/UI_UX_GUIDELINES.md)
- 👥 [등장인물 및 AI 라이벌 프로필](docs/story/CHARACTERS.md)
- 📦 [시각 및 오디오 에셋 카탈로그](docs/assets/ASSET_CATALOG.md)
