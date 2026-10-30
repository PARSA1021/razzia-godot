extends SceneTree
## "Continue" must rebuild the same screen a fresh game shows at the same checkpoint (docs/03 §25 autosave).
##   godot --headless --path . --script res://tests/ui_resume_test.gd -- [w=1280] [h=720]     (also: w=430 h=932, w=844 h=390)
## Scenarios (the autosave is written when the human is asked for a card / extra-money bar):
##   1 resume at "before choosing a card"  == layout/HUD of the fresh game at that checkpoint
##   2 resume when a card was only selected (not submitted) -> selection is not saved, prompt is "PICK A CARD"
##   3 resume after the card was submitted (real GameScreen with autosave on) -> the file holds checkpoint + the submitted card,
##     Continue re-applies it: the card is not asked again, the round's events are replayed, the game reaches the next decision
##   4 resume at the extra-money prompt -> bar choice active, button reads "PICK A BAR" (never "PLAYED")
##   5 resume at the start of a late round -> HUD money / venues / deck equal the engine state
##   7 quit while the human has to answer a negotiation (file = checkpoint + the card): Continue replays the round, opens the
##     panel and asks the negotiation question again - not the card - and the answer is accepted by the engine
##   6 resume at a late-round checkpoint of a *fresh* game that was played on (negotiations, carried-over money):
##     display model and money-card piles equal the live display
## Script errors (SCRIPT ERROR in the log) are not catchable from GDScript: run it as shown in README and grep the output.
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const AI = preload("res://ai/ai.gd")
const SaveStore = preload("res://ui/save_store.gd")
const SAVE_PATH := "user://ui_resume_test_save.json"

var args := {}
var started := false
var fails: Array = []
var n_checks := 0
var t0 := 0
var N                       # fresh game
var saved_text := ""
var saved_rng := 0
var _first_idle := true
var _done6 := false
var rng_bot := AI.new_rng(99)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		args[kv[0]] = kv[1]
	var w := int(args.get("w", 1280))
	var h := int(args.get("h", 720))
	root.size = Vector2i(w, h)
	root.content_scale_size = Vector2i(720, 1280) if h > w else Vector2i(1280, 720)
	Engine.time_scale = 8.0
	t0 = Time.get_ticks_msec()
	SaveStore.path = SAVE_PATH
	SaveStore.clear()
	_run()
	return false


func _ok(name: String, cond: bool, info: String = "") -> void:
	n_checks += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, info])


func _cfg() -> Dictionary:
	return {"playerCount": 4, "seed": 5, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]}


func _real(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


## Engine/controller only: plays the human with the AI helpers until `want` is true for the pending request.
func _advance_to(want: Callable) -> Dictionary:
	var s := Eng.create_game(_cfg())
	var ctl := Ctl.new(s)
	var rng := AI.new_rng(5)
	var p = ctl.run()
	for guard in range(2000):
		if p == null or want.call(s, p):
			break
		var v := Eng.get_public_view(s, "P1")
		var a := {}
		match p["type"]:
			"SELECT_CARD": a = {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)}
			"PLACE_EXTRA_MONEY": a = {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)}
			"MAKE_PROPOSAL": a = {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(v, rng)}
			"RESPOND": a = {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(v, rng)}
		p = ctl.submit(a)["pending"]
	return {"text": Eng.serialize_game(s), "rng": int(ctl.ai_rng["rngState"]), "pending": p, "round": int(s["round"])}


## Same path as main.gd _continue(): load the save text, begin(resume=true).
func _resume(text: String, rng: int) -> Control:
	var r := Eng.load_game(text)
	var g = Game.new()
	g.autosave_enabled = false
	root.add_child(g)
	g.begin(r["state"], true, rng)
	return g


func _metrics(g) -> Dictionary:
	var hand := []
	for hv in g.hand_views:
		hand.append(hv.position)
	var strips := {}
	for pid in g.strip_views:
		strips[pid] = [g.strip_views[pid].position, g.strip_views[pid].size]
	return {
		"label_pos": g.now_label.position, "label_size": g.now_label.size, "label_text": g.now_label.text,
		"hand": hand, "strips": strips, "hud": [g.stat_round.value, g.stat_table.value, g.stat_deck.value],
		"disp": JSON.stringify(g.disp, "", true), "btn": [g.confirm_btn.text, g.confirm_btn.disabled],
	}


