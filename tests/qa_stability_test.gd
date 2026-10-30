extends SceneTree
## QA: repeated screen changes must not pile up nodes, objects or orphans.
## menu -> game -> menu, ten times, plus help / records open-close; node and orphan counts are compared against the first cycle.
##   godot --path . --headless --fixed-fps 60 --script res://tests/qa_stability_test.gd
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")

var checks := 0
var fails: Array = []
var started := false
var main: Control


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _btn(from: Node, needle: String) -> Button:
	if from == null:
		return null
	for b in from.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _press(b: Button) -> void:
	if b != null and is_instance_valid(b):
		b.emit_signal("pressed")
	await _frames(12)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.speed_name = "fast"
	SaveStore.path = Settings.test_file("qa_stab.json")          # never the player's real autosave, and never shared with another test process
	SaveStore.clear()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)

	var nodes: Array = []
	var orphans: Array = []
	for cycle in range(10):
		# menu -> new game
		await _press(_btn(main.current, "NEW GAME"))
		await _frames(30)
		var game = main.current
		if cycle == 0:
			_ok("a game starts from the menu", game.get("state") != null and not game.state.is_empty())
		# leave through the in-game exit panel, the way a player does
		game.exit_btn.emit_signal("pressed")
		await _frames(20)
		var leave := _btn(game, "나가기")
		if leave == null:
			_ok("the exit panel offers 나가기 (cycle %d)" % cycle, false)
			break
		await _press(leave)
		await _frames(30)
		if cycle == 0:
			_ok("leaving a game returns to the menu", _btn(main.current, "NEW GAME") != null)
		# help and records, opened and closed again
		await _press(_btn(main.current, "HOW TO PLAY"))
		await _frames(20)
		var back := _btn(main.current, "닫기")
		if back == null:
			back = _btn(main.current, "← ")
		if back != null:
			await _press(back)
		else:
			main.show_menu()
		await _frames(25)
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		orphans.append(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_ok("ten menu/game cycles completed", nodes.size() == 10, str(nodes.size()))
	if nodes.size() >= 10:
		var first: float = nodes[1]
		var last: float = nodes[9]
		_ok("node count does not grow over ten cycles", last <= first * 1.2 + 40.0, "%d -> %d" % [int(first), int(last)])
		_ok("no orphan nodes pile up", float(orphans[9]) <= float(orphans[1]) + 10.0, "%d -> %d" % [int(orphans[1]), int(orphans[9])])
	print("QA STABILITY: checks=%d failed=%d nodes=%s orphans=%s -> %s" % [checks, fails.size(), str(nodes), str(orphans), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
