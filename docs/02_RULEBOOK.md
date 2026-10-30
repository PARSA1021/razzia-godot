# Razzia Mobile — Rulebook

> This is the project's gameplay source of truth.
>
> Reference basis: 1992 Ravensburger Razzia rulebook, article no. 27 001 9, by Stefan H. Dorra. The original rulebook contains 6 bar cards, 48 Zocker cards, 24 Razzia cards, 84 money cards and one die.

## 0. Rule Authority

Rule IDs in this file are authoritative for implementation.

If an implementation conflicts with this file, the implementation is wrong unless this file is intentionally changed first.

---

# 1. RULE-001 — Objective

At the end of the game, each player totals their money.

The player with the highest total money wins.

---

# 2. RULE-002 — Player Count

The original game supports 3–8 players.

The setup differs for:

- 3 players
- 4–6 players
- 7–8 players

The MVP may initially implement 3–6 players, but the engine should not hard-code a maximum of 6.

---

# 3. RULE-003 — Components

Original components:

- 6 Bar cards
- 48 Zocker cards
- 24 Razzia cards
- 84 money cards
- 1 six-sided die

Money denominations:

| Value | Quantity |
|---:|---:|
| $5,000 | 15 |
| $10,000 | 15 |
| $15,000 | 12 |
| $20,000 | 12 |
| $25,000 | 9 |
| $30,000 | 9 |
| $40,000 | 6 |
| $50,000 | 6 |

Total money cards: 84.

---

# 4. RULE-004 — Six Bars

The original game has six bars:

1. Colibri
2. Cotton Club
3. Havana Bar
4. The Jungle
5. Lincoln's
6. Jazz House

Each bar has a border color.

Cards use the same border-color system to indicate which bar they belong to.

A card may only resolve against its matching bar.

---

# 5. RULE-005 — Card Types

There are two card types:

- `ZOCKER`
- `RAZZIA`

Both card types belong to one bar and contain a die symbol from 1–6.

Data model:

```text
Card
├── id
├── type = ZOCKER | RAZZIA
├── barId
└── dieSymbol = 1..6
```

---

# 6. RULE-006 — Hand Size

At the start of a normal round, each player has five cards.

After a round resolves, the next Croupier deals one new card to each player so that each player again has five cards.

If the face-down card deck runs out, shuffle the face-up discarded cards and create a new face-down deck.

---

# 7. RULE-007 — Croupier

The Croupier is the player responsible for opening the round.

For the first round, the original rules designate the player who considers themselves the "coolest gambler" as the first Croupier.

After each round, the next player becomes Croupier.

The Croupier determines the money placement for the round.

---

# 8. RULE-008 — Normal Money Distribution

For 4–8 player games:

1. The Croupier takes 7 money cards.
2. Six cards are placed face-up, one on each bar from left to right.
3. The seventh card is placed face-up on any bar chosen by the Croupier.
4. Existing unclaimed money remains on the bars.

Therefore a bar may receive multiple money cards in a round.

For 3 players, see RULE-030.

---

# 9. RULE-009 — Hidden Card Selection

Each player secretly selects exactly one card from their five-card hand.

The selected card is placed face-down.

Players must not know the selected cards of other players before the reveal.

In the digital version, the engine must not expose another player's hidden selection to the human player before reveal.

---

# 10. RULE-010 — Simultaneous Reveal

After all players have selected a card:

1. All selected cards are revealed.
2. Cards are grouped by their matching bar.
3. Each bar is resolved independently.

---

# 11. RULE-011 — Single Zocker

If exactly one Zocker card is played for a bar, that player receives all money currently on that bar.

The bar's money becomes zero.

---

# 12. RULE-012 — Multiple Zockers

If two or more Zocker cards are played for the same bar and no Razzia card is present:

1. The Zocker with the highest die symbol becomes the proposer.
2. The proposer creates a distribution proposal for the money on that bar.
3. Other involved Zocker players respond.
4. Accepted portions are paid.
5. If a player rejects the proposal, the applicable duel procedure is used.

The proposer may allocate money to themselves.

---

# 13. RULE-013 — Razzia Activation

A Razzia card represents a police raid.

If a bar contains at least one Razzia card and at least one Zocker card:

- the Zocker players receive no money from that bar;
- the Razzia players become the claimants for that bar's money;
- the Razzia players negotiate the distribution of that bar's money.

The Zocker cards have no further role in that bar's negotiation.

---

# 14. RULE-014 — Razzia Without Zocker

If one or more Razzia cards are played for a bar but no Zocker card is played there:

- the raid does not confiscate the money;
- no claimant receives the money;
- the money remains on the bar for future rounds.

This is a critical edge case.

---

# 15. RULE-015 — Multiple Razzia Cards

If a bar has Razzia cards and at least one Zocker card:

- only the Razzia players participate in the money distribution;
- the Zocker players receive nothing from that bar;
- the Razzia player with the highest die symbol has the right to make the first distribution proposal.

---

# 16. RULE-016 — Die Symbols

Each played card has a die symbol from 1 to 6.

