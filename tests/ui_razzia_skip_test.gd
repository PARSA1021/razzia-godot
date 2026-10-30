extends SceneTree
## RAZZIA fx: SKIP must end it at once, leave nothing behind, and FAST must scale it (Phase 8B-2).
##   godot --headless --fixed-fps 60 --path . --script res://tests/ui_razzia_skip_test.gd -- [part=A|B|AB]
##   (--fixed-fps makes the virtual clock exact and lets the whole-game part run in seconds instead of minutes)
## Part A  _fx_razzia() on its own (virtual time = sum of frame deltas; run with --fixed-fps 60 for exact numbers):
##   skip right after the start / during the flashes / during the stamp / during the hold / during the fade, repeated skip
##   requests, no skip (NORMAL, FAST, SLOW), reduced motion. Checks: time from the skip request to the end, nothing left in
##   fx_layer, no tween left running, the coroutine finishes exactly once.
## Part B  whole games through the real board (no bot): a skip schedule is applied to every RAZZIA fx that starts, then
##   - the played event list == the engine's event list (nothing lost, nothing twice, same order)
##   - displayed money == engine money, settle_mismatch == 0, no fx layer left
##   - NORMAL-with-skips, FAST and reduced motion end in the same engine state
##   - the round-result board is ~half as long under FAST
## SCRIPT ERROR lines are not catchable from GDScript: grep the output for them.
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const Settings = preload("res://ui/settings.gd")

var args := {}
var started := false
var vt := 0.0
var n_checks := 0
var fails: Array = []
var game
var rng
var pump_on := false
var board_t := -1.0
var board_log: Array = []
var fx_log: Array = []
var _fx_start := -1.0
var _fx_pressed := -1.0
var _fx_plan := -1.0
var _fx_count := 0
var schedule: Array = []
var ended := false
var types_played: Array = []
var _fx_n_done := 0


func _process(d: float) -> bool:
	if not started:
		started = true
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = a.split("=")
			args[kv[0]] = kv[1]
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		_main()
		return false
	vt += d
	if pump_on:
		_pump()
	return false


func _ok(name: String, cond: bool, info: String = "") -> void:
	n_checks += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, info])


func _cfg(speed: String, reduce: bool) -> void:
	Settings.load_settings()
	Settings.speed_name = speed
	Settings.reduce_motion = reduce


func _razzia_layers() -> Array:
	var out: Array = []
	for c in game.fx_layer.get_children():
		# the fx layer = a full-rect Control whose first child is the colour wash (flying money cards are Controls too)
		# (Phase 26: the first child is the RaidFX shot, ui/raid_fx.gd)
		if c is Control and not c.is_queued_for_deletion() and c.get_child_count() > 0 and (c.get_child(0) is ColorRect or (c.get_child(0).get_script() != null and str(c.get_child(0).get_script().resource_path).ends_with("raid_fx.gd"))):
			out.append(c)
	return out


