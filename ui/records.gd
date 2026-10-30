extends RefCounted
## Records and achievements (Phase 13): what the human player has done over all games. Stored in user://records.json.
## Presentation-side only: it reads the finished game (GameSummary + the engine's event log) and never touches the engine, the AI
## or the save format of a running game. Each finished game is recorded once (key = seed + player count), so replays / resumes
## can never count a game twice.

const Sum = preload("res://ui/game_summary.gd")

static var path := preload("res://ui/settings.gd").test_file("records.json")        # tests point this at a scratch file
const VERSION := 1
const HISTORY_MAX := 20

## id -> [title, description, kind]; kind "game" = decided by one finished game, "total" = by the totals over all games
const ACHIEVEMENTS := {
	"first_win": ["첫 승리", "게임에서 처음으로 우승", "game"],
	"first_razzia": ["경찰을 불러라", "한 판에서 RAZZIA를 한 번 발동", "game"],
	"duel_3": ["결투의 맛", "한 판에서 결투 3승", "game"],
	"duel_flawless": ["무패의 결투사", "결투를 2번 이상 하고 모두 승리", "game"],
	"solo_5": ["독점 사업", "한 판에서 혼자 차지한 술집 5곳 이상", "game"],
	"big_hit": ["대박", "한 번에 $150,000 이상 획득", "game"],
	"big_round": ["풍년", "한 라운드에서 $200,000 이상 획득", "game"],
	"dealmaker": ["협상의 달인", "내 제안이 그대로 통과된 협상 3번 이상", "game"],
	"comeback": ["역전극", "6라운드 종료 때 꼴찌였다가 우승", "game"],
	"full_table": ["만원 테이블", "8인 게임에서 우승", "game"],
	"games_10": ["단골손님", "게임 10판 완료", "total"],
	"wins_5": ["이 구역의 주인", "누적 5승", "total"],
	"streak_3": ["연승 행진", "3연승", "total"],
}
const ORDER := ["first_win", "first_razzia", "duel_3", "duel_flawless", "solo_5", "big_hit", "big_round", "dealmaker", "comeback", "full_table", "games_10", "wins_5", "streak_3"]


static func blank() -> Dictionary:
	return {"version": VERSION, "games": 0, "wins": 0, "streak": 0, "best_streak": 0,
		"totals": {"rounds": 0, "earned": 0, "duels": 0, "duel_wins": 0, "razzias": 0, "shut_out": 0, "solo_wins": 0, "deals": 0, "proposals": 0, "accepts": 0, "duel_calls": 0},
		"best": {"money": 0, "award": 0, "round_gain": 0},
		"by_count": {}, "achievements": {}, "history": [], "keys": []}


