extends RefCounted
## Razzia Mobile game engine (GDScript port of tools/js/engine.js).
## Source of truth: docs/02_RULEBOOK.md (RULE-xxx), docs/03_GAME_FLOW.md (states), docs/04_GAME_DATA.md (data).
## Pure rules: no UI, no AI, no nodes. All randomness goes through the seeded RNG stored in state["rngState"].
## Anything the docs leave open is marked ASSUMPTION-xxx and listed in docs/08_ASSUMPTIONS.md.
##
## State is a plain Dictionary with the SAME keys as the JS engine (camelCase), so saves and golden logs are
## interchangeable between the two implementations.
##
## GDScript has no exceptions: public actions return {"ok": bool, "events": Array, "error": Dictionary}.
## Internal broken-invariant situations are appended to state["fatal"] (and push_error'd); tests assert it stays absent.

const Rng = preload("res://engine/rng.gd")
const Util = preload("res://engine/util.gd")
const RelicManager = preload("res://engine/relic_manager.gd")

const VERSION := 1
const HAND_SIZE := 5                 # RULE-006
const MONEY_STEP := 5000             # ASSUMPTION-STEP: proposals use multiples of the smallest money card

const BAR_DEFS := [                  # RULE-004
	{"id": "COLIBRI", "name": "Colibri", "order": 1},
	{"id": "COTTON_CLUB", "name": "Cotton Club", "order": 2},
	{"id": "HAVANA_BAR", "name": "Havana Bar", "order": 3},
	{"id": "THE_JUNGLE", "name": "The Jungle", "order": 4},
	{"id": "LINCOLNS", "name": "Lincoln's", "order": 5},
	{"id": "JAZZ_HOUSE", "name": "Jazz House", "order": 6},
]

# RULE-003 (84 cards). Keys are listed in ascending order on purpose: the JS engine iterates integer keys
# ascending, and the shuffle result depends on that initial order.
const ORIGINAL_MONEY_COUNTS := {
	5000: 15, 10000: 15, 15000: 12, 20000: 12, 25000: 9, 30000: 9, 40000: 6, 50000: 6,
}
const REMOVED_MONEY_3P := {          # RULE-030 step 4
	5000: 2, 10000: 2, 15000: 2, 20000: 2, 25000: 1, 30000: 1, 40000: 1, 50000: 1,
}

# ASSUMPTION-DIST: per bar 8 Zocker cards (1,2,3,3,4,4,5,6) and 4 Razzia cards (2,4,5,6);
# chosen so that RULE-029 removes exactly 18 cards.
const ZOCKER_SYMBOLS := [1, 2, 3, 3, 4, 4, 5, 6]
const RAZZIA_SYMBOLS := [2, 4, 5, 6]

const PERSONALITIES := ["CONSERVATIVE", "AGGRESSIVE", "OPPORTUNIST"]


## ---------------- errors ----------------

static func err(category: String, message: String) -> Dictionary:
	return {"category": category, "message": message}


static func rule_err(m: String) -> Dictionary:
	return err("RULE_ERROR", m)


static func state_err(m: String) -> Dictionary:
	return err("STATE_ERROR", m)


static func data_err(m: String) -> Dictionary:
	return err("DATA_ERROR", m)


static func _fatal(s: Dictionary, msg: String) -> void:
	if not s.has("fatal"):
		s["fatal"] = []
	s["fatal"].append(msg)
	push_error("RAZZIA ENGINE: " + msg)


static func _fail(e: Dictionary) -> Dictionary:
	return {"ok": false, "events": [], "error": e}


## ---------------- RNG helpers ----------------

## Test hook: state["forcedRolls"] = [..] is consumed before the RNG.
static func _roll_die(s: Dictionary) -> int:
	var forced = s.get("forcedRolls", null)
	if forced != null and forced.size() > 0:
		return int(forced.pop_front())
	return Rng.rng_int(s, 1, 6)


## ---------------- data factories (docs/04 §15-16) ----------------

static func create_original_card_set() -> Array:
	var cards := []
	for b in BAR_DEFS:
		for i in range(ZOCKER_SYMBOLS.size()):
			var sym: int = ZOCKER_SYMBOLS[i]
			cards.append({"id": "%s-Z%d-%d" % [b["id"], sym, i], "type": "ZOCKER", "barId": b["id"], "dieSymbol": sym})
		for i in range(RAZZIA_SYMBOLS.size()):
			var sym: int = RAZZIA_SYMBOLS[i]
			cards.append({"id": "%s-R%d-%d" % [b["id"], sym, i], "type": "RAZZIA", "barId": b["id"], "dieSymbol": sym})
	return cards


static func create_money_cards(counts: Dictionary) -> Array:
	var out := []
	for v in counts:
		for k in range(int(counts[v])):
			out.append({"id": "M%d-%d" % [v, k], "value": int(v)})
	return out


static func make_bars(active_count: int) -> Array:
	var bars := []
	for i in range(BAR_DEFS.size()):
		var b: Dictionary = BAR_DEFS[i]
		bars.append({"id": b["id"], "name": b["name"], "order": b["order"], "active": i < active_count, "money": 0})
	return bars


