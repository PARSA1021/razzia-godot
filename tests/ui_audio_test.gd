extends SceneTree
## Sound (Phase 9A). Headless uses the Dummy audio driver, so this checks the wiring (streams load, loop flag, players start/stop,
## switches, which effects a whole game triggers) — not how it sounds.
##   godot --headless --fixed-fps 60 --path . --script res://tests/ui_audio_test.gd
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")

var started := false
var n := 0
var fails: Array = []
var game
var rng
var ended := false
var hp_done := false
var hp_res := {}
var coin_for_others := false


func _process(_d: float) -> bool:
	if not started:
		started = true
		_main()
	return false


func _ok(name: String, cond: bool, info: String = "") -> void:
	n += 1
	if not cond:
		fails.append(name)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", name, info])


func _frames(k: int) -> void:
	for _i in range(k):
		await process_frame


func _pump() -> void:
	var f := root.gui_get_focus_owner()
	if f is Button and f.is_visible_in_tree():
		if game.nego.is_ancestor_of(f):
			f.emit_signal("pressed")
		elif game.modal_layer.is_ancestor_of(f):
			var busy := false
			for tw in get_processed_tweens():
				if tw.is_valid() and tw.is_running():
					busy = true
			if not busy:
				f.emit_signal("pressed")


func _on_idle(p: Dictionary) -> void:
	await process_frame
	if game == null or not is_instance_valid(game):
		return
	var v := Eng.get_public_view(game.state, "P1")
	if p["type"] == "SELECT_CARD":
		if not hp_done:
			hp_done = true
			await _hover_pick_test()
		game._human_action.emit({"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)})
	elif p["type"] == "PLACE_EXTRA_MONEY":
		game._human_action.emit({"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)})


func _main() -> void:
	Settings.load_settings()
	Settings.dialogue_on = false
	Settings.music_on = true
	Settings.sfx_on = true
	Settings.speed_name = "FAST"
	Settings.reduce_motion = false
	# 1) the files are there and import as streams
	for path in ["click.mp3", "taking_card.mp3", "rolling_dice.mp3", "cashier_ching.mp3", "police_siren.mp3", "noir_jazz_loop.ogg", "offer.ogg", "accept.ogg", "duel.ogg", "round_end.ogg", "game_end.ogg", "hover.ogg", "pick.ogg", "coin.ogg", "your_turn.ogg", "stamp.ogg", "denied.ogg", "final_round.ogg", "shuffle.ogg", "duel_win.ogg", "duel_lose.ogg", "win.ogg", "toggle_on.ogg", "toggle_off.ogg", "tick.ogg", "panel_open.ogg", "panel_close.ogg", "page.ogg", "confirm.ogg", "flip.ogg", "deal.ogg", "coin2.ogg", "coin3.ogg", "coin4.ogg", "cash_big.ogg", "nego_open.ogg", "stage.ogg", "drumroll.ogg", "tie.ogg", "game_start.ogg", "tension_loop.ogg", "ambience_loop.ogg"]:
		var st = load("res://assets/audio/" + path)
		_ok("asset loads: " + path, st is AudioStream, "%.2fs" % (st.get_length() if st != null else -1.0))
	# 2) host, music loop, effects
	Audio.start_music()
	await _frames(3)
	var h: Node = Audio._inst
	_ok("host node exists under root", h != null and is_instance_valid(h) and h.is_inside_tree())
	_ok("music is playing and loops", h._music.playing and "loop" in h._music.stream and h._music.stream.loop)
	Audio.play("click")
	_ok("click starts a player", h._pool.any(func(p): return p.playing and p.stream.resource_path.ends_with("click.mp3")))
	Audio.play("click")
	_ok("two clicks within the minimum gap play once (throttle)", h._pool.filter(func(p): return p.playing and p.stream.resource_path.ends_with("click.mp3")).size() == 1)
	Audio.play("ching")
	Audio.play("dice")
	_ok("ching + dice start", h._pool[0].playing and h._pool[1].playing)
	# 2b) volume: effects scale with the effects slider, 0 = silent; the music target follows the music slider
	Settings.sfx_vol = 0.5
	h._last.clear()
	Audio.play("ching")
	_ok("sfx volume 0.5 -> ching about -6 dB", absf(h._pool[0].volume_db - (float(Audio.SFX["ching"][1]) + linear_to_db(0.5))) < 0.1, "%.2f dB" % h._pool[0].volume_db)
	Settings.sfx_vol = 0.0
	h._last.clear()
	Audio.play("take")
	_ok("sfx volume 0 -> nothing is played", h._last.is_empty())
	Settings.sfx_vol = 1.0
	Settings.music_vol = 0.5
	Audio.refresh()
	_ok("music volume 0.5 -> target about -6 dB below the base", absf(h._music_target - (Audio.MUSIC_DB + linear_to_db(0.5))) < 0.1, "%.2f" % h._music_target)
	Settings.music_vol = 0.0
	Audio.refresh()
	_ok("music volume 0 -> music stopped", not h._music.playing)
	Settings.music_vol = 1.0
	Audio.refresh()
	_ok("music volume 1 -> music plays again", h._music.playing)
	# 3) switches
	Settings.sfx_on = false
	var before: Dictionary = h._last.duplicate()
	Audio.play("take")
	_ok("effects switch off: nothing new is played", h._last == before)
	Settings.sfx_on = true
	Settings.music_on = false
	Audio.refresh()
	_ok("music switch off stops the music", not h._music.playing)
	Settings.dialogue_on = false
	Settings.music_on = true
	Audio.refresh()
	_ok("music switch on starts it again", h._music.playing)
	Audio.siren_start()
	_ok("siren starts and the music ducks", h._siren.playing)
	Audio.siren_stop(0.0)
	await _frames(2)
	_ok("siren stops", not h._siren.playing)
	# 3b) Phase 11 mix: groups, master, buses, focus, tension, variants, presets
	_ok("buses Music + SFX exist and feed Master", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0 and AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == &"Master")
	_ok("limiter sits on the master bus", AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1) is AudioEffectLimiter)
	_ok("ambience loop plays with the music", h._ambience.playing)
	Settings.ui_vol = 0.5
	Settings.sfx_vol = 1.0
	Settings.master_vol = 1.0
	h._last.clear()
	Audio.play("confirm")
	var tick_p = h._pool.filter(func(p): return p.playing and p.stream.resource_path.ends_with("confirm.ogg"))
	_ok("interface volume scales ui cues", tick_p.size() == 1 and absf(tick_p[0].volume_db - (float(Audio.SFX["confirm"][1]) + linear_to_db(0.5))) < 0.1)
	Settings.master_vol = 0.5
	h._last.clear()
	Audio.play("ching")
	_ok("master volume scales every effect", absf(h._pool[0].volume_db - (float(Audio.SFX["ching"][1]) + linear_to_db(0.5))) < 0.1)
	Settings.master_vol = 0.0
	h._last.clear()
	Audio.play("take")
	_ok("master 0 -> silent", h._last.is_empty())
	Settings.master_vol = 1.0
	Settings.ui_vol = 0.8
	var seen := {}
	for i in range(24):
		h._last.clear()
		Audio.play("coin")
		for k in ["coin", "coin2", "coin3", "coin4"]:
			if h._last.has(k):
				seen[k] = true
	_ok("coin cues vary (at least 3 of 4 variants)", seen.size() >= 3, str(seen.keys()))
	h._last.clear()
	var pitches := {}
	for i in range(8):
		h._last.clear()
		Audio.play("flip")
		for p in h._pool:
			if p.playing and p.stream.resource_path.ends_with("flip.ogg"):
				pitches[snappedf(p.pitch_scale, 0.001)] = true
	_ok("repeated cues get pitch variation", pitches.size() >= 3, str(pitches.keys()))
	Audio.focus(true)
	await _frames(40)
	_ok("focus mutes the music (low-pass closes, music ducks)", h._lp.cutoff_hz < 18000.0 and h._duck_db < -1.0, "%.0f Hz %.1f dB" % [h._lp.cutoff_hz, h._duck_db])
	Audio.tension(true)
	await _frames(30)
	_ok("tension layer fades in", h._tension.playing and h._tension.volume_db > -59.0)
	Audio.focus(false)
	Audio.tension(false)
	await _frames(400)
	_ok("focus end restores the music and stops the tension layer", h._lp.cutoff_hz > 15000.0 and absf(h._duck_db) < 0.5 and not h._tension.playing, "%.0f Hz %.1f dB" % [h._lp.cutoff_hz, h._duck_db])
	Settings.apply_mix(1)
	_ok("preset 'calm' lowers music and effects", Settings.music_vol < 0.5 and Settings.sfx_vol < 0.8)
	Settings.apply_mix(0)
	Settings.dialogue_on = false
	Settings.music_on = true
	Settings.sfx_on = true
	Settings.sfx_vol = 1.0
	Audio.refresh()
	var SP = load("res://ui/sound_panel.gd")
	var sp: Control = SP.build(1.0)
	root.add_child(sp)
	await _frames(2)
	_ok("sound panel has master/music/sfx/ui sliders and 3 presets", sp.find_child("Slider_master", true, false) != null and sp.find_child("Slider_music", true, false) != null and sp.find_child("Slider_sfx", true, false) != null and sp.find_child("Slider_ui", true, false) != null and sp.find_child("Preset_2", true, false) != null)
	sp.find_child("Preset_1", true, false).pressed.emit()
	_ok("pressing a preset applies it to Settings and the sliders", Settings.music_vol < 0.5 and absf(sp.find_child("Slider_music", true, false).value - Settings.music_vol) < 0.01)
	Settings.apply_mix(0)
	Settings.save_settings()
	sp.queue_free()
	# 4) a whole game through the real screen: which effects fired
	h._last.clear()
	Settings.speed_name = "FAST"
	var s := Eng.create_game({"playerCount": 4, "seed": 5, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	root.size = Vector2i(1280, 720)
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	rng = AI.new_rng(5 * 31 + 7)
	game.idle.connect(_on_idle)
	game.event_played.connect(func(ev):
		if ev["type"] == "GAME_ENDED":
			ended = true)
	var siren_seen := [false]
	game.begin(s)
	var guard := 0
	while not ended and guard < 400000:
		await process_frame
		_pump()
		if h._siren.playing:
			siren_seen[0] = true
		guard += 1
	_ok("game finished", ended)
	_ok("take / dice / ching were triggered by the game", h._last.has("take") and h._last.has("dice") and h._last.has("ching"), str(h._last.keys()))
	_ok("offer / round_end / game_end|win were triggered by the game", h._last.has("offer") and h._last.has("round_end") and (h._last.has("game_end") or h._last.has("win")), str(h._last.keys()))
	_ok("muted cues (hover / pick) stay silent", not hp_res.get("hover", false) and not hp_res.get("pick", false))
	_ok("other players' payouts / money placement play coin; my payout ching", h._last.has("coin") and h._last.has("ching"))
	_ok("your_turn / stamp / shuffle|final_round|duel_win|duel_lose|win|game_end cues fired", not h._last.has("your_turn") and h._last.has("stamp") and (h._last.has("win") or h._last.has("game_end")), str(h._last.keys()))
	var muted_fired := false
	for m in Audio.MUTED:
		if h._last.has(m):
			muted_fired = true
	_ok("no muted cue was ever played", not muted_fired)
	_ok("accept or duel cue was triggered", h._last.has("accept") or h._last.has("duel"))
	_ok("RAZZIA played the siren", siren_seen[0])
	await _frames(5)
	await _panel_test(h)
	print("AUDIO TEST: checks=%d failed=%d -> %s" % [n, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("  failed: ", fails)
	quit(0 if fails.is_empty() else 1)


func _scr(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _hover(p: Vector2) -> Control:
	var e := InputEventMouseMotion.new()
	e.position = _scr(p)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	return root.gui_get_hovered_control()


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


## The in-game menu (the exit button) carries the sound settings: real mouse clicks must reach the toggles and the sliders.
func _panel_test(h: Node) -> void:
	Settings.dialogue_on = false
	Settings.music_on = true
	Settings.sfx_on = true
	Settings.music_vol = 1.0
	Settings.sfx_vol = 1.0
	game.modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in game.modal_layer.get_children():
		c.queue_free()
	await _frames(2)
	game._on_exit_pressed()
	await _frames(4)
	# Phase 29: the pause settings are tabs; the sound rows are on the 소리 tab
	var tabs = game.modal_layer.find_child("SettingsTabs", true, false)
	_ok("the pause panel has settings tabs", tabs != null)
	if tabs != null:
		tabs.get_meta("select").call(1)
	await _frames(4)
	var rows = game.modal_layer.find_child("SoundRows", true, false)
	_ok("exit menu has the sound rows", rows != null)
	if rows == null:
		return
	for key in ["music", "sfx"]:
		var tg: Button = rows.find_child("Toggle_" + key, true, false)
		var sl: HSlider = rows.find_child("Slider_" + key, true, false)
		var hp: Vector2 = tg.get_global_transform_with_canvas() * (tg.size / 2.0)
		var over := _hover(hp)
		_ok("%s toggle: pointer over it reaches it" % key, over == tg or (over != null and tg.is_ancestor_of(over)))
		await _click(hp)
		await _frames(2)
		_ok("%s toggle: real click turns it OFF" % key, (not Settings.music_on) if key == "music" else (not Settings.sfx_on))
		await _click(hp)
		await _frames(2)
		_ok("%s toggle: second click turns it ON" % key, Settings.music_on if key == "music" else Settings.sfx_on)
		var sp: Vector2 = sl.get_global_transform_with_canvas() * Vector2(sl.size.x * 0.25, sl.size.y / 2.0)
		var over2 := _hover(sp)
		_ok("%s slider: pointer over it reaches it" % key, over2 == sl)
		await _click(sp)
		await _frames(2)
		var got: float = Settings.music_vol if key == "music" else Settings.sfx_vol
		_ok("%s slider: real click at 25%% sets about 0.25" % key, absf(got - 0.25) < 0.15, "value=%.2f" % got)
	# mute key
	var ev := InputEventKey.new()
	ev.keycode = KEY_M
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)
	_ok("M mutes everything (Phase 28: one master mute, the music / effects choices are kept)", Settings.mute_all and Settings.music_on and Settings.sfx_on and Audio.group_vol("sfx") == 0.0)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_M
	ev2.pressed = true
	Input.parse_input_event(ev2)
	Input.flush_buffered_events()
	await _frames(2)
	_ok("M again restores them", not Settings.mute_all and Settings.music_on and Settings.sfx_on and Audio.group_vol("sfx") > 0.0)
	Settings.music_vol = 1.0
	Settings.sfx_vol = 1.0
	Settings.save_settings()


## first card prompt: real pointer motion over a hand card must tick, a real click must play the pick cue
func _hover_pick_test() -> void:
	var h: Node = Audio._inst
	for _k in range(120):
		await process_frame
	var cv = game.hand_views[2]
	_hover(Vector2(2, 700))
	for _k in range(10):
		await process_frame
	h._last.erase("hover")
	h._last.erase("pick")
	var p: Vector2 = cv.get_global_transform_with_canvas() * (cv.size / 2.0)
	_hover(p)
	await process_frame
	await process_frame
	hp_res["hover"] = h._last.has("hover")
	await _click(p)
	await process_frame
	hp_res["pick"] = h._last.has("pick")
	game._deselect()
	_hover(Vector2(2, 700))
