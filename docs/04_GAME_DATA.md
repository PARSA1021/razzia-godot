# Razzia Mobile — Game Data Specification

## 1. Purpose

This document defines the data structures used by the game engine.

The UI must consume these structures rather than creating its own parallel game model.

---

# 2. Primitive Types

```ts
type PlayerId = string;
type CardId = string;
type BarId = string;

type CardType =
  | "ZOCKER"
  | "RAZZIA";
```

---

# 3. Bar

```ts
interface Bar {
  id: BarId;
  name: string;
  order: number;
  active: boolean;
  money: number;
}
```

Recommended IDs:

```text
COLIBRI
COTTON_CLUB
HAVANA_BAR
THE_JUNGLE
LINCOLNS
JAZZ_HOUSE
```

For 3-player games:

```text
LINCOLNS.active = false
JAZZ_HOUSE.active = false
```

---

# 4. Card

```ts
interface Card {
  id: CardId;
  type: CardType;
  barId: BarId;
  dieSymbol: 1 | 2 | 3 | 4 | 5 | 6;
}
```

A card must never have:

- an invalid bar;
- an invalid type;
- a die symbol outside 1–6.

---

# 5. Money Card

The physical game uses money cards.

The digital implementation can represent them as values:

```ts
type MoneyValue =
  | 5000
  | 10000
  | 15000
  | 20000
  | 25000
  | 30000
  | 40000
  | 50000;
```

```ts
interface MoneyCard {
  id: string;
  value: MoneyValue;
}
```

For a digital implementation, individual money-card IDs are useful for debugging and replay.

---

# 6. Original Money Distribution

```ts
const ORIGINAL_MONEY_COUNTS = {
  5000: 15,
  10000: 15,
  15000: 12,
  20000: 12,
  25000: 9,
  30000: 9,
  40000: 6,
  50000: 6
};
```

Total:

```text
84 cards
```

---

# 7. Player

```ts
interface Player {
  id: PlayerId;
  name: string;
  isHuman: boolean;
  seatIndex: number;

  money: number;

  hand: CardId[];

  selectedCardId?: CardId;

  aiDifficulty?: "EASY" | "NORMAL" | "HARD";
}
```

Do not store another player's hidden card selection in a UI-accessible structure before reveal in multiplayer.

For single-player AI, the engine may know AI selections internally.

---

# 8. Game Phase

```ts
type GamePhase =
  | "GAME_INIT"
  | "SETUP"
  | "ROUND_START"
  | "DEAL_TO_FIVE"
  | "MONEY_DISTRIBUTION"
  | "CARD_SELECTION"
  | "WAIT_FOR_SELECTIONS"
  | "REVEAL"
  | "GROUP_BY_BAR"
  | "BAR_RESOLUTION"
  | "SIMPLE_RESOLUTION"
  | "NEGOTIATION"
  | "PROPOSAL"
  | "PROPOSAL_RESPONSE"
  | "DUEL_SETUP"
  | "DUEL_ROLL"
  | "DUEL_RESOLVE"
  | "AWARD_MONEY"
  | "ROUND_CLEANUP"
  | "GAME_END_CHECK"
  | "FINAL_SCORE"
  | "GAME_OVER";
```

---

# 9. Game State

```ts
interface GameState {
  version: number;

  phase: GamePhase;

  round: number;

  playerCount: number;

  players: Player[];

  bars: Bar[];

  drawPile: CardId[];

  discardPile: CardId[];

  moneyDeck: MoneyCard[];

  croupierId: PlayerId;

  currentBarIndex?: number;

  currentBarId?: BarId;

  activeNegotiation?: NegotiationState;

  activeDuel?: DuelState;

  finalRound: boolean;

  winnerId?: PlayerId;
}
```

---

# 10. Negotiation State

```ts
interface NegotiationState {
  id: string;

  barId: BarId;

  claimantIds: PlayerId[];

  proposerId: PlayerId;

  prize: number;

  proposal: Record<PlayerId, number>;

  responses: Record<
    PlayerId,
    "PENDING" | "ACCEPT" | "DUEL"
  >;
}
```

---

# 11. Duel State

```ts
interface DuelState {
  id: string;

  barId: BarId;

  playerA: PlayerId;
  playerB: PlayerId;

  cardA: CardId;
  cardB: CardId;

  rollA?: number;
  rollB?: number;

  scoreA?: number;
  scoreB?: number;

  challengerId: PlayerId;

  winnerId?: PlayerId;
}
```

---

# 12. Played Card

Use a separate object for revealed cards.

```ts
interface PlayedCard {
  cardId: CardId;
  playerId: PlayerId;
  barId: BarId;
  type: CardType;
  dieSymbol: number;
}
```

This avoids mutating the original card definition.

---

# 13. Game Setup Configuration

```ts
interface GameConfig {
  playerCount: number;

  humanPlayerId: PlayerId;

  aiDifficulty: "EASY" | "NORMAL" | "HARD";

  seed?: number;

  enableAnimations: boolean;

  animationSpeed:
    | "SLOW"
    | "NORMAL"
    | "FAST";
}
```

---

# 14. Game Invariants

These should be tested continuously.

### INV-001 — Card uniqueness

A card exists in exactly one location:

- a player's hand;
- draw pile;
- discard pile;
- current played cards.

Never two locations simultaneously.

### INV-002 — Money conservation

```text
money deck
+ money on bars
+ player money
=
total money available in the configured game
```

### INV-003 — Hand size

After `DEAL_TO_FIVE`:

```text
player.hand.length === 5
```

### INV-004 — One selection

During `CARD_SELECTION`:

```text
selectedCardId
```

must reference exactly one card in the player's hand.

### INV-005 — Bar ownership

Every card's `barId` must reference a valid active bar.

---

# 15. Card Factory

The project should use a single card factory:

```ts
createOriginalCardSet(): Card[]
```

Do not manually create card arrays inside UI components.

---

# 16. Setup Factories

```ts
createSetupFor3Players()
createSetupFor4To6Players()
createSetupFor7To8Players()
```

These functions should return:

```ts
{
  bars,
  cardDeck,
  moneyDeck
}
```

The 4–6 player setup removes 18 specified cards; the 3-player setup removes the two inactive bars and their cards plus the specified money cards; the 7–8 setup uses all game cards.

---

# 17. Money Transfer API

Use a central service:

```ts
awardMoney(
  playerId: PlayerId,
  amount: number,
  sourceBarId: BarId
)
```

The function must:

1. validate amount;
2. validate source bar balance;
3. decrease bar money;
4. increase player money;
5. emit an event.

Do not directly mutate:

```ts
bar.money += ...
player.money += ...
```

from UI code.

---

# 18. Randomness

Use an injectable RNG:

```ts
interface RNG {
  nextInt(min: number, max: number): number;
}
```

The engine should not call platform-specific random functions directly.

This allows:

- deterministic tests;
- replay;
- bug reproduction;
- AI simulation.

