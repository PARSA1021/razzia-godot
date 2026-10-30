extends SceneTree
## Records and achievements (Phase 13): recording is exact, once per game, and never reads or changes the engine.
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const Rec = preload("res://ui/records.gd")
const Sum = preload("res://ui/game_summary.gd")
var checks := 0
var fails: Array = []


func _ok(name: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, extra])


func _play(n: int, seed_n: int) -> Dictionary:
	var s := Eng.create_game({"playerCount": n, "seed": seed_n, "humanPlayerId": "P1", "names": ["나", "B", "C", "D", "E", "F", "G", "H"].slice(0, n)})
	for p in s["players"]:
		p["isHuman"] = false
	Ctl.new(s).run()
	return s


func _initialize() -> void:
	Rec.path = "user://records_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Rec.path))
	var r := Rec.load_records()
	_ok("empty store: zero games", int(r["games"]) == 0 and r["achievements"].is_empty())
	var wins := 0
	var duel_wins := 0
	var duels := 0
	var played := 0
	var ach_seen := {}
	for sd in [5, 6, 7, 8, 9, 10, 11, 12]:
		var s := _play(4, sd)
		var summ := Sum.compute(s["events"], s["players"])
		var out := Rec.record_game(s, "P1")
		_ok("seed %d: recorded" % sd, out["recorded"])
		var again := Rec.record_game(s, "P1")
		_ok("seed %d: the same game is never recorded twice" % sd, not again["recorded"] and again["new"].is_empty())
		played += 1
		for e in s["events"]:
			if e["type"] == "GAME_ENDED" and "P1" in e["winnerIds"]:
				wins += 1
		duel_wins += int(summ["players"]["P1"]["duel_wins"])
		duels += int(summ["players"]["P1"]["duels"])
		for id in out["new"]:
			_ok("seed %d: achievement %s is new only once" % [sd, id], not ach_seen.has(id))
			ach_seen[id] = true
	r = Rec.load_records()
	_ok("games == %d" % played, int(r["games"]) == played)
	_ok("wins == %d" % wins, int(r["wins"]) == wins)
	_ok("duel totals match the engine events (%d/%d)" % [duel_wins, duels], int(r["totals"]["duel_wins"]) == duel_wins and int(r["totals"]["duels"]) == duels)
	_ok("history has one entry per game", r["history"].size() == played)
	_ok("by_count['4'] games == %d" % played, int(r["by_count"]["4"]["games"]) == played)
	_ok("unlocked achievements == the ones announced as new", r["achievements"].size() == ach_seen.size(), str(r["achievements"].keys()))
	_ok("games_10 not yet (8 games)", not r["achievements"].has("games_10"))
	for sd in [13, 14, 15]:
		Rec.record_game(_play(4, sd), "P1")
	r = Rec.load_records()
	_ok("games_10 unlocked after 10 games", r["achievements"].has("games_10"))
	# the file survives a reload and a corrupt file falls back to an empty record (never a crash)
	var f := FileAccess.open(Rec.path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var bad := Rec.load_records()
	_ok("corrupt file -> empty records", int(bad["games"]) == 0)
	# a human-less game is not recorded
	_ok("no human -> not recorded", not Rec.record_game(_play(3, 1), "")["recorded"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Rec.path))
	print("RECORDS TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("failed: ", fails)
	quit(0 if fails.is_empty() else 1)
