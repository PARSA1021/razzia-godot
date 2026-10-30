extends SceneTree
## Round start (Phase 8B-4): shorter banner beat + money-card stagger must not change what is shown or when input opens.
##   godot --headless --fixed-fps 60 --path . --script res://tests/ui_round_start_test.gd
## Whole games through the real board, no bot (prompts answered the frame they appear; the result board is confirmed after its
## own animation). At every card prompt: no money card is still flying, the displayed deck / venue money / money-card piles
## equal the engine (piles = the engine event log, same rule as the resume path), nothing stray is left in fx_layer. Also:
## played events == engine events, displayed money == engine money, NORMAL / FAST / SLOW / reduced motion end identically,
## and the span "board closed -> card prompt" is printed per speed (virtual time = sum of frame deltas).
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
var ended := false
var types_played: Array = []
var spans: Array = []
var bad_idle: Array = []
var _span_start := 0.0
var board_seen := false


func _process(d: float) -> bool:
	if not started:
		started = true
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = a.split("=")
			args[kv[0]] = kv[1]
		root.size = Vector2i(int(args.get("w", 1280)), int(args.get("h", 720)))
		root.content_scale_size = Vector2i(720, 1280) if int(args.get("h", 720)) > int(args.get("w", 1280)) else Vector2i(1280, 720)
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


func _running_tweens() -> int:
	var n := 0
	for tw in get_processed_tweens():
		if tw.is_valid() and tw.is_running():
			n += 1
	return n


func _pump() -> void:
	if game == null or not is_instance_valid(game):
		return
	var f := root.gui_get_focus_owner()
	if f is Button and f.is_visible_in_tree():
		if game.nego.is_ancestor_of(f):
			f.emit_signal("pressed")
		elif game.modal_layer.is_ancestor_of(f):
			board_seen = true
			if Settings.reduce_motion or _running_tweens() == 0:
				_span_start = vt            # the next round starts when the board is closed
				f.emit_signal("pressed")


func _on_idle(p: Dictionary) -> void:
	if p["type"] == "SELECT_CARD":
		_check_prompt()
	await process_frame
	if game == null or not is_instance_valid(game):
		return
	var v := Eng.get_public_view(game.state, "P1")
	if p["type"] == "SELECT_CARD":
		game._human_action.emit({"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)})
	elif p["type"] == "PLACE_EXTRA_MONEY":
		game._human_action.emit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)})


## At a card prompt the round start is over: every money card has landed and the display equals the engine.
func _check_prompt() -> void:
	var r := int(game.state["round"])
	var why: Array = []
	if "_money_flying" in game and game._money_flying != 0:        # (property exists from Phase 8B-4 on)
		why.append("money cards still flying: %d" % game._money_flying)
	var stray := 0
	for c in game.fx_layer.get_children():
		if not c.is_queued_for_deletion() and "face_up" in c:
			stray += 1
	if stray != 0:
		why.append("stray flying cards in fx_layer: %d" % stray)
	if int(game.disp["deck"]) != game.state["moneyDeck"].size():
		why.append("deck %d != engine %d" % [int(game.disp["deck"]), game.state["moneyDeck"].size()])
	if int(game.pile.count) != game.state["moneyDeck"].size():
		why.append("pile.count %d != engine %d" % [int(game.pile.count), game.state["moneyDeck"].size()])
	var piles: Dictionary = game._money_card_counts_from_log()
	for b in game.state["bars"]:
		if not b["active"]:
			continue
		var id: String = b["id"]
		if int(game.disp["bar_money"][id]) != int(b["money"]):
			why.append("%s money %d != engine %d" % [id, int(game.disp["bar_money"][id]), int(b["money"])])
		var want := int(piles.get(id, 0)) if int(b["money"]) > 0 else 0
		if int(game.disp["bar_cards"][id]) != want:
			why.append("%s money cards %d != engine log %d" % [id, int(game.disp["bar_cards"][id]), want])
	if not why.is_empty():
		bad_idle.append("round %d: %s" % [r, "; ".join(why)])
	spans.append(vt - _span_start)


