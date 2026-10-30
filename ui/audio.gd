extends Node
## Sound (Phase 9A–11). Presentation only — nothing here touches the engine, the controller or the events.
## Static entry points (`Audio.play("click")`, `Audio.start_music()`, ...) lazily add a single host node under the SceneTree root, so the
## music keeps playing across menu <-> game. Every call is a harmless no-op when the host / a stream is not available (tests, missing import).
##
## Phase 11 mix design (immersion without fatigue):
##  - Four volume groups: master, music, effects, interface (clicks / sliders / panels); each has its own slider in Settings.
##  - Music sits low under the effects; a quiet room-tone ambience runs with it. Stingers (round end, win, ...) and the siren duck the music.
##  - While a negotiation / duel is open the music is "focused": low-passed (muffled) and a slow tension layer fades in.
##  - Repeated cues get a little pitch / volume variation (coins, ticks, clicks) so they never sound machine-gunned.
##  - A limiter on the master bus stops stacked sounds from clipping; the window losing focus silences the game.

const Settings = preload("res://ui/settings.gd")
const MUSIC_PATH := "res://assets/audio/noir_jazz_loop.ogg"
## Music cues (Phase 28). One piece per situation, all in D minor so a cross-fade never jumps key. A cue whose file is
## missing falls back to the table music (and to silence if that is missing too): music can never stop the game.
const CUES := {
	"menu": "res://assets/audio/menu_theme.ogg",           # title screen: slow, spacious
	"table": "res://assets/audio/noir_jazz_loop.ogg",      # a normal round
	"final": "res://assets/audio/final_round_loop.ogg",    # the last round: faster, tighter
}
const XFADE_IN_DB_S := 30.0          # the new cue comes up at this rate (dB / s) ...
const XFADE_OUT_DB_S := 22.0         # ... while the old one goes down a little slower: a short overlap, never a gap
const TENSION_PATH := "res://assets/audio/tension_loop.ogg"
const AMBIENCE_PATH := "res://assets/audio/ambience_loop.ogg"
const MUSIC_DB := -14.0
const AMBIENCE_DB := -36.0
const TENSION_DB := -19.0
const FOCUS_CUT_HZ := 1500.0           # music low-pass while a negotiation / duel is open
const THINK_CUT_HZ := 3200.0           # gentler muffle while the player is deciding
const FOCUS_DUCK_DB := -3.0
const SIREN_DUCK_DB := -12.0
const STINGER_DUCK_DB := -7.0
const READ_DUCK_DB := -8.0             # a cutscene / result board is on screen: let the text be read
const THINK_DUCK_DB := -5.0            # the player's own move: the room goes quiet around them
const AMBIENCE_THINK_DB := -4.0        # the room tone steps back with the music while deciding
## name -> [path, volume dB, minimum gap in seconds, group ("sfx" | "ui"), pitch variation (+-fraction)]
## Level policy (Phase 16): cues the player hears many times a round sit low (clicks, cards, coins); the rare dramatic ones
## (duel, raid, round / game end, achievement) keep their weight. That headroom is what makes a long session restful.
const SFX := {
	"click": ["res://assets/audio/click.mp3", -8.0, 0.03, "ui", 0.03],
	"hover": ["res://assets/audio/hover.ogg", -11.0, 0.05, "ui", 0.05],
	"tick": ["res://assets/audio/tick.ogg", -8.0, 0.03, "ui", 0.06],
	"toggle_on": ["res://assets/audio/toggle_on.ogg", -6.0, 0.1, "ui", 0.0],
	"toggle_off": ["res://assets/audio/toggle_off.ogg", -6.0, 0.1, "ui", 0.0],
	"panel_open": ["res://assets/audio/panel_open.ogg", -6.0, 0.15, "ui", 0.02],
	"panel_close": ["res://assets/audio/panel_close.ogg", -7.0, 0.15, "ui", 0.02],
	"page": ["res://assets/audio/page.ogg", -6.0, 0.1, "ui", 0.05],
	"confirm": ["res://assets/audio/confirm.ogg", -5.0, 0.2, "ui", 0.0],
	"denied": ["res://assets/audio/denied.ogg", -6.0, 0.3, "ui", 0.0],
	"stage": ["res://assets/audio/stage.ogg", -8.0, 0.2, "ui", 0.0],
	"pick": ["res://assets/audio/pick.ogg", -3.0, 0.05, "sfx", 0.04],
	"take": ["res://assets/audio/taking_card.mp3", -4.0, 0.07, "sfx", 0.03],
	"flip": ["res://assets/audio/flip.ogg", -6.0, 0.06, "sfx", 0.05],
	"deal": ["res://assets/audio/deal.ogg", -7.0, 0.4, "sfx", 0.0],
	"shuffle": ["res://assets/audio/shuffle.ogg", -5.0, 0.5, "sfx", 0.0],
	"dice": ["res://assets/audio/rolling_dice.mp3", -2.0, 0.25, "sfx", 0.0],
	"drumroll": ["res://assets/audio/drumroll.ogg", -6.0, 0.5, "sfx", 0.0],
	"ching": ["res://assets/audio/cashier_ching.mp3", -3.0, 0.25, "sfx", 0.0],
	"cash_big": ["res://assets/audio/cash_big.ogg", -3.0, 0.5, "sfx", 0.0],
	"coin": ["res://assets/audio/coin.ogg", -10.0, 0.12, "sfx", 0.04],
	"coin2": ["res://assets/audio/coin2.ogg", -10.0, 0.12, "sfx", 0.04],
	"coin3": ["res://assets/audio/coin3.ogg", -10.0, 0.12, "sfx", 0.04],
	"coin4": ["res://assets/audio/coin4.ogg", -10.0, 0.12, "sfx", 0.04],
	"nego_open": ["res://assets/audio/nego_open.ogg", -6.0, 0.4, "sfx", 0.0],
	"offer": ["res://assets/audio/offer.ogg", -4.0, 0.2, "sfx", 0.0],
	"accept": ["res://assets/audio/accept.ogg", -3.0, 0.2, "sfx", 0.0],
	"duel": ["res://assets/audio/duel.ogg", -3.0, 0.2, "sfx", 0.0],
	"duel_win": ["res://assets/audio/duel_win.ogg", -3.0, 0.3, "sfx", 0.0],
	"duel_lose": ["res://assets/audio/duel_lose.ogg", -3.0, 0.3, "sfx", 0.0],
	"tie": ["res://assets/audio/tie.ogg", -5.0, 0.3, "sfx", 0.0],
	"your_turn": ["res://assets/audio/your_turn.ogg", -6.0, 0.5, "sfx", 0.0],
	"stamp": ["res://assets/audio/stamp.ogg", -2.0, 0.3, "sfx", 0.0],
	"final_round": ["res://assets/audio/final_round.ogg", -3.0, 1.0, "sfx", 0.0],
	"round_end": ["res://assets/audio/round_end.ogg", -4.0, 0.5, "sfx", 0.0],
	"game_start": ["res://assets/audio/game_start.ogg", -3.0, 1.0, "sfx", 0.0],
	"game_end": ["res://assets/audio/game_end.ogg", -2.0, 1.0, "sfx", 0.0],
	"win": ["res://assets/audio/win.ogg", -2.0, 1.0, "sfx", 0.0],
	"achieve": ["res://assets/audio/achieve.ogg", -3.0, 1.0, "sfx", 0.0],
	"card_snap": ["res://assets/audio/card_snap.wav", -6.0, 0.05, "sfx", 0.04],
	"chip_clink": ["res://assets/audio/chip_clink.wav", -8.0, 0.08, "sfx", 0.05],
	"dice_cup": ["res://assets/audio/dice_cup.wav", -5.0, 0.2, "sfx", 0.03],
	"gavel": ["res://assets/audio/gavel.wav", -4.0, 0.25, "sfx", 0.02],
	"police_whistle": ["res://assets/audio/police_whistle.wav", -3.0, 0.5, "sfx", 0.0],
	"tutorial_bell": ["res://assets/audio/tutorial_bell.wav", -6.0, 0.3, "ui", 0.0],
	"relic_chime": ["res://assets/audio/relic_chime.wav", -4.0, 0.5, "sfx", 0.0],
}
## `play("coin")` picks one of these at random (never the same one twice in a row)
const VARIANTS := {"coin": ["coin", "coin2", "coin3", "coin4"]}
## these duck the music for a moment so they are heard in full
const STINGERS := ["achieve", "round_end", "game_end", "win", "duel_win", "duel_lose", "final_round", "game_start", "cash_big", "tie", "police_whistle", "relic_chime"]
## Cues that were more distracting than useful (constant UI chatter) are switched off here; the SFX table stays so they can be re-enabled by deleting an entry.
const MUTED := ["hover", "tick", "toggle_on", "toggle_off", "panel_open", "panel_close", "page", "stage", "drumroll", "your_turn", "pick", "nego_open", "game_start", "cash_big"]
const SIREN_PATH := "res://assets/audio/police_siren.mp3"
const SIREN_DB := -3.0
const POOL := 10

