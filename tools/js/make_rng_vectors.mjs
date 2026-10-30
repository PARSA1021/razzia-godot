// RNG vectors from the reference mulberry32 (ai.js; same algorithm as the engine's state-based rngFloat).
// Floats are stored as the exact integer numerator k in k / 2^32, so no decimal parsing error can creep in.
import fs from "node:fs";
import AI from "./ai.js";
const seeds = [0, 1, 2, 42, 12345, 0x7fffffff, 0x80000000, 0xdeadbeef, 0xfffffffe, 0xffffffff];
const out = seeds.map((seed) => {
  const r = AI.mulberry32(seed);
  const k = [];
  for (let i = 0; i < 64; i++) k.push(Math.round(r() * 4294967296));
  return { seed, k };
});
fs.writeFileSync(process.argv[2] || "../../tests/golden/rng.json", JSON.stringify(out));
console.log("rng vectors:", out.length, "seeds x", out[0].k.length);
