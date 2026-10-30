extends SceneTree
## Game summary (Phase 13): AI-only games, the summary is checked against the engine's own numbers.
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const Sum = preload("res://ui/game_summary.gd")
var checks := 0
var fails: Array = []


func _ok(name: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, extra])


func _play(n: int, seed_n: int) -> Dictionary:
	var names := ["A", "B", "C", "D", "E", "F", "G", "H"].slice(0, n)
	var s := Eng.create_game({"playerCount": n, "seed": seed_n, "humanPlayerId": "P1", "names": names})
	for p in s["players"]:
		p["isHuman"] = false                  # AI-only game
	var ctl := Ctl.new(s)
	ctl.run()
	return s


func _initialize() -> void:
	for cfg in [[3, 1], [4, 5], [5, 21], [6, 12], [8, 4]]:
		var s := _play(cfg[0], cfg[1])
		var tag := "%dp seed %d" % cfg
		_ok("%s: game finished" % tag, s["phase"] == "GAME_END" or s["events"].back()["type"] == "GAME_ENDED", s["phase"])
		var sum: Dictionary = Sum.compute(s["events"], s["players"])
		# 1) earnings per player == money in the final ROUND_ENDED
		var last: Dictionary = {}
		for e in s["events"]:
			if e["type"] == "ROUND_ENDED":
				last = e
		var ok_money := true
		for p in s["players"]:
			if int(sum["players"][p["id"]]["earned"]) != int(last["money"][p["id"]]):
				ok_money = false
		_ok("%s: summed MONEY_AWARDED == final money for every player" % tag, ok_money)
		var n_rounds := 0
		for e in s["events"]:
			if e["type"] == "ROUND_ENDED":
				n_rounds += 1
		_ok("%s: one summary row per round (%d)" % [tag, n_rounds], sum["rounds"].size() == n_rounds)
		# 2) per-round gains add up to the same totals
		var by_round := {}
		for r in sum["rounds"]:
			for pid in r["gained"]:
				by_round[pid] = int(by_round.get(pid, 0)) + int(r["gained"][pid])
		var ok_r := true
		for p in s["players"]:
			if int(by_round.get(p["id"], 0)) != int(sum["players"][p["id"]]["earned"]):
				ok_r = false
		_ok("%s: round gains add up to the totals" % tag, ok_r)
		# 3) duels: wins <= duels; every duel has exactly one winner
		var duels := 0
		for e in s["events"]:
			if e["type"] == "DUEL_RESOLVED":
				duels += 1
		var wins := 0
		var sides := 0
		var wins_ok := true
		for p in s["players"]:
			var d: Dictionary = sum["players"][p["id"]]
			wins += int(d["duel_wins"])
			sides += int(d["duels"])
			if int(d["duel_wins"]) > int(d["duels"]):
				wins_ok = false
		_ok("%s: duel record consistent (%d duels, %d wins, %d fighter slots)" % [tag, duels, wins, sides], wins == duels and sides == 2 * duels and wins_ok)
		# 4) biggest award really is the maximum
		var mx := 0
		for e in s["events"]:
			if e["type"] == "MONEY_AWARDED":
				mx = maxi(mx, int(e["amount"]))
		_ok("%s: biggest award == max MONEY_AWARDED (%d)" % [tag, mx], int(sum["biggest_award"]["amount"]) == mx)
		# 5) titles: at most 4, each player at most 2, valid players, deterministic
		var cnt := {}
		for a in sum["awards"]:
			cnt[a["pid"]] = int(cnt.get(a["pid"], 0)) + 1
		var cmax := 0
		for k in cnt:
			cmax = maxi(cmax, int(cnt[k]))
		_ok("%s: titles <= 4 and <= 2 per player (%d titles)" % [tag, sum["awards"].size()], sum["awards"].size() <= 4 and cmax <= 2)
		var sum2: Dictionary = Sum.compute(s["events"], s["players"])
		_ok("%s: deterministic" % tag, JSON.stringify(sum) == JSON.stringify(sum2))
		var series := Sum.money_series(sum, s["players"])
		_ok("%s: money series has one point per round" % tag, series["P1"].size() == n_rounds)
	print("SUMMARY TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("failed: ", fails)
	quit(0 if fails.is_empty() else 1)
