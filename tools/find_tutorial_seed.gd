extends SceneTree
## Finds seeds where the tutorial table plays out exactly as planned (ui/tutorial_plan.gd):
##   round 1 I take venue X alone, round 2 I offer first to Vito on Y, he refuses, I WIN the duel,
##   round 3 I deal the extra card and my police card shuts Mack out of Z. No other negotiation in those rounds.
##   godot --headless --path . --script res://tools/find_tutorial_seed.gd -- from=1 to=4000 [check=SEED]
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const AI = preload("res://ai/ai.gd")
const Plan = preload("res://ui/tutorial_plan.gd")


static func play(seed_v: int, extra_choice: int = 0) -> Dictionary:
	var s := Eng.create_game(Plan.config(seed_v))
	if s.has("error"):
		return {"ok": false, "why": "create: " + str(s["error"])}
	var ctl := Ctl.new(s)
	ctl.script_ai = func(k, pid, _v): return Plan.decide(ctl.state, k, pid)
	var rng := AI.new_rng(1)
	var pending = ctl.run()
	var log := {"human_cards": {}, "extra_prompt": false}
	var guard := 0
	while pending != null and int(ctl.state["round"]) <= Plan.ROUNDS and guard < 200:
		guard += 1
		var st: Dictionary = ctl.state
		var a := {}
		match pending["type"]:
			"SELECT_CARD":
				var t := Plan.human_target(st)
				if t.is_empty():
					return {"ok": false, "why": "round %d: no planned card" % int(st["round"])}
				log["human_cards"][int(st["round"])] = t["id"]
				a = {"type": "SELECT_CARD", "playerId": Plan.ME, "cardId": t["id"]}
			"PLACE_EXTRA_MONEY":
				log["extra_prompt"] = int(st["round"])
				var bars := []
				for b in st["bars"]:
					if b["active"]:
						bars.append(b["id"])
				a = {"type": "PLACE_EXTRA_MONEY", "playerId": Plan.ME, "barId": bars[extra_choice % bars.size()]}
			"MAKE_PROPOSAL":
				a = {"type": "MAKE_PROPOSAL", "playerId": Plan.ME, "allocations": AI.make_proposal(Eng.get_public_view(st, Plan.ME), rng)}
			"RESPOND":
				return {"ok": false, "why": "round %d: I was asked to respond" % int(st["round"])}
		var r := ctl.submit(a)
		if not r["ok"]:
			return {"ok": false, "why": "rejected: " + str(r["error"])}
		pending = r["pending"]
	# read the log
	var negs := {1: [], 2: [], 3: []}
	var res := {1: [], 2: [], 3: []}
	var duel_winner := ""
	var raid := {}
	var final_seen := false
	for ev in ctl.state["events"]:
		var rd := int(ev["round"])
		if rd < 1 or rd > 3:
			continue
		match str(ev["type"]):
			"NEGOTIATION_STARTED":
				negs[rd].append(ev)
			"BAR_RESOLVED":
				res[rd].append(ev)
			"DUEL_RESOLVED":
				if rd == 2:
					duel_winner = str(ev["winnerId"])
			"RAZZIA_ACTIVATED":
				if rd == 3 and Plan.ME in ev["razzias"]:
					raid = ev
			"FINAL_ROUND_ANNOUNCED":
				final_seen = true
	var single1 := false
	for e in res[1]:
		if str(e["kind"]) == "SINGLE_ZOCKER" and str(e.get("winnerId", "")) == Plan.ME:
			single1 = true
	var ok: bool = single1 and negs[1].is_empty() and negs[2].size() == 1 and negs[2][0]["proposerId"] == Plan.ME \
		and Plan.RIVAL in negs[2][0]["claimantIds"] and negs[2][0]["claimantIds"].size() == 2 and duel_winner == Plan.ME \
		and not raid.is_empty() and Plan.RAIDED in raid["shutOut"] and raid["razzias"].size() == 1 and negs[3].is_empty() \
		and int(log["extra_prompt"]) == 3 and not final_seen and int(ctl.state["round"]) == 4
	return {"ok": ok, "why": "single1=%s negs=%d/%d/%d duel=%s raid=%s extra=%s round=%d" % [single1, negs[1].size(), negs[2].size(), negs[3].size(), duel_winner, not raid.is_empty(), str(log["extra_prompt"]), int(ctl.state["round"])], "log": log}


func _init() -> void:
	var from := 1
	var to := 3000
	var check := -1
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		match kv[0]:
			"from": from = int(kv[1])
			"to": to = int(kv[1])
			"check": check = int(kv[1])
	if check >= 0:
		var all_ok := true
		for ch in range(6):
			var r := play(check, ch)
			print("check seed=%d extra_choice=%d -> %s (%s)" % [check, ch, r["ok"], r["why"]])
			all_ok = all_ok and r["ok"]
		print("TUTORIAL SEED %d: %s" % [check, "PASS" if all_ok else "FAIL"])
		quit(0 if all_ok else 1)
		return
	var found := []
	for sd in range(from, to + 1):
		var r := play(sd)
		if r["ok"]:
			# the free extra-card choice in round 3 must not change anything
			var stable := true
			for ch in range(1, 6):
				if not play(sd, ch)["ok"]:
					stable = false
			if stable:
				found.append(sd)
				print("seed %d OK %s" % [sd, str(r["log"]["human_cards"])])
				if found.size() >= 10:
					break
	print("FOUND: ", found)
	quit(0)
