# 🔍 STEAM RELEASE AUDIT — 스팀 상용화 출시 준비 종합 감사 보고서

> **작성 기준일:** 2026-11-01  
> **감사 주관:** Technical Director, Game Director, QA Lead, Steam Release Specialist  
> **대상 프로젝트:** Razzia Mobile (`res://project.godot`)  
> **엔진 버전:** Godot 4.3 Stable (Standard 64-bit, Compatibility / OpenGL 3.3)  
> **상태 평가:** **조건부 출시 가능 (Conditional Go)** — 핵심 게임 루프와 불변식은 완벽하나, 상표권/IP 리브랜딩, Steamworks SDK 연동, 3종의 UI/테스트 결함 수정 필수

---

## 1. 종합 진단 요약 (Executive Summary)

본 프로젝트는 1992년 Stefan Dorra의 명작 보드게임 *Razzia*의 동시 선택 심리 베팅 룰을 100% 디지털화하고, 싱글 플레이어 리플레이성을 극대화하기 위해 '로그라이크 유물 모드(Relic Mode)'를 결합한 고품질 인디 카드 전략 게임이다.

기술적/구조적 감사 결과, **엔진 코어 로직(상태 머신, 결정론적 Mulberry32 난수, 109종 불변식 테스트)과 세이브 시스템의 무결성(240개 중단점 복원, 6,442개 체크 100% 통과)은 상용 게임 중에서도 최상위권의 안정성**을 갖추고 있다. 또한 1280×800 해상도 대응, 게임패드 입력 추상화, 저전력 렌더링 등 Steam Deck을 고려한 기반 설계가 훌륭하게 구축되어 있다.

그러나 **실제 Steam 유료 출시(Commercial Release)**를 기준으로 볼 때, 즉시 출시를 가로막는 치명적인 P0/P1급 이슈가 존재한다:

1. **상표권 및 IP 법적 리스크 (P0):** 게임명 "Razzia" 및 Stefan Dorra/Ravensburger 원작 명시는 라이선스 계약 없이는 저작권/상표권 침해 및 상점 페이지 동결 위험이 매우 큼. 리브랜딩 필수.
2. **Steamworks SDK 미통합 (P1):** GodotSteam 등 네이티브 SDK가 전혀 연동되어 있지 않음. 13종 업적은 로컬 JSON으로만 기록되며, Steam Cloud 및 Steam 오버레이 세션 관리가 부재함.
3. **익스포트 프리셋 누락 (P1):** `export_presets.cfg`가 없어 플랫폼별(Windows, Linux, macOS) 빌드 자동화가 불가능한 상태.
4. **UI 및 테스트 단절 결함 3건 (P1):**
   - 설정 패널 신규 스트링 4종("다른 플레이어 결투", "축약", "크게 보기", "화면 흔들림") 번역 누락 (`tests/i18n_slots_test.gd` 실패).
   - `ui/board/board_results.gd`의 버튼 텍스트 변경(`"다음 라운드로 ▸"`)과 테스트 코드(`qa_*_playthrough_test.gd`, `qa_tutorial_test.gd`)의 하드코딩 매처(`"NEXT ROUND"`) 불일치로 인한 자동 플레이스루 무한 대기.
   - `tools/check_paths.py`의 동적 스크린샷 포맷 문자열 미등록으로 인한 CI 스크립트 실패.

---

## 2. 영역별 정밀 진단 매트릭스

| 영역 | 현황 및 완성도 | 준비 수준 | 핵심 발견 사항 및 위험 요소 |
|---|:---:|:---:|---|
| **코어 엔진 (Engine)** | 100% | **READY** | 52개 시드 골든 리플레이 109개 검증 0 실패. 단방향 상태 머신 완벽 분리. |
| **세이브/로드 (Save/Resume)** | 98% | **READY** | 듀얼 슬롯, 임시 파일 교체 원자적 쓰기. 240개 중단점 복원 6,442개 체크 통과. |
| **AI 및 밸런스 (AI/Systems)** | 95% | **READY** | 3단계 난이도 + 3대 성향 + 7인 라이벌. 안티치트(`get_public_view`) 준수. |
| **유물 모드 (Relic/Roguelike)** | 95% | **READY** | 8종 고유 유물, 암시장 상점, 통화량 보존 불변식(INV-002) 65개 체크 통과. |
| **UI/UX & 해상도** | 90% | **NEEDS FIX** | 듀얼 반응형(1280×720 / 720×1280). 설정 패널 번역 누락 4건 발견. |
| **Steam Deck 호환성** | 88% | **GOOD** | 1280×800 꽉 찬 화면, XInput 매핑, 30/60fps 절전 모드. 가상 키보드 연동 필요. |
| **Steamworks 통합** | 0% | **NOT STARTED**| GodotSteam 미설치. 업적/클라우드 세이브/오버레이 연동 부재. |
| **빌드 & 패키징** | 20% | **BLOCKED** | `export_presets.cfg` 파일 부재. Windows/Linux/macOS 바이너리 미생성. |
| **지식재산권 (Legal/IP)** | 30% | **CRITICAL RISK** | 게임명 'Razzia' 및 원작자 표기. 상표권 및 저작권 침해 소송 위험. |
| **QA 자동화** | 75% | **NEEDS FIX** | 룰/유물/세이브는 완벽하나, UI 통합 테스트 3종에서 매칭 스트링 불일치로 멈춤 발생. |

