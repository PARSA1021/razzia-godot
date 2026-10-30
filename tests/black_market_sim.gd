extends SceneTree
## Phase 3-A: Black Market Shop & Roguelike Loop Simulation Benchmark
## Simulates 200 games per purchasing strategy (1,000 total games) across identical seeds.
## Evaluates:
## 1. NO_BUY (Baseline: hoards cash, buys nothing)
## 2. INFORMANT_FIRST (Priority: The Informant for $25k)
## 3. BRIBED_JUDGE_FIRST (Priority: Bribed Judge for $30k)
## 4. DIRTY_COP_FIRST (Priority: Dirty Cop for $35k)
## 5. SURPLUS_ONLY (Conservative: buys only when cash > $80k)

const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const RelicManager = preload("res://engine/relic_manager.gd")

const MATCHES_PER_STRATEGY := 200
const BASE_SEED := 20000


func _init() -> void:
	print("==================================================")
	print("Phase 3: 8-Relic Catalog & Strategy Simulation Benchmark")
	print("Simulating %d games per archetype strategy (4 Players, NORMAL AI)" % MATCHES_PER_STRATEGY)
	print("==================================================")

	var strategies := ["NO_BUY", "STARTER_DUEL", "STARTER_ECONOMY", "STARTER_INFO", "BALANCED_BUILD"]
	var results := {}

	for strat in strategies:
		results[strat] = _simulate_strategy(strat)

	_print_report(results)
	quit(0)


func _simulate_strategy(strat: String) -> Dictionary:
	var wins := 0.0
	var total_final_money := 0
	var total_spent := 0
	var total_duels := 0
	var relic_purchases := {}
	var relic_triggers := {}
	for rid in RelicManager.RELICS.keys():
		relic_purchases[rid] = 0
		relic_triggers[rid] = 0

	for i in range(MATCHES_PER_STRATEGY):
		var seed_n: int = BASE_SEED + i
		var cfg := {
			"playerCount": 4,
			"seed": seed_n,
			"humanPlayerId": null,
			"names": ["Player P1", "AI 2", "AI 3", "AI 4"],
			"aiDifficulty": "NORMAL",
			"relics": [],
		}
		var s := Eng.create_game(cfg)

		# Assign starter relic per archetype
		match strat:
			"STARTER_DUEL":
				RelicManager.add_relic(s, "P1", "lucky_coin")
			"STARTER_ECONOMY":
				RelicManager.add_relic(s, "P1", "protection_racket")
			"STARTER_INFO":
				RelicManager.add_relic(s, "P1", "informant")
			"BALANCED_BUILD":
				RelicManager.add_relic(s, "P1", "lucky_coin")

		var ctl = Ctl.new(s)
		var last_ev_checked: Array = [0]
		ctl.on_action = func(st: Dictionary, _act: Dictionary):
			var evs: Array = st.get("events", [])
			while last_ev_checked[0] < evs.size():
				var e: Dictionary = evs[last_ev_checked[0]]
				last_ev_checked[0] += 1
				if e["type"] == "ROUND_ENDED" and not bool(e.get("finalRound", false)):
					_execute_shop_decision(st, "P1", strat, relic_purchases)

		ctl.run()

		for p in s["players"]:
			if p["id"] == "P1":
				total_final_money += int(p["money"])
		total_spent += int(s.get("blackMarketVault", 0))

		for e in s["events"]:
			match e["type"]:
				"GAME_ENDED":
					if "P1" in e.get("winnerIds", []):
						wins += 1.0 / float(e["winnerIds"].size())
				"DUEL_RESOLVED":
					total_duels += 1
				"RELIC_TRIGGERED":
					var rid: String = str(e.get("relicId", ""))
					if relic_triggers.has(rid) and e.get("playerId") == "P1":
						relic_triggers[rid] += 1

	var total_trig := 0
	for count_val in relic_triggers.values():
		total_trig += count_val

	return {
		"win_rate": (wins / float(MATCHES_PER_STRATEGY)) * 100.0,
		"avg_final_money": total_final_money / MATCHES_PER_STRATEGY,
		"avg_spent": total_spent / MATCHES_PER_STRATEGY,
		"duels_per_game": float(total_duels) / float(MATCHES_PER_STRATEGY),
		"purchases": relic_purchases,
		"triggers": relic_triggers,
		"triggers_per_game": float(total_trig) / float(MATCHES_PER_STRATEGY),
	}


func _execute_shop_decision(s: Dictionary, pid: String, strat: String, purchase_tracker: Dictionary) -> void:
	if strat == "NO_BUY":
		return

	var priority_order: Array = []
	match strat:
		"STARTER_DUEL":
			priority_order = ["loaded_dice", "bribed_judge", "syndicate_crest", "swiss_account"]
		"STARTER_ECONOMY":
			priority_order = ["swiss_account", "dirty_cop", "syndicate_crest", "protection_racket"]
		"STARTER_INFO":
			priority_order = ["bribed_judge", "swiss_account", "syndicate_crest", "lucky_coin"]
		"BALANCED_BUILD":
			priority_order = ["protection_racket", "loaded_dice", "swiss_account", "syndicate_crest"]

	for rid in priority_order:
		if RelicManager.can_afford(s, pid, rid) and not RelicManager.has_relic(s, pid, rid):
			var res = RelicManager.buy_relic(s, pid, rid)
			if res.get("ok", false):
				purchase_tracker[rid] += 1
				break


func _print_report(results: Dictionary) -> void:
	print("\n---------------- 8-RELIC STRATEGY BENCHMARK (200 Matches Each) ----------------")
	print("%-16s | %-9s | %-12s | %-10s | %-10s | %-12s" % [
		"Strategy", "Win Rate", "Avg Money", "Avg Spent", "Duels/Gm", "Triggers/Gm"
	])
	print("--------------------------------------------------------------------------------")
	for k in results.keys():
		var r: Dictionary = results[k]
		print("%-16s | %8.1f%% | $%-11d | $%-9d | %9.2f | %11.2f" % [
			k, r["win_rate"], r["avg_final_money"], r["avg_spent"], r["duels_per_game"], r["triggers_per_game"]
		])
	print("--------------------------------------------------------------------------------\n")
