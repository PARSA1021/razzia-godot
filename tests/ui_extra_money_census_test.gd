extends SceneTree
## Two things a player must never misread:
##  A) the dealer's extra money card: it is shown as a card that travels to the venue and stays there as a gold tag
##     (amount + dealer) for the round; the human dealer sees the card while choosing and a preview on the venue.
##  B) the venue card's counts: total == already out + in my hand + left, and "left" is exactly the deck + the other
##     players' hands - checked at every card prompt of a whole game, never ahead of the board, and again after Continue.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_extra_money_census_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const MoneyCard = preload("res://ui/money_card_view.gd")
const AI = preload("res://ai/ai.gd")
var rng := AI.new_rng(7)

var checks := 0
var fails: Array = []
var started := false
var fail_once := {}
var cur_game = null
var ended := [false]
var tag_errors := []


func _on_ev(ev: Dictionary) -> void:
	var g = cur_game
	var t := str(ev["type"])
	if t == "MONEY_PLACED" and bool(ev["extra"]):
		var b = g.bar_views[str(ev["barId"])]
		var who: String = "나" if str(g.disp["croupier"]) == g.human_id else g._nm(str(g.disp["croupier"]))
		if b.extra_amount != int(ev["value"]) or b.extra_by != who:
			tag_errors.append("placed %s %d/%s vs %d/%s" % [ev["barId"], b.extra_amount, b.extra_by, int(ev["value"]), who])
	elif t == "ROUND_STARTED":
		for id in g.bar_order:
			if g.bar_views[id].extra_amount != 0:
				tag_errors.append("round start: %s kept a tag" % id)
	elif t == "MONEY_AWARDED":
		var id2: String = str(ev["barId"])
		if int(g.disp["bar_money"][id2]) <= 0 and g.bar_views[id2].extra_amount != 0:
			tag_errors.append("paid out: %s kept a tag" % id2)
	elif t == "ROUND_ENDED":
		# the engine is already ahead here (next hand dealt): the census must follow the board, not the engine
		var shown_hand := 0
		for v in g.hand_views:
			if is_instance_valid(v):
				shown_hand += 1
		var mine_all := 0
		for id3 in g.bar_order:
			var c3: Dictionary = g._venue_census(id3)
			mine_all += int(c3["my_zocker"].size()) + int(c3["my_razzia"].size())
		_ok("mid-replay the venue card only knows the hand the board shows", mine_all <= shown_hand + 1, "%d vs %d" % [mine_all, shown_hand])
	elif t == "GAME_ENDED":
		ended[0] = true


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	if not c or not fail_once.has(n):
		print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])
	fail_once[n] = true


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _process(_d: float) -> bool:
	if not started:
		started = true
		_run.call_deferred()
	return false


func _click(c: Control) -> void:
	var p: Vector2 = root.get_final_transform() * c.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await _frames(3)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


## ground truth (hidden state: the test may look, the game may not)
func _truth(g, bar_id: String) -> Dictionary:
	var t := {"left": 0, "mine": 0, "out": 0, "total": 0}
	var st: Dictionary = g.state
	for cid in st["cards"]:
		if str(st["cards"][cid]["barId"]) == bar_id:
			t["total"] += 1
	for cid in st["drawPile"]:
		if str(st["cards"][cid]["barId"]) == bar_id:
			t["left"] += 1
	for p in st["players"]:
		for cid in p["hand"]:
			if str(st["cards"][cid]["barId"]) != bar_id:
				continue
			if str(p["id"]) == g.human_id:
				t["mine"] += 1
			else:
				t["left"] += 1
	for cid in st["discardPile"]:
		if str(st["cards"][cid]["barId"]) == bar_id:
			t["out"] += 1
	for pc in st["playedCards"]:
		if str(pc["barId"]) == bar_id:
			t["out"] += 1
	return t


func _check_census(g, where: String) -> void:
	for id in g.bar_order:
		var c: Dictionary = g._venue_census(id)
		var tr := _truth(g, id)
		var tot := int(c["total_z"]) + int(c["total_r"])
		var outn := int(c["out_z"]) + int(c["out_r"])
		var mine := int(c["my_zocker"].size()) + int(c["my_razzia"].size())
		var left := int(c["zocker_left"]) + int(c["razzia_left"])
		_ok("census adds up (total = out + mine + left) [%s]" % where, tot == outn + mine + left and tot == tr["total"], "%s %d=%d+%d+%d (truth %d)" % [id, tot, outn, mine, left, tr["total"]])
		_ok("census 'left' is exactly deck + other hands [%s]" % where, left == tr["left"], "%s %d vs %d" % [id, left, tr["left"]])
		_ok("census 'mine' is exactly my hand [%s]" % where, mine == tr["mine"], "%s %d vs %d" % [id, mine, tr["mine"]])
		_ok("census 'out' is exactly the revealed cards [%s]" % where, outn == tr["out"], "%s %d vs %d" % [id, outn, tr["out"]])
		var zs: Array = c["left_z_syms"]
		_ok("left eyes list matches the left count [%s]" % where, zs.size() == int(c["zocker_left"]) and (zs.is_empty() or int(zs.max()) == int(c["top_symbol"])))


