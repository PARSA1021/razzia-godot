# ⚙️ GAME SYSTEMS — 핵심 게임 시스템 명세서

> **상위 문서:** [`docs/README.md`](../README.md)  
> **관련 문서:** [`docs/game-design/GAME_RULES.md`](GAME_RULES.md), [`docs/technical/PROJECT_ARCHITECTURE.md`](../technical/PROJECT_ARCHITECTURE.md)

---

## 1. 결정론적 난수 엔진 (Deterministic Mulberry32 PRNG)

본 프로젝트의 모든 난수 생성은 자바스크립트 표준과 100% 비트 호환되는 **Mulberry32 32-bit PRNG**(`engine/rng.gd`)를 사용합니다.

```gdscript
# engine/rng.gd Mulberry32 32-bit 구현
static func next32(state: int) -> Dictionary:
    var s := (state + 0x6D2B79F5) & 0xFFFFFFFF
    var t := s
    t = _imul((t ^ (t >> 15)), (t | 1))
    t ^= t + _imul((t ^ (t >> 7)), (t | 61))
    var res := ((t ^ (t >> 14)) >> 0) & 0xFFFFFFFF
    return {"val": res, "state": s}
```

### 시스템적 의의:
1. **완벽한 버그 재현성:** 초기 시드(Seed) 값과 플레이어 입력 시퀀스만 저장하면, 100만 번의 게임 실행도 단 1비트의 오차 없이 동일하게 리플레이됩니다.
2. **골든 리플레이 검증:** 52개의 무작위 시드로 완주한 게임 결과(`tests/golden/`)를 검증하여 규칙 회귀를 방지합니다.

---

## 2. 엔진 불변식 검증 시스템 (Engine Invariants: INV-001 ~ INV-005)

엔진은 상태가 전이될 때마다 `verify_invariants(state)`를 호출하여 게임 데이터의 무결성을 실시간 감시합니다.

| 식별자 | 명칭 | 검증 내용 |
|---|---|---|
| **INV-001** | 카드 보존 법칙 | $\text{덱} + \text{버림패} + \sum \text{플레이어 손패} + \sum \text{제출 카드} = \text{초기 카드 총수}(54 \text{ or } 72)$ |
| **INV-002** | 통화량 보존 법칙 | $\text{머니 덱} + \sum \text{바 판돈} + \sum \text{플레이어 현금} + \text{추가 머니} + \text{암시장 금고} = \text{총 통화량}$ |
| **INV-003** | 손패 크기 불변식 | 라운드 시작 및 손패 보충 직후 모든 플레이어의 손패는 정확히 5장 |
| **INV-004** | 크루피에 순환 불변식 | 매 라운드 종료 시 크루피에는 정확히 시계방향으로 1칸 회전 |
| **INV-005** | 청구 자격 무결성 | 경찰 단속 발동 시 도박꾼은 어떠한 경우에도 판돈 청구자 명단에 포함되지 않음 |

---

## 3. 협상 및 AI 반응 알고리즘 (Negotiation Algorithm)

### 3.1 제안 계산 및 노이즈 고정 (Fixed Noise)
협상 시 제안 금액은 $5,000 단위로 조정됩니다.
- **역산 방지 노이즈 (Anti-Reverse-Engineering):** 플레이어가 슬라이더를 움직여가며 AI의 수락 임계값을 간보는 행위를 방지하기 위해, **협상 1회당 1개의 고정 노이즈($\epsilon \in [-0.05, +0.05]$)**를 시드 기반으로 추첨하여 고정합니다. 슬라이더를 아무리 왕복해도 기준선이 변하지 않습니다.

### 3.2 AI 성향별 수락 확률 공식
AI는 제안된 금액 비율($r = \text{제안금} / \text{총 판돈}$)과 자신이 결투를 신청했을 때 이길 확률($P_{\text{win}}$)을 비교하여 판단합니다:

$$\text{수락 기준치} = P_{\text{win}} \times (1.0 + \text{성향 계수}) + \epsilon$$

- **보수형 (CONSERVATIVE - Vito, Sal):** 결투 리스크를 극도로 기피하므로, 결투 승률보다 약간 낮은 제안금이라도 기꺼이 수락합니다.
- **공격형 (AGGRESSIVE - Mack, Dutch):** 자존심이 강하고 판돈 독식을 선호하여, 50% 이상의 공평한 분배가 아니면 가차없이 결투를 신청합니다.
- **기회주의형 (OPPORTUNIST - Lola, Rosie, Nico):** 현재 자신이 1위인지 꼴찌인지에 따라 가변적인 태도를 취합니다.

---

## 4. 컴팩트 결투 시스템 (Compact Duel View)

기존의 번거롭고 긴 결투 연출을 개선하여 테이블 중앙에서 즉시 해결되는 컴팩트 결투를 지원합니다:
1. **도전자(Challenger) / 방어자(Defender) 명확한 뱃지:** 리볼버 아이콘(도전자)과 다이얼 금고 아이콘(방어자)으로 역할 시각화.
2. **동점 승리자 강조:** 동점 발생 시 도전자가 승리함을 시각적으로 뚜렷하게 연출.
3. **스킵 및 배속 지원:** 터치 또는 스페이스바/패드 버튼으로 주사위 굴림 연출을 즉시 완료 가능.

---

## 5. 세이브 & 리줌 시스템 (Dual-Slot Save/Resume)

- **저장 위치:** `user://autosave.json`
- **체크포인트 저장:** 매 라운드 정산 완료 직후 자동으로 상태가 직렬화됩니다.
- **2개 슬롯 지원:**
  - 슬롯 1: 클래식 모드 진행 데이터
  - 슬롯 2: 유물 모드 진행 데이터
- **원자적 쓰기 (Atomic Write):** 임시 파일(`autosave.json.tmp`)에 먼저 쓰고 교체함으로써 비정상 종료 시 세이브 파일 손상을 원천 방지합니다.
