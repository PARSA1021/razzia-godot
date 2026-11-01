# 🎮 STEAM INTEGRATION — Steamworks 연동 계획 및 플랫폼 기술 명세

> **작성 기준일:** 2026-11-01  
> **대상 플랫폼:** PC (Windows, Linux, macOS), Steam Deck (SteamOS)  
> **연동 방식 권고:** **GodotSteam GDExtension (Godot 4.3 호환)**

---

## 1. Steamworks 통합 솔루션 비교 및 선정

Godot 4.3에서 Steamworks API를 연동하는 세 가지 접근법을 비교 평가한다.

| 비교 항목 | 옵션 A: GodotSteam GDExtension (추천) | 옵션 B: Godot 엔진 커스텀 빌드 | 옵션 C: 순수 GDScript C-FFI / Wrapper |
|---|---|---|---|
| **설치 편의성** | 높음 (`addons/godotsteam`에 바이너리 배치) | 매우 낮음 (엔진 소스코드 전체 컴파일 필요) | 보통 (Godot 4의 GDExtension 직접 래핑) |
| **유지보수성** | 우수 (Godot 버전 업데이트 시 확장만 교체) | 취약 (엔진 패치 시마다 재컴파일) | 취약 (수동 API 바인딩 유지보수 부담) |
| **호환성** | Godot 4.3 공식 지원 | 완벽 (엔진 내장 모듈) | 제한적 |
| **플랫폼 지원** | Windows, Linux/SteamOS, macOS | 모든 데스크톱 플랫폼 | 플랫폼별 빌드 필요 |
| **최종 평가** | **채택 (가장 안전하고 낭비 없는 솔루션)** | 비권장 (1인 개발 리소스 낭비 극심) | 비권장 (안정성 미검증) |

---

## 2. 세부 Steamworks 기능 구현 계획

### 2.1 Steam 초기화 및 라이프사이클 (`SteamManager.gd` 신규 오토로드)
- **목표:** 게임 부팅 시 `Steam.steamInitEx()` 호출 및 Steam 클라이언트 구동 확인.
- **예외 처리:**
  - Steam 클라이언트 없이 실행된 경우(개발/테스트 모드 또는 DRM Free 배포), 비활성 모드(Mock Mode)로 안전하게 격리되어 충돌 없이 실행되도록 보장.
  - `SteamAppId` 환경 변수 또는 `steam_appid.txt` (개발 시) 배치.
- **종료 처리:** 게임 종료 시 `Steam.steamShutdown()` 호출.

### 2.2 Steam 도전과제 (Steam Achievements)
현재 `ui/records.gd`에 정의된 13종의 업적을 Steamworks API와 1:1로 매핑한다.

| 인게임 ID (`ui/records.gd`) | Steam API 이름 (권고) | 명칭 (한국어 / English) | 달성 조건 |
|---|---|---|---|
| `first_win` | `ACH_FIRST_WIN` | 첫 승리 / First Victory | 매치 최종 1위 달성 |
| `first_razzia` | `ACH_FIRST_RAZZIA` | 경찰을 불러라 / Call the Cops | 한 매치에서 RAZZIA(단속) 1회 이상 발동 |
| `duel_3` | `ACH_DUEL_3` | 결투의 맛 / Taste of Duel | 한 매치에서 주사위 결투 3승 달성 |
| `duel_flawless` | `ACH_DUEL_FLAWLESS` | 무패의 결투사 / Undefeated Duelist | 결투 2회 이상 참여 및 전승 |
| `solo_5` | `ACH_SOLO_5` | 독점 사업 / Solo Monopoly | 한 매치에서 혼자 독점한 주점 5곳 이상 |
| `big_hit` | `ACH_BIG_HIT` | 대박 / Big Score | 단일 주점에서 $150,000 이상 일시 획득 |
| `big_round` | `ACH_BIG_ROUND` | 풍년 / Bountiful Harvest | 단일 라운드에서 총 $200,000 이상 획득 |
| `dealmaker` | `ACH_DEALMAKER` | 협상의 달인 / Master Negotiator | 자신의 분배 제안이 통과된 횟수 3회 이상 |
| `comeback` | `ACH_COMEBACK` | 역전극 / The Great Comeback | 6라운드 종료 시 꼴찌에서 최종 우승 |
| `full_table` | `ACH_FULL_TABLE` | 만원 테이블 / Packed House | 8인 매치에서 최종 1위 달성 |
| `games_10` | `ACH_GAMES_10` | 단골손님 / Regular Customer | 총 10게임 플레이 완료 |
| `wins_5` | `ACH_WINS_5` | 이 구역의 주인 / Boss of Chicago | 통산 5회 우승 달성 |
| `streak_3` | `ACH_STREAK_3` | 연승 행진 / Winning Streak | 3연속 우승 달성 |

