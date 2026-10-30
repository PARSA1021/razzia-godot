# Razzia Mobile — Game Flow & State Machine

## 1. Purpose

This document converts the rules into implementable game states.

The game engine should be implemented as a state machine rather than a collection of UI callbacks.

---

# 2. High-Level Flow

```text
BOOT
  ↓
SETUP
  ↓
ROUND_START
  ↓
DEAL_TO_FIVE
  ↓
MONEY_DISTRIBUTION
  ↓
CARD_SELECTION
  ↓
REVEAL
  ↓
BAR_RESOLUTION
  ├── SIMPLE_RESOLUTION
  └── NEGOTIATION
          ├── ACCEPT
          └── DUEL
  ↓
ROUND_CLEANUP
  ↓
GAME_END_CHECK
  ├── NO → NEXT_CROUPIER → ROUND_START
  └── YES → FINAL_SCORE
```

---

# 3. State IDs

| State | Purpose |
|---|---|
| `GAME_INIT` | Create a new game |
| `SETUP` | Prepare cards, money and players |
| `ROUND_START` | Start a round |
| `DEAL_TO_FIVE` | Restore every hand to five cards |
| `MONEY_DISTRIBUTION` | Croupier distributes money |
| `CARD_SELECTION` | Players secretly choose cards |
| `WAIT_FOR_SELECTIONS` | Wait until all players have selected |
| `REVEAL` | Reveal selected cards |
| `GROUP_BY_BAR` | Group cards by bar |
| `BAR_RESOLUTION` | Resolve bars one at a time |
| `SIMPLE_RESOLUTION` | Resolve uncontested bars |
| `NEGOTIATION` | Handle contested bar |
| `PROPOSAL` | Highest-priority claimant proposes |
| `PROPOSAL_RESPONSE` | Other claimants accept/reject |
| `DUEL_SETUP` | Prepare a duel |
| `DUEL_ROLL` | Roll dice |
| `DUEL_RESOLVE` | Compare scores |
| `AWARD_MONEY` | Transfer money |
| `ROUND_CLEANUP` | Discard played cards |
| `GAME_END_CHECK` | Check whether final round has ended |
| `FINAL_SCORE` | Calculate totals |
| `GAME_OVER` | Display winner |

---

# 4. State Contract

Every state must define:

```ts
interface GameStateDefinition {
  id: string;
  enter(state: GameState): GameState;
  canExit(state: GameState): boolean;
  getNextState(state: GameState): GamePhase;
}
```

Do not allow arbitrary UI components to mutate phases.

---

# 5. GAME_INIT

## Entry

The player selects:

- player count;
- human player position;
- AI difficulty;
- optional game settings.

## Action

Create a fresh game state.

## Exit

Configuration is valid.

## Next

`SETUP`

---

# 6. SETUP

## Action

Based on player count:

- configure bars;
- configure card deck;
- configure money deck;
- configure player order;
- select first Croupier;
- deal five cards to every player;
- initialize all bar money to zero.

## Next

`ROUND_START`

---

# 7. ROUND_START

## Action

- determine current Croupier;
- reset per-round temporary state;
- determine whether cards must be recycled;
- prepare round metadata.

## Next

`DEAL_TO_FIVE`

---

# 8. DEAL_TO_FIVE

For each player:

```ts
while (player.hand.length < 5) {
  player.hand.push(drawCard());
}
```

If the draw deck is empty, recycle the discard pile according to RULE-027.

## Next

`MONEY_DISTRIBUTION`

---

# 9. MONEY_DISTRIBUTION

For 4–8 players:

- draw seven money cards;
- distribute six left-to-right across the six bars;
- place the seventh on the Croupier-selected bar.

For 3 players:

- draw five money cards;
- distribute four across the available four bars;
- place the fifth on a selected bar.

## Important

Do not reset existing bar money.

## Next

`CARD_SELECTION`

---

# 10. CARD_SELECTION

Each player chooses exactly one card.

For a human:

- highlight selectable cards;
- allow exactly one selection;
- hide selection from other players.

For AI:

- call `AIController.chooseCard()`.

## Exit condition

All players have a selected card.

## Next

`REVEAL`

---

# 11. REVEAL

Reveal all selected cards simultaneously.

The engine creates:

```ts
playedCards: PlayedCard[]
```

Then:

## Next

`GROUP_BY_BAR`

---

# 12. GROUP_BY_BAR

Group played cards:

```ts
Map<BarId, PlayedCard[]>
```

Each card belongs to exactly one bar.

Empty bars require no resolution.

## Next

`BAR_RESOLUTION`

---

# 13. BAR_RESOLUTION

Process each active bar exactly once.

Recommended deterministic order:

```text
BAR_1 → BAR_2 → BAR_3 → BAR_4 → BAR_5 → BAR_6
```

For 3 players, only the four active bars exist.

For each bar:

```text
if no cards:
    continue

if no Zocker and one or more Razzia:
    money stays
    continue

if exactly one Zocker and no Razzia:
    award all money to Zocker
    continue

if one or more Razzia and one or more Zocker:
    eligible claimants = Razzia players
    resolve negotiation
    continue

if two or more Zocker and no Razzia:
    eligible claimants = Zocker players
    resolve negotiation
```

If a state cannot be resolved by the documented rules, stop in development mode.

---

# 14. NEGOTIATION

Input:

```ts
claimants: PlayerId[]
barMoney: number
cards: PlayedCard[]
```

Determine the proposer.

```ts
proposer = highestDieSymbolClaimant()
```

Tie-breaking uses seat order relative to the Croupier.

## Two claimants

Go to `PROPOSAL`.

## Three claimants

Go to `PROPOSAL`.

## Four or more

Do not invent a rule.

Raise:

```text
UnsupportedRuleError("Four-or-more claimant negotiation is not verified")
```

until the rule is explicitly documented.

---

# 15. PROPOSAL

The proposer creates an allocation.

Example:

```ts
{
  proposer: "P1",
  allocations: {
    P1: 35000,
    P2: 20000
  }
}
```

Validation:

- no negative values;
- total allocation cannot exceed the available prize;
- proposal must be payable under RULE-019.

## Next

`PROPOSAL_RESPONSE`

---

# 16. PROPOSAL_RESPONSE — TWO CLAIMANTS

The other claimant chooses:

- `ACCEPT`
- `DUEL`

If `ACCEPT`:

```text
AWARD_MONEY
```

If `DUEL`:

```text
DUEL_SETUP
```

---

# 17. PROPOSAL_RESPONSE — THREE CLAIMANTS

Each non-proposer independently chooses:

- `ACCEPT`
- `DUEL`

### Both accept

Award according to proposal.

### Exactly one rejects

1. Pay the accepting player's proposed amount.
2. The rejecting player and proposer duel.
3. Duel winner receives the remaining money.

### Both reject

Run two duels:

1. Highest-symbol claimant vs lowest-symbol claimant.
2. Winner vs remaining claimant.
3. Winner of second duel receives the full prize.

---

# 18. DUEL_SETUP

Store:

```ts
interface DuelState {
  barId: string;
  prize: number;
  playerA: PlayerId;
  playerB: PlayerId;
  cardA: CardId;
  cardB: CardId;
  dieRollA?: number;
  dieRollB?: number;
}
```

The duel uses the card each player played for that bar.

## Next

`DUEL_ROLL`

---

# 19. DUEL_ROLL

Each player rolls exactly once.

```ts
scoreA = cardA.dieSymbol + rollA
scoreB = cardB.dieSymbol + rollB
```

The physical game uses one die rolled once by each player.

In the digital version, the engine may generate the two results from the same RNG source, but each must be a separate 1–6 roll.

## Next

`DUEL_RESOLVE`

---

# 20. DUEL_RESOLVE

If:

```text
scoreA > scoreB
```

A wins.

If:

```text
scoreB > scoreA
```

B wins.

If:

```text
scoreA == scoreB
```

the player who called the duel wins.

## Next

`AWARD_MONEY`

---

# 21. AWARD_MONEY

Transfer the specified amount.

Never create money.

Never destroy money except by a documented setup exclusion.

Invariant:

```text
totalMoneyInGame =
moneyInDeck
+ moneyOnBars
+ moneyHeldByPlayers
```

The invariant should remain true during normal gameplay.

---

# 22. ROUND_CLEANUP

1. Move all played cards to discard.
2. Clear selected-card state.
3. Clear temporary negotiation state.
4. Clear temporary duel state.
5. Determine next Croupier.

## Next

`GAME_END_CHECK`

---

# 23. GAME_END_CHECK

The game uses the money deck to determine the final round.

If the current round is the final round:

```text
FINAL_SCORE
```

Otherwise:

```text
ROUND_START
```

The engine must track whether the current round is the final round rather than guessing from UI.

---

# 24. FINAL_SCORE

For every player:

```ts
total = player.money.reduce((sum, value) => sum + value, 0)
```

Highest total wins.

Store:

```ts
winnerId
finalScores
```

## Next

`GAME_OVER`

---

# 25. Save/Resume

A saved game must include enough state to resume from any safe checkpoint.

At minimum:

- phase;
- round;
- Croupier;
- player order;
- player hands;
- player money;
- bars and money;
- draw deck;
- discard pile;
- RNG seed/state if deterministic replay is supported;
- active negotiation;
- active duel.

Do not save UI-only animation state as game truth.

---

# 26. Event Log

For debugging, record events such as:

```text
GAME_STARTED
ROUND_STARTED
MONEY_PLACED
CARD_SELECTED
CARDS_REVEALED
BAR_RESOLVED
PROPOSAL_MADE
PROPOSAL_ACCEPTED
DUEL_STARTED
DICE_ROLLED
DUEL_RESOLVED
MONEY_AWARDED
ROUND_ENDED
GAME_ENDED
```

This will make AI/vibe-coding debugging much easier.