static func create_setup_for_3_players() -> Dictionary:    # RULE-030
	var bars := []
	for b in BAR_DEFS:
		bars.append({
			"id": b["id"], "name": b["name"], "order": b["order"],
			"active": b["id"] != "LINCOLNS" and b["id"] != "JAZZ_HOUSE", "money": 0,
		})
	var cards := []
	for c in create_original_card_set():
		if c["barId"] != "LINCOLNS" and c["barId"] != "JAZZ_HOUSE":
			cards.append(c)
	var counts := {}
	for v in ORIGINAL_MONEY_COUNTS:
		counts[v] = ORIGINAL_MONEY_COUNTS[v] - REMOVED_MONEY_3P[v]
	return {"bars": bars, "cardDeck": cards, "moneyDeck": create_money_cards(counts), "perRound": 5}


static func create_setup_for_4_to_6_players() -> Dictionary:    # RULE-029
	var cards := []
	for c in create_original_card_set():
		if not (c["type"] == "RAZZIA" and c["dieSymbol"] == 5):
			cards.append(c)
	for b in BAR_DEFS:
		for sym in [3, 4]:
			var idx := -1
			for i in range(cards.size()):
				var c: Dictionary = cards[i]
				if c["barId"] == b["id"] and c["type"] == "ZOCKER" and c["dieSymbol"] == sym:
					idx = i
					break
			if idx < 0:
				return {"error": data_err("setup: missing Zocker %d for %s" % [sym, b["id"]])}
			cards.remove_at(idx)
	return {"bars": make_bars(6), "cardDeck": cards, "moneyDeck": create_money_cards(ORIGINAL_MONEY_COUNTS), "perRound": 7}


static func create_setup_for_7_to_8_players() -> Dictionary:    # RULE-031
	return {"bars": make_bars(6), "cardDeck": create_original_card_set(), "moneyDeck": create_money_cards(ORIGINAL_MONEY_COUNTS), "perRound": 7}


static func create_setup(player_count: int) -> Dictionary:
	if player_count == 3:
		return create_setup_for_3_players()
	if player_count >= 4 and player_count <= 6:
		return create_setup_for_4_to_6_players()
	if player_count >= 7 and player_count <= 8:
		return create_setup_for_7_to_8_players()
	return {"error": rule_err("RULE-002: player count must be 3-8")}


## ---------------- helpers ----------------

static func get_player(s: Dictionary, id) -> Dictionary:
	for p in s["players"]:
		if p["id"] == id:
			return p
	_fatal(s, "unknown player %s" % str(id))
	return {}


static func get_bar(s: Dictionary, id) -> Dictionary:
	for b in s["bars"]:
		if b["id"] == id:
			return b
	_fatal(s, "unknown bar %s" % str(id))
	return {}


static func active_bars(s: Dictionary) -> Array:
	var out := []
	for b in s["bars"]:
		if b["active"]:
			out.append(b)
	return out


static func _emit(s: Dictionary, type: String, payload: Dictionary = {}) -> Dictionary:
	s["seq"] = int(s["seq"]) + 1
	var e := {"seq": s["seq"], "type": type, "round": s["round"]}
	for k in payload:
		e[k] = payload[k]
	s["events"].append(e)
	return e


static func money_map(s: Dictionary) -> Dictionary:
	var m := {}
	for p in s["players"]:
		m[p["id"]] = p["money"]
	return m


static func played_by_bar(s: Dictionary, bar_id: String) -> Array:
	var out := []
	for p in s["playedCards"]:
		if p["barId"] == bar_id:
			out.append(p)
	return out


static func played_of(s: Dictionary, pid: String, bar_id: String) -> Dictionary:
	for p in s["playedCards"]:
		if p["playerId"] == pid and p["barId"] == bar_id:
			return p
	_fatal(s, "player %s has no played card at %s" % [pid, bar_id])
	return {}


static func _ids(played: Array) -> Array:
	var out := []
	for c in played:
		out.append(c["playerId"])
	return out


## RULE-022/024: distance in seats from the current Croupier, clockwise. 0 = the Croupier.
static func seat_distance(s: Dictionary, pid: String) -> int:
	var cr: int = get_player(s, s["croupierId"])["seatIndex"]
	var me: int = get_player(s, pid)["seatIndex"]
	return (me - cr + int(s["playerCount"])) % int(s["playerCount"])


## Priority: higher die symbol first; ties: farther from the Croupier first (RULE-022).
## ASSUMPTION-ORDER: "lowest" (RULE-020 both-reject) is the last element of this same ordering.
static func order_by_priority(s: Dictionary, played: Array) -> Array:
	var arr := played.duplicate()
	arr.sort_custom(func(a, b):
		if a["dieSymbol"] != b["dieSymbol"]:
			return a["dieSymbol"] > b["dieSymbol"]
		return seat_distance(s, a["playerId"]) > seat_distance(s, b["playerId"])
	)
	return arr


## Exact win probability for AI and UI hints (docs/06 §14).
static func duel_win_probability(sym_a: int, sym_b: int, a_is_challenger: bool) -> float:
	var win := 0
	for a in range(1, 7):
		for b in range(1, 7):
			var sa := sym_a + a
			var sb := sym_b + b
			if sa > sb or (sa == sb and a_is_challenger):
				win += 1
	return float(win) / 36.0


## ---------------- game creation ----------------

