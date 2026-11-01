# 🧪 TESTING GUIDE — 테스트 실행 및 품질 보증(QA) 가이드

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/technical/BUILD_AND_DEPLOYMENT.md`](../technical/BUILD_AND_DEPLOYMENT.md), [`docs/development/DEVELOPMENT_STATUS.md`](DEVELOPMENT_STATUS.md)

---

## 1. 테스트 철학: 무결점 결정론적 검증

RAZZIA는 **"엔진의 단 1비트 오차나 규칙 왜곡도 허용하지 않는다"**는 원칙 아래, 51개의 전용 자동화 테스트 스크립트와 52개의 골든 리플레이 픽스처를 보유하고 있습니다.

---

## 2. 테스트 실행 방법

### 2.1 전체 통합 테스트 스위트 (109 Checks)
가장 핵심적인 회귀 테스트 스위트로, PR 제출 전 반드시 실행해야 합니다.

```bash
# Godot 바이너리를 통한 헤드리스 실행
godot --headless --script res://tests/run_tests.gd

# 또는 간이 셸 스크립트 실행
./run_tests.sh
```

**통과 기준:**
```text
109 checks, 0 failed, 18.9s
RESULT: PASS
```

### 2.2 서브시스템별 단독 테스트 실행
특정 기능을 수정한 경우 해당 전용 테스트 스크립트를 즉시 실행할 수 있습니다.

```bash
# 1. 유물 시스템 및 암시장 경제 검증
godot --headless --script res://tests/relic_system_test.gd

# 2. UI 렌더링 스모크 및 화면 리사이즈 검증
godot --headless --script res://tests/ui_smoke.gd

# 3. 플랫폼 입력 전환 (패드/터치/마우스) 검증
godot --headless --script res://tests/platform_test.gd

# 4. 세이브/로드 및 이어하기 무결성 검증
godot --headless --script res://tests/save_resume_test.gd

# 5. 텍스트 가독성 및 최소 폰트 크기 오딧
godot --headless --script res://tests/text_audit.gd

# 6. 정적 리소스 경로 전수 검사 (Python)
python3 tools/check_paths.py
```

---

## 3. 골든 리플레이 테스트 구조 (`tests/golden/`)

`tests/golden/` 디렉터리에는 미리 계산된 52개 시드의 전체 경기 액션 및 상태 해시가 보관되어 있습니다.
- 엔진의 룰 계산식이 조금이라도 바뀌면 골든 리플레이와 불일치가 발생하여 즉시 테스트가 실패합니다.
- 만약 의도적으로 게임 규칙을 변경한 경우, `tools/regenerate_golden.sh`를 통해 공식 승인 절차를 거쳐 골든 데이터를 갱신해야 합니다.

---

## 4. 테스트 샌드박스 격리 (Test Isolation)

모든 테스트는 실행 시 자동으로 `user://test_<pid>_*` 경로를 생성하여 실행되며, 테스트 종료 시 깨끗하게 삭제됩니다. 실제 사용자의 세이브 데이터(`user://autosave.json`)나 환경 설정이 훼손될 염려가 없습니다.