static var _inst: Node = null

var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _music_old: AudioStreamPlayer   # the cue that is fading out (cross-fade partner of _music)
var _cue := "table"
var _cue_path := ""                # the file _music is playing now
var _ambience: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _streams := {}
var _last := {}
var _last_variant := {}
var _want_music := false
var _ducked := false               # the siren is on
var _focus := false                # negotiation / duel open
var _thinking := false             # the player has a decision in front of them (card, bar, offer)
var _reading := false              # a cutscene / round-result / game-over board is on screen
var _intensity := 0                # 0 normal, 1 final round (its own music cue, see CUES)
var _tension_on := false
var _stinger_left := 0.0
var _duck_db := 0.0                # current (smoothed) duck offset applied on top of the base music level
var _music_target := MUSIC_DB      # volume changes run in _process (no Tween objects: they would show up as running UI tweens)
var _siren_fade := 0.0              # dB per second while the siren fades out (0 = not fading)
var _lp: AudioEffectLowPassFilter
var _rng := RandomNumberGenerator.new()


static func _host() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	_inst = (load("res://ui/audio.gd") as GDScript).new()
	_inst.name = "Audio"
	(loop as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


## linear 0..1 -> dB (0 = silent)
static func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


## Volume group of an effect ("ui" or "sfx") as a linear 0..1 value (master included).
static func group_vol(group: String) -> float:
	return Settings.master_eff() * (Settings.ui_vol if group == "ui" else Settings.sfx_vol)


static func play(sfx_name: String) -> void:
	if sfx_name in MUTED:
		return
	Settings.load_settings()
	if VARIANTS.has(sfx_name):
		var h0 := _host()
		if h0 == null:
			return
		sfx_name = h0._pick_variant(sfx_name)
	var group: String = SFX[sfx_name][3] if SFX.has(sfx_name) else "sfx"
	if not Settings.sfx_on or group_vol(group) <= 0.001:
		return
	var h := _host()
	if h != null:
		h._play(sfx_name)


static var _last_barks := {}


## Plays a character voice bark if available (e.g. res://assets/audio/barks/<character>_<situation>.ogg or .mp3).
## Safely and cleanly no-ops if no bark file exists (no console warnings, no crashes).
static func bark(char_name: String, situation: String) -> void:
	if char_name.is_empty():
		return
	Settings.load_settings()
	if not Settings.sfx_on or group_vol("sfx") <= 0.001:
		return
	var key := "%s_%s" % [char_name, situation]
	var now := Time.get_ticks_msec()
	if _last_barks.has(key) and (now - int(_last_barks[key])) < 2200:
		return
	_last_barks[key] = now
	var stem := "res://assets/audio/barks/%s_%s" % [char_name.to_lower(), situation]
	var path := ""
	for ext in [".ogg", ".mp3", ".wav"]:
		if ResourceLoader.exists(stem + ext):
			path = stem + ext
			break
	if path != "":
		var h := _host()
		if h != null:
			h._play_stream_file(path, "sfx")


static func start_music() -> void:
	Settings.load_settings()
	var h := _host()
	if h != null:
		h._want_music = true
		h._apply_music()



## Which piece should play: "menu" | "table" | "final". The same cue again does nothing (no restart); a new one
## cross-fades. Safe to call before the host exists and with any sound settings.
static func cue(name: String) -> void:
	var h := _host()
	if h != null:
		h._cue = name if CUES.has(name) else "table"
		h._apply_music()


## the cue being played (tests)
static func current_cue() -> String:
	return _inst._cue if _inst != null and is_instance_valid(_inst) else ""


## how many music players are sounding right now (tests: never two pieces at full level, never a duplicate)
static func music_voices() -> Array:
	var out: Array = []
	if _inst != null and is_instance_valid(_inst):
		for pl in [_inst._music, _inst._music_old]:
			if pl.playing:
				out.append({"path": pl.stream.resource_path if pl.stream != null else "", "db": pl.volume_db})
	return out


## Called after any sound setting changed.
static func refresh() -> void:
	var h := _host()
	if h != null:
		h._apply_music()


## Negotiation / duel open (true) or closed (false): the music gets muffled and a little quieter.
static func focus(on: bool) -> void:
	var h := _host()
	if h != null:
		h._focus = on
		if not on:
			h._tension_on = false


## Slow tension layer under the music (the duel, the raid).
static func tension(on: bool) -> void:
	var h := _host()
	if h != null:
		h._tension_on = on
		h._apply_music()


## The player has a decision in front of them (pick a card, place the money card). The music and the room tone step back
## and lose their top end, so the table is quiet while they think. Purely a mix change: nothing is muted, nothing waits.
static func thinking(on: bool) -> void:
	var h := _host()
	if h != null:
		h._thinking = on


## Something on screen has to be read (a cutscene, the round result, the game-over board): the music drops further.
static func reading(on: bool) -> void:
	var h := _host()
	if h != null:
		h._reading = on


## 0 = normal, 1 = final round: a quiet tension bed joins the music until the game ends.
static func intensity(level: int) -> void:
	var h := _host()
	if h != null:
		h._intensity = level
		h._cue = "final" if level > 0 else "table"       # the last round has its own piece (Phase 28)
		h._apply_music()


## Back to the neutral mix (leaving a game for the menu).
static func reset_mood() -> void:
	var h := _host()
	if h != null:
		h._thinking = false
		h._reading = false
		h._focus = false
		h._tension_on = false
		h._intensity = 0
		h._apply_music()


static func siren_start() -> void:
	Settings.load_settings()
	if not Settings.sfx_on or group_vol("sfx") <= 0.001:
		return
	var h := _host()
	if h != null:
		h._siren_start()


static func siren_stop(fade: float = 0.3) -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst._siren_stop(fade)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_buses()
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = _loop_player("Music", MUSIC_DB)
	_music_old = _loop_player("Music", -60.0)
	_ambience = _loop_player("Music", AMBIENCE_DB)
	_tension = _loop_player("Music", -60.0)
	_siren = AudioStreamPlayer.new()
	_siren.bus = "SFX"
	_siren.volume_db = SIREN_DB
	add_child(_siren)


func _loop_player(bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


## Music / SFX buses feeding Master; low-pass on Music (focus), limiter on Master (no clipping when sounds stack).
func _setup_buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(mi, _lp)
	var ma := AudioServer.get_bus_index("Master")
	if ma >= 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		lim.threshold_db = -6.0
		AudioServer.add_bus_effect(ma, lim)


## Optional UI feedback for the mute key: the game screen sets this to show its toast.
static var mute_feedback: Callable = Callable()


func _ready() -> void:
	_apply_music()


## M = mute / unmute everything. It lives here because this node runs even while the tree is paused, so the key still
## works with the pause panel open - which is exactly where a player goes looking for the sound settings.
func _input(event: InputEvent) -> void:
	var hit := false
	if InputMap.has_action("toggle_mute"):
		hit = event.is_action_pressed("toggle_mute") and not (event is InputEventKey and event.echo)
	else:
		hit = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M
	if not hit:
		return
	Settings.mute_all = not Settings.mute_all          # one switch for everything; the music / effects choices are kept
	var on: bool = not Settings.mute_all
	Settings.save_settings()
	refresh()
	if mute_feedback.is_valid():
		mute_feedback.call(on)
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Settings.focus_mute:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


func _pick_variant(base: String) -> String:
	var list: Array = VARIANTS[base]
	var pick: String = list[_rng.randi() % list.size()]
	if pick == _last_variant.get(base, "") and list.size() > 1:
		pick = list[(list.find(pick) + 1) % list.size()]
	_last_variant[base] = pick
	return pick


func _play(sfx_name: String) -> void:
	if not is_inside_tree() or not SFX.has(sfx_name):
		return
	var spec: Array = SFX[sfx_name]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sfx_name, -10.0)) < float(spec[2]):
		return
	_last[sfx_name] = now
	var st := _stream(spec[0])
	if st == null:
		return
	var p: AudioStreamPlayer
	if sfx_name == "ching" or sfx_name == "dice":
		p = _pool[0] if sfx_name == "ching" else _pool[1]       # long tails: a new one replaces the old one instead of piling up
	else:
		_next = 2 + (_next + 1) % (POOL - 2)
		p = _pool[_next]
	p.stream = st
	var jit: float = float(spec[4])
	p.pitch_scale = 1.0 + _rng.randf_range(-jit, jit) if jit > 0.0 else 1.0
	p.volume_db = float(spec[1]) + _db(group_vol(spec[3]))
	p.play()
	if STINGERS.has(sfx_name):
		_stinger_left = maxf(_stinger_left, 1.4)