## Returns the new state, or {"error": {...}} when the configuration is invalid.
static func create_game(config: Dictionary = {}) -> Dictionary:
	var raw_n = config.get("playerCount", 3)
	if raw_n is float and raw_n != floor(raw_n):
		return {"error": rule_err("RULE-002: player count must be an integer 3-8")}
	var n := int(raw_n)
	if n < 3 or n > 8:
		return {"error": rule_err("RULE-002: player count must be an integer 3-8")}
	var setup := create_setup(n)
	if setup.has("error"):
		return setup
	var seed_v := int(config.get("seed", 1)) & 0xFFFFFFFF
	if seed_v == 0:
		seed_v = 1
	var human_id = config["humanPlayerId"] if config.has("humanPlayerId") else "P1"    # null = all AI
	var names: Array = config.get("names", [])
	var difficulty: String = str(config.get("aiDifficulty", "NORMAL"))

	var s := {
		"version": VERSION, "phase": "GAME_INIT", "round": 0, "playerCount": n,
		"players": [], "bars": setup["bars"], "cards": {}, "drawPile": [], "discardPile": [], "moneyDeck": [],
		"croupierId": null, "currentBarIndex": null, "currentBarId": null,
		"activeNegotiation": null, "activeDuel": null, "finalRound": false, "winnerId": null, "winnerIds": [],
		"playedCards": [], "extraMoneyCard": null, "roundStartMoney": {}, "totalMoney": 0, "perRound": setup["perRound"],
		"config": {"seed": seed_v, "aiDifficulty": difficulty, "humanPlayerId": human_id},
		"rngState": seed_v, "events": [], "seq": 0,
	}

	var ai_seat := 0
	for i in range(n):
		var id := "P%d" % (i + 1)
		var is_human: bool = (id == human_id)
		var nm: String
		if i < names.size() and str(names[i]) != "":
			nm = str(names[i])
		else:
			nm = "나" if is_human else "AI %d" % (i + 1)
		var p := {
			"id": id, "name": nm, "isHuman": is_human, "seatIndex": i, "money": 0, "hand": [], "selectedCardId": null,
		}
		if not is_human:
			p["aiDifficulty"] = difficulty
			p["personality"] = PERSONALITIES[ai_seat % PERSONALITIES.size()]
			ai_seat += 1
		s["players"].append(p)

	var ids := []
	for c in setup["cardDeck"]:
		s["cards"][c["id"]] = c
		ids.append(c["id"])
	s["drawPile"] = Rng.shuffle(s, ids)
	s["moneyDeck"] = Rng.shuffle(s, setup["moneyDeck"])
	var total := 0
	for m in s["moneyDeck"]:
		total += int(m["value"])
	s["totalMoney"] = total

	s["phase"] = "SETUP"
	_emit(s, "GAME_STARTED", {"playerCount": n, "seed": seed_v, "totalMoney": total})
	for p in s["players"]:
		while p["hand"].size() < HAND_SIZE:
			p["hand"].append(_draw_card(s))
	var first = config.get("firstCroupierId", null)
	if first != null and str(first) != "":
		s["croupierId"] = first
	else:    # RULE-007: the "coolest gambler" is chosen at random
		s["croupierId"] = s["players"][Rng.rng_int(s, 0, n - 1)]["id"]
	if config.has("relics"):
		RelicManager.init_game_relics(s, config["relics"], str(human_id) if human_id != null else "P1")
	s["phase"] = "ROUND_START"
	_advance(s)
	return s


static func _draw_card(s: Dictionary):
	if s["drawPile"].is_empty():    # RULE-027
		if s["discardPile"].is_empty():
			_fatal(s, "draw pile and discard pile are both empty")
			return null
		var recycled: Array = s["discardPile"]
		s["discardPile"] = []
		s["drawPile"] = Rng.shuffle(s, recycled)
		_emit(s, "DECK_RECYCLED", {"count": s["drawPile"].size()})
	return s["drawPile"].pop_back()


## ---------------- state machine ----------------

static func _advance(s: Dictionary) -> void:
	for guard in range(100000):
		match s["phase"]:
			"ROUND_START":
				_round_start(s)
			"DEAL_TO_FIVE":
				_deal_to_five(s)
			"MONEY_DISTRIBUTION":
				if s["extraMoneyCard"] != null:
					return
				s["phase"] = "CARD_SELECTION"
			"CARD_SELECTION":
				for p in s["players"]:
					if p["selectedCardId"] == null:
						return
				s["phase"] = "REVEAL"
			"REVEAL":
				_reveal(s)
			"GROUP_BY_BAR":
				s["currentBarIndex"] = -1
				s["phase"] = "BAR_RESOLUTION"
			"BAR_RESOLUTION":
				if _resolve_next_bar(s) == "WAIT":
					return
			"PROPOSAL", "PROPOSAL_RESPONSE":
				return
			"ROUND_CLEANUP":
				_round_cleanup(s)
			"GAME_END_CHECK":
				s["phase"] = "FINAL_SCORE" if s["finalRound"] else "ROUND_START"    # RULE-028
			"FINAL_SCORE":
				_final_score(s)
			"GAME_OVER":
				return
			_:
				_fatal(s, "cannot advance from phase %s" % str(s["phase"]))
				return
		if s.has("fatal"):
			return
	_fatal(s, "advance loop did not terminate")


static func _round_start(s: Dictionary) -> void:
	s["round"] = int(s["round"]) + 1
	s["playedCards"] = []
	s["extraMoneyCard"] = null
	s["activeNegotiation"] = null
	s["activeDuel"] = null
	if RelicManager.is_relic_mode(s):
		RelicManager.handle_round_start(s)
	s["roundStartMoney"] = money_map(s)
	_emit(s, "ROUND_STARTED", {"croupierId": s["croupierId"]})
	s["phase"] = "DEAL_TO_FIVE"


