# Razzia Mobile — UI/UX Specification

## 1. UX Goal

The mobile UI should make a physical tabletop game understandable without removing the hidden-information and simultaneous-choice elements that make Razzia interesting.

The player should always know:

- how much money they have;
- how much is in each bar;
- what cards they hold;
- what action is currently required;
- why the game is waiting;
- why money was awarded or not awarded.

---

# 2. Screen Map

```text
SPLASH
  ↓
MAIN_MENU
  ├── NEW_GAME
  ├── CONTINUE
  ├── HOW_TO_PLAY
  └── SETTINGS

NEW_GAME
  ↓
GAME_BOARD

GAME_BOARD
  ├── CARD_SELECTION
  ├── REVEAL
  ├── BAR_RESOLUTION
  ├── NEGOTIATION
  ├── DUEL
  └── ROUND_RESULT

GAME_OVER
```

---

# 3. Main Menu

Elements:

- New Game
- Continue
- How to Play
- Settings

Do not put gameplay state logic in the menu.

---

# 4. New Game

Controls:

- player count;
- human seat;
- AI difficulty;
- animation speed.

For MVP:

- default to 4 players;
- one human;
- three AI.

---

# 5. Game Board

The game board is the primary screen.

Suggested layout:

```text
┌──────────────────────────────┐
│ Round 4          $125,000    │
├──────────────────────────────┤
│                              │
│ COLIBRI          $10,000     │
│ COTTON CLUB      $35,000     │
│ HAVANA BAR       $20,000     │
│ THE JUNGLE       $65,000     │
│ LINCOLN'S        $15,000     │
│ JAZZ HOUSE       $90,000     │
│                              │
├──────────────────────────────┤
│       YOUR HAND              │
│                              │
│ [CARD] [CARD] [CARD] [CARD] │
│                 [CARD]       │
└──────────────────────────────┘
```

The exact visual design may change.

The information hierarchy must not.

---

# 6. Bar Component

Each bar should show:

- name;
- visual identity/color;
- current money;
- optional card-result indicator during resolution.

When a bar is selected/active:

- highlight it;
- show why it is being resolved.

Never rely only on color.

Use:

- name;
- icon;
- text;
- optional color.

This supports color-blind users.

---

# 7. Card Component

Each card should show:

- card type;
- bar;
- die symbol.

The selected card should have an obvious selected state.

Cards must not be permanently removed from the UI just because they are selected; the UI can visually mark the selected card until reveal.

---

# 8. Card Selection

Flow:

1. Player sees five cards.
2. Player taps a card.
3. Card becomes selected.
4. A confirmation action appears.
5. Player confirms.
6. The selected card becomes hidden/locked.
7. UI shows "Waiting for other players".
8. When all players are ready, reveal begins.

For an optional faster mode, confirmation can be disabled only if the player explicitly enables it.

---

# 9. Hidden Information

Before reveal:

- never show AI selected cards;
- never show AI's intended bar;
- never show AI's planned negotiation.

Do not leak hidden information through UI animations.

Example of bad UX:

```text
AI card moves toward Jazz House
```

before reveal.

Example of good UX:

```text
AI card remains face-down.
All cards flip simultaneously.
```

---

# 10. Reveal

Recommended animation:

1. Screen pauses briefly.
2. All face-down cards appear.
3. Cards flip together.
4. Cards fly/slide toward their corresponding bars.
5. Bar resolution starts.

The animation must be skippable.

---

# 11. Bar Resolution

When resolving a bar, display:

```text
JAZZ HOUSE
$85,000

Zocker ★5 — Player A
Zocker ★3 — Player B
```

Then show:

```text
Player A makes an offer.
```

The player should understand:

- why the bar is contested;
- who has priority;
- how much money is at stake.

---

# 12. Razzia Presentation

When a Razzia is active:

```text
🚨 RAZZIA

The gamblers are shut out.

Eligible claimants:
Player B — ★5
Player C — ★3

Prize: $85,000
```

Do not imply that the Razzia card always gets money.

If there is no Zocker at that bar:

```text
No gambler found.
The money remains at the bar.
```

---

# 13. Negotiation UI

Show:

- prize amount;
- proposer;
- every claimant;
- proposed allocation.

Example:

```text
JAZZ HOUSE — $85,000

YOUR OFFER

You        $55,000
Player B   $30,000

[CONFIRM OFFER]
```

For a human responding:

```text
PLAYER A OFFERS

You receive:
$30,000

[ACCEPT]
[DUEL]
```

Do not use "Reject" if the actual rule action is specifically a duel challenge.

---

# 14. Duel UI

Show:

```text
DUEL

Your card symbol: ★4
Opponent symbol: ★5

Roll the die.

[ROLL]
```

After both rolls:

```text
YOU
★4 + 3 = 7

OPPONENT
★5 + 1 = 6

YOU WIN
+$85,000
```

If tied:

```text
TIE

The player who called the duel wins.
```

---

# 15. Round Result

After all bars are resolved:

```text
ROUND 4 COMPLETE

+$85,000  Jazz House
+$20,000  Colibri
No money   Havana Bar

Your total:
$215,000
```

The player should be able to continue immediately.

---

# 16. Game Over

Show:

- final money totals;
- ranking;
- winner;
- round count;
- optional replay button.

For MVP, the result screen can be simple.

---

# 17. Tutorial

The tutorial should teach in this order:

1. Six bars.
2. Money accumulates.
3. Choose one of five cards.
4. Cards are hidden until everyone chooses.
5. Zocker claims.
6. Razzia interrupts Zocker.
7. Multiple claimants negotiate.
8. Rejection leads to duel.
9. Most money wins.

Do not explain every edge case before the player understands the core loop.

---

# 18. Accessibility

Provide:

- text labels in addition to color;
- scalable text;
- reduced animation mode;
- high-contrast option;
- haptic feedback toggle;
- sound toggle;
- animation skip;
- readable card symbols.

---

# 19. Mobile Navigation Rule

The player should never need to understand the state machine.

The UI should express actions as natural language:

Good:

```text
Choose a card.
```

Good:

```text
Make an offer.
```

Good:

```text
Accept or call a duel.
```

Avoid exposing developer terminology:

```text
ENTER PROPOSAL_RESPONSE STATE
```

---

# 20. UI/Engine Separation

UI may:

- display state;
- request an action;
- animate an engine result.

UI may not:

- decide winners;
- award money;
- calculate duel scores;
- mutate the deck;
- advance the game phase directly.

