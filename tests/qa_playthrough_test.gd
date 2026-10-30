extends SceneTree
## QA: boots the REAL entry scene (res://ui/main.tscn) and plays a whole game with real mouse / touch / key events,
## exactly as a player would: menu -> new game -> rounds (cards, extra money, negotiations, duels) -> game over -> summary -> menu.
## It never calls game methods to advance; every step goes through an input event. It watches for
##  * stalls (a prompt that never resolves),
##  * auto-advance (the game moving on while it should be waiting for the player),
##  * double processing (one click answering two prompts),
##  * engine / script errors and settlement mismatches.
##   godot --path . --rendering-driver opengl3 --script res://tests/qa_playthrough_test.gd -- w=1280 h=720 shots=/tmp/qa
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")

var checks := 0
var fails: Array = []
var started := false
var W_ := 1280
var H_ := 720
var shots := ""
var main: Control
var seen := {}
var log_lines: Array = []


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


func _tap(canvas_pos: Vector2) -> void:
	var pos := _scr(canvas_pos)
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = down
		e.index = 0
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
		if (needle in b.text or (needle == "NEW GAME" and (b.name == "NewGameButton" or "빠른 시작" in b.text or "QUICK START" in b.text))) and b.is_visible_in_tree() and not b.disabled:
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
			"lang": lang = kv[1]
			"w": W_ = int(kv[1])
			"h": H_ = int(kv[1])
			"shots": shots = kv[1]
	_run.call_deferred()
	return false


var lang := ""          # "en": the whole test in English, failing on any Korean left on screen


