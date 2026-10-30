extends SceneTree
## QA: Sal's tutorial from the real entry scene, with real input only (mouse, or the controller with pad=1).
## menu -> first NEW GAME offers the tutorial -> 3 staged rounds -> finale -> a real game starts. Also: Sal's talk blocks the
## table, the pause panel still works, the skip button ends it, and the offer is not repeated afterwards.
##   godot --headless --fixed-fps 60 --path . --script res://tests/qa_tutorial_test.gd -- [pad=1] [skip=1] [shots=/tmp/t]
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const Plan = preload("res://ui/tutorial_plan.gd")

var checks := 0
var fails: Array = []
var started := false
var pad := false
var skip_mode := false
var shots := ""
var main: Control
var seen := {}
var W_ := 1280
var H_ := 800


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _snap(name: String) -> void:
	if shots == "" or seen.has("shot_" + name):
		return
	seen["shot_" + name] = true
	await _frames(3)
	root.get_texture().get_image().save_png("%s_%s.png" % [shots, name])


func _click_at(canvas_pos: Vector2) -> void:
	var pos: Vector2 = root.get_final_transform() * canvas_pos
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


func _click(c: Control) -> void:
	await _click_at(c.get_global_rect().get_center())


func _pad(b: int) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _btn(from: Node, needle: String) -> Button:
	if from == null:
		return null
	for b in from.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


## controller: walk the d-pad to a button, then A (same walk a player does)
func _pad_to(target: Control, max_steps: int = 24) -> bool:
	var tried := {}
	for i in range(max_steps):
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			return true
		var fo := root.gui_get_focus_owner()
		if fo == target:
			await _pad(JOY_BUTTON_A)
			return true
		var dir := JOY_BUTTON_DPAD_DOWN
		if fo != null:
			var d: Vector2 = target.get_global_rect().get_center() - fo.get_global_rect().get_center()
			var horiz: bool = absf(d.x) > absf(d.y)
			var key := "%s>%s" % [fo.get_instance_id(), horiz]
			if tried.has(key):
				horiz = not horiz
			tried[key] = true
			if horiz:
				dir = JOY_BUTTON_DPAD_RIGHT if d.x > 0 else JOY_BUTTON_DPAD_LEFT
			else:
				dir = JOY_BUTTON_DPAD_DOWN if d.y > 0 else JOY_BUTTON_DPAD_UP
		await _pad(dir)
	print("  [gap] cannot reach ", target.text if target is Button else target.name)
	return false


func _press(b: Control) -> void:
	if pad:
		await _pad_to(b)
	else:
		await _click(b)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		match kv[0]:
			"lang": lang = kv[1]
			"pad": pad = kv[1] == "1"
			"skip": skip_mode = kv[1] == "1"
			"shots": shots = kv[1]
			"w": W_ = int(kv[1])
			"h": H_ = int(kv[1])
	_run.call_deferred()
	return false


var lang := ""          # "en": the whole test in English, failing on any Korean left on screen


