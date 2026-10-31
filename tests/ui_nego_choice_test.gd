extends SceneTree
## Negotiation answer cards (UI only): the numbers equal the engine's, left/right + Enter, one answer only, skip.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_nego_choice_test.gd
const Nego = preload("res://ui/nego_panel.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
var checks := 0
var fails: Array = []
var started := false
var host: Control

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _real(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout        # the focus guard counts real seconds


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame

func _process(_d: float) -> bool:
	if started: return false
	started = true
	_run.call_deferred()
	return false

func _view(me_sym: int, prop_sym: int, mine: int, theirs: int) -> Dictionary:
	return {"you": "P1", "negotiation": {"proposal": {"P1": mine, "P2": theirs}, "proposerId": "P2", "symbols": {"P1": me_sym, "P2": prop_sym}}}

func _make(skipping := false):
	var n = Nego.new()
	n.names = {"P1": "나", "P2": "Vito"}
	n.human_id = "P1"
	n.personalities = {"P2": "CONSERVATIVE"}
	if skipping:
		n.skipping = func(): return true
	host.add_child(n)
	n.visible = true
	return n

func _texts(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		out += (l as Label).text + " | "
	return out

func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := InputEventJoypadButton.new()
	r.button_index = button
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame

func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.reduce_motion = false
	Settings.beginner_hints = true
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	var n = _make()
	var view := _view(1, 4, 5000, 15000)
	var res := [""]
	var emitted := [0]
	n.decided.connect(func(_v): emitted[0] += 1)
	var f := func(): res[0] = await n.ask_response(view)
	f.call()
	await _frames(10)
	await _real(0.8)
	var btns: Array = n._action_box.find_children("*", "Button", true, false)
	_ok("two answer cards", btns.size() == 2, str(btns.size()))
	var acc: Button = btns[0]
	var duel: Button = btns[1]
	var chance := Eng.duel_win_probability(1, 4, true)
	_ok("ACCEPT card shows the proposed amount", "$5,000" in _texts(acc), _texts(acc))
	_ok("DUEL card shows the engine's win chance", ("승률 %d%%" % int(round(chance * 100.0))) in _texts(duel), _texts(duel))
	_ok("DUEL card shows the real pot and the real loss", "$20,000" in _texts(duel) and "지면 $0" in _texts(duel), _texts(duel))
	_ok("default focus is on ACCEPT", acc.has_focus())
	await _key(KEY_RIGHT)
	_ok("Right moves the focus to DUEL", duel.has_focus())
	await _key(KEY_RIGHT)
	_ok("Right wraps back to ACCEPT", acc.has_focus())
	await _key(KEY_LEFT)
	_ok("Left moves the focus to DUEL", duel.has_focus())
	_ok("nothing answered by moving the focus", res[0] == "" and emitted[0] == 0)
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)                                        # mashed Enter
	duel.emit_signal("pressed")                                  # extra clicks
	acc.emit_signal("pressed")                                   # and a click on the other card
	_ok("LOCKED: both cards disabled right away", duel.disabled and acc.disabled)
	_ok("the chosen card says what was chosen", "결투 선언" in _texts(duel))
	_ok("not answered yet during the short hold", res[0] == "")
	await _frames(40)
	_ok("answer is DUEL (the focused card), exactly once", res[0] == "DUEL" and emitted[0] == 1, "%s x%d" % [res[0], emitted[0]])
	n.queue_free()
	await _frames(2)

	# accept by keyboard on the default focus
	n = _make()
	res[0] = ""
	emitted[0] = 0
	n.decided.connect(func(_v): emitted[0] += 1)
	var f2 := func(): res[0] = await n.ask_response(view)
	f2.call()
	await _frames(10)
	await _real(0.8)
	await _key(KEY_ENTER)
	await _frames(40)
	_ok("Enter on the default focus accepts", res[0] == "ACCEPT" and emitted[0] == 1, "%s x%d" % [res[0], emitted[0]])
	n.queue_free()
	await _frames(2)

	# gamepad: d-pad moves between the cards, A confirms (the same keys the engine maps to ui_left / ui_right / ui_accept)
	n = _make()
	res[0] = ""
	emitted[0] = 0
	n.decided.connect(func(_v): emitted[0] += 1)
	var f4 := func(): res[0] = await n.ask_response(view)
	f4.call()
	await _frames(10)
	await _real(0.8)
	btns = n._action_box.find_children("*", "Button", true, false)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_ok("gamepad d-pad right moves the focus to DUEL", btns[1].has_focus())
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_A)                                      # mashed A
	await _frames(40)
	_ok("gamepad A answers DUEL exactly once", res[0] == "DUEL" and emitted[0] == 1, "%s x%d" % [res[0], emitted[0]])
	n.queue_free()
	await _frames(2)

	# an Enter that arrives while the cards have just appeared must not answer for the player
	n = _make()
	res[0] = ""
	var f3 := func(): res[0] = await n.ask_response(view)
	f3.call()
	await _key(KEY_ENTER)
	await _frames(5)
	_ok("a stray Enter right after the cards appear answers nothing", res[0] == "")
	n.queue_free()
	await _frames(2)

	# skip: no waiting after the choice
	n = _make(true)
	res[0] = ""
	var fpad := func(): res[0] = await n.ask_response(view)
	fpad.call()
	await _frames(10)
	var b4: Array = n._action_box.find_children("*", "Button", true, false)
	if b4.size() == 2:
		b4[1].emit_signal("pressed")
	await _frames(4)
	_ok("skip: the answer is returned at once", res[0] == "DUEL", res[0])
	n.queue_free()
	await _frames(2)

	# the card that is better by expected value is labelled by a fact, never forced
	n = _make()
	var f5 := func(): await n.ask_response(_view(6, 1, 5000, 15000))
	f5.call()
	await _frames(40)
	var b5: Array = n._action_box.find_children("*", "Button", true, false)
	# Phase 28: the fact is one line under the two cards (a marker inside the card ran out of it on small screens);
	# the better card keeps its coloured, thicker frame
	_ok("high card: the panel says the duel pays more on average", "평균적으로는 결투가 더 유리" in _texts(n._action_box), _texts(n._action_box))
	var nb: StyleBoxFlat = b5[1].get_theme_stylebox("normal")
	var na: StyleBoxFlat = b5[0].get_theme_stylebox("normal")
	_ok("high card: the DUEL card's frame is the marked one", nb.border_width_left > na.border_width_left)
	n.queue_free()
	await _frames(2)

	print("NEGO CHOICE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