func _running_tweens() -> int:
	var n := 0
	for tw in get_processed_tweens():
		if tw.is_valid() and tw.is_running():
			n += 1
	return n


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _new_game(players: int, seed_: int, flow: bool = false) -> void:
	var s := Eng.create_game({"playerCount": players, "seed": seed_, "humanPlayerId": "P1",
		"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, players)})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	rng = AI.new_rng(seed_ * 31 + 7)
	if flow:
		# connected BEFORE begin(): GAME_STARTED and the first prompt can be emitted synchronously
		game.idle.connect(_on_idle)
		game.event_played.connect(func(ev):
			types_played.append(ev["type"])
			if ev["type"] == "GAME_ENDED":
				ended = true)
	game.begin(s)


func _drop_game() -> void:
	pump_on = false
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null
	await _frames(3)


func _main() -> void:
	var part := str(args.get("part", "AB"))
	var t0 := Time.get_ticks_msec()
	if part.contains("A"):
		await _part_a()
	if part.contains("B"):
		await _part_b()
	print("RAZZIA SKIP TEST: checks=%d failed=%d secs=%.1f -> %s" % [n_checks, fails.size(), (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("  failed: ", fails)
	quit(0 if fails.is_empty() else 1)


## ---------------------------------------------------------------------------- part A: the fx on its own

func _fx_case(name: String, skip_at: float, requests: int, lo: float, hi: float, after_max: float) -> void:
	game.skip = false
	var base_children: int = game.fx_layer.get_child_count()
	var tw_before := _running_tweens()
	var done := [0, 0.0]            # [times finished, virtual time of the finish]
	var run := func():
		await game._fx_razzia()
		done[0] += 1
		done[1] = vt
	var t0 := vt
	run.call()
	var pressed := -1.0
	var guard := 0
	while done[0] == 0 and guard < 3000:
		await process_frame
		guard += 1
		if skip_at >= 0.0 and pressed < 0.0 and vt - t0 >= skip_at:
			pressed = vt
			game.skip = true
		elif pressed >= 0.0 and requests > 1 and vt - pressed < 0.1:
			game.skip = true         # repeated requests while it is ending
	var total: float = done[1] - t0
	var after: float = (done[1] - pressed) if pressed >= 0.0 else -1.0
	await _frames(4)
	var info := "total=%.3fs after_skip=%s" % [total, ("%.3fs" % after) if after >= 0.0 else "-"]
	_ok("%s: finishes (once)" % name, done[0] == 1, "finished=%d" % done[0])
	if lo >= 0.0:
		_ok("%s: duration in [%.2f, %.2f]" % [name, lo, hi], total >= lo and total <= hi, info)
	if after_max >= 0.0:
		_ok("%s: ends within %.2fs of the skip request" % [name, after_max], pressed >= 0.0 and after <= after_max, info)
	_ok("%s: nothing left in fx_layer" % name, game.fx_layer.get_child_count() == base_children, "children=%d base=%d" % [game.fx_layer.get_child_count(), base_children])
	_ok("%s: no tween left running" % name, _running_tweens() <= tw_before, "running=%d before=%d" % [_running_tweens(), tw_before])
	game.skip = false


func _part_a() -> void:
	print("== part A: _fx_razzia on its own")
	Engine.time_scale = 1.0
	_cfg("NORMAL", false)
	_new_game(4, 5)
	await game.idle                  # the board is built and waits for the human; nothing else plays
	await _frames(5)
	var settle := 0
	while game.fx_layer.get_child_count() > 0 and settle < 240:
		settle += 1                  # the "+$5,000" amounts over the venues fade out on their own (Phase 23)
		await process_frame
	# NORMAL (P7): 2.0 s hold + 0.25 s fade
	await _fx_case("NORMAL no skip", -1.0, 1, 2.15, 2.40, -1.0)
	await _fx_case("NORMAL skip right after start", 0.02, 1, -1.0, -1.0, 0.10)
	await _fx_case("NORMAL skip during flashes (0.30s)", 0.30, 1, -1.0, -1.0, 0.10)
	await _fx_case("NORMAL skip during stamp (1.10s)", 1.10, 1, -1.0, -1.0, 0.10)
	await _fx_case("NORMAL skip during hold (1.80s)", 1.80, 1, -1.0, -1.0, 0.10)
	await _fx_case("NORMAL skip during fade (2.15s)", 2.15, 1, -1.0, -1.0, 0.10)
	await _fx_case("NORMAL repeated skip requests", 0.50, 6, -1.0, -1.0, 0.10)
	# skip set before the fx starts: nothing is built at all
	game.skip = true
	var c0: int = game.fx_layer.get_child_count()
	await game._fx_razzia()
	await _frames(3)
	_ok("skip already set: no layer, returns at once", game.fx_layer.get_child_count() == c0)
	game.skip = false
	# FAST: the hold and the fade are scaled by Settings.dur (flashes keep their own length)
	_cfg("FAST", false)
	await _fx_case("FAST no skip", -1.0, 1, 1.25, 1.50, -1.0)
	await _fx_case("FAST skip during stamp (0.80s)", 0.80, 1, -1.0, -1.0, 0.10)
	await _fx_case("FAST skip during fade (1.30s)", 1.30, 1, -1.0, -1.0, 0.10)
	_cfg("SLOW", false)
	await _fx_case("SLOW no skip", -1.0, 1, 3.50, 3.80, -1.0)
	_cfg("NORMAL", true)
	await _fx_case("reduced motion: instant", -1.0, 1, 0.0, 0.10, -1.0)
	await _drop_game()


## ---------------------------------------------------------------------------- part B: whole games

func _pump() -> void:
	if game == null or not is_instance_valid(game):
		return
	# RAZZIA fx bookkeeping + the skip schedule (the same effect as the SKIP button / a tap on the table)
	var layers := _razzia_layers()
	if layers.size() > 0:
		if _fx_start < 0.0:
			_fx_start = vt
			_fx_pressed = -1.0
			_fx_plan = float(schedule[_fx_count % schedule.size()])
			_fx_count += 1
		if _fx_plan >= 0.0 and _fx_pressed < 0.0 and vt - _fx_start >= _fx_plan and game.skip_btn.visible:
			_fx_pressed = vt
			game.skip = true
		elif _fx_pressed >= 0.0 and vt - _fx_pressed < 0.1:
			game.skip = true         # repeated requests while it ends
	elif _fx_start >= 0.0:
		fx_log.append({"plan": _fx_plan, "life": vt - _fx_start, "after": (vt - _fx_pressed) if _fx_pressed >= 0.0 else -1.0})
		_fx_start = -1.0
	# focused button of the event panel (roll / accept / ok) or of the result board
	var f := root.gui_get_focus_owner()
	if f is Button and f.is_visible_in_tree():
		if game.nego.is_ancestor_of(f):
			f.emit_signal("pressed")
	# the result board's button no longer takes keyboard focus at once (stray-Enter guard), so it is found by its text, not by focus
	var nb: Button = null
	for b in game.modal_layer.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and (b.text == "NEXT ROUND" or b.text == "FINAL RESULT"):
			nb = b
	if nb != null:
		if board_t < 0.0:
			board_t = vt
		if Settings.reduce_motion or _running_tweens() == 0:
			board_log.append(vt - board_t)
			board_t = -1.0
			nb.emit_signal("pressed")


func _on_idle(p: Dictionary) -> void:
	await process_frame
	if game == null or not is_instance_valid(game):
		return
	var v := Eng.get_public_view(game.state, "P1")
	if p["type"] == "SELECT_CARD":
		game._human_action.emit({"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)})
	elif p["type"] == "PLACE_EXTRA_MONEY":
		game._human_action.emit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)})


## Plays one whole game; returns {types, money, mismatch, fx, board}
func _play_game(players: int, seed_: int, speed: String, reduce: bool, sched: Array) -> Dictionary:
	_cfg(speed, reduce)
	Engine.time_scale = 1.0
	schedule = sched
	fx_log = []
	board_log = []
	types_played = []
	_fx_start = -1.0
	_fx_count = 0
	ended = false
	_new_game(players, seed_, true)
	pump_on = true
	var guard := 0
	while not ended and guard < 400000:
		await process_frame
		guard += 1
	pump_on = false
	await _frames(4)
	var engine_types: Array = []
	for e in game.state["events"]:
		engine_types.append(str(e["type"]))
	var money := {}
	var disp_ok := true
	for p in game.state["players"]:
		money[p["id"]] = int(p["money"])
		if int(game.disp["money"][p["id"]]) != int(p["money"]):
			disp_ok = false
	var out := {"types": types_played.duplicate(), "engine_types": engine_types, "money": money, "disp_ok": disp_ok,
		"mismatch": int(game.settle_mismatch), "layers": _razzia_layers().size(), "fx": fx_log.duplicate(), "board": board_log.duplicate()}
	await _drop_game()
	Engine.time_scale = 1.0
	return out


func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _check_game(tag: String, r: Dictionary) -> void:
	_ok("%s: played events == engine events (count %d)" % [tag, r["types"].size()], r["types"] == r["engine_types"], "played=%d engine=%d" % [r["types"].size(), r["engine_types"].size()])
	_ok("%s: displayed money == engine money" % tag, r["disp_ok"])
	_ok("%s: settle_mismatch == 0" % tag, r["mismatch"] == 0)
	_ok("%s: no RAZZIA layer left" % tag, r["layers"] == 0)


func _part_b() -> void:
	print("== part B: whole games with a skip schedule")
	var sched := [0.02, 0.3, 1.1, 1.8, 2.6, -1.0, 0.5]      # offsets after the fx appears; -1 = no skip
	for cfg in [[4, 5], [8, 5]]:
		var tag := "%dp seed %d" % [cfg[0], cfg[1]]
		var rn: Dictionary = await _play_game(cfg[0], cfg[1], "NORMAL", false, sched)
		_check_game(tag + " NORMAL+skips", rn)
		var started_fx: Array = rn["fx"]
		var bad_after := 0
		var skipped := 0
		for e in started_fx:
			if e["plan"] >= 0.0 and e["after"] >= 0.0:
				skipped += 1
				if e["after"] > 0.15:
					bad_after += 1
		_ok("%s NORMAL: fx cases seen=%d, skipped=%d" % [tag, started_fx.size(), skipped], started_fx.size() >= 1)
		_ok("%s NORMAL: every skipped fx ended within 0.15s of the request" % tag, bad_after == 0, "late=%d %s" % [bad_after, JSON.stringify(started_fx)])
		var rf: Dictionary = await _play_game(cfg[0], cfg[1], "FAST", false, [-1.0])
		_check_game(tag + " FAST", rf)
		var rr: Dictionary = await _play_game(cfg[0], cfg[1], "NORMAL", true, [-1.0])
		_check_game(tag + " reduced motion", rr)
		_ok("%s: NORMAL+skips / FAST / reduced motion end in the same engine state" % tag, rn["money"] == rf["money"] and rn["money"] == rr["money"] and rn["types"] == rf["types"] and rn["types"] == rr["types"])
		for e in rf["fx"]:
			_ok("%s FAST: unskipped fx lasts 1.25-1.55s" % tag, e["life"] >= 1.25 and e["life"] <= 1.55, "life=%.3f" % e["life"])
		# board: same schedule-free NORMAL run for the comparison
		var rn2: Dictionary = await _play_game(cfg[0], cfg[1], "NORMAL", false, [-1.0])
		_check_game(tag + " NORMAL no skip", rn2)
		for e in rn2["fx"]:
			_ok("%s NORMAL no skip: fx lasts 2.15-2.40s" % tag, e["life"] >= 2.15 and e["life"] <= 2.40, "life=%.3f" % e["life"])
		var mn := _median(rn2["board"])
		var mf := _median(rf["board"])
		_ok("%s: round-result board NORMAL %.2fs -> FAST %.2fs (about half)" % [tag, mn, mf], mn > 0.9 and mn < 1.6 and mf < mn * 0.7 and mf > 0.3, "n=%d/%d" % [rn2["board"].size(), rf["board"].size()])
		_ok("%s: NORMAL no skip == NORMAL+skips (events, money)" % tag, rn2["types"] == rn["types"] and rn2["money"] == rn["money"])
