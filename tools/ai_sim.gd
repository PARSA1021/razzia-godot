extends SceneTree
## AI-only simulation (no UI): difficulty ladder and personality profile.
##   godot --headless --path . --script res://tools/ai_sim.gd -- n=4 games=120 diffs=EASY,NORMAL,NORMAL,NORMAL
## Difficulties rotate over the seats every game so seat/personality bias cancels out. Prints per-difficulty and per-personality tables.
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")

func _initialize() -> void:
	var n := 4
	var games := 100
	var diffs: Array = []
	var base_seed := 1000
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		match kv[0]:
			"n": n = int(kv[1])
			"games": games = int(kv[1])
			"diffs": diffs = Array(kv[1].split(","))
			"seed": base_seed = int(kv[1])
	if diffs.is_empty():
		for i in range(n): diffs.append("NORMAL")
	var by_diff := {}
	var by_pers := {}
	for g in range(games):
		var s := Eng.create_game({"playerCount": n, "seed": base_seed + g, "humanPlayerId": null, "names": []})
		var assign := {}
		for i in range(n):
			var d: String = diffs[(i + g) % n]
			s["players"][i]["aiDifficulty"] = d
			assign[s["players"][i]["id"]] = {"d": d, "p": s["players"][i]["personality"]}
		Ctl.new(s).run()
		var winners: Array = []
		var rank := {}
		for e in s["events"]:
			if e["type"] == "GAME_ENDED":
				winners = e["winnerIds"]
		var money := {}
		for p in s["players"]: money[p["id"]] = int(p["money"])
		var total := 0
		for id in money: total += money[id]
		for p in s["players"]:
			var id: String = p["id"]
			var d: String = assign[id]["d"]
			var pe: String = assign[id]["p"]
			for key in [[by_diff, d], [by_pers, pe]]:
				var t: Dictionary = key[0].get(key[1], {"seats": 0, "wins": 0.0, "share": 0.0, "resp": 0, "duel": 0, "prop": 0, "prop_keep": 0.0, "duels": 0, "duel_won": 0})
				t["seats"] += 1
				if id in winners: t["wins"] += 1.0 / winners.size()
				t["share"] += float(money[id]) / maxf(1.0, float(total))
				key[0][key[1]] = t
		# behaviour from events
		var last_prop := {}
		for e in s["events"]:
			match e["type"]:
				"PROPOSAL_MADE":
					var a: Dictionary = assign[e["proposerId"]]
					for t in [by_diff[a["d"]], by_pers[a["p"]]]:
						t["prop"] += 1
					var alloc: Dictionary = e["proposal"] if e.has("proposal") else {}
					if alloc.has(e["proposerId"]):
						var tot := 0
						for k in alloc: tot += int(alloc[k])
						for t in [by_diff[a["d"]], by_pers[a["p"]]]:
							t["prop_keep"] += float(alloc[e["proposerId"]]) / maxf(1.0, float(tot))
				"PROPOSAL_ACCEPTED":
					var a2: Dictionary = assign[e["playerId"]]
					for t in [by_diff[a2["d"]], by_pers[a2["p"]]]:
						t["resp"] += 1
				"DUEL_CALLED":
					var a3: Dictionary = assign[e["playerId"]]
					for t in [by_diff[a3["d"]], by_pers[a3["p"]]]:
						t["resp"] += 1
						t["duel"] += 1
				"DUEL_RESOLVED":
					var w: String = e["winnerId"]
					for pid in [e["playerA"], e["playerB"]]:
						var a4: Dictionary = assign[pid]
						for t in [by_diff[a4["d"]], by_pers[a4["p"]]]:
							t["duels"] += 1
							if pid == w: t["duel_won"] += 1
	for title in ["난이도", "성격"]:
		var tab: Dictionary = by_diff if title == "난이도" else by_pers
		print("== %s (n=%d, games=%d, fair share = %.1f%%)" % [title, n, games, 100.0 / n])
		for k in tab:
			var t: Dictionary = tab[k]
			print("  %-12s seats=%4d win=%5.1f%% moneyShare=%5.1f%% duelCall=%5.1f%% (of %d responses) propKeep=%5.1f%% duelWin=%5.1f%% (%d duels)" % [
				k, t["seats"], 100.0 * t["wins"] / t["seats"], 100.0 * t["share"] / t["seats"],
				100.0 * t["duel"] / maxf(1.0, t["resp"]), t["resp"], 100.0 * t["prop_keep"] / maxf(1.0, t["prop"]),
				100.0 * t["duel_won"] / maxf(1.0, t["duels"]), t["duels"]])
	quit()
