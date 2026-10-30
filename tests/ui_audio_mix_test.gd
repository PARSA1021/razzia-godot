extends SceneTree
## Adaptive mix (Phase 16): the music must step back on its own at the moments the player needs to concentrate,
## and come back afterwards. Levels are read off the real AudioStreamPlayers, so this fails if the mix stops working.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_audio_mix_test.gd
const Audio = preload("res://ui/audio.gd")
const Settings = preload("res://ui/settings.gd")

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


## let the smoothing in _process settle (the duck glides at 30-40 dB/s)
func _settle() -> void:
	await _frames(90)


## the tension bed swells slowly on purpose (14 dB/s): give it the time a player would hear
func _settle_slow() -> void:
	await _frames(330)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()            # take the saved file first: a lazy load later must not undo these values
	Settings.music_on = true
	Settings.sfx_on = true
	Settings.music_vol = 1.0
	Settings.sfx_vol = 1.0
	Settings.master_vol = 1.0
	Audio.start_music()
	await _frames(10)
	var h: Node = Audio._inst
	_ok("the music host exists", h != null)
	if h == null:
		return _finish()
	await _settle()
	var base: float = h._music.volume_db
	var amb_base: float = h._ambience.volume_db
	_ok("music plays at its base level", h._music.playing and absf(base - h._music_base()) < 0.6, "%.1f dB" % base)
	_ok("the room tone plays under it", h._ambience.playing and amb_base < base, "%.1f dB" % amb_base)
	_ok("nothing is muffled in the neutral mix", h._lp.cutoff_hz > 15000.0, "%.0f Hz" % h._lp.cutoff_hz)

	# 1) the player's own move: quieter and a little muffled, room tone steps back too
	Audio.thinking(true)
	await _settle()
	var think: float = h._music.volume_db
	_ok("thinking: the music steps back", think < base - 3.0, "%.1f -> %.1f dB" % [base, think])
	_ok("thinking: only the top end is taken off", h._lp.cutoff_hz < 6000.0 and h._lp.cutoff_hz > 2000.0, "%.0f Hz" % h._lp.cutoff_hz)
	_ok("thinking: the room tone steps back as well", h._ambience.volume_db < amb_base - 2.0, "%.1f dB" % h._ambience.volume_db)
	Audio.thinking(false)
	await _settle()
	_ok("the mix comes back after the move", absf(h._music.volume_db - base) < 0.6 and h._lp.cutoff_hz > 15000.0, "%.1f dB %.0f Hz" % [h._music.volume_db, h._lp.cutoff_hz])

	# 2) something to read (cutscene / result board): further back than thinking
	Audio.reading(true)
	await _settle()
	var read: float = h._music.volume_db
	_ok("reading: the music is further back than while thinking", read < think, "%.1f vs %.1f dB" % [read, think])
	_ok("reading: the music is muffled", h._lp.cutoff_hz < 2500.0, "%.0f Hz" % h._lp.cutoff_hz)
	Audio.reading(false)
	await _settle()
	_ok("the mix comes back after reading", absf(h._music.volume_db - base) < 0.6)

	# 3) a negotiation keeps its own duck, and the siren still wins over everything
	Audio.focus(true)
	await _settle()
	_ok("negotiation: the music is ducked and muffled", h._music.volume_db < base - 1.0 and h._lp.cutoff_hz < 2500.0)
	Audio.thinking(true)
	await _settle()
	_ok("one reason at a time: thinking does not stack on the negotiation duck", h._music.volume_db >= base + Audio.FOCUS_DUCK_DB - 0.6)
	Audio.thinking(false)
	Audio.focus(false)
	await _settle()

	# 4) final round (Phase 28): its own music cue instead of a bed under the table music; a duel still brings the bed in
	_ok("no tension bed in a normal round", not h._tension.playing or h._tension.volume_db < -50.0)
	Audio.intensity(1)
	await _settle_slow()
	_ok("final round: the final-round piece plays", Audio.current_cue() == "final" and h._music.playing and str(h._music.stream.resource_path).ends_with("final_round_loop.ogg"), str(h._music.stream.resource_path) if h._music.stream != null else "none")
	_ok("final round: no extra bed on top of its own piece", not h._tension.playing or h._tension.volume_db < -50.0)
	Audio.tension(true)
	await _settle_slow()
	var duel_bed: float = h._tension.volume_db
	_ok("a duel in the final round brings the bed in", h._tension.playing and duel_bed > -40.0, "%.1f dB" % duel_bed)
	_ok("the bed stays under the music", duel_bed < h._music.volume_db, "%.1f vs %.1f dB" % [duel_bed, h._music.volume_db])
	Audio.tension(false)
	await _settle_slow()
	_ok("after the duel the bed goes away", not h._tension.playing or h._tension.volume_db < -50.0, "%.1f dB" % h._tension.volume_db)
	Audio.intensity(0)
	await _settle_slow()
	_ok("back to the table piece", Audio.current_cue() == "table" and str(h._music.stream.resource_path).ends_with("noir_jazz_loop.ogg"))

	# 5) leaving a game clears every mood, so the menu starts neutral
	Audio.thinking(true)
	Audio.reading(true)
	Audio.reset_mood()
	await _settle_slow()
	_ok("reset: back to the neutral level", absf(h._music.volume_db - base) < 0.6, "%.1f dB" % h._music.volume_db)
	_ok("reset: nothing is muffled", h._lp.cutoff_hz > 15000.0, "%.0f Hz" % h._lp.cutoff_hz)
	_ok("reset: the tension bed is gone", not h._tension.playing or h._tension.volume_db < -50.0)

	# 6) level policy: the cues heard many times a round stay under the rare dramatic ones
	var loud_rare := ["win", "game_end", "achieve", "final_round", "duel_win", "duel_lose"]
	var quiet_common := ["click", "coin", "take", "flip", "deal"]
	var worst_rare := 99.0
	for k in loud_rare:
		worst_rare = minf(worst_rare, float(Audio.SFX[k][1]))
	var loudest_common := -99.0
	for k in quiet_common:
		loudest_common = maxf(loudest_common, float(Audio.SFX[k][1]))
	_ok("frequent cues sit below the rare dramatic ones", loudest_common < worst_rare, "%.1f vs %.1f dB" % [loudest_common, worst_rare])
	_ok("no cue is mixed above 0 dB", loudest_common <= 0.0 and worst_rare <= 0.0)
	_finish()


func _finish() -> void:
	print("AUDIO MIX TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
