# 📖 ZOCARI: Take It or Leave It — 프로젝트 종합 개발 문서 포털

> **"Take it or leave it. (받든지 말든지.)"** — 1927년 시카고, 금주법 시대의 밤거리를 지배하라.  
> 본 디렉터리는 글로벌 독립 브랜드 **Zocari: Take It or Leave It (조카리)**의 Steam 상용화 출시에 대한 기획, 디자인, 기술 아키텍처, 스토리, 개발 현황, 법률 실사 및 에셋 전반을 총망라한 개발 문서 보관소입니다. (1992년 Stefan Dorra의 전설적인 보드게임 *Razzia* 메커니즘 공식 오마주)

---

## 🚀 Steam 상용화 출시 핵심 전략 문서 (Release Suite)

Steam 출시 검토(TD, Game Director, QA Lead, Steam Specialist)를 위해 신규 편제된 최상위 의사결정 문서군입니다.

| 문서명 | 파일 경로 | 주요 내용 및 목적 |
|---|---|---|
| 🔍 **스팀 출시 종합 감사 보고서** | [`docs/STEAM_RELEASE_AUDIT.md`](STEAM_RELEASE_AUDIT.md) | 상용 출시 준비 상태, 조건부 출시 판정(Conditional Go), 핵심 리스크 진단 |
| 🏛️ **기술 아키텍처 명세서** | [`docs/TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md) | 5계층 단방향 아키텍처, 4대 불변식, 2단계 원자적 세이브 파이프라인 |
| 🎮 **Steamworks 통합 계획서** | [`docs/STEAM_INTEGRATION.md`](STEAM_INTEGRATION.md) | GodotSteam GDExtension 연동, 13종 업적 매핑, AutoCloud 세이브 전략 |
| 📟 **Steam Deck 호환성 가이드** | [`docs/STEAM_DECK_COMPATIBILITY.md`](STEAM_DECK_COMPATIBILITY.md) | Verified 4대 기준 검증, 1280×800 꽉 찬 화면, 30fps 절전 렌더링 프로파일 |
| 🎲 **게임 디자인 & AI 평가서** | [`docs/GAME_DESIGN_REVIEW.md`](GAME_DESIGN_REVIEW.md) | 블러핑/협상/결투 심리전 분석, AI 기댓값 알고리즘, 유물 모드 상업성 검토 |
| 🧪 **QA 종합 테스트 계획서** | [`docs/QA_TEST_PLAN.md`](QA_TEST_PLAN.md) | 109종 골든 테스트(PASS), 6,442개 세이브 체크(PASS), 발견된 3대 결함 진단 |
| ⚖️ **법률 및 에셋 라이선스 실사** | [`docs/LEGAL_AND_ASSET_AUDIT.md`](LEGAL_AND_ASSET_AUDIT.md) | 상표권 분쟁 회피 독자 리브랜딩 권고, 폰트/아이콘/오디오 라이선스 실사 |
| 🏷️ **글로벌 상표권 및 IP 사전 실사** | [`docs/BRAND_NAMING_AND_IP_CLEARANCE.md`](BRAND_NAMING_AND_IP_CLEARANCE.md) | 35대 조어형 브랜드 후보, KIPRIS/USPTO/EUIPO 검색, 4단계 법적 위험 분류 |
| 🗺️ **5단계 상용화 로드맵** | [`docs/STEAM_RELEASE_ROADMAP.md`](STEAM_RELEASE_ROADMAP.md) | Phase 1~5 마일스톤, P0/P1 작업 명세표, 상점 캡슐 에셋 준비 계획 |
| 📜 **마스터 체인지로그** | [`docs/CHANGELOG.md`](CHANGELOG.md) | Phase 1 ~ 30 누적 개발 및 릴리즈 노트 |

---

## 🧭 도메인별 상세 문서 분류 (Documentation Taxonomy)

문서는 성격과 대상 독자에 따라 6개의 전문 도메인으로 엄격히 분리되어 관리됩니다.

```text
docs/
├── STEAM_RELEASE_AUDIT.md         # [신규] 스팀 출시 종합 감사 보고서
├── TECHNICAL_ARCHITECTURE.md      # [신규] 기술 아키텍처 및 시스템 설계 명세
├── STEAM_INTEGRATION.md           # [신규] Steamworks 연동 계획 및 플랫폼 기술 명세
├── STEAM_DECK_COMPATIBILITY.md    # [신규] 스팀덱 호환성 정밀 분석 및 Verified 가이드
├── GAME_DESIGN_REVIEW.md          # [신규] 게임 디렉터 관점의 기획/재미/완성도 평가
├── QA_TEST_PLAN.md                # [신규] 품질 보증(QA) 및 종합 테스트 계획서
├── LEGAL_AND_ASSET_AUDIT.md       # [신규] 지식재산권, 상표권 및 에셋 라이선스 실사
├── BRAND_NAMING_AND_IP_CLEARANCE.md # [신규] 글로벌 상표권 실사 및 35대 신규 브랜드 후보
├── STEAM_RELEASE_ROADMAP.md       # [신규] 5단계 개발 우선순위 및 상용화 로드맵
├── CHANGELOG.md                   # [신규] 프로젝트 마스터 변경 이력
│
├── game-design/                   # 🎲 게임 디자인 및 규칙 체계
│   ├── GAME_OVERVIEW.md           # 게임 개요, 기획 의도 및 모바일 이식 철학
│   ├── GAME_DESIGN_DOCUMENT.md    # 상세 기획서 (코어 루프, 상태 머신, 모드 체계)
│   ├── GAME_RULES.md              # 공식 룰북 (RULE-001 ~ RULE-036, 가정 및 변형 규칙)
│   ├── GAME_SYSTEMS.md            # 핵심 시스템 (결정론적 엔진, 협상/결투 알고리즘, 유물/암시장)
│   └── GAME_BALANCE.md            # 경제 밸런스, 난이도별 AI 가중치, 주사위 확률 분포
│
├── story/                         # 🍸 세계관 및 내러티브
│   ├── STORY_OVERVIEW.md          # 1920년대 시카고 금주법 배경 시놉시스
│   ├── WORLD_BUILDING.md          # 6대 비밀 주점(Speakeasy) 로어 및 상세 설정
│   ├── CHARACTERS.md              # 7인 AI 라이벌 및 주인공 캐릭터 프로필
│   └── NARRATIVE_DESIGN.md        # 다이내믹 컷씬 연출 및 상황별 바크(대사) 트리거
│
├── design/                        # 🎨 아트 및 UI/UX 디자인
│   ├── ART_DIRECTION.md           # 아르데코(Art Deco) & 누아르 비주얼 가이드라인
│   ├── UI_UX_GUIDELINES.md        # 반응형 듀얼 레이아웃(PC/Steam Deck vs Mobile), 조작 원칙
│   ├── AUDIO_DESIGN.md            # D단조 누아르 재즈 BGM 및 절차적 SFX 설계
│   └── ACCESSIBILITY.md           # 무광과민성 보호, 스크린 셰이크 조절, 고대비 가독성
│
├── technical/                     # ⚙️ 기술 구조 및 소프트웨어 공학
│   ├── TECHNICAL_OVERVIEW.md      # 기술 스택 (Godot 4.3, GDScript 2.0, OpenGL3)
│   ├── PROJECT_ARCHITECTURE.md    # 엄격한 단방향 계층 구조 및 이벤트 디스패치 파이프라인
│   ├── CODE_GUIDELINES.md         # 코드 컨벤션, 정적 타이핑, AI 안티치트 차단 원칙
│   ├── DATA_AND_SAVE_SYSTEM.md    # 듀얼 슬롯 자동 저장, 전적/업적 스키마, 격리 샌드박스
│   └── BUILD_AND_DEPLOYMENT.md    # 타깃 플랫폼별 빌드 및 배포, CI/CD 검증 파이프라인
│
├── development/                   # 🚀 프로젝트 관리 및 테스팅
│   ├── DEVELOPMENT_STATUS.md      # 구현 완료 vs 개발 중 vs 기획 단계 상세 기능 매트릭스
│   ├── ROADMAP.md                 # v1.0 정식 출시 및 플랫폼 확장 로드맵
│   ├── KNOWN_ISSUES.md            # 알려진 이슈, 엣지 케이스 및 성능 프로파일링
│   ├── TESTING_GUIDE.md           # 109종 골든 테스트 및 UI/게임패드 자동화 테스트 가이드
│   └── CHANGELOG.md               # Phase 1 ~ 29+ 누적 개발 히스토리
│
└── assets/                        # 📦 에셋 카탈로그 및 라이선스
    ├── ASSET_CATALOG.md           # 일러스트, 폰트, 벡터 아이콘 등록부 및 CC BY 라이선스
    └── AUDIO_ASSET_LIST.md        # 104종 BGM 및 사운드 이펙트 상세 레지스트리
```

---

## 🎯 빠른 링크 (Quick Navigator)

### 1. 신규 개발자 온보딩
- 프로젝트 전체 아키텍처 이해하기: [`docs/TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md)
- 코딩 규칙 및 품질 기준: [`docs/technical/CODE_GUIDELINES.md`](technical/CODE_GUIDELINES.md)
- 자동화 테스트 실행 및 검증: [`docs/QA_TEST_PLAN.md`](QA_TEST_PLAN.md)

