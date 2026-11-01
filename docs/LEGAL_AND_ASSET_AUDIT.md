# ⚖️ LEGAL AND ASSET AUDIT — 지식재산권, 상표권 및 에셋 라이선스 감사 보고서

> **작성 기준일:** 2026-11-01  
> **감사 주관:** Technical Director & Legal Risk Lead  
> **검토 목적:** Steam 유료 출시 시 법률적 분쟁(상표권, 저작권, 라이선스 위반) 원천 차단

---

## 1. 원작 보드게임 관련 법적 리스크 분석 (Critical Finding)

본 프로젝트는 1992년 독일 Ravensburger 사에서 출판된 **Stefan Dorra**의 보드게임 *Razzia* (Art. No. 27 001 9)의 규칙을 기반으로 제작되었다.

### 1.1 게임 규칙(Game Mechanics)과 표현(Expression)의 법적 경계
- **미국 및 국제 저작권법 원칙 (Idea-Expression Dichotomy):**
  - 게임의 추상적인 규칙, 알고리즘, 수학적 메커니즘 자체는 저작권 보호 대상이 아니다. (규칙 자체는 특허가 없는 한 타인이 독자적인 코드로 구현할 수 있음).
  - 그러나 **게임의 명칭(Title), 룰북의 원문 텍스트, 카드 아트, 그래픽 디자인, 캐릭터 설정, 트레이드 드레스(Trade Dress)**는 저작권 및 상표권의 강력한 보호를 받는다.
- **본 프로젝트의 독립성 요소:**
  - 1920년대 시카고 금주법 시대 스피크이지(Speakeasy)라는 완전히 새로운 테마와 스토리텔링을 창작함.
  - 8종 고유 유물 모드, 암시장 경제, 7인의 신규 캐릭터 및 대화 시스템을 독자 구축함.
  - 룰북 텍스트는 원작 번역이 아닌 새로 작성된 독자적 설명 체계임.

### 1.2 게임명 "RAZZIA"의 상표권(Trademark) 및 상업적 리스크
1. **상표권 분쟁 위험:**
   - 'Razzia'는 일반 명사(경찰 급습)이기도 하지만, 보드게임/비디오게임 분류(Nice Class 9/28)에서 Ravensburger 또는 Stefan Dorra에 의해 상표 등록되어 있거나 오랜 상업적 사용을 통해 보호받고 있을 가능성이 높음.
   - 또한 Reiner Knizia의 유명 경매 게임 *Ra* 역시 마피아 테마 버전인 *Razzia!* (Amigo, 2004)로 출판된 바 있어, 시장 혼동(Confusion in the Marketplace)을 이유로 이의 제기(Opposition)나 침해 소송을 제기당할 위험이 큼.
2. **"Mobile" 접미사의 부정적 상업 효과:**
   - "Razzia Mobile"이라는 이름은 Steam PC/Deck 유저들에게 '모바일 단순 이식작(Shitty Mobile Port)'이라는 선입견을 주어 구매 전환율을 극도로 떨어뜨림.
3. **법률 감사 결론 및 권고:**
   - **출시 전 필수 리브랜딩 (P0):** 게임명에서 'Razzia'를 배제하거나 부제로 격하하고, 독자적인 1920s 시카고 테마의 브랜드로 교체해야 함.
   - **권장 신규 타이틀 후보군:**
     - *Speakeasy 1927: The Underground Bet* (스피크이지 1927)
     - *Underground Syndicate: Chicago 1927* (언더그라운드 신디케이트)
     - *Prohibition: Speakeasy Nights* (금주법: 비밀 주점의 밤)

---

## 2. 시각 에셋 라이선스 실사 (Visual Assets)

### 2.1 벡터 아이콘 (game-icons.net, CC BY 3.0)
- **사용 현황:** `assets/icons/` 내 25개 SVG 파일.
- **라이선스 요구사항:** 저작자 명시(Attribution) 필수.
- **이행 상태:** `CREDITS.md`에 Delapouite, Lorc, Andy Meneely, Skoll 등 작가별 출처 및 CC BY 3.0 라이선스가 정확하게 명시되어 있어 **라이선스 100% 준수 완료**.

