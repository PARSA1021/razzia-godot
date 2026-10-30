extends SceneTree
## The one-line round note (Phase 18) must describe what actually happened to the player — never a guess, never a
## "what if". Each case is built from the same three display records the board itself uses.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_round_note_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")

var checks := 0
var fails: Array = []
var started := false
var game


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


## plays: [[playerId, barId, type, symbol], ...]; awards: {playerId: [[bar, amount]]}
func _note(plays: Array, reasons: Dictionary, awards: Dictionary, gained: Dictionary) -> String:
	game._round_plays = []
	for p in plays:
		game._round_plays.append({"playerId": p[0], "barId": p[1], "type": p[2], "dieSymbol": p[3]})
	game._round_reason = reasons.duplicate()
	game._round_awards = {}
	for pid in awards:
		var list := []
		for a in awards[pid]:
			list.append({"bar": a[0], "amount": a[1]})
		game._round_awards[pid] = list
	return game._my_round_note({"gained": gained, "money": {}, "round": 3, "finalRound": false})


func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 4, "seed": 4, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	game.bot = func(_p, _v, _g): return {}
	root.add_child(game)
	game.begin(s)
	await _frames(20)

	# 1) alone at a venue
	var n1 := _note([["P1", "COLIBRI", "ZOCKER", 4]], {"COLIBRI": "단독 도박꾼"}, {"P1": [["COLIBRI", 30000]]}, {"P1": 30000})
	_ok("alone: names the venue and the money", "COLIBRI" in n1 and "혼자" in n1 and "+$30,000" in n1, n1)

	# 2) shared by agreement
	var n2 := _note([["P1", "COLIBRI", "ZOCKER", 4], ["P2", "COLIBRI", "ZOCKER", 5]], {"COLIBRI": "합의 분배"},
		{"P1": [["COLIBRI", 10000]], "P2": [["COLIBRI", 20000]]}, {"P1": 10000, "P2": 20000})
	_ok("deal: says how many it was split with", "합의" in n2 and "1명" in n2 and "+$10,000" in n2, n2)

	# 3) lost a duel
	var n3 := _note([["P1", "COLIBRI", "ZOCKER", 2], ["P2", "COLIBRI", "ZOCKER", 6]], {"COLIBRI": "결투 결과"},
		{"P2": [["COLIBRI", 40000]]}, {"P1": 0, "P2": 40000})
	_ok("lost duel: says it was a duel and that nothing was paid", "결투" in n3 and "COLIBRI" in n3, n3)
	_ok("lost duel: the round's best payout is named", "Vito" in n3 and "$40,000" in n3, n3)

	# 4) thrown out by a police card
	var n4 := _note([["P1", "COLIBRI", "ZOCKER", 3], ["P2", "COLIBRI", "RAZZIA", 4]], {"COLIBRI": "RAZZIA 단속 보상"},
		{"P2": [["COLIBRI", 25000]]}, {"P1": 0, "P2": 25000})
	_ok("raided: says the player was thrown out and how many police cards", "쫓겨났" in n4 and "경찰 카드 1장" in n4, n4)

	# 5) my venue did not resolve at all
	var n5 := _note([["P1", "JAZZ_HOUSE", "ZOCKER", 1]], {"COLIBRI": "단독 도박꾼"}, {"P2": [["COLIBRI", 15000]]}, {"P1": 0, "P2": 15000})
	_ok("not resolved: says the money is still piling up", "정리되지 않" in n5 and "JAZZ HOUSE" in n5, n5)

	# 6) police reward for me
	var n6 := _note([["P1", "COLIBRI", "RAZZIA", 4], ["P2", "COLIBRI", "ZOCKER", 3]], {"COLIBRI": "RAZZIA 단속 보상"},
		{"P1": [["COLIBRI", 25000]]}, {"P1": 25000})
	_ok("police reward: named as such", "단속 보상" in n6 and "+$25,000" in n6, n6)

	# 7) when I had the best payout myself, it is not repeated as somebody else's
	var n7 := _note([["P1", "COLIBRI", "ZOCKER", 6]], {"COLIBRI": "단독 도박꾼"}, {"P1": [["COLIBRI", 50000]], "P2": [["JAZZ_HOUSE", 10000]]}, {"P1": 50000, "P2": 10000})
	_ok("my own best round is not re-announced as a rival's", not ("최고 수입" in n7), n7)

	# 8) no card of mine on the table -> no note at all (never an invented sentence)
	var n8 := _note([["P2", "COLIBRI", "ZOCKER", 4]], {"COLIBRI": "단독 도박꾼"}, {"P2": [["COLIBRI", 20000]]}, {"P2": 20000})
	_ok("nothing played by me: no note", n8 == "", n8)

	# 9) every note is one short line
	for n in [n1, n2, n3, n4, n5, n6, n7]:
		if n == "":
			continue
		_ok("a note stays short (%s...)" % n.substr(0, 12), n.length() <= 90 and not ("\n" in n), "%d chars" % n.length())
	print("ROUND NOTE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