func _new_game(seed_v: int, first: String, use_bot: bool):
	var s := Eng.create_game({"playerCount": 4, "seed": seed_v, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"], "firstCroupierId": first})
	var g = Game.new()
	g.autosave_enabled = false
	if use_bot:
		g.bot = func(pending, view, _gg):
			match str(pending["type"]):
				"SELECT_CARD":
					return {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(view, rng)}
				"PLACE_EXTRA_MONEY":
					return {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(view, rng)}
				"MAKE_PROPOSAL":
					return {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(view, rng)}
				"RESPOND":
					return {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(view, rng)}
			return {}
	root.add_child(g)
	g.begin(s)
	return g


func _run() -> void:
	Settings.load_settings()
	var saved := [Settings.music_on, Settings.sfx_on, Settings.dialogue_on, Settings.speed_name, Settings.coach_on, Settings.reduce_motion]
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.coach_on = false
	Settings.reduce_motion = false
	Settings.speed_name = "fast"
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 720)

	# ---------------- A) the human dealer: card in hand, preview, flight, tag
	var g = _new_game(3, "P1", false)
	var w := 0
	while w < 1200 and not g._awaiting_bar:
		w += 1
		await process_frame
	_ok("the human dealer is asked to place the extra card", g._awaiting_bar, "frames=%d" % w)
	await _frames(20)
	var held: Control = g._extra_held
	_ok("the extra card is shown face up while choosing", held != null and is_instance_valid(held) and held is MoneyCard and int(held.amount) == int(g.state["extraMoneyCard"]["value"]))
	var amount := int(g.state["extraMoneyCard"]["value"])
	var target_id: String = g.bar_order[2]
	var bv = g.bar_views[target_id]
	_ok("every venue offers a preview of the card", bv.preview_extra == amount)
	bv.hovering = true
	bv._redraw_tag()
	var before := int(g.disp["bar_money"][target_id])
	_ok("the preview tag is drawn on the hovered venue", bv._tag != null and is_instance_valid(bv._tag))
	var flew := [false]
	g.event_played.connect(func(ev):
		if str(ev["type"]) == "MONEY_PLACED" and bool(ev["extra"]):
			flew[0] = true)
	await _click(bv)
	var w2 := 0
	var saw_flight := false
	while w2 < 400 and not flew[0]:
		w2 += 1
		await process_frame
		for c in g.fx_layer.get_children():
			if c is MoneyCard:
				saw_flight = true
	_ok("the card travels to the chosen venue (a MoneyCard is in flight)", saw_flight)
	_ok("the tag stays on the venue: amount + dealer", bv.extra_amount == amount and bv.extra_by == "나", "%d %s" % [bv.extra_amount, bv.extra_by])
	_ok("the venue's money grew by exactly the card", int(g.disp["bar_money"][target_id]) == before + amount, "%d vs %d" % [int(g.disp["bar_money"][target_id]), before + amount])
	var others_clean := true
	for id in g.bar_order:
		if id != target_id and g.bar_views[id].extra_amount != 0:
			others_clean = false
	_ok("only that venue carries the tag", others_clean)
	_ok("the preview is gone once placed", bv.preview_extra == 0)
	_ok("the line names dealer, amount and venue", "나" in g.now_label.text and g.T.money(amount) in g.now_label.text and g.T.bar_name(target_id) in g.now_label.text, g.now_label.text)
	g.queue_free()
	await _frames(5)

	# ---------------- B) a whole game by bot: tags follow the rules, census is exact at every prompt
	g = _new_game(11, "", true)
	var resume_state := [null]
	var prompts := [0]
	cur_game = g
	g.event_played.connect(_on_ev)
	g.idle.connect(func(pending):
		if str(pending.get("type", "")) == "SELECT_CARD":
			prompts[0] += 1
			_check_census(g, "prompt")
			if int(g.state["round"]) == 4 and resume_state[0] == null:
				resume_state[0] = {"state": g.state.duplicate(true), "census": {}, "hist": {}}
				for id in g.bar_order:
					resume_state[0]["census"][id] = g._venue_census(id)
					resume_state[0]["hist"][id] = g._venue_history(id)
				resume_state[0]["reshuffles"] = g._reshuffles)
	var f := 0
	while not ended[0] and f < 60000:
		f += 1
		await process_frame
	_ok("the bot game finished", ended[0], "frames=%d prompts=%d" % [f, prompts[0]])
	_ok("extra-money tags were always right (placed, kept, cleared)", tag_errors.is_empty(), str(tag_errors.slice(0, 4)))
	_ok("the census was checked at many prompts", prompts[0] >= 8, str(prompts[0]))
	g.queue_free()
	await _frames(5)

	# ---------------- C) Continue: the venue card says the same thing after loading the save
	if resume_state[0] != null:
		var st: Dictionary = resume_state[0]["state"]
		var g2 = Game.new()
		g2.autosave_enabled = false
		g2.bot = func(_p, _v, _g): return {}
		root.add_child(g2)
		g2.begin(st, true)
		await _frames(30)
		var same := true
		var why := ""
		for id in g2.bar_order:
			var a: Dictionary = resume_state[0]["census"][id]
			var b2: Dictionary = g2._venue_census(id)
			for k in ["total_z", "total_r", "out_z", "out_r", "zocker_left", "razzia_left", "top_symbol"]:
				if int(a[k]) != int(b2[k]):
					same = false
					why = "%s %s %d vs %d" % [id, k, int(a[k]), int(b2[k])]
			if str(resume_state[0]["hist"][id]) != str(g2._venue_history(id)):
				same = false
				why = "%s history %s vs %s" % [id, str(resume_state[0]["hist"][id]), str(g2._venue_history(id))]
		_ok("after Continue the venue card shows the same counts and history", same, why)
		_ok("after Continue the reshuffle count is the same", int(resume_state[0]["reshuffles"]) == g2._reshuffles)
		_check_census(g2, "resumed")
		g2.queue_free()
	else:
		_ok("reached round 4 for the Continue check", false)

	Settings.music_on = saved[0]
	Settings.sfx_on = saved[1]
	Settings.dialogue_on = saved[2]
	Settings.speed_name = saved[3]
	Settings.coach_on = saved[4]
	Settings.reduce_motion = saved[5]
	print("EXTRA/CENSUS TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