### 2. 게임 기획 및 룰북 확인
- 공식 룰북 (RULE-001 ~ RULE-036): [`docs/game-design/GAME_RULES.md`](game-design/GAME_RULES.md)
- 핵심 시스템 및 협상/결투 메커니즘: [`docs/game-design/GAME_SYSTEMS.md`](game-design/GAME_SYSTEMS.md)
- 로그라이크 유물 모드(Relic Mode) 규격: [`docs/game-design/GAME_DESIGN_DOCUMENT.md`](game-design/GAME_DESIGN_DOCUMENT.md)

### 3. Steam 출시 전략 확인
- 출시 종합 감사: [`docs/STEAM_RELEASE_AUDIT.md`](STEAM_RELEASE_AUDIT.md)
- Steam Deck 최적화: [`docs/STEAM_DECK_COMPATIBILITY.md`](STEAM_DECK_COMPATIBILITY.md)
- 출시 로드맵 & 우선순위: [`docs/STEAM_RELEASE_ROADMAP.md`](STEAM_RELEASE_ROADMAP.md)

---

## 🔒 문서 관리 및 갱신 원칙

1. **단일 진실 공급원 (Single Source of Truth)**:
   - 게임 규칙의 최상위 권위는 [`docs/game-design/GAME_RULES.md`](game-design/GAME_RULES.md)입니다.
   - 코드와 문서가 상충할 경우 임의로 코드를 고치지 않고, 룰 문서의 근거를 확인한 후 공식 변경 절차(`RULE CHANGE`)를 거칩니다.
2. **구현 상태의 정직한 기록**:
   - 기획 단계인 내용과 실제 엔진/UI에 구현 완료된 내용을 명확히 분리합니다. 미구현 기능을 완료된 것처럼 기록하지 않습니다.
3. **결정론과 재현성 보장**:
   - 모든 시스템과 규칙 설계는 결정론적 난수(Mulberry32)와 골든 테스트(`tests/run_tests.gd`)로 검증 가능해야 합니다.