## RULE-006, RULE-032: the Croupier deals clockwise.
static func _deal_to_five(s: Dictionary) -> void:
	var n: int = s["playerCount"]
	var start: int = get_player(s, s["croupierId"])["seatIndex"]
	var drawn := {}
	for k in range(n):
		var p: Dictionary = s["players"][(start + k) % n]
		drawn[p["id"]] = 0
		while p["hand"].size() < HAND_SIZE:
			p["hand"].append(_draw_card(s))
			drawn[p["id"]] += 1
	_emit(s, "HAND_FILLED", {"drawn": drawn})
	_start_money_distribution(s)


static func _place_money(s: Dictionary, money_card: Dictionary, bar_id: String, extra: bool) -> void:
	get_bar(s, bar_id)["money"] += int(money_card["value"])
	_emit(s, "MONEY_PLACED", {"barId": bar_id, "value": money_card["value"], "cardId": money_card["id"], "extra": extra})


## RULE-008 / RULE-030 / RULE-025: existing bar money is never reset.
## ASSUMPTION-END: in the final round fewer cards may remain; they go left to right with no free placement
## unless the full set (bars + 1) is available.
static func _start_money_distribution(s: Dictionary) -> void:
	var bars := active_bars(s)
	s["finalRound"] = s["moneyDeck"].size() <= int(s["perRound"])    # RULE-028
	if s["finalRound"]:
		_emit(s, "FINAL_ROUND_ANNOUNCED", {"moneyCardsLeft": s["moneyDeck"].size()})
	var count := mini(int(s["perRound"]), s["moneyDeck"].size())
	var drawn := []
	for i in range(count):
		drawn.append(s["moneyDeck"].pop_back())
	var normal := mini(count, bars.size())
	for j in range(normal):
		_place_money(s, drawn[j], bars[j]["id"], false)
	s["extraMoneyCard"] = drawn[count - 1] if count > bars.size() else null
	s["phase"] = "MONEY_DISTRIBUTION"


## RULE-010
static func _reveal(s: Dictionary) -> void:
	var played := []
	for p in s["players"]:
		var c: Dictionary = s["cards"][p["selectedCardId"]]
		p["hand"].erase(c["id"])
		p["selectedCardId"] = null
		played.append({"cardId": c["id"], "playerId": p["id"], "barId": c["barId"], "type": c["type"], "dieSymbol": c["dieSymbol"]})
	s["playedCards"] = played
	_emit(s, "CARDS_REVEALED", {"cards": Util.clone(played)})
	s["phase"] = "GROUP_BY_BAR"


static func _resolve_next_bar(s: Dictionary) -> String:
	var bars := active_bars(s)
	var i: int = int(s["currentBarIndex"]) + 1
	while i < bars.size():
		var cards := played_by_bar(s, bars[i]["id"])
		if not cards.is_empty():
			s["currentBarIndex"] = i
			s["currentBarId"] = bars[i]["id"]
			return _resolve_bar(s, bars[i], cards)
		i += 1
	s["currentBarIndex"] = null
	s["currentBarId"] = null
	s["phase"] = "ROUND_CLEANUP"
	return "DONE"


## docs/04 §17: the only way money moves from a bar to a player.
static func award_money(s: Dictionary, player_id: String, amount: int, bar_id: String) -> void:
	var bar := get_bar(s, bar_id)
	if amount < 0:
		_fatal(s, "invalid amount %d" % amount)
		return
	if amount > int(bar["money"]):
		_fatal(s, "bar %s holds %d, cannot pay %d" % [bar_id, bar["money"], amount])
		return
	if amount == 0:
		return
	bar["money"] -= amount
	get_player(s, player_id)["money"] += amount
	_emit(s, "MONEY_AWARDED", {"playerId": player_id, "amount": amount, "barId": bar_id})


static func _resolve_bar(s: Dictionary, bar: Dictionary, cards: Array) -> String:
	var zs := []
	var rs := []
	for c in cards:
		if c["type"] == "ZOCKER":
			zs.append(c)
		else:
			rs.append(c)

	if int(bar["money"]) == 0:    # ASSUMPTION-EMPTY: nothing to claim, nothing to negotiate
		_emit(s, "BAR_RESOLVED", {"barId": bar["id"], "kind": "EMPTY", "zockers": _ids(zs), "razzias": _ids(rs)})
		return "CONTINUE"
	if zs.is_empty() and not rs.is_empty():    # RULE-014
		_emit(s, "BAR_RESOLVED", {"barId": bar["id"], "kind": "RAZZIA_NO_ZOCKER", "money": bar["money"], "razzias": _ids(rs)})
		RelicManager.handle_failed_raid(s, bar, _ids(rs))
		return "CONTINUE"
	if zs.size() == 1 and rs.is_empty():    # RULE-011
		_emit(s, "BAR_RESOLVED", {"barId": bar["id"], "kind": "SINGLE_ZOCKER", "money": bar["money"], "winnerId": zs[0]["playerId"]})
		award_money(s, zs[0]["playerId"], int(bar["money"]), bar["id"])
		if RelicManager.is_relic_mode(s):
			RelicManager.handle_solo_bar_bonus(s, zs[0]["playerId"], bar["id"])
		return "CONTINUE"

	var claimants: Array
	var kind: String
	if not rs.is_empty() and not zs.is_empty():    # RULE-013, RULE-015
		kind = "RAZZIA"
		claimants = rs
		_emit(s, "RAZZIA_ACTIVATED", {"barId": bar["id"], "razzias": _ids(rs), "shutOut": _ids(zs), "money": bar["money"]})
	else:    # RULE-012
		kind = "ZOCKER"
		claimants = zs

	if claimants.size() == 1:
		# ASSUMPTION-SOLE-RAZZIA: a single Razzia player is the only claimant and takes the whole bar.
		_emit(s, "BAR_RESOLVED", {"barId": bar["id"], "kind": "RAZZIA_SOLE_CLAIMANT", "money": bar["money"], "winnerId": claimants[0]["playerId"]})
		award_money(s, claimants[0]["playerId"], int(bar["money"]), bar["id"])
		if RelicManager.is_relic_mode(s):
			RelicManager.handle_solo_bar_bonus(s, claimants[0]["playerId"], bar["id"])
		return "CONTINUE"

	# RULE-021 (four or more claimants): proposal/response is unchanged; duels become a tournament in _resolve_negotiation.
	var ordered := order_by_priority(s, claimants)
	var symbols := {}
	for c in ordered:
		symbols[c["playerId"]] = c["dieSymbol"]
	s["activeNegotiation"] = {
		"id": "N%d-%s" % [s["round"], bar["id"]], "barId": bar["id"], "kind": kind, "claimantIds": _ids(ordered),
		"symbols": symbols, "proposerId": ordered[0]["playerId"], "prize": bar["money"], "proposal": null, "responses": {},
	}
	_emit(s, "NEGOTIATION_STARTED", {
		"barId": bar["id"], "kind": kind, "claimantIds": _ids(ordered), "symbols": Util.clone(symbols),
		"proposerId": ordered[0]["playerId"], "prize": bar["money"],
	})
	s["phase"] = "PROPOSAL"
	return "WAIT"