**연동 구조:**
`ui/records.gd`의 `unlock_achievement(id)` 메서드 내부에서:
```gdscript
if SteamManager.is_steam_active():
    Steam.setAchievement(STEAM_ID_MAP[id])
    Steam.storeStats()
```
로컬 JSON과 Steam 서버 양쪽에 원자적으로 동기화.

---

### 2.3 Steam Cloud 세이브 연동
- **연동 전략:** 복잡한 ISteamRemoteStorage API 호출 대신 **Steam AutoCloud** 설정을 우선 채택.
- **이유:**
  - 본 프로젝트는 이미 `user://autosave.json`, `user://autosave_2.json`, `user://records.json`으로 파일이 깔끔하게 분리되어 있음.
  - Steamworks 백엔드 상점 설정에서 `user://` 폴더 경로만 AutoCloud로 지정하면 코드 한 줄 수정 없이 크로스 플랫폼 동기화 가능.
- **충돌 방지 설계:**
  - Steam Cloud 충돌 발생 시 Steam 클라이언트가 타임스탬프를 기준으로 사용자에게 선택을 요청함.
  - `save_store.gd`의 기존 `.bak` 백업 및 파손 격리(`.corrupt`) 파이프라인 덕분에 클라우드 파일 덮어쓰기 오류가 발생해도 복구 가능.

---

### 2.4 Steam Input 및 Steam Deck 컨트롤러
- **현재 상태:** `InputModeManager.gd`에서 일반 XInput 및 DirectInput 게임패드를 완벽히 지원 중.
- **Steam Input 지원 방향:**
  - 초기 출시(v1.0): **Gamepad Template (기본 컨트롤러 템플릿)** 활용. Steamworks 설정에서 기본 템플릿을 'Standard Gamepad'로 지정.
  - 향후 개선(v1.1): Steam Input Action Set (인게임 액션 바인딩) 파일 `game_actions.vdf` 도입.

---

## 3. 플랫폼별 빌드 및 배포 파이프라인

### 3.1 Steam 빌드 브랜치 전략
- `default` (출시 브랜치): 정식 상용화 빌드.
- `beta` (베타 브랜치): 테스터 대상 사전 검증 빌드 (암호화 키 적용).
- `nightly` (개발 브랜치): CI 자동 빌드 업로드.

### 3.2 SteamPipe 배포 자동화
`steamcmd`를 이용한 원터치 배포 스크립트 구축:
```text
steamcmd +login <USER> +run_app_build <BUILD_SCRIPT_VDF> +quit
```
- Content Depot 1: Windows 실행 파일 (`razzia.exe`, `razzia.pck`)
- Content Depot 2: Linux/Steam Deck 실행 파일 (`razzia.x86_64`, `razzia.pck`)
- Content Depot 3: macOS App 번들 (`Razzia.app`)

---

## 4. 위험 요소 및 장애 대비책 (Troubleshooting)

1. **GDExtension 버전 불일치:**
   - 위험: Godot 4.3용으로 컴파일된 GodotSteam GDExtension 바이너리를 사용해야 함. 버전 불일치 시 엔진 부팅 실패.
   - 대책: GodotSteam v4.12+ (Godot 4.3 대응 공식 릴리즈) 사전 검증 바이너리 고정.
2. **Steam Deck 오버레이 미표시:**
   - 원인: OpenGL 3 / Compatibility 렌더러 사용 시 gamescope 환경에서 오버레이 훅 간섭 가능성.
   - 대책: Steam Deck 실기기에서 Steam 버튼 및 `...` 오버레이 호출 프레임 검증.
