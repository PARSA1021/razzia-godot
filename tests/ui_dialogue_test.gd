extends SceneTree
## Dialogue scenes (Phase 14): shown at the game start, not skippable by a stray key, advance with Enter / click / touch, SKIP and Esc leave,
## the off switch and reduced motion work, and every scene kind builds real lines.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_dialogue_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const DS = preload("res://ui/dialogue_scene.gd")
var game
var checks := 0
var fails: Array = []
var started := false

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame

func _click(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)

func _scene() -> Node:
	for c in game.get_children():
		if c is DS: return c
	return null

func _new_game(seed_n: int, dialogue: bool, reduce: bool = false) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	Settings.dialogue_on = dialogue
	Settings.reduce_motion = reduce
	var s := Eng.create_game({"playerCount": 4, "seed": seed_n, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	game.begin(s)

func _process(_d: float) -> bool:
	if started: return false
	started = true
	_run.call_deferred()
	return false

func _run() -> void:
	Settings.load_settings()
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.speed_name = "NORMAL"
	root.size = Vector2i(1280, 720)
	# 1. intro scene at the game start; stray keys right away do nothing; Enter completes the text, Enter again advances
	await _new_game(5, true)
	var sc := _scene()
	for i in range(120):
		if sc != null: break
		await process_frame
		sc = _scene()
	_ok("intro scene appears at the start", sc != null and "intro" in game.scenes_shown)
	_ok("the game does not ask for a card while the scene is up", not game._awaiting_select)
	var n0: int = sc.lines.size()
	_ok("intro has 2-3 lines from AI players only", n0 >= 2 and n0 <= 3 and not ("나" in sc.lines.map(func(l): return l["who"])), str(n0))
	await _key(KEY_ENTER)                       # < 0.25 s after the line appeared: ignored
	_ok("a stray Enter right after the scene appeared does not advance it", sc._i == 0)
	await _frames(18)                           # armed now, text still typing
	await _key(KEY_ENTER)                       # completes the typing
	_ok("first Enter completes the text", sc._text.visible_ratio >= 1.0 and sc._i == 0)
	await _frames(20)
	await _key(KEY_ENTER)
	_ok("next Enter shows the next line", sc._i == 1 or not is_instance_valid(sc))
	# mash: the scene still ends, and no later input is swallowed by the game
	for i in range(40):
		await _key(KEY_ENTER)
		await _frames(12)
		if not is_instance_valid(sc) or sc._done: break
	await _frames(10)
	_ok("scene finished after the last line", _scene() == null)
	for i in range(1500):
		if game._awaiting_select: break
		await process_frame
	_ok("then the game asks for a card", game._awaiting_select)
	# 2. SKIP button
	await _new_game(6, true)
	await _frames(30)
	sc = _scene()
	_ok("scene present (second game)", sc != null)
	await _click(sc._skip_btn.get_global_rect().get_center())
	await _frames(10)
	_ok("SKIP leaves the scene", _scene() == null)
	for i in range(1500):
		if game._awaiting_select: break
		await process_frame
	_ok("... and the game goes on", game._awaiting_select)
	# 3. off switch
	await _new_game(7, false)
	for i in range(1500):
		if game._awaiting_select: break
		if game._awaiting_bar and i % 40 == 0:
			await _key(KEY_ENTER)          # the human croupier puts the extra money card on the focused venue
		await process_frame
	_ok("dialogue OFF: no scene at all", game._awaiting_select and game.scenes_shown.is_empty(), "awaiting=%s shown=%s" % [str(game._awaiting_select), str(game.scenes_shown)])
	# 4. reduced motion: text is complete at once, arrow does not pulse
	await _new_game(8, true, true)
	await _frames(20)
	sc = _scene()
	_ok("reduced motion: text shown completely at once", sc != null and sc._text.visible_ratio >= 1.0)
	Settings.reduce_motion = false
	await _key(KEY_ESCAPE)
	await _frames(5)
	# 5. every scene kind builds lines and Esc leaves
	for kind in ["final", "end", "duel"]:
		Settings.dialogue_on = true
		var extra := {}
		if kind == "end": extra = {"winnerIds": ["P2"]}
		if kind == "duel": extra = {"actor": game._ai_players()[0], "ai_won": true}
		game._play_scene(kind, extra)
		await _frames(15)
		sc = _scene()
		_ok("%s scene has lines" % kind, sc != null and sc.lines.size() >= 1 and str(sc.lines[0]["text"]) != "", str(sc.lines if sc else ""))
		await _frames(20)
		await _key(KEY_ESCAPE)
		await _frames(5)
		if _scene() != null: print("  [dbg] scene still there: done=", _scene()._done, " in tree=", _scene().is_inside_tree())
		_ok("%s scene: Esc leaves" % kind, _scene() == null)
	print("DIALOGUE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty(): print("failed: ", fails)
	quit(0 if fails.is_empty() else 1)
