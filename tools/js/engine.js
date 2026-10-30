/* Razzia Mobile game engine.
 * Source of truth: docs/02_RULEBOOK.md (RULE-xxx), docs/03_GAME_FLOW.md (states), docs/04_GAME_DATA.md (data).
 * Pure rules: no UI, no AI. All randomness goes through the seeded RNG stored in state.rngState.
 * Anything the docs leave open is marked ASSUMPTION-xxx and listed in docs/08_ASSUMPTIONS.md.
 */
"use strict";

  var VERSION = 1;
  var HAND_SIZE = 5;                 // RULE-006
  var MONEY_STEP = 5000;             // ASSUMPTION-STEP: proposals use multiples of the smallest money card

  var BAR_DEFS = [                   // RULE-004
    { id: "COLIBRI", name: "Colibri", order: 1 },
    { id: "COTTON_CLUB", name: "Cotton Club", order: 2 },
    { id: "HAVANA_BAR", name: "Havana Bar", order: 3 },
    { id: "THE_JUNGLE", name: "The Jungle", order: 4 },
    { id: "LINCOLNS", name: "Lincoln's", order: 5 },
    { id: "JAZZ_HOUSE", name: "Jazz House", order: 6 }
  ];

  var ORIGINAL_MONEY_COUNTS = {      // RULE-003 (84 cards)
    5000: 15, 10000: 15, 15000: 12, 20000: 12, 25000: 9, 30000: 9, 40000: 6, 50000: 6
  };
  var REMOVED_MONEY_3P = {           // RULE-030 step 4
    5000: 2, 10000: 2, 15000: 2, 20000: 2, 25000: 1, 30000: 1, 40000: 1, 50000: 1
  };

  // ASSUMPTION-DIST: the docs give 48 Zocker / 24 Razzia and the RULE-029 removals, but not the die-symbol
  // distribution. Chosen so that RULE-029 removes exactly 18 cards (6 Razzia-5, 6 Zocker-3, 6 Zocker-4):
  // per bar 8 Zocker cards (1,2,3,3,4,4,5,6) and 4 Razzia cards (2,4,5,6).
  var ZOCKER_SYMBOLS = [1, 2, 3, 3, 4, 4, 5, 6];
  var RAZZIA_SYMBOLS = [2, 4, 5, 6];

  /* ---------------- errors ---------------- */

  class GameError extends Error {
    constructor(category, message) { super(message); this.name = category; this.category = category; }
  }
  class UnsupportedRuleError extends GameError {
    constructor(message) { super("RULE_ERROR", message); this.name = "UnsupportedRuleError"; }
  }
  function ruleErr(m) { return new GameError("RULE_ERROR", m); }
  function stateErr(m) { return new GameError("STATE_ERROR", m); }
  function dataErr(m) { return new GameError("DATA_ERROR", m); }

  /* ---------------- RNG (state-based, deterministic) ---------------- */

  function rngFloat(s) {
    s.rngState = (s.rngState + 0x6D2B79F5) | 0;
    var t = s.rngState;
    t = Math.imul(t ^ (t >>> 15), 1 | t);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  function rngInt(s, min, max) { return min + Math.floor(rngFloat(s) * (max - min + 1)); }
  function shuffle(s, arr) {
    for (var i = arr.length - 1; i > 0; i--) {
      var j = rngInt(s, 0, i), t = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    return arr;
  }
  // Test hook: state.forcedRolls = [..] is consumed before the RNG (keeps the "all randomness via RNG" rule testable).
  function rollDie(s) {
    if (s.forcedRolls && s.forcedRolls.length) return s.forcedRolls.shift();
    return rngInt(s, 1, 6);
  }

  /* ---------------- data factories (docs/04 §15-16) ---------------- */

  function createOriginalCardSet() {
    var cards = [];
    BAR_DEFS.forEach(function (b) {
      ZOCKER_SYMBOLS.forEach(function (sym, i) {
        cards.push({ id: b.id + "-Z" + sym + "-" + i, type: "ZOCKER", barId: b.id, dieSymbol: sym });
      });
      RAZZIA_SYMBOLS.forEach(function (sym, i) {
        cards.push({ id: b.id + "-R" + sym + "-" + i, type: "RAZZIA", barId: b.id, dieSymbol: sym });
      });
    });
    return cards;
  }

  function createMoneyCards(counts) {
    var out = [];
    Object.keys(counts).forEach(function (v) {
      for (var k = 0; k < counts[v]; k++) out.push({ id: "M" + v + "-" + k, value: Number(v) });
    });
    return out;
  }

  function makeBars(activeCount) {
    return BAR_DEFS.map(function (b, i) { return { id: b.id, name: b.name, order: b.order, active: i < activeCount, money: 0 }; });
  }

  function createSetupFor3Players() {   // RULE-030
    var bars = BAR_DEFS.map(function (b) {
      return { id: b.id, name: b.name, order: b.order, active: b.id !== "LINCOLNS" && b.id !== "JAZZ_HOUSE", money: 0 };
    });
    var cards = createOriginalCardSet().filter(function (c) { return c.barId !== "LINCOLNS" && c.barId !== "JAZZ_HOUSE"; });
    var counts = {};
    Object.keys(ORIGINAL_MONEY_COUNTS).forEach(function (v) { counts[v] = ORIGINAL_MONEY_COUNTS[v] - REMOVED_MONEY_3P[v]; });
    return { bars: bars, cardDeck: cards, moneyDeck: createMoneyCards(counts), perRound: 5 };
  }

  function createSetupFor4To6Players() {   // RULE-029
    var cards = createOriginalCardSet().filter(function (c) { return !(c.type === "RAZZIA" && c.dieSymbol === 5); });
    BAR_DEFS.forEach(function (b) {
      [3, 4].forEach(function (sym) {
        var idx = cards.findIndex(function (c) { return c.barId === b.id && c.type === "ZOCKER" && c.dieSymbol === sym; });
        if (idx < 0) throw dataErr("setup: missing Zocker " + sym + " for " + b.id);
        cards.splice(idx, 1);
      });
    });
    return { bars: makeBars(6), cardDeck: cards, moneyDeck: createMoneyCards(ORIGINAL_MONEY_COUNTS), perRound: 7 };
  }

  function createSetupFor7To8Players() {   // RULE-031
    return { bars: makeBars(6), cardDeck: createOriginalCardSet(), moneyDeck: createMoneyCards(ORIGINAL_MONEY_COUNTS), perRound: 7 };
  }

  function createSetup(playerCount) {
    if (playerCount === 3) return createSetupFor3Players();
    if (playerCount >= 4 && playerCount <= 6) return createSetupFor4To6Players();
    if (playerCount >= 7 && playerCount <= 8) return createSetupFor7To8Players();
    throw ruleErr("RULE-002: player count must be 3-8");
  }

  /* ---------------- helpers ---------------- */

  function clone(x) { return JSON.parse(JSON.stringify(x)); }
  function getPlayer(s, id) {
    for (var i = 0; i < s.players.length; i++) if (s.players[i].id === id) return s.players[i];
    throw dataErr("unknown player " + id);
  }
  function getBar(s, id) {
    for (var i = 0; i < s.bars.length; i++) if (s.bars[i].id === id) return s.bars[i];
    throw dataErr("unknown bar " + id);
  }
  function activeBars(s) { return s.bars.filter(function (b) { return b.active; }); }
  function emit(s, type, payload) {
    var e = { seq: ++s.seq, type: type, round: s.round };
    if (payload) for (var k in payload) e[k] = payload[k];
    s.events.push(e);
    return e;
  }
  function moneyMap(s) { var m = {}; s.players.forEach(function (p) { m[p.id] = p.money; }); return m; }
  function playedByBar(s, barId) { return s.playedCards.filter(function (p) { return p.barId === barId; }); }
  function playedOf(s, pid, barId) {
    for (var i = 0; i < s.playedCards.length; i++) {
      if (s.playedCards[i].playerId === pid && s.playedCards[i].barId === barId) return s.playedCards[i];
    }
    throw stateErr("player " + pid + " has no played card at " + barId);
  }

  // RULE-022/024: distance in seats from the current Croupier, clockwise. 0 = the Croupier.
  function seatDistance(s, pid) {
    var cr = getPlayer(s, s.croupierId).seatIndex, me = getPlayer(s, pid).seatIndex;
    return (me - cr + s.playerCount) % s.playerCount;
  }
  // Priority: higher die symbol first; ties: farther from the Croupier first (RULE-022).
  // ASSUMPTION-ORDER: "lowest" (RULE-020 both-reject) is the last element of this same ordering (RULE-023 is not specific).
  function orderByPriority(s, playedCards) {
    return playedCards.slice().sort(function (a, b) {
      return (b.dieSymbol - a.dieSymbol) || (seatDistance(s, b.playerId) - seatDistance(s, a.playerId));
    });
  }

  function duelWinProbability(symA, symB, aIsChallenger) {   // exact, for AI and UI hints (docs/06 §14)
    var win = 0;
    for (var a = 1; a <= 6; a++) for (var b = 1; b <= 6; b++) {
      var sa = symA + a, sb = symB + b;
      if (sa > sb || (sa === sb && aIsChallenger)) win++;
    }
    return win / 36;
  }

  /* ---------------- game creation ---------------- */

  function createGame(config) {
    config = config || {};
    var n = config.playerCount === undefined ? 3 : config.playerCount;
    if (!(n >= 3 && n <= 8) || Math.floor(n) !== n) throw ruleErr("RULE-002: player count must be an integer 3-8");
    var setup = createSetup(n);
    var seed = (config.seed === undefined ? 1 : config.seed) >>> 0 || 1;
    var humanId = config.humanPlayerId === undefined ? "P1" : config.humanPlayerId;   // null = all AI
    var names = config.names || [];
    var PERSONALITIES = ["CONSERVATIVE", "AGGRESSIVE", "OPPORTUNIST"];

    var s = {
      version: VERSION, phase: "GAME_INIT", round: 0, playerCount: n,
      players: [], bars: setup.bars, cards: {}, drawPile: [], discardPile: [], moneyDeck: [],
      croupierId: null, currentBarIndex: null, currentBarId: null,
      activeNegotiation: null, activeDuel: null, finalRound: false, winnerId: null, winnerIds: [],
      playedCards: [], extraMoneyCard: null, roundStartMoney: {}, totalMoney: 0, perRound: setup.perRound,
      config: { seed: seed, aiDifficulty: config.aiDifficulty || "NORMAL", humanPlayerId: humanId },
      rngState: seed, events: [], seq: 0
    };

    var aiSeat = 0;
    for (var i = 0; i < n; i++) {
      var id = "P" + (i + 1), isHuman = id === humanId;
      s.players.push({
        id: id, name: names[i] || (isHuman ? "나" : "AI " + (i + 1)), isHuman: isHuman, seatIndex: i, money: 0, hand: [],
        selectedCardId: null, aiDifficulty: isHuman ? undefined : (config.aiDifficulty || "NORMAL"),
        personality: isHuman ? undefined : PERSONALITIES[aiSeat++ % PERSONALITIES.length]
      });
    }

    setup.cardDeck.forEach(function (c) { s.cards[c.id] = c; });
    s.drawPile = shuffle(s, setup.cardDeck.map(function (c) { return c.id; }));
    s.moneyDeck = shuffle(s, setup.moneyDeck);
    s.totalMoney = s.moneyDeck.reduce(function (a, m) { return a + m.value; }, 0);

    s.phase = "SETUP";
    emit(s, "GAME_STARTED", { playerCount: n, seed: seed, totalMoney: s.totalMoney });
    s.players.forEach(function (p) { while (p.hand.length < HAND_SIZE) p.hand.push(drawCard(s)); });
    s.croupierId = config.firstCroupierId || s.players[rngInt(s, 0, n - 1)].id;   // RULE-007: "coolest gambler" is chosen at random
    s.phase = "ROUND_START";
    advance(s);
    return s;
  }

  function drawCard(s) {
    if (!s.drawPile.length) {            // RULE-027
      if (!s.discardPile.length) throw stateErr("draw pile and discard pile are both empty");
      s.drawPile = shuffle(s, s.discardPile.splice(0, s.discardPile.length));
      emit(s, "DECK_RECYCLED", { count: s.drawPile.length });
    }
    return s.drawPile.pop();
  }

  /* ---------------- state machine ---------------- */

  function advance(s) {
    for (var guard = 0; guard < 100000; guard++) {
      switch (s.phase) {
        case "ROUND_START": roundStart(s); break;
        case "DEAL_TO_FIVE": dealToFive(s); break;
        case "MONEY_DISTRIBUTION":
          if (s.extraMoneyCard) return;
          s.phase = "CARD_SELECTION"; break;
        case "CARD_SELECTION":
          if (!s.players.every(function (p) { return p.selectedCardId; })) return;
          s.phase = "REVEAL"; break;
        case "REVEAL": reveal(s); break;
        case "GROUP_BY_BAR": s.currentBarIndex = -1; s.phase = "BAR_RESOLUTION"; break;
        case "BAR_RESOLUTION":
          if (resolveNextBar(s) === "WAIT") return;
          break;
        case "PROPOSAL": case "PROPOSAL_RESPONSE": return;
        case "ROUND_CLEANUP": roundCleanup(s); break;
        case "GAME_END_CHECK": s.phase = s.finalRound ? "FINAL_SCORE" : "ROUND_START"; break;   // RULE-028
        case "FINAL_SCORE": finalScore(s); break;
        case "GAME_OVER": return;
        default: throw stateErr("cannot advance from phase " + s.phase);
      }
    }
    throw stateErr("advance loop did not terminate");
  }

  function roundStart(s) {
    s.round++;
    s.playedCards = [];
    s.extraMoneyCard = null;
    s.activeNegotiation = null; s.activeDuel = null;
    s.roundStartMoney = moneyMap(s);
    emit(s, "ROUND_STARTED", { croupierId: s.croupierId });
    s.phase = "DEAL_TO_FIVE";
  }

  function dealToFive(s) {   // RULE-006, RULE-032: the Croupier deals clockwise
    var start = getPlayer(s, s.croupierId).seatIndex, drawn = {};
    for (var k = 0; k < s.playerCount; k++) {
      var p = s.players[(start + k) % s.playerCount];
      drawn[p.id] = 0;
      while (p.hand.length < HAND_SIZE) { p.hand.push(drawCard(s)); drawn[p.id]++; }
    }
    emit(s, "HAND_FILLED", { drawn: drawn });
    startMoneyDistribution(s);
  }

  function placeMoney(s, moneyCard, barId, extra) {
    getBar(s, barId).money += moneyCard.value;
    emit(s, "MONEY_PLACED", { barId: barId, value: moneyCard.value, cardId: moneyCard.id, extra: !!extra });
  }

  // RULE-008 / RULE-030 / RULE-025: existing bar money is never reset.
  // ASSUMPTION-END: in the final round fewer cards may remain; they go left to right with no free placement
  // unless the full set (bars + 1) is available.
  function startMoneyDistribution(s) {
    var bars = activeBars(s);
    s.finalRound = s.moneyDeck.length <= s.perRound;      // RULE-028
    if (s.finalRound) emit(s, "FINAL_ROUND_ANNOUNCED", { moneyCardsLeft: s.moneyDeck.length });
    var count = Math.min(s.perRound, s.moneyDeck.length), drawn = [];
    for (var i = 0; i < count; i++) drawn.push(s.moneyDeck.pop());
    var normal = Math.min(count, bars.length);
    for (var j = 0; j < normal; j++) placeMoney(s, drawn[j], bars[j].id, false);
    s.extraMoneyCard = count > bars.length ? drawn[count - 1] : null;
    s.phase = "MONEY_DISTRIBUTION";
  }

  function reveal(s) {   // RULE-010
    s.playedCards = s.players.map(function (p) {
      var c = s.cards[p.selectedCardId];
      p.hand.splice(p.hand.indexOf(c.id), 1);
      p.selectedCardId = null;
      return { cardId: c.id, playerId: p.id, barId: c.barId, type: c.type, dieSymbol: c.dieSymbol };
    });
    emit(s, "CARDS_REVEALED", { cards: clone(s.playedCards) });
    s.phase = "GROUP_BY_BAR";
  }

  function resolveNextBar(s) {
    var bars = activeBars(s);
    for (var i = s.currentBarIndex + 1; i < bars.length; i++) {
      var cards = playedByBar(s, bars[i].id);
      if (!cards.length) continue;
      s.currentBarIndex = i; s.currentBarId = bars[i].id;
      return resolveBar(s, bars[i], cards);
    }
    s.currentBarIndex = null; s.currentBarId = null;
    s.phase = "ROUND_CLEANUP";
    return "DONE";
  }

  function awardMoney(s, playerId, amount, barId) {   // docs/04 §17: the only way money moves from a bar to a player
    var bar = getBar(s, barId);
    if (!(amount >= 0) || amount % 1 !== 0) throw dataErr("invalid amount " + amount);
    if (amount > bar.money) throw stateErr("bar " + barId + " holds " + bar.money + ", cannot pay " + amount);
    if (amount === 0) return;
    bar.money -= amount;
    getPlayer(s, playerId).money += amount;
    emit(s, "MONEY_AWARDED", { playerId: playerId, amount: amount, barId: barId });
  }

  function resolveBar(s, bar, cards) {
    var zs = cards.filter(function (c) { return c.type === "ZOCKER"; });
    var rs = cards.filter(function (c) { return c.type === "RAZZIA"; });
    var ids = function (a) { return a.map(function (c) { return c.playerId; }); };

    if (bar.money === 0) {   // ASSUMPTION-EMPTY: nothing to claim, nothing to negotiate
      emit(s, "BAR_RESOLVED", { barId: bar.id, kind: "EMPTY", zockers: ids(zs), razzias: ids(rs) });
      return "CONTINUE";
    }
    if (!zs.length && rs.length) {   // RULE-014
      emit(s, "BAR_RESOLVED", { barId: bar.id, kind: "RAZZIA_NO_ZOCKER", money: bar.money, razzias: ids(rs) });
      return "CONTINUE";
    }
    if (zs.length === 1 && !rs.length) {   // RULE-011
      emit(s, "BAR_RESOLVED", { barId: bar.id, kind: "SINGLE_ZOCKER", money: bar.money, winnerId: zs[0].playerId });
      awardMoney(s, zs[0].playerId, bar.money, bar.id);
      return "CONTINUE";
    }
    var claimants, kind;
    if (rs.length && zs.length) {    // RULE-013, RULE-015
      kind = "RAZZIA"; claimants = rs;
      emit(s, "RAZZIA_ACTIVATED", { barId: bar.id, razzias: ids(rs), shutOut: ids(zs), money: bar.money });
    } else { kind = "ZOCKER"; claimants = zs; }    // RULE-012

    if (claimants.length === 1) {
      // ASSUMPTION-SOLE-RAZZIA: a single Razzia player is the only claimant and takes the whole bar.
      emit(s, "BAR_RESOLVED", { barId: bar.id, kind: "RAZZIA_SOLE_CLAIMANT", money: bar.money, winnerId: claimants[0].playerId });
      awardMoney(s, claimants[0].playerId, bar.money, bar.id);
      return "CONTINUE";
    }
    // RULE-021 (resolved from the rule text supplied by the project owner, 2026-10-07): with four or more claimants the proposal/response
    // step is unchanged; duels are handled as a tournament in resolveNegotiation. See docs/08_ASSUMPTIONS.md (ASSUMPTION-021-*).
    var ordered = orderByPriority(s, claimants);
    var symbols = {};
    ordered.forEach(function (c) { symbols[c.playerId] = c.dieSymbol; });
    s.activeNegotiation = {
      id: "N" + s.round + "-" + bar.id, barId: bar.id, kind: kind, claimantIds: ids(ordered), symbols: symbols,
      proposerId: ordered[0].playerId, prize: bar.money, proposal: null, responses: {}
    };
    emit(s, "NEGOTIATION_STARTED", { barId: bar.id, kind: kind, claimantIds: ids(ordered), symbols: symbols, proposerId: ordered[0].playerId, prize: bar.money });
    s.phase = "PROPOSAL";
    return "WAIT";
  }

  /* ---------------- actions ---------------- */

  function placeExtraMoney(s, a) {
    if (s.phase !== "MONEY_DISTRIBUTION" || !s.extraMoneyCard) throw stateErr("no extra money card to place");
    if (a.playerId !== s.croupierId) throw ruleErr("RULE-008: only the Croupier places the extra money card");
    var bar = getBar(s, a.barId);
    if (!bar.active) throw ruleErr("RULE-030: bar " + a.barId + " is not active");
    placeMoney(s, s.extraMoneyCard, bar.id, true);
    s.extraMoneyCard = null;
  }

  function selectCard(s, a) {
    if (s.phase !== "CARD_SELECTION") throw stateErr("cards cannot be selected in phase " + s.phase);
    var p = getPlayer(s, a.playerId);
    if (p.selectedCardId) throw stateErr("player " + p.id + " already selected a card");
    if (p.hand.indexOf(a.cardId) < 0) throw ruleErr("RULE-009: card " + a.cardId + " is not in the hand of " + p.id);
    p.selectedCardId = a.cardId;
    emit(s, "CARD_SELECTED", { playerId: p.id });   // never carries the card id: hidden information
  }

  function validateProposal(s, neg, allocations) {
    if (!allocations || typeof allocations !== "object") throw dataErr("proposal needs allocations");
    var total = 0;
    Object.keys(allocations).forEach(function (pid) {
      if (neg.claimantIds.indexOf(pid) < 0) throw ruleErr("proposal pays " + pid + " who is not a claimant");
      var v = allocations[pid];
      if (!(v >= 0) || v % 1 !== 0) throw ruleErr("proposal amounts must be non-negative whole numbers");
      if (v % MONEY_STEP !== 0) throw ruleErr("ASSUMPTION-STEP: amounts must be multiples of " + MONEY_STEP);
      total += v;
    });
    // ASSUMPTION-019: RULE-019 allows paying from already-won money, 03_GAME_FLOW §15 caps the total at the prize.
    // The stricter reading (total == prize) is used until the conflict is resolved.
    if (total !== neg.prize) throw ruleErr("RULE-019/ASSUMPTION-019: proposal must distribute exactly the prize (" + neg.prize + "), got " + total);
  }

  function makeProposal(s, a) {
    var neg = s.activeNegotiation;
    if (s.phase !== "PROPOSAL" || !neg) throw stateErr("no proposal is expected");
    if (a.playerId !== neg.proposerId) throw ruleErr("RULE-012: only " + neg.proposerId + " may propose");
    validateProposal(s, neg, a.allocations);
    var proposal = {};
    neg.claimantIds.forEach(function (pid) { proposal[pid] = a.allocations[pid] || 0; });
    neg.proposal = proposal;
    neg.claimantIds.forEach(function (pid) { if (pid !== neg.proposerId) neg.responses[pid] = "PENDING"; });
    emit(s, "PROPOSAL_MADE", { barId: neg.barId, proposerId: neg.proposerId, proposal: clone(proposal), prize: neg.prize });
    s.phase = "PROPOSAL_RESPONSE";
  }

  function respond(s, a) {
    var neg = s.activeNegotiation;
    if (s.phase !== "PROPOSAL_RESPONSE" || !neg) throw stateErr("no response is expected");
    if (neg.responses[a.playerId] !== "PENDING") throw ruleErr("player " + a.playerId + " has no pending response");
    if (a.response !== "ACCEPT" && a.response !== "DUEL") throw dataErr("response must be ACCEPT or DUEL");
    neg.responses[a.playerId] = a.response;
    if (a.response === "ACCEPT") emit(s, "PROPOSAL_ACCEPTED", { barId: neg.barId, playerId: a.playerId });
    else emit(s, "DUEL_CALLED", { barId: neg.barId, playerId: a.playerId });
    var pending = Object.keys(neg.responses).filter(function (pid) { return neg.responses[pid] === "PENDING"; });
    if (!pending.length) resolveNegotiation(s);
  }

  function runDuel(s, aId, bId, challengerId, barId) {   // RULE-018
    var cardA = playedOf(s, aId, barId), cardB = playedOf(s, bId, barId);
    s.activeDuel = { id: "D" + s.round + "-" + barId + "-" + s.seq, barId: barId, playerA: aId, playerB: bId, cardA: cardA.cardId, cardB: cardB.cardId, challengerId: challengerId };
    emit(s, "DUEL_STARTED", { barId: barId, playerA: aId, playerB: bId, symbolA: cardA.dieSymbol, symbolB: cardB.dieSymbol, cardA: cardA, cardB: cardB, challengerId: challengerId });
    var rollA = rollDie(s), rollB = rollDie(s);
    var scoreA = cardA.dieSymbol + rollA, scoreB = cardB.dieSymbol + rollB;
    s.activeDuel.rollA = rollA; s.activeDuel.rollB = rollB; s.activeDuel.scoreA = scoreA; s.activeDuel.scoreB = scoreB;
    emit(s, "DICE_ROLLED", { barId: barId, rollA: rollA, rollB: rollB });
    var winner = scoreA > scoreB ? aId : scoreB > scoreA ? bId : challengerId;
    s.activeDuel.winnerId = winner;
    emit(s, "DUEL_RESOLVED", {
      barId: barId, playerA: aId, playerB: bId, rollA: rollA, rollB: rollB, scoreA: scoreA, scoreB: scoreB,
      tie: scoreA === scoreB, challengerId: challengerId, winnerId: winner
    });
    s.activeDuel = null;
    return winner;
  }

  function resolveNegotiation(s) {   // RULE-017, RULE-020
    var neg = s.activeNegotiation, bar = getBar(s, neg.barId), prize = neg.prize;
    var proposer = neg.proposerId;
    var responders = neg.claimantIds.filter(function (pid) { return pid !== proposer; });
    var rejecters = responders.filter(function (pid) { return neg.responses[pid] === "DUEL"; });
    var accepters = responders.filter(function (pid) { return neg.responses[pid] === "ACCEPT"; });
    var outcome;

    function payAll() {
      neg.claimantIds.forEach(function (pid) { awardMoney(s, pid, neg.proposal[pid], bar.id); });
    }

    if (!rejecters.length) {
      outcome = "DEAL";
      payAll();
    } else if (neg.claimantIds.length === 2) {
      outcome = "DUEL";
      var w2 = runDuel(s, proposer, rejecters[0], rejecters[0], bar.id);
      awardMoney(s, w2, prize, bar.id);
    } else if (neg.claimantIds.length >= 4) {
      // RULE-021: accepters take their offered amount and leave. The proposer is the first "current winner"; the rejecters challenge in
      // order of lowest die symbol first. Each duel is called by the challenger (ties go to the challenger). The survivor takes what is left.
      outcome = rejecters.length === 1 ? "ONE_REJECTS" : "TOURNAMENT";
      accepters.forEach(function (pid) { awardMoney(s, pid, neg.proposal[pid], bar.id); });
      // ASSUMPTION-021-ORDER: equal symbols among challengers are ordered by the same priority list reversed (the one sitting closer to the Croupier challenges first).
      var challengers = neg.claimantIds.filter(function (pid) { return rejecters.indexOf(pid) >= 0; }).reverse();
      var current = proposer;
      challengers.forEach(function (pid) { current = runDuel(s, current, pid, pid, bar.id); });
      awardMoney(s, current, bar.money, bar.id);
    } else if (rejecters.length === 1) {
      outcome = "ONE_REJECTS";
      awardMoney(s, accepters[0], neg.proposal[accepters[0]], bar.id);
      var w3 = runDuel(s, proposer, rejecters[0], rejecters[0], bar.id);
      awardMoney(s, w3, bar.money, bar.id);   // the remaining money of the contested bar
    } else {
      outcome = "BOTH_REJECT";
      var order = neg.claimantIds;    // priority order: highest first, lowest last
      var highest = order[0], middle = order[1], lowest = order[2];
      // ASSUMPTION-CHALLENGER: duel 1 is called by the lowest claimant, duel 2 by the remaining third claimant.
      var first = runDuel(s, highest, lowest, lowest, bar.id);
      var second = runDuel(s, first, middle, middle, bar.id);
      awardMoney(s, second, prize, bar.id);
    }
    emit(s, "BAR_RESOLVED", { barId: bar.id, kind: neg.kind, outcome: outcome, money: prize, proposerId: proposer });
    s.activeNegotiation = null;
    s.phase = "BAR_RESOLUTION";
    if (bar.money !== 0) throw stateErr("bar " + bar.id + " still holds " + bar.money + " after resolution");
  }

  function roundCleanup(s) {   // RULE-026, RULE-007
    s.playedCards.forEach(function (p) { s.discardPile.push(p.cardId); });
    s.playedCards = [];
    s.players.forEach(function (p) { p.selectedCardId = null; });
    s.activeNegotiation = null; s.activeDuel = null;
    var money = moneyMap(s), gained = {};
    s.players.forEach(function (p) { gained[p.id] = p.money - s.roundStartMoney[p.id]; });
    var next = s.players[(getPlayer(s, s.croupierId).seatIndex + 1) % s.playerCount].id;
    emit(s, "ROUND_ENDED", { money: money, gained: gained, nextCroupierId: next, finalRound: s.finalRound });
    s.croupierId = next;
    s.phase = "GAME_END_CHECK";
  }

  function finalScore(s) {   // RULE-001, RULE-028
    var ranking = s.players.map(function (p) { return { playerId: p.id, money: p.money }; })
      .sort(function (a, b) { return b.money - a.money; });
    var best = ranking[0].money;
    s.winnerIds = ranking.filter(function (r) { return r.money === best; }).map(function (r) { return r.playerId; });
    // ASSUMPTION-TIE: the docs give no tie-break for the final total; ties are reported as shared wins.
    s.winnerId = s.winnerIds.length === 1 ? s.winnerIds[0] : null;
    emit(s, "GAME_ENDED", { ranking: ranking, winnerIds: s.winnerIds.slice() });
    s.phase = "GAME_OVER";
  }

  /* ---------------- public API ---------------- */

  // Mutating variant (used by simulations). Returns the events produced by this action.
  function reduceInPlace(s, a) {
    var before = s.events.length;
    switch (a && a.type) {
      case "PLACE_EXTRA_MONEY": placeExtraMoney(s, a); break;
      case "SELECT_CARD": selectCard(s, a); break;
      case "MAKE_PROPOSAL": makeProposal(s, a); break;
      case "RESPOND": respond(s, a); break;
      default: throw stateErr("unknown action " + (a && a.type));
    }
    advance(s);
    return s.events.slice(before);
  }

  // Immutable variant: never touches the input state.
  function dispatch(state, a) {
    var s = clone(state);
    var events = reduceInPlace(s, a);
    return { state: s, events: events };
  }

  function getPendingInput(s) {
    if (s.phase === "MONEY_DISTRIBUTION" && s.extraMoneyCard) return { type: "PLACE_EXTRA_MONEY", playerId: s.croupierId };
    if (s.phase === "CARD_SELECTION") {
      var waiting = s.players.filter(function (p) { return !p.selectedCardId; }).map(function (p) { return p.id; });
      return waiting.length ? { type: "SELECT_CARD", playerIds: waiting } : null;
    }
    if (s.phase === "PROPOSAL") return { type: "MAKE_PROPOSAL", playerId: s.activeNegotiation.proposerId };
    if (s.phase === "PROPOSAL_RESPONSE") {
      var neg = s.activeNegotiation;
      return { type: "RESPOND", playerIds: Object.keys(neg.responses).filter(function (pid) { return neg.responses[pid] === "PENDING"; }) };
    }
    return null;
  }

  // What a player may legitimately know (docs/06 §9): own hand, revealed cards, discards, bar money, public money,
  // public actions. Never the draw pile order, other hands, or other players' hidden selections or responses.
  function getPublicView(s, pid) {
    var me = getPlayer(s, pid);
    var revealed = s.phase !== "CARD_SELECTION" && s.phase !== "MONEY_DISTRIBUTION";
    var unseen = { ZOCKER: 0, RAZZIA: 0 };
    var known = {};
    me.hand.forEach(function (id) { known[id] = 1; });
    s.discardPile.forEach(function (id) { known[id] = 1; });
    if (revealed) s.playedCards.forEach(function (p) { known[p.cardId] = 1; });
    Object.keys(s.cards).forEach(function (id) { if (!known[id]) unseen[s.cards[id].type]++; });
    var neg = s.activeNegotiation;
    return {
      version: s.version, phase: s.phase, round: s.round, playerCount: s.playerCount, finalRound: s.finalRound,
      croupierId: s.croupierId, you: pid, perRound: s.perRound,
      yourProfile: { aiDifficulty: me.aiDifficulty, personality: me.personality },
      hand: me.hand.map(function (id) { return clone(s.cards[id]); }),
      players: s.players.map(function (p) {
        return { id: p.id, name: p.name, isHuman: p.isHuman, seatIndex: p.seatIndex, money: p.money, handSize: p.hand.length, hasSelected: !!p.selectedCardId };
      }),
      bars: s.bars.map(function (b) { return { id: b.id, name: b.name, order: b.order, active: b.active, money: b.money }; }),
      discardPile: s.discardPile.map(function (id) { return clone(s.cards[id]); }),
      playedCards: revealed ? clone(s.playedCards) : [],
      extraMoneyCard: s.extraMoneyCard ? clone(s.extraMoneyCard) : null,
      moneyDeckCount: s.moneyDeck.length,
      unseen: unseen,
      negotiation: neg ? {
        id: neg.id, barId: neg.barId, kind: neg.kind, claimantIds: neg.claimantIds.slice(), symbols: clone(neg.symbols),
        proposerId: neg.proposerId, prize: neg.prize, proposal: neg.proposal ? clone(neg.proposal) : null,
        myResponse: neg.responses[pid] || null
      } : null
    };
  }

  // INV-001..005 (docs/04 §14). Returns a list of violations (empty = ok).
  function checkInvariants(s) {
    var errs = [], seen = {};
    function see(id, where) { if (seen[id]) errs.push("INV-001 card " + id + " in " + seen[id] + " and " + where); else seen[id] = where; }
    s.players.forEach(function (p) { p.hand.forEach(function (id) { see(id, "hand " + p.id); }); });
    s.drawPile.forEach(function (id) { see(id, "draw"); });
    s.discardPile.forEach(function (id) { see(id, "discard"); });
    s.playedCards.forEach(function (p) { see(p.cardId, "played"); });
    Object.keys(s.cards).forEach(function (id) { if (!seen[id]) errs.push("INV-001 card " + id + " is nowhere"); });
    var total = s.moneyDeck.reduce(function (a, m) { return a + m.value; }, 0) +
      s.bars.reduce(function (a, b) { return a + b.money; }, 0) +
      s.players.reduce(function (a, p) { return a + p.money; }, 0) +
      (s.extraMoneyCard ? s.extraMoneyCard.value : 0);
    if (total !== s.totalMoney) errs.push("INV-002 money " + total + " != " + s.totalMoney);
    if (s.phase === "CARD_SELECTION") {
      s.players.forEach(function (p) { if (p.hand.length !== HAND_SIZE) errs.push("INV-003 hand size " + p.hand.length + " for " + p.id); });
    }
    s.players.forEach(function (p) {
      if (p.selectedCardId && p.hand.indexOf(p.selectedCardId) < 0) errs.push("INV-004 selection of " + p.id + " not in hand");
    });
    s.bars.forEach(function (b) { if (!b.active && b.money !== 0) errs.push("INV-005 inactive bar " + b.id + " holds money"); });
    s.playedCards.forEach(function (p) { if (!getBar(s, p.barId).active) errs.push("INV-005 played card on inactive bar " + p.barId); });
    return errs;
  }

  function serializeGame(s) { return JSON.stringify({ version: VERSION, gameState: s }); }
  function loadGame(json) {
    var o = typeof json === "string" ? JSON.parse(json) : json;
    if (!o || o.version !== VERSION) throw new GameError("SAVE_ERROR", "unsupported save version " + (o && o.version));
    return o.gameState;
  }

  var api = {
    VERSION: VERSION, HAND_SIZE: HAND_SIZE, MONEY_STEP: MONEY_STEP, BAR_DEFS: BAR_DEFS,
    ORIGINAL_MONEY_COUNTS: ORIGINAL_MONEY_COUNTS, GameError: GameError, UnsupportedRuleError: UnsupportedRuleError,
    createOriginalCardSet: createOriginalCardSet, createSetupFor3Players: createSetupFor3Players,
    createSetupFor4To6Players: createSetupFor4To6Players, createSetupFor7To8Players: createSetupFor7To8Players,
    createGame: createGame, dispatch: dispatch, reduceInPlace: reduceInPlace, getPendingInput: getPendingInput,
    getPublicView: getPublicView, checkInvariants: checkInvariants, serializeGame: serializeGame, loadGame: loadGame,
    duelWinProbability: duelWinProbability, seatDistance: seatDistance, orderByPriority: orderByPriority, clone: clone
  };
  export default api;

