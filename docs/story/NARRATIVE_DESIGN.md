# 📜 NARRATIVE DESIGN — 내러티브 연출 및 대사 시스템

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/story/STORY_OVERVIEW.md`](STORY_OVERVIEW.md), [`docs/story/CHARACTERS.md`](CHARACTERS.md), [`docs/technical/PROJECT_ARCHITECTURE.md`](../technical/PROJECT_ARCHITECTURE.md)

---

## 1. 내러티브 연출 철학

RAZZIA는 텍스트가 과도하게 플레이의 흐름을 끊는 것을 지양합니다.  
보드게임 본연의 빠른 템포와 긴장감을 유지하면서도, **결정적인 순간(카드 공개, 협상 결렬, 단속 발동, 결투 승패)에 캐릭터의 성격이 살아 숨 쉬는 숏폼(Short-form) 누아르 대사**를 노출하여 몰입감을 극대화합니다.

---

## 2. 대화 및 컷씬 시스템 구조 (`ui/dialogue_scene.gd`)

### 2.1 연출 파이프라인
1. **트리거 수신:** 게임 컨트롤러(`controller/match_controller.gd`)에서 내러티브 이벤트(예: `RAID_TRIGGERED`, `DUEL_RESOLVED`) 발생.
2. **이벤트 인터셉트:** 활성화된 대화 큐(`dialogue_scene.gd`)에서 상황에 맞는 화자(Speaker)와 대사 풀을 추출.
3. **시각 연출:**
   - 배경 펠트 테이블의 어두운 비네팅(Dark Vignette) 처리.
   - 캐릭터 전신 일러스트(`assets/characters_full/`)가 좌측 또는 우측에서 슬라이드 인.
   - 타자기 효과(Typewriter Effect, 글자당 0.03초)로 대사 출력.
   - 아르데코 대화창 테두리 골드 발광.
4. **빠른 진행 지원:** 화면 터치, 스페이스바, 게임패드 A 버튼 입력 시 즉시 텍스트 전체 출력 및 0.4초 내 퇴장(Dismiss).

---

## 3. 상황별 바크(Voice Bark) 트리거 매트릭스

| 상황 ID | 발동 조건 | 대사 테마 및 연출 목적 |
|---|---|---|
| `BARK_SOLE_CLAIM` | 혼자서 바 판돈을 독점 정산할 때 | 우쭐함, 실속을 챙긴 만족감, 상대방을 비웃는 대사 |
| `BARK_RAID_SURPRISE` | 도박꾼이 모인 바에 경찰이 들이닥쳤을 때 | 도박꾼의 당혹감, 분노 / 경찰의 의기양양한 체포 선언 |
| `BARK_RAID_FAIL` | 도박꾼이 없는 빈 바에 경찰만 출현했을 때 | 허탕을 친 경찰의 민망함, 헛걸음한 분노 |
| `BARK_NEGO_OFFER` | 제안자가 협상금을 제시할 때 | 협박, 회유, 젠틀한 타협안 권유 |
| `BARK_NEGO_REJECT` | 상대방이 제안을 걷어차고 결투를 신청할 때 | 모욕감, 분노, 건곤일척의 선전포고 |
| `BARK_DUEL_WIN` | 결투에서 승리하여 판돈을 독식했을 때 | 승리의 환희, 상대방을 조롱하는 마무리 멘트 |
| `BARK_DUEL_LOSE` | 결투에서 패배하여 빈손으로 물러날 때 | 패배의 억울함, 다음 라운드 복수 다짐 |
| `BARK_FINAL_ROUND` | 머니 덱이 고갈되어 마지막 라운드가 선언될 때 | 비장미, 마지막 한 방을 노리는 승부사들의 긴장감 |

---

## 4. 다국어 및 현지화 연출 규칙

- 모든 대사는 한국어 원문과 영어 번역본이 1:1로 매핑됩니다.
- 한국어 대사는 1920년대 번안 소설 및 필름 누아르 특유의 건조하고 비정한 어투(~다, ~지, ~군)를 유지합니다.
- 영어 대사는 1920s 시카고 슬랭(*bootlegger, copper, chump, dough, flatfoot*)을 적극 활용하여 시대적 분위기를 살립니다.
- 폰트 렌더링 시 한국어는 `Hahmlet-Subset.ttf`, 영어는 `Lora.ttf`로 동적 폴백되어 글자 깨짐이 원천 방지됩니다.
