# 📜 CHANGELOG — 프로젝트 전체 변경 이력 및 릴리즈 노트

> **상위 포털:** [`docs/README.md`](README.md)  
> **상세 개발 이력 (Phases 1 ~ 29+):** [`docs/development/CHANGELOG.md`](development/CHANGELOG.md)

---

## [Phase 30: Steam Release Preparation Audit] — 2026-11-01 (Current)
- **Steam 출시 종합 감사 완료:** Technical Director, Game Director, QA Lead, Steam Specialist 관점에서 프로젝트 전수 조사.
- **감사 및 출시 전략 문서 구축:**
  - `docs/STEAM_RELEASE_AUDIT.md`: 스팀 출시 종합 감사 보고서.
  - `docs/TECHNICAL_ARCHITECTURE.md`: 5계층 아키텍처 및 불변식, 데이터 흐름 명세.
  - `docs/STEAM_INTEGRATION.md`: GodotSteam GDExtension, 업적 13종, AutoCloud 연동 계획.
  - `docs/STEAM_DECK_COMPATIBILITY.md`: 1280×800 해상도, XInput 매핑, 배터리 세이버 렌더링 분석.
  - `docs/GAME_DESIGN_REVIEW.md`: AI 기댓값 알고리즘, 유물 8종, 암시장 경제성 분석.
  - `docs/QA_TEST_PLAN.md`: 109종 골든 테스트(PASS), 세이브 6,442개 체크(PASS) 및 결함 3건 정밀 진단.
  - `docs/LEGAL_AND_ASSET_AUDIT.md`: 상표권 리스크 회피 리브랜딩 권고 및 에셋 라이선스 실사.
  - `docs/STEAM_RELEASE_ROADMAP.md`: 5단계 출시 마일스톤 및 P0~P3 우선순위표 확립.
- **주요 결함 발견 및 격리:**
  - 설정창 신규 항목 4종 번역 누락 (`tests/i18n_slots_test.gd`).
  - 장부 버튼 텍스트 변경과 UI 플레이스루 테스트 매처 불일치로 인한 타임아웃 멈춤.
  - `tools/check_paths.py` 개발 도구 동적 포맷팅 문자열 미등록.

---

## [Phase 29+] — 종합 문서화 체계 구축 및 프로젝트 구조 정밀 정리
- **문서 체계 도메인화:** `docs/` 디렉터리를 6개 전문 도메인(`game-design/`, `story/`, `design/`, `technical/`, `development/`, `assets/`)으로 재편.
- **루트 README 개정:** 게임 정체성, 기술 스택, 실행 가이드 종합 포털 구축.
- **레거시 에셋 격리:** 미사용 폰트 정리 및 레거시 스크린샷 아카이브 격리.

---

## [Commit 0d895eb ~ ba2be02] — 결투 연출 축약 및 정산 화면 고도화
- **AI 결투 축약 연출:** 플레이어가 참여하지 않는 타 AI 간의 결투를 술집 카드 위에서 작고 빠르게 축약 렌더링.
- **결투 정산 기록:** 결투 승패 및 주사위 합산 결과를 정산 장부에 상세 기록.
- **플레이어 결투 긴장감 연출:** 방어자 선착지, 동점 시 도전자 승리 강조 안내, A 버튼 홀드 주사위 흔들기 및 화면 흔들림(Screen Shake) 토글 추가.
- **협상 고정 노이즈:** 슬라이더 반복 조작을 통한 기준선 역산 차단.

---

## [Phases 25 ~ 28] — 로그라이크 유물 모드 (Relic Mode) 및 아르데코 비주얼
- **로그라이크 모드 추가 (RULE-036):** 클래식 룰 위에 8종의 고유 유물 및 암시장 상점 레이어 구축.
- **스타터 드래프트:** 매치 시작 시 3종 유물 중 1개 무료 선택 지원.
- **암시장 상점 (Black Market):** 라운드 사이 유물 구매 및 $5,000 리롤 지원. 통화량 보존(INV-002) 달성.
- **카드 오버랩 개편:** 4~8인 플레이 시 작은 플레이어 원형 초상화 렌더링 및 주사위 모서리 보호.
- **서체 확정:** 타이틀 `Stint Ultra Expanded`, 머니 `Playfair Display`, 타자기 `Special Elite`.

---

## [Phases 20 ~ 24] — Steam Deck 및 크로스 플랫폼 최적화
- **SteamDeckManager 오토로드:** SteamOS 자동 감지 및 1280×800 꽉 찬 화면 지원.
- **전력 프로파일:** 60fps 기본 / 30fps 절전 렌더링(`OS.low_processor_usage_mode`) 및 정적 펠트 셰이더 교체 지원.
- **InputModeManager 오토로드:** 마우스, 터치, 게임패드(XInput), 키보드 실시간 자동 전환.

---

## [Phases 1 ~ 19] — 코어 엔진 복원 및 듀얼 레이아웃 구축
- **JS 프로토타입 포팅:** 검증된 JavaScript 엔진을 GDScript로 1:1 비트 일치 포팅.
- **Mulberry32 PRNG:** 32-bit 결정론적 난수 생성기 및 52개 시드 골든 리플레이 109종 불변식 검증.
- **듀얼 레이아웃:** 가로 와이드(1280×720) 및 세로 모바일(720×1280) 동시 지원.
- **오디오 시스템:** 누아르 재즈 3트랙 BGM 루프 및 104종 사운드 에셋 시스템 구축.
- **듀얼 세이브 시스템:** 원자적 쓰기(Atomic Write) 기반 클래식/유물 모드 2슬롯 분리 저장.
