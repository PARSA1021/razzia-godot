# 🐛 KNOWN ISSUES — 알려진 문제점 및 기술적 고려사항

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/STEAM_RELEASE_AUDIT.md`](../STEAM_RELEASE_AUDIT.md), [`docs/QA_TEST_PLAN.md`](../QA_TEST_PLAN.md), [`docs/development/DEVELOPMENT_STATUS.md`](DEVELOPMENT_STATUS.md)

---

## 1. 알려진 경미한 이슈 및 결함

### 1.1 도구 스크립트의 동적 스크린샷 경로 (`tools/check_paths.py`)
- **현상:** `tools/check_paths.py` 실행 시 `tools/capture_bundle*.gd` 및 `tools/capture_screenshot.gd`의 포맷팅 문자열(`res://tools/screenshots/%s.png`)이 "미등록 동적 경로" 경고로 3건 출력되며 CI 실패.
- **영향도:** 낮음 (개발용 자동 스크린샷 캡처 도구의 저장 대상 경로일 뿐이며 실제 게임 런타임 리소스 누락이 아님).
- **해결 방안:** `tools/check_paths.py`의 `DYNAMIC` 화이트리스트에 캡처 파일 ID를 등록하여 경고 억제 예정.

### 1.2 설정 패널 신규 항목 영문 번역 누락 (`tests/i18n_slots_test.gd`)
- **현상:** 설정 패널에 추가된 신규 옵션 4종(`"다른 플레이어 결투"`, `"축약"`, `"크게 보기"`, `"화면 흔들림"`)이 `tools/i18n/` 및 `i18n/en.gd`에 등록되지 않아 영문 모드에서도 한글로 노출됨 (`i18n_slots_test.gd` 5 checks FAIL).
- **영향도:** 보통 (영문 환경 유저 경험 저하).
- **해결 방안:** `tools/i18n/en_menu_save.py`에 영문 매핑 추가 후 `build_en.py` 재실행.

### 1.3 UI 플레이스루 테스트 매처 문자열 불일치 (`qa_*_playthrough_test.gd`)
- **현상:** `tests/qa_gamepad_playthrough_test.gd`, `tests/qa_playthrough_test.gd`, `tests/qa_tutorial_test.gd` 실행 시 라운드 결과 모달에서 버튼을 찾지 못해 무한 대기 타임아웃 발생.
- **원인:** 실제 UI 버튼 텍스트가 `tr("다음 라운드로 ▸")` (영문: `"Next Round ▸"`)로 폴리싱되었으나, 테스트 코드는 대문자 `"NEXT ROUND"`, `"FINAL RESULT"`만을 검색하여 탐색 실패.
- **해결 방안:** 테스트 프레임워크의 `_btn()` 매처에 `tr("다음 라운드로 ▸")` 및 대소문자 무시(case-insensitive) 매칭 보강.

### 1.4 플랫폼별 익스포트 프리셋 누락 (`export_presets.cfg`)
- **현상:** 프로젝트 루트에 `export_presets.cfg`가 없어 헤드리스 CLI 또는 CI 상에서 Windows/Linux/macOS 바이너리 빌드 자동화 불가능.
- **영향도:** 높음 (배포 파이프라인 블록).
- **해결 방안:** Godot 4.3 표준 Export Preset 파일 생성 및 Git 관리.

### 1.5 극단적인 초고해상도(32:9 슈퍼 울트라와이드) 환경 뷰포트
- **현상:** 5120×1440 등 극단적인 가로 비율 모니터에서 게임 실행 시 펠트 테이블 좌우 끝단이 넓게 확장되어 중앙 카지노 테이블 영역이 다소 집중되지 않는 느낌을 줄 수 있음.
- **영향도:** 낮음 (게임 기능 및 UI 조작에는 전혀 지장 없음).
- **개선 계획:** 울트라와이드 감지 시 좌우 황동 레일 바깥쪽에 고급 앤틱 원목 데스크 텍스처를 배치하는 레터박스 옵션 추가 고려.

### 1.6 macOS Intel 내장 그래픽(HD 6000 등) OpenGL3 드라이버 경고
- **현상:** 구형 Intel 내장 그래픽 환경에서 Godot 에디터 또는 게임 실행 시 드라이버 호환성 관련 콘솔 로그(`Compatibility - Using Device: Intel Inc.`)가 출력됨.
- **영향도:** 없음 (정상 60fps 렌더링 유지 확인).

---

## 2. 미확정 가정 사항 (Assumptions & Inconsistencies)

원작 1992년 독일어 룰북의 일부 애매한 문구에 대해 본 프로젝트는 다음의 일관된 가정을 적용하여 구현했습니다:

1. **4인 이상 다자간 결투 순서 (RULE-021):**
   - 원작 룰북은 3인 결투까지만 구체적으로 기술하고 4인 이상은 "유사하게 진행한다"고만 언급함.
   - 본 프로젝트는 최고 우선권자가 거절자들과 역순으로 순차 1:1 토너먼트를 치르는 방식으로 규칙을 정립함 (`tests/run_tests.gd` 통과).
2. **협상 제안금의 반올림 및 스냅 단위:**
   - 25%, 50%, 75% 프리셋 금액 분배 시 가장 가까운 $5,000 단위로 스냅하며, 정확히 중간값일 경우 제안자(내 몫)가 유리한 쪽으로 배정함.