func _play_stream_file(path: String, group: String) -> void:
	if not is_inside_tree():
		return
	var st := _stream(path)
	if st == null:
		return
	_next = 2 + (_next + 1) % (POOL - 2)
	var p: AudioStreamPlayer = _pool[_next]
	p.stream = st
	p.pitch_scale = 1.0
	p.volume_db = -3.0 + _db(group_vol(group))
	p.play()



## Base music level from the settings (without ducking).
func _music_base() -> float:
	return MUSIC_DB + _db(Settings.music_vol) + _db(Settings.master_eff())


func _apply_music() -> void:
	if not is_inside_tree():
		return
	_music_target = _music_base()
	var audible: bool = _want_music and Settings.music_on and Settings.music_vol > 0.001 and Settings.master_eff() > 0.001
	if audible:
		_play_cue()
		if _cue != "menu":
			_start_loop(_ambience, AMBIENCE_PATH, false)
		else:
			if _ambience.playing:
				_ambience.stop()
		if _tension_on:
			_start_loop(_tension, TENSION_PATH, false)
	else:
		for pl in [_music, _music_old, _ambience, _tension]:
			if pl.playing:
				pl.stop()
		_cue_path = ""


## The file for the wanted cue (falling back to the table music), started or cross-faded to.
func _play_cue() -> void:
	var want: String = CUES.get(_cue, MUSIC_PATH)
	if _stream(want) == null:
		want = MUSIC_PATH
	if _stream(want) == null:
		return                                   # no music file at all: stay silent, the game goes on
	if want == _cue_path and _music.playing:
		return                                   # the same piece keeps playing: never restart it
	if _music.playing:
		# swap the players: the old piece fades out from where it is, the new one starts low and comes up
		var tmp := _music_old
		_music_old = _music
		_music = tmp
		if _music.playing:
			_music.stop()
	_music.stream = null
	_cue_path = want
	_start_loop(_music, want, true)


