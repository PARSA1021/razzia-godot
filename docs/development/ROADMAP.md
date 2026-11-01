# 🗺️ ROADMAP — 향후 개발 계획 및 마일스톤

> **상위 문서:** [`docs/README.md`](../README.md)  
> **상세 출시 로드맵 (Phase 1 ~ 5 P0/P1 작업 명세):** [`docs/STEAM_RELEASE_ROADMAP.md`](../STEAM_RELEASE_ROADMAP.md)  
> **관련 문서:** [`docs/development/DEVELOPMENT_STATUS.md`](DEVELOPMENT_STATUS.md), [`docs/development/CHANGELOG.md`](CHANGELOG.md)

---

## 1. 마일스톤 로드맵 개요

```text
[현재] Phase 30 ──> [Phase 1~3] 스팀 출시 준비 ──> [v1.0] 스팀 정식 출시 ──> [v1.5] 유물 확장팩 ──> [v2.0] 온라인 멀티
(출시 종합 감사)     (리브랜딩/SDK/Deck)         (Steam Deck 완벽 인증)       (신규 유물 12종)        (P2P 네트워크 로비)
```

상세한 Steam 출시 5단계 작업(우선순위, 중요도, 난이도, 선행 조건, 완료 기준)은 최상위 전략 문서인 [`docs/STEAM_RELEASE_ROADMAP.md`](../STEAM_RELEASE_ROADMAP.md)에서 관리됩니다.

---

## 2. 세부 마일스톤 계획

### Milestone 1: Steam 출시 준비 및 기술 통합 (Phase 1 ~ 3)
- **목표:** 상표권 리스크 해소, 결함 3건 해결, Steamworks API 연동.
- **주요 작업:**
  - 상표권 회피를 위한 독자 1920s 시카고 타이틀 리브랜딩 확정.
  - `export_presets.cfg` 생성 및 Windows/Linux/macOS 빌드 파이프라인 수립.
  - GodotSteam GDExtension 연동 (Steam 13종 도전과제 및 AutoCloud 세이브).
  - Steam Deck 가상 키보드(OSK) 바인딩 및 텍스트 가독성 검증.

### Milestone 2: v1.0 — Steam 정식 출시 & Steam Deck Verified (출시 목표)
- **목표:** PC 및 Steam Deck 정식 상용화 배포.
- **주요 작업:**
  - Steam Deck Verified 기준 100% 충족 검증 (텍스트 크기, 기본 컨트롤러 프로파일, 배터리 소모량).
  - 커뮤니티 트레일러(60초) 및 캡슐 그래픽 4종 제작.
  - 글로벌 유료 출시 ($4.99 ~ $6.99).

### Milestone 3: v1.5 — 유물 모드 확장 & 보스 챌린지 (콘텐츠 업데이트)
- **목표:** 싱글 플레이 로그라이크 모드의 깊이 확장.
- **주요 작업:**
  - 신규 유물 12종 추가 (특정 바 전용 시너지, 경찰 매수 연계 등).
  - '알 카포네(Al Capone)' 특별 보스 챌린지 모드 (치트급 스킬을 사용하는 보스와의 1:1 대결).
  - 일일 도전(Daily Run) 모드 지원 (매일 고정된 시드로 전 세계 플레이어와 점수 경쟁).

### Milestone 4: v2.0 — 온라인 멀티플레이어 (장기 연구 과제)
- **목표:** 3~8인 실시간 온라인 매치메이킹 지원.
- **주요 연구 과제:**
  - 결정론적 턴제 넷코드(Lockstep 또는 비동기 웹소켓 서버) 설계.
  - 비공개 카드 선택 시 패킷 암호화를 통한 맵핵/패킷 치팅 원천 방지.
  - 친구 초대 프라이빗 룸 및 텍스트/이모티콘 휠 지원.