static func load_records() -> Dictionary:
	if not FileAccess.file_exists(path):
		return blank()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return blank()
	var r := blank()
	for k in r:
		if parsed.has(k) and (typeof(parsed[k]) == typeof(r[k]) or (typeof(parsed[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(r[k]) in [TYPE_INT, TYPE_FLOAT])):
			r[k] = parsed[k]
	# JSON numbers come back as floats
	for k in ["games", "wins", "streak", "best_streak"]:
		r[k] = int(r[k])
	for sub in ["totals", "best"]:
		for k in r[sub]:
			r[sub][k] = int(r[sub][k])
	return r


static func save_records(r: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(r))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


static func game_key(state: Dictionary) -> String:
	return "%s-%s" % [str(state["config"]["seed"]), str(state["players"].size())]


## Pure: which "game" achievements this finished game earns.
static func game_achievements(summary: Dictionary, state: Dictionary, human_id: String) -> Array:
	var out: Array = []
	if not summary["players"].has(human_id):
		return out
	var me: Dictionary = summary["players"][human_id]
	var ranking: Array = []
	var winners: Array = []
	for e in state["events"]:
		if e["type"] == "GAME_ENDED":
			ranking = e["ranking"]
			winners = e["winnerIds"]
	var won := human_id in winners
	if won:
		out.append("first_win")
	if int(me["razzias"]) >= 1:
		out.append("first_razzia")
	if int(me["duel_wins"]) >= 3:
		out.append("duel_3")
	if int(me["duels"]) >= 2 and int(me["duel_wins"]) == int(me["duels"]):
		out.append("duel_flawless")
	if int(me["solo_wins"]) >= 5:
		out.append("solo_5")
	if int(me["best_award"]) >= 150000:
		out.append("big_hit")
	if int(Sum.best_round(summary, human_id)["gained"]) >= 200000:
		out.append("big_round")
	if int(me["deals"]) >= 3:
		out.append("dealmaker")
	if won and summary["rounds"].size() >= 6:
		var after6: Dictionary = summary["rounds"][5]["money"]
		var lowest := true
		var mine := int(after6.get(human_id, 0))
		for pid in after6:
			if pid != human_id and int(after6[pid]) <= mine:
				lowest = false
		if lowest:
			out.append("comeback")
	if won and state["players"].size() >= 8:
		out.append("full_table")
	return out


## Records one finished game. Returns {"recorded": bool, "new": [achievement ids unlocked now]}.
static func record_game(state: Dictionary, human_id: String) -> Dictionary:
	if human_id == "":
		return {"recorded": false, "new": []}
	var r := load_records()
	var key := game_key(state)
	if key in r["keys"]:
		return {"recorded": false, "new": []}
	var summary := Sum.compute(state["events"], state["players"])
	var me: Dictionary = summary["players"][human_id]
	var winners: Array = []
	var ranking: Array = []
	for e in state["events"]:
		if e["type"] == "GAME_ENDED":
			winners = e["winnerIds"]
			ranking = e["ranking"]
	var won := human_id in winners
	r["games"] += 1
	if won:
		r["wins"] += 1
		r["streak"] += 1
		r["best_streak"] = maxi(int(r["best_streak"]), int(r["streak"]))
	else:
		r["streak"] = 0
	var t: Dictionary = r["totals"]
	t["rounds"] += summary["rounds"].size()
	for k in ["earned", "duels", "duel_wins", "razzias", "shut_out", "solo_wins", "deals", "proposals", "accepts", "duel_calls"]:
		t[k] = int(t[k]) + int(me[k])
	var final_money := 0
	var rank := 0
	var i := 0
	for x in ranking:
		i += 1
		if x["playerId"] == human_id:
			final_money = int(x["money"])
			rank = i
	r["best"]["money"] = maxi(int(r["best"]["money"]), final_money)
	r["best"]["award"] = maxi(int(r["best"]["award"]), int(me["best_award"]))
	r["best"]["round_gain"] = maxi(int(r["best"]["round_gain"]), int(Sum.best_round(summary, human_id)["gained"]))
	var c := str(state["players"].size())
	var bc: Dictionary = r["by_count"].get(c, {"games": 0, "wins": 0})
	bc["games"] = int(bc["games"]) + 1
	bc["wins"] = int(bc["wins"]) + (1 if won else 0)
	r["by_count"][c] = bc
	r["history"].append({"players": state["players"].size(), "rank": rank, "money": final_money, "won": won, "rounds": summary["rounds"].size()})
	while r["history"].size() > HISTORY_MAX:
		r["history"].pop_front()
	r["keys"].append(key)
	while r["keys"].size() > 200:
		r["keys"].pop_front()
	# achievements: per game, then totals (after the totals above were updated)
	var newly: Array = []
	var earned: Array = game_achievements(summary, state, human_id)
	if int(r["games"]) >= 10:
		earned.append("games_10")
	if int(r["wins"]) >= 5:
		earned.append("wins_5")
	if int(r["best_streak"]) >= 3:
		earned.append("streak_3")
	for id in ORDER:
		if id in earned and not r["achievements"].has(id):
			r["achievements"][id] = int(r["games"])
			newly.append(id)
	save_records(r)
	return {"recorded": true, "new": newly}


static func win_rate(r: Dictionary) -> float:
	return float(r["wins"]) / float(r["games"]) if int(r["games"]) > 0 else 0.0
