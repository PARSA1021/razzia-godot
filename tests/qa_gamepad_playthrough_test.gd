extends SceneTree
## QA (Steam Deck): boots the REAL entry scene and plays a whole game with the CONTROLLER ONLY.
## Every step is an InputEventJoypadButton / InputEventJoypadMotion: A, B, X, Y, Start, d-pad, left stick.
## No mouse, no touch, no keyboard, no direct method calls to advance the game.
## Focus is followed the way a player sees it: if the button the player needs cannot be reached with the d-pad
## from the current focus within a few presses, that is a "focus gap" and the test fails.
##   godot --path . --rendering-driver opengl3 --script res://tests/qa_gamepad_playthrough_test.gd -- w=1280 h=800 shots=/tmp/pad
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const TextAudit = preload("res://tests/text_audit.gd")
const T = preload("res://ui/tokens.gd")

var checks := 0
var fails: Array = []
var started := false
var W_ := 1280
var H_ := 800
var shots := ""
var main: Control
var seen := {}
var focus_gaps: Array = []
var presses := 0
var audit := false
var text_min := 999.0
var player_name := ""             # name=...: play under this (cleaned) name - long names must not break any screen
var lang := ""                    # "en": play the whole game in English and fail on any Korean left on screen
var hangul_left: Array = []
var text_small := 0
var drawn_min_all := 999.0
var force_quality := ""
var saved_coach := false
var stop_after := ""          # screenshot runs on big screens: stop once this snapshot is taken (e.g. stop_after=05_offer)
var saved_quality := ""
var drawn_min_where := ""


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## English run: look at the screen every few frames during the whole game, not only at the screenshot points
func _scan_loop() -> void:
	while true:
		await _frames(6)
		for h in TextAudit.hangul(root):
			var key: String = h.get_slice(" (", 0)
			if not key in hangul_left:
				hangul_left.append(key)
				print("  [ko left] %s" % h)


