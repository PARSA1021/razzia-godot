extends SceneTree
## Venue card (Phase 17): tapping a venue tells the player what they could have counted themselves.
## The important part is what it must NOT know: a card sitting in another player's hand is never "seen".
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_venue_info_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")

var checks := 0
var fails: Array = []
var started := false
var game


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _click(c: Control) -> void:
	var p: Vector2 = root.get_final_transform() * c.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


## everything printed for this venue, straight from the deck definition (public knowledge)
func _printed(bar_id: String) -> Dictionary:
	var out := {"ZOCKER": 0, "RAZZIA": 0}
	for cid in game.state["cards"]:
		var c: Dictionary = game.state["cards"][cid]
		if str(c["barId"]) == bar_id:
			out[str(c["type"])] += 1
	return out


## where every unseen card of this venue really is (hidden state: the test may look, the game may not)
func _hidden_split(bar_id: String) -> Dictionary:
	var out := {"deck": 0, "other_hands": 0}
	for cid in game.state["drawPile"]:
		if str(game.state["cards"][cid]["barId"]) == bar_id:
			out["deck"] += 1
	for p in game.state["players"]:
		if str(p["id"]) == game.human_id:
			continue
		for cid in p["hand"]:
			if str(game.state["cards"][cid]["barId"]) == bar_id:
				out["other_hands"] += 1
	return out


## how many cards the engine has revealed in total (the board may still be replaying earlier events)
func engine_revealed() -> int:
	var n := 0
	for ev in game.state["events"]:
		if str(ev["type"]) == "CARDS_REVEALED":
			n += int(ev["cards"].size())
	return n


func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.speed_name = "fast"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 4, "seed": 11, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	game = Game.new()
	game.autosave_enabled = false
	game.bot = func(pending, _view, g):
		if pending["type"] == "SELECT_CARD":
			return {"type": "SELECT_CARD", "playerId": g.human_id, "cardId": Eng.get_player(g.state, g.human_id)["hand"][0]}
		if pending["type"] == "PLACE_EXTRA_MONEY":
			return {"type": "PLACE_EXTRA_MONEY", "playerId": g.human_id, "barId": g.bar_order[0]}
		if pending["type"] == "MAKE_PROPOSAL":
			return {"type": "MAKE_PROPOSAL", "playerId": g.human_id, "allocations": {}}
		return {"type": "RESPOND", "playerId": g.human_id, "response": "ACCEPT"}
	var shown := [0]
	game.event_played.connect(func(ev):
		if str(ev["type"]) == "CARDS_REVEALED":
			shown[0] += int(ev["cards"].size()))
	root.add_child(game)
	game.begin(s)
	await _frames(60)

	var bar: String = game.bar_order[0]
	# 1) the count is complete: seen + left == everything printed for the venue
	var cen: Dictionary = game._venue_census(bar)
	var printed := _printed(bar)
	_ok("zocker: seen + left equals the printed card set", int(cen["seen_zocker"]) + int(cen["zocker_left"]) == printed["ZOCKER"], "%d+%d vs %d" % [int(cen["seen_zocker"]), int(cen["zocker_left"]), printed["ZOCKER"]])
	_ok("razzia: seen + left equals the printed card set", int(cen["seen_razzia"]) + int(cen["razzia_left"]) == printed["RAZZIA"], "%d+%d vs %d" % [int(cen["seen_razzia"]), int(cen["razzia_left"]), printed["RAZZIA"]])

	# 2) no leak: "left" is exactly deck + the other players' hands
	var hidden := _hidden_split(bar)
	var left_total := int(cen["zocker_left"]) + int(cen["razzia_left"])
	_ok("what is left is exactly the deck plus the other hands", left_total == hidden["deck"] + hidden["other_hands"], "%d vs %d+%d" % [left_total, hidden["deck"], hidden["other_hands"]])
	_ok("a card in someone else's hand is still counted as unseen", hidden["other_hands"] == 0 or left_total >= hidden["other_hands"])

	# 3) my own hand is reported, and only mine
	var my_count := 0
	for cid in Eng.get_player(game.state, game.human_id)["hand"]:
		if str(game.state["cards"][cid]["barId"]) == bar:
			my_count += 1
	_ok("my own cards of this venue are listed", int(cen["my_zocker"].size()) + int(cen["my_razzia"].size()) == my_count, "%d vs %d" % [int(cen["my_zocker"].size()) + int(cen["my_razzia"].size()), my_count])
	if int(cen["zocker_left"]) > 0:
		_ok("the highest unseen eye is a real unseen card", int(cen["top_symbol"]) >= 1 and int(cen["top_symbol"]) <= 6, str(cen["top_symbol"]))

	# 4) the card opens on a tap and shows the venue
	var bv = game.bar_views[bar]
	await _click(bv)
	await _frames(10)
	var panel: Node = game.modal_layer.get_node_or_null("BarInfo")
	_ok("tapping a venue opens its card", panel != null)
	if panel != null:
		var texts := ""
		for l in panel.find_children("*", "Label", true, false):
			texts += str(l.text) + " | "
		_ok("the card names the venue", game.T.bar_name(bar) in texts, texts.substr(0, 60))
		_ok("the card shows the unseen counts", ("%d 장" % int(cen["zocker_left"])) in texts and ("%d 장" % int(cen["razzia_left"])) in texts, texts.substr(0, 120))
		_ok("the card says where those cards are", "덱이나 다른 사람 손" in texts)
		# Esc closes it again
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(6)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await _frames(10)
		_ok("Esc closes the card", game.modal_layer.get_node_or_null("BarInfo") == null)
		_ok("Esc did not open the exit panel instead", game.modal_layer.get_node_or_null("ExitConfirm") == null)

	# 5) a second tap re-opens it (no stacking)
	await _click(bv)
	await _frames(10)
	await _click(bv)
	await _frames(10)
	var open_cards := 0
	for c in game.modal_layer.get_children():
		if c.name == "BarInfo":
			open_cards += 1
	_ok("tapping twice never stacks two cards", open_cards <= 1, str(open_cards))
	var p2: Node = game.modal_layer.get_node_or_null("BarInfo")
	if p2 != null:
		p2.queue_free()
		await _frames(5)

	# 6) while the extra money card is being placed, a tap is the answer - not the info card
	game._awaiting_bar = true
	for id in game.bar_order:
		game.bar_views[id].clickable = true
	var answered := [""]
	game._human_action.connect(func(a): answered[0] = str(a.get("type", "")))
	await _click(bv)
	await _frames(10)
	_ok("placing the money card still works (the tap is the answer)", answered[0] == "PLACE_EXTRA_MONEY", answered[0])
	_ok("no info card opened during the prompt", game.modal_layer.get_node_or_null("BarInfo") == null)
	game._awaiting_bar = false
	for id in game.bar_order:
		game.bar_views[id].clickable = false

	# 7) the play history only holds what was revealed on the table
	var hist_total := 0
	for pid in game._seen_plays:
		hist_total += int(game._seen_plays[pid].size())
	_ok("the history holds exactly the cards the board has shown", hist_total == shown[0], "%d vs %d" % [hist_total, shown[0]])
	_ok("the board lags the engine, and the card follows the board", shown[0] <= engine_revealed())
	print("VENUE INFO TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
