extends SceneTree
## First-game guide (Phase 19): the right tip at the right moment, once each, never in the way, and gone after one
## finished game. The tip card must never swallow a click meant for the board.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_coach_test.gd
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


func _coach_node() -> Control:
	return game.modal_layer.get_node_or_null("Coach")


func _texts(n: Node) -> String:
	var out := ""
	if n == null:
		return out
	for l in n.find_children("*", "Label", true, false):
		out += str(l.text) + " "
	return out


func _new_game(coach: bool) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await _frames(5)
	Settings.coach_on = coach
	var s := Eng.create_game({"playerCount": 4, "seed": 5, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	game.begin(s)
	await _frames(30)


func _run() -> void:
	Settings.load_settings()            # take the saved file first, then override: a lazy load must not undo the test setup
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.speed_name = "FAST"
	var saved_tut: bool = Settings.tutorial_done
	Settings.tutorial_done = false        # these tips are for players who skipped Sal's tutorial
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)

	# 1) the card tip arrives with the first card prompt
	await _new_game(true)
	var guard := 0
	while guard < 600 and not game._awaiting_select:
		guard += 1
		await process_frame
	_ok("the board asks for a card", game._awaiting_select)
	await _frames(5)
	var tip := _coach_node()
	_ok("the first card prompt shows a tip", tip != null)
	if tip != null:
		var t := _texts(tip)
		_ok("the tip explains what to do", "카드" in t and "술집" in t, t.substr(0, 50))
		_ok("the tip points at the venue card", "안 나온 카드" in t, t.substr(0, 90))
		_ok("the tip card itself ignores the mouse", tip.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		var btns: Array = tip.find_children("*", "Button", true, false)
		_ok("the tip can be dismissed", btns.size() == 1 and btns[0].mouse_filter != Control.MOUSE_FILTER_IGNORE)
		_ok("the tip sits inside the screen", tip.position.x >= 0.0 and tip.position.y >= 0.0 and tip.position.x + tip.size.x <= game.size.x + 1.0 and tip.position.y + tip.size.y <= game.size.y + 1.0, str(tip.position))
		_ok("the tip does not cover the hand", tip.position.y + tip.size.y < game.hand_views[0].position.y + 1.0 if not game.hand_views.is_empty() else true)
		btns[0].emit_signal("pressed")
		await _frames(5)
		_ok("pressing the button closes the tip", _coach_node() == null)

	# 2) one tip per key, even when the prompt comes round again
	game._coach("card", "x", "y")
	await _frames(3)
	_ok("the same tip never comes back in one game", _coach_node() == null)

	# 3) the tip disappears by itself when the move is made
	game._coach("extra", "추가 머니카드", "설명")
	await _frames(3)
	_ok("another key still shows its own tip", _coach_node() != null)
	game._coach_hide()
	await _frames(3)
	_ok("the tip closes when the move is made", _coach_node() == null)

	# 4) with the guide switched off nothing appears at all
	await _new_game(false)
	guard = 0
	while guard < 600 and not game._awaiting_select:
		guard += 1
		await process_frame
	await _frames(10)
	_ok("guide off: no tip during the card prompt", _coach_node() == null)

	# 5) a finished game switches the guide off by itself, and the setting survives
	Settings.coach_on = true
	game._ev_game_ended({"winnerIds": ["P2"], "ranking": [], "money": {}})
	await _frames(10)
	_ok("one finished game turns the guide off", not Settings.coach_on)
	Settings._loaded = false
	Settings.load_settings()
	_ok("the choice is saved", not Settings.coach_on)
	# after Sal's tutorial the tips it taught by doing are not repeated
	Settings.coach_on = true
	Settings.tutorial_done = true
	await _new_game(true)
	var g2 := 0
	while g2 < 600 and not game._awaiting_select:
		g2 += 1
		await process_frame
	await _frames(5)
	_ok("after the tutorial the card tip is not shown again", _coach_node() == null)
	Settings.tutorial_done = saved_tut
	# leave the shared settings file the way it was found (other tests read it)
	Settings.coach_on = true
	Settings.music_on = true
	Settings.sfx_on = true
	Settings.dialogue_on = true
	Settings.save_settings()

	print("COACH TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
