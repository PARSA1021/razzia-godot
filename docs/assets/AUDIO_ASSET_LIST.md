# 🎧 AUDIO ASSET LIST — 104종 오디오 에셋 레지스트리

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/design/AUDIO_DESIGN.md`](../design/AUDIO_DESIGN.md), [`docs/assets/ASSET_CATALOG.md`](ASSET_CATALOG.md)

---

## 1. 개요 및 오디오 에셋 통계

`assets/audio/` 디렉터리에는 52개의 오디오 바이너리 파일(.ogg, .wav, .mp3)과 52개의 Godot 리소스 임포트 메타데이터(.import)가 저장되어 있습니다 (총 104개 파일).

---

## 2. BGM 및 배경 앰비언스 루프 (Background Music & Ambience)

| 파일명 | 포맷 | 용량 | 재생 영역 | 음악적 특징 및 역할 |
|---|---|---:|---|---|
| `menu_theme.ogg` | OGG | 909 KB | 메인 메뉴, 설정, 크레딧 | 1920년대 스모키 재즈 피아노 & 브러시 스네어 라운지 BGM |
| `noir_jazz_loop.ogg` | OGG | 1.49 MB | 인게임 기본 라운드 (R1 ~ 중반) | 중간 템포 워킹 베이스와 뮤트 트럼펫 중심의 누아르 스윙 루프 |
| `tension_loop.ogg` | OGG | 397 KB | 협상 슬라이더, 긴장 대치 상황 | 무거운 저음 펄스와 서스펜스 심벌 중심의 긴장 루프 |
| `final_round_loop.ogg` | OGG | 1.11 MB | 마지막 라운드 (Final Round) | 거친 브라스 섹션과 팀파니가 가미된 클라이맥스 루프 |
| `ambience_loop.ogg` | OGG | 112 KB | 지하 주점 배경 환경음 | 잔 부딪히는 소리, 은은한 웅성거림의 스피크이지 앰비언스 |

---

## 3. 카드 및 테이블 조작 효과음 (Card Handling SFX)

| 파일명 | 포맷 | 용량 | 발동 타이밍 |
|---|---|---:|---|
| `taking_card.mp3` | MP3 | 16 KB | 손패에서 카드를 들어 올릴 때 (Lift) |
| `card_snap.wav` | WAV | 15 KB | 카드를 테이블 슬롯에 확정 제출할 때 (Confirm) |
| `flip.ogg` | OGG | 4.7 KB | 동시 공개 시 모든 카드가 뒤집힐 때 (Reveal) |
| `shuffle.ogg` | OGG | 10 KB | 라운드 시작 전 덱을 섞을 때 |
| `deal.ogg` | OGG | 7.1 KB | 라운드 종료 후 손패를 1장 보충할 때 |
| `pick.ogg` | OGG | 5.3 KB | 손패 카드 탭 선택 시 |

---

## 4. 판돈 및 칩 사운드 (Cash & Chip SFX)

| 파일명 | 포맷 | 용량 | 발동 타이밍 |
|---|---|---:|---|
| `chip_clink.wav` | WAV | 19 KB | 테이블 판돈 칩 배치 및 이동 시 |
| `cash_big.ogg` | OGG | 11 KB | $50,000 이상 대규모 판돈 획득 시 |
| `cashier_ching.mp3` | MP3 | 79 KB | 암시장 상점에서 유물 구매 완료 시 |
| `coin.ogg` ~ `coin4.ogg` | OGG | 각 ~6 KB | 일반 현금 획득 시 4단 변형 코인음 |
| `offer.ogg` | OGG | 6.2 KB | 협상 슬라이더 조정 시 금액 틱 효과 |

---

## 5. 결투 및 주사위 사운드 (Dice & Duel SFX)

| 파일명 | 포맷 | 용량 | 발동 타이밍 |
|---|---|---:|---|
| `dice_cup.wav` | WAV | 33 KB | 주사위 컵을 흔들 때 |
| `rolling_dice.mp3` | MP3 | 40 KB | 주사위가 테이블 위에서 구를 때 |
| `drumroll.ogg` | OGG | 17 KB | 결투 판정 직전 드럼롤 서스펜스 |
| `duel.ogg` | OGG | 5.8 KB | 결투 돌입 선언 시 |
| `duel_win.ogg` | OGG | 7.4 KB | 결투 승리 시 승리의 팡파르 |
| `duel_lose.ogg` | OGG | 6.2 KB | 결투 패배 시 처절한 타격음 |
| `tie.ogg` | OGG | 7.1 KB | 동점 발생 시 도전자 승리 선언 |

---

## 6. 경찰 단속 사운드 (Police Raid SFX)

| 파일명 | 포맷 | 용량 | 발동 타이밍 |
|---|---|---:|---|
| `police_whistle.wav` | WAV | 61 KB | 경찰 단속 발동 순간 호루라기 소리 |
| `police_siren.mp3` | MP3 | 173 KB | 경찰 단속 진행 중 사이렌 앰비언스 |

---

## 7. 유물, 징글 및 UI 시스템 사운드 (Relics, Jingles & UI)

| 파일명 | 포맷 | 용량 | 발동 타이밍 |
|---|---|---:|---|
| `relic_chime.wav` | WAV | 75 KB | 유물 특수 효과 인터셉트 발동 시 신비로운 차임벨 |
| `gavel.wav` | WAV | 30 KB | 매수한 판사 효과 및 공식 협상 타결 판결봉 |
| `achieve.ogg` | OGG | 11 KB | 13종 도전과제 달성 팝업 시 |
| `game_start.ogg` | OGG | 10 KB | 매치 개시 징글 |
| `game_end.ogg` | OGG | 16 KB | 최종 라운드 종료 및 승자 발표 시 |
| `win.ogg` | OGG | 18 KB | 플레이어 1위 최종 우승 팡파르 |
| `tutorial_bell.wav` | WAV | 66 KB | 튜토리얼 단계 완료 시 벨소리 |
| `click.mp3`, `hover.ogg` | MP3/OGG | 각 ~4 KB | 범용 버튼 클릭 및 마우스 호버 |
| `panel_open.ogg` / `close`| OGG | 각 ~6 KB | 모달 패널 열림/닫힘 |
| `toggle_on.ogg` / `off` | OGG | 각 ~4 KB | 환경설정 토글 스위치 조작 |
