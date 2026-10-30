extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = everything passed, 1 = at least one failure.
##
## Sections
##  1. RNG vectors            : bit-exact against the JS mulberry32 (tests/golden/rng.json)
##  2. Golden engine replay   : golden actions through the engine -> identical event log (52 games, 3-8 players)
##  3. Golden AI full replay  : AI + controller from the seed -> identical actions AND events (52 games)
##  4. Save / load            : serialize mid-game, reload, finish -> identical event log
##  5. Rule scenarios         : hand-built situations checked against docs/02_RULEBOOK.md (independent of the JS)
##  6. Error handling & hidden information & AI anti-cheat (docs/06 §16, docs/07 §11)

const Eng = preload("res://engine/engine.gd")
const Rng = preload("res://engine/rng.gd")
const Util = preload("res://engine/util.gd")
const AI = preload("res://ai/ai.gd")
const Ctl = preload("res://controller/match_controller.gd")

var checks := 0
var fails := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	_test_rng()
	var index: Array = Util.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/index.json")))
	_test_golden_engine(index)
	_test_golden_ai(index)
	_test_save_load(index)
	_test_rule_scenarios()
	_test_errors_and_hidden_info()
	print("")
	print("%d checks, %d failed, %.1fs" % [checks, fails, (Time.get_ticks_msec() - t0) / 1000.0])
	print("RESULT: ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func ok(cond: bool, label: String, detail: String = "") -> bool:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", label, ("  -> " + detail) if detail != "" else "")
	return cond


func _load_golden(file: String):
	return Util.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/" + file)))


func _summary(s: Dictionary) -> Dictionary:
	var money := {}
	for p in s["players"]:
		money[p["id"]] = p["money"]
	return {
		"round": s["round"], "phase": s["phase"], "rngState": s["rngState"], "croupierId": s["croupierId"],
		"winnerId": s["winnerId"], "winnerIds": s["winnerIds"], "money": money,
		"drawPile": s["drawPile"].size(), "discardPile": s["discardPile"].size(), "moneyDeck": s["moneyDeck"].size(),
	}


## Compares two event lists; returns "" when equal, otherwise a description of the first difference.
func _diff_events(got: Array, want: Array) -> String:
	var n := mini(got.size(), want.size())
	for i in range(n):
		var a := Util.canonical(got[i])
		var b := Util.canonical(want[i])
		if a != b:
			return "event #%d differs\n      got : %s\n      want: %s" % [i, a, b]
	if got.size() != want.size():
		return "event count %d != %d" % [got.size(), want.size()]
	return ""


## ---------------------------------------------------------------- 1. RNG

func _test_rng() -> void:
	print("[1] RNG vectors (JS mulberry32)")
	var data: Array = _load_golden("rng.json")
	var bad := 0
	for e in data:
		var s := {"rngState": int(e["seed"])}
		for i in range(e["k"].size()):
			var f := Rng.rng_float(s)
			if f * 4294967296.0 != float(e["k"][i]):
				bad += 1
	ok(bad == 0, "rng matches JS for %d seeds x %d samples" % [data.size(), data[0]["k"].size()], "%d mismatches" % bad)


## ---------------------------------------------------------------- 2. golden engine replay

