extends RefCounted
## Game summary (Phase 13): everything the end-of-game board, the records and the achievements need, computed from the engine's
## own event log (state["events"]) — a pure function, no UI, no randomness, never touches the engine.
##
## compute(events, players) -> {
##   "rounds":  [{round, gained{pid:int}, money{pid:int}, razzia:bool}],        one entry per ROUND_ENDED
##   "players": {pid: {earned, duels, duel_wins, razzias, shut_out, solo_wins, deals, proposals, accepts, duel_calls, best_award, best_bar}},
##   "biggest_award": {pid, amount, barId, round}, "biggest_prize": {barId, prize, round, outcome},
##   "awards":  [{id, title, desc, pid}]      titles of the game (at most 4, each player at most 2)
## }

const T = preload("res://ui/tokens.gd")
const TITLE_MIN := {"duel_king": 2, "razzia": 2, "solo": 2, "dealer": 2}


static func _blank() -> Dictionary:
	return {"earned": 0, "duels": 0, "duel_wins": 0, "razzias": 0, "shut_out": 0, "solo_wins": 0, "deals": 0, "proposals": 0,
		"accepts": 0, "duel_calls": 0, "best_award": 0, "best_bar": ""}


static func compute(events: Array, players: Array) -> Dictionary:
	var st := {}
	for p in players:
		st[p["id"]] = _blank()
	var rounds: Array = []
	var biggest_award := {"pid": "", "amount": 0, "barId": "", "round": 0}
	var biggest_prize := {"barId": "", "prize": 0, "round": 0, "outcome": ""}
	var razzia_round := false
	var proposer_of := {}
	for e in events:
		match e["type"]:
			"MONEY_AWARDED":
				var pid: String = e["playerId"]
				if not st.has(pid):
					continue
				var amt := int(e["amount"])
				st[pid]["earned"] += amt
				if amt > int(st[pid]["best_award"]):
					st[pid]["best_award"] = amt
					st[pid]["best_bar"] = e["barId"]
				if amt > int(biggest_award["amount"]):
					biggest_award = {"pid": pid, "amount": amt, "barId": e["barId"], "round": int(e["round"])}
			"RAZZIA_ACTIVATED":
				razzia_round = true
				for pid in e["razzias"]:
					if st.has(pid):
						st[pid]["razzias"] += 1
				for pid in e["shutOut"]:
					if st.has(pid):
						st[pid]["shut_out"] += 1
			"BAR_RESOLVED":
				if e.get("kind", "") == "SINGLE_ZOCKER" and st.has(e["winnerId"]):
					st[e["winnerId"]]["solo_wins"] += 1
				if e.has("outcome"):
					if int(e.get("money", 0)) > int(biggest_prize["prize"]):
						biggest_prize = {"barId": e["barId"], "prize": int(e["money"]), "round": int(e["round"]), "outcome": e["outcome"]}
					if e["outcome"] == "DEAL" and st.has(e.get("proposerId", "")):
						st[e["proposerId"]]["deals"] += 1
			"PROPOSAL_MADE":
				if st.has(e["proposerId"]):
					st[e["proposerId"]]["proposals"] += 1
			"PROPOSAL_ACCEPTED":
				if st.has(e["playerId"]):
					st[e["playerId"]]["accepts"] += 1
			"DUEL_CALLED":
				if st.has(e["playerId"]):
					st[e["playerId"]]["duel_calls"] += 1
			"DUEL_RESOLVED":
				for pid in [e["playerA"], e["playerB"]]:
					if st.has(pid):
						st[pid]["duels"] += 1
				if st.has(e["winnerId"]):
					st[e["winnerId"]]["duel_wins"] += 1
			"ROUND_ENDED":
				rounds.append({"round": int(e["round"]), "gained": e["gained"].duplicate(), "money": e["money"].duplicate(), "razzia": razzia_round})
				razzia_round = false
	return {"rounds": rounds, "players": st, "biggest_award": biggest_award, "biggest_prize": biggest_prize, "awards": _awards(st, players)}


## Highest value of `key` (>= minimum); a tie goes to the lower seat, so the result never depends on dictionary order.
static func _top(st: Dictionary, players: Array, key: String, minimum: int, exclude: Array) -> String:
	var best := ""
	var best_v := minimum - 1
	for p in players:
		var pid: String = p["id"]
		if pid in exclude:
			continue
		var v := int(st[pid][key])
		if v > best_v:
			best_v = v
			best = pid
	return best


static func _awards(st: Dictionary, players: Array) -> Array:
	var out: Array = []
	var count := {}
	var specs := [
		["duel_king", "결투왕", "duel_wins", "duel_king", func(v): return T.t("결투 %d승") % v],
		["razzia", "단속반장", "razzias", "razzia", func(v): return T.t("RAZZIA 발동 %d회") % v],
		["solo", "독점왕", "solo_wins", "solo", func(v): return T.t("혼자 차지한 술집 %d곳") % v],
		["dealer", "협상가", "deals", "dealer", func(v): return T.t("제안이 그대로 통과된 협상 %d번") % v],
	]
	for sp in specs:
		var pid := _top(st, players, sp[2], int(TITLE_MIN[sp[3]]), [])
		if pid == "" or int(count.get(pid, 0)) >= 2:
			continue
		count[pid] = int(count.get(pid, 0)) + 1
		out.append({"id": sp[0], "title": sp[1], "desc": sp[4].call(int(st[pid][sp[2]])), "pid": pid})
	return out


## Money of every player after each round, for the line chart: {pid: [after round 1, after round 2, ...]}.
static func money_series(summary: Dictionary, players: Array) -> Dictionary:
	var s := {}
	for p in players:
		s[p["id"]] = []
		for r in summary["rounds"]:
			s[p["id"]].append(int(r["money"].get(p["id"], 0)))
	return s


## The round in which `pid` gained the most (0 when never).
static func best_round(summary: Dictionary, pid: String) -> Dictionary:
	var best := {"round": 0, "gained": 0}
	for r in summary["rounds"]:
		var g := int(r["gained"].get(pid, 0))
		if g > int(best["gained"]):
			best = {"round": int(r["round"]), "gained": g}
	return best
