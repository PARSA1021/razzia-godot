extends SceneTree
## SteamDeckManager / InputModeManager 단위 점검 (헤드리스).
##   godot --headless --path . --script res://tests/platform_test.gd            -> 데스크톱 경로
##   SteamDeck=1 godot --headless --path . --script res://tests/platform_test.gd -- expect=deck
const Settings = preload("res://ui/settings.gd")
const IMM = preload("res://platform/input_mode_manager.gd")
var checks := 0
var fails: Array = []
var started := false


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


class Listener extends Node:
	var got := []

	func on_quality_changed(k: String) -> void:
		got.append(k)


func _process(_d: float) -> bool:
	if not started:
		started = true
		_run.call_deferred()
	return false


func _run() -> void:
	await process_frame
	var expect := "desktop"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("expect="):
			expect = a.split("=")[1]
	var sdm: Node = root.get_node_or_null("SteamDeckManager")
	var imm: Node = root.get_node_or_null("InputModeManager")
	_ok("autoloads exist", sdm != null and imm != null)
	if sdm == null or imm == null:
		return _end()
	Settings.load_settings()
	var saved_q: String = Settings.quality
	var saved_d: String = Settings.display_mode
	print("  ", sdm.diagnostics_line())
	if expect == "deck":
		_ok("SteamDeck=1 -> STEAM_DECK_CONFIRMED", sdm.kind_name() == "STEAM_DECK_CONFIRMED", sdm.kind_name())
		_ok("handheld", sdm.is_handheld())
		Settings.quality = ""
		_ok("auto quality on Deck is BALANCED", sdm.resolve_quality() == sdm.Quality.BALANCED)
	else:
		_ok("plain Linux is NOT treated as a Steam Deck", sdm.kind_name() != "STEAM_DECK_CONFIRMED", sdm.kind_name())
		Settings.quality = ""
		_ok("auto quality on desktop is HIGH", sdm.resolve_quality() == sdm.Quality.HIGH)
	# presets
	var listener := Listener.new()
	root.add_child(listener)
	listener.add_to_group("quality_listeners")
	for k in ["BATTERY", "BALANCED", "HIGH"]:
		sdm.set_quality(k)
		await process_frame
		_ok("set_quality(%s) -> effective %s" % [k, k], Settings.quality_effective == k)
	_ok("quality listeners are notified (felt shader swap hook)", listener.got == ["BATTERY", "BALANCED", "HIGH"], str(listener.got))
	Settings.quality = "bogus"
	_ok("unknown preset falls back to auto", sdm.resolve_quality() in [sdm.Quality.HIGH, sdm.Quality.BALANCED])
	# settings persist
	Settings.quality = "BATTERY"
	Settings.display_mode = "windowed"
	Settings.save_settings()
	Settings.quality = ""
	Settings.display_mode = ""
	Settings._loaded = false
	Settings.load_settings()
	_ok("quality / display mode are saved and loaded", Settings.quality == "BATTERY" and Settings.display_mode == "windowed")
	# input mode
	var modes := []
	imm.input_mode_changed.connect(func(m, _d): modes.append(m))
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	Input.parse_input_event(jb)
	await process_frame
	_ok("pad button -> GAMEPAD", imm.mode_name() == "GAMEPAD")
	var mm := InputEventJoypadMotion.new()
	mm.axis = JOY_AXIS_LEFT_X
	mm.axis_value = 0.2
	var k := InputEventKey.new()
	k.keycode = KEY_A
	k.pressed = true
	Input.parse_input_event(k)
	await process_frame
	_ok("key -> KEYBOARD_MOUSE", imm.mode_name() == "KEYBOARD_MOUSE")
	Input.parse_input_event(mm)
	await process_frame
	_ok("stick inside the dead zone does not switch to GAMEPAD", imm.mode_name() == "KEYBOARD_MOUSE")
	mm.axis_value = 0.9
	Input.parse_input_event(mm)
	await process_frame
	_ok("stick past the dead zone switches to GAMEPAD", imm.mode_name() == "GAMEPAD")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	Input.parse_input_event(t)
	await process_frame
	_ok("touch -> TOUCH", imm.mode_name() == "TOUCH")
	_ok("input_mode_changed fired for every switch", modes.size() >= 4, str(modes))
	_ok("glyphs follow the device (touch)", imm.prompt("accept") != "A")
	Input.parse_input_event(jb)
	await process_frame
	_ok("glyphs follow the device (pad)", imm.prompt("accept") == "A" and imm.prompt("pause") != "")
	for act in ["ui_accept", "ui_cancel", "pause", "toggle_mute", "venue_info", "skip_anim"]:
		var has_pad := false
		for e in InputMap.action_get_events(act):
			if e is InputEventJoypadButton:
				has_pad = true
		_ok("action %s has a controller binding" % act, has_pad)
	IMM.ensure_bindings()
	IMM.ensure_bindings()
	var n_acc := 0
	for e in InputMap.action_get_events("ui_accept"):
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A:
			n_acc += 1
	_ok("ensure_bindings is idempotent", n_acc == 1, str(n_acc))
	Settings.quality = saved_q
	Settings.display_mode = saved_d
	Settings.save_settings()
	_end()


func _end() -> void:
	print("PLATFORM TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