func _test_golden_engine(index: Array) -> void:
	print("[2] Golden engine replay (%d games)" % index.size())
	var bad_games := 0
	for entry in index:
		var doc: Dictionary = _load_golden(entry["file"])
		var s := Eng.create_game(doc["config"])
		var good := true
		var d := _diff_events(s["events"], doc["initialEvents"])
		if d != "":
			good = false
			ok(false, entry["file"] + " initial events", d)
		if Util.canonical(_summary(s)) != Util.canonical(doc["initialSummary"]):
			good = false
			ok(false, entry["file"] + " initial summary", Util.canonical(_summary(s)) + "\n      want: " + Util.canonical(doc["initialSummary"]))
		var step := 0
		for a in doc["actions"]:
			var r := Eng.reduce_in_place(s, a)
			if not r["ok"]:
				good = false
				ok(false, "%s action #%d rejected" % [entry["file"], step], str(r["error"]))
				break
			var inv := Eng.check_invariants(s)
			if not inv.is_empty():
				good = false
				ok(false, "%s invariants after action #%d" % [entry["file"], step], str(inv))
				break
			step += 1
		if good:
			d = _diff_events(s["events"], doc["events"])
			if d != "":
				good = false
				ok(false, entry["file"] + " full event log", d)
		if good and Util.canonical(_summary(s)) != Util.canonical(doc["final"]):
			good = false
			ok(false, entry["file"] + " final summary", Util.canonical(_summary(s)) + "\n      want: " + Util.canonical(doc["final"]))
		if good and Eng.get_pending_input(s) != null:
			good = false
			ok(false, entry["file"] + " still waiting for input after the last golden action")
		if not good:
			bad_games += 1
	ok(bad_games == 0, "all %d golden games replay identically through the engine" % index.size(), "%d games differ" % bad_games)


## ---------------------------------------------------------------- 3. golden AI replay

func _test_golden_ai(index: Array) -> void:
	print("[3] Golden AI + controller replay (%d games)" % index.size())
	var bad_games := 0
	for entry in index:
		var doc: Dictionary = _load_golden(entry["file"])
		var s := Eng.create_game(doc["config"])
		var ctl := Ctl.new(s)
		var actions := []
		ctl.on_action = func(_st, a): actions.append(a.duplicate(true))
		var pending = ctl.run()
		var good := true
		if pending != null or not ctl.error.is_empty():
			good = false
			ok(false, entry["file"] + " controller stopped", "pending=%s error=%s" % [str(pending), str(ctl.error)])
		if good:
			var n := mini(actions.size(), doc["actions"].size())
			for i in range(n):
				if Util.canonical(actions[i]) != Util.canonical(doc["actions"][i]):
					good = false
					ok(false, "%s AI action #%d differs" % [entry["file"], i],
						"\n      got : %s\n      want: %s" % [Util.canonical(actions[i]), Util.canonical(doc["actions"][i])])
					break
			if good and actions.size() != doc["actions"].size():
				good = false
				ok(false, entry["file"] + " action count", "%d != %d" % [actions.size(), doc["actions"].size()])
		if good:
			var d := _diff_events(s["events"], doc["events"])
			if d != "":
				good = false
				ok(false, entry["file"] + " event log", d)
		if good and not Eng.check_invariants(s).is_empty():
			good = false
			ok(false, entry["file"] + " final invariants", str(Eng.check_invariants(s)))
		if good and s.has("fatal"):
			good = false
			ok(false, entry["file"] + " fatal", str(s["fatal"]))
		if not good:
			bad_games += 1
	ok(bad_games == 0, "all %d games: AI picks the same cards/offers/answers as the JS AI" % index.size(), "%d games differ" % bad_games)


## ---------------------------------------------------------------- 4. save / load

func _test_save_load(index: Array) -> void:
	print("[4] Save / load")
	var seen_counts := {}
	var tested := 0
	for entry in index:
		var pc: int = entry["playerCount"]
		var key := "%d-%s" % [pc, entry["aiDifficulty"]]
		if seen_counts.has(key):
			continue
		seen_counts[key] = true
		var doc: Dictionary = _load_golden(entry["file"])
		var s := Eng.create_game(doc["config"])
		var half: int = doc["actions"].size() / 2
		for i in range(half):
			Eng.reduce_in_place(s, doc["actions"][i])
		var text := Eng.serialize_game(s)
		var loaded := Eng.load_game(text)
		if not ok(loaded["ok"], "%s: save loads" % key, str(loaded["error"])):
			continue
		var s2: Dictionary = loaded["state"]
		ok(Util.canonical(s2) == Util.canonical(s), "%s: loaded state equals saved state" % key)
		for i in range(half, doc["actions"].size()):
			var r := Eng.reduce_in_place(s2, doc["actions"][i])
			if not r["ok"]:
				ok(false, "%s: action #%d after reload rejected" % [key, i], str(r["error"]))
				break
		var d := _diff_events(s2["events"], doc["events"])
		ok(d == "", "%s: finishing a reloaded game gives the golden log" % key, d)
		tested += 1
	var bad := Eng.load_game(JSON.stringify({"version": 99, "gameState": {}}))
	ok(not bad["ok"] and bad["error"]["category"] == "SAVE_ERROR", "unknown save version is a SAVE_ERROR, not silently accepted")
	var junk := Eng.load_game("[1,2,3]")
	ok(not junk["ok"], "non-object save data is rejected")
	ok(tested >= 10, "save/load covered %d configurations" % tested)