## ---------------- actions ----------------

static func _place_extra_money(s: Dictionary, a: Dictionary) -> Dictionary:
	if s["phase"] != "MONEY_DISTRIBUTION" or s["extraMoneyCard"] == null:
		return state_err("no extra money card to place")
	if a.get("playerId") != s["croupierId"]:
		return rule_err("RULE-008: only the Croupier places the extra money card")
	var bar := _find_bar(s, a.get("barId"))
	if bar.is_empty():
		return data_err("unknown bar %s" % str(a.get("barId")))
	if not bar["active"]:
		return rule_err("RULE-030: bar %s is not active" % bar["id"])
	_place_money(s, s["extraMoneyCard"], bar["id"], true)
	s["extraMoneyCard"] = null
	return {}


static func _find_bar(s: Dictionary, id) -> Dictionary:
	for b in s["bars"]:
		if b["id"] == id:
			return b
	return {}


static func _find_player(s: Dictionary, id) -> Dictionary:
	for p in s["players"]:
		if p["id"] == id:
			return p
	return {}


static func _select_card(s: Dictionary, a: Dictionary) -> Dictionary:
	if s["phase"] != "CARD_SELECTION":
		return state_err("cards cannot be selected in phase %s" % str(s["phase"]))
	var p := _find_player(s, a.get("playerId"))
	if p.is_empty():
		return data_err("unknown player %s" % str(a.get("playerId")))
	if p["selectedCardId"] != null:
		return state_err("player %s already selected a card" % p["id"])
	if not p["hand"].has(a.get("cardId")):
		return rule_err("RULE-009: card %s is not in the hand of %s" % [str(a.get("cardId")), p["id"]])
	p["selectedCardId"] = a["cardId"]
	_emit(s, "CARD_SELECTED", {"playerId": p["id"]})    # never carries the card id: hidden information
	return {}


## Returns {} when valid, otherwise an error dictionary. Whole-number floats are accepted as ints.
static func _validate_proposal(neg: Dictionary, allocations) -> Dictionary:
	if not (allocations is Dictionary):
		return data_err("proposal needs allocations")
	var total := 0
	for pid in allocations:
		if not neg["claimantIds"].has(pid):
			return rule_err("proposal pays %s who is not a claimant" % str(pid))
		var v = allocations[pid]
		if not (v is int or v is float) or v < 0 or v != floor(v):
			return rule_err("proposal amounts must be non-negative whole numbers")
		if int(v) % MONEY_STEP != 0:
			return rule_err("ASSUMPTION-STEP: amounts must be multiples of %d" % MONEY_STEP)
		total += int(v)
	# ASSUMPTION-019: RULE-019 allows paying from already-won money, 03_GAME_FLOW §15 caps the total at the prize.
	# The stricter reading (total == prize) is used until the conflict is resolved.
	if total != int(neg["prize"]):
		return rule_err("RULE-019/ASSUMPTION-019: proposal must distribute exactly the prize (%d), got %d" % [neg["prize"], total])
	return {}


static func _make_proposal(s: Dictionary, a: Dictionary) -> Dictionary:
	var neg = s["activeNegotiation"]
	if s["phase"] != "PROPOSAL" or neg == null:
		return state_err("no proposal is expected")
	if a.get("playerId") != neg["proposerId"]:
		return rule_err("RULE-012: only %s may propose" % neg["proposerId"])
	var e := _validate_proposal(neg, a.get("allocations"))
	if not e.is_empty():
		return e
	var proposal := {}
	for pid in neg["claimantIds"]:
		proposal[pid] = int(a["allocations"].get(pid, 0))
	neg["proposal"] = proposal
	for pid in neg["claimantIds"]:
		if pid != neg["proposerId"]:
			neg["responses"][pid] = "PENDING"
	_emit(s, "PROPOSAL_MADE", {"barId": neg["barId"], "proposerId": neg["proposerId"], "proposal": Util.clone(proposal), "prize": neg["prize"]})
	s["phase"] = "PROPOSAL_RESPONSE"
	return {}