### 2.2 캐릭터 및 바 일러스트 에셋
- **대상:** `assets/art/bars/` (6종), `assets/art/cards/` (26종), `assets/characters/` (7종), `assets/characters_full/` (7종).
- **Steam AI Content Disclosure 규정:**
  - Valve는 상점에 등록되는 게임이 이미지 생성 AI(Midjourney, Stable Diffusion 등)를 사용했는지 여부를 파트너 백엔드에서 의무적으로 체크하고 설명하도록 규정함.
  - 해당 에셋들이 생성형 AI를 활용하여 제작된 것이라면, Steamworks 등록 양식의 "AI Generated Content" 항목에 "사전 생성된 2D 배경 및 캐릭터 일러스트레이션(Pre-generated Art Assets)"으로 정직하게 체크하고, 훈련 데이터 침해 요소가 없음을 확인해야 함.

---

## 3. 서체(Fonts) 라이선스 실사

`assets/fonts/` 내 활성 폰트 6종에 대한 라이선스 점검:

| 폰트 파일 | 서체명 | 라이선스 형태 | 상업용 판매 가능 여부 | 고지 의무 준수 상태 |
|---|---|:---:|:---:|:---:|
| `StintUltraExpanded-Regular.ttf` | Stint Ultra Expanded | SIL OFL 1.1 | 가능 (무료) | `CREDITS.md` 명시 완료 |
| `PlayfairDisplay.ttf` | Playfair Display | SIL OFL 1.1 | 가능 (무료) | `OFL-PlayfairDisplay.txt` 동봉 완료 |
| `NotoSansKR.ttf` | Noto Sans KR | SIL OFL 1.1 | 가능 (무료) | `OFL-NotoSansKR.txt` 동봉 완료 |
| `SpecialElite.ttf` | Special Elite | Apache 2.0 | 가능 (무료) | `CREDITS.md` 명시 완료 |
| `Lora.ttf` | Lora | SIL OFL 1.1 | 가능 (무료) | `CREDITS.md` 명시 완료 |
| `Hahmlet-Subset.ttf` | Hahmlet | SIL OFL 1.1 | 가능 (무료) | `CREDITS.md` 명시 완료 |

모든 폰트가 상업적 소프트웨어 임베딩 및 재배포를 허용하는 오픈소스 라이선스(SIL OFL 또는 Apache 2.0)이며, 단독 유료 판매를 금지하는 조항을 준수하고 있다.

---

## 4. 오디오 에셋 라이선스 실사

### 4.1 BGM (Background Music)
- **출처:** `tools/make_music.py`를 통해 파이썬 mido로 멜로디/화성을 작곡하고, FluidSynth와 `FluidR3_GM.sf2` 사운드폰트를 사용하여 렌더링.
- **사운드폰트 라이선스:** `FluidR3_GM`은 MIT 라이선스를 따르며, 렌더링된 오디오 출력물에 대해 완전한 상업적 독점권이 보장됨. 저작권 문제 0%.

### 4.2 효과음 (SFX)
- **출처:** `tools/generate_sfx.py`를 통해 수학적 사인파, 노이즈, 지수 감쇠 엔벨로프를 결합하여 절차적으로 합성된 16-bit 44.1kHz WAV.
- 외부 샘플팩을 무단 사용하지 않았으므로 저작권 분쟁 가능성 전무.

---

## 5. 최종 법률 검토 체크리스트 및 출시 전 조치 사항

- [ ] **[P0] 상표권 회피:** 프로젝트 타이틀을 독자 브랜드(예: *The Speakeasy 1927*)로 변경 확정.
- [ ] **[P0] 원작 명시 완화:** `README.md` 및 상점 페이지에서 "1992 Dorra Razzia의 계승" 문구를 "1920년대 고전 심리 베팅 보드게임에서 영감을 받은 독자 창작작"으로 완곡하게 다듬어 법적 빌미 제거.
- [ ] **[P1] Steam AI 신고서 작성:** 상점 등록 시 2D 일러스트 생성 AI 활용 내역 사전 신고.
- [ ] **[P1] CREDITS 인게임 노출:** 인게임 도움말/설정에 `CREDITS.md` 텍스트를 열람할 수 있는 화면 제공.
