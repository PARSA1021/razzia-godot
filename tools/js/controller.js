/* Action layer between UI and engine (docs/07 §8). It asks the AI for its moves using public views only,
 * stops when a human decision is needed, and collects the engine events produced meanwhile.
 */
"use strict";
  import E from "./engine.js";
  import AI from "./ai.js";

  function createController(state, opts) {
    opts = opts || {};
    var seed = (opts.aiSeed !== undefined ? opts.aiSeed : (state.config.seed ^ 0x5bd1e995)) >>> 0;
    var ctrl = { state: state, buffer: [], aiSeed: seed, aiRng: AI.mulberry32(seed) };

    function act(action, who) {
      try {
        var ev = E.reduceInPlace(ctrl.state, action);
        for (var i = 0; i < ev.length; i++) ctrl.buffer.push(ev[i]);
        if (opts.onAction) opts.onAction(ctrl.state, action);
      } catch (e) {
        if (who === "ai" && e instanceof E.GameError) throw new E.GameError("AI_ERROR", "AI produced an invalid action: " + e.message);
        throw e;
      }
    }
    function isHuman(pid) { return ctrl.state.players.filter(function (p) { return p.id === pid; })[0].isHuman; }
    function view(pid) { return E.getPublicView(ctrl.state, pid); }

    // Plays every AI decision until the human must act (or the game is over). Returns the pending human input or null.
    ctrl.run = function () {
      for (var guard = 0; guard < 100000; guard++) {
        var p = E.getPendingInput(ctrl.state);
        if (!p) return null;
        var acted = false;
        if (p.type === "PLACE_EXTRA_MONEY") {
          if (isHuman(p.playerId)) return p;
          act({ type: "PLACE_EXTRA_MONEY", playerId: p.playerId, barId: AI.chooseExtraBar(view(p.playerId), ctrl.aiRng) }, "ai");
          acted = true;
        } else if (p.type === "SELECT_CARD") {
          p.playerIds.forEach(function (pid) {
            if (isHuman(pid)) return;
            act({ type: "SELECT_CARD", playerId: pid, cardId: AI.chooseCard(view(pid), ctrl.aiRng) }, "ai");
            acted = true;
          });
          if (!acted) return p;
        } else if (p.type === "MAKE_PROPOSAL") {
          if (isHuman(p.playerId)) return p;
          act({ type: "MAKE_PROPOSAL", playerId: p.playerId, allocations: AI.makeProposal(view(p.playerId), ctrl.aiRng) }, "ai");
          acted = true;
        } else if (p.type === "RESPOND") {
          // every AI answers from its own view before any later answer exists: responses stay independent
          var ais = p.playerIds.filter(function (pid) { return !isHuman(pid); });
          var answers = ais.map(function (pid) { return { pid: pid, r: AI.respondToProposal(view(pid), ctrl.aiRng) }; });
          answers.forEach(function (x) { act({ type: "RESPOND", playerId: x.pid, response: x.r }, "ai"); acted = true; });
          if (!acted) return p;
        }
        if (!acted) return p;
      }
      throw new E.GameError("STATE_ERROR", "controller loop did not terminate");
    };

    ctrl.act = function (action) { act(action, "human"); return ctrl.run(); };
    ctrl.drainEvents = function () { var b = ctrl.buffer; ctrl.buffer = []; return b; };
    return ctrl;
  }

  var api = { createController: createController };
  export default api;