static func _respond(s: Dictionary, a: Dictionary) -> Dictionary:
	var neg = s["activeNegotiation"]
	if s["phase"] != "PROPOSAL_RESPONSE" or neg == null:
		return state_err("no response is expected")
	var pid = a.get("playerId")
	if neg["responses"].get(pid, "") != "PENDING":
		return rule_err("player %s has no pending response" % str(pid))
	var resp = a.get("response")
	if resp != "ACCEPT" and resp != "DUEL":
		return data_err("response must be ACCEPT or DUEL")
	neg["responses"][pid] = resp
	if resp == "ACCEPT":
		_emit(s, "PROPOSAL_ACCEPTED", {"barId": neg["barId"], "playerId": pid})
	else:
		_emit(s, "DUEL_CALLED", {"barId": neg["barId"], "playerId": pid})
	for k in neg["responses"]:
		if neg["responses"][k] == "PENDING":
			return {}
	_resolve_negotiation(s)
	return {}


## RULE-018. Returns the winner's id.
static func _run_duel(s: Dictionary, a_id: String, b_id: String, challenger_id: String, bar_id: String) -> String:
	var card_a := played_of(s, a_id, bar_id)
	var card_b := played_of(s, b_id, bar_id)
	s["activeDuel"] = {
		"id": "D%d-%s-%d" % [s["round"], bar_id, s["seq"]], "barId": bar_id, "playerA": a_id, "playerB": b_id,
		"cardA": card_a["cardId"], "cardB": card_b["cardId"], "challengerId": challenger_id,
	}
	_emit(s, "DUEL_STARTED", {
		"barId": bar_id, "playerA": a_id, "playerB": b_id, "symbolA": card_a["dieSymbol"], "symbolB": card_b["dieSymbol"],
		"cardA": Util.clone(card_a), "cardB": Util.clone(card_b), "challengerId": challenger_id,
	})
	var roll_a := _roll_die(s)
	var roll_b := _roll_die(s)
	if RelicManager.is_relic_mode(s):
		roll_a = RelicManager.apply_duel_die_bonus(s, a_id, roll_a)
		roll_b = RelicManager.apply_duel_die_bonus(s, b_id, roll_b)
	var score_a: int = int(card_a["dieSymbol"]) + roll_a
	var score_b: int = int(card_b["dieSymbol"]) + roll_b
	if RelicManager.is_relic_mode(s):
		score_a += RelicManager.apply_duel_score_bonus(s, a_id)
		score_b += RelicManager.apply_duel_score_bonus(s, b_id)
	var d: Dictionary = s["activeDuel"]
	d["rollA"] = roll_a
	d["rollB"] = roll_b
	d["scoreA"] = score_a
	d["scoreB"] = score_b
	_emit(s, "DICE_ROLLED", {"barId": bar_id, "rollA": roll_a, "rollB": roll_b})
	var winner: String
	if score_a > score_b:
		winner = a_id
	elif score_b > score_a:
		winner = b_id
	else:
		winner = RelicManager.resolve_duel_tie(s, a_id, b_id, challenger_id)
	d["winnerId"] = winner
	_emit(s, "DUEL_RESOLVED", {
		"barId": bar_id, "playerA": a_id, "playerB": b_id, "rollA": roll_a, "rollB": roll_b, "scoreA": score_a, "scoreB": score_b,
		"tie": score_a == score_b, "challengerId": challenger_id, "winnerId": winner,
	})
	s["activeDuel"] = null
	return winner


## RULE-017, RULE-020, RULE-021
static func _resolve_negotiation(s: Dictionary) -> void:
	var neg: Dictionary = s["activeNegotiation"]
	var bar := get_bar(s, neg["barId"])
	var prize: int = neg["prize"]
	var proposer: String = neg["proposerId"]
	var rejecters := []
	var accepters := []
	for pid in neg["claimantIds"]:
		if pid == proposer:
			continue
		if neg["responses"][pid] == "DUEL":
			rejecters.append(pid)
		elif neg["responses"][pid] == "ACCEPT":
			accepters.append(pid)
	var outcome: String

	if rejecters.is_empty():
		outcome = "DEAL"
		for pid in neg["claimantIds"]:
			award_money(s, pid, int(neg["proposal"][pid]), bar["id"])
	elif neg["claimantIds"].size() == 2:
		outcome = "DUEL"
		var w2 := _run_duel(s, proposer, rejecters[0], rejecters[0], bar["id"])
		award_money(s, w2, prize, bar["id"])
	elif neg["claimantIds"].size() >= 4:
		# RULE-021: accepters take their offered amount and leave. The proposer is the first "current winner";
		# the rejecters challenge in order of lowest die symbol first. Each duel is called by the challenger
		# (ties go to the challenger). The survivor takes what is left.
		outcome = "ONE_REJECTS" if rejecters.size() == 1 else "TOURNAMENT"
		for pid in accepters:
			award_money(s, pid, int(neg["proposal"][pid]), bar["id"])
		# ASSUMPTION-021-ORDER: equal symbols among challengers are ordered by the same priority list reversed.
		var challengers := []
		for pid in neg["claimantIds"]:
			if rejecters.has(pid):
				challengers.append(pid)
		challengers.reverse()
		var current := proposer
		for pid in challengers:
			current = _run_duel(s, current, pid, pid, bar["id"])
		award_money(s, current, int(bar["money"]), bar["id"])
	elif rejecters.size() == 1:
		outcome = "ONE_REJECTS"
		award_money(s, accepters[0], int(neg["proposal"][accepters[0]]), bar["id"])
		var w3 := _run_duel(s, proposer, rejecters[0], rejecters[0], bar["id"])
		award_money(s, w3, int(bar["money"]), bar["id"])    # the remaining money of the contested bar
	else:
		outcome = "BOTH_REJECT"
		var order: Array = neg["claimantIds"]    # priority order: highest first, lowest last
		var highest: String = order[0]
		var middle: String = order[1]
		var lowest: String = order[2]
		# ASSUMPTION-CHALLENGER: duel 1 is called by the lowest claimant, duel 2 by the remaining third claimant.
		var first := _run_duel(s, highest, lowest, lowest, bar["id"])
		var second := _run_duel(s, first, middle, middle, bar["id"])
		award_money(s, second, prize, bar["id"])
	_emit(s, "BAR_RESOLVED", {"barId": bar["id"], "kind": neg["kind"], "outcome": outcome, "money": prize, "proposerId": proposer})
	s["activeNegotiation"] = null
	s["phase"] = "BAR_RESOLUTION"
	if int(bar["money"]) != 0:
		_fatal(s, "bar %s still holds %d after resolution" % [bar["id"], bar["money"]])


