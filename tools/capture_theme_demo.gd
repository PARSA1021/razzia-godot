extends SceneTree

const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const ThemeAssets = preload("res://ui/theme_assets.gd")
const CardView = preload("res://ui/card_view.gd")

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.speed_name = "FAST"
	SaveStore.path = Settings.test_file("capture_save.json")
	SaveStore.clear()

	var shots_dir := ProjectSettings.globalize_path("res://tools/screenshots/theme_test")
	DirAccess.make_dir_recursive_absolute(shots_dir)

	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)

	# 1. Capture Noir Card Gallery
	await _capture_gallery("noir", shots_dir + "/01_noir_cards_showcase.png")

	# 2. Capture Circus Card Gallery (Circus Razzia + Fallback Gambler + Fallback Poster)
	await _capture_gallery("circus", shots_dir + "/02_circus_cards_showcase.png")

	# 3. Capture Gameplay Board with a Razzia card injected
	await _capture_board_with_razzia("noir", shots_dir + "/03_noir_board_gameplay.png")
	await _capture_board_with_razzia("circus", shots_dir + "/04_circus_board_gameplay.png")

	print("Theme capture completed! Saved to: ", shots_dir)
	quit(0)


func _capture_gallery(theme_name: String, out_path: String) -> void:
	Settings.theme = theme_name
	ThemeAssets.clear_cache()

	var canvas := Control.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color("0a120e")
	bg.size = Vector2(1280, 720)
	canvas.add_child(bg)

	var title_lbl := Label.new()
	title_lbl.text = "THEME: %s (RAZZIA / ZOCKER FALLBACK / HAVANA FALLBACK / BACK)" % theme_name.to_upper()
	title_lbl.position = Vector2(60, 40)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color("d4af37"))
	canvas.add_child(title_lbl)

	# 1) Razzia Card
	var cv_razzia = CardView.new()
	cv_razzia.card = {"barId": "COLIBRI", "type": "RAZZIA", "dieSymbol": 3}
	cv_razzia.size = Vector2(210, 290)
	cv_razzia.position = Vector2(60, 100)
	canvas.add_child(cv_razzia)

	var l1 := Label.new()
	l1.text = "RAZZIA CARD\n(%s)" % ("SWAPPED (CIRCUS)" if theme_name == "circus" else "ORIGINAL (NOIR)")
	l1.position = Vector2(60, 405)
	l1.add_theme_font_size_override("font_size", 14)
	l1.add_theme_color_override("font_color", Color("e6c280"))
	canvas.add_child(l1)

	# 2) Gambler Card (Colibri)
	var cv_gambler = CardView.new()
	cv_gambler.card = {"barId": "COLIBRI", "type": "ZOCKER", "dieSymbol": 5}
	cv_gambler.size = Vector2(210, 290)
	cv_gambler.position = Vector2(300, 100)
	canvas.add_child(cv_gambler)

	var l2 := Label.new()
	l2.text = "GAMBLER CARD\n(%s)" % ("FALLBACK TO NOIR" if theme_name == "circus" else "ORIGINAL (NOIR)")
	l2.position = Vector2(300, 405)
	l2.add_theme_font_size_override("font_size", 14)
	l2.add_theme_color_override("font_color", Color("e6c280"))
	canvas.add_child(l2)

	# 3) Gambler Card (Havana)
	var cv_havana = CardView.new()
	cv_havana.card = {"barId": "HAVANA_BAR", "type": "ZOCKER", "dieSymbol": 6}
	cv_havana.size = Vector2(210, 290)
	cv_havana.position = Vector2(540, 100)
	canvas.add_child(cv_havana)

	var l3 := Label.new()
	l3.text = "HAVANA CARD\n(%s)" % ("FALLBACK TO NOIR" if theme_name == "circus" else "ORIGINAL (NOIR)")
	l3.position = Vector2(540, 405)
	l3.add_theme_font_size_override("font_size", 14)
	l3.add_theme_color_override("font_color", Color("e6c280"))
	canvas.add_child(l3)

	# 4) Card Back
	var cv_back = CardView.new()
	cv_back.card = {}
	cv_back.face_up = false
	cv_back.size = Vector2(210, 290)
	cv_back.position = Vector2(780, 100)
	canvas.add_child(cv_back)

	var l4 := Label.new()
	l4.text = "CARD BACK\n(ZOCARI BRAND 'Z')"
	l4.position = Vector2(780, 405)
	l4.add_theme_font_size_override("font_size", 14)
	l4.add_theme_color_override("font_color", Color("e6c280"))
	canvas.add_child(l4)

	# 5) Character Portrait
	var port = Control.new()
	port.custom_minimum_size = Vector2(100, 100)
	port.position = Vector2(1040, 130)
	var Portrait = preload("res://ui/portrait.gd")
	port.draw.connect(func():
		Portrait.paint(port, Vector2(50, 50), 45, "CONSERVATIVE", "Vito")
	)
	canvas.add_child(port)

	var l5 := Label.new()
	l5.text = "VITO PORTRAIT\n(FALLBACK TO NOIR)"
	l5.position = Vector2(1020, 240)
	l5.add_theme_font_size_override("font_size", 14)
	l5.add_theme_color_override("font_color", Color("e6c280"))
	canvas.add_child(l5)

	await _frames(20)
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("Saved gallery: ", out_path)
	canvas.queue_free()
	await _frames(5)


func _capture_board_with_razzia(theme_name: String, out_path: String) -> void:
	Settings.theme = theme_name
	ThemeAssets.clear_cache()

	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(15)

	# Click New Game / Quick Start
	for b in main.current.find_children("*", "Button", true, false):
		if b.name == "NewGameButton" or "빠른 시작" in b.text or "QUICK START" in b.text:
			b.pressed.emit()
			break

	var game = null
	for i in range(400):
		await process_frame
		if main.current != null and main.current.get("state") != null and not main.current.state.is_empty():
			game = main.current
			if game.get("_awaiting_select") == true:
				break

	if game != null and game.has_method("_layout_hand"):
		# Inject a Razzia card into human hand to clearly demonstrate the theme change on the board!
		if game.hand_views.size() > 0:
			game.hand_views[0].card = {"barId": "COLIBRI", "type": "RAZZIA", "dieSymbol": 3}
			game.hand_views[0].queue_redraw()

	await _frames(25)
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("Captured board for theme '%s' with razzia to: %s" % [theme_name, out_path])
	main.queue_free()
	await _frames(10)
