# 📦 ASSET CATALOG — 시각 에셋 및 리소스 등록부

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/assets/AUDIO_ASSET_LIST.md`](AUDIO_ASSET_LIST.md), [`CREDITS.md`](../../CREDITS.md), [`docs/design/ART_DIRECTION.md`](../design/ART_DIRECTION.md)

---

## 1. 개요 및 라이선스 정책

본 프로젝트에서 사용되는 모든 그래픽, 일러스트, 폰트 및 벡터 아이콘은 저작권 및 오픈소스 라이선스를 엄격히 준수합니다.

---

## 2. 6대 비밀 주점 포스터 (`assets/art/bars/`)

| 파일명 | 해상도 | 용량 | 대상 장소 | 테마 컬러 |
|---|---|---:|---|---|
| `COLIBRI.jpg` | 1024×1536 | 1.07 MB | 콜리브리 (고급 살롱) | 로열 블루 (`#2f6fb0`) |
| `COTTON_CLUB.jpg` | 1024×1536 | 1.25 MB | 코튼 클럽 (할렘 재즈 클럽) | 크림슨 레드 (`#b23a3a`) |
| `HAVANA_BAR.jpg` | 1024×1536 | 1.07 MB | 하바나 바 (럼 밀수 바) | 웜 골드 (`#c9a431`) |
| `THE_JUNGLE.jpg` | 1024×1536 | 1.17 MB | 더 정글 (무법지대 부둣가 바) | 에메랄드 그린 (`#2f9e55`) |
| `LINCOLNS.jpg` | 512×768 | 119 KB | 링컨스 (비밀 정치가 클럽) | 임페리얼 퍼플 (`#8a4fb0`) |
| `JAZZ_HOUSE.jpg` | 512×768 | 124 KB | 재즈 하우스 (심야 잼세션 클럽) | 선셋 오렌지 (`#d9731f`) |

---

## 3. 카드 일러스트 에셋 (`assets/art/cards/`)

총 26개 파일:
1. `razzia.jpg`: 범용 경찰 단속 백그라운드 (66 KB)
2. `razzia_<VENUE>.jpg` (6종): 각 주점별 특화된 경찰 급습 고해상도 포스터 (각 약 1.1 MB)
3. `zocker_<VENUE>.jpg` (6종): 각 주점별 도박꾼 캐릭터 일러스트 (각 약 70~120 KB)

---

## 4. 캐릭터 일러스트 에셋

### 4.1 소형 아바타 흉상 (`assets/characters/`)
HUD 순위표 및 미니 카드 모서리에 렌더링되는 원형 초상화 (각 약 100 KB, PNG 투명 배경):
- `Vito.png`, `Lola.png`, `Mack.png`, `Dutch.png`, `Rosie.png`, `Sal.png`, `Nico.png`

### 4.2 대형 전신 일러스트 (`assets/characters_full/`)
결투 모달 및 컷씬 대화창(`dialogue_scene.gd`)에서 사용되는 고해상도 전신 스탠딩 (각 약 230 KB, PNG 투명 배경):
- `Vito.png`, `Lola.png`, `Mack.png`, `Dutch.png`, `Rosie.png`, `Sal.png`, `Nico.png`

---

## 5. 벡터 아이콘 에셋 (`assets/icons/`)

모든 벡터 아이콘은 [game-icons.net](https://game-icons.net)의 **CC BY 3.0** 라이선스를 따릅니다.

### 5.1 시스템 아이콘 (`assets/icons/system/`)
- `challenger.svg`: 결투 도전자 뱃지 (리볼버)
- `defender.svg`: 결투 방어자 뱃지 (다이얼 금고)
- `die_face.svg`: 6면체 주사위 굴리기 액션
- `lock.svg`: 잠금 / 보호 상태
- `police_raid.svg`: 경찰 단속 경보 배너 (사이렌)
- `reroll.svg`: 암시장 매물 새로고침 (회전 화살표)

### 5.2 유물 아이콘 (`assets/icons/relics/`)
8종 활성 유물 + 1종 폴백:
- `lucky_coin.svg`: 행운의 동전
- `protection_racket.svg`: 보호세 수금원
- `informant.svg`: 비밀 정보원
- `swiss_account.svg`: 스위스 비밀계좌
- `bribed_judge.svg`: 매수한 판사
- `loaded_dice.svg`: 조작된 주사위
- `dirty_cop.svg`: 부패한 경관
- `syndicate_crest.svg`: 신디케이트 문장
- `fallback_relic.svg`: 기본 계약서 서류

### 5.3 장소 벡터 심볼 (`assets/icons/venues/`)
색약 사용자를 위한 고유 실루엣 아이콘 6종:
- `colibri.svg`, `cotton_club.svg`, `havana_bar.svg`, `the_jungle.svg`, `lincolns.svg`, `jazz_house.svg`

### 5.4 후보 에셋 보관소 (`assets/icons/candidates/`)
디자인 확장 및 추가 유물 선정을 위해 사전 확보된 리소스 12종 (보류 상태 보존).

---

## 6. 활성 글꼴 (Fonts)

| 폰트 파일명 | 서체명 | 라이선스 | 용량 | 용도 |
|---|---|---|---:|---|
| `StintUltraExpanded-Regular.ttf` | Stint Ultra Expanded | SIL OFL 1.1 | 42 KB | 메인 로고 및 영문 대형 타이틀 |
| `PlayfairDisplay.ttf` | Playfair Display | SIL OFL 1.1 | 300 KB | 고정폭 판돈 금액 렌더링 |
| `SpecialElite.ttf` | Special Elite | Apache 2.0 | 166 KB | 타자기 폰트, 단속 스탬프 |
| `NotoSansKR.ttf` | Noto Sans KR | SIL OFL 1.1 | 10.4 MB | 범용 UI 및 시스템 한글 텍스트 |
| `Lora.ttf` | Lora | SIL OFL 1.1 | 212 KB | 영문 컷씬 대사 및 서사 |
| `Hahmlet-Subset.ttf` | Hahmlet (Subset) | SIL OFL 1.1 | 679 KB | 한글 컷씬 대사 (빈출 음절 경량화) |
| `Hahmlet.ttf` | Hahmlet (Master) | SIL OFL 1.1 | 3.55 MB | 서브셋 재생성용 마스터 폰트 (보존) |
