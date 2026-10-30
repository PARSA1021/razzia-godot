# Razzia Mobile — Changelog

## 2026-10-03

### Added
- Initial game overview.
- Initial rulebook specification.
- Initial game-flow/state-machine specification.
- Initial data specification.
- Initial UI/UX specification.
- Initial AI design specification.
- Initial development rules.

### Verification
- Core rules were cross-checked against the available 1992 Ravensburger rulebook scan.
- The four-or-more claimant negotiation case is intentionally marked unresolved rather than invented.

### TODO
- Verify any remaining edition-specific edge cases directly against the physical rulebook if available.
- Decide mobile technology stack.
- Begin Phase 1 foundation implementation.

## 2026-10-04

### Added
- `src/engine.js`: full rules engine for 3 players (state machine, seeded RNG, save/load v1, invariants INV-001..005, structured events).
- `src/ai.js`: rule-based AI, EASY and NORMAL, personalities CONSERVATIVE / AGGRESSIVE / OPPORTUNIST; public view only.
- `src/controller.js`: action layer between UI and engine.
- `ui/` + `build.js`: mobile UI (noir look), single-file build to `dist/play.html`.
- Tests: `test/run-tests.js` (40 engine/AI tests), `test/ai-sim.js` (balance sim), `test/ui-smoke.js` (full games through jsdom).
- `docs/08_ASSUMPTIONS.md`.

### Changed
- ASSUMPTION-* items are recorded for every gap in the docs (see 08_ASSUMPTIONS.md). No documented rule was changed.

### Fixed
- AI balance: OPPORTUNIST over-winning (48%) fixed via NORMAL alpha 1.4 / alphaMul 1.0; seat fairness now ~33% each.
- `getPublicView` now exposes `yourProfile` so the AI reads its own difficulty/personality without touching hidden data.

### Tests
- 40/40 engine tests, 60-game invariant property test, AI anti-cheat test, 4 jsdom full-game UI runs, 390px layout check, resume check.

### TODO
- Verify ASSUMPTIONs against the physical rulebook; resolve RULE-021 to unlock 4–8 players.
- HARD AI; tech-stack decision; sound/haptics; tutorial (docs/05).

## 2026-10-04 (card feel)

### Added
- Card faces in the game (hand, table, bars) from `design/cards.html`; hand of 5 as 3+2 thumb-sized cards; tapped card lifts, confirm locks it (docs/05 §8).
- Table row: one slot per player, face-down while hidden (shows only that a card was put down, docs/05 §9), all flip together on reveal, then slide to their bars (§10, skippable).
- `design/cards.html`: card sheet (72 cards, back, money cards).

### Changed
- UI only (`ui/ui.js`, `ui/head.html`). Engine, AI, rules untouched.

### Fixed
- Entrance animations replayed on every redraw; now only the event that creates a card animates.

## 2026-10-05 (UI redesign phases 0-2)

### Added
- PHASE 1 design system in `ui/head.html`: `--rz-*` tokens for surfaces, text, brass/gold, danger, felt/wood/velvet, bar colors, card-art colors, type scale, spacing, radii and motion (`--rz-speed`, durations, easing). Reduced motion sets speed to 0 in one place.
- PHASE 2 game board: HUD (round, money on the table), opponent seats, casino table (felt, wood rim) with four bars and note stacks, card slots on the table, my plate, "now" line, hand tray.
- Number count-up for bar totals, player money and the pot (respects skip, fast mode, reduced motion).

### Changed
- UI only (`ui/head.html`, `ui/ui.js`). All colors now come from tokens; no engine, AI, save format or rule changes.
- Layout and look moved from cold blue noir to a warm speakeasy palette.

### Tests
- 40/40 engine tests, jsdom full-game runs, 320px and 390px screenshots, save and resume check.

### TODO (not part of this step)
- PHASE 3-12: card polish, reveal countdown, negotiation/duel scenes, Razzia event, round result, menu, audio, accessibility pass.

## 2026-10-05 (UI redesign phases 3-4)

### Added
- PHASE 3 cards: tilt on select, Zocker (gold) and Razzia (red) identities, `CARD SELECTED` note, `PLAY CARD` button, `LOCKED` tag, `YOU ARE READY` and `WAITING FOR OTHER PLAYERS` states.
- PHASE 4 reveal: ALL PLAYERS READY, table darkens, 3-2-1, all cards flip together, cards fly to their bars, bar pulse (docs/05 §10). Skippable.
- `Anim` helpers in `ui/ui.js` (speed, skip and reduced motion respected) and UI-only beats in the playback queue.
- `test/ui-hidden.js`: the page holds no face of another player's card before the flip.

### Changed
- The played card now stays visible and marked until the flip (docs/05 §7). Before, it flew away and vanished.
- Card faces are put into the page only at the flip, not earlier.
- UI only. Engine, AI, rules, save format untouched.

### Tests
- 40/40 engine tests, 6 full jsdom games, hidden-information check (135 states, 0 leaks), 390px frames of each reveal step, 320px reduced-motion run, resume check.

## 2026-10-06 (UI redesign phases 5-6)

### Added
- PHASE 5 negotiation on the table (no popup): contested bar scene with stake, each claimant with their die symbol, who proposes first, the split as a bar, live accept / duel marks, a next-step line. Panels: `YOU ARE THE PROPOSER` / `YOUR OFFER` / `MAKE OFFER`; `<name> OFFERS` / `YOU RECEIVE` / `ACCEPT` / `CALL DUEL`.
- PHASE 6 duel scene: `$X AT STAKE`, both sides with die symbols, `ROLL` tap (when you are in the duel), tumbling dice, sums (`★3 + 5 = 8`), winner, tie note (challenger wins, as the engine decided). Other bars dim during the scene.
- `test/ui-smoke.js` and `test/ui-hidden.js` now tap ROLL.

### Changed
- UI only. Scenes are built from engine events (and from the pending negotiation after a reload). The ROLL tap only starts the replay; the engine had already decided the result. Dice faces shuffle for show only.

### Tests
- 40/40 engine tests, 6 full jsdom games with ROLL taps, hidden-information check, 390px frames of response panel, duel ready, rolling and result, resume check.

## 2026-10-06 — PHASE 7 (Razzia event) + portrait/landscape roles
- Razzia event (`RAZZIA_ACTIVATED`): hush → siren flash (max 2 flashes, none with reduced motion) → "RAZZIA" slam → shut-out Zocker cards pushed back with OUT mark → claimants resolve. `RAZZIA_NO_ZOCKER` shows "NO GAMBLERS FOUND. THE MONEY STAYS." Presentation only; the engine decides who is shut out. No audio yet (Phase 10).
- Layout: portrait = comfortable play (one column, action panel scrolls into view). Landscape (≤760px high) = casino-table mode: sidebar (status, me, narration), table with bars in one row, scenes/cards as table overlays, hand in one row with PLAY CARD, input panels as overlay cards, log/rules hidden.
- Engine, AI, controller untouched.
