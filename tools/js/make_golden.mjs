// Generates golden logs from the reference JS engine/AI/controller.
// Each golden game = config + every action taken + every engine event + a final summary.
// The GDScript port must reproduce all of it exactly (see tests/run_tests.gd).
import fs from "node:fs";
import path from "node:path";
import E from "./engine.js";
import C from "./controller.js";

const OUT = path.resolve(process.argv[2] || "../../tests/golden");
fs.mkdirSync(OUT, { recursive: true });

const CASES = [];
for (const n of [3, 4, 5, 6, 7, 8]) {
  for (const diff of ["NORMAL", "EASY"]) {
    const seeds = n === 3 ? [1, 2, 3, 7, 42, 12345] : [1, 2, 3, 99];
    for (const seed of seeds) CASES.push({ playerCount: n, aiDifficulty: diff, seed, humanPlayerId: null });
  }
}

function summary(s) {
  return {
    round: s.round, phase: s.phase, rngState: s.rngState, croupierId: s.croupierId,
    winnerId: s.winnerId, winnerIds: s.winnerIds,
    money: Object.fromEntries(s.players.map((p) => [p.id, p.money])),
    drawPile: s.drawPile.length, discardPile: s.discardPile.length, moneyDeck: s.moneyDeck.length,
  };
}

let index = [];
for (const cfg of CASES) {
  const actions = [];
  const state = E.createGame(cfg);
  const initialEvents = state.events.slice();
  const initialSummary = summary(state);
  const ctrl = C.createController(state, { onAction: (_s, a) => actions.push(JSON.parse(JSON.stringify(a))) });
  const pending = ctrl.run();
  if (pending) throw new Error("all-AI game stopped waiting for input: " + JSON.stringify(pending));
  const inv = E.checkInvariants(state);
  if (inv.length) throw new Error("invariants: " + inv.join("; "));
  const name = `g_${cfg.playerCount}p_${cfg.aiDifficulty}_${cfg.seed}.json`;
  const doc = {
    config: cfg,
    initialEvents,
    initialSummary,
    actions,
    events: state.events,       // full log including the initial events
    final: summary(state),
  };
  fs.writeFileSync(path.join(OUT, name), JSON.stringify(doc));
  index.push({ file: name, ...cfg, rounds: state.round, actions: actions.length, events: state.events.length });
}
fs.writeFileSync(path.join(OUT, "index.json"), JSON.stringify(index, null, 1));
console.log(`wrote ${index.length} golden games to ${OUT}`);
console.log(index.map((i) => `${i.file} rounds=${i.rounds} actions=${i.actions} events=${i.events}`).join("\n"));
