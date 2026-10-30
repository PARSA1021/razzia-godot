extends SceneTree
## Phase 2-G: Relic Balance and Simulation Benchmark
## Runs 200 matches per configuration with identical seeds to evaluate:
## 1. Win rates (P1 vs AI)
## 2. Average end-game bankroll
## 3. Relic trigger frequencies
## 4. Duel frequency & tie-break rates
## 5. Raid failure rate & Dirty Cop extortion yield

const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const RelicManager = preload("res://engine/relic_manager.gd")

const MATCHES_PER_CONFIG := 200
const BASE_SEED := 10000


func _init() -> void:
	print("==================================================")
	print("Phase 2-G: Relic Balance & Simulation Benchmark")
	print("Simulating %d games per configuration (4 Players, NORMAL AI)" % MATCHES_PER_CONFIG)
	print("==================================================")

	var configs := {
		"CLASSIC": [],
		"INFORMANT": ["informant"],
		"BRIBED_JUDGE": ["bribed_judge"],
		"DIRTY_COP": ["dirty_cop"],
		"ALL_THREE": ["informant", "bribed_judge", "dirty_cop"],
	}

	var results := {}
	for cfg_name in configs.keys():
		results[cfg_name] = _simulate_batch(cfg_name, configs[cfg_name])

	_print_report(results)
	quit(0)


func _simulate_batch(name: String, relics: Array) -> Dictionary:
	var wins := 0.0
	var total_p1_money := 0
	var total_duels := 0
	var total_ties := 0
	var total_raids := 0
	var failed_raids := 0
	var relic_triggers := {
		"informant": 0,
		"bribed_judge": 0,
		"dirty_cop": 0,
	}
	var total_bribes_collected := 0

	for i in range(MATCHES_PER_CONFIG):
		var seed_n: int = BASE_SEED + i
		var cfg := {
			"playerCount": 4,
			"seed": seed_n,
			"humanPlayerId": null, # all AI drivers for deterministic simulation
			"names": ["Target P1", "AI 2", "AI 3", "AI 4"],
			"aiDifficulty": "NORMAL",
		}
		if not relics.is_empty():
			cfg["relics"] = relics

		var s := Eng.create_game(cfg)
		# Assign relics explicitly to P1 for benchmark evaluation
		for r in relics:
			RelicManager.add_relic(s, "P1", r)

		var ctl = Ctl.new(s)
		ctl.run()

		# Collect game stats
		for p in s["players"]:
			if p["id"] == "P1":
				total_p1_money += int(p["money"])

		for e in s["events"]:
			match e["type"]:
				"GAME_ENDED":
					if "P1" in e.get("winnerIds", []):
						wins += 1.0 / float(e["winnerIds"].size())
				"DUEL_RESOLVED":
					total_duels += 1
					if bool(e.get("tie", false)):
						total_ties += 1
				"BAR_RESOLVED":
					if str(e.get("kind", "")) == "RAZZIA_NO_ZOCKER":
						failed_raids += 1
						total_raids += 1
					elif str(e.get("kind", "")) in ["RAZZIA", "RAZZIA_SOLE_CLAIMANT"]:
						total_raids += 1
				"RELIC_TRIGGERED":
					var rid: String = str(e.get("relicId", ""))
					if relic_triggers.has(rid) and e.get("playerId") == "P1":
						relic_triggers[rid] += 1
						if rid == "dirty_cop":
							total_bribes_collected += int(e.get("amount", 0))

	return {
		"win_rate": (wins / float(MATCHES_PER_CONFIG)) * 100.0,
		"avg_money": total_p1_money / MATCHES_PER_CONFIG,
		"total_duels": total_duels,
		"duels_per_game": float(total_duels) / float(MATCHES_PER_CONFIG),
		"ties_per_game": float(total_ties) / float(MATCHES_PER_CONFIG),
		"raids_per_game": float(total_raids) / float(MATCHES_PER_CONFIG),
		"failed_raid_pct": (float(failed_raids) / float(maxi(1, total_raids))) * 100.0,
		"triggers": relic_triggers,
		"avg_bribe": total_bribes_collected / MATCHES_PER_CONFIG,
	}


func _print_report(results: Dictionary) -> void:
	print("\n---------------- SIMULATION RESULTS (200 Matches Each) ----------------")
	print("%-14s | %-9s | %-12s | %-10s | %-12s | %-10s" % [
		"Configuration", "Win Rate", "Avg Money", "Duels/Game", "Triggers/Gm", "Bribe/Game"
	])
	print("------------------------------------------------------------------------")
	for k in results.keys():
		var r: Dictionary = results[k]
		var total_trig: int = 0
		for t in r["triggers"].values():
			total_trig += t
		var trig_per_gm: float = float(total_trig) / float(MATCHES_PER_CONFIG)
		print("%-14s | %8.1f%% | $%-11d | %10.2f | %12.2f | $%-9d" % [
			k, r["win_rate"], r["avg_money"], r["duels_per_game"], trig_per_gm, r["avg_bribe"]
		])
	print("------------------------------------------------------------------------\n")
