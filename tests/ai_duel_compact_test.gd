extends SceneTree
## Test for AI Duel Condensation (Item 5):
## - In COMPACT mode, AI duels do not dim the screen or open the full-screen modal
## - Compact widget appears on the venue card, rolls dice, shows sum, highlights winner
## - Settlement screen preserves and displays the detailed duel reason
## - In FULL mode or when player is involved, the full modal is preserved
##   godot --headless --path . --fixed-fps 60 --script res://tests/ai_duel_compact_test.gd

const GameScreen = preload("res://ui/game_screen.gd")
const Settings = preload("res://ui/settings.gd")
const CompactDuelView = preload("res://ui/compact_duel_view.gd")

var checks := 0
var fails: Array = []
var started := false
var host: Control

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false

func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.reduce_motion = false
	Settings.speed_name = "FAST"
	root.size = Vector2i(1280, 800)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	print("=== [1] Direct CompactDuelView Widget Verification ===")
	var cd := CompactDuelView.new()
	var duel_ev := {
		"barId": "COLIBRI",
		"playerA": "P2",
		"playerB": "P3",
		"symbolA": 3,
		"symbolB": 4,
		"prize": 30000,
		"challengerId": "P3"
	}
	var pnames := {"P2": "Vito", "P3": "Lola"}
	host.add_child(cd)
	cd.setup(duel_ev, pnames, 1.0)
	await _frames(2)

	_ok("compact duel header shows bar and duel label", "COLIBRI" in cd._head_lbl.text and "결투" in cd._head_lbl.text, cd._head_lbl.text)
	_ok("compact duel prize shows $30,000", "$30,000" in cd._prize_lbl.text, cd._prize_lbl.text)
	_ok("initial dice show '?' (hidden before roll)", "?" in cd._a_calc_lbl.text and "?" in cd._b_calc_lbl.text)

	# Set rolls
	cd.set_rolls({"rollA": 4, "rollB": 3})
	await _frames(2)
	_ok("rolls calculated correctly (3 + 🎲4 = 7)", cd._a_calc_lbl.text.contains("3 + 🎲4 = 7"), cd._a_calc_lbl.text)
	_ok("rolls calculated correctly (4 + 🎲3 = 7)", cd._b_calc_lbl.text.contains("4 + 🎲3 = 7"), cd._b_calc_lbl.text)

	# Resolve with tie (7 vs 7, P3 Lola is challenger)
	cd.resolve({"winnerId": "P3", "scoreA": 7, "scoreB": 7, "tie": true})
	await _frames(2)
	_ok("winner Lola highlighted on tie", "Lola" in cd._status_lbl.text and "동점 도전자" in cd._status_lbl.text, cd._status_lbl.text)

	cd.fade_out_and_free()
	await _frames(15)

	print("=== [2] GameScreen Event Replay with COMPACT AI Duel ===")
	Settings.ai_duel_mode = "COMPACT"
	var Eng = preload("res://engine/engine.gd")
	var s := Eng.create_game({"playerCount": 4, "difficulty": "NORMAL", "humanId": "P1"})
	var game := GameScreen.new()
	game.autosave_enabled = false
	host.add_child(game)
	game.begin(s)
	await _frames(5)

	# Simulate DUEL_STARTED event between P2 and P3 (neither is human)
	await game._play_event({
		"type": "DUEL_STARTED",
		"barId": "COLIBRI",
		"playerA": "P2",
		"playerB": "P3",
		"symbolA": 2,
		"symbolB": 5,
		"prize": 40000,
		"challengerId": "P3"
	})
	await _frames(2)

	_ok("COMPACT mode: dim is NOT visible", game.dim.visible == false)
	_ok("COMPACT mode: full nego modal is NOT visible", game.nego.visible == false)
	_ok("COMPACT mode: compact duel widget exists on modal_layer", game._compact_duel != null and is_instance_valid(game._compact_duel))

	# Simulate DICE_ROLLED
	await game._play_event({
		"type": "DICE_ROLLED",
		"rollA": 5,
		"rollB": 3
	})
	await _frames(2)
	_ok("compact duel received rolls", "2 + 🎲5 = 7" in game._compact_duel._a_calc_lbl.text)

	# Simulate DUEL_RESOLVED
	await game._play_event({
		"type": "DUEL_RESOLVED",
		"barId": "COLIBRI",
		"playerA": "P2",
		"playerB": "P3",
		"scoreA": 7,
		"scoreB": 8,
		"winnerId": "P3",
		"challengerId": "P3",
		"tie": false
	})
	await _frames(2)

	# Detailed reason stored in _round_reason
	var reason: String = str(game._round_reason.get("COLIBRI", ""))
	_ok("detailed duel reason stored for settlement", game._nm("P3") in reason and "8 vs 7" in reason, reason)
	_ok("compact duel widget cleaned up after resolution", game._compact_duel == null or not is_instance_valid(game._compact_duel))

	print("=== [3] GameScreen with FULL AI Duel Mode ===")
	Settings.ai_duel_mode = "FULL"
	await game._play_event({
		"type": "DUEL_STARTED",
		"barId": "HAVANA_BAR",
		"playerA": "P2",
		"playerB": "P4",
		"symbolA": 3,
		"symbolB": 4,
		"prize": 20000,
		"challengerId": "P4"
	})
	await _frames(2)
	_ok("FULL mode: dim IS visible", game.dim.visible == true)
	_ok("FULL mode: nego modal IS visible", game.nego.visible == true)

	game.nego.close()
	game.queue_free()
	await _frames(2)

	Settings.ai_duel_mode = "COMPACT"

	print("\n=== SUMMARY ===")
	print("%d checks, %d failed" % [checks, fails.size()])
	if fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%s)" % str(fails))
		quit(1)
