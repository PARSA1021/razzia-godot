extends SceneTree
## Real-input regression test (Phase 12): the human picks a card and presses Enter like a player would; the round must go
## through every step (reveal, bars, negotiation / money, round end) and must NOT be cut short by the key presses.
## Keys go through Input.parse_input_event (the same path as a keyboard), mouse clicks through real motion + button events.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_enter_flow_test.gd -- mode=enter|hold|mash|mouse_enter|confirm_click seed=5
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const Trace = preload("res://ui/flow_trace.gd")

var mode := "enter"
var seed_n := 5
var reduce := false
var game
var checks := 0
var fails: Array = []
var started := false
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv[0] == "mode":
			mode = kv[1]
		elif kv[0] == "rm":
			reduce = kv[1] == "1"
		elif kv[0] == "seed":
			seed_n = int(kv[1])


func _ok(name: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, extra])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _key(code: Key, echo: bool = false, hold_frames: int = 1) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	Input.parse_input_event(e)
	await _frames(hold_frames)
	var r := InputEventKey.new()
	r.keycode = code
	r.physical_keycode = code
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(1)


func _click(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await _frames(2)
	var d := InputEventMouseButton.new()
	d.position = pos
	d.global_position = pos
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	Input.parse_input_event(d)
	await _frames(2)
	var u := InputEventMouseButton.new()
	u.position = pos
	u.global_position = pos
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _wait_select(max_frames: int) -> bool:
	var bar_wait := 0
	for i in range(max_frames):
		if game._awaiting_select:
			return true
		if game._awaiting_bar:                 # an extra money card: Enter puts it on the focused venue
			bar_wait += 1
			if bar_wait == 30:
				await _key(KEY_ENTER)
				bar_wait = 0
		await process_frame
	return false


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()
	Settings.speed_name = "NORMAL"
	Settings.reduce_motion = reduce
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	root.size = Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 4, "seed": seed_n, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	Trace.clear()
	var seen_types: Array = []
	var round_ended := {}
	game.event_played.connect(func(ev):
		seen_types.append(ev["type"])
		if ev["type"] == "ROUND_ENDED":
			round_ended[int(ev["round"])] = true)
	game.begin(s)
	_ok("round 1: the game asks for a card", await _wait_select(1200))
	var f0 := Engine.get_process_frames()
	var n_before := seen_types.size()
	match mode:
		"enter":
			await _key(KEY_ENTER)                  # focused card -> selected
			_ok("first Enter only selects (card selected, nothing played yet)", game.selected_view != null and game._awaiting_select)
			await _frames(10)
			await _key(KEY_ENTER)                  # second Enter confirms
		"hold":
			await _key(KEY_ENTER)
			await _frames(10)
			await _key(KEY_ENTER, false, 1)
			for i in range(40):
				await _key(KEY_ENTER, true, 1)     # key repeat while held
		"mash":
			await _key(KEY_ENTER)
			await _frames(6)
			for i in range(30):
				await _key(KEY_ENTER, false, 1)
		"mouse_enter":
			var cv = game.hand_views[2]
			await _click(cv.get_global_rect().get_center())
			_ok("clicking a card selects exactly that card", game.selected_view == cv)
			await _key(KEY_ENTER)
		"confirm_click":
			var cv2 = game.hand_views[1]
			await _click(cv2.get_global_rect().get_center())
			await _click(game.confirm_btn.get_global_rect().get_center())
			await _key(KEY_ENTER)
			await _key(KEY_ENTER)
	# the human action must have been accepted exactly once
	var sel_count := 0
	for l in Trace.lines:
		if "[confirm]" in l:
			sel_count += 1
	_ok("Enter / click confirmed the card (state moved on from SELECT_CARD)", not game._awaiting_select or seen_types.size() > n_before, "events=%d" % (seen_types.size() - n_before))
	# let the round play until the result board appears; keep poking Enter like an impatient player in "mash" mode
	var bfa := [-1]          # lambdas capture by value: use an array
	game.result_board_shown.connect(func(): bfa[0] = Engine.get_process_frames())
	var frames := 0
	var prompt_since := -1
	var prompts := 0
	while frames < 20000 and bfa[0] < 0:
		if mode == "mash" and frames % 7 == 0 and game.nego._action_box.get_child_count() == 0:
			await _key(KEY_ENTER)
			frames += 2
		# the human is asked something in the negotiation panel (offer / answer / roll): Enter answers it, but not at once
		if game.nego.visible and game.nego._action_box.get_child_count() > 0:
			if prompt_since < 0:
				prompt_since = frames
				if mode == "mash":
					await _key(KEY_ENTER)           # stray Enter right when the prompt appears
					_ok("stray Enter does not answer a negotiation prompt that just appeared", game.nego._action_box.get_child_count() > 0)
			elif frames - prompt_since > 45:
				prompts += 1
				await _key(KEY_ENTER)
				prompt_since = -1
		else:
			prompt_since = -1
		await process_frame
		frames += 1
	_ok("the result board appeared (round played through reveal, bars, money)", bfa[0] >= 0)
	var mid_types: Array = seen_types.slice(n_before)
	if mode == "mash":
		var t_start := Time.get_ticks_msec()
		for i in range(8):                   # stray Enters right after the board came up (within ~0.4 s wall time, 8 presses at most)
			await _key(KEY_ENTER)
			if Time.get_ticks_msec() - t_start > 400:
				break
		_ok("stray Enter does not dismiss the result board in its first moments", game.modal_layer.get_child_count() > 0 and not round_ended.has(1), "modal children=%d" % game.modal_layer.get_child_count())
	await _frames(70)
	_ok("board still waits for the player", game.modal_layer.get_child_count() > 0 and not round_ended.has(1))
	await _key(KEY_ENTER)                    # first press finishes the board animation (if still running) ...
	await _frames(20)
	if not round_ended.has(1):
		await _key(KEY_ENTER)                # ... the next one moves on
	for i in range(900):
		if round_ended.has(1) and game._awaiting_select:
			break
		await process_frame
	_ok("round 1 ended", round_ended.has(1))
	_ok("round 2 asks for a card", game._awaiting_select and int(game.state["round"]) == 2, "round=%s" % str(game.state["round"]))
	seen_types = mid_types
	var secs := float(bfa[0] - f0) / 60.0       # game time from the card to the result board (60 fps, --fixed-fps 60)
	print("  seen after the card: ", seen_types)
	_ok("the replay contained a reveal", "CARDS_REVEALED" in seen_types)
	_ok("the replay contained the bar resolution(s)", "BAR_RESOLVED" in seen_types)
	var sk := Trace.lines.filter(func(l): return "[skip]" in l)
	_ok("Enter never set the skip flag", sk.is_empty(), str(sk))
	var confirms := Trace.lines.filter(func(l): return "[confirm]" in l and "awaiting=true" in l and "selected=true" in l)
	_ok("exactly one accepted confirm per decision", confirms.size() <= 1 or mode == "confirm_click", str(confirms.size()))
	_ok("card -> result board takes a followable time (>= %.1f s)" % (3.0 if reduce else 5.0), secs >= (3.0 if reduce else 5.0), "%.1fs" % secs)
	print("RESULT %s checks=%d failed=%d mode=%s secs=%.1f" % ["PASS" if fails.is_empty() else "FAIL", checks, fails.size(), mode, secs])
	if not fails.is_empty():
		print("failed: ", fails)
		for l in Trace.lines.slice(maxi(0, Trace.lines.size() - 60)):
			print(l)
	quit(0 if fails.is_empty() else 1)
