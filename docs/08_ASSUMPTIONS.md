# Razzia Mobile — Assumptions and Open Questions

Every place where the specification (docs 01–07) is silent, vague or self-contradictory, the code follows one explicit
assumption instead of silently inventing a rule (docs/07 dev rules). Each is marked `ASSUMPTION-*` in `src/engine.js`.
**Replace these with the real 1992 rule once it is verified against the physical rulebook.** Changing one means a RULE CHANGE entry in CHANGELOG.md.

| ID | Gap in the docs | What the code does | Rules touched | Tests |
|---|---|---|---|---|
| ASSUMPTION-DIST | Docs give 48 Zocker / 24 Razzia cards, RULE-029 removals, but not the die symbols per card | Per bar: Zocker 1,2,3,3,4,4,5,6; Razzia 2,4,5,6 (consistent with removing exactly 18 cards) | RULE-029, 04_GAME_DATA | setup tests |
| ASSUMPTION-SOLE-RAZZIA | One Razzia card alone on a bar with Zockers: who gets the money? | The single Razzia player is the only claimant and takes the whole bar | Razzia resolution | Razzia tests |
| ASSUMPTION-019 | RULE-019 allows paying from already-won money; 03_GAME_FLOW §15 caps total at the prize | Stricter reading: proposal must sum exactly to the prize | RULE-019 | validation tests |
| ASSUMPTION-STEP | No smallest unit for proposals | Multiples of $5,000 (smallest money card) | RULE-018/019 | validation tests |
| ASSUMPTION-CHALLENGER | 3 claimants, both reject: who is challenger in each duel? | Duel 1: lowest-priority claimant; duel 2: the remaining third | RULE-020, RULE-024 | negotiation tests |
| ASSUMPTION-ORDER | RULE-023 priority is vague | Higher symbol first; ties: farther from Croupier first; "lowest" = last | RULE-023 | seat-distance test |
| ASSUMPTION-END | Final round with fewer money cards than needed | Cards placed left to right; no free placement unless bars+1 cards | RULE-005..008 | end-game test |
| ASSUMPTION-EMPTY | Bar with $0 and claimants | Not resolved | bar resolution | Zocker tests |
| ASSUMPTION-TIE | Tie in final money | Shared win (`winnerId` null, `winnerIds` list) | RULE-033 | end-game test |
| First Croupier | — | Random (RULE-007) | RULE-007 | determinism test |
| 3-player length | — | 72 money cards, 5 per round, 15 rounds, last round has 2 cards | RULE-004 | end-game test |

## Unresolved (blocks features, not guessed)
- **RULE-021 — four or more claimants on one bar**: engine throws `UnsupportedRuleError`; therefore the UI only offers 3 players (1 human + 2 AI). 4–8 player setups exist in the engine but are locked.
- The docs claim a cross-check with the 1992 rulebook scan; I could not access it, so every assumption above needs confirmation from that source.

## Not built (by choice)
- HARD AI (discard tracking, opponent profiles) — docs/06 later phase.
- Production tech stack — docs list it as TODO; the prototype is plain JS with no build step so it can be ported.

## IP note
The prototype reuses the game name and bar names of the source game. A public or commercial release needs a trademark/IP review (docs/01 §10). This is not legal advice.
