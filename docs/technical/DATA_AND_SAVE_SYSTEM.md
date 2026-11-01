# 💾 DATA AND SAVE SYSTEM — 데이터 저장 및 세이브 시스템 명세

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/technical/PROJECT_ARCHITECTURE.md`](PROJECT_ARCHITECTURE.md), [`docs/development/TESTING_GUIDE.md`](../development/TESTING_GUIDE.md)

---

## 1. 저장소 파일 레이아웃 (`user://`)

런타임 데이터는 Godot의 샌드박스 사용자 디렉토리(`user://`) 내 3개의 파일로 분리되어 관리됩니다.

```text
user://
├── autosave.json        # 인게임 듀얼 슬롯 자동 저장 데이터 (JSON)
├── settings.cfg         # 사용자 환경설정 (ConfigFile / INI)
└── records.json         # 역대 전적 통계 및 13종 도전과제 달성도 (JSON)
```

---

## 2. 듀얼 슬롯 자동 저장 시스템 (`ui/save_store.gd`)

### 2.1 슬롯 분리 정책
- **슬롯 1 (`slot_1`):** 클래식 모드(Classic Mode) 진행 데이터 전용.
- **슬롯 2 (`slot_2`):** 유물 모드(Relic Mode) 진행 데이터 전용.
두 모드는 별개의 슬롯에 독립적으로 기록되므로, 클래식 모드를 하다가 유물 모드를 새로 시작해도 이전 클래식 게임이 덮어쓰여지지 않습니다.

### 2.2 원자적 쓰기 (Atomic Write) 파이프라인
저장 도중 앱이 강제 종료되거나 배터리가 방전되어 데이터가 깨지는 것을 방지하기 위해 2단계 원자적 교체 방식을 적용합니다:
1. 직렬화된 JSON 데이터를 `user://autosave.json.tmp`에 완전하게 기록.
2. 기록 성공 확인 후, 파일 시스템 레벨에서 `autosave.json`으로 원자적 이름 변경(Rename/Replace).

### 2.3 세이브 데이터 스키마
```json
{
  "version": 1,
  "slot_1": {
    "saved_at": 1730412000,
    "mode": "classic",
    "engine_state": {
      "phase": "CARD_SELECTION",
      "round": 3,
      "croupier": 1,
      "bar_money": { "COLIBRI": 45000, "COTTON_CLUB": 20000, ... },
      "players": [ ... ],
      "rng": 1284918237
    }
  },
  "slot_2": null
}
```

---

## 3. 사용자 설정 스키마 (`user://settings.cfg`)

```ini
[game]
language="ko"              ; "ko" 또는 "en"
speed_multiplier=1.0       ; 애니메이션 배속 (1.0, 1.5, 2.0)
screen_shake=true          ; 화면 흔들림 효과 켜기/끄기
beginner_hints=true        ; 협상 승률 가이드 표시 여부

[audio]
master_volume=1.0          ; 0.0 ~ 1.0
bgm_volume=0.8
sfx_volume=0.9

[display]
fullscreen=false
fps_limit=60               ; Steam Deck 배터리 모드 시 30 또는 40
```

---

## 4. 전적 및 도전과제 스키마 (`user://records.json`)

플레이어의 누적 전적(총 플레이 판수, 승률, 누적 상금, 최고 판돈)과 13종의 업적(`ACH_FIRST_WIN`, `ACH_RAZZIA_SWEEP`, `ACH_DUEL_MASTER` 등) 달성 여부 및 달성 시각을 보관합니다.

---

## 5. 테스트 실행 격리 샌드박스 (Test Isolation)

자동화 테스트(`tests/*.gd`)를 실행할 때 실제 유저의 세이브나 설정이 오염되는 것을 방지하기 위해:
- 테스트 프로세스의 고유 PID를 따서 `user://test_<pid>_autosave.json` 형태의 임시 격리 경로를 사용합니다.
- 테스트 완료 후 해당 임시 파일들은 자동으로 안전하게 삭제 정리됩니다.