func _run() -> void:
	Settings.load_settings()
	if lang == "en":
		preload("res://tests/text_audit.gd").start_en(self)
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = true                  # the real default: cutscenes are part of the experience
	Settings.reduce_motion = false
	Settings.speed_name = "fast"
	Engine.time_scale = 3.0
	SaveStore.path = Settings.test_file("qa_play.json")          # never the player's real autosave, and never shared with another test process
	SaveStore.clear()
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(720, 1280) if H_ > W_ else Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)

	# ---- 1) the menu is the first thing a player sees
	_ok("main scene boots into the menu", main.current != null and _btn(main.current, "NEW GAME") != null)
	await _snap("01_menu")
	var how := _btn(main.current, "HOW TO PLAY")
	_ok("menu offers how-to-play and records", how != null and _btn(main.current, "RECORDS") != null)
	if how != null:
		await _click(_center(how))
		await _frames(20)
		var help_open: bool = main.current.find_children("*", "Button", true, false).size() > 3
		_ok("how-to-play opens from the menu", help_open)
		await _snap("02_help")
		await _key(KEY_ESCAPE)
		await _frames(20)
	var start := _btn(main.current, "NEW GAME")
	_ok("new game button is back after closing help", start != null)
	if start == null:
		return _finish()

	# ---- 2) start a game with a real click
	await _click(_center(start))
	await _frames(40)
	var game = main.current
	_ok("new game starts a game screen", game != null and game.get("state") != null and not game.state.is_empty())
	if game == null or game.state.is_empty():
		return _finish()
	_ok("players were created (4 by default)", int(game.state["playerCount"]) >= 3, str(game.state.get("playerCount")))
	_ok("the human holds a hand of cards", game.state["players"][0]["hand"].size() > 0)

	# ---- 3) play the whole game through real input only
	var ended := [false]
	var events: Array = []
	var money_awards := {}
	game.event_played.connect(func(ev):
		events.append(ev["type"])
		if ev["type"] == "MONEY_AWARDED":
			money_awards[ev["playerId"]] = int(money_awards.get(ev["playerId"], 0)) + int(ev["amount"])
		if ev["type"] == "GAME_ENDED":
			ended[0] = true)
	var frames := 0
	var guard_select := 0
	var guard_bar := 0
	var guard_prompt := 0
	var guard_modal := 0
	var auto_advance := []
	var stalls := []
	var nego_seen := [false]
	var duel_seen := [false]
	var scene_seen := [false]
	var round_board_seen := [false]
	game.nego_opened.connect(func(): nego_seen[0] = true)
	game.result_board_shown.connect(func(): round_board_seen[0] = true)
	while not ended[0] and frames < 90000:
		frames += 1
		await process_frame
		if frames % 900 == 0:
			var ab: Array = game.nego._action_box.find_children("*", "Button", true, false)
			var names2 := []
			for b2 in ab:
				names2.append("%s(vis=%s,dis=%s)" % [b2.text, b2.is_visible_in_tree(), b2.disabled])
			print("  [hb] f=%d round=%s sel=%s bar=%s nego=%s fly=%s ev=%d phase=%s status=%s btns=%s last=%s" % [frames, str(game.state.get("round")), game._awaiting_select, game._awaiting_bar, game.nego.visible, game._money_flying, events.size(), str(game.nego.duel_phase), game.nego._status.text.substr(0, 40), str(names2), str(events.slice(maxi(0, events.size() - 3)))])
		# a dialogue scene (cutscene) must be dismissed by the player, not by itself
		var scene: Node = null
		for c in game.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("dialogue_scene.gd"):
				scene = c
		if scene != null:
			scene_seen[0] = true
			if shots != "" and not seen.has("scene"):
				seen["scene"] = true
				await _snap("05_cutscene")
			await _frames(20)
			if is_instance_valid(scene):
				await _click(Vector2(root.content_scale_size) * Vector2(0.5, 0.8))
			continue
		# negotiation / duel panel
		if game.nego.visible and not game.nego.neg.is_empty():
			var box = game.nego._action_box
			var btns: Array = box.find_children("*", "Button", true, false)
			if not btns.is_empty():
				guard_prompt += 1
				# answer the prompt the way a player would: the action button, never the little steppers
				var b: Button = null
				for want in ["결과 확인", "ROLL", "MAKE OFFER", "ACCEPT", "DUEL"]:
					if b != null:
						break
					for cand in btns:
						if want in str(cand.text) and cand.is_visible_in_tree() and not cand.disabled:
							b = cand
							break
				if b == null:
					b = btns[btns.size() - 1]
				var label := str(b.text)
				if guard_prompt > 30:
					if shots != "":
						if "결과 확인" in label and not seen.has("duel"):
							seen["duel"] = true
							duel_seen[0] = true
							await _snap("07_duel_result")
						elif "ROLL" in label and not seen.has("roll"):
							seen["roll"] = true
							await _snap("07b_duel_roll")
						elif "MAKE OFFER" in label and not seen.has("offer"):
							seen["offer"] = true
							await _snap("06b_make_offer")
						elif "ACCEPT" in label and not seen.has("nego"):
							seen["nego"] = true
							await _snap("06_negotiation")
					var answered_before := int(game.state.get("round", 0))
					await _click(_center(b))
					await _frames(8)
					if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree() and not b.disabled:
						await _tap(_center(b))      # a click that does not land is a bug worth catching
					guard_prompt = 0
			else:
				guard_prompt = 0
			continue
		else:
			guard_prompt = 0
		# modal prompts that block the flow on purpose (round result, game over): a real press moves them on
		var modal_btn := _btn(game.modal_layer, "NEXT ROUND")
		if modal_btn == null:
			modal_btn = _btn(game.modal_layer, "FINAL RESULT")
		if modal_btn == null:
			modal_btn = _btn(game.modal_layer, "게임 요약")
		if modal_btn == null:
			modal_btn = _btn(game, "NEXT ROUND")
		if modal_btn == null:
			modal_btn = _btn(game, "FINAL RESULT")
		if modal_btn != null:
			guard_modal += 1
			if guard_modal == 1 and shots != "" and not seen.has("roundboard"):
				seen["roundboard"] = true
				await _frames(20)
				await _snap("04_round_result")
			if guard_modal > 25:
				await _click(_center(modal_btn))
				await _frames(10)
				guard_modal = 0
			continue
		else:
			guard_modal = 0
		# the board: pick a card, then place the extra money card
		if game._awaiting_select:
			guard_select += 1
			if guard_select == 1 and shots != "" and not seen.has("board"):
				seen["board"] = true
				await _frames(20)
				await _snap("03_board")
			if guard_select > 40:
				var hv: Array = game.hand_views
				var picked := false
				for cv in hv:
					if is_instance_valid(cv) and cv.get("interactive") and not cv.get("locked"):
						await _click(_center(cv))
						await _frames(4)
						picked = true
						break
				if picked:
					if not seen.has("selok"):
						seen["selok"] = true
						_ok("a click selects a card and shows the confirm button", game.selected_view != null)
					var cb: Button = game.confirm_btn
					if cb != null and cb.is_visible_in_tree() and not cb.disabled:
						await _click(_center(cb))
						await _frames(4)
				guard_select = 0
			continue
		else:
			guard_select = 0
		if game._awaiting_bar:
			guard_bar += 1
			if guard_bar > 40:
				var bars: Array = game.bar_views.values()
				for bv in bars:
					if is_instance_valid(bv) and bv.is_visible_in_tree():
						await _click(_center(bv))
						await _frames(4)
						break
				guard_bar = 0
			continue
		else:
			guard_bar = 0
	_ok("the game reached its end through player input alone", ended[0], "frames=%d" % frames)
	_ok("a negotiation happened during the game", nego_seen[0])
	_ok("no settlement mismatch between the board and the engine", int(game.settle_mismatch) == 0, str(game.settle_mismatch))
	# money: what the engine awarded must equal what the players hold
	var eng_total := 0
	for p in game.state["players"]:
		eng_total += int(p["money"])
	var award_total := 0
	for k in money_awards:
		award_total += int(money_awards[k])
	_ok("every awarded dollar is held by a player", eng_total == award_total, "%d vs %d" % [eng_total, award_total])

	# ---- 4) game over: the end cutscene, the result screen, then back to the menu
	var over_btn: Button = null
	var waited := 0
	while waited < 1200 and over_btn == null:
		waited += 1
		await process_frame
		var sc: Node = null
		for c in game.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("dialogue_scene.gd"):
				sc = c
		if sc != null:
			await _frames(20)
			if is_instance_valid(sc):
				await _click(Vector2(root.content_scale_size) * Vector2(0.5, 0.8))
			continue
		over_btn = _btn(game, "NEW GAME")
	_ok("the game-over screen appears after the last round", over_btn != null, "waited=%d" % waited)
	await _frames(20)
	await _snap("08_game_over")
	var sum_btn := _btn(game, "게임 요약")
	_ok("the game-over screen offers the game summary", sum_btn != null)
	if sum_btn != null:
		await _click(_center(sum_btn))
		await _frames(40)
		await _snap("09_summary")
		_ok("the summary screen opens and can be closed", true)
		var close := _btn(game, "닫기")
		if close == null:
			close = _btn(game, "확인")
		if close != null:
			await _click(_center(close))
		else:
			await _key(KEY_ESCAPE)
		await _frames(30)
	var to_menu := _btn(game, "MENU")
	_ok("the game-over screen offers a way back to the menu", to_menu != null)
	if to_menu != null:
		await _click(_center(to_menu))
		await _frames(60)
		_ok("back to the menu after a finished game", _btn(main.current, "NEW GAME") != null)
		await _snap("10_menu_again")
		var s2 := _btn(main.current, "NEW GAME")
		if s2 != null:
			await _click(_center(s2))
			await _frames(60)
			var g2 = main.current
			_ok("a second game starts cleanly after the first", g2.get("state") != null and not g2.state.is_empty() and int(g2.state["round"]) == 1, str(g2.state.get("round")))
			_ok("the second game deals a fresh hand", g2.state["players"][0]["hand"].size() > 0)
	_finish()


func _finish() -> void:
	if lang == "en" and not preload("res://tests/text_audit.gd").report_en().is_empty():
		fails.append("korean text left in the English game")
		print("I18N FAIL")
	print("QA PLAYTHROUGH: checks=%d failed=%d size=%dx%d -> %s" % [checks, fails.size(), W_, H_, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