## RULE-026, RULE-007
static func _round_cleanup(s: Dictionary) -> void:
	for p in s["playedCards"]:
		s["discardPile"].append(p["cardId"])
	s["playedCards"] = []
	for p in s["players"]:
		p["selectedCardId"] = null
	s["activeNegotiation"] = null
	s["activeDuel"] = null
	if RelicManager.is_relic_mode(s):
		RelicManager.handle_round_cleanup(s)
	var money := money_map(s)
	var gained := {}
	for p in s["players"]:
		gained[p["id"]] = int(p["money"]) - int(s["roundStartMoney"][p["id"]])
	var cr: int = get_player(s, s["croupierId"])["seatIndex"]
	var next: String = s["players"][(cr + 1) % int(s["playerCount"])]["id"]
	_emit(s, "ROUND_ENDED", {"money": money, "gained": gained, "nextCroupierId": next, "finalRound": s["finalRound"]})
	s["croupierId"] = next
	s["phase"] = "GAME_END_CHECK"


## RULE-001, RULE-028
static func _final_score(s: Dictionary) -> void:
	var ranking := []
	for p in s["players"]:
		ranking.append({"playerId": p["id"], "money": p["money"]})
	# stable insertion sort, money descending (JS Array.sort is stable; Array.sort_custom is not)
	for i in range(1, ranking.size()):
		var item = ranking[i]
		var j := i - 1
		while j >= 0 and int(ranking[j]["money"]) < int(item["money"]):
			ranking[j + 1] = ranking[j]
			j -= 1
		ranking[j + 1] = item
	var best: int = ranking[0]["money"]
	var winners := []
	for r in ranking:
		if int(r["money"]) == best:
			winners.append(r["playerId"])
	s["winnerIds"] = winners
	# ASSUMPTION-TIE: the docs give no tie-break for the final total; ties are reported as shared wins.
	s["winnerId"] = winners[0] if winners.size() == 1 else null
	_emit(s, "GAME_ENDED", {"ranking": ranking, "winnerIds": winners.duplicate()})
	s["phase"] = "GAME_OVER"


## ---------------- public API ----------------

## Mutating variant (used by the controller and simulations).
## Returns {"ok": true, "events": [...]} or {"ok": false, "error": {category, message}}.
static func reduce_in_place(s: Dictionary, a: Dictionary) -> Dictionary:
	var before: int = s["events"].size()
	var e := {}
	match a.get("type", null):
		"PLACE_EXTRA_MONEY":
			e = _place_extra_money(s, a)
		"SELECT_CARD":
			e = _select_card(s, a)
		"MAKE_PROPOSAL":
			e = _make_proposal(s, a)
		"RESPOND":
			e = _respond(s, a)
		_:
			e = state_err("unknown action %s" % str(a.get("type", null)))
	if not e.is_empty():
		return _fail(e)
	_advance(s)
	if s.has("fatal"):
		return _fail(state_err("engine invariant broken: %s" % str(s["fatal"][0])))
	return {"ok": true, "events": s["events"].slice(before), "error": {}}


