extends SceneTree
## Test B/C (UI): a duel the human is part of keeps its result until confirmed (no auto-advance, repeated Enter safe),
## the verdict is shown as words, and the extra money card announces before -> +amount -> after matching the events.
## The table is staged (the tutorial's seed and scripted AI, without Sal): round 1 an AI dealer places the extra card,
## round 2 I offer first to Vito, he refuses, the duel is played with real key presses.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_duel_flow_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const Plan = preload("res://ui/tutorial_plan.gd")
var game
var checks := 0
var fails: Array = []
var started := false


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _btn(needle: String) -> Button:
	if not game.nego.visible:
		return null
	for b in game.nego._action_box.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _run() -> void:
	Settings.load_settings()
	Settings.speed_name = "NORMAL"
	Settings.reduce_motion = false
	Settings.dialogue_on = false
	Settings.coach_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var s := Eng.create_game(Plan.config())
	game = Game.new()
	game.autosave_enabled = false
	game.ai_script = func(kind, pid, _view): return Plan.decide(game.ctl.state, kind, pid)
	var st := {"extra_ev": {}, "resolved": false, "advanced_early": false, "confirmed": false}
	game.event_played.connect(func(ev):
		var ty := str(ev["type"])
		if ty == "MONEY_PLACED" and bool(ev["extra"]) and st["extra_ev"].is_empty():
			st["extra_ev"] = ev
		elif ty == "DUEL_RESOLVED":
			st["resolved"] = true
		elif st["resolved"] and not st["confirmed"] and ty != "MONEY_PLACED":
			st["advanced_early"] = true)
	root.add_child(game)
	game.begin(s)

	# ---- round 1: the AI dealer's extra card line names before, amount and after
	var f := 0
	while f < 3000 and st["extra_ev"].is_empty():
		f += 1
		await process_frame
	await _frames(5)
	var ev: Dictionary = st["extra_ev"]
	_ok("an AI dealer placed the extra money card", not ev.is_empty())
	if not ev.is_empty():
		var le: Dictionary = game.last_extra
		var txt: String = game.now_label.text
		_ok("extra: bar and amount equal the MONEY_PLACED event", le.get("barId") == ev["barId"] and int(le.get("amount", -1)) == int(ev["value"]))
		_ok("extra: after == before + amount", int(le["after"]) == int(le["before"]) + int(le["amount"]))
		_ok("extra: the line names before, amount and after", game.T.money(le["before"]) in txt and game.T.money(le["amount"]) in txt and game.T.money(le["after"]) in txt, txt)
		_ok("extra: the venue keeps the gold tag", game.bar_views[str(ev["barId"])].extra_amount == int(ev["value"]))

	# ---- play the planned cards; offer; Vito refuses; roll with Enter
	var confirm_seen := false
	f = 0
	while f < 20000 and not confirm_seen:
		f += 1
		await process_frame
		if game._awaiting_select and int(game.state["round"]) <= 2:
			await _frames(30)
			var t: Dictionary = Plan.human_target(game.state)
			game._human_action.emit({"type": "SELECT_CARD", "playerId": game.human_id, "cardId": t["id"]})
			await _frames(5)
			continue
		var modal_next: Button = null
		for b in game.modal_layer.find_children("*", "Button", true, false):
			if "NEXT ROUND" in b.text and b.is_visible_in_tree():
				modal_next = b
		if modal_next != null:
			await _frames(30)
			modal_next.emit_signal("pressed")
			await _frames(5)
			continue
		var offer := _btn("MAKE OFFER")
		if offer != null:
			await _frames(40)
			offer.emit_signal("pressed")
			continue
		var roll := _btn("ROLL")
		if roll != null:
			await _frames(45)                  # the button arms its focus after a short guard
			await _key(KEY_ENTER)
			continue
		var conf := _btn("결과 확인")
		if conf != null:
			confirm_seen = true
			_ok("duel result: confirm button shown", true)
			_ok("duel result: verdict words are on screen", game.nego._verdict_a.text.begins_with("▲") or game.nego._verdict_b.text.begins_with("▲"), "%s / %s" % [game.nego._verdict_a.text, game.nego._verdict_b.text])
			await _frames(240)                 # 4 s: it must still be waiting
			_ok("duel result: no auto-advance after 4 s", not st["advanced_early"] and is_instance_valid(conf) and conf.is_inside_tree())
			await _key(KEY_ENTER)
			st["confirmed"] = true
			await _key(KEY_ENTER)              # a second, stray Enter
			await _frames(10)
			var gone := not is_instance_valid(conf) or conf.is_queued_for_deletion() or not conf.is_inside_tree()
			_ok("duel result: Enter confirms, a repeated Enter does nothing harmful", gone)
	_ok("a duel with the human happened (staged table)", confirm_seen and st["resolved"])
	var fatal = game.state.get("fatal", [])
	_ok("the engine reported no broken invariant", fatal == null or fatal.is_empty())
	print("DUEL FLOW TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
