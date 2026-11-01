# ⚙️ TECHNICAL OVERVIEW — 기술 스택 및 환경 명세서

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/technical/PROJECT_ARCHITECTURE.md`](PROJECT_ARCHITECTURE.md), [`docs/technical/BUILD_AND_DEPLOYMENT.md`](BUILD_AND_DEPLOYMENT.md)

---

## 1. 핵심 기술 스택 (Core Technology Stack)

| 계층 | 사용 기술 | 선정 이유 및 기술적 특성 |
|---|---|---|
| **게임 엔진** | **Godot Engine 4.3 (Stable)** | 가볍고 빠른 실행, 뛰어난 2D 캔버스 성능, macOS/Linux/Windows 및 모바일 무결점 크로스 플랫폼 지원 |
| **스크립팅 언어** | **GDScript 2.0** | 정적 타입 힌트(`static typing`) 완벽 지원, 노드 트리 라이프사이클과의 네이티브 결합, 빠른 빌드 및 핫리로딩 |
| **렌더링 드라이버** | **Compatibility (OpenGL 3.3 / OpenGL ES 3.0)** | 구형 인텔 내장 그래픽, 저전력 모바일 GPU, 스팀덱(SteamOS) 전반에서 안정적이고 가벼운 60fps 보장 |
| **난수 엔진** | **Mulberry32 32-bit PRNG** | JavaScript 표준 및 골든 데이터와 비트 단위 일치, 완전한 결정론적 리플레이 보장 |
| **데이터 직렬화** | **JSON & Godot ConfigFile** | 사람이 읽을 수 있고 버전 관리가 용이한 세이브 파일 및 사용자 설정 저장 포맷 |
| **외부 의존성** | **Zero External Plugins** | 엔진 내장 기능과 표준 GDScript만으로 구성하여 플러그인 호환성 붕괴 위험을 원천 차단 |

---

## 2. 프로젝트 설정 명세 (`project.godot`)

```ini
[application]
config/name="Razzia Mobile"
run/main_scene="res://ui/main.tscn"
config/features=PackedStringArray("4.3", "Compatibility")

[autoload]
SteamDeckManager="*res://platform/steam_deck_manager.gd"
InputModeManager="*res://platform/input_mode_manager.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/vsync/vsync_mode=1

[rendering]
renderer/rendering_method="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
```

---

## 3. 화면 스케일링 및 반응형 해상도 아키텍처

- **기준 해상도:** 가로 모드 1280×720 (16:9).
- **스트레치 정책:** `mode="canvas_items"`, `aspect="expand"`.
  - 가로가 더 넓거나 좁은 화면(Steam Deck 1280×800 16:10, 울트라와이드 21:9)에서는 좌우 또는 상하 여백에 레터박스를 강제하지 않고, 펠트 테이블을 확장 렌더링하여 광활한 공간감을 제공합니다.
  - 세로 모드(모바일 720×1280) 감지 시 자동으로 세로 전용 컴팩트 뷰포트로 전환됩니다.

---

## 4. 성능 목표 및 하드웨어 프로파일링

- **프레임레이트:** 일반 PC/모바일 기본 60fps 고정. Steam Deck 배터리 모드 시 30fps/40fps 절전 옵션 지원.
- **메모리 사용량:** 텍스처 아틀라스 및 에셋 최적화를 통해 런타임 VRAM 150MB 이하, 총 RAM 250MB 이하 유지.
- **콜드 스타트 타임:** 앱 실행 후 메인 메뉴 표시까지 1.5초 이내.
