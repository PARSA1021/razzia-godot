# 🧪 QA TEST PLAN — 품질 보증(QA) 및 종합 테스트 계획서

> **작성 기준일:** 2026-11-01  
> **검토 주관:** QA Lead & Test Automation Engineer  
> **엔진 환경:** Godot Engine 4.3 Stable (Standard 64-bit, headless)

---

## 1. 테스트 체계 구조 및 현재 검증 결과

본 프로젝트는 단위 룰 검증부터 시드 기반 골든 리플레이, 세이브 무결성 전수 조사까지 매우 높은 수준의 자동화 테스트 스위트를 구비하고 있다.

### 1.1 자동화 테스트 실행 실측 결과 요약
| 테스트 스위트 | 검증 대상 | 체크 수 | 실측 결과 | 수행 시간 | 상태 |
|---|---|:---:|:---:|:---:|:---:|
| `tests/run_tests.gd` | RNG 비트 일치, 52개 시드 골든 리플레이, 룰 불변식 | 109 | **0 FAIL** | 17.6초 | **PASS** |
| `tests/save_resume_test.gd` | 240개 세션 중단점 직렬화/복원 및 무결성 | 6,442 | **0 FAIL** | 137.6초 | **PASS** |
| `tests/relic_system_test.gd` | 8종 유물 효과, 스타터 드래프트, 상태 저장 | 94 | **0 FAIL** | 6.8초 | **PASS** |
| `tests/black_market_test.gd` | 암시장 상점, 리롤, 통화량 보존(INV-002) | 65 | **0 FAIL** | 4.2초 | **PASS** |
| `tests/records_test.gd` | 13종 도전과제, 전적 누적, 통계 무결성 | 34 | **0 FAIL** | 2.1초 | **PASS** |
| `tests/platform_test.gd` | SteamDeck 감지, 입력 전환, 품질 프리셋 | 24 | **0 FAIL** | 1.8초 | **PASS** |
| `tests/rules_help_test.gd` | 룰북 텍스트 및 확률 수학적 검증 | 13 | **0 FAIL** | 1.2초 | **PASS** |
| `tests/i18n_slots_test.gd` | 한국어/영어 전환 및 슬롯 격리 | 60 | **5 FAIL** | 3.5초 | **FAIL (결함 발견)** |
| `tests/qa_gamepad_playthrough_test.gd` | 1280×800 컨트롤러 전용 1판 풀 플레이스루 | 24 | **6 FAIL** | 타임아웃 | **FAIL (결함 발견)** |
| `tests/qa_playthrough_test.gd` | 마우스/터치 전용 풀 플레이스루 | - | 타임아웃 | - | **FAIL (결함 발견)** |
| `tests/qa_tutorial_test.gd` | Sal의 튜토리얼 3라운드 완주 검증 | - | 타임아웃 | - | **FAIL (결함 발견)** |
| `tools/ci_check.sh` (1단계) | `tools/check_paths.py` 리소스 경로 전수 검사 | 651 | **3 FAIL** | 0.8초 | **FAIL (결함 발견)** |

---

## 2. 정밀 감사에서 발견된 3대 결함 원인 분석

### 결함 1: `tests/i18n_slots_test.gd` 실패 (5 checks failed)
- **증상:** 영문 모드 전환 후 설정 패널 검증 단계에서 한글 텍스트 잔존으로 실패.
- **원인:** 커밋 `2526f8c` 및 `ba2be02`에서 추가된 설정 항목 4종(`"다른 플레이어 결투"`, `"축약"`, `"크게 보기"`, `"화면 흔들림"`)이 `tools/i18n/` 및 `i18n/en.gd` 사전에 미등록됨.
- **해결 방안:** 영문 번역 키 추가:
  - `"다른 플레이어 결투"` $\rightarrow$ `"Other Players' Duels"`
  - `"축약"` $\rightarrow$ `"Compact"`
  - `"크게 보기"` $\rightarrow$ `"Full View"`
  - `"화면 흔들림"` $\rightarrow$ `"Screen Shake"`

### 결함 2: UI 플레이스루 테스트 3종 타임아웃 멈춤 현상
- **대상:** `qa_gamepad_playthrough_test.gd`, `qa_playthrough_test.gd`, `qa_tutorial_test.gd`
- **증상:** 라운드 1 또는 2 종료 후 장부 모달에서 다음 라운드로 넘어가지 못하고 멈춤.
- **원인:** `ui/board/board_results.gd:238`에서 다음 라운드 버튼 라벨이 `tr("다음 라운드로 ▸")` (영문: `"Next Round ▸"`)로 폴리싱되었으나, 테스트 프레임워크의 `_btn()` 매처는 과거의 영문 대문자 `"NEXT ROUND"`, `"FINAL RESULT"`만을 고정 검색하고 있어 버튼을 찾지 못함.
- **해결 방안:** 테스트 코드의 탐색 키워드에 `tr("다음 라운드로 ▸")`, `"Next Round"`, `"암시장 방문 ▸"`을 추가하고 대소문자 무시(case-insensitive) 탐색을 적용.

### 결함 3: `tools/check_paths.py` 동적 포맷팅 경고 (3 paths failed)
- **증상:** CI 1단계 검사에서 `tools/capture_bundle*.gd`의 `%s` 경로 패턴을 미등록 동적 경로로 판정하여 FAIL 반환.
- **원인:** 개발용 자동 캡처 도구의 파일 경로 생성 패턴이 `tools/check_paths.py`의 `DYNAMIC` 화이트리스트에 누락됨.
- **해결 방안:** `check_paths.py`의 `DYNAMIC` 딕셔너리에 캡처 도구의 번들 파일명 목록 등록.

---

## 3. Steam 출시 전 수동 QA 테스트 매트릭스

자동화 테스트로 검증하기 어려운 사용자 경험 영역에 대해 출시 전 수동 검증을 실시한다.

| 번호 | 테스트 시나리오 | 검증 절차 | 합격 기준 |
|:---:|---|---|---|
| **M-01** | 저장 도중 프로세스 강제 종료 | 카드 선택 직후 Alt+F4 / 작업관리자 강제 종료 | 재실행 시 `.bak` 또는 직전 체크포인트 정상 복원 |
| **M-02** | Steam Cloud 크로스 디바이스 동기화 | PC에서 라운드 3 저장 $\rightarrow$ Steam Deck에서 실행 | Steam Deck에서 슬롯 1에 라운드 3 정확히 노출 |
| **M-03** | 게임패드 실시간 탈착 (Hot-plugging) | 게임 진행 중 컨트롤러 USB 분리 후 재연결 | 입력 모드가 끊김 없이 즉시 복구되고 조작 가능 |
| **M-04** | 해상도 및 창 모드 변경 | 전체 화면 $\leftrightarrow$ 창 모드 $\leftrightarrow$ 해상도 변경 | UI 깨짐, 폰트 겹침, 황동 레일 어긋남 없음 |
| **M-05** | 장시간 연속 플레이 메모리 누수 | 4인 게임 20판 연속 플레이 | 메모리 사용량 350MB 이하 유지 및 프레임 드랍 없음 |
| **M-06** | Steam Deck 슬립 및 웨이크업 | 결투 주사위 연출 중 전원 버튼 슬립 $\rightarrow$ 1시간 후 기상 | 튕김 없이 오디오와 애니메이션 정상 재개 |
| **M-07** | 이름 입력 가상 키보드 | Steam Deck에서 유저 이름 필드 터치 | SteamOS On-Screen Keyboard 자동 호출 |
