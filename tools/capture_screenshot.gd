extends SceneTree

const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var snap_name := "screenshot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			snap_name = a.substr(4)

	Settings.load_settings()
	Settings.tutorial_done = true
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	SaveStore.path = Settings.test_file("capture_save.json")
	SaveStore.clear()

	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)

	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)

	# Click New Game
	var start: Button = null
	for b in main.current.find_children("*", "Button", true, false):
		if b.name == "NewGameButton" or "빠른 시작" in b.text or "QUICK START" in b.text:
			start = b
			break
	if start != null:
		start.pressed.emit()

	var game = null
	for i in range(600):
		await process_frame
		if main.current != null and main.current.get("state") != null and not main.current.state.is_empty():
			game = main.current
			if game.get("_awaiting_select") == true:
				break

	await _frames(30)
	var dir := "res://tools/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out_path := ProjectSettings.globalize_path("res://tools/screenshots/%s.png" % snap_name)
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("Captured screenshot to: ", out_path, " size: ", img.get_size())
	quit(0)
