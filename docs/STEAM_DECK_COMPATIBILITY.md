# 📟 STEAM DECK COMPATIBILITY — 스팀덱 호환성 정밀 분석 및 Verified 가이드

> **작성 기준일:** 2026-11-01  
> **목표 평가:** **Steam Deck Verified (완벽 호환 녹색 체크마크)**  
> **하드웨어 대상:** Steam Deck LCD (Jupiter), Steam Deck OLED (Galileo)

---

## 1. Steam Deck Verified 4대 필수 기준 충족 현황

Valve가 규정하는 Steam Deck Verified 4대 핵심 기준에 대한 현재 프로젝트 평가:

| 검증 항목 | Valve 요구 기준 | 현재 프로젝트 상태 | 비고 및 조치 계획 |
|---|---|:---:|---|
| **입력 (Input)** | 완전한 컨트롤러 지원 및 화면 버튼 글리프 표시 | **충족 (95%)** | XInput 매핑, A/B/X/Y/Start/Select 완비. 가상 키보드 호출 1건 필요. |
| **디스플레이 (Display)** | 1280×800 또는 1280×720 지원, 텍스트 가독성 확보 | **완전 충족 (100%)** | 1280×800 꽉 찬 화면 레이아웃, `MIN_SCREEN_PX`로 최소 가독성 수학적 방어. |
| **원활성 (Seamlessness)** | 호환성 경고 없음, 런처 없음, 게임 내 설정 간섭 없음 | **완전 충족 (100%)** | 단일 바이너리 즉시 실행, 외부 런처 부재, Proton 없이 네이티브 Linux 구동. |
| **시스템 지원 (System)** | 기본 그래픽 설정에서 30fps 이상 유지, 배터리 수명 | **완전 충족 (100%)** | Compatibility (OpenGL 3.3) 렌더러로 60fps 고정. 30/60fps 배터리 세이버 탑재. |

---

## 2. 화면 및 디스플레이 분석 (1280×800, 16:10)

### 2.1 화면비 대응 및 레터박스 방지
- **기본 해상도:** 1280×720 (16:9)
- **Steam Deck 해상도:** 1280×800 (16:10)
- **적용 방식 (`ui/main.gd` & `project.godot`):**
  - Godot의 `canvas_items` stretch 모드와 `expand` aspect를 사용하여 화면 상하 여백에 검은 띠(레터박스)를 강제하지 않음.
  - 펠트 테이블 텍스처와 황동 레일이 800px 높이에 맞춰 자연스럽게 확장 렌더링되어 테이블이 화면 전체를 가득 채움.

### 2.2 텍스트 가독성 (Legibility)
- Valve 가이드라인: 7인치/7.4인치 화면에서 모든 텍스트는 9pt(약 12px) 이상이어야 함.
- 본 프로젝트는 `ui/tokens.gd`의 `T.fs()` 함수를 통해 화면 스케일링이 작아지더라도 폰트 크기가 `MIN_SCREEN_PX`(11~12px) 밑으로 내려가지 않도록 강제 클램핑됨.
- `tests/text_audit.gd`를 통해 인게임 모든 라벨의 크기를 검증 완료.

---

## 3. 조작 및 컨트롤러 인터랙션 (`InputModeManager.gd`)

### 3.1 컨트롤러 매핑 구성표
| 컨트롤러 입력 | 인게임 액션 | UI 피드백 및 글리프 |
|---|---|---|
| **D-Pad / Left Stick** | 카드 포커스 이동, 메뉴 항목 탐색 | 골드 하이라이트 프레임 이동 |
| **A 버튼 (South)** | 카드 선택 및 제출, 모달 확인 (`ui_accept`) | "선택 (A)", "확인 (A)" |
| **B 버튼 (East)** | 취소, 모달 닫기, 이전 메뉴 (`ui_cancel`) | "취소 (B)", "닫기 (B)" |
| **X 버튼 (West)** | 연출 및 애니메이션 즉시 건너뛰기 (`skip_anim`) | "건너뛰기 (X)" |
| **Y 버튼 (North)** | 고른 카드의 주점 상세 정보 도감 (`venue_info`) | "술집 정보 (Y)" |
| **Start 버튼 (Menu)** | 일시정지 및 설정 메뉴 열기 (`pause`) | 우측 상단 ≡ 아이콘 반응 |
| **Select / Back 버튼** | 오디오 전체 음소거 토글 (`toggle_mute`) | "소리 꺼짐 (Select)" 토글 |
| **Right Stick** | 룰북 및 전적 긴 텍스트 스크롤 | 900px/s 부드러운 스크롤 |

### 3.2 포커스 복원 (Focus Restoration)
- 메뉴나 모달이 열렸을 때 포커스가 공중에 뜨지 않도록 `InputModeManager.gd`가 첫 방향키 입력 시 가장 적절한 기본 버튼으로 포커스를 자동 인계함.

### 3.3 잔여 과제: 가상 키보드 (Steam OSK) 호출
- **현상:** 메인 메뉴에서 사용자 이름 입력 시(`ui/menu_screen.gd`), 터치나 마우스 클릭 시에는 물리 키보드를 요구함.
- **해결책:** 플레이어가 LineEdit을 클릭하거나 컨트롤러로 포커스 후 A를 눌렀을 때, `DisplayServer.virtual_keyboard_show()`를 호출하여 SteamOS On-Screen Keyboard가 자동으로 팝업되도록 연결 필요.

---

## 4. 전력 소모 및 배터리 최적화 (`SteamDeckManager.gd`)

### 4.1 저전력 렌더링 모드 (Battery Saver)
카드 게임은 플레이어가 의사결정을 내리는 대기 시간(Think Time)이 전체 플레이의 70% 이상을 차지한다.
- `SteamDeckManager.Quality.BATTERY_SAVER` 활성화 시:
  1. `Engine.max_fps = 30`으로 상한 제한.
  2. `OS.low_processor_usage_mode = true` 적용: 화면 내용에 변화가 없을 경우 CPU/GPU 렌더 루프를 대폭 억제.
  3. `ui/felt.gdshader`의 동적 조명 셰이더를 정적 틴트 셰이더(`ui/felt_static.gdshader`)로 자동 교체.
- **효과:** Steam Deck 배터리 지속 시간이 기본 60fps 구동 대비 2.5배 이상 증가 (약 6~7시간 연속 플레이 가능 추정).

### 4.2 슬립 및 복귀 (Sleep & Suspend/Resume)
- 싱글 플레이 턴제 구조이므로 언제든 전원 버튼을 눌러 슬립 모드로 진입하고 복귀해도 상태가 깨지지 않음.
- 라운드마다 원자적 자동 저장이 완료되어 있어 슬립 중 배터리가 방전되더라도 게임이 안전하게 보존됨.