A higher die symbol means higher priority when determining who makes the distribution proposal.

The die symbol is also added to the physical die result during a duel.

Formula:

```text
duelScore = card.dieSymbol + rolledDie
```

---

# 17. RULE-017 — Two-Player Negotiation

When exactly two eligible claimants compete for a bar:

1. The player with the higher die symbol makes a distribution proposal.
2. The proposal allocates the bar's money between the two players.
3. The other player may accept.
4. If accepted, the money is distributed as proposed.
5. If rejected, the rejecting player may call for a duel.
6. A duel is then resolved using RULE-018.

---

# 18. RULE-018 — Duel

Each dueling player rolls the six-sided die once.

Each player's duel score is:

```text
card.dieSymbol + dieRoll
```

The player with the higher total wins the duel.

The duel winner receives all money from the contested bar.

If the totals are tied, the player who called the duel wins.

---

# 19. RULE-019 — Proposal Payment Limit

A proposer may only offer amounts they can actually pay from the contested bar's money plus, if necessary, money they have already won.

The proposer may use their already-won money to make the proposed payment.

Players may not exchange money directly with one another as a separate transaction.

The proposal is about the contested bar's prize and must be implementable by the proposer.

---

# 20. RULE-020 — Three-Player Negotiation

When three eligible claimants compete for the same bar:

1. The player with the highest die symbol makes the distribution proposal.
2. Each of the other two players independently accepts or rejects.

### If both accept

All three receive the proposed amounts.

### If exactly one rejects

- The accepting player receives their offered amount.
- The two players who remain in dispute duel.
- The duel winner receives the remaining money from the contested bar.

### If both reject

Two duels occur:

1. The players with the highest and lowest die symbols duel.
2. The winner of that duel then duels the remaining third player.
3. The winner of the second duel receives the entire contested-bar prize.

---

# 21. RULE-021 — Four or More Claimants

When four or more eligible claimants compete for the same bar:

1. The player with the highest die symbol makes the distribution proposal.
2. Each of the other players independently accepts or rejects.

### If all accept

All players receive their proposed amounts.

### If one or more reject

- All accepting players receive their offered amounts.
- The proposer and all rejecting players participate in a sequential duel tournament for the remaining money on the contested bar.
- The participants are ordered by their priority (highest die symbol first).
- The tournament begins with the highest priority participant (the proposer).
- In reverse priority order (starting with the lowest priority participant), each challenger duels the current winner.
- The final winner of the tournament receives the entire remaining contested-bar prize.

---

# 22. RULE-022 — Tie for Proposal Priority

If two players have the same die symbol and are negotiating:

- the player sitting farther from the current Croupier starts the distribution proposal.

This is a physical-table rule and must be represented digitally using a deterministic seat order.

---

# 23. RULE-023 — Three-Player Tie Exception

If three players negotiate, two of whom have equal die symbols, and the proposer is not accepted:

- the player farther from the Croupier is treated as the later duelist according to the original special-case rule.

The engine must preserve the relative seat order from the Croupier.

---

# 24. RULE-024 — Seat Order

The game must maintain a circular player order.

Example:

```text
Croupier = Player 2

Player order:
P2 -> P3 -> P4 -> P1 -> P2
```

"Farther from the Croupier" must be resolved deterministically from this order.

Do not use random tie-breaking.

---

# 25. RULE-025 — Unclaimed Money

Money that is not awarded during a round remains on its current bar.

It is not returned to the money deck.

It can accumulate with money placed in later rounds.

---

# 26. RULE-026 — Card Discard

After a round is completely resolved:

- all played Zocker cards are placed face-up in the discard pile;
- all played Razzia cards are placed face-up in the discard pile.

The next round then begins.

---

# 27. RULE-027 — Card Recycle

If the face-down card deck runs out:

1. Take the face-up discard pile.
2. Shuffle it.
3. Create a new face-down draw deck.
4. Continue dealing.

Do not recycle cards that are currently in players' hands.

---

# 28. RULE-028 — Game End

The last round begins when the last seven money cards, or fewer, can be distributed from the money deck.

The final round is played completely.

After the final round:

1. Each player totals all money.
2. Highest total wins.

---

# 29. RULE-029 — 4–6 Player Setup

For 4–6 players:

1. Place all six bars.
2. Remove from the game:
   - every Razzia card with die symbol 5;
   - one Zocker card with die symbol 3 of each border color;
   - one Zocker card with die symbol 4 of each border color.
3. This removes 18 cards total.
4. Shuffle the remaining cards.
5. Deal five cards to each player.
6. Put the remaining cards face-down as the draw deck.
7. Shuffle the money cards and create three face-down money stacks.
8. Prepare the die.

---

# 30. RULE-030 — 3-Player Setup

For 3 players:

1. Remove the Lincoln's and Jazz House bar cards.
2. Remove all Lincoln's cards.
3. Remove all Jazz House cards.
4. Remove money cards:
   - 2 × $5,000
   - 2 × $10,000
   - 2 × $15,000
   - 2 × $20,000
   - 1 × $25,000
   - 1 × $30,000
   - 1 × $40,000
   - 1 × $50,000
