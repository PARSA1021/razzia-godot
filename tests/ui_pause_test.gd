extends SceneTree
## The pause panel must really pause (Phase 20): while it is open the table, the AI turns and the animations stop, so a
## round can never end behind it. Continuing resumes, and leaving a paused game never leaves the menu frozen.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_pause_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")

var checks := 0
var fails: Array = []
var started := false
var game
var events := 0


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _btn(from: Node, needle: String) -> Button:
	for b in from.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.coach_on = false
	Settings.speed_name = "NORMAL"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 4, "seed": 9, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	game.bot = func(p, _v, g):
		if p["type"] == "SELECT_CARD":
			return {"type": "SELECT_CARD", "playerId": g.human_id, "cardId": Eng.get_player(g.state, g.human_id)["hand"][0]}
		if p["type"] == "PLACE_EXTRA_MONEY":
			return {"type": "PLACE_EXTRA_MONEY", "playerId": g.human_id, "barId": g.bar_order[0]}
		if p["type"] == "MAKE_PROPOSAL":
			return {"type": "MAKE_PROPOSAL", "playerId": g.human_id, "allocations": {}}
		return {"type": "RESPOND", "playerId": g.human_id, "response": "ACCEPT"}
	game.event_played.connect(func(_ev): events += 1)
	root.add_child(game)
	game.begin(s)
	await _frames(120)
	_ok("the game is running", events > 0, str(events))
	_ok("the tree is not paused while playing", not paused)

	# pause
	game._on_exit_pressed()
	await _frames(5)
	var panel: Node = game.modal_layer.get_node_or_null("ExitConfirm")
	_ok("the pause panel is up", panel != null)
	_ok("the tree is paused", paused)
	var at_pause := events
	var round_at_pause := int(game.state["round"])
	await _frames(240)
	_ok("nothing happens on the table while paused", events == at_pause, "%d -> %d" % [at_pause, events])
	_ok("the round cannot end behind the panel", int(game.state["round"]) == round_at_pause)
	_ok("no second board stacks on top of the pause", game.modal_layer.get_child_count() == 1, str(game.modal_layer.get_child_count()))

	# the panel's own buttons still work while the tree is paused
	var stay := _btn(game, "계속하기")
	_ok("the pause panel still answers while paused", stay != null and stay.process_mode == Node.PROCESS_MODE_INHERIT and game.modal_layer.process_mode == Node.PROCESS_MODE_ALWAYS)
	stay.emit_signal("pressed")
	await _frames(10)
	_ok("continuing closes the panel", game.modal_layer.get_node_or_null("ExitConfirm") == null)
	_ok("continuing unpauses the tree", not paused)
	var after := events
	await _frames(180)
	_ok("the game runs again after continuing", events > after, "%d -> %d" % [after, events])

	# the mute key must still work with the pause panel open: that is where the sound settings are
	game._on_exit_pressed()
	await _frames(5)
	var was_on: bool = Settings.mute_all            # Phase 28: M is the one master mute
	var k := InputEventKey.new()
	k.keycode = KEY_M
	k.physical_keycode = KEY_M
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(5)
	_ok("M still mutes while paused", Settings.mute_all != was_on, "%s -> %s" % [was_on, Settings.mute_all])
	Input.parse_input_event(k)
	await _frames(5)
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.save_settings()
	# leaving a paused game must not leave the tree paused for the menu
	game._on_exit_pressed()
	await _frames(5)
	_ok("paused again", paused)
	var leave := _btn(game, "나가기")
	leave.emit_signal("pressed")
	await _frames(10)
	_ok("leaving unpauses the tree", not paused)
	game.queue_free()
	await _frames(10)
	_ok("the tree is free to run after the game screen is gone", not paused)

	print("PAUSE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