func _start_loop(pl: AudioStreamPlayer, path: String, fade_in: bool) -> void:
	if pl.stream == null:
		var st := _stream(path)
		if st == null:
			return
		if "loop" in st:
			st.loop = true
		pl.stream = st
	if not pl.playing:
		if fade_in:
			pl.volume_db = -45.0               # fades up in _process
		pl.play()


func _process(d: float) -> void:
	# smoothed duck offset: siren > stinger > reading > focus > thinking (one state at a time, loudest reason wins)
	var want_duck := 0.0
	if _ducked:
		want_duck = SIREN_DUCK_DB
	elif _stinger_left > 0.0:
		want_duck = STINGER_DUCK_DB
	elif _reading:
		want_duck = READ_DUCK_DB
	elif _focus:
		want_duck = FOCUS_DUCK_DB
	elif _thinking:
		want_duck = THINK_DUCK_DB
	_stinger_left = maxf(0.0, _stinger_left - d)
	_duck_db = move_toward(_duck_db, want_duck, 30.0 * d)
	_music_target = _music_base() + _duck_db
	if _music.playing and not is_equal_approx(_music.volume_db, _music_target):
		_music.volume_db = move_toward(_music.volume_db, _music_target, (XFADE_IN_DB_S if _music_old.playing else 40.0) * d)
	if _music_old.playing:
		_music_old.volume_db = move_toward(_music_old.volume_db, -60.0, XFADE_OUT_DB_S * d)
		if _music_old.volume_db <= -59.0:
			_music_old.stop()
			_music_old.stream = null
	# ambience follows the music level; tension layer fades in / out
	if _ambience.playing:
		var amb := AMBIENCE_DB + _db(Settings.music_vol) + _db(Settings.master_eff())
		if _thinking or _reading:
			amb += AMBIENCE_THINK_DB
		_ambience.volume_db = move_toward(_ambience.volume_db, amb, 40.0 * d)
	if _tension.playing:
		var tt := -60.0
		if _tension_on:
			tt = TENSION_DB + _db(Settings.music_vol) + _db(Settings.master_eff())
		_tension.volume_db = move_toward(_tension.volume_db, tt, 14.0 * d)
		if not _tension_on and _tension.volume_db <= -58.0:
			_tension.stop()
	# muffle the music while a negotiation / duel is open, lightly while the player decides (the cutoff glides: never a click)
	if _lp != null:
		var cut := 20000.0
		if _focus or _ducked or _reading:
			cut = FOCUS_CUT_HZ
		elif _thinking:
			cut = THINK_CUT_HZ
		_lp.cutoff_hz = clampf(exp(move_toward(log(_lp.cutoff_hz), log(cut), 5.0 * d)), FOCUS_CUT_HZ, 20000.0)
	if _siren_fade > 0.0 and _siren.playing:
		_siren.volume_db -= _siren_fade * d
		if _siren.volume_db <= -40.0:
			_siren.stop()
			_siren_fade = 0.0


func _siren_start() -> void:
	if not is_inside_tree():
		return
	var st := _stream(SIREN_PATH)
	if st == null:
		return
	_siren_fade = 0.0
	_siren.stream = st
	_siren.volume_db = SIREN_DB + _db(group_vol("sfx"))
	_siren.play()
	_ducked = true


func _siren_stop(fade: float) -> void:
	if not is_inside_tree():
		return
	if _siren.playing:
		if fade <= 0.0:
			_siren.stop()
			_siren_fade = 0.0
		else:
			_siren_fade = (SIREN_DB + _db(group_vol("sfx")) + 40.0) / fade
	_ducked = false