func _same_v(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 1.5


func _structure(g, tag: String) -> void:
	var u: float = g.u
	var lim := maxf(70.0 * u, 100.0)        # a two-line narration in portrait is ~70 px; the broken resume produced 459
	_ok("%s: narration label has its own height (not stretched)" % tag, g.now_label.size.y <= lim, "(h=%.0f, limit %.0f)" % [g.now_label.size.y, lim])
	var strips_ok := true
	for pid in g.strip_views:
		var sv: Control = g.strip_views[pid]
		if not (sv.size.distance_to(g._strip_metrics["card"]) <= 1.5 and sv.position.distance_to(g.strip_slot_pos(pid)) <= 1.5):
			strips_ok = false
	_ok("%s: face-down cards sit in their slots (%d)" % [tag, g.strip_views.size()], strips_ok)
	var lab: Rect2 = g.now_label.get_global_rect()
	var hand_rect := Rect2()
	for hv in g.hand_views:
		hand_rect = hand_rect.merge(hv.get_global_rect()) if hand_rect.size != Vector2.ZERO else hv.get_global_rect()
	_ok("%s: narration label does not sit behind the hand" % tag, g.hand_views.is_empty() or not lab.intersects(hand_rect.grow(-2.0)))


func _hud_matches_engine(g, tag: String) -> void:
	var st: Dictionary = g.state
	var ok: bool = int(g.disp["round"]) == int(st["round"]) and int(g.disp["deck"]) == st["moneyDeck"].size()
	for b in st["bars"]:
		if b["active"] and int(g.disp["bar_money"][b["id"]]) != int(b["money"]):
			ok = false
	for p in st["players"]:
		if int(g.disp["money"][p["id"]]) != int(p["money"]):
			ok = false
	_ok("%s: displayed round / deck / venue money / player money == engine state" % tag, ok)


func _run() -> void:
	print("RESUME TEST %sx%s" % [str(args.get("w", 1280)), str(args.get("h", 720))])
	# ---- fresh game: reach the first card prompt, remember the autosave the UI would write there
	N = Game.new()
	N.autosave_enabled = true           # scenario 3 needs the file the board really writes
	root.add_child(N)
	N.idle.connect(_on_idle_N)
	var s := Eng.create_game(_cfg())
	N.begin(s)
	# scenarios 1-3 run inside _on_idle_N / _on_event_N; wait until they are finished
	while not _all_done:
		await _real(0.2)
	N.queue_free()

	# ---- 4: extra-money prompt
	var d4 := _advance_to(func(_s, p): return p["type"] == "PLACE_EXTRA_MONEY")
	_ok("4 found a PLACE_EXTRA_MONEY checkpoint for the human", d4["pending"] != null and d4["pending"]["type"] == "PLACE_EXTRA_MONEY", "(round %d)" % int(d4["round"]))
	if d4["pending"] != null:
		var g4 = _resume(d4["text"], d4["rng"])
		await _real(1.0)
		_structure(g4, "4")
		_ok("4 bar choice is active", g4._awaiting_bar)
		_ok("4 button reads PICK A BAR (disabled), not PLAYED", g4.confirm_btn.text == "PICK A BAR" and g4.confirm_btn.disabled, "('%s')" % g4.confirm_btn.text)
		_ok("4 narration names the extra money card", g4.now_label.text.contains("추가 머니카드"), "('%s')" % g4.now_label.text)
		_hud_matches_engine(g4, "4")
		g4.queue_free()

	# ---- 5: start of a late round
	var d5 := _advance_to(func(s, p): return p["type"] == "SELECT_CARD" and int(s["round"]) >= 5)
	_ok("5 found a late-round checkpoint", d5["pending"] != null, "(round %d)" % int(d5["round"]))
	if d5["pending"] != null:
		var g5 = _resume(d5["text"], d5["rng"])
		await _real(1.0)
		_structure(g5, "5")
		_hud_matches_engine(g5, "5")
		_ok("5 can choose a card (prompt active, button 'PICK A CARD')", g5._awaiting_select and g5.confirm_btn.text == "PICK A CARD")
		g5.queue_free()

	# ---- 7: quit at a negotiation question
	SaveStore.clear()
	var wrote := _write_save_until(func(p): return p["type"] == "MAKE_PROPOSAL" or p["type"] == "RESPOND")
	_ok("7 built a save at a human negotiation question (checkpoint + recorded actions)", wrote)
	if wrote:
		var f7 := SaveStore.load_save()
		_ok("7 file holds recorded actions", f7["ok"] and f7["actions"].size() >= 1, "(%d)" % f7["actions"].size())
		var g7 = Game.new()
		g7.autosave_enabled = false
		root.add_child(g7)
		g7.idle.connect(func(p: Dictionary):
			if _g7_first.is_empty():
				_g7_first = p)
		g7.begin(f7["state"], true, f7["aiRngState"], f7["actions"])
		var waited := 0.0
		while _g7_first.is_empty() and waited < 40.0:
			await _real(0.2)
			waited += 0.2
		_ok("7 Continue asks the negotiation question again, not the card", _g7_first.has("type") and (_g7_first["type"] == "MAKE_PROPOSAL" or _g7_first["type"] == "RESPOND"), "(%s)" % str(_g7_first.get("type", "none")))
		await _real(0.6)
		var btn: Button = null
		for b in g7.nego._action_box.find_children("*", "Button", true, false):
			if ("MAKE OFFER" in b.text or "ACCEPT" in b.text) and not b.disabled:
				btn = b
		_ok("7 negotiation panel is open with its answer button", g7.nego.visible and btn != null)
		_structure(g7, "7")
		if btn != null:
			var before: int = g7.state["events"].size()
			btn.pressed.emit()
			await _real(0.5)
			_ok("7 the answer is accepted by the engine and play continues", g7.ctl.error.is_empty() and g7.state["events"].size() > before, "(events %d -> %d)" % [before, g7.state["events"].size()])
		g7.queue_free()
	_finish()


var _g7_first := {}


## Same protocol as GameScreen._flow (checkpoint at card/bar prompts, record after each accepted action), stops at a wanted prompt.
func _write_save_until(want: Callable) -> bool:
	var s := Eng.create_game(_cfg())
	var ctl := Ctl.new(s)
	var pending = ctl.run()
	while pending != null:
		if pending["type"] == "SELECT_CARD" or pending["type"] == "PLACE_EXTRA_MONEY":
			SaveStore.save(s, int(ctl.ai_rng["rngState"]))
		if want.call(pending):
			return true
		var v := Eng.get_public_view(s, "P1")
		var rng := AI.new_rng(int(s["seq"]) * 31 + 7)
		var a := {}
		match pending["type"]:
			"SELECT_CARD": a = {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)}
			"PLACE_EXTRA_MONEY": a = {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)}
			"MAKE_PROPOSAL": a = {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(v, rng)}
			"RESPOND": a = {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(v, rng)}
		var r := ctl.submit(a)
		SaveStore.record_action(a)
		pending = r["pending"]
	return false


