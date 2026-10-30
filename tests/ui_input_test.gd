extends SceneTree
## Plays a whole game with keyboard/gamepad actions only (ui_left/right, ui_accept, ui_cancel) – no bot.
##   godot --headless --path . --script res://tests/ui_input_test.gd -- players=4 seed=5
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")

var args := {}
var game
var started := false
var acc := 0.0
var state_stage := 0
var cancel_tested := false
var cancel_ok := false
var focus_seen := false
var fan_ok := false
var ended := false
var rounds := 0
var t0 := 0
var shots := ""
var taken := {}


func _process(d: float) -> bool:
	if not started:
		started = true
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = a.split("=")
			args[kv[0]] = kv[1]
		Engine.time_scale = 8.0
		shots = str(args.get("shots", ""))
		if int(args.get("w", 0)) > 0:
			root.size = Vector2i(int(args.w), int(args.h))
			root.content_scale_size = Vector2i(720, 1280) if int(args.h) > int(args.w) else Vector2i(1280, 720)
		t0 = Time.get_ticks_msec()
		var n := int(args.get("players", 4))
		var s := Eng.create_game({"playerCount": n, "seed": int(args.get("seed", 5)), "humanPlayerId": "P1",
			"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, n)})
		game = Game.new()
		game.autosave_enabled = false
		root.add_child(game)
		game.event_played.connect(func(ev):
			if ev["type"] == "ROUND_ENDED": rounds += 1
			if ev["type"] == "GAME_ENDED" and not ended:
				ended = true
				_finish())
		game.idle.connect(_on_idle)
		game.begin(s)
		return false
	acc += d
	if acc < 0.2 / Engine.time_scale * 4.0:
		return false
	acc = 0.0
	if game._awaiting_select and not fan_ok and game.hand_views.size() == 5 and not game.hand_views[0].has_meta("intro"):
		# fan geometry: outer cards tilt outwards, a hovered card is lifted and drawn in front
		var tl = game._hand_target(0, 5)
		var tr = game._hand_target(4, 5)
		var tm = game._hand_target(2, 5)
		var base_y: float = tm["pos"].y
		game.hand_views[2].hovering = true
		game.hand_views[2].interactive = true
		var lifted = game._hand_target(2, 5)
		game.hand_views[2].hovering = false
		fan_ok = tl["rot"] < 0.0 and tr["rot"] > 0.0 and absf(tm["rot"]) < 0.001 and lifted["pos"].y < base_y - 5.0 and lifted["front"]
	if game._awaiting_select:
		if not cancel_tested:
			# staged so each state can be photographed after its tweens settle: hover -> focus -> select -> cancel
			match state_stage:
				0:
					game.hand_views[3].hovering = true
					game._on_hand_hover(game.hand_views[3])
					state_stage = 1
				1:
					_snap("state_hover")
					game.hand_views[3].hovering = false
					game._on_hand_hover(game.hand_views[3])
					_press("ui_right")
					state_stage = 2
				2:
					_snap("state_focus")
					_press("ui_accept")
					state_stage = 3
				3:
					_snap("state_selected")
					if game.selected_view != null and game.hand_views.any(func(v): return v.focused) and not game.confirm_btn.disabled:
						focus_seen = true
					_press("ui_cancel")
					state_stage = 4
				4:
					_snap("state_cancelled")
					cancel_ok = game.selected_view == null and game.confirm_btn.disabled
					cancel_tested = true
		elif game.selected_view == null:
			_press("ui_accept")        # focus already on a card -> select
		else:
			_press("ui_accept")        # second accept -> play
	elif game._awaiting_bar:
		_press("ui_right"); _press("ui_accept")
	else:
		_press("ui_accept")            # focused modal button (negotiation / duel / round result)
	return false


func _on_idle(pending: Dictionary) -> void:
	var t: String = pending["type"]
	if shots == "" or taken.has(t) or t == "SELECT_CARD":
		return
	taken[t] = true
	await create_timer(0.6 / Engine.time_scale).timeout
	await process_frame
	root.get_texture().get_image().save_png("%s/human_%s.png" % [shots, t.to_lower()])


func _snap(name: String) -> void:
	if shots != "":
		root.get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func _press(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _finish() -> void:
	await process_frame
	var ok := fan_ok and rounds >= 12 and rounds == int(game.state["round"]) and cancel_ok and focus_seen
	print("INPUT TEST: fanOk=%s rounds=%d cancelOk=%s focusSeen=%s secs=%.1f -> %s" % [fan_ok, rounds, cancel_ok, focus_seen, (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
