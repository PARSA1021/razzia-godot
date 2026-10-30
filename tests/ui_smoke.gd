extends SceneTree
## Bot-driven full game through the real board UI.
##   godot --headless --path . --script res://tests/ui_smoke.gd -- players=4 seed=7 [shots=outdir] [w=1280 h=720] [fast=1]
## With shots=<dir> a rendering driver (xvfb) is required; PNGs are written at key moments.
const Game = preload("res://ui/game_screen.gd")
const Settings = preload("res://ui/settings.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")

var args := {}
var game
var rng := AI.new_rng(99)
var shots_dir := ""
var taken := {}
var errors := 0
var rounds := 0
var ended := false
var events_seen := {}
var t0 := 0.0


var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_start()
	return false


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	shots_dir = str(args.get("shots", ""))
	var w := int(args.get("w", 1280))
	var h := int(args.get("h", 720))
	root.content_scale_size = Vector2i(720, 1280) if h > w else Vector2i(1280, 720)
	root.size = Vector2i(w, h)
	Settings.load_settings()
	if args.has("reduce"):
		Settings.reduce_motion = true
	Engine.time_scale = float(args.get("scale", 6))
	t0 = Time.get_ticks_msec()
	var cfg := {"playerCount": int(args.get("players", 4)), "seed": int(args.get("seed", 7)),
		"humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, int(args.get("players", 4)))}
	var s := Eng.create_game(cfg)
	game = Game.new()
	game.autosave_enabled = false
	game.bot = _bot
	root.add_child(game)
	game.event_played.connect(_on_event)
	game.idle.connect(_on_idle)
	game.nego_opened.connect(_on_nego_opened)
	game.result_board_shown.connect(func(): _shot("round_result"))
	game.begin(s)
	var timer := create_timer(240.0 / max(1.0, Engine.time_scale) + 60.0, true, false, true)
	timer.timeout.connect(func():
		printerr("SMOKE TIMEOUT")
		quit(2))


func _bot(pending: Dictionary, view: Dictionary, _screen) -> Dictionary:
	var pid := "P1"
	match pending["type"]:
		"SELECT_CARD":
			return {"type": "SELECT_CARD", "playerId": pid, "cardId": AI.choose_card(view, rng)}
		"PLACE_EXTRA_MONEY":
			return {"type": "PLACE_EXTRA_MONEY", "playerId": pid, "barId": AI.choose_extra_bar(view, rng)}
		"MAKE_PROPOSAL":
			return {"type": "MAKE_PROPOSAL", "playerId": pid, "allocations": AI.make_proposal(view, rng)}
		"RESPOND":
			return {"type": "RESPOND", "playerId": pid, "response": AI.respond_to_proposal(view, rng)}
	return {}


func _shot(name: String) -> void:
	if shots_dir == "" or taken.has(name):
		return
	taken[name] = true
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	if str(args.get("until", "")) == name:
		quit(0)


func _on_idle(pending: Dictionary) -> void:
	if args.has("seq") and pending["type"] == "SELECT_CARD" and not taken.has("seq"):
		taken["seq"] = true
		for i in range(4):
			await create_timer(0.12 * (i + 1)).timeout
			await process_frame
			root.get_texture().get_image().save_png("%s/seq_%d.png" % [shots_dir, i])
	if pending["type"] == "SELECT_CARD":
		_shot("select_r%d" % game.state["round"] if game.state["round"] <= 1 else "select_late")
	_check_hidden()


func _check_hidden() -> void:
	# before reveal, no opponent card may be face up on the board
	if game.state["phase"] == "SELECT_CARDS" or game.state["phase"] == "PLAYERS_SELECT":
		for pid in game.strip_views:
			if pid != "P1" and game.strip_views[pid].face_up:
				printerr("HIDDEN INFO LEAK: ", pid)
				errors += 1


func _on_event(ev: Dictionary) -> void:
	var t: String = ev["type"]
	events_seen[t] = int(events_seen.get(t, 0)) + 1
	if t == "CARD_SELECTED":
		_check_hidden()
	if t == "MONEY_PLACED" and args.has("flight") and int(events_seen[t]) == 4 and shots_dir != "":
		# photograph a money card in flight (deck pile -> venue): taken a few frames after the event starts the tween
		await create_timer(0.14 / maxf(0.01, Engine.time_scale), true, false, true).timeout
		root.get_texture().get_image().save_png("%s/money_flight.png" % shots_dir)
	if t == "ROUND_ENDED":
		rounds += 1
	if t in ["CARDS_REVEALED", "BAR_RESOLVED", "MONEY_AWARDED", "PROPOSAL_MADE", "DUEL_RESOLVED", "NEGOTIATION_STARTED", "DUEL_STARTED", "RAZZIA_ACTIVATED", "DICE_ROLLED", "ROUND_ENDED", "GAME_ENDED"]:
		_shot(t.to_lower())
	if t == "GAME_ENDED" and not ended:
		ended = true
		await _shot("game_over")
		await process_frame
		_finish()


func _finish() -> void:
	var inv := Eng.check_invariants(game.state)
	errors += int(game.settle_mismatch)
	print("SMOKE done: rounds=%d events=%s invariantsOk=%s errors=%d secs=%.1f" % [rounds, JSON.stringify(events_seen), str(inv), errors, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if errors > 0 else 0)


## Photograph the event panel while it is still sliding in (needs scale=1 so the 0.25 s tween spans real frames).
func _on_nego_opened() -> void:
	if shots_dir == "" or taken.has("nego_sliding"):
		return
	await create_timer(0.09, true, false, true).timeout
	_shot("nego_sliding")