var _all_done := false
var _metrics_N := {}


func _bot(pending: Dictionary, view: Dictionary, _screen) -> Dictionary:
	match pending["type"]:
		"SELECT_CARD": return {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(view, rng_bot)}
		"PLACE_EXTRA_MONEY": return {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(view, rng_bot)}
		"MAKE_PROPOSAL": return {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(view, rng_bot)}
		"RESPOND": return {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(view, rng_bot)}
	return {}


func _on_idle_N(p: Dictionary) -> void:
	if not _first_idle and not _done6 and p["type"] == "SELECT_CARD" and N.bot.is_valid() and int(N.state["round"]) >= 5:
		_done6 = true
		# everything below the `await` sees the live display exactly as it is at this prompt
		var text := Eng.serialize_game(N.state)
		var rng := int(N.ctl.ai_rng["rngState"])
		var live_disp := JSON.stringify(N.disp, "", true)
		var live_piles := {}
		for id in N.bar_order:
			live_piles[id] = N.bar_views[id].money_cards
		var live_round := int(N.state["round"])
		var g6 = _resume(text, rng)
		await _real(0.5)
		var res_piles := {}
		for id in g6.bar_order:
			res_piles[id] = g6.bar_views[id].money_cards
		_ok("6 (fresh game, round %d) display model equals the live display after Continue" % live_round, JSON.stringify(g6.disp, "", true) == live_disp)
		_ok("6 money-card piles on the venues equal the live display", res_piles == live_piles, "(%s vs %s)" % [str(res_piles), str(live_piles)])
		_structure(g6, "6")
		g6.queue_free()
		_all_done = true
		return
	if not _first_idle or p["type"] != "SELECT_CARD":
		return
	_first_idle = false
	saved_text = Eng.serialize_game(N.state)
	saved_rng = int(N.ctl.ai_rng["rngState"])
	await _real(1.0)                   # let the fresh game's intro animations settle
	_metrics_N = _metrics(N)
	_structure(N, "1 fresh")
	# 1: resume from the same checkpoint
	var g1 = _resume(saved_text, saved_rng)
	await _real(1.0)
	var m := _metrics(g1)
	_structure(g1, "1 resumed")
	_ok("1 narration label position/size equals the fresh game", _same_v(m["label_pos"], _metrics_N["label_pos"]) and _same_v(m["label_size"], _metrics_N["label_size"]), "(%s %s vs %s %s)" % [m["label_pos"], m["label_size"], _metrics_N["label_pos"], _metrics_N["label_size"]])
	var hand_same: bool = m["hand"].size() == _metrics_N["hand"].size()
	if hand_same:
		for i in range(m["hand"].size()):
			hand_same = hand_same and _same_v(m["hand"][i], _metrics_N["hand"][i])
	_ok("1 hand layout equals the fresh game", hand_same)
	var strips_same: bool = m["strips"].size() == _metrics_N["strips"].size()
	for pid in m["strips"]:
		strips_same = strips_same and _metrics_N["strips"].has(pid) and _same_v(m["strips"][pid][0], _metrics_N["strips"][pid][0]) and _same_v(m["strips"][pid][1], _metrics_N["strips"][pid][1])
	_ok("1 face-down cards equal the fresh game", strips_same)
	_ok("1 HUD texts equal the fresh game", m["hud"] == _metrics_N["hud"], "(%s vs %s)" % [str(m["hud"]), str(_metrics_N["hud"])])
	_ok("1 display model (round/deck/bars/money/ready) equals the fresh game", m["disp"] == _metrics_N["disp"], "" if m["disp"] == _metrics_N["disp"] else "\n      resumed: %s\n      fresh:   %s" % [m["disp"], _metrics_N["disp"]])
	_ok("1 prompt state equals the fresh game (button, choose-a-card)", m["btn"] == _metrics_N["btn"] and g1._awaiting_select, "(%s)" % str(m["btn"]))
	_hud_matches_engine(g1, "1")
	g1.queue_free()
	# 2: a card was selected in the UI but not submitted -> the autosave has no selection
	N._on_hand_pressed(N.hand_views[0])
	_ok("2 (fresh game) a card is selected in the UI", N.selected_view != null and not N.confirm_btn.disabled)
	var g2 = _resume(saved_text, saved_rng)
	await _real(1.0)
	_ok("2 resume shows no selected card and 'PICK A CARD'", g2.selected_view == null and g2.confirm_btn.disabled and g2.confirm_btn.text == "PICK A CARD")
	_structure(g2, "2")
	g2.queue_free()
	# 3: submit, then resume from the autosave that was written before the submit
	var card_id := str(N.selected_view.card["id"])
	N.event_played.connect(_on_event_N.bind(card_id), CONNECT_ONE_SHOT)
	N._on_confirm()


