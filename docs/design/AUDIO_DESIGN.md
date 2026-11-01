# 🎷 AUDIO DESIGN — 오디오 디렉션 및 사운드 시스템 명세

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/assets/AUDIO_ASSET_LIST.md`](../assets/AUDIO_ASSET_LIST.md), [`docs/design/ART_DIRECTION.md`](ART_DIRECTION.md)

---

## 1. 사운드 철학: D단조 필름 누아르 재즈 (Noir Jazz Direction)

RAZZIA의 오디오 환경은 **1920년대 시카고 지하 주점의 농밀하고 연기 자욱한 공기**를 청각적으로 재현합니다.

- **조성 (Key):** 우울하면서도 긴장감을 놓지 않는 **D단조 (D minor)** 중심.
- **악기 구성:** 브러시 스네어(Brushed Snare), 워킹 콘트라베이스(Walking Upright Bass), 뮤트 트럼펫(Muted Trumpet), 스모키한 피아노 컴핑.
- **다이내믹스:** 평화로운 카드 선택 단계에서는 차분한 라운지 음악을 유지하다가, 협상 결렬 및 단속 순간 급격히 서스펜스를 고조시킵니다.

---

## 2. BGM 음악 트랙 구성

| 트랙 파일명 | 포맷 | 재생 상황 | 음악적 특징 및 연출 의도 |
|---|---|---|---|
| `menu_theme.ogg` | Ogg Vorbis | 메인 메뉴, 설정, 크레딧 | 느긋한 템포의 스모키 재즈 트리오. 매치 진입 전 몰입감 형성. |
| `noir_jazz_loop.ogg` | Ogg Vorbis | 일반 인게임 라운드 (Round 1 ~ 중반) | 중간 템포의 스윙 리듬. 생각에 방해되지 않는 차분한 BGM. |
| `tension_loop.ogg` | Ogg Vorbis | 협상 모달, 거액 판돈 대치 | 베이스 펄스와 서스펜스 심벌. 심리적 압박감 부여. |
| `final_round_loop.ogg` | Ogg Vorbis | 마지막 라운드 (Final Round) | 격렬한 브라스 섹션과 묵직한 팀파니. 마지막 승부의 장엄함. |

---

## 3. 효과음 (SFX) 시스템 및 절차적 합성 (`ui/audio.gd`)

효과음은 물리적 카지노의 손맛을 극대화하도록 정밀 조율되었습니다:

1. **카드 조작계:**
   - `taking_card.mp3`: 손패를 들어 올릴 때의 부드러운 종이 마찰음.
   - `card_snap.wav`: 테이블에 카드를 딱 놓을 때의 경쾌한 타격음.
   - `flip.ogg`: 동시 카드 공개 시 여러 장이 한 번에 뒤집히는 셔플 플립음.
2. **금전 및 칩 조작계:**
   - `chip_clink.wav`: 세라믹 칩이 부딪히는 맑은 소리.
   - `cash_big.ogg` / `cashier_ching.mp3`: 대규모 판돈 획득 시 앤틱 금고 벨소리.
3. **단속 및 결투계:**
   - `police_whistle.wav` / `police_siren.mp3`: 단속 발동 시 귀를 찌르는 호루라기와 사이렌.
   - `rolling_dice.mp3` / `dice_cup.wav`: 목제 컵에서 주사위가 굴러 테이블에 안착하는 소리.
   - `gavel.wav`: 판사 유물 및 협상 최종 체결 판결음.

---

## 4. 다이내믹 오디오 더킹 (Adaptive Ducking)

사운드가 서로 엉켜 소음이 되는 것을 방지하기 위해 `ui/audio.gd`는 실시간 볼륨 더킹을 수행합니다:
- 경찰 사이렌 또는 대규모 결투 SFX 재생 시, BGM 트랙의 볼륨을 즉시 -6dB 자동 감쇠(Duck)한 뒤 1.2초에 걸쳐 서서히 원복.
- 컷씬 대사 음성 노출 시 배경 앰비언스를 페이드 아웃.

---

## 5. 믹서 버스 및 사용자 볼륨 통제

게임 엔진의 오디오 버스는 3단 분리 구조를 갖습니다:
$$\text{Master Bus} \longrightarrow \begin{cases} \text{BGM Bus} & (0\% \sim 100\%) \\ \text{SFX Bus} & (0\% \sim 100\%) \end{cases}$$
사용자는 언제든 인게임 메뉴 또는 퀵 사운드 패널(`ui/sound_panel.gd`)을 통해 무단계로 볼륨을 조절할 수 있으며, 설정은 `user://settings.cfg`에 영구 저장됩니다.
