extends SceneTree
## Real-mouse hit test (Phase 8B-5). Mouse picking in Godot follows TREE order, not z_index, so a control added later can silently
## swallow clicks meant for a button underneath it. For a whole game (no bot; prompts answered the frame they appear):
##   1. every control the player must click (hand cards, PLAY CARD, venues at the extra-money prompt, every negotiation button,
##      the result-board button, SKIP and the exit button during a replay) is sampled at several points; a real InputEventMouseMotion
##      is injected and the viewport is asked which control is under the pointer -> it must be that control (or a child of it);
##   2. real motion + press/release on the lower edge of every hand card (the part a hovered card lifts away from) must select it.
##   godot --headless --fixed-fps 60 --path . --script res://tests/ui_mouse_hit_test.gd [-- w=430 h=932 players=4 seed=5]
## SCRIPT ERROR lines are not catchable from GDScript: grep the output for them.
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const Settings = preload("res://ui/settings.gd")

var args := {}
var started := false
var game
var rng
var ended := false
var fails := {}       # key -> {n, who}
var checks := {}      # phase -> n
var nego_sigs := {}
var board_swept := false
var replay_swept := 0
var edge_n := 0
var edge_fail := 0
var edge_done := false

func _process(d: float) -> bool:
	if not started:
		started = true
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = a.split("=")
			args[kv[0]] = kv[1]
		var w := int(args.get("w", 1280)); var h := int(args.get("h", 720))
		root.size = Vector2i(w, h)
		root.content_scale_size = Vector2i(720, 1280) if h > w else Vector2i(1280, 720)
		Settings.load_settings()
		Settings.speed_name = str(args.get("speed", "NORMAL"))
		Settings.reduce_motion = false
		var np := int(args.get("players", 4))
		var s := Eng.create_game({"playerCount": np, "seed": int(args.get("seed", 5)), "humanPlayerId": "P1",
			"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, np)})
		game = Game.new()
		game.autosave_enabled = false
		root.add_child(game)
		rng = AI.new_rng(11)
		game.idle.connect(_on_idle)
		game.event_played.connect(_on_event)
		game.begin(s)
		return false
	_pump()
	if ended:
		_tick += 1
		if _tick > 120:
			_finish()
	return false

func _tweens() -> int:
	var n := 0
	for tw in get_processed_tweens():
		if tw.is_valid() and tw.is_running():
			n += 1
	return n

func _scr(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func _hover_at(p: Vector2) -> Control:
	var e := InputEventMouseMotion.new()
	e.position = _scr(p); e.global_position = e.position
	Input.parse_input_event(e); Input.flush_buffered_events()
	return root.gui_get_hovered_control()

func _pt(c: Control, fx: float, fy: float) -> Vector2:
	# rotation-safe: centre-ish points only (cards are rotated up to 5 degrees)
	return c.get_global_transform_with_canvas() * Vector2(c.size.x * fx, c.size.y * fy)

## `want`: control that should own the point (or one of its descendants)
func _sweep(phase: String, name: String, c: Control, pts: Array = [[0.5, 0.5], [0.15, 0.2], [0.85, 0.2], [0.15, 0.8], [0.85, 0.8]]) -> void:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return
	for fp in pts:
		var p: Vector2 = _pt(c, fp[0], fp[1])
		var vr := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		checks[phase] = int(checks.get(phase, 0)) + 1
		if not vr.has_point(p):
			_fail(phase, name, fp, "OFFSCREEN %s" % str(p))
			continue
		var h := _hover_at(p)
		if h == c or (h != null and c.is_ancestor_of(h)):
			continue
		var who := "null"
		if h != null:
			who = "%s z=%d mf=%d rect=%s" % [str(game.get_path_to(h)) if game.is_ancestor_of(h) else str(h), h.z_index, h.mouse_filter, str(h.get_global_rect())]
			if "card" in h:
				who += " card=%s face_up=%s interactive=%s" % [str(h.card.get("id", "")), str(h.face_up), str(h.interactive)]
		_fail(phase, name, fp, "covered by %s | want z=%d rect=%s par=%s" % [who, c.z_index, str(c.get_global_rect()), str(c.get_parent().get_class())])

func _fail(phase: String, name: String, fp: Array, who: String) -> void:
	var k := "%s | %s | %s" % [phase, name, who]
	if not fails.has(k):
		fails[k] = {"n": 0, "pt": fp}
	fails[k]["n"] += 1

func _pump() -> void:
	if game == null or not is_instance_valid(game):
		return
	var f := root.gui_get_focus_owner()
	if f is Button and f.is_visible_in_tree():
		if game.nego.is_ancestor_of(f):
			# sweep every visible button of this nego screen once
			var sig := ""
			for b in _buttons(game.nego):
				sig += b.text + "|"
			if not nego_sigs.has(sig) and _tweens() == 0:
				nego_sigs[sig] = true
				for b in _buttons(game.nego):
					if not b.disabled:
						_sweep("nego", "btn[%s]" % b.text.substr(0, 14), b, [[0.5, 0.5], [0.12, 0.5], [0.88, 0.5], [0.5, 0.15], [0.5, 0.85]])
			f.emit_signal("pressed")
		elif game.modal_layer.is_ancestor_of(f) and _tweens() == 0:
			if not board_swept:
				board_swept = true
				_sweep("board", "btn[%s]" % f.text, f)
			f.emit_signal("pressed")

func _buttons(n: Node) -> Array:
	var out := []
	if n is Button and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out

func _on_event(ev: Dictionary) -> void:
	if game.skip_btn.visible and replay_swept < 3 and ev["type"] in ["CARDS_REVEALED", "BAR_RESOLVED", "MONEY_PLACED"]:
		replay_swept += 1
		_sweep("replay", "SKIP btn", game.skip_btn)
		_sweep("replay", "exit btn", game.exit_btn)
	if ev["type"] == "GAME_ENDED":
		ended = true

func _on_idle(p: Dictionary) -> void:
	await process_frame
	await process_frame
	await process_frame
	if game == null or not is_instance_valid(game):
		return
	var v := Eng.get_public_view(game.state, "P1")
	if p["type"] == "SELECT_CARD":
		# wait for the hand to settle, then sweep everything the player can click
		var g := 0
		while _tweens() > 0 and g < 200:
			await process_frame; g += 1
		_hover_at(Vector2(2, 700))
		for i in range(game.hand_views.size()):
			_sweep("select", "hand[%d]" % i, game.hand_views[i], [[0.5, 0.5], [0.5, 0.15], [0.5, 0.85]])
			_hover_at(Vector2(2, 700))
			await process_frame; await process_frame
			var g2 := 0
			while _tweens() > 0 and g2 < 100:
				await process_frame; g2 += 1
		_hover_at(Vector2(2, 700))
		_sweep("select", "exit btn", game.exit_btn)
		_sweep("select", "opp btn", game.opp_btn)
		if not edge_done:
			edge_done = true
			await _edge_clicks()
		game._on_hand_pressed(game.hand_views[0])
		await process_frame
		_sweep("select", "confirm btn", game.confirm_btn)
		game._human_action.emit({"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)})
	elif p["type"] == "PLACE_EXTRA_MONEY":
		var g3 := 0
		while _tweens() > 0 and g3 < 200:
			await process_frame; g3 += 1
		for id in game.bar_views:
			var bv = game.bar_views[id]
			if bv.visible and bv.clickable:
				_sweep("extra", "bar %s" % id, bv, [[0.5, 0.5], [0.2, 0.2], [0.8, 0.2], [0.2, 0.8], [0.8, 0.8], [0.5, 0.95]])
		game._human_action.emit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)})

func _physics_process(_d: float) -> bool:
	return false

func _finish() -> void:
	var total := 0
	for k in checks:
		total += int(checks[k])
	for k in fails:
		print("  FAIL x%d  %s  at %s" % [fails[k]["n"], k, str(fails[k]["pt"])])
	for k in checks:
		print("  phase %-8s %d points" % [k, checks[k]])
	var need_phases := ["select", "extra", "nego", "board", "replay"]
	var missing := []
	for ph in need_phases:
		if int(checks.get(ph, 0)) == 0:
			missing.append(ph)
	print("  hand lower-edge clicks: %d tried, %d failed" % [edge_n, edge_fail])
	var ok := fails.is_empty() and missing.is_empty() and edge_fail == 0 and edge_n >= 30
	print("MOUSE HIT TEST: points=%d failed=%d missing_phases=%s edge_clicks=%d/%d -> %s" % [total, fails.size(), str(missing), edge_n - edge_fail, edge_n, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)

var _tick := 0
func _notification(what: int) -> void:
	pass


func _click(p: Vector2) -> void:
	for pr in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pr
		e.position = _scr(p)
		e.global_position = e.position
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pr else 0
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame


## The pointer rests on the lowest part of a card long enough for the hover lift to play out, then clicks: the card must still be there.
func _edge_clicks() -> void:
	for i in range(game.hand_views.size()):
		var cv = game.hand_views[i]
		for fx in [0.2, 0.5, 0.8]:
			for fy in [0.9, 0.97]:
				_hover_at(Vector2(2, 700))
				for _k in range(25):
					await process_frame
				game._deselect()
				var pt: Vector2 = _pt(cv, fx, fy)
				_hover_at(pt)
				for _k in range(20):
					await process_frame
				await _click(pt)
				await process_frame
				edge_n += 1
				if game.selected_view != cv:
					edge_fail += 1
					print("  FAIL edge click card %d at (%.2f, %.2f) selected=%d" % [i, fx, fy, game.hand_views.find(game.selected_view)])
				game._deselect()
	_hover_at(Vector2(2, 700))