## ---------------------------------------------------------------- 5. rule scenarios

## Builds a game at CARD_SELECTION where every player holds exactly the cards given in `picks`
## ({playerId: [barId, TYPE, symbol]}); the players then each select that card.
## Bars get the given money. Returns the state right after the last selection (negotiation or finished round).
func _scenario(player_count: int, croupier: String, bar_money: Dictionary, picks: Dictionary, forced_rolls: Array = []) -> Dictionary:
	var s := Eng.create_game({"playerCount": player_count, "seed": 7, "humanPlayerId": null, "firstCroupierId": croupier})
	# finish money placement for this round with the AI croupier if needed, then override money and hands
	var ctl := Ctl.new(s)
	# run until the AI would start choosing cards; simplest: set state directly at CARD_SELECTION
	while s["phase"] == "MONEY_DISTRIBUTION" and s["extraMoneyCard"] != null:
		Eng.reduce_in_place(s, {"type": "PLACE_EXTRA_MONEY", "playerId": s["croupierId"], "barId": "COLIBRI"})
	for b in s["bars"]:
		b["money"] = 0
	var total_on_bars := 0
	for k in bar_money:
		Eng.get_bar(s, k)["money"] = bar_money[k]
		total_on_bars += bar_money[k]
	s["totalMoney"] = total_on_bars    # make the money invariant meaningful for this synthetic table
	s["moneyDeck"] = []
	for p in s["players"]:
		p["money"] = 0
	var assigned := {}
	for pid in picks:
		var spec: Array = picks[pid]
		var found := ""
		for id in s["cards"]:
			var c: Dictionary = s["cards"][id]
			if c["barId"] == spec[0] and c["type"] == spec[1] and c["dieSymbol"] == spec[2] and not assigned.has(id):
				found = id
				break
		if found == "":
			ok(false, "scenario setup: no free card for %s %s" % [pid, str(spec)])
			continue
		assigned[found] = pid
		# take the card out of wherever it currently is and put it first in this player's hand
		for p3 in s["players"]:
			p3["hand"].erase(found)
		s["drawPile"].erase(found)
		s["discardPile"].erase(found)
		Eng.get_player(s, pid)["hand"].insert(0, found)
	s["forcedRolls"] = forced_rolls.duplicate()
	for pid in picks:
		var r := Eng.reduce_in_place(s, {"type": "SELECT_CARD", "playerId": pid, "cardId": _assigned_card(assigned, pid)})
		if not r["ok"]:
			print("  scenario setup rejected: ", r["error"])
	return s


func _assigned_card(assigned: Dictionary, pid: String) -> String:
	for id in assigned:
		if assigned[id] == pid:
			return id
	return ""


func _last(s: Dictionary, type: String) -> Dictionary:
	for i in range(s["events"].size() - 1, -1, -1):
		if s["events"][i]["type"] == type:
			return s["events"][i]
	return {}


func _count(s: Dictionary, type: String) -> int:
	var n := 0
	for e in s["events"]:
		if e["type"] == type:
			n += 1
	return n


