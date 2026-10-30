extends SceneTree
## AI levels (Phase 13b): every level plays complete legal games, the ladder EASY < NORMAL < HARD holds on fixed seeds,
## and the personalities keep their documented order of duel-calling (CONSERVATIVE < OPPORTUNIST < AGGRESSIVE).
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
var checks := 0
var fails: Array = []

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _play(n: int, seed_n: int, diffs: Array) -> Dictionary:
	var s := Eng.create_game({"playerCount": n, "seed": seed_n, "humanPlayerId": null, "names": []})
	for i in range(n):
		s["players"][i]["aiDifficulty"] = diffs[i % diffs.size()]
	Ctl.new(s).run()
	return s

func _initialize() -> void:
	for d in ["EASY", "NORMAL", "HARD"]:
		var ok := true
		for sd in range(20):
			var s := _play(4, 500 + sd, [d])
			var ended := false
			var errs := 0
			for e in s["events"]:
				if e["type"] == "GAME_ENDED": ended = true
			ok = ok and ended
		_ok("%s: 20 complete games (4p)" % d, ok)
	for n in [3, 5, 8]:
		var s := _play(n, 77, ["HARD"])
		var ended := false
		for e in s["events"]:
			if e["type"] == "GAME_ENDED": ended = true
		_ok("HARD plays a full %d-player game" % n, ended)
	# ladder: one challenger of each level against three NORMAL, seats rotated, fixed seeds
	var rate := {}
	for lvl in ["EASY", "HARD"]:
		var wins := 0.0
		var seats := 0
		for g in range(600):
			var s := Eng.create_game({"playerCount": 4, "seed": 9000 + g, "humanPlayerId": null, "names": []})
			for i in range(4):
				s["players"][i]["aiDifficulty"] = lvl if i == g % 4 else "NORMAL"
			Ctl.new(s).run()
			for e in s["events"]:
				if e["type"] == "GAME_ENDED" and ("P%d" % (g % 4 + 1)) in e["winnerIds"]:
					wins += 1.0 / e["winnerIds"].size()
			seats += 1
		rate[lvl] = wins / seats
	_ok("ladder: EASY (%.1f%%) < fair 25%% < HARD (%.1f%%) against NORMAL" % [rate["EASY"] * 100, rate["HARD"] * 100], rate["EASY"] < 0.21 and rate["HARD"] > 0.27)
	# personalities: all NORMAL, 6 players
	var calls := {}
	var resp := {}
	for g in range(400):
		var s := _play(6, 3000 + g, ["NORMAL"])
		var pers := {}
		for p in s["players"]: pers[p["id"]] = p["personality"]
		for e in s["events"]:
			if e["type"] == "DUEL_CALLED" or e["type"] == "PROPOSAL_ACCEPTED":
				var k: String = pers[e["playerId"]]
				resp[k] = int(resp.get(k, 0)) + 1
				if e["type"] == "DUEL_CALLED": calls[k] = int(calls.get(k, 0)) + 1
	var rc: float = float(calls["CONSERVATIVE"]) / resp["CONSERVATIVE"]
	var ro: float = float(calls["OPPORTUNIST"]) / resp["OPPORTUNIST"]
	var ra: float = float(calls["AGGRESSIVE"]) / resp["AGGRESSIVE"]
	_ok("duel-call order CONSERVATIVE %.0f%% < OPPORTUNIST %.0f%% < AGGRESSIVE %.0f%%" % [rc * 100, ro * 100, ra * 100], rc < ro and ro < ra)
	print("AI LEVELS TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
