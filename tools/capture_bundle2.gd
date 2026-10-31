extends SceneTree
## Captures screenshots and frames for animated GIFs for Bundle 2 (Roadmap 4 & 5):
## 1. Player-involved duel presentation (blank dice before roll, tie notice, defender landing, verdict)
## 2. AI-vs-AI compact duel on venue card (mini dice, calculation, winner highlight, pot float)
## 3. Settlement screen with duel outcome recorded
## godot --path . --fixed-fps 30 --script res://tools/capture_bundle2.gd

const GameScreen = preload("res://ui/game_screen.gd")
const Settings = preload("res://ui/settings.gd")
const NegoPanel = preload("res://ui/nego_panel.gd")
const CompactDuelView = preload("res://ui/compact_duel_view.gd")
const Eng = preload("res://engine/engine.gd")

var started := false

func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false

func _save_png(name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://tools/screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var out_path := "%s/%s.png" % [dir, name]
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(out_path)
		print("Saved screenshot: ", out_path)

func _save_frame(folder: String, idx: int) -> void:
	var dir := ProjectSettings.globalize_path("res://tools/screenshots/%s" % folder)
	DirAccess.make_dir_recursive_absolute(dir)
	var out_path := "%s/frame_%03d.png" % [dir, idx]
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(out_path)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true
	Settings.dialogue_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.speed_name = "NORMAL"
	Settings.reduce_motion = false
	Settings.screen_shake = true

	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)

	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	# =========================================================================
	# Scene 1: Player Duel Intro & Sequence
	# =========================================================================
	print("--- Capturing Scene 1: Player Duel ---")
	NegoPanel.session_first_duel = true
	var nego := NegoPanel.new()
	var names := {"P1": "나", "P2": "Vito", "P3": "Lola", "P4": "Mack"}
	nego.setup(names, "P1", 1.0, 760.0)
	nego.personalities = {"P2": "CONSERVATIVE"}
	host.add_child(nego)

	var ev_duel := {
		"barId": "COLIBRI",
		"prize": 50000,
		"kind": "ZOCKER",
		"claimantIds": ["P1", "P2"],
		"proposerId": "P1",
		"playerA": "P1",
		"playerB": "P2",
		"challengerId": "P2",
		"symbolA": 4,
		"symbolB": 2
	}
	nego.proposal = {"P1": 25000, "P2": 25000}
	nego.begin_duel(ev_duel)
	await _frames(15)

	_save_png("duel_player_intro")

	# Capture frames for player duel GIF
	var p_frame := 0
	_save_frame("player_duel_frames", p_frame)
	p_frame += 1

	# Ask roll
	nego.ask_roll()
	for f in range(12):
		await _frames(1)
		_save_frame("player_duel_frames", p_frame)
		p_frame += 1

	# Simulate rolls: Defender P1 rolls 3 (4+3=7), Challenger P2 rolls 5 (2+5=7 -> TIE)
	nego.set_rolls({"rollA": 3, "rollB": 5})
	for f in range(25):
		await _frames(2)
		_save_frame("player_duel_frames", p_frame)
		p_frame += 1

	# Finish duel
	nego.finish_duel({
		"barId": "COLIBRI",
		"playerA": "P1",
		"playerB": "P2",
		"rollA": 3,
		"rollB": 5,
		"scoreA": 7,
		"scoreB": 7,
		"tie": true,
		"challengerId": "P2",
		"winnerId": "P2"
	})
	for f in range(15):
		await _frames(2)
		_save_frame("player_duel_frames", p_frame)
		p_frame += 1

	_save_png("duel_player_resolved")
	nego.queue_free()
	await _frames(5)

	# =========================================================================
	# Scene 2: AI Compact Duel on Bar Card (Full table visible!)
	# =========================================================================
	print("--- Capturing Scene 2: AI Compact Duel on Bar ---")
	Settings.ai_duel_mode = "COMPACT"
	var s := Eng.create_game({"playerCount": 4, "seed": 42, "humanPlayerId": "P1"})
	var game := GameScreen.new()
	game.autosave_enabled = false
	host.add_child(game)
	game.begin(s)
	await _frames(15)

	# Trigger compact duel between P2 and P3 at COLIBRI
	var c_frame := 0
	game._play_event({
		"type": "DUEL_STARTED",
		"barId": "COLIBRI",
		"playerA": "P2",
		"playerB": "P3",
		"symbolA": 3,
		"symbolB": 4,
		"prize": 40000,
		"challengerId": "P3"
	})

	for f in range(8):
		await _frames(1)
		_save_frame("compact_duel_frames", c_frame)
		c_frame += 1

	_save_png("duel_ai_compact")

	# Roll dice
	game._play_event({
		"type": "DICE_ROLLED",
		"rollA": 4,
		"rollB": 3
	})
	for f in range(12):
		await _frames(1)
		_save_frame("compact_duel_frames", c_frame)
		c_frame += 1

	# Resolve duel (7 vs 7 tie -> P3 Lola wins as challenger)
	game._play_event({
		"type": "DUEL_RESOLVED",
		"barId": "COLIBRI",
		"playerA": "P2",
		"playerB": "P3",
		"rollA": 4,
		"rollB": 3,
		"scoreA": 7,
		"scoreB": 7,
		"winnerId": "P3",
		"challengerId": "P3",
		"tie": true
	})
	for f in range(20):
		await _frames(1)
		_save_frame("compact_duel_frames", c_frame)
		c_frame += 1

	# =========================================================================
	# Scene 3: Settlement Screen with Duel Reason Recorded
	# =========================================================================
	print("--- Capturing Scene 3: Settlement Screen with Duel Record ---")
	game._round_awards["P3"] = [{"bar": "COLIBRI", "amount": 40000}]
	await game._play_event({
		"type": "ROUND_ENDED",
		"round": 1,
		"croupierId": "P2",
		"money": {"P1": 100000, "P2": 100000, "P3": 140000, "P4": 100000},
		"gained": {"P1": 0, "P2": 0, "P3": 40000, "P4": 0}
	})
	await _frames(30)
	_save_png("duel_settlement_record")

	game.queue_free()
	await _frames(5)

	print("ALL CAPTURES COMPLETED SUCCESSFULLY!")
	quit(0)