---

## 3. 핵심 발견 결함 (Key Audit Findings)

### Finding 1 [CRITICAL]: 상표권 및 원작 지식재산권 분쟁 위험
- **위치:** `README.md:1`, `CREDITS.md:4`, `project.godot:13`
- **현상:** 게임명이 "RAZZIA"로 지정되어 있으며, 1992년 Ravensburger 출판 / Stefan Dorra 설계 원작을 직간접적으로 명시함.
- **영향:** Steam 출시 시 Valve의 IP 검토 단계 또는 경쟁사/원작자 대리인의 통지로 인해 상점 페이지 차단 및 DMCA 게시 중단 위험 직면.
- **조치 권고:** 독자적 세계관(1927년 시카고 스피크이지)을 강조하는 신규 명칭(예: *The Speakeasy 1927*, *Underground Syndicate*)으로 리브랜딩 확정.

### Finding 2 [HIGH]: Steamworks SDK 미연동 및 Steam Cloud 부재
- **위치:** `ui/records.gd`, `ui/save_store.gd`
- **현상:** 13종 도전과제가 `user://records.json`에만 로컬 기록되며, Steam 클라우드 세이브 동기화 기능이 없음.
- **영향:** 플레이어가 PC와 Steam Deck 간에 세이브를 공유할 수 없으며, Steam 클라이언트 상에 업적이 언락되지 않음.
- **조치 권고:** GDExtension 기반 `GodotSteam` 플러그인 도입 또는 표준 AutoCloud 디렉토리 매핑 설정.

### Finding 3 [MEDIUM]: 설정 패널 신규 항목 영문 번역 누락
- **위치:** `ui/settings_panel.gd`, `i18n/en.gd`, `tests/i18n_slots_test.gd`
- **현상:** 최근 추가된 "다른 플레이어 결투", "축약", "크게 보기", "화면 흔들림" 항목이 영문 매핑 테이블에 없어 영문 모드에서도 한글로 노출됨 (`tests/i18n_slots_test.gd` 5건 FAIL).
- **조치 권고:** `tools/i18n/en_menu_save.py`에 4종 키 추가 후 `build_en.py` 실행.

### Finding 4 [MEDIUM]: UI 자동화 테스트 프레임워크의 버튼 텍스트 불일치
- **위치:** `tests/qa_gamepad_playthrough_test.gd:334`, `tests/qa_playthrough_test.gd:258`, `tests/qa_tutorial_test.gd:325`
- **현상:** 테스트 코드는 `"NEXT ROUND"` 대문자를 찾고 있으나, 실제 렌더링 코드는 `tr("다음 라운드로 ▸")` (영문: `"Next Round ▸"`)를 출력하여 버튼 탐색에 실패, 120,000 프레임 동안 대기하다 타임아웃 발생.
- **조치 권고:** 테스트의 `_btn()` 탐색 대상에 `tr("다음 라운드로 ▸")` 및 대소문자 무시(case-insensitive) 매칭 로직 보강.

### Finding 5 [MEDIUM]: Export Presets 설정 누락
- **위치:** 프로젝트 루트 (`export_presets.cfg` 부재)
- **현상:** Windows, Linux, macOS 플랫폼별 내보내기 설정 파일이 버전 관리에 누락됨.
- **조치 권고:** Godot 4.3 공식 템플릿에 맞춘 `export_presets.cfg` 작성 및 아키텍처별 바이너리 타겟 정의.

---

## 4. 최종 종합 평가 및 출시 판정

**판정:** **"출시 유보 (Hold) — P0/P1 해결 후 Go"**

코어 게임은 이미 매우 재미있고 탄탄하며 버그가 거의 없다. 상용 인디게임으로 성공하기 위한 3대 핵심 작업(리브랜딩, Steamworks/Cloud 연동, UI 테스트 결함 3건 해소)을 완료하는 즉시 스팀 얼리액세스 또는 정식 출시가 가능하다.
