extends RefCounted
## The tutorial's fixed table: one seed, three rounds, each staging one idea.
##   Round 1  a lone gambler takes the whole venue           (me: a ZOCKER alone on venue X)
##   Round 2  two gamblers on one venue: offer, refusal, duel (me + Vito on venue Y, my eye is higher so I offer first)
##   Round 3  I am the dealer (extra card), and a raid       (me: a RAZZIA on venue Z where Mack sits with a ZOCKER)
## The AI players are scripted through MatchController.script_ai; every answer is still checked by the engine rules.
## All choices are computed from the state at the moment of the decision, so the same functions drive the live tutorial
## and the seed check (tools/find_tutorial_seed.gd) and always agree.

const Eng = preload("res://engine/engine.gd")

## Found by tools/find_tutorial_seed.gd: every round stages as planned and I win the round-2 duel.
const SEED := 23
const FIRST_DEALER := "P3"           # P3 deals round 1, P4 round 2, I (P1) deal round 3
const NAMES := ["나", "Vito", "Lola", "Mack"]
const ME := "P1"
const RIVAL := "P2"                  # Vito: the duel in round 2
const RAIDED := "P4"                 # Mack: the gambler my police card shuts out in round 3
const ROUNDS := 3


static func config(seed_v: int = SEED) -> Dictionary:
	var names: Array = NAMES.duplicate()
	names[0] = preload("res://ui/settings.gd").seat_name()       # my own name, if I chose one (the cast stays the same)
	return {"playerCount": 4, "seed": seed_v, "humanPlayerId": ME, "names": names, "firstCroupierId": FIRST_DEALER,
		"tutorial": true}


static func _card(s: Dictionary, cid: String) -> Dictionary:
	return s["cards"][cid]


static func _hand(s: Dictionary, pid: String) -> Array:
	return Eng.get_player(s, pid)["hand"]


## venue the human is meant to play this round (and the card), or {} when the table does not allow the plan
static func human_target(s: Dictionary) -> Dictionary:
	var r := int(s["round"])
	if r == 1:
		var best := {}
		for cid in _hand(s, ME):
			var c := _card(s, cid)
			if c["type"] == "ZOCKER" and (best.is_empty() or int(c["dieSymbol"]) > int(best["dieSymbol"])):
				best = c
		return best
	if r == 2:
		var pair := _duel_pair(s)
		return pair.get("me", {})
	if r == 3:
		var pr := _raid_pair(s)
		return pr.get("me", {})
	return {}


## round 2: my ZOCKER and Vito's ZOCKER on the same venue, my eye higher (I make the offer); the widest gap wins
static func _duel_pair(s: Dictionary) -> Dictionary:
	var out := {}
	for a in _hand(s, ME):
		var ca := _card(s, a)
		if ca["type"] != "ZOCKER":
			continue
		for b in _hand(s, RIVAL):
			var cb := _card(s, b)
			if cb["type"] != "ZOCKER" or cb["barId"] != ca["barId"] or int(cb["dieSymbol"]) >= int(ca["dieSymbol"]):
				continue
			var gap := int(ca["dieSymbol"]) - int(cb["dieSymbol"])
			if out.is_empty() or gap > int(out["gap"]):
				out = {"me": ca, "rival": cb, "gap": gap}
	return out


## round 3: my RAZZIA and Mack's ZOCKER on the same venue
static func _raid_pair(s: Dictionary) -> Dictionary:
	for a in _hand(s, ME):
		var ca := _card(s, a)
		if ca["type"] != "RAZZIA":
			continue
		for b in _hand(s, RAIDED):
			var cb := _card(s, b)
			if cb["type"] == "ZOCKER" and cb["barId"] == ca["barId"]:
				return {"me": ca, "raided": cb}
	return {}


## venues already taken this round by players who chose before `pid` (the controller asks in seat order)
static func _taken(s: Dictionary) -> Dictionary:
	var t := {}
	for p in s["players"]:
		if p["selectedCardId"] != null:
			t[_card(s, p["selectedCardId"])["barId"]] = true
	return t


## A side player: a ZOCKER on a venue nobody else uses this round (they each quietly take their venue)
static func _side_card(s: Dictionary, pid: String, avoid: String) -> Variant:
	var taken := _taken(s)
	taken[avoid] = true
	var fallback = null
	for cid in _hand(s, pid):
		var c := _card(s, cid)
		if taken.has(c["barId"]):
			continue
		if c["type"] == "ZOCKER":
			return cid
		if fallback == null:
			fallback = cid
	if fallback != null:
		return fallback
	for cid in _hand(s, pid):
		if _card(s, cid)["barId"] != avoid:
			return cid
	return null


## MatchController.script_ai
static func decide(s: Dictionary, kind: String, pid: String) -> Variant:
	var r := int(s["round"])
	if r > ROUNDS:
		return null
	match kind:
		"SELECT_CARD":
			var target := human_target(s)
			var bar := str(target.get("barId", ""))
			if r == 2 and pid == RIVAL:
				var pair := _duel_pair(s)
				if not pair.is_empty():
					return pair["rival"]["id"]
			if r == 3 and pid == RAIDED:
				var pr := _raid_pair(s)
				if not pr.is_empty():
					return pr["raided"]["id"]
			return _side_card(s, pid, bar)
		"RESPOND":
			if r == 2 and pid == RIVAL:
				return "DUEL"
			return "ACCEPT"
		"PLACE_EXTRA_MONEY":
			var t := human_target(s)
			if not t.is_empty():
				return t["barId"]          # the dealer's extra card lands where I am about to play: easy to follow
	return null
