// Which rule branches do the golden games actually exercise?
import fs from "node:fs";
import path from "node:path";
const dir = path.resolve(process.argv[2] || "../../tests/golden");
const idx = JSON.parse(fs.readFileSync(path.join(dir, "index.json")));
const tally = {};
const bump = (k, f) => { (tally[k] ||= new Set()).add(f); tally[k].n = (tally[k].n || 0) + 1; };
for (const g of idx) {
  const d = JSON.parse(fs.readFileSync(path.join(dir, g.file)));
  const pc = g.playerCount;
  for (const e of d.events) {
    if (e.type === "BAR_RESOLVED") {
      bump("BAR_RESOLVED kind=" + e.kind + (e.outcome ? " outcome=" + e.outcome : ""), g.file);
      if (e.outcome) bump(`  claimants-bucket ${pc === 3 ? "3p" : "4+p"} outcome=${e.outcome}`, g.file);
    }
    if (e.type === "NEGOTIATION_STARTED") bump("NEGOTIATION claimants=" + e.claimantIds.length, g.file);
    if (e.type === "DUEL_RESOLVED") bump("DUEL " + (e.tie ? "TIE (challenger wins)" : "decided by score"), g.file);
    if (["DECK_RECYCLED", "FINAL_ROUND_ANNOUNCED", "RAZZIA_ACTIVATED", "PROPOSAL_ACCEPTED", "DUEL_CALLED"].includes(e.type)) bump(e.type, g.file);
    if (e.type === "GAME_ENDED") bump("GAME_ENDED winners=" + e.winnerIds.length, g.file);
    if (e.type === "MONEY_PLACED") bump("MONEY_PLACED extra=" + e.extra, g.file);
  }
  // seat-distance tie-break exercised? (two claimants with equal symbols)
  for (const e of d.events) if (e.type === "NEGOTIATION_STARTED") {
    const v = Object.values(e.symbols); if (new Set(v).size < v.length) bump("NEGOTIATION with equal die symbols (RULE-022 tie-break)", g.file);
  }
}
for (const k of Object.keys(tally).sort()) console.log(String(tally[k].n).padStart(6), "x in", String(tally[k].size).padStart(2), "games |", k);
