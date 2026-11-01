# Razzia Mobile — Game Overview

> Project purpose: Build a mobile & PC/Steam Deck digital adaptation of the 1992 Ravensburger game **Razzia**, designed by Stefan Dorra.
>
> 🚀 **Steam 출시 마스터 문서 안내:** 최신 상용화 출시 감사 및 로드맵은 [`docs/STEAM_RELEASE_AUDIT.md`](STEAM_RELEASE_AUDIT.md) 및 [`README.md`](../README.md)를 참고하세요.
> Detailed rules live in `02_RULEBOOK.md`; implementation flow lives in `03_GAME_FLOW.md`.


## 1. Project Identity

- Working title: `Razzia Mobile`
- Source game: `Razzia`
- Original publisher: Ravensburger
- Original year: 1992
- Original designer: Stefan Dorra
- Original player count: 3–8
- Original play time: approximately 15–30 minutes depending on source/edition description
- Core theme: 1927, illegal gambling bars, gamblers, police raids, money
- Core objective: finish with the most money

## 2. Project Goal

Create a mobile game that preserves the core gameplay loop of the 1992 rules while adapting physical actions to a touch interface.

The first target is a **single-player game against AI**.

Online multiplayer is a future phase and must not be allowed to distort the single-player game architecture.

## 3. Core Gameplay Pillars

The following are the features that define the identity of the game:

1. Six gambling bars with accumulating money.
2. Each player has a private hand of cards.
3. Players simultaneously choose one card.
4. Cards are revealed simultaneously.
5. Each card belongs to exactly one bar.
6. A card is either a `ZOCKER` card or a `RAZZIA` card.
7. A die symbol on the card determines negotiation priority.
8. Multiple claimants for the same bar trigger negotiation.
9. A rejected negotiation can trigger a dice duel.
10. Money left unclaimed remains on its bar and can accumulate.
11. The player with the highest total money at the end wins.

## 4. Original Rules vs Mobile Adaptation

### Preserve unless explicitly changed

- Six bars.
- Zocker/Razzia card distinction.
- Hidden simultaneous card selection.
- Simultaneous reveal.
- Money accumulation on bars.
- Highest die-symbol claimant gets the right to make the first distribution proposal.
- Negotiation.
- Duel resolution.
- Remaining money staying on bars.
- Croupier rotation.
- Original player-count setup differences.

### Mobile-only adaptations

- Touch-based card selection.
- Animated card reveal.
- Digital dice roll.
- AI players.
- Automatic bookkeeping.
- Automatic deck reshuffling.
- Save/resume.
- Accessibility options.
- Tutorial.
- Optional speed controls.

Mobile adaptations must not silently change the underlying game rules.

## 5. Target MVP

The MVP should support:

- 3–6 players in a local/single-player simulation.
- One human player.
- AI opponents.
- Full card selection/reveal loop.
- Six bars.
- Money deck.
- Zocker resolution.
- Razzia resolution.
- Two-player negotiation.
- Two-player duel.
- Three-player negotiation and duel flow.
- Round progression.
- Game-end detection.
- Final score.
- Basic save state.

7–8 player support can be added after the core engine is stable.

## 6. Non-Goals for MVP

Do not initially build:

- Online matchmaking.
- Accounts.
- Social systems.
- Cosmetic shop.
- Live events.
- Battle pass.
- Real-money economy.
- Complex character progression.
- Machine-learning AI.

## 7. Design Principle

The game engine must be deterministic given:

- initial random seed,
- shuffled decks,
- player decisions,
- AI decisions,
- dice results.

This allows bugs and rule disputes to be reproduced.

## 8. Source of Truth

Priority order:

1. `02_RULEBOOK.md`
2. `03_GAME_FLOW.md`
3. `04_GAME_DATA.md`
4. `05_UI_UX.md`
5. `06_AI_DESIGN.md`
6. `07_DEVELOPMENT_RULES.md`

If documents conflict, do not silently choose one. Stop and report the conflict.

## 9. Rule Change Policy

Any intentional change to the original rules must be documented as:

- `RULE CHANGE`
- reason
- original behavior
- new mobile behavior
- affected rule IDs
- affected tests

Never hide a rule change inside implementation code.

## 10. Intellectual Property Boundary

This project should distinguish between:

- game mechanics/rules being implemented for a prototype,
- original artwork,
- original card illustrations,
- logos,
- packaging,
- rulebook text,
- trademarks,
- other protected assets.

Do not copy original artwork, logos, or rulebook text into the application unless the project has the necessary rights/licensing.

For a public/commercial release, perform a jurisdiction-appropriate IP/trademark review before release.

## 11. Definition of Done

The game is not considered feature-complete merely because the UI works.

A feature is done only when:

- the rule is documented,
- the game state can represent it,
- the engine resolves it correctly,
- edge cases are handled,
- tests exist,
- UI feedback exists where needed,
- save/load does not corrupt the state.
