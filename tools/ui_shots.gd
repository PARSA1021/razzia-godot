extends SceneTree
## Screenshots of the menu-side screens (Phase 29 "no scrolling" check), plus a scroll audit:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/ui_shots.gd -- w=844 h=390 out=/tmp/s lang=en
## Writes <out>_menu.png, _settings_<tab>.png, _help_<page>.png, _records.png and prints, for every screen, whether any
## visible ScrollContainer exists and whether every visible button / label lies inside the screen.
## Exit code 1 when a scroll area is shown or something lies off screen.

const Settings = preload("res://ui/settings.gd")
const I18n = preload("res://ui/i18n.gd")

var W_ := 1280
var H_ := 720
var out := ""
var problems: Array = []
var main: Control


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		match kv[0]:
			"w": W_ = int(kv[1])
			"h": H_ = int(kv[1])
			"out": out = kv[1]
			"lang":
				Settings.load_settings()
				Settings.language = kv[1]
				I18n.apply(kv[1])
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	if out != "" and DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	# scroll audit: no visible scroll area, nothing visible outside the screen
	var screen := Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
	for n in root.find_children("*", "ScrollContainer", true, false):
		if (n as Control).is_visible_in_tree():
			problems.append("%s: scroll area %s" % [name, n.get_path()])
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Button or c is Label or c is HSlider or c is LineEdit) or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x < 2 or r.size.y < 2:
			continue
		if not screen.grow(2.0).encloses(r):
			problems.append("%s: off screen '%s' %s" % [name, str(c.get("text")).substr(0, 30), str(r)])
	print("  [%s] checked" % name)


func _btn(from: Node, needle: String) -> Button:
	for b in from.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree():
			return b
	return null


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.reduce_motion = true
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(720, 1280) if H_ > W_ else Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	await _shot("menu")
	main.current._show_settings()
	await _frames(6)
	var tabs: Node = main.current.find_child("SettingsTabs", true, false)
	var n_tabs: int = tabs.get_meta("pages").size()
	for i in range(n_tabs):
		tabs.get_meta("select").call(i)
		await _shot("settings_%d" % i)
	main.current.get_node("SettingsModal").free()
	main.current._toggle_help()
	await _frames(6)
	var help: Node = main.current._help
	for i in range(30):
		await _shot("help_%02d" % i)
		var nx := _btn(help, "다음  ▶")
		if nx == null:
			break
		nx.pressed.emit()
		await _frames(3)
	main.current._toggle_help()
	await _frames(4)
	var rb := main.current.find_child("RecordsButton", true, false) as Button
	rb.pressed.emit()
	await _frames(8)
	var rs: Node = null
	for c in main.current.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("records_screen.gd"):
			rs = c
	if rs != null and rs.has_method("tab_count"):
		for i in range(rs.tab_count()):
			rs.select_tab(i)
			await _shot("records_%d" % i)
	else:
		await _shot("records")
	print("UI SHOTS %dx%d: %d problem(s)" % [W_, H_, problems.size()])
	for p in problems.slice(0, 30):
		print("   ", p)
	quit(0 if problems.is_empty() else 1)