## Plays one whole game; returns the summary.
func _play(players: int, seed_: int, speed: String, reduce: bool) -> Dictionary:
	Settings.load_settings()
	Settings.dialogue_on = false        # this harness answers buttons, not cutscenes: never depend on the saved setting
	Settings.speed_name = speed
	Settings.reduce_motion = reduce
	Engine.time_scale = 1.0
	ended = false
	types_played = []
	spans = []
	bad_idle = []
	_span_start = vt
	var s := Eng.create_game({"playerCount": players, "seed": seed_, "humanPlayerId": "P1",
		"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, players)})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	rng = AI.new_rng(seed_ * 31 + 7)
	game.idle.connect(_on_idle)
	game.event_played.connect(func(ev):
		types_played.append(ev["type"])
		if ev["type"] == "GAME_ENDED":
			ended = true)
	pump_on = true
	game.begin(s)
	var guard := 0
	while not ended and guard < 400000:
		await process_frame
		guard += 1
	pump_on = false
	for _i in range(4):
		await process_frame
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
		"mismatch": int(game.settle_mismatch), "spans": spans.duplicate(), "bad": bad_idle.duplicate()}
	game.queue_free()
	game = null
	for _i in range(3):
		await process_frame
	return out


func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _main() -> void:
	var t0 := Time.get_ticks_msec()
	var cases := [[4, 5], [8, 5]]
	var summary := {}
	for cfg in cases:
		var tag := "%dp seed %d" % [cfg[0], cfg[1]]
		var res := {}
		for sp in [["NORMAL", false], ["FAST", false], ["SLOW", false], ["NORMAL", true]]:
			var key := "%s%s" % [sp[0], "+reduce" if sp[1] else ""]
			var r: Dictionary = await _play(cfg[0], cfg[1], sp[0], sp[1])
			res[key] = r
			var label := "%s %s" % [tag, key]
			_ok("%s: played events == engine events (%d)" % [label, r["types"].size()], r["types"] == r["engine_types"])
			_ok("%s: displayed money == engine money, settle_mismatch == 0" % label, r["disp_ok"] and r["mismatch"] == 0)
			_ok("%s: all %d card prompts: landed, deck/venue money/piles == engine" % [label, r["spans"].size()], r["bad"].is_empty(), str(r["bad"].slice(0, 2)))
			_ok("%s: 12 round starts seen" % label, r["spans"].size() >= 12)
			print("      round start span (board closed -> card prompt): median %.3fs  min %.3f  max %.3f" % [_median(r["spans"].slice(1)), r["spans"].slice(1).min(), r["spans"].slice(1).max()])
		_ok("%s: NORMAL / FAST / SLOW / reduced motion end in the same engine state" % tag,
			res["NORMAL"]["money"] == res["FAST"]["money"] and res["NORMAL"]["money"] == res["SLOW"]["money"] and res["NORMAL"]["money"] == res["NORMAL+reduce"]["money"]
			and res["NORMAL"]["types"] == res["FAST"]["types"] and res["NORMAL"]["types"] == res["NORMAL+reduce"]["types"])
		var mn := _median(res["NORMAL"]["spans"].slice(1))
		var mf := _median(res["FAST"]["spans"].slice(1))
		var ms := _median(res["SLOW"]["spans"].slice(1))
		var mr := _median(res["NORMAL+reduce"]["spans"].slice(1))
		_ok("%s: span scales with the speed setting (FAST %.2f < NORMAL %.2f < SLOW %.2f)" % [tag, mf, mn, ms], mf < mn * 0.7 and ms > mn * 1.3)
		_ok("%s: reduced motion keeps a short readable round start, shorter than NORMAL (%.3fs vs %.3fs)" % [tag, mr, mn], mr < mn * 0.65 and mr > 0.3)
		summary[tag] = {"NORMAL": mn, "FAST": mf, "SLOW": ms, "reduce": mr}
	print("ROUND START SUMMARY ", JSON.stringify(summary))
	print("ROUND START TEST: checks=%d failed=%d secs=%.1f -> %s" % [n_checks, fails.size(), (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("  failed: ", fails)
	quit(0 if fails.is_empty() else 1)