func _run() -> void:
	Settings.load_settings()
	if lang == "en":
		preload("res://tests/text_audit.gd").start_en(self)
	var saved := [Settings.music_on, Settings.sfx_on, Settings.dialogue_on, Settings.tutorial_done, Settings.coach_on, Settings.speed_name, Settings.reduce_motion]
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.tutorial_done = false
	Settings.coach_on = true
	Settings.speed_name = "fast"
	Settings.reduce_motion = false
	Engine.time_scale = 2.0
	SaveStore.path = Settings.test_file("qa_tut.json")
	SaveStore.clear()
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(720, 1280) if H_ > W_ else Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)

	# ---- the first NEW GAME offers the tutorial
	var ng := _btn(main.current, "NEW GAME")
	await _press(ng)
	await _frames(20)
	var ask: Node = main.current.get_node_or_null("TutorialAsk")
	_ok("the first NEW GAME offers Sal's tutorial", ask != null)
	await _snap("00_ask")
	var go := _btn(ask, "튜토리얼 하기")
	_ok("the offer has focus on '튜토리얼 하기' for a controller", root.gui_get_focus_owner() == go)
	await _press(go)
	await _frames(40)
	var game = main.current
	_ok("the tutorial table starts (fixed seed)", game.get("tutorial") != null and int(game.state["config"]["seed"]) == Plan.SEED)
	var tut: Control = game.tutorial
	var dealt := false
	if skip_mode:
		# ---- skip at the first line: a real game follows
		var w0 := 0
		while w0 < 600 and tut.mode != "talk":
			w0 += 1
			await process_frame
		await _click(tut._skip_btn)
		await _frames(60)
		var g2 = main.current
		_ok("skipping ends the tutorial and starts a real game", g2 != game and g2.get("tutorial") == null and g2.get("state") != null and not g2.state.is_empty())
		_ok("skipping counts as done (not offered again)", Settings.tutorial_done)
		return _finish(saved)

	# ---- play it through
	var stats := {"talk": 0, "do": 0, "info": false, "dealer": false, "offer": false, "roll": false, "verdict": false, "boards": 0, "blocked": true, "pause": false}
	var won := {}
	game.event_played.connect(func(ev):
		if str(ev["type"]) == "MONEY_AWARDED" and str(ev["playerId"]) == Plan.ME:
			won[int(ev["round"])] = int(won.get(int(ev["round"]), 0)) + int(ev["amount"])
		if str(ev["type"]) == "DUEL_RESOLVED":
			won["duel"] = str(ev["winnerId"]))
	var last_text := ""
	var frames := 0
	var stuck := 0
	while frames < 30000 and is_instance_valid(game) and main.current == game:
		frames += 1
		await process_frame
		if not is_instance_valid(tut):
			break
		if frames % 3000 == 0:
			var mb := []
			for b in game.modal_layer.find_children("*", "Button", true, false):
				mb.append(b.text)
			print("  [hb] f=%d mode=%s text=%s disp_round=%s state_round=%s sel=%s bar=%s nego=%s modal=%s halted=%s" % [frames, tut.mode, tut._text.text.substr(0, 30), str(game.disp.get("round")), str(game.state.get("round")), game._awaiting_select, game._awaiting_bar, game.nego.visible, str(mb), game._tutorial_halted])
		if tut.mode == "choice":
			await _frames(20)
			await _snap("09_finale")
			_ok("the finale offers a real game", _btn(tut, "진짜 게임 시작") != null)
			_ok("finishing marks the tutorial as done", Settings.tutorial_done)
			await _press(_btn(tut, "진짜 게임 시작"))
			await _frames(60)
			break
		if tut.mode == "talk":
			if tut._text.text != last_text:
				last_text = tut._text.text
				stats["talk"] += 1
				await _frames(30)
				if stats["talk"] == 1:
					await _snap("01_intro")
				if stats["talk"] == 4:
					await _snap("02_money")
				# Sal's talk blocks the table: a click on a hand card does nothing
				if game.hand_views.size() > 0 and is_instance_valid(game.hand_views[0]) and stats["talk"] == 6:
					var before_sel = game.selected_view
					await _click(game.hand_views[0])
					stats["blocked"] = game.selected_view == before_sel
				# the pause still works during the tutorial
				if stats["talk"] == 3 and not stats["pause"]:
					await _key(KEY_ESCAPE)
					await _frames(10)
					var opened: bool = game.modal_layer.has_node("ExitConfirm") and paused and not tut.visible
					await _key(KEY_ESCAPE)
					await _frames(10)
					stats["pause"] = opened and not paused and tut.visible
			if pad:
				await _pad(JOY_BUTTON_A)
			else:
				await _click_at(Vector2(root.content_scale_size) * Vector2(0.5, 0.5))
			await _frames(6)
			continue
		if tut.mode == "do":
			stuck += 1
			if tut._text.text != last_text:
				last_text = tut._text.text
				stats["do"] += 1
				stuck = 0
				await _frames(25)
			var bi: Node = game.modal_layer.get_node_or_null("BarInfo")
			if bi != null:
				stats["info"] = true
				await _snap("03_venue_info")
				if pad:
					await _pad(JOY_BUTTON_B)
				else:
					await _click(_btn(bi, "닫기"))
				await _frames(10)
				continue
			if game._awaiting_select and ("눌러 봐" in tut._text.text or tut._text.text.begins_with("Tap ")):     # the venue-card beat (Korean or English)
				await _snap("03a_open_info")
				if pad:
					await _pad(JOY_BUTTON_Y)
				else:
					await _click_at(tut.hole.get_center() + tut.global_position)
				await _frames(10)
				continue
			if game._awaiting_select:
				if not seen.has("card%d" % int(game.state["round"])):
					seen["card%d" % int(game.state["round"])] = true
					await _snap("04_play_card_r%d" % int(game.state["round"]))
				if pad:
					await _pad(JOY_BUTTON_A)
					await _frames(6)
					await _pad(JOY_BUTTON_A)
				else:
					var target: Control = null
					for v in game.hand_views:
						if is_instance_valid(v) and not v.locked:
							target = v
					if game.selected_view == null and target != null:
						await _click(target)
					elif game.confirm_btn.is_visible_in_tree():
						await _click(game.confirm_btn)
				await _frames(10)
				continue
			if game._awaiting_bar:
				stats["dealer"] = true
				await _snap("05_dealer")
				if pad:
					await _pad(JOY_BUTTON_A)
				else:
					await _click(game.bar_views[game.bar_order[0]])
				await _frames(10)
				continue
			var offer := _btn(game.nego._action_box, "MAKE OFFER") if game.nego.visible else null
			if offer != null:
				stats["offer"] = true
				await _snap("06_offer")
				await _press(offer)
				await _frames(10)
				continue
			var roll := _btn(game.nego._action_box, "ROLL") if game.nego.visible else null
			if roll != null:
				stats["roll"] = true
				await _snap("07_roll")
				await _press(roll)
				await _frames(10)
				continue
			var verdict := _btn(game.nego._action_box, "결과 확인") if game.nego.visible else null
			if verdict != null:
				stats["verdict"] = true
				await _snap("07b_verdict")
				await _press(verdict)
				await _frames(10)
				continue
			var nxt := _btn(game.modal_layer, "NEXT ROUND")
			if nxt == null:
				nxt = _btn(game.modal_layer, "FINAL RESULT")
			if nxt != null:
				if not seen.has("b%d" % int(game.disp["round"])):
					seen["b%d" % int(game.disp["round"])] = true
					stats["boards"] += 1
				await _snap("08_board")
				await _press(nxt)
				await _frames(10)
				continue
			if stuck > 600:
				_ok("a 'do' step can always be answered", false, tut._text.text)
				break
			continue
		# no beat: the table plays on (cutscene-free); keep going
	print("  stats=", stats, " won=", won, " frames=", frames, " same_game=", main.current == game, " tut_valid=", is_instance_valid(tut))
	_ok("Sal talked through the tutorial", int(stats["talk"]) >= 12, str(stats["talk"]))
	_ok("the venue card step was done", stats["info"])
	_ok("I dealt the extra card in round 3", stats["dealer"])
	_ok("I made an offer, rolled and saw the verdict", stats["offer"] and stats["roll"] and stats["verdict"])
	_ok("three round boards were closed", int(stats["boards"]) == 3, str(stats["boards"]))
	_ok("round 1: I took a venue alone", int(won.get(1, 0)) > 0)
	_ok("round 2: I won the duel", str(won.get("duel", "")) == Plan.ME)
	_ok("round 3: my police card took the raided venue", int(won.get(3, 0)) > 0)
	_ok("Sal's talk blocks clicks on the table", stats["blocked"])
	_ok("the pause panel works during the tutorial (overlay steps aside)", stats["pause"])
	var g2 = main.current
	_ok("after the finale a real game starts", g2 != game and g2.get("tutorial") == null and g2.get("state") != null and not g2.state.is_empty() and int(g2.state["round"]) >= 1)
	if g2 != null and g2.get("tutorial") == null:
		var ex: Node = g2.get_node_or_null("/root")
		# back to the menu: the offer is not shown again, the menu offers it as a button instead
		g2.exit_requested.emit()
		await _frames(30)
		var ng2 := _btn(main.current, "NEW GAME")
		if ng2 != null:
			await _click(ng2)
			await _frames(30)
		_ok("the offer is not repeated after the tutorial", main.current.get_node_or_null("TutorialAsk") == null)
	_finish(saved)


func _finish(saved: Array) -> void:
	Settings.music_on = saved[0]
	Settings.sfx_on = saved[1]
	Settings.dialogue_on = saved[2]
	Settings.tutorial_done = saved[3]
	Settings.coach_on = saved[4]
	Settings.speed_name = saved[5]
	Settings.reduce_motion = saved[6]
	Settings.save_settings()
	SaveStore.clear()
	if lang == "en" and not preload("res://tests/text_audit.gd").report_en().is_empty():
		fails.append("korean text left in the English game")
		print("I18N FAIL")
	print("QA TUTORIAL: checks=%d failed=%d pad=%s skip=%s -> %s" % [checks, fails.size(), pad, skip_mode, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
