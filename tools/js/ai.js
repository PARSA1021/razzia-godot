/* Razzia Mobile AI (docs/06_AI_DESIGN.md): rule-based, deterministic given its RNG, and limited to public information.
 * EASY and NORMAL are implemented. HARD (discard tracking, opponent profiles) is not built yet.
 * All weights live in DIFFICULTY / PERSONALITY, not in the logic.
 */
"use strict";
  import E from "./engine.js";

  var DIFFICULTY = {
    EASY:   { alpha: 0.4, noise: 0.45, useUnseen: false, accept: 0.70, greed: 0.25, propNoise: 0.25 },
    NORMAL: { alpha: 1.4, noise: 0.10, useUnseen: true,  accept: 0.95, greed: 0.12, propNoise: 0.05 }
  };
  var PERSONALITY = {
    CONSERVATIVE: { risk: 0.30, accept: -0.12, greed: -0.04, alphaMul: 1.0 },
    AGGRESSIVE:   { risk: -0.10, accept: 0.15, greed: 0.06, alphaMul: 1.0 },
    OPPORTUNIST:  { risk: 0.10, accept: 0.0, greed: 0.0, alphaMul: 1.0 }
  };
  var HOLD_COST = 0.01;   // scarce high symbols are worth keeping a little

  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function cfgFor(view, pid) {
    var me = view.yourProfile || {};
    var d = DIFFICULTY[me.aiDifficulty || "NORMAL"] || DIFFICULTY.NORMAL;
    var per = PERSONALITY[me.personality || "CONSERVATIVE"] || PERSONALITY.CONSERVATIVE;
    return {
      alpha: d.alpha * per.alphaMul, noise: d.noise, useUnseen: d.useUnseen, risk: per.risk,
      accept: d.accept + per.accept, greed: Math.max(0, d.greed + per.greed), propNoise: d.propNoise
    };
  }

  function binom(n, k) { var r = 1; for (var i = 1; i <= k; i++) r = r * (n - k + i) / i; return r; }
  function clamp(x, lo, hi) { return Math.max(lo, Math.min(hi, x)); }
  function shareFrac(sym, k) { return clamp(1 / k + 0.045 * (sym - 3.5), 0.08, 0.8); }

  // Probability that one opponent plays at a bar, from public bar money only.
  function barProbabilities(view, bars, cfg) {
    var w = {}, sum = 0;
    bars.forEach(function (b) { w[b.id] = Math.pow(b.money / 1000 + 3, cfg.alpha); sum += w[b.id]; });
    var p = {};
    bars.forEach(function (b) { p[b.id] = w[b.id] / sum; });
    return p;
  }

  function zockerShare(view, cfg) {
    if (!cfg.useUnseen) return 2 / 3;
    var z = view.unseen.ZOCKER, r = view.unseen.RAZZIA;
    return z + r > 0 ? z / (z + r) : 2 / 3;
  }

  // Expected value and spread of playing `card` against the n-1 hidden opponent cards.
  function evaluateCard(card, moneyK, p, q, nOthers) {
    var ev = 0, ev2 = 0;
    for (var a = 0; a <= nOthers; a++) {
      var pa = binom(nOthers, a) * Math.pow(p, a) * Math.pow(1 - p, nOthers - a);
      for (var zc = 0; zc <= a; zc++) {
        var rc = a - zc;
        var pr = pa * binom(a, zc) * Math.pow(q, zc) * Math.pow(1 - q, rc);
        var pay;
        if (card.type === "ZOCKER") {
          if (rc > 0) pay = 0;
          else if (zc === 0) pay = moneyK;
          else pay = moneyK * shareFrac(card.dieSymbol, zc + 1) * 0.95;
        } else {
          if (zc === 0) pay = 0;
          else if (rc === 0) pay = moneyK;
          else pay = moneyK * shareFrac(card.dieSymbol, rc + 1) * 0.95;
        }
        ev += pr * pay; ev2 += pr * pay * pay;
      }
    }
    return { ev: ev, sd: Math.sqrt(Math.max(0, ev2 - ev * ev)) };
  }

  function cardValues(view, cfg, extraBarId, extraValue) {
    var bars = view.bars.filter(function (b) { return b.active; }).map(function (b) {
      return { id: b.id, money: b.money + (b.id === extraBarId ? extraValue : 0) };
    });
    var pb = barProbabilities(view, bars, cfg), q = zockerShare(view, cfg), nOthers = view.playerCount - 1;
    var money = {}, avg = 0;
    bars.forEach(function (b) { money[b.id] = b.money / 1000; avg += b.money / 1000; });
    avg = avg / bars.length;
    return view.hand.map(function (card) {
      var r = evaluateCard(card, money[card.barId], pb[card.barId], q, nOthers);
      return { card: card, value: r.ev - cfg.risk * r.sd - HOLD_COST * card.dieSymbol * avg, scale: avg };
    });
  }

  function pickBest(list, cfg, rng) {
    var best = null, bestV = -Infinity;
    list.forEach(function (x) {
      var v = x.value + (rng() - 0.5) * 2 * cfg.noise * Math.max(1, x.scale);
      if (v > bestV) { bestV = v; best = x; }
    });
    return best;
  }

  function chooseCard(view, rng) {
    var cfg = cfgFor(view, view.you);
    return pickBest(cardValues(view, cfg, null, 0), cfg, rng).card.id;
  }

  // The Croupier places the extra money card before choosing a card (docs/03 §9).
  function chooseExtraBar(view, rng) {
    var cfg = cfgFor(view, view.you), best = null, bestV = -Infinity;
    view.bars.filter(function (b) { return b.active; }).forEach(function (b) {
      var top = pickBest(cardValues(view, cfg, b.id, view.extraMoneyCard.value), { noise: 0 }, rng);
      var v = top.value + (rng() - 0.5) * 2 * cfg.noise * Math.max(1, top.scale);
      if (v > bestV) { bestV = v; best = b.id; }
    });
    return best;
  }

  function roundToStep(x) { return Math.round(x / E.MONEY_STEP) * E.MONEY_STEP; }

  // Always returns a proposal the engine accepts: whole steps summing exactly to the prize.
  function makeProposal(view, rng) {
    var neg = view.negotiation, cfg = cfgFor(view, view.you), me = view.you;
    var mySym = neg.symbols[me], others = neg.claimantIds.filter(function (id) { return id !== me; });
    var nC = neg.claimantIds.length, scale = nC === 2 ? 1 : nC === 3 ? 0.8 : Math.max(0.35, 2.4 / nC);   // more claimants = a duel is worth less to each of them
    var offers = {}, total = 0;
    others.forEach(function (o) {
      var pWin = E.duelWinProbability(neg.symbols[o], mySym, true);
      var raw = neg.prize * pWin * (1 - cfg.greed) * scale * (1 + (rng() - 0.5) * 2 * cfg.propNoise);
      offers[o] = Math.max(0, roundToStep(raw)); total += offers[o];
    });
    var cap = roundToStep(neg.prize * 0.9);
    while (total > cap) {
      var big = others.slice().sort(function (a, b) { return offers[b] - offers[a]; })[0];
      if (offers[big] <= 0) break;
      offers[big] -= E.MONEY_STEP; total -= E.MONEY_STEP;
    }
    var alloc = {}; alloc[me] = neg.prize - total;
    others.forEach(function (o) { alloc[o] = offers[o]; });
    return alloc;
  }

  // "DUEL" is the rule action; the AI calls it when the expected duel value beats the offer.
  function respondToProposal(view, rng) {
    var neg = view.negotiation, cfg = cfgFor(view, view.you), me = view.you;
    var offer = neg.proposal[me];
    var others = neg.claimantIds.filter(function (id) { return id !== me && id !== neg.proposerId; });
    var prize = neg.prize - others.reduce(function (a, o) { return a + neg.proposal[o]; }, 0);   // assume the others accept
    var duelEV = E.duelWinProbability(neg.symbols[me], neg.symbols[neg.proposerId], true) * prize;
    var jitter = cfg.noise > 0.3 ? (rng() - 0.5) * 0.3 * neg.prize : 0;
    return offer + jitter >= duelEV * cfg.accept ? "ACCEPT" : "DUEL";
  }

  var api = {
    DIFFICULTY: DIFFICULTY, PERSONALITY: PERSONALITY, mulberry32: mulberry32,
    chooseCard: chooseCard, chooseExtraBar: chooseExtraBar, makeProposal: makeProposal, respondToProposal: respondToProposal
  };
  export default api;

