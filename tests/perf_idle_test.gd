extends SceneTree
## 대기 화면 전력 지표: 플레이어가 카드를 고르는 동안(게임 시간의 대부분) 초당 실제로 그린 프레임 수를 프리셋별로 잽니다.
## 실제 Steam Deck 전력(W)이 아니라, 전력에 비례하는 "그리기 횟수"를 비교하는 대리 지표입니다.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 --script res://tests/perf_idle_test.gd
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
var started := false
var draws := 0


func _process(_d: float) -> bool:
	if not started:
		started = true
		_run.call_deferred()
	return false


func _measure(secs: float) -> Dictionary:
	draws = 0
	var t0 := Time.get_ticks_msec()
	var it := 0
	var cpu_us := 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		var a := Time.get_ticks_usec()
		await process_frame
		cpu_us += Time.get_ticks_usec() - a
		it += 1
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	return {"draw_fps": draws / el, "loop_fps": it / el}


func _run() -> void:
	Settings.load_settings()
	Settings.tutorial_done = true      # the first NEW GAME would offer the tutorial (tested in qa_tutorial_test)
	Settings.load_settings()
	var saved_q: String = Settings.quality
	var saved_dl: bool = Settings.dialogue_on
	var saved_coach: bool = Settings.coach_on
	var saved_music: bool = Settings.music_on
	var saved_sfx: bool = Settings.sfx_on
	Settings.dialogue_on = false
	Settings.coach_on = false
	Settings.music_on = false
	Settings.sfx_on = false
	SaveStore.path = Settings.test_file("perf.json")
	SaveStore.clear()
	RenderingServer.frame_post_draw.connect(func(): draws += 1)
	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for b in main.current.find_children("*", "Button", true, false):
		if b.name == "NewGameButton" or "NEW GAME" in b.text or "빠른 시작" in b.text or "QUICK START" in b.text:
			b.pressed.emit()
			break
	var game = main.current
	var w := 0
	while w < 3000 and not (game.get("_awaiting_select") == true):
		w += 1
		await process_frame
	print("PERF: board waiting for a card after %d frames" % w)
	var sdm: Node = root.get_node("SteamDeckManager")
	var lines := []
	for q in ["HIGH", "BALANCED", "BATTERY"]:
		sdm.set_quality(q)
		for i in 20:
			await process_frame
		var r := await _measure(4.0)
		var line := "PERF %-9s idle board: drawn %.1f fps, main loop %.1f /s  (max_fps=%d low_processor=%s)" % [q, r["draw_fps"], r["loop_fps"], Engine.max_fps, OS.low_processor_usage_mode]
		print(line)
		lines.append(line)
	Settings.quality = saved_q
	Settings.dialogue_on = saved_dl
	Settings.coach_on = saved_coach
	Settings.music_on = saved_music
	Settings.sfx_on = saved_sfx
	Settings.save_settings()
	SaveStore.clear()
	quit(0)