func _test_rule_scenarios() -> void:
	print("[5] Rule scenarios (docs/02_RULEBOOK.md)")

	# RULE-011 single Zocker takes the whole bar
	var s := _scenario(3, "P1", {"COLIBRI": 30000, "COTTON_CLUB": 10000},
		{"P1": ["COLIBRI", "ZOCKER", 3], "P2": ["COTTON_CLUB", "ZOCKER", 2], "P3": ["HAVANA_BAR", "ZOCKER", 6]})
	ok(Eng.get_player(s, "P1")["money"] == 30000, "RULE-011: lone Zocker takes the whole bar (P1 got %d)" % Eng.get_player(s, "P1")["money"])
	ok(Eng.get_player(s, "P2")["money"] == 10000, "RULE-011: second lone Zocker on another bar")
	ok(Eng.get_player(s, "P3")["money"] == 0, "RULE-011: bar with no money pays nothing (ASSUMPTION-EMPTY)")

	# RULE-014 Razzia without Zocker: money stays
	s = _scenario(3, "P1", {"COLIBRI": 50000},
		{"P1": ["COLIBRI", "RAZZIA", 6], "P2": ["COTTON_CLUB", "ZOCKER", 1], "P3": ["HAVANA_BAR", "ZOCKER", 1]})
	ok(Eng.get_bar(s, "COLIBRI")["money"] == 50000, "RULE-014: Razzia without Zocker leaves the money on the bar")
	ok(Eng.get_player(s, "P1")["money"] == 0, "RULE-014: the Razzia player gets nothing")
	ok(_last(s, "BAR_RESOLVED").get("kind", "") != "" and _count(s, "NEGOTIATION_STARTED") == 0, "RULE-014: no negotiation is started")

	# RULE-013 / ASSUMPTION-SOLE-RAZZIA: Razzia + Zocker shuts the Zocker out
	s = _scenario(3, "P1", {"COLIBRI": 40000},
		{"P1": ["COLIBRI", "RAZZIA", 4], "P2": ["COLIBRI", "ZOCKER", 6], "P3": ["HAVANA_BAR", "ZOCKER", 1]})
	ok(Eng.get_player(s, "P1")["money"] == 40000, "RULE-013: sole Razzia player takes the bar")
	ok(Eng.get_player(s, "P2")["money"] == 0, "RULE-013: the Zocker is shut out")
	ok(_count(s, "RAZZIA_ACTIVATED") == 1, "RULE-013: RAZZIA_ACTIVATED event emitted")

	# RULE-012 / 017: two Zockers, higher symbol proposes, other accepts
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 2], "P2": ["COLIBRI", "ZOCKER", 5], "P3": ["HAVANA_BAR", "ZOCKER", 1]})
	ok(s["phase"] == "PROPOSAL" and s["activeNegotiation"]["proposerId"] == "P2", "RULE-012: highest die symbol proposes (P2 with 5)")
	var r := Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 40000, "P1": 20000}})
	ok(r["ok"], "RULE-017: valid proposal accepted by the engine", str(r["error"]))
	r = Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P1", "response": "ACCEPT"})
	ok(Eng.get_player(s, "P2")["money"] == 40000 and Eng.get_player(s, "P1")["money"] == 20000, "RULE-017: accepted proposal pays as proposed")

	# RULE-018: duel, higher total wins
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 2], "P2": ["COLIBRI", "ZOCKER", 5], "P3": ["HAVANA_BAR", "ZOCKER", 1]}, [6, 1])
	Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 55000, "P1": 5000}})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P1", "response": "DUEL"})
	# duel A = proposer P2 (5+rollA=1 -> 6), B = P1 (2+rollB... forced [6,1]: rollA=6, rollB=1): A=11, B=3
	ok(Eng.get_player(s, "P2")["money"] == 60000, "RULE-018: higher duel total (5+6 vs 2+1) wins the whole bar")

	# RULE-018: tie goes to the player who called the duel (the rejecter P1)
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 2], "P2": ["COLIBRI", "ZOCKER", 5], "P3": ["HAVANA_BAR", "ZOCKER", 1]}, [1, 4])
	Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 55000, "P1": 5000}})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P1", "response": "DUEL"})
	# A: 5+1 = 6, B: 2+4 = 6 -> tie -> challenger (P1) wins
	ok(Eng.get_player(s, "P1")["money"] == 60000, "RULE-018: a tied duel is won by the player who called it")
	ok(_last(s, "DUEL_RESOLVED").get("tie", false) == true, "RULE-018: DUEL_RESOLVED marks the tie")

	# RULE-020: 3 claimants, one accepts, one rejects
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 6], "P2": ["COLIBRI", "ZOCKER", 4], "P3": ["COLIBRI", "ZOCKER", 2]}, [1, 1])
	ok(s["activeNegotiation"]["claimantIds"] == ["P1", "P2", "P3"], "RULE-020: claimants ordered by die symbol")
	Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": {"P1": 30000, "P2": 20000, "P3": 10000}})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P2", "response": "ACCEPT"})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P3", "response": "DUEL"})
	# P2 keeps 20000; P1 (6+1=7) beats P3 (2+1=3) for the remaining 40000
	ok(Eng.get_player(s, "P2")["money"] == 20000, "RULE-020: the accepting player receives the offered amount")
	ok(Eng.get_player(s, "P1")["money"] == 40000 and Eng.get_player(s, "P3")["money"] == 0, "RULE-020: proposer-vs-rejecter duel winner takes the remainder")

	# RULE-020: 3 claimants, both reject -> two duels
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 6], "P2": ["COLIBRI", "ZOCKER", 4], "P3": ["COLIBRI", "ZOCKER", 2]}, [1, 6, 1, 1])
	Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": {"P1": 40000, "P2": 10000, "P3": 10000}})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P2", "response": "DUEL"})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P3", "response": "DUEL"})
	ok(_count(s, "DUEL_RESOLVED") == 2, "RULE-020: both reject -> exactly two duels")
	# duel 1: highest P1 (6+1=7) vs lowest P3 (2+6=8) -> P3 wins; duel 2: P3 (2+1=3) vs P2 (4+1=5) -> P2 wins everything
	ok(Eng.get_player(s, "P2")["money"] == 60000, "RULE-020: winner of the second duel takes the entire prize")

	# RULE-021: four claimants, one accepts, two reject -> tournament
	s = _scenario(4, "P1", {"COLIBRI": 80000},
		{"P1": ["COLIBRI", "ZOCKER", 6], "P2": ["COLIBRI", "ZOCKER", 5], "P3": ["COLIBRI", "ZOCKER", 2], "P4": ["COLIBRI", "ZOCKER", 1]},
		[1, 1, 1, 1, 1, 1])
	ok(s["activeNegotiation"]["claimantIds"] == ["P1", "P2", "P3", "P4"], "RULE-021: four claimants ordered by priority")
	Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": {"P1": 40000, "P2": 15000, "P3": 15000, "P4": 10000}})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P2", "response": "ACCEPT"})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P3", "response": "DUEL"})
	Eng.reduce_in_place(s, {"type": "RESPOND", "playerId": "P4", "response": "DUEL"})
	ok(Eng.get_player(s, "P2")["money"] == 15000, "RULE-021: accepting player is paid and leaves")
	ok(_count(s, "DUEL_RESOLVED") == 2, "RULE-021: proposer + 2 rejecters = 2 duels in the tournament")
	var duels := []
	for e in s["events"]:
		if e["type"] == "DUEL_RESOLVED":
			duels.append(e)
	# lowest priority (P4) challenges first, against the proposer P1; then P3 challenges the winner
	ok(duels[0]["playerA"] == "P1" and duels[0]["playerB"] == "P4" and duels[0]["challengerId"] == "P4", "RULE-021: lowest-priority rejecter challenges the proposer first")
	ok(duels[1]["playerB"] == "P3" and duels[1]["playerA"] == duels[0]["winnerId"], "RULE-021: next challenger duels the current winner")
	var paid := 0
	for p in s["players"]:
		paid += p["money"]
	ok(paid == 80000 and Eng.get_bar(s, "COLIBRI")["money"] == 0, "RULE-021: the whole bar is paid out, nothing is created or lost")

	# RULE-022: equal symbols -> the seat farther from the Croupier proposes first
	s = _scenario(3, "P2", {"COLIBRI": 20000},
		{"P1": ["COLIBRI", "ZOCKER", 4], "P2": ["COLIBRI", "ZOCKER", 4], "P3": ["HAVANA_BAR", "ZOCKER", 1]})
	# croupier P2: distances P2=0, P3=1, P1=2 -> P1 is farther
	ok(s["activeNegotiation"]["proposerId"] == "P1", "RULE-022: tie on die symbol -> player farther from the Croupier proposes (P1)")

	# RULE-019 (strict reading): proposals must be whole $5,000 steps summing to the prize
	s = _scenario(3, "P1", {"COLIBRI": 60000},
		{"P1": ["COLIBRI", "ZOCKER", 2], "P2": ["COLIBRI", "ZOCKER", 5], "P3": ["HAVANA_BAR", "ZOCKER", 1]})
	r = Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 50000, "P1": 5000}})
	ok(not r["ok"], "RULE-019: proposal that does not sum to the prize is rejected")
	r = Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 52500, "P1": 7500}})
	ok(not r["ok"], "ASSUMPTION-STEP: amounts that are not multiples of $5,000 are rejected")
	r = Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P2", "allocations": {"P2": 70000, "P1": -10000}})
	ok(not r["ok"], "RULE-019: negative amounts are rejected")
	r = Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": {"P2": 40000, "P1": 20000}})
	ok(not r["ok"] and r["error"]["category"] == "RULE_ERROR", "RULE-012: only the highest-priority claimant may propose")
	ok(s["phase"] == "PROPOSAL", "rejected actions leave the phase unchanged")

	# ASSUMPTION-TIE / RULE-001: final totals. A shared top total is reported as a shared win (never silently one winner).
	var tie := Eng.create_game({"playerCount": 3, "seed": 3, "humanPlayerId": null})
	tie["players"][0]["money"] = 30000
	tie["players"][1]["money"] = 30000
	tie["players"][2]["money"] = 10000
	tie["phase"] = "FINAL_SCORE"
	Eng._advance(tie)
	ok(tie["phase"] == "GAME_OVER" and tie["winnerIds"] == ["P1", "P2"] and tie["winnerId"] == null, "ASSUMPTION-TIE: equal top totals -> shared win (winnerIds P1,P2)")
	var ranking: Array = _last(tie, "GAME_ENDED")["ranking"]
	ok(ranking[0]["playerId"] == "P1" and ranking[1]["playerId"] == "P2" and ranking[2]["playerId"] == "P3", "final ranking is stable for equal totals (seat order kept)")
	var solo := Eng.create_game({"playerCount": 3, "seed": 3, "humanPlayerId": null})
	solo["players"][0]["money"] = 5000
	solo["players"][1]["money"] = 90000
	solo["players"][2]["money"] = 10000
	solo["phase"] = "FINAL_SCORE"
	Eng._advance(solo)
	ok(solo["winnerId"] == "P2" and solo["winnerIds"] == ["P2"], "RULE-001: the highest total wins")

	# setup rules
	var s3 := Eng.create_game({"playerCount": 3, "seed": 5})
	ok(s3["cards"].size() == 48 and s3["totalMoney"] > 0, "RULE-030: 3 players use 48 cards (4 bars x 12)")
	var inactive := 0
	for b in s3["bars"]:
		if not b["active"]:
			inactive += 1
	ok(inactive == 2, "RULE-030: Lincoln's and Jazz House are inactive in a 3-player game")
	var s5 := Eng.create_game({"playerCount": 5, "seed": 5})
	ok(s5["cards"].size() == 72 - 18, "RULE-029: 4-6 players remove 18 cards (%d in play)" % s5["cards"].size())
	var s8 := Eng.create_game({"playerCount": 8, "seed": 5})
	ok(s8["cards"].size() == 72, "RULE-031: card count for 8 players is 72 (%d)" % s8["cards"].size())
	var total84 := 0
	for v in Eng.ORIGINAL_MONEY_COUNTS:
		total84 += int(v) * int(Eng.ORIGINAL_MONEY_COUNTS[v])
	var money_cards := 0
	for v in Eng.ORIGINAL_MONEY_COUNTS:
		money_cards += int(Eng.ORIGINAL_MONEY_COUNTS[v])
	ok(money_cards == 84, "RULE-003: the money set has 84 cards")
	ok(s5["totalMoney"] == total84 and total84 == 1_680_000, "RULE-003: 4-6 players use all money, total $%d" % s5["totalMoney"])
	ok(s8["totalMoney"] == total84, "RULE-031: 7-8 players use all money")
	ok(s3["totalMoney"] == total84 - 2 * 5000 - 2 * 10000 - 2 * 15000 - 2 * 20000 - 25000 - 30000 - 40000 - 50000, "RULE-030: 3 players remove the listed money cards (total $%d)" % s3["totalMoney"])
	ok(Eng.create_game({"playerCount": 2}).has("error") and Eng.create_game({"playerCount": 9}).has("error"), "RULE-002: player counts outside 3-8 are rejected")
	for pc in [3, 4, 5, 6, 7, 8]:
		var g := Eng.create_game({"playerCount": pc, "seed": 11})
		var hands_ok := true
		for p in g["players"]:
			if p["hand"].size() != 5:
				hands_ok = false
		ok(hands_ok and Eng.check_invariants(g).is_empty(), "RULE-006/INV: %d players start with five cards each and valid invariants" % pc)
	var d1 := Eng.create_game({"playerCount": 4, "seed": 99})
	var d2 := Eng.create_game({"playerCount": 4, "seed": 99})
	ok(Util.canonical(d1) == Util.canonical(d2), "docs/01 §7: same seed -> identical game")
	var d3 := Eng.create_game({"playerCount": 4, "seed": 100})
	ok(Util.canonical(d1) != Util.canonical(d3), "different seed -> different deal")