func _on_event_N(_ev: Dictionary, card_id: String) -> void:
	# first event after the submit: the board has already recorded the accepted card in the autosave
	N.bot = _bot          # scenario 6: play the fresh game on with the same AI helpers the smoke test uses (before its next prompt)
	var f := SaveStore.load_save()
	_ok("3 autosave holds the checkpoint plus the submitted card", f["ok"] and f["actions"].size() == 1 and f["actions"][0]["type"] == "SELECT_CARD" and str(f["actions"][0]["cardId"]) == card_id, "(%s)" % str(f.get("actions", [])))
	_ok("3 checkpoint inside the file is still the state before the submit", Eng.get_player(f["state"], "P1")["selectedCardId"] == null)
	var g3 = Game.new()
	g3.autosave_enabled = false
	g3.bot = _bot         # no clicking through the round-result board by hand; idle still fires at every decision
	root.add_child(g3)
	g3.idle.connect(func(p: Dictionary):
		if _g3_done:
			return
		_g3_done = true
		_on_g3_prompt(g3, p, card_id), CONNECT_ONE_SHOT)
	g3.event_played.connect(func(ev: Dictionary):
		if ev["type"] == "CARDS_REVEALED":
			_g3_reveals += 1)
	g3.begin(f["state"], true, f["aiRngState"], f["actions"])


var _g3_done := false
var _g3_reveals := 0


func _on_g3_prompt(g3, p: Dictionary, card_id: String) -> void:
	# synchronous: this is the live board exactly at the first decision after the replay (the bot answers right after)
	var st: Dictionary = g3.state
	var me: Dictionary = Eng.get_player(st, "P1")
	var sel := 0
	for e in st["events"]:
		if e["type"] == "CARD_SELECTED" and e["playerId"] == "P1" and int(e["round"]) == 1:
			sel += 1
	_ok("3 resumed game reached the next decision (%s, round %d), not the old card prompt" % [str(p["type"]), int(st["round"])], int(st["round"]) > 1 or p["type"] != "SELECT_CARD", "")
	_ok("3 the submitted card was not asked again: played once, gone from the hand", sel == 1 and not me["hand"].has(card_id))
	_ok("3 the round's events were replayed on the board (exactly one reveal)", _g3_reveals == 1, "(%d)" % _g3_reveals)
	_hud_matches_engine(g3, "3")
	_structure(g3, "3")
	g3.queue_free()


func _finish() -> void:
	SaveStore.clear()
	print("RESUME TEST: checks=%d failed=%d secs=%.1f -> %s" % [n_checks, fails.size(), (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("  failed: ", fails)
	quit(0 if fails.is_empty() else 1)