## Immutable variant: never touches the input state. Returns the result plus "state".
static func dispatch(state: Dictionary, a: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	var r := reduce_in_place(s, a)
	r["state"] = s
	return r


## Returns null (nothing is waiting) or a Dictionary describing the input the engine needs next.
static func get_pending_input(s: Dictionary):
	if s["phase"] == "MONEY_DISTRIBUTION" and s["extraMoneyCard"] != null:
		return {"type": "PLACE_EXTRA_MONEY", "playerId": s["croupierId"]}
	if s["phase"] == "CARD_SELECTION":
		var waiting := []
		for p in s["players"]:
			if p["selectedCardId"] == null:
				waiting.append(p["id"])
		return {"type": "SELECT_CARD", "playerIds": waiting} if not waiting.is_empty() else null
	if s["phase"] == "PROPOSAL":
		return {"type": "MAKE_PROPOSAL", "playerId": s["activeNegotiation"]["proposerId"]}
	if s["phase"] == "PROPOSAL_RESPONSE":
		var neg: Dictionary = s["activeNegotiation"]
		var pending := []
		for pid in neg["responses"]:
			if neg["responses"][pid] == "PENDING":
				pending.append(pid)
		return {"type": "RESPOND", "playerIds": pending}
	return null


## What a player may legitimately know (docs/06 §9): own hand, revealed cards, discards, bar money, public money,
## public actions. Never the draw pile order, other hands, or other players' hidden selections or responses.
static func get_public_view(s: Dictionary, pid: String) -> Dictionary:
	var me := get_player(s, pid)
	var revealed: bool = s["phase"] != "CARD_SELECTION" and s["phase"] != "MONEY_DISTRIBUTION"
	var unseen := {"ZOCKER": 0, "RAZZIA": 0}
	var known := {}
	for id in me["hand"]:
		known[id] = 1
	for id in s["discardPile"]:
		known[id] = 1
	if revealed:
		for p in s["playedCards"]:
			known[p["cardId"]] = 1
	for id in s["cards"]:
		if not known.has(id):
			unseen[s["cards"][id]["type"]] += 1
	var neg = s["activeNegotiation"]
	var hand := []
	for id in me["hand"]:
		hand.append(Util.clone(s["cards"][id]))
	var players := []
	for p in s["players"]:
		players.append({
			"id": p["id"], "name": p["name"], "isHuman": p["isHuman"], "seatIndex": p["seatIndex"],
			"money": p["money"], "handSize": p["hand"].size(), "hasSelected": p["selectedCardId"] != null,
		})
	var bars := []
	for b in s["bars"]:
		bars.append({"id": b["id"], "name": b["name"], "order": b["order"], "active": b["active"], "money": b["money"]})
	var discard := []
	for id in s["discardPile"]:
		discard.append(Util.clone(s["cards"][id]))
	var view := {
		"version": s["version"], "phase": s["phase"], "round": s["round"], "playerCount": s["playerCount"],
		"finalRound": s["finalRound"], "croupierId": s["croupierId"], "you": pid, "perRound": s["perRound"],
		"yourProfile": {"aiDifficulty": me.get("aiDifficulty", null), "personality": me.get("personality", null)},
		"hand": hand, "players": players, "bars": bars, "discardPile": discard,
		"playedCards": Util.clone(s["playedCards"]) if revealed else [],
		"extraMoneyCard": Util.clone(s["extraMoneyCard"]),
		"moneyDeckCount": s["moneyDeck"].size(), "unseen": unseen, "negotiation": null,
	}
	if neg != null:
		view["negotiation"] = {
			"id": neg["id"], "barId": neg["barId"], "kind": neg["kind"], "claimantIds": neg["claimantIds"].duplicate(),
			"symbols": Util.clone(neg["symbols"]), "proposerId": neg["proposerId"], "prize": neg["prize"],
			"proposal": Util.clone(neg["proposal"]), "myResponse": neg["responses"].get(pid, null),
		}
	return view


## INV-001..005 (docs/04 §14). Returns a list of violations (empty = ok).
static func check_invariants(s: Dictionary) -> Array:
	var errs := []
	var seen := {}
	var see := func(id, where: String) -> void:
		if seen.has(id):
			errs.append("INV-001 card %s in %s and %s" % [str(id), seen[id], where])
		else:
			seen[id] = where
	for p in s["players"]:
		for id in p["hand"]:
			see.call(id, "hand " + p["id"])
	for id in s["drawPile"]:
		see.call(id, "draw")
	for id in s["discardPile"]:
		see.call(id, "discard")
	for p in s["playedCards"]:
		see.call(p["cardId"], "played")
	for id in s["cards"]:
		if not seen.has(id):
			errs.append("INV-001 card %s is nowhere" % id)
	var total := 0
	for m in s["moneyDeck"]:
		total += int(m["value"])
	for b in s["bars"]:
		total += int(b["money"])
	for p in s["players"]:
		total += int(p["money"])
	if s["extraMoneyCard"] != null:
		total += int(s["extraMoneyCard"]["value"])
	if s.has("blackMarketVault"):
		total += int(s["blackMarketVault"])
	if total != int(s["totalMoney"]):
		errs.append("INV-002 money %d != %d" % [total, s["totalMoney"]])
	if s["phase"] == "CARD_SELECTION":
		for p in s["players"]:
			if p["hand"].size() != HAND_SIZE:
				errs.append("INV-003 hand size %d for %s" % [p["hand"].size(), p["id"]])
	for p in s["players"]:
		if p["selectedCardId"] != null and not p["hand"].has(p["selectedCardId"]):
			errs.append("INV-004 selection of %s not in hand" % p["id"])
	for b in s["bars"]:
		if not b["active"] and int(b["money"]) != 0:
			errs.append("INV-005 inactive bar %s holds money" % b["id"])
	for p in s["playedCards"]:
		if not get_bar(s, p["barId"])["active"]:
			errs.append("INV-005 played card on inactive bar %s" % p["barId"])
	return errs


static func serialize_game(s: Dictionary) -> String:
	return JSON.stringify({"version": VERSION, "gameState": s})


## Accepts the JSON text (or an already parsed Dictionary). Returns {"ok": true, "state": ...} or {"ok": false, "error": ...}.
static func load_game(json) -> Dictionary:
	var o = json
	if json is String:
		o = JSON.parse_string(json)
	if not (o is Dictionary):
		return {"ok": false, "error": err("SAVE_ERROR", "save data is not an object")}
	o = Util.normalize(o)
	if o.get("version", null) != VERSION or not (o.get("gameState", null) is Dictionary):
		return {"ok": false, "error": err("SAVE_ERROR", "unsupported save version %s" % str(o.get("version", null)))}
	return {"ok": true, "state": o["gameState"], "error": {}}
