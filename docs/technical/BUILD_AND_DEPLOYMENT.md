# 🚀 BUILD AND DEPLOYMENT — 빌드, 배포 및 플랫폼 최적화 가이드

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/technical/TECHNICAL_OVERVIEW.md`](TECHNICAL_OVERVIEW.md), [`docs/development/TESTING_GUIDE.md`](../development/TESTING_GUIDE.md)

---

## 1. 개발 환경 요구사항

- **게임 엔진:** Godot Engine 4.3 Stable (Standard 버전)
- **개발 운영체제:** macOS (Apple Silicon / Intel), Windows 10/11, Linux (Ubuntu 22.04+)
- **보조 도구:** Python 3.10+ (폰트 서브셋팅, 오디오 생성, 리소스 경로 검증)

---

## 2. CLI 실행 명령어 (macOS / Linux / Windows)

### 2.1 에디터 GUI 실행
```bash
# macOS
open -a "Godot" --args --path .

# Linux / Windows
godot --editor --path .
```

### 2.2 게임 즉시 실행
```bash
godot --path .
```

### 2.3 헤드리스 통합 테스트 실행
```bash
godot --headless --script res://tests/run_tests.gd
```

---

## 3. 플랫폼별 익스포트(Export) 가이드

Godot 에디터 상단 메뉴 `프로젝트(Project) -> 내보내기(Export)`에서 각 플랫폼별 템플릿을 설정합니다.

### 3.1 Steam Deck & SteamOS 최적화
- **프리셋:** Linux/X11 (x86_64)
- **특화 기능 (`platform/steam_deck_manager.gd`):**
  - 실행 환경이 SteamOS 또는 Steam Deck 하드웨어임을 자동 감지.
  - 전원 연결 상태에 따라 기본 60fps, 배터리 구동 시 30fps/40fps 절전 모드 자동 제안.
  - 1280×800 (16:10) 해상도에 맞춰 펠트 테이블 상하 여백 최적 확장.
  - Steam Deck 내장 컨트롤러를 표준 XInput 게임패드로 100% 매핑.

### 3.2 데스크톱 (Windows / macOS)
- **Windows:** `razzia.exe` 단일 바이너리 및 `.pck` 패키징.
- **macOS:** Universal Binary (x86_64 + arm64) `.app` 번들 및 공증(Notarization) 준비.

### 3.3 모바일 (Android / iOS)
- **Android:**
  - Gradle 빌드 템플릿 활성화.
  - 최소 SDK 버전: Android 8.0 (API Level 26).
  - VRAM 압축 포맷: ETC2 / ASTC.
- **iOS:**
  - Xcode 프로젝트 익스포트.
  - 최소 지원 버전: iOS 14.0+.

---

## 4. 지속적 통합(CI/CD) 파이프라인

프로젝트 루트의 `tools/ci_check.sh` 스크립트를 통해 원터치로 전체 빌드 사전 검증을 수행할 수 있습니다.

```bash
# CI 검증 스크립트 실행
./tools/ci_check.sh
```

### CI 파이프라인 검증 단계:
1. **정적 리소스 무결성 검증 (`tools/check_paths.py`):**
   - 650개 이상의 `res://` 경로가 파일 시스템에 실존하는지 전수 조사.
2. **골든 엔진 리플레이 검증 (`tests/run_tests.gd`):**
   - 52개 시드에 대한 상태 머신 전이 및 룰 불변식(INV-001~005) 109개 항목 검증.
3. **UI 스모크 테스트 (`tests/ui_smoke.gd`):**
   - 메인 메뉴 진입, 게임 화면 생성, 해상도 리사이즈 시 크래시 여부 검증.