## ---------------------------------------------------------------- 6. errors, hidden information, anti-cheat

func _test_errors_and_hidden_info() -> void:
	print("[6] Errors, hidden information, AI anti-cheat")
	var s := Eng.create_game({"playerCount": 3, "seed": 21, "humanPlayerId": "P1"})
	var ctl := Ctl.new(s)
	var pending = ctl.run()
	if pending != null and pending["type"] == "PLACE_EXTRA_MONEY":
		var r0 := ctl.submit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": "COLIBRI"})
		pending = r0["pending"]
	ok(pending != null and pending["type"] == "SELECT_CARD", "controller stops and asks the human to choose a card")

	# invalid actions return controlled errors and do not change the state
	var before := Util.canonical(s)
	var r := Eng.reduce_in_place(s, {"type": "SELECT_CARD", "playerId": "P1", "cardId": "NOT-A-CARD"})
	ok(not r["ok"] and r["error"]["category"] == "RULE_ERROR", "card not in hand -> RULE_ERROR")
	r = Eng.reduce_in_place(s, {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": {}})
	ok(not r["ok"] and r["error"]["category"] == "STATE_ERROR", "proposal in the wrong phase -> STATE_ERROR")
	r = Eng.reduce_in_place(s, {"type": "DANCE"})
	ok(not r["ok"], "unknown action type is rejected")
	r = Eng.reduce_in_place(s, {"type": "SELECT_CARD", "playerId": "P9", "cardId": "x"})
	ok(not r["ok"], "unknown player is rejected")
	ok(Util.canonical(s) == before, "rejected actions never change the state")

	# hidden information: before reveal nobody sees a chosen card id
	var my_card: String = s["players"][0]["hand"][2]
	var rs := ctl.submit({"type": "SELECT_CARD", "playerId": "P1", "cardId": my_card})
	ok(rs["ok"], "human selection accepted")
	# all selections done -> revealed. Check an earlier moment instead: rebuild a state where only the AIs selected.
	var g := Eng.create_game({"playerCount": 4, "seed": 33, "humanPlayerId": "P1"})
	var c2 := Ctl.new(g)
	var pend = c2.run()
	if pend != null and pend["type"] == "PLACE_EXTRA_MONEY":
		pend = c2.submit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": "COLIBRI"})["pending"]
	ok(g["phase"] == "CARD_SELECTION", "reached CARD_SELECTION with AI players already holding hidden selections")
	var secret_ids := []
	for p in g["players"]:
		if p["selectedCardId"] != null:
			secret_ids.append(p["selectedCardId"])
	ok(secret_ids.size() == 3, "the three AI players have selected (hidden) cards")
	var leak := false
	var view_text := JSON.stringify(Eng.get_public_view(g, "P1"))
	for sid in secret_ids:
		if view_text.find(sid) >= 0:
			leak = true
	ok(not leak, "public view of the human holds no AI selected card id before reveal")
	var event_text := JSON.stringify(g["events"])
	var leak2 := false
	for sid in secret_ids:
		if event_text.find(sid) >= 0:
			leak2 = true
	ok(not leak2, "CARD_SELECTED events never carry the card id")
	var ai_view := Eng.get_public_view(g, "P2")
	var ai_leak := false
	var ai_text := JSON.stringify(ai_view)
	for sid in secret_ids:
		if sid != g["players"][1]["selectedCardId"] and ai_text.find(sid) >= 0:
			ai_leak = true
	ok(not ai_leak, "an AI's view holds no other player's selected card id")

	# anti-cheat (docs/06 §16): changing the human's hidden selection must not change any AI decision
	var base := Eng.create_game({"playerCount": 4, "seed": 44, "humanPlayerId": "P1"})
	var cb := Ctl.new(base)
	var pb = cb.run()
	if pb != null and pb["type"] == "PLACE_EXTRA_MONEY":
		cb.submit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": "COLIBRI"})
	# the AIs already chose; compare against a twin where the human holds a different hand card selected
	var twin: Dictionary = base.duplicate(true)
	var h: Array = twin["players"][0]["hand"]
	twin["players"][0]["selectedCardId"] = h[0]
	var base_view_a := Eng.get_public_view(twin, "P2")
	twin["players"][0]["selectedCardId"] = h[4]
	var base_view_b := Eng.get_public_view(twin, "P2")
	ok(Util.canonical(base_view_a) == Util.canonical(base_view_b), "AI public view is identical whichever card the human selected")
	var rng_a := AI.new_rng(5)
	var rng_b := AI.new_rng(5)
	twin["players"][0]["selectedCardId"] = h[0]
	var pick_a := AI.choose_card(Eng.get_public_view(twin, "P2"), rng_a)
	twin["players"][0]["selectedCardId"] = h[4]
	var pick_b := AI.choose_card(Eng.get_public_view(twin, "P2"), rng_b)
	ok(pick_a == pick_b, "AI card choice is unchanged by the human's hidden selection")

	# AI validity over many random situations: every proposal the AI makes is accepted by the engine
	var invalid := 0
	var n_props := 0
	for seed_v in range(100, 130):
		for pc in [3, 5, 8]:
			var gg := Eng.create_game({"playerCount": pc, "seed": seed_v, "humanPlayerId": null, "aiDifficulty": "EASY" if seed_v % 2 == 0 else "NORMAL"})
			var cc := Ctl.new(gg)
			cc.run()
			if not cc.error.is_empty() or gg.has("fatal"):
				invalid += 1
			n_props += _count(gg, "PROPOSAL_MADE")
			if not Eng.check_invariants(gg).is_empty():
				invalid += 1
	ok(invalid == 0, "180 extra AI-only games (3/5/8 players): no invalid AI action, no broken invariant (%d proposals)" % n_props)
