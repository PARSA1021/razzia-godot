extends SceneTree
## QA: the real "quit in the middle of a game and continue later" path, driven through res://ui/main.tscn with real input.
## menu -> new game -> play into a later round -> Esc -> 나가기 -> menu shows CONTINUE -> continue -> the same game is back.
##   godot --path . --rendering-driver opengl3 --script res://tests/qa_resume_test.gd -- w=1280 h=720 shots=/tmp/qa_res
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")

var checks := 0
var fails: Array = []
var started := false
var W_ := 1280
var H_ := 720
var shots := ""
var main: Control


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _snap(name: String) -> void:
	if shots == "":
		return
	await _frames(2)
	root.get_texture().get_image().save_png("%s_%s.png" % [shots, name])


## canvas coords (what get_global_rect gives) -> window coords (what input events carry)
func _scr(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _click(canvas_pos: Vector2) -> void:
	var pos := _scr(canvas_pos)
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


func _btn(from: Node, needle: String) -> Button:
	if from == null:
		return null
	for b in from.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		match kv[0]:
			"w": W_ = int(kv[1])
			"h": H_ = int(kv[1])
			"shots": shots = kv[1]
	_run.call_deferred()
	return false


## Plays with real clicks until `until.call()` is true (or the frame budget runs out).
func _play(game, until: Callable, budget: int) -> void:
	var frames := 0
	var hold := 0
	while frames < budget and not until.call():
		frames += 1
		await process_frame
		var scene: Node = null
		for c in game.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("dialogue_scene.gd"):
				scene = c
		if scene != null:
			await _frames(20)
			if is_instance_valid(scene):
				await _click(Vector2(root.content_scale_size) * Vector2(0.5, 0.8))
			continue
		var modal := _btn(game.modal_layer, "NEXT ROUND")
		if modal == null:
			modal = _btn(game.modal_layer, "FINAL RESULT")
		if modal == null:
			modal = _btn(game, "NEXT ROUND")
		if modal != null:
			hold += 1
			if hold > 25:
				await _click(_center(modal))
				hold = 0
			continue
		if game.nego.visible and not game.nego.neg.is_empty():
			var btns: Array = game.nego._action_box.find_children("*", "Button", true, false)
			if not btns.is_empty():
				hold += 1
				var b: Button = null
				for want in ["결과 확인", "ROLL", "MAKE OFFER", "ACCEPT", "DUEL"]:
					if b != null:
						break
					for cand in btns:
						if want in str(cand.text) and cand.is_visible_in_tree() and not cand.disabled:
							b = cand
							break
				if b != null and hold > 30:
					await _click(_center(b))
					hold = 0
			continue
		if game._awaiting_select:
			hold += 1
			if hold > 40:
				for cv in game.hand_views:
					if is_instance_valid(cv) and cv.get("interactive") and not cv.get("locked"):
						await _click(_center(cv))
						await _frames(4)
						break
				var cb: Button = game.confirm_btn
				if cb != null and cb.is_visible_in_tree() and not cb.disabled:
					await _click(_center(cb))
				hold = 0
			continue
		if game._awaiting_bar:
			hold += 1
			if hold > 40:
				for bv in game.bar_views.values():
					if is_instance_valid(bv) and bv.is_visible_in_tree():
						await _click(_center(bv))
						break
				hold = 0
			continue
		hold = 0


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false            # this test is about the save file, not the cutscenes
	Settings.reduce_motion = false
	Settings.speed_name = "fast"
	Engine.time_scale = 3.0
	SaveStore.path = Settings.test_file("qa_resume.json")          # never the player's real autosave, and never shared with another test process
	SaveStore.clear()
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(720, 1280) if H_ > W_ else Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	_ok("a fresh install has no CONTINUE button", _btn(main.current, "CONTINUE") == null)
	var start := _btn(main.current, "NEW GAME")
	await _click(_center(start))
	await _frames(40)
	var game = main.current
	_ok("game started", not game.state.is_empty())

	# play into round 3 so the save has real history behind it
	await _play(game, func(): return int(game.state.get("round", 1)) >= 3, 40000)
	_ok("played into a later round", int(game.state["round"]) >= 3, "round=%d" % int(game.state["round"]))
	var round_before := int(game.state["round"])
	var money_before := {}
	for p in game.state["players"]:
		money_before[p["id"]] = int(p["money"])
	var seed_before = game.state["config"]["seed"]
	_ok("the autosave file exists while playing", SaveStore.has_save())

	# Esc opens the exit panel from the table, not from a negotiation, a board or a cutscene (those answer Esc themselves):
	# play on to the next card prompt, the moment a player would step away
	await _play(game, func(): return (game._awaiting_select or game._awaiting_bar) and not game._overlay_open(), 20000)
	await _frames(10)
	round_before = int(game.state["round"])
	for p in game.state["players"]:
		money_before[p["id"]] = int(p["money"])
	# Esc -> the exit panel -> 나가기
	await _key(KEY_ESCAPE)
	await _frames(30)
	await _snap("01_exit_panel")
	var leave := _btn(game, "나가기")
	_ok("Esc opens the exit panel with a way out", leave != null)
	if leave == null:
		return _finish()
	await _click(_center(leave))
	await _frames(40)
	_ok("leaving the game lands on the menu", _btn(main.current, "NEW GAME") != null)
	var cont := _btn(main.current, "CONTINUE")
	_ok("the menu now offers CONTINUE", cont != null)
	await _snap("02_menu_continue")
	if cont == null:
		return _finish()

	# continue -> the slot list -> load slot 1 -> the same game must come back
	await _click(_center(cont))
	await _frames(20)
	var load1: Button = main.current.find_child("Load1", true, false)
	_ok("CONTINUE shows the save slots, slot 1 holds this game", load1 != null and not load1.disabled)
	var load2: Button = main.current.find_child("Load2", true, false)
	_ok("the empty slot 2 cannot be loaded", load2 != null and load2.disabled)
	await _snap("02b_slots")
	if load1 == null:
		return _finish()
	await _click(_center(load1))
	await _frames(120)
	var g2 = main.current
	_ok("continue reopens a game screen", g2 != null and g2.get("state") != null and not g2.state.is_empty())
	if g2 == null or g2.state.is_empty():
		return _finish()
	await _frames(60)
	_ok("the resumed game is the same game (same seed)", g2.state["config"]["seed"] == seed_before, "%s vs %s" % [str(g2.state["config"]["seed"]), str(seed_before)])
	_ok("the resumed game is at the same round", int(g2.state["round"]) == round_before, "%d vs %d" % [int(g2.state["round"]), round_before])
	var money_ok := true
	for p in g2.state["players"]:
		if int(p["money"]) != int(money_before.get(p["id"], -1)):
			money_ok = false
	_ok("every player's money survived the resume", money_ok)
	await _snap("03_resumed")

	# and it is still playable: it must reach the next round through input alone
	var target := round_before + 1
	await _play(g2, func(): return int(g2.state.get("round", 1)) >= target, 40000)
	_ok("the resumed game keeps playing normally", int(g2.state["round"]) >= target, "round=%d" % int(g2.state["round"]))
	_finish()


func _finish() -> void:
	print("QA RESUME: checks=%d failed=%d size=%dx%d -> %s" % [checks, fails.size(), W_, H_, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
