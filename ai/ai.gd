extends RefCounted
## Razzia Mobile AI (docs/06_AI_DESIGN.md), GDScript port of tools/js/ai.js.
## Rule-based, deterministic given its RNG, and limited to the public view (Engine.get_public_view).
## Levels: EASY, NORMAL and HARD (Phase 13b; HARD = no noise, sharper opponent model, risk-seeking - see DIFFICULTY below).
## All weights live in DIFFICULTY / PERSONALITY, not in the logic.
##
## PORTING NOTE: every division below is a float division on purpose (GDScript int / int truncates).
## The `rng` argument is a Dictionary {"rngState": int}; Rng.rng_float(rng) is the JS closure's `rng()`.

const Eng = preload("res://engine/engine.gd")
const Rng = preload("res://engine/rng.gd")

const DIFFICULTY := {
	"EASY": {"alpha": 0.4, "noise": 0.45, "useUnseen": false, "accept": 0.70, "greed": 0.25, "propNoise": 0.25},
	# HARD (Phase 13b): no noise, sharper opponent model, exact accept threshold, and risk-seeking (the game rewards finishing first, not the average).
	# Measured by tools/ai_sim.gd (4 players, 1 HARD vs 3 NORMAL, 2500 games): HARD wins ~31%, NORMAL ~23% (fair share 25%).
	"HARD": {"alpha": 2.0, "noise": 0.0, "useUnseen": true, "accept": 1.0, "greed": 0.12, "propNoise": 0.0, "riskMul": 0.0, "riskAdd": -0.3},
	"NORMAL": {"alpha": 1.4, "noise": 0.10, "useUnseen": true, "accept": 0.95, "greed": 0.12, "propNoise": 0.05},
}
const PERSONALITY := {
	"CONSERVATIVE": {"risk": 0.30, "accept": -0.12, "greed": -0.04, "alphaMul": 1.0},
	"AGGRESSIVE": {"risk": -0.10, "accept": 0.15, "greed": 0.06, "alphaMul": 1.0},
	"OPPORTUNIST": {"risk": 0.10, "accept": 0.0, "greed": 0.0, "alphaMul": 1.0},
}
const HOLD_COST := 0.01    # scarce high symbols are worth keeping a little


static func new_rng(seed_value: int) -> Dictionary:
	return {"rngState": seed_value & 0xFFFFFFFF}


static func _cfg_for(view: Dictionary) -> Dictionary:
	var me: Dictionary = view.get("yourProfile", {})
	var dname = me.get("aiDifficulty", null)
	var pname = me.get("personality", null)
	var d: Dictionary = DIFFICULTY.get(dname if dname else "NORMAL", DIFFICULTY["NORMAL"])
	var per: Dictionary = PERSONALITY.get(pname if pname else "CONSERVATIVE", PERSONALITY["CONSERVATIVE"])
	return {
		"alpha": d["alpha"] * per["alphaMul"], "noise": d["noise"], "useUnseen": d["useUnseen"], "risk": per["risk"] * float(d.get("riskMul", 1.0)) + float(d.get("riskAdd", 0.0)),
		"accept": d["accept"] + per["accept"], "greed": maxf(0.0, d["greed"] + per["greed"]), "propNoise": d["propNoise"],
	}


static func _binom(n: int, k: int) -> float:
	var r := 1.0
	for i in range(1, k + 1):
		r = r * float(n - k + i) / float(i)
	return r


static func _share_frac(sym: int, k: int) -> float:
	return clampf(1.0 / float(k) + 0.045 * (float(sym) - 3.5), 0.08, 0.8)


## Probability that one opponent plays at a bar, from public bar money only.
static func _bar_probabilities(bars: Array, cfg: Dictionary) -> Dictionary:
	var w := {}
	var total := 0.0
	for b in bars:
		w[b["id"]] = pow(float(b["money"]) / 1000.0 + 3.0, cfg["alpha"])
		total += w[b["id"]]
	var p := {}
	for b in bars:
		p[b["id"]] = w[b["id"]] / total
	return p


static func _zocker_share(view: Dictionary, cfg: Dictionary) -> float:
	if not cfg["useUnseen"]:
		return 2.0 / 3.0
	var z: int = view["unseen"]["ZOCKER"]
	var r: int = view["unseen"]["RAZZIA"]
	return float(z) / float(z + r) if z + r > 0 else 2.0 / 3.0


## Expected value and spread of playing `card` against the n-1 hidden opponent cards.
static func _evaluate_card(card: Dictionary, money_k: float, p: float, q: float, n_others: int) -> Dictionary:
	var ev := 0.0
	var ev2 := 0.0
	for a in range(n_others + 1):
		var pa := _binom(n_others, a) * pow(p, a) * pow(1.0 - p, n_others - a)
		for zc in range(a + 1):
			var rc := a - zc
			var pr := pa * _binom(a, zc) * pow(q, zc) * pow(1.0 - q, rc)
			var pay: float
			if card["type"] == "ZOCKER":
				if rc > 0:
					pay = 0.0
				elif zc == 0:
					pay = money_k
				else:
					pay = money_k * _share_frac(card["dieSymbol"], zc + 1) * 0.95
			else:
				if zc == 0:
					pay = 0.0
				elif rc == 0:
					pay = money_k
				else:
					pay = money_k * _share_frac(card["dieSymbol"], rc + 1) * 0.95
			ev += pr * pay
			ev2 += pr * pay * pay
	return {"ev": ev, "sd": sqrt(maxf(0.0, ev2 - ev * ev))}