func _snap(name: String) -> void:
	if lang == "en":
		await _frames(2)
		for h in TextAudit.hangul(root):
			var key: String = h.get_slice(" (", 0)
			if not key in hangul_left:
				hangul_left.append(key)
				print("  [ko left] @%s  %s" % [name, h])
	if audit:
		await _frames(2)
		var r: Dictionary = TextAudit.report(root, name)
		if r["n"] > 0:
			text_min = minf(text_min, r["min"])
		text_small += int(r["small"])
		if T.drawn_min < 900.0:
			print("         drawn text since last checkpoint: min %.1fpx '%s'" % [T.drawn_min, T.drawn_min_text])
			drawn_min_all = minf(drawn_min_all, T.drawn_min)
			if T.drawn_min < drawn_min_all + 0.01:
				drawn_min_where = "%s @%s" % [T.drawn_min_text, name]
		T.drawn_min = 999.0
	if shots == "":
		return
	await _frames(2)
	root.get_texture().get_image().save_png("%s_%s.png" % [shots, name])
	if stop_after != "" and name == stop_after:
		print("QA GAMEPAD: screenshot run stopped after %s (checks=%d failed=%d) -> %s" % [name, checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
		quit(0 if fails.is_empty() else 1)


## one press + release of a controller button
func _pad(button: int, hold: int = 1) -> void:
	presses += 1
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		e.pressure = 1.0 if down else 0.0
		Input.parse_input_event(e)
		await _frames(hold if down else 2)


## a left-stick flick (past the dead zone, then back to centre)
func _stick(axis: int, value: float) -> void:
	presses += 1
	for v in [value, 0.0]:
		var m := InputEventJoypadMotion.new()
		m.device = 0
		m.axis = axis
		m.axis_value = v
		Input.parse_input_event(m)
		await _frames(2)


func _want_snaps() -> bool:
	return shots != "" or audit


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _btn(from: Node, needle: String) -> Button:
	if from == null:
		return null
	for b in from.find_children("*", "Button", true, false):
		if (needle in b.text or (needle == "NEW GAME" and (b.name == "NewGameButton" or "빠른 시작" in b.text or "QUICK START" in b.text))) and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


## Walk the d-pad from the current focus to `target`, then press A. Returns false (and records a focus gap) when the
## target cannot be reached - the exact thing a Steam Deck player would be stuck on.
func _pad_to(target: Control, why: String, max_steps: int = 24) -> bool:
	var tried := {}
	for i in range(max_steps):
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			return true                     # it went away by itself (answered elsewhere): nothing to press
		var fo := _focus()
		if fo == target:
			await _pad(JOY_BUTTON_A)
			await _frames(4)
			return true
		var dir := JOY_BUTTON_DPAD_DOWN
		if fo != null:
			var d: Vector2 = target.get_global_rect().get_center() - fo.get_global_rect().get_center()
			var horiz: bool = absf(d.x) > absf(d.y)
			var key := "%s>%s" % [fo.get_instance_id(), horiz]
			if tried.has(key):
				horiz = not horiz           # that axis did not move us last time: try the other one
			tried[key] = true
			if horiz:
				dir = JOY_BUTTON_DPAD_RIGHT if d.x > 0 else JOY_BUTTON_DPAD_LEFT
			else:
				dir = JOY_BUTTON_DPAD_DOWN if d.y > 0 else JOY_BUTTON_DPAD_UP
		await _pad(dir)
		await _frames(3)
	var fo2 := _focus()
	focus_gaps.append("%s: '%s' unreachable (focus=%s)" % [why, (target as Button).text if target is Button else target.name, str(fo2.name) + ":" + (fo2.text if fo2 is Button else "") if fo2 != null else "none"])
	print("  [gap] ", focus_gaps[-1])
	return false


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
			"quality": force_quality = kv[1]
			"stop_after": stop_after = kv[1]
			"audit":
				audit = kv[1] == "1"
				T.audit_on = audit
			"lang":
				lang = kv[1]
			"name":
				player_name = kv[1].replace("_", " ")
	_run.call_deferred()
	return false


func _dialogue(game: Node) -> Node:
	for c in game.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("dialogue_scene.gd"):
			return c
	return null


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.load_settings()
	if player_name != "":
		Settings.player_name = Settings.clean_name(player_name)
	if lang != "":
		Settings.language = lang
		preload("res://ui/i18n.gd").apply(lang)
		T.audit_on = true              # drawn text is checked too (T.note_text)
		_scan_loop()
	var saved := [Settings.music_on, Settings.sfx_on, Settings.dialogue_on, Settings.reduce_motion, Settings.speed_name]
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = true
	saved_coach = Settings.coach_on
	Settings.coach_on = true          # a first game: the tips are on screen, and must never get in a controller player's way
	Settings.reduce_motion = false
	Settings.speed_name = "fast"
	Engine.time_scale = 3.0
	SaveStore.path = Settings.test_file("qa_pad.json")
	SaveStore.clear()
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(1280, 720)
	var imm: Node = root.get_node_or_null("InputModeManager")
	saved_quality = Settings.quality
	if force_quality != "":
		root.get_node("SteamDeckManager").set_quality(force_quality)
		print("  quality preset forced: %s (max_fps=%d low_processor=%s)" % [force_quality, Engine.max_fps, OS.low_processor_usage_mode])
	_ok("InputModeManager autoload is present", imm != null)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)

	# ---- menu: the first press of A must start something, no mouse needed
	var ng := _btn(main.current, "NEW GAME")
	_ok("menu boots with a NEW GAME button", ng != null)
	_ok("menu gives the first button focus without any input", _focus() != null and _focus() is Button, str(_focus().text if _focus() is Button else "none"))
	await _stick(JOY_AXIS_LEFT_Y, 0.2)                 # inside the dead zone: must not move focus
	var before := _focus()
	await _stick(JOY_AXIS_LEFT_Y, 0.2)
	_ok("a stick nudge inside the dead zone does not move focus", _focus() == before)
	await _snap("01_menu")
	if ng == null:
		return _finish(saved)
	if not await _pad_to(ng, "menu NEW GAME"):
		return _finish(saved)
	await _frames(40)
	if imm != null:
		_ok("input mode is GAMEPAD after controller presses", imm.mode_name() == "GAMEPAD", imm.mode_name())
		_ok("button prompts read as controller buttons", imm.prompt("accept") == "A" and imm.prompt("cancel") == "B", "%s/%s" % [imm.prompt("accept"), imm.prompt("cancel")])
	var game = main.current
	_ok("A on NEW GAME starts a game", game != null and game.get("state") != null and not game.state.is_empty())
	if game == null or game.get("state") == null or game.state.is_empty():
		return _finish(saved)

	var ended := [false]
	game.event_played.connect(func(ev):
		if ev["type"] == "GAME_ENDED":
			ended[0] = true)
	var nego_seen := [false]
	var human_nego := [false]
	game.nego_opened.connect(func(): nego_seen[0] = true)
	var frames := 0
	var idle := 0
	var cards_played := 0
	var bars_picked := 0
	var nego_answers := 0
	var modals := 0
	var scenes := 0
	var pause_tested := false
	var coach_seen := false
	var info_tested := false
	var skip_tested := false
	var last_round := -1
	while not ended[0] and frames < 120000:
		frames += 1
		await process_frame
		if game.modal_layer.has_node("Coach"):
			coach_seen = true
		if frames % 1500 == 0:
			print("  [hb] f=%d round=%s sel=%s bar=%s nego=%s focus=%s presses=%d" % [frames, str(game.state.get("round")), game._awaiting_select, game._awaiting_bar, game.nego.visible, str(_focus().name) if _focus() != null else "-", presses])
		# X skips a replay (the table animation), exactly once is enough to prove it
		if not skip_tested and game.skip_btn.visible and not game._awaiting_select and not game.nego.visible and _dialogue(game) == null:
			var xe := InputEventJoypadButton.new()
			xe.button_index = JOY_BUTTON_X
			xe.pressed = true
			Input.parse_input_event(xe)
			await process_frame
			var skipped: bool = game.skip
			var xr := xe.duplicate()
			xr.pressed = false
			Input.parse_input_event(xr)
			presses += 1
			if _dialogue(game) != null or not game.skip_btn.visible:
				continue                 # a cutscene opened in between (X does nothing there): try at the next replay
			_ok("X skips the running animation", skipped)
			skip_tested = true
			continue
		var scene := _dialogue(game)
		if scene != null:
			await _frames(20)
			if is_instance_valid(scene):
				await _pad(JOY_BUTTON_A)
				scenes += 1
			continue
		if game.nego.visible and not game.nego.neg.is_empty():
			if game.state["players"][0]["id"] in game.nego.neg.get("claimantIds", []):
				human_nego[0] = true
			var box = game.nego._action_box
			var target: Button = null
			for want in ["결과 확인", "ROLL", "MAKE OFFER", "ACCEPT", "DUEL"]:
				if target != null:
					break
				for cand in box.find_children("*", "Button", true, false):
					if want in str(cand.text) and cand.is_visible_in_tree() and not cand.disabled:
						target = cand
						break
			if target == null:
				idle += 1
				if idle % 600 == 0:
					var names := []
					for cand in box.find_children("*", "Button", true, false):
						names.append("%s(v=%s,d=%s)" % [cand.text, cand.is_visible_in_tree(), cand.disabled])
					print("  [nego-wait] buttons=%s status=%s" % [str(names), game.nego._status.text.substr(0, 50)])
				continue
			idle += 1
			if idle < 50:                    # prompts arm their focus after a short guard: give them that time
				continue
			var label := str(target.text)
			if _want_snaps():
				for pair in [["결과 확인", "duel_result"], ["ROLL", "duel_roll"], ["MAKE OFFER", "offer"], ["ACCEPT", "nego"]]:
					if pair[0] in label and not seen.has(pair[1]):
						seen[pair[1]] = true
						await _snap("05_" + pair[1])
			await _pad_to(target, "negotiation " + label.substr(0, 12))
			nego_answers += 1
			await _frames(8)
			idle = 0
			continue
		var modal_btn: Button = null
		for nm in ["NEXT ROUND", "FINAL RESULT"]:
			if modal_btn == null:
				modal_btn = _btn(game.modal_layer, nm)
			if modal_btn == null:
				modal_btn = _btn(game, nm)
		if modal_btn != null:
			idle += 1
			if idle < 50:
				continue
			if _want_snaps() and not seen.has("board_result"):
				seen["board_result"] = true
				await _snap("04_round_result")
			await _pad_to(modal_btn, "round board " + modal_btn.text)
			modals += 1
			await _frames(10)
			idle = 0
			continue
		if game._awaiting_select:
			idle += 1
			if idle < 40:
				continue
			idle = 0
			var r := int(game.state.get("round", 0))
			if not pause_tested:
				pause_tested = true
				await _pad(JOY_BUTTON_START)
				await _frames(10)
				_ok("Start opens the pause panel", game.modal_layer.has_node("ExitConfirm") and paused)
				await _snap("03b_pause")
				await _pad(JOY_BUTTON_B)
				await _frames(10)
				_ok("B closes the pause panel and resumes", not game.modal_layer.has_node("ExitConfirm") and not paused)
				await _pad(JOY_BUTTON_START)
				await _frames(10)
				await _pad(JOY_BUTTON_START)
				await _frames(10)
				_ok("Start toggles the pause panel closed again", not game.modal_layer.has_node("ExitConfirm") and not paused)
			if not info_tested:
				info_tested = true
				await _pad(JOY_BUTTON_DPAD_RIGHT)
				await _pad(JOY_BUTTON_Y)
				await _frames(10)
				_ok("Y opens the venue card for the focused card", game.modal_layer.has_node("BarInfo"))
				await _snap("03c_venue_info")
				await _pad(JOY_BUTTON_B)
				await _frames(10)
				_ok("B closes the venue card", not game.modal_layer.has_node("BarInfo"))
			if r != last_round and _want_snaps() and not seen.has("board"):
				seen["board"] = true
				await _snap("03_board")
			last_round = r
			var hand_before: int = game.state["players"][0]["hand"].size()
			await _pad(JOY_BUTTON_DPAD_RIGHT)                # focus a card
			await _pad(JOY_BUTTON_A)                         # select it
			await _frames(4)
			if not seen.has("sel"):
				seen["sel"] = true
				_ok("A selects the focused card", game.selected_view != null)
			await _pad(JOY_BUTTON_A)                         # play it
			await _frames(30)
			if game.state["players"][0]["hand"].size() < hand_before or not game._awaiting_select:
				cards_played += 1
			continue
		if game._awaiting_bar:
			idle += 1
			if idle < 40:
				continue
			idle = 0
			await _stick(JOY_AXIS_LEFT_X, 1.0)               # the left stick navigates too
			await _pad(JOY_BUTTON_A)
			await _frames(20)
			bars_picked += 1
			continue
		idle = 0
	_ok("the whole game was played with the controller only", ended[0], "frames=%d presses=%d" % [frames, presses])
	_ok("cards were played with d-pad + A", cards_played >= 3, str(cards_played))
	_ok("cutscenes were advanced with A", scenes > 0, str(scenes))
	_ok("negotiation / duel prompts were answered by controller", nego_answers > 0 or not human_nego[0], "%d (opened=%s, human in it=%s)" % [nego_answers, nego_seen[0], human_nego[0]])
	_ok("round boards were closed by controller", modals > 0, str(modals))
	_ok("first-game tips were on screen and never blocked the controller", coach_seen)
	_ok("pause, venue card and skip were exercised", pause_tested and info_tested and skip_tested)

	# ---- game over -> summary -> menu, controller only
	var over_btn: Button = null
	var waited := 0
	while waited < 1500 and over_btn == null:
		waited += 1
		await process_frame
		var sc := _dialogue(game)
		if sc != null:
			await _frames(20)
			if is_instance_valid(sc):
				await _pad(JOY_BUTTON_A)
			continue
		over_btn = _btn(game, "NEW GAME")
	_ok("game-over screen appears", over_btn != null)
	await _frames(60)
	await _snap("06_game_over")
	var sum_btn := _btn(game, "게임 요약")
	if sum_btn != null:
		await _pad_to(sum_btn, "game over 게임 요약")
		await _frames(40)
		var sum_open := false
		for c in game.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("summary_screen.gd"):
				sum_open = true
		_ok("A on 게임 요약 opens the summary", sum_open)
		await _snap("07_summary")
		await _stick(JOY_AXIS_RIGHT_Y, 1.0)              # right stick scrolls long screens
		await _pad(JOY_BUTTON_B)
		await _frames(30)
		var still := false
		for c in game.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("summary_screen.gd") and not c.is_queued_for_deletion():
				still = true
		_ok("B closes the summary", not still)
		_ok("focus returns to the game-over screen after the summary", _focus() != null, str(_focus().text if _focus() is Button else "none"))
	var to_menu := _btn(game, "MENU")
	_ok("game-over offers MENU", to_menu != null)
	if to_menu != null:
		await _pad_to(to_menu, "game over MENU")
		await _frames(60)
		_ok("back to the menu by controller", _btn(main.current, "NEW GAME") != null)
		_ok("the menu has focus again for the next A press", _focus() != null)
	_ok("no focus gaps (every needed button reachable with the d-pad)", focus_gaps.is_empty(), str(focus_gaps))
	_finish(saved)


func _finish(saved: Array = []) -> void:
	if saved.size() == 5:
		Settings.music_on = saved[0]
		Settings.sfx_on = saved[1]
		Settings.dialogue_on = saved[2]
		Settings.reduce_motion = saved[3]
		Settings.speed_name = saved[4]
	SaveStore.clear()
	Settings.coach_on = saved_coach
	Settings.save_settings()
	if force_quality != "":
		Settings.quality = saved_quality
		Settings.save_settings()
	if audit:
		print("TEXT AUDIT: smallest control text %.1fpx, %d control text items under 12px; smallest drawn text %.1fpx %s" % [text_min, text_small, drawn_min_all, drawn_min_where])
	if lang == "en":
		for h in T.drawn_hangul:
			hangul_left.append("drawn: " + str(h))
		print("I18N: %d Korean text(s) left in the English game" % hangul_left.size())
		for h in hangul_left:
			print("   ", h)
		if not hangul_left.is_empty():
			fails.append("korean text left in English: %d" % hangul_left.size())
	print("QA GAMEPAD: checks=%d failed=%d size=%dx%d presses=%d -> %s" % [checks, fails.size(), W_, H_, presses, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
