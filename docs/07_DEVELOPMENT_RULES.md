# Razzia Mobile — Development Rules

## 1. Purpose

This file defines how AI-assisted development must be performed.

The goal is to make the project easy for both a human developer and coding agents to understand and maintain.

---

# 2. Source of Truth

Use this priority:

```text
02_RULEBOOK.md
    ↓
03_GAME_FLOW.md
    ↓
04_GAME_DATA.md
    ↓
05_UI_UX.md
    ↓
06_AI_DESIGN.md
```

If code contradicts a higher-priority document, fix the code or explicitly change the document.

---

# 3. Golden Rule

**Never invent a game rule to make the code easier.**

If the rule is unclear:

1. stop;
2. identify the missing rule;
3. mark it as unresolved;
4. ask for verification;
5. update the rule document;
6. then implement.

---

# 4. Vibe Coding Workflow

Every coding task should follow:

```text
UNDERSTAND
  ↓
PLAN
  ↓
IMPLEMENT
  ↓
TEST
  ↓
REVIEW
  ↓
REPORT
```

The coding agent must not jump directly from a vague request to a large code rewrite.

---

# 5. Before Coding

The AI must:

1. inspect the existing project;
2. inspect relevant `/docs`;
3. identify affected rule IDs;
4. identify affected state IDs;
5. identify affected data types;
6. propose a small implementation plan.

Example:

```text
Task:
Implement two-player negotiation.

Relevant rules:
RULE-017
RULE-018
RULE-019

Relevant states:
NEGOTIATION
PROPOSAL
PROPOSAL_RESPONSE
DUEL_SETUP
DUEL_ROLL
DUEL_RESOLVE
AWARD_MONEY
```

---

# 6. Small Changes

Prefer one coherent feature per task.

Good:

```text
Implement card selection.
```

Good:

```text
Implement BarResolver for single Zocker.
```

Bad:

```text
Finish the entire game.
Add multiplayer.
Add animations.
Add AI.
Refactor architecture.
```

---

# 7. Do Not Rewrite Working Code

Do not:

- rewrite unrelated files;
- change architecture without a reason;
- rename public APIs unnecessarily;
- replace working libraries;
- delete tests because they are inconvenient.

If a refactor is needed, explain why before doing it.

---

# 8. Game Logic / UI Separation

Strict separation:

```text
UI
 ↓
Controller / Action Layer
 ↓
Game Engine
 ↓
Game State
```

The UI must never decide:

- who wins;
- how much money is awarded;
- whether Razzia activates;
- who wins a duel;
- whether the game ends.

---

# 9. Single Source of Game State

There must be one authoritative `GameState`.

Do not create:

```text
UI money
UI bar money
engine money
AI money
```

as independent values.

The UI reads from `GameState`.

---

# 10. Immutable Actions

Prefer actions/events:

```ts
selectCard(playerId, cardId)
acceptProposal(playerId)
callDuel(playerId)
rollDuel(playerId)
```

rather than direct mutation from components.

---

# 11. Validation

Every public engine action must validate:

- current phase;
- player permissions;
- referenced IDs;
- card ownership;
- valid amounts;
- valid negotiation state.

Invalid actions must return a controlled error.

---

# 12. No Magic Numbers

Avoid:

```ts
if (money > 50000) ...
```

unless the value is an intentional AI heuristic.

Prefer named constants/configuration:

```ts
const MONEY_VALUES = [...]
```

Rules should be represented through named functions or rule IDs.

---

# 13. Testing Requirements

Every implemented rule must have tests.

Minimum test categories:

### Setup

- 3-player setup
- 4–6 player setup
- 7–8 player setup

### Cards

- hand size
- card uniqueness
- deck recycling

### Money

- normal distribution
- accumulated money
- money conservation

### Zocker

- single Zocker
- multiple Zocker

### Razzia

- Razzia + Zocker
- Razzia without Zocker
- multiple Razzia

### Negotiation

- accept
- duel
- three-player one rejection
- three-player two rejections
- tied die symbols

### Duel

- higher score
- lower score
- tie
- challenger wins tie

