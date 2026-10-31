extends SceneTree
## Benchmark AI duel round duration: COMPACT vs FULL mode
## godot --headless --path . --fixed-fps 60 --script res://tests/benchmark_ai_duel_speed.gd

const GameScreen = preload("res://ui/game_screen.gd")
const Settings = preload("res://ui/settings.gd")
const Eng = preload("res://engine/engine.gd")

var started := false

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
	Settings.speed_name = "NORMAL"

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_ctrl)

	print("=== BENCHMARK: AI DUEL REPLAY SPEED (NORMAL ANIMATION SPEED) ===")

	var duel_events := [
		{
			"type": "DUEL_STARTED",
			"barId": "COLIBRI",
			"playerA": "P2",
			"playerB": "P3",
			"symbolA": 3,
			"symbolB": 4,
			"prize": 30000,
			"challengerId": "P3"
		},
		{
			"type": "DICE_ROLLED",
			"rollA": 4,
			"rollB": 3
		},
		{
			"type": "DUEL_RESOLVED",
			"barId": "COLIBRI",
			"playerA": "P2",
			"playerB": "P3",
			"rollA": 4,
			"rollB": 3,
			"scoreA": 7,
			"scoreB": 7,
			"tie": true,
			"winnerId": "P3",
			"challengerId": "P3"
		}
	]

	# Test 1: FULL mode (old behavior)
	Settings.ai_duel_mode = "FULL"
	var s1 := Eng.create_game({"playerCount": 4, "difficulty": "NORMAL", "humanId": "P1"})
	var game1 := GameScreen.new()
	game1.autosave_enabled = false
	root_ctrl.add_child(game1)
	game1.begin(s1)
	for i in range(10): await process_frame

	var t0 := Time.get_ticks_msec()
	for ev in duel_events:
		await game1._play_event(ev)
	var full_dur_ms := Time.get_ticks_msec() - t0
	game1.queue_free()
	for i in range(5): await process_frame

	# Test 2: COMPACT mode (new behavior)
	Settings.ai_duel_mode = "COMPACT"
	var s2 := Eng.create_game({"playerCount": 4, "difficulty": "NORMAL", "humanId": "P1"})
	var game2 := GameScreen.new()
	game2.autosave_enabled = false
	root_ctrl.add_child(game2)
	game2.begin(s2)
	for i in range(10): await process_frame

	var t1 := Time.get_ticks_msec()
	for ev in duel_events:
		await game2._play_event(ev)
	var compact_dur_ms := Time.get_ticks_msec() - t1
	game2.queue_free()

	print("--------------------------------------------------")
	print("FULL (이전 전체 화면 모달) 결투 소요 시간: %.2f초 (%d ms)" % [full_dur_ms / 1000.0, full_dur_ms])
	print("COMPACT (신규 술집 위 축약) 결투 소요 시간: %.2f초 (%d ms)" % [compact_dur_ms / 1000.0, compact_dur_ms])
	var diff_s := (full_dur_ms - compact_dur_ms) / 1000.0
	var speedup := float(full_dur_ms) / float(compact_dur_ms) if compact_dur_ms > 0 else 1.0
	print("결투당 절약 시간: %.2f초 단축 (%.1f배 속도 향상, 화면 가림 0)" % [diff_s, speedup])
	print("--------------------------------------------------")
	quit(0)
