extends SceneTree
## The "menu?" panel must answer to mouse clicks, touch taps, keyboard and the gamepad accept button.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_exit_menu_test.gd -- w=1280 h=720
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
var game
var checks := 0
var fails: Array = []
var started := false
var W_ := 1280
var H_ := 720

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _mouse(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)

func _touch(pos: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = down
		e.index = 0
		Input.parse_input_event(e)
		await _frames(2)

func _process(_d: float) -> bool:
	if started: return false
	started = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv[0] == "w": W_ = int(kv[1])
		if kv[0] == "h": H_ = int(kv[1])
	_run.call_deferred()
	return false

func _center(n: Control) -> Vector2:
	return n.get_global_rect().get_center()

func _find_btn(root_n: Node, text: String) -> Button:
	for b in root_n.find_children("*", "Button", true, false):
		if text in b.text: return b
	return null

func _run() -> void:
	Settings.load_settings()
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	root.size = Vector2i(W_, H_)
	root.content_scale_size = Vector2i(720, 1280) if H_ > W_ else Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 7, "seed": 5, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal"]})
	game = Game.new()
	game.autosave_enabled = false
	root.add_child(game)
	var left := [false]
	game.exit_requested.connect(func(): left[0] = true)
	game.begin(s)
	for i in range(1500):
		if game._awaiting_select: break
		await process_frame
	_ok("game reached card selection", game._awaiting_select)
	for how in ["mouse", "touch"]:
		game._on_exit_pressed()
		await _frames(10)
		var panel = game.modal_layer.get_node_or_null("ExitConfirm")
		_ok("%s: panel open" % how, panel != null)
		var stay := _find_btn(panel, "계속하기")
		var leave := _find_btn(panel, "나가기")
		var vp := root.get_visible_rect().size
		var win_scale := Vector2(float(W_), float(H_)) / vp
		_ok("%s: buttons are inside the screen" % how, vp.x >= _center(stay).x and _center(stay).y <= vp.y and _center(leave).y <= vp.y, "stay=%s vp=%s" % [str(_center(stay)), str(vp)])
		# what is on top at the button centre?
		if how == "mouse":
			await _mouse(_center(stay) * win_scale)
		else:
			await _touch(_center(stay) * win_scale)
		await _frames(10)
		_ok("%s: 계속하기 closes the panel" % how, game.modal_layer.get_node_or_null("ExitConfirm") == null or game.modal_layer.get_node("ExitConfirm").is_queued_for_deletion())
		await _frames(5)
	# 나가기
	game._on_exit_pressed()
	await _frames(10)
	var p2 = game.modal_layer.get_node_or_null("ExitConfirm")
	var lv := _find_btn(p2, "나가기")
	var pos := _center(lv) * (Vector2(float(W_), float(H_)) / root.get_visible_rect().size)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	await _frames(3)
	var hov = root.gui_get_hovered_control()
	print("  [dbg] hovered at leave button: ", hov, " name=", hov.name if hov else "", " parent=", hov.get_parent().name if hov else "", " z=", hov.z_index if hov else 0, " leave z=", lv.z_index, " leave disabled=", lv.disabled, " focus_mode=", lv.focus_mode)
	await _mouse(pos)
	await _frames(10)
	_ok("mouse: 나가기 requests the exit", left[0])
	print("EXIT MENU TEST: checks=%d failed=%d size=%dx%d -> %s" % [checks, fails.size(), W_, H_, "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
