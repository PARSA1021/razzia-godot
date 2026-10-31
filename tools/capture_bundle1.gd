extends SceneTree

const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const Eng = preload("res://engine/engine.gd")
const RelicManager = preload("res://engine/relic_manager.gd")
const NegoPanel = preload("res://ui/nego_panel.gd")
const StarterRelicModal = preload("res://ui/board/starter_relic_modal.gd")
const BlackMarketPanel = preload("res://ui/board/black_market_panel.gd")

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _save_snap(name: String) -> void:
	var dir := "res://tools/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out_path := ProjectSettings.globalize_path("res://tools/screenshots/%s.png" % name)
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(out_path)
		print("Saved screenshot: ", out_path)
	else:
		print("ERROR: Image texture was null for ", name)

func _run() -> void:
	var prefix := "before"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("prefix="):
			prefix = a.substr(7)

	Settings.load_settings()
	Settings.tutorial_done = true
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	SaveStore.path = Settings.test_file("capture_bundle1.json")
	SaveStore.clear()

	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)

	var bg_color := Color("0d1810")

	# 1. Starting Relic Modal
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	canvas.add_child(bg)

	var s := Eng.create_game({"playerCount": 4, "seed": 100, "relics": [], "humanPlayerId": "P1", "names": ["앤디", "Vito", "Lola", "Mack"]})
	var starter := StarterRelicModal.new()
	canvas.add_child(starter)
	starter.setup(s, "P1", 1.0, true)
	await _frames(20)
	_save_snap("%s_starter_relic" % prefix)
	starter.queue_free()
	canvas.queue_free()
	await _frames(5)

	# 2. Black Market Panel
	canvas = CanvasLayer.new()
	root.add_child(canvas)
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	canvas.add_child(bg)

	s = Eng.create_game({"playerCount": 4, "seed": 100, "relics": ["lucky_coin"], "humanPlayerId": "P1", "names": ["앤디", "Vito", "Lola", "Mack"]})
	s["players"][0]["money"] = 10000
	var shop := BlackMarketPanel.new()
	canvas.add_child(shop)
	shop.setup(s, "P1", 1.0, true)
	await _frames(20)
	_save_snap("%s_black_market" % prefix)
	shop.queue_free()
	canvas.queue_free()
	await _frames(5)

	var nego_names := {"P1": "앤디", "P2": "Mack", "P3": "Vito", "P4": "Lola"}

	# 3. Negotiation Panel
	canvas = CanvasLayer.new()
	root.add_child(canvas)
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	canvas.add_child(bg)

	var nego := NegoPanel.new()
	canvas.add_child(nego)
	nego.setup(nego_names, "P1", 1.0, 580.0)
	nego.personalities = {"P2": "OPPORTUNIST"}
	var ev_nego := {
		"barId": "HAVANA_BAR",
		"prize": 40000,
		"kind": "ZOCKER",
		"claimantIds": ["P1", "P2"],
		"proposerId": "P1",
		"symbols": {"P1": 5, "P2": 3}
	}
	nego.open(ev_nego)
	var view := {
		"you": "P1",
		"negotiation": ev_nego,
		"state": s
	}
	nego.ask_proposal(view)
	await _frames(20)
	_save_snap("%s_negotiation" % prefix)
	nego.queue_free()
	canvas.queue_free()
	await _frames(5)

	# 4. Duel Panel
	canvas = CanvasLayer.new()
	root.add_child(canvas)
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	canvas.add_child(bg)

	var duel_panel := NegoPanel.new()
	canvas.add_child(duel_panel)
	duel_panel.setup(nego_names, "P1", 1.0, 720.0)
	duel_panel.personalities = {"P2": "OPPORTUNIST", "P3": "AGGRESSIVE"}
	var ev_duel := {
		"barId": "THE_JUNGLE",
		"prize": 60000,
		"kind": "ZOCKER",
		"claimantIds": ["P2", "P3"],
		"proposerId": "P2",
		"playerA": "P2",
		"playerB": "P3",
		"challengerId": "P3",
		"symbolA": 6,
		"symbolB": 5
	}
	duel_panel.open(ev_duel)
	duel_panel.begin_duel(ev_duel)
	await _frames(20)
	_save_snap("%s_duel" % prefix)
	duel_panel.queue_free()
	canvas.queue_free()
	await _frames(5)

	print("ALL SCREENSHOTS CAPTURED WITH PREFIX: ", prefix)
	quit(0)