static func _card_values(view: Dictionary, cfg: Dictionary, extra_bar_id, extra_value: int) -> Array:
	var bars := []
	for b in view["bars"]:
		if b["active"]:
			bars.append({"id": b["id"], "money": int(b["money"]) + (extra_value if b["id"] == extra_bar_id else 0)})
	var pb := _bar_probabilities(bars, cfg)
	var q := _zocker_share(view, cfg)
	var n_others: int = int(view["playerCount"]) - 1
	var money := {}
	var avg := 0.0
	for b in bars:
		money[b["id"]] = float(b["money"]) / 1000.0
		avg += float(b["money"]) / 1000.0
	avg = avg / float(bars.size())
	var out := []
	for card in view["hand"]:
		var r := _evaluate_card(card, money[card["barId"]], pb[card["barId"]], q, n_others)
		out.append({"card": card, "value": r["ev"] - cfg["risk"] * r["sd"] - HOLD_COST * float(card["dieSymbol"]) * avg, "scale": avg})
	return out


## NOTE: consumes one rng() per entry even when noise is 0 (the JS does the same; the stream must stay aligned).
static func _pick_best(list: Array, noise: float, rng: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_v := -INF
	for x in list:
		var v: float = x["value"] + (Rng.rng_float(rng) - 0.5) * 2.0 * noise * maxf(1.0, x["scale"])
		if v > best_v:
			best_v = v
			best = x
	return best


static func choose_card(view: Dictionary, rng: Dictionary) -> String:
	var cfg := _cfg_for(view)
	return _pick_best(_card_values(view, cfg, null, 0), cfg["noise"], rng)["card"]["id"]


## The Croupier places the extra money card before choosing a card (docs/03 §9).
static func choose_extra_bar(view: Dictionary, rng: Dictionary) -> String:
	var cfg := _cfg_for(view)
	var best_id := ""
	var best_v := -INF
	for b in view["bars"]:
		if not b["active"]:
			continue
		var top := _pick_best(_card_values(view, cfg, b["id"], int(view["extraMoneyCard"]["value"])), 0.0, rng)
		var v: float = top["value"] + (Rng.rng_float(rng) - 0.5) * 2.0 * cfg["noise"] * maxf(1.0, top["scale"])
		if v > best_v:
			best_v = v
			best_id = b["id"]
	return best_id


static func _round_to_step(x: float) -> int:
	return int(floor(x / float(Eng.MONEY_STEP) + 0.5)) * Eng.MONEY_STEP    # JS Math.round: half up


## Always returns a proposal the engine accepts: whole steps summing exactly to the prize.
static func make_proposal(view: Dictionary, rng: Dictionary) -> Dictionary:
	var neg: Dictionary = view["negotiation"]
	var cfg := _cfg_for(view)
	var me: String = view["you"]
	var my_sym: int = neg["symbols"][me]
	var others := []
	for id in neg["claimantIds"]:
		if id != me:
			others.append(id)
	var n_c: int = neg["claimantIds"].size()
	var scale: float
	if n_c == 2:
		scale = 1.0
	elif n_c == 3:
		scale = 0.8
	else:
		scale = maxf(0.35, 2.4 / float(n_c))    # more claimants = a duel is worth less to each of them
	var prize: int = neg["prize"]
	var offers := {}
	var total := 0
	for o in others:
		var p_win := Eng.duel_win_probability(neg["symbols"][o], my_sym, true)
		var raw: float = float(prize) * p_win * (1.0 - cfg["greed"]) * scale * (1.0 + (Rng.rng_float(rng) - 0.5) * 2.0 * cfg["propNoise"])
		offers[o] = maxi(0, _round_to_step(raw))
		total += offers[o]
	var cap := _round_to_step(float(prize) * 0.9)
	while total > cap:
		var big: String = others[0]    # first maximum, like a stable descending sort
		for o in others:
			if offers[o] > offers[big]:
				big = o
		if offers[big] <= 0:
			break
		offers[big] -= Eng.MONEY_STEP
		total -= Eng.MONEY_STEP
	var alloc := {}
	alloc[me] = prize - total
	for o in others:
		alloc[o] = offers[o]
	return alloc


## "DUEL" is the rule action; the AI calls it when the expected duel value beats the offer.
static func respond_to_proposal(view: Dictionary, rng: Dictionary) -> String:
	var neg: Dictionary = view["negotiation"]
	var cfg := _cfg_for(view)
	var me: String = view["you"]
	var offer: int = neg["proposal"][me]
	var prize: int = neg["prize"]
	for id in neg["claimantIds"]:
		if id != me and id != neg["proposerId"]:
			prize -= int(neg["proposal"][id])    # assume the others accept
	var duel_ev := Eng.duel_win_probability(neg["symbols"][me], neg["symbols"][neg["proposerId"]], true) * float(prize)
	var jitter := 0.0
	if cfg["noise"] > 0.3:
		jitter = (Rng.rng_float(rng) - 0.5) * 0.3 * float(neg["prize"])
	return "ACCEPT" if float(offer) + jitter >= duel_ev * cfg["accept"] else "DUEL"
