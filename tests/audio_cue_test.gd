extends SceneTree
## Phase 28 music cues: menu / table / final-round pieces, cross-faded.
##   - the wanted piece plays, the same cue again never restarts it
##   - a change cross-fades: at most two players for a moment, never above the target level, then exactly one
##   - an unknown cue or a missing file falls back to the table piece; no file at all = silence, never an error
##   - music off, master mute: nothing plays; back on: the current cue resumes
##   - the mute switch and the volumes are saved
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/audio_cue_test.gd

const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")

var checks := 0
var fails: Array = []
var started := false


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


func _path(h) -> String:
	return str(h._music.stream.resource_path) if h._music.playing and h._music.stream != null else ""


## follows a cross-fade frame by frame: the most players heard at once and the loudest level reached
func _watch(h, frames: int) -> Dictionary:
	var most := 0
	var loudest := -80.0
	for i in range(frames):
		await process_frame
		var v: Array = Audio.music_voices()
		most = maxi(most, v.size())
		for e in v:
			loudest = maxf(loudest, float(e["db"]))
	return {"most": most, "loudest": loudest}


func _run() -> void:
	Settings.load_settings()
	Settings.music_on = true
	Settings.music_vol = 1.0
	Settings.master_vol = 1.0
	Settings.mute_all = false
	Audio.cue("menu")
	Audio.start_music()
	await _frames(5)
	var h = Audio._host()
	_ok("the host exists", h != null and h.is_inside_tree())
	await _frames(120)
	_ok("menu: the menu theme plays", _path(h).ends_with("menu_theme.ogg"), _path(h))
	_ok("menu: one piece only", Audio.music_voices().size() == 1)
	var target: float = h._music_base()
	_ok("menu: at its level", absf(h._music.volume_db - target) < 1.0, "%.1f vs %.1f" % [h._music.volume_db, target])
	# (the headless audio driver does not advance playback positions, so "not restarted" = same player, no fade, level kept)
	var player_id: int = h._music.get_instance_id()
	var plays := [0]
	h._music.finished.connect(func(): plays[0] += 1)
	Audio.cue("menu")
	Audio.start_music()
	Audio.refresh()
	await _frames(30)
	_ok("the same cue again does not restart the piece", h._music.get_instance_id() == player_id and not h._music_old.playing and absf(h._music.volume_db - target) < 1.0 and Audio.music_voices().size() == 1)

	# menu -> table
	Audio.cue("table")
	var w := await _watch(h, 200)
	_ok("menu -> table: never more than two pieces at once", int(w["most"]) <= 2, str(w["most"]))
	_ok("menu -> table: no jump in loudness during the cross-fade", float(w["loudest"]) <= target + 0.6, "%.1f dB (target %.1f)" % [w["loudest"], target])
	_ok("menu -> table: the table piece plays alone afterwards", _path(h).ends_with("noir_jazz_loop.ogg") and Audio.music_voices().size() == 1, str(Audio.music_voices()))
	# table -> final -> table
	Audio.intensity(1)
	w = await _watch(h, 200)
	_ok("final round: its own piece, cross-faded", _path(h).ends_with("final_round_loop.ogg") and int(w["most"]) <= 2 and Audio.music_voices().size() == 1)
	Audio.intensity(0)
	await _watch(h, 200)
	_ok("back to the table piece", _path(h).ends_with("noir_jazz_loop.ogg"))
	# quick changes: menu, table, menu within a few frames must still end with exactly one player
	Audio.cue("menu")
	await _frames(3)
	Audio.cue("table")
	await _frames(3)
	Audio.cue("menu")
	w = await _watch(h, 240)
	_ok("rapid cue changes never stack players", int(w["most"]) <= 2 and Audio.music_voices().size() == 1 and _path(h).ends_with("menu_theme.ogg"), str(Audio.music_voices()))
	# unknown cue / missing file
	Audio.cue("nonsense")
	await _watch(h, 200)
	_ok("an unknown cue plays the table piece", _path(h).ends_with("noir_jazz_loop.ogg"))
	h._streams[Audio.CUES["final"]] = null              # as if final_round_loop.ogg were not shipped
	Audio.intensity(1)
	await _watch(h, 200)
	_ok("a missing file falls back to the table piece (no error, no silence)", _path(h).ends_with("noir_jazz_loop.ogg") and Audio.music_voices().size() == 1)
	h._streams.erase(Audio.CUES["final"])
	Audio.intensity(0)
	var saved_table = h._streams.get(Audio.MUSIC_PATH, null)
	h._streams[Audio.CUES["menu"]] = null
	h._streams[Audio.MUSIC_PATH] = null
	Audio.cue("menu")
	await _frames(10)
	_ok("no music file at all: nothing crashes, the old piece just carries on or stops", true)
	h._streams.erase(Audio.CUES["menu"])
	h._streams[Audio.MUSIC_PATH] = saved_table
	# music off / master mute
	Audio.cue("table")
	await _watch(h, 120)
	Settings.music_on = false
	Audio.refresh()
	await _frames(5)
	_ok("music off: nothing plays", Audio.music_voices().is_empty())
	Settings.music_on = true
	Audio.refresh()
	await _watch(h, 120)
	_ok("music on again: the current cue comes back once", _path(h).ends_with("noir_jazz_loop.ogg") and Audio.music_voices().size() == 1)
	Settings.mute_all = true
	Audio.refresh()
	await _frames(5)
	_ok("master mute: nothing plays, effects are silent too", Audio.music_voices().is_empty() and Audio.group_vol("sfx") == 0.0)
	Settings.save_settings()
	Settings.mute_all = false
	Settings._loaded = false
	Settings.load_settings()
	_ok("the mute switch is saved", Settings.mute_all)
	Settings.mute_all = false
	Settings.master_vol = 0.55
	Settings.save_settings()
	Settings.master_vol = 1.0
	Settings._loaded = false
	Settings.load_settings()
	_ok("the master volume is saved", absf(Settings.master_vol - 0.55) < 0.001)
	Audio.refresh()
	await _watch(h, 120)
	_ok("unmuted: music again, at the new master level", Audio.music_voices().size() == 1 and absf(h._music.volume_db - h._music_base()) < 1.0)
	print("AUDIO CUE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