### End game

- final round
- final score
- winner

---

# 14. Property Tests / Invariants

The following should be tested after major engine actions.

## Money invariant

```text
money in deck
+ money on bars
+ money held by players
=
configured total money
```

## Card invariant

Every card must exist exactly once.

## Hand invariant

After dealing:

```text
hand.length === 5
```

---

# 15. Debug Logging

Use structured events.

Example:

```json
{
  "event": "DUEL_RESOLVED",
  "round": 4,
  "barId": "JAZZ_HOUSE",
  "playerA": "P1",
  "playerB": "P2",
  "rollA": 4,
  "rollB": 2,
  "scoreA": 9,
  "scoreB": 7,
  "winner": "P1"
}
```

Do not rely only on human-readable console messages.

---

# 16. Reproducible Randomness

All randomness must pass through the game's RNG abstraction.

Support:

```ts
newGame({ seed: 12345 })
```

in development/testing.

A bug report should ideally include the seed.

---

# 17. Save Compatibility

Persist a `version` field in save data.

Example:

```json
{
  "version": 1,
  "gameState": {}
}
```

If the data schema changes:

- increment version;
- add migration logic;
- do not silently discard old saves.

---

# 18. Documentation Updates

When a feature changes a rule or game flow:

1. update documentation first;
2. update rule/state IDs;
3. implement code;
4. update tests;
5. update changelog.

---

# 19. Changelog

Maintain a root-level `CHANGELOG.md`.

Format:

```md
## YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Tests
- ...

### TODO
- ...
```

---

# 20. AI Coding Agent Response Format

After each coding task, the AI should report:

```md
## Implemented

- ...

## Files Changed

- ...

## Rules Affected

- RULE-...

## States Affected

- ...

## Tests Added/Updated

- ...

## Verification

- ...

## Remaining TODO

- ...
```

Keep the report concise.

---

# 21. No Silent Scope Expansion

If the requested feature suggests a larger architectural change, do not automatically implement the larger change.

Example:

User:

> Add a card selection animation.

Do not automatically:

- rewrite the card system;
- change the game engine;
- add a new animation library;
- redesign the entire UI.

Implement the requested feature first.

---

# 22. Error Handling

Errors should be categorized:

```text
RULE_ERROR
STATE_ERROR
DATA_ERROR
UI_ERROR
AI_ERROR
SAVE_ERROR
```

Example:

```ts
throw new RuleError(
  "RULE-021: Four-or-more claimant negotiation is not implemented."
);
```

This is better than a generic:

```text
Something went wrong.
```

---

# 23. Development Order

Recommended implementation sequence:

### Phase 1 — Foundation

- project setup;
- TypeScript types;
- GameState;
- RNG;
- event system.

### Phase 2 — Data

- bars;
- cards;
- money;
- setup factories.

### Phase 3 — Core Loop

- round start;
- money distribution;
- card dealing;
- card selection;
- reveal.

### Phase 4 — Resolution

- single Zocker;
- Razzia;
- multiple claimants;
- negotiation;
- duel.

### Phase 5 — End Game

- final-round detection;
- final scoring;
- game-over.

### Phase 6 — AI

- Easy;
- Normal;
- Hard.

### Phase 7 — UI Polish

- animations;
- sound;
- haptics;
- tutorial;
- accessibility.

### Phase 8 — Multiplayer

- networking;
- synchronization;
- reconnect;
- anti-cheat;
- matchmaking.

---

# 24. Definition of Done

A task is complete only if:

- code compiles;
- relevant tests pass;
- no unrelated behavior regressed;
- affected rule IDs are identified;
- game-state transitions are valid;
- UI does not bypass the engine;
- documentation is updated when necessary.

---

# 25. Final Instruction to Coding AI

When working on this project:

> Treat the `/docs` directory as the project specification.
>
> Do not invent rules.
>
> Do not silently change game mechanics.
>
> Do not expose hidden information.
>
> Do not put game logic inside UI components.
>
> Make small, testable changes.
>
> When uncertain, stop and identify the uncertainty instead of guessing.