5. In a round, the Croupier takes 5 money cards.
6. Four are placed on the remaining bars from left to right.
7. The fifth is placed on a bar chosen by the Croupier.
8. Otherwise use the normal rules.

---

# 31. RULE-031 — 7–8 Player Setup

For 7–8 players:

- use all game cards;
- otherwise use the normal rules.

---

# 32. RULE-032 — Player Hand After Round

After a round's resolution, the next Croupier gives each player one card so each player again has five cards.

This happens before the next round's money distribution.

---

# 33. RULE-033 — Money Does Not Reset Between Rounds

At the end of a round:

- claimed money leaves the bar;
- unclaimed money stays on the bar.

The next Croupier adds new money to the existing bar totals.

---

# 34. RULE-034 — No Hidden Rule Logic in UI

The UI must never independently determine game outcomes.

The game engine decides:

- who receives money,
- whether Razzia activates,
- who proposes,
- whether a duel is triggered,
- who wins a duel,
- whether the game ends.

The UI only displays the engine result and collects player input.

---

# 35. RULE-035 — Rule Verification Policy

If a future implementation requirement cannot be resolved from this document:

1. do not guess;
2. mark the rule as unresolved;
3. request verification from the source rulebook;
4. add/update a RULE-ID;
5. then implement.

---

# 36. RULE-036 — Relic Mode / Black Market (Roguelike Variant)

Relic Mode is an optional roguelike variant layered on top of the canonical Razzia rules.
Classic Mode remains 100% faithful to RULE-001..035 without any relics or shop phases.

## 36.1 Setup and Starter Draft
1. Upon starting a new match in Relic Mode, if the human player has no relics, a Starter Relic Draft modal opens offering 3 distinct starter relics:
   - `lucky_coin` (Duel archetype): +1 to final duel score total.
   - `protection_racket` (Economy archetype): +$5,000 bonus whenever claiming a venue alone.
   - `informant` (Info archetype): Reveals 1 AI destination bar before card selection.
2. The player selects 1 starter relic for free ($0) before Round 1 begins.

## 36.2 Inter-Round Black Market Shop
1. At the conclusion of each round (after bar resolution and before the next round's money distribution), the Black Market panel opens.
2. The shop displays up to 4 available relics dynamically sampled from the unowned catalog.
3. Each relic card displays its title, rarity, category, price, and exact gameplay effect.
4. If the player possesses sufficient cash, they may click [구매] to purchase a relic. The purchase cost is deducted from the player's balance and transferred to the Black Market Vault (`blackMarketVault`).
5. The player may spend $5,000 to reroll the shop offerings (`[🔄 물건 새로고침 ($5,000)]`). The reroll fee is transferred to the Black Market Vault.
6. The player may leave the shop at any time by pressing [거래 완료 및 다음 라운드 진행].

## 36.3 Money Conservation Invariant (INV-002)
1. Money spent in the Black Market (purchases and rerolls) is stored in `s["blackMarketVault"]`.
2. When economic relics mint bonuses (e.g. `protection_racket` +$5k, `swiss_account` 10% interest, `syndicate_crest` +$3k dividend), `s["totalMoney"]` is increased by the exact same amount.
3. Therefore, `INV-002` (`total = moneyDeck + bars + players + extraMoneyCard + blackMarketVault == totalMoney`) remains strictly valid across all phases.

## 36.4 Active Relics & Resolution Timings
1. **Lucky Coin (`lucky_coin`):**
   - Timing: Duel resolution (`_run_duel`).
   - Effect: Adds +1 to final duel score total.
2. **Protection Racket (`protection_racket`):**
   - Timing: Venue resolution (`_resolve_bar`).
   - Effect: If player is the sole claimant (`SINGLE_ZOCKER` or `RAZZIA_SOLE_CLAIMANT`), awards +$5,000 bonus cash.
3. **Informant (`informant`):**
   - Timing: Card selection phase.
   - Effect: Displays 1 AI opponent's destination bar on the table prior to card submission.
4. **Swiss Account (`swiss_account`):**
   - Timing: Round cleanup (`_round_cleanup`).
   - Effect: Awards 10% interest on current cash balance (capped at $12,000).
5. **Bribed Judge (`bribed_judge`):**
   - Timing: Duel tie resolution (`_run_duel`).
   - Effect: When defending against a duel challenge, ties are awarded to the owner instead of the challenger.
6. **Loaded Dice (`loaded_dice`):**
   - Timing: Duel die roll (`_run_duel`).
   - Effect: Any duel die roll result of 1 or 2 is upgraded to 3.
7. **Dirty Cop (`dirty_cop`):**
   - Timing: Venue resolution (`_resolve_bar`).
   - Effect: When player plays a RAZZIA card that fails because no ZOCKER cards were present, extorts 15% bribe from the bar's cash pile.
8. **Syndicate Crest (`syndicate_crest`):**
   - Timing: Round start (`_round_start`).
   - Effect: Awards +$3,000 dividend per owned relic at the start of each round.

