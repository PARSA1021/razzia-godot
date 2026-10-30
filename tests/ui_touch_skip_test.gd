extends SceneTree
## `skip` must only ever be set while the board replays events. Taps/clicks on empty table while the human is deciding
## (card, extra-money bar, negotiation answer) used to leave `skip` set, so the next reveal/result replay ran instantly.
##   godot --headless --path . --script res://tests/ui_touch_skip_test.gd -- [seed=5] [players=4] [w=1280] [h=720]
## The tap events are built as real InputEventScreenTouch / InputEventMouseButton objects and delivered to GameScreen._gui_input
## (that is the handler an empty-table tap reaches). Real touch hardware is not covered.
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const SettingsX = preload("res://ui/settings.gd")

var args := {}
var game
var started := false
var rng := AI.new_rng(7)
var t0 := 0
var t_confirm := 0
var round1_done := false
var n_checks := 0
var n_sel_me := 0
var n_rounds := 0
var n_reveal := 0
var saw_s1 := false
var fails: Array = []
var taps_in_decision := 0
var _decision_handled := false
var _acc := 0.0


func _process(d: float) -> bool:
	if not started:
		started = true
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = a.split("=")
			args[kv[0]] = kv[1]
		var w := int(args.get("w", 1280))
		var h := int(args.get("h", 720))
		root.size = Vector2i(w, h)
		root.content_scale_size = Vector2i(720, 1280) if h > w else Vector2i(1280, 720)
		t0 = Time.get_ticks_msec()
		var n := int(args.get("players", 4))
		var s := Eng.create_game({"playerCount": n, "seed": int(args.get("seed", 5)), "humanPlayerId": "P1",
			"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, n)})
		SettingsX.dialogue_on = false
		game = Game.new()
		game.autosave_enabled = false
		root.add_child(game)
		game.idle.connect(_on_idle)
		game.event_played.connect(_on_event)
		game.begin(s)
		create_timer(120.0, true, false, true).timeout.connect(func():
			printerr("TOUCH SKIP TEST TIMEOUT")
			quit(2))
		return false
	_acc += d
	if _acc >= 0.25:
		_acc = 0.0
		_drive_panel()
	return false


func _ok(name: String, cond: bool, info: String = "") -> void:
	n_checks += 1
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, info])
	if not cond:
		fails.append(name)


func _tap_events() -> Array:
	var out: Array = []
	var pos := Vector2(root.size) * 0.5
	for pr in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = pos
		t.pressed = pr
		out.append(t)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	m.position = pos
	out.append(m)
	return out


func _tap() -> void:
	for e in _tap_events():
		game._gui_input(e)


func _on_idle(p: Dictionary) -> void:
	if game.skip:
		_ok("skip is false whenever the human is asked (%s)" % p["type"], false)
	match p["type"]:
		"SELECT_CARD":
			if not round1_done and not saw_s1:
				saw_s1 = true
				await create_timer(1.5, true, false, true).timeout       # real time; the board has settled
				_tap()
				_ok("S1 tap while choosing leaves skip unset", not game.skip)
				game._on_hand_pressed(game.hand_views[0])
				t_confirm = Time.get_ticks_msec()
				game._on_confirm()
				game._on_confirm()            # double tap / double Enter: must not submit twice
				game._accept_focus()
			else:
				await create_timer(0.1, true, false, true).timeout
				game._on_hand_pressed(game.hand_views[0])
				game._on_confirm()
		"PLACE_EXTRA_MONEY":
			await create_timer(0.1, true, false, true).timeout
			_tap()
			_ok("tap while choosing the extra-money bar leaves skip unset", not game.skip)
			game._on_bar_chosen(game.bar_order[0])
		"MAKE_PROPOSAL", "RESPOND":
			pass          # handled in _drive_panel once the panel is waiting for the answer


func _on_event(ev: Dictionary) -> void:
	var t: String = ev["type"]
	if t == "CARD_SELECTED" and ev["playerId"] == "P1":
		n_sel_me += 1
	if t == "ROUND_ENDED":
		n_rounds += 1
	if t == "CARDS_REVEALED":
		n_reveal += 1
	if t == "CARDS_REVEALED" and t_confirm > 0 and not round1_done:
		var ms := Time.get_ticks_msec() - t_confirm
		# un-skipped replay at normal speed takes ~3 s; a replay that inherited skip=true took ~30 ms
		_ok("S1 reveal after a stray tap still plays its animation", ms >= 1500, "(%d ms)" % ms)
		# S2: a tap *while events replay* is the intended skip and must still work
		_tap()
		_ok("S2 tap during replay still skips", game.skip)
		round1_done = true
		Engine.time_scale = 8.0
	if t == "GAME_ENDED":
		_finish()


## Negotiation answers: the panel waits on its own `decided` signal, outside the card/bar prompts.
func _drive_panel() -> void:
	if game == null or game.nego == null:
		return
	for b in game.find_children("*", "Button", true, false):
		if b.text in ["NEXT ROUND", "FINAL RESULT"] and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()          # round-result board: continue
			return
	if not game.nego.visible:
		return
	var btn: Button = null
	for b in game.nego._action_box.find_children("*", "Button", true, false):
		if ("MAKE OFFER" in b.text or "ACCEPT" in b.text or "ROLL THE DIE" in b.text) and not b.disabled:
			btn = b
	if btn == null:
		return
	if not game.skip_btn.visible:
		# a human decision (proposal / response): the board is not replaying -> a tap here must not set skip
		_tap()
		taps_in_decision += 1
		_ok("S3 tap during a negotiation decision leaves skip unset (#%d)" % taps_in_decision, not game.skip)
	btn.pressed.emit()


func _finish() -> void:
	await process_frame
	_ok("one CARD_SELECTED / CARDS_REVEALED per round (no duplicate submit or replay)", n_sel_me == n_rounds and n_reveal == n_rounds and game.ctl.error.is_empty(), "(me=%d reveals=%d rounds=%d)" % [n_sel_me, n_reveal, n_rounds])
	_ok("S3 reached (human negotiation decision seen)", taps_in_decision > 0, "(seed %s)" % str(args.get("seed", 5)))
	print("TOUCH SKIP TEST: checks=%d failed=%d secs=%.1f -> %s" % [n_checks, fails.size(), (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
