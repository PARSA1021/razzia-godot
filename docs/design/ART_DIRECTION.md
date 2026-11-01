# 🎨 ART DIRECTION — 비주얼 스타일 및 아트 디렉션 가이드

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/design/UI_UX_GUIDELINES.md`](UI_UX_GUIDELINES.md), [`docs/assets/ASSET_CATALOG.md`](../assets/ASSET_CATALOG.md), [`docs/story/WORLD_BUILDING.md`](../story/WORLD_BUILDING.md)

---

## 1. 비주얼 콘셉트: 아르데코 & 필름 누아르 (Art Deco & Film Noir)

RAZZIA의 비주얼 정체성은 **1920년대 미국의 아르데코(Art Deco) 기하학 양식**과 **필름 누아르(Film Noir)의 극적인 명암 대비(Chiaroscuro)**의 결합입니다.

- **황동과 벨벳 (Brass & Velvet):** 호화로운 카지노의 황동 가드레일, 묵직한 마호가니 원목, 짙은 녹색과 검은색의 벨벳 테이블 펠트.
- **빛과 그림자:** 스피크이지 지하의 은은한 백열구 램프, 경찰 단속 시 유리창을 뚫고 들어오는 서치라이트의 날카로운 광선.
- **정제된 레트로:** 과도하게 낡은 빈티지 질감보다는, 고급스러움과 절제미를 유지하는 벡터 그래픽 및 고해상도 일러스트의 조화.

---

## 2. 디자인 컬러 토큰 시스템 (`ui/tokens.gd`)

모든 색상은 하드코딩되지 않고 `ui/tokens.gd`의 상수를 통해 전역 통제됩니다.

### 2.1 베이스 환경 팔레트
| 토큰 상수 | 16진수 코드 | 미리보기 | 용도 |
|---|---|---|---|
| `BG_DEEP` | `#0a0907` | ⬛ 흑갈색 | 최하단 배경 및 윈도우 레터박스 |
| `BG_PANEL` | `#15110c` | 🟫 다크 마호가니 | 주 패널, 모달 배경 |
| `BG_PANEL_2` | `#1f1810` | 🟫 소프트 마호가니 | 중첩 패널, 툴팁, 버튼 배경 |
| `FELT` | `#0f1a14` | 🟩 딥 포레스트 그린 | 게임 테이블의 펠트 바닥 |
| `BRASS` | `#a8854a` | 🟨 빈티지 황동 | 프레임, 분할선, 비활성 엠블럼 |
| `GOLD` | `#d6b274` | 🟨 브라이트 골드 | 주요 타이틀, 활성 테두리, 판돈 금액 |
| `GOLD_DIM` | `#7d6743` | 🟤 앤틱 골드 | 보조 라벨, 딤드 텍스트 |
| `TEXT` | `#ece0c4` | ⬜ 웜 크림 아이보리 | 본문 및 기본 가독 텍스트 |
| `TEXT_DIM` | `#a89674` | 🟤 샌드 베이지 | 힌트, 보조 설명문, 설명 각주 |
| `DANGER` | `#c9402f` | 🟥 크림슨 레드 | 결투 신청, 경고, 거절, 탈락 |
| `POLICE_BLUE` | `#2f6fd0` | 🟦 사이렌 블루 | 경찰 단속(RAZZIA) 배너, 체포 이펙트 |
| `OK` | `#3ecf6e` | 🟩 에메랄드 그린 | 수락, 구매 확인, 승리 강조 |

### 2.2 6대 주점 고유 테마 컬러
- `COLIBRI`: `#2f6fb0` (로열 사파이어 블루)
- `COTTON_CLUB`: `#b23a3a` (벨벳 크림슨 레드)
- `HAVANA_BAR`: `#c9a431` (빈티지 웜 골드)
- `THE_JUNGLE`: `#2f9e55` (에메랄드 딥 그린)
- `LINCOLNS`: `#8a4fb0` (임페리얼 퍼플)
- `JAZZ_HOUSE`: `#d9731f` (선셋 앰버 오렌지)

---

## 3. 타이포그래피 계층 (Typography Hierarchy)

폰트는 무작위로 사용되지 않으며, `ui/tokens.gd`의 `font(kind, weight)` 인터페이스를 통해 용도별로 엄격히 제한됩니다.

| 식별자 | 서체 (Font Family) | 라이선스 | 용도 및 특징 |
|---|---|---|---|
| `"title"` | **Stint Ultra Expanded** | SIL OFL 1.1 | 게임 로고, 대형 화면 타이틀, 장소명 영문 대문자 표기 |
| `"money"` | **Playfair Display** | SIL OFL 1.1 | 판돈 금액(`$50,000`), 고정폭 숫자(`tnum` 활성화) 정렬 |
| `"stamp"` | **Special Elite** | Apache 2.0 | 단속 스탬프(`RAZZIA`), 기밀 서류 도장, 타자기 효과 |
| `"ui"` | **Noto Sans KR** | SIL OFL 1.1 | 범용 버튼, HUD 라벨, 시스템 설정, 규칙 설명 본문 |
| `"dialogue"` | **Lora + Hahmlet-Subset** | SIL OFL 1.1 | 컷씬 대사, 캐릭터 서사 텍스트 (영문 세리프 + 한글 명조) |

---

## 4. 셰이더 및 머티리얼 효과 (Shaders & VFX)

1. **프로시저럴 펠트 셰이더 (`ui/felt.gdshader`):**
   - 부드러운 노이즈 텍스처와 비네팅, 미세한 조명 하이라이트를 수학적으로 계산하여 고급 카지노 테이블의 질감을 재현.
   - 저사양 기기(모바일/배터리 모드)에서는 고정 틴트 셰이더(`ui/felt_static.gdshader`)로 자동 전환.
2. **황동 레일 드로잉 (`ui/board/board_layout.gd`):**
   - 2중 원호와 직사각형 베지어 곡선을 활용한 프로시저럴 아르데코 프레임 렌더링.
3. **단속 연출 서치라이트 (`ui/raid_fx.gd`):**
   - 경찰 단속 시 화면 전체에 푸른빛과 붉은빛의 회전형 서치라이트 빔을 투사.
