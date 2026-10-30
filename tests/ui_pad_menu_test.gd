extends SceneTree
## 메뉴를 컨트롤러로만: 게임 방법 / 기록 열고 닫기(B), 환경 설정 펼치기, 성능·화면 행까지 십자키로 닿는지.
##   godot --headless --path . --script res://tests/ui_pad_menu_test.gd
const Settings = preload("res://ui/settings.gd")
var checks := 0
var fails: Array = []
var started := false


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _pad(b: int) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _ftext() -> String:
	var f := root.gui_get_focus_owner()
	return (f as Button).text if f is Button else ("<%s>" % f.name if f != null else "<none>")


## walk the d-pad (the way a player would: towards the button on screen) until the focused button's text contains `needle`
func _down_to(needle: String, n: int = 30) -> bool:
	var target: Button = null
	for b in root.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.is_queued_for_deletion():
			target = b
	if target == null:
		return false
	var tried := {}
	for i in n:
		var fo := root.gui_get_focus_owner()
		if fo == target:
			return true
		var dir := JOY_BUTTON_DPAD_DOWN
		if fo != null:
			var d: Vector2 = target.get_global_rect().get_center() - fo.get_global_rect().get_center()
			var horiz: bool = absf(d.x) > absf(d.y)
			var key := "%s>%s" % [fo.get_instance_id(), horiz]
			if tried.has(key):
				horiz = not horiz
			tried[key] = true
			if horiz:
				dir = JOY_BUTTON_DPAD_RIGHT if d.x > 0 else JOY_BUTTON_DPAD_LEFT
			else:
				dir = JOY_BUTTON_DPAD_DOWN if d.y > 0 else JOY_BUTTON_DPAD_UP
		await _pad(dir)
	return root.gui_get_focus_owner() == target


func _process(_d: float) -> bool:
	if not started:
		started = true
		_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.load_settings()
	var saved_q: String = Settings.quality
	var saved_d: String = Settings.display_mode
	var w := 1280
	var h := 800
	for a in OS.get_cmdline_user_args():
		if a.begins_with("w="):
			w = int(a.substr(2))
		if a.begins_with("h="):
			h = int(a.substr(2))
	root.size = Vector2i(w, h)
	root.content_scale_size = Vector2i(1280, 720)
	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	var menu: Node = main.current
	_ok("menu opens with a focused button", root.gui_get_focus_owner() != null, _ftext())
	# how to play
	_ok("d-pad reaches HOW TO PLAY", await _down_to("HOW TO PLAY"), _ftext())
	await _pad(JOY_BUTTON_A)
	await _frames(20)
	var help := menu.find_children("*", "", true, false).filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("help_screen.gd"))
	_ok("A opens how-to-play", not help.is_empty())
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_B)
	await _frames(20)
	help = menu.find_children("*", "", true, false).filter(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("help_screen.gd") and not n.is_queued_for_deletion())
	_ok("B closes how-to-play", help.is_empty())
	_ok("focus returns to HOW TO PLAY", "HOW TO PLAY" in _ftext(), _ftext())
	# records
	_ok("d-pad reaches RECORDS", await _down_to("RECORDS"), _ftext())
	await _pad(JOY_BUTTON_A)
	await _frames(20)
	await _pad(JOY_BUTTON_B)
	await _frames(20)
	_ok("records open and close with A / B, focus comes back", "RECORDS" in _ftext(), _ftext())
	# settings fold
	_ok("d-pad reaches 환경 설정", await _down_to("환경 설정"), _ftext())
	await _pad(JOY_BUTTON_A)
	await _frames(10)
	# Phase 29: settings open in their own panel with tabs; the focus starts on the first tab
	_ok("A opens the settings panel on its first tab", menu.find_child("SettingsModal", true, false) != null and "게임 진행" in _ftext(), _ftext())
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_ok("d-pad moves along the tabs to 화면", "화면" in _ftext(), _ftext())
	await _pad(JOY_BUTTON_A)
	await _frames(5)
	var got_battery := await _down_to("배터리 절약", 40)
	_ok("d-pad reaches the 성능 row (배터리 절약)", got_battery, _ftext())
	if got_battery:
		await _pad(JOY_BUTTON_A)
		await _frames(5)
		_ok("A on 배터리 절약 applies the preset", Settings.quality == "BATTERY" and Settings.quality_effective == "BATTERY")
	_ok("d-pad reaches the 화면 row", await _down_to("전체 화면", 10), _ftext())
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
	if shots != "":
		await _frames(5)
		root.get_texture().get_image().save_png(shots + "_menu_settings.png")
	var fo := root.gui_get_focus_owner()
	_ok("the focused settings row is on screen", fo != null and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(fo.get_global_rect()), str(fo.get_global_rect() if fo != null else ""))
	await _pad(JOY_BUTTON_B)
	await _frames(10)
	_ok("B closes the settings panel, focus back on 환경 설정", menu.find_child("SettingsModal", true, false) == null and "환경 설정" in _ftext(), _ftext())
	_ok("and back up to NEW GAME", await _down_to("NEW GAME", 40), _ftext())
	Settings.quality = saved_q
	Settings.display_mode = saved_d
	Settings.save_settings()
	root.get_node("SteamDeckManager").apply_quality()
	print("PAD MENU TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
