extends RefCounted
## User settings (docs/05 §18): animation speed, reduced motion, music / sound effects on-off. Saved to user://settings.cfg.

const I18n = preload("res://ui/i18n.gd")
const PATH := "user://settings.cfg"
## A test or tool run (godot --script res://tests/... or res://tools/...) never touches the player's files: it gets its own
## settings / autosave / records files for that process, starting from the defaults, removed again when it exits.
static var _test_run := -1                # must be declared before `path`: static initialisers run in order
static var path := test_file("settings.cfg")


static func is_test_run() -> bool:
	if _test_run < 0:
		_test_run = 0
		if OS.get_environment("RAZZIA_TEST") == "1":
			_test_run = 1
		var args := OS.get_cmdline_args()
		for i in range(args.size()):
			var a: String = args[i]
			if a.begins_with("res://tests/") or a.begins_with("res://tools/") or a.begins_with("tests/") or a.begins_with("tools/"):
				_test_run = 1
	return _test_run == 1


## "user://<name>" for the game; "user://test_<pid>_<name>" for a test / tool process
static func test_file(name: String) -> String:
	return ("user://test_%s_%s" % [_test_tag(), name]) if is_test_run() else "user://" + name


## the process id; a restart test (RAZZIA_TEST_TAG=...) gives two processes the same files on purpose
static func _test_tag() -> String:
	var tag := OS.get_environment("RAZZIA_TEST_TAG")
	return tag if tag != "" else str(OS.get_process_id())


## removes this process's own test files (called by the platform autoload when the process exits)
static func cleanup_test_files() -> void:
	if not is_test_run():
		return
	var d := DirAccess.open("user://")
	if d == null:
		return
	if OS.get_environment("RAZZIA_TEST_KEEP") == "1":
		return                    # the first half of a restart test: the second process reads these files
	var prefix := "test_%s_" % _test_tag()
	for f in d.get_files():
		if f.begins_with(prefix):
			d.remove(f)
const SPEEDS := {"SLOW": 1.6, "NORMAL": 1.0, "FAST": 0.5}

static var speed_name := "NORMAL"
static var reduce_motion := false
static var music_on := true
static var sfx_on := true
static var music_vol := 1.0       # 0..1, 1.0 = the loudness the sounds were mixed at
static var sfx_vol := 1.0
static var master_vol := 1.0
static var mute_all := false        # everything silent (M key / the master switch); the volumes themselves are kept
static var ui_vol := 0.8           # button clicks, sliders, panels
static var dialogue_on := true     # short character dialogue scenes at key moments (Phase 14)
static var coach_on := true        # first-game hints at the moments they are needed (Phase 19); off after one finished game
static var focus_mute := true      # silence everything while the window is in the background
## 화면·성능 (Steam Deck 대응). "" = 자동: SteamDeckManager가 실행 환경을 보고 고릅니다.
static var dialogue_mid := true    # mid-game scenes (big duel, raid, lead change); false = "핵심만": opening, last round, end
static var tutorial_done := false   # Sal's tutorial finished or skipped once (the first NEW GAME stops offering it)
static var display_mode := ""      # "" 자동 | "fullscreen" | "windowed"
static var quality := ""           # "" 자동 | "HIGH" | "BALANCED" | "BATTERY"
static var language := "ko"         # "ko" | "en" (ui/i18n.gd). A new player gets the system language; a test run is always "ko"
static var player_name := ""        # the human player's name; "" = the default ("나" / "You"), see display_name()
static var quality_effective := "HIGH"   # 실제로 적용된 프리셋 (저장하지 않음, 매니저가 채움)
static var last_player_count := 4
static var last_difficulty := "NORMAL"
static var last_game_mode := "CLASSIC"
static var beginner_hints := false  # 초보자 힌트: 승률·기대값·추천 버튼 노출 여부 (기본값: false)
static var screen_shake := true     # 화면 흔들림 효과 (false = 흔들림 0)
static var ai_duel_mode := "COMPACT" # "COMPACT" (축약) | "FULL" (크게 보기)
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	var found := cf.load(path) == OK
	# who never chose a language: an existing player (settings from before languages existed) keeps Korean, a new one
	# gets the system language; tests always run in Korean (their expected texts are Korean)
	language = "ko" if (found or is_test_run()) else I18n.system_default()
	if found:
		language = str(cf.get_value("general", "language", "ko"))
		player_name = clean_name(str(cf.get_value("general", "player_name", "")))
		speed_name = str(cf.get_value("anim", "speed", "NORMAL"))
		if not SPEEDS.has(speed_name):
			speed_name = "NORMAL"
		reduce_motion = bool(cf.get_value("anim", "reduce_motion", false))
		music_on = bool(cf.get_value("audio", "music", true))
		sfx_on = bool(cf.get_value("audio", "sfx", true))
		music_vol = clampf(float(cf.get_value("audio", "music_vol", 1.0)), 0.0, 1.0)
		sfx_vol = clampf(float(cf.get_value("audio", "sfx_vol", 1.0)), 0.0, 1.0)
		master_vol = clampf(float(cf.get_value("audio", "master_vol", 1.0)), 0.0, 1.0)
		mute_all = bool(cf.get_value("audio", "mute_all", false))
		ui_vol = clampf(float(cf.get_value("audio", "ui_vol", 0.8)), 0.0, 1.0)
		focus_mute = bool(cf.get_value("audio", "focus_mute", true))
		dialogue_on = bool(cf.get_value("anim", "dialogue", true))
		coach_on = bool(cf.get_value("anim", "coach", true))
		tutorial_done = bool(cf.get_value("anim", "tutorial_done", false))
		dialogue_mid = bool(cf.get_value("anim", "dialogue_mid", true))
		display_mode = str(cf.get_value("display", "mode", ""))
		if not display_mode in ["", "fullscreen", "windowed"]:
			display_mode = ""
		quality = str(cf.get_value("display", "quality", ""))
		if not quality in ["", "HIGH", "BALANCED", "BATTERY"]:
			quality = ""
		last_player_count = clampi(int(cf.get_value("general", "last_player_count", 4)), 3, 8)
		last_difficulty = str(cf.get_value("general", "last_difficulty", "NORMAL"))
		if not last_difficulty in ["EASY", "NORMAL", "HARD"]:
			last_difficulty = "NORMAL"
		last_game_mode = str(cf.get_value("general", "last_game_mode", "CLASSIC"))
		if not last_game_mode in ["CLASSIC", "RELIC"]:
			last_game_mode = "CLASSIC"
		beginner_hints = bool(cf.get_value("general", "beginner_hints", false))
		screen_shake = bool(cf.get_value("display", "screen_shake", true))
		ai_duel_mode = str(cf.get_value("anim", "ai_duel_mode", "COMPACT"))
		if not ai_duel_mode in ["COMPACT", "FULL"]:
			ai_duel_mode = "COMPACT"
	I18n.apply(language)


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("general", "language", language)
	cf.set_value("general", "player_name", player_name)
	cf.set_value("general", "last_player_count", last_player_count)
	cf.set_value("general", "last_difficulty", last_difficulty)
	cf.set_value("general", "last_game_mode", last_game_mode)
	cf.set_value("general", "beginner_hints", beginner_hints)
	cf.set_value("anim", "speed", speed_name)
	cf.set_value("anim", "reduce_motion", reduce_motion)
	cf.set_value("audio", "music", music_on)
	cf.set_value("audio", "sfx", sfx_on)
	cf.set_value("audio", "music_vol", music_vol)
	cf.set_value("audio", "sfx_vol", sfx_vol)
	cf.set_value("audio", "master_vol", master_vol)
	cf.set_value("audio", "mute_all", mute_all)
	cf.set_value("audio", "ui_vol", ui_vol)
	cf.set_value("audio", "focus_mute", focus_mute)
	cf.set_value("anim", "dialogue", dialogue_on)
	cf.set_value("anim", "coach", coach_on)
	cf.set_value("anim", "tutorial_done", tutorial_done)
	cf.set_value("anim", "dialogue_mid", dialogue_mid)
	cf.set_value("anim", "ai_duel_mode", ai_duel_mode)
	cf.set_value("display", "mode", display_mode)
	cf.set_value("display", "quality", quality)
	cf.set_value("display", "screen_shake", screen_shake)
	cf.save(path)


## Scales a duration (seconds) by the chosen speed; reduced motion collapses animations to nothing.
## the master level that is actually applied: 0 while everything is muted
static func master_eff() -> float:
	return 0.0 if mute_all else master_vol


static func dur(sec: float) -> float:
	if reduce_motion:
		return 0.0
	return sec * float(SPEEDS.get(speed_name, 1.0))


## Mix presets for the sound panels: [label, music, effects, interface]
const MIX_PRESETS := [["몰입", 0.8, 1.0, 0.8], ["차분", 0.45, 0.7, 0.5], ["효과음만", 0.0, 1.0, 0.8]]


static func apply_mix(i: int) -> void:
	var m: Array = MIX_PRESETS[clampi(i, 0, MIX_PRESETS.size() - 1)]
	music_on = float(m[1]) > 0.0
	music_vol = float(m[1]) if music_on else music_vol
	sfx_on = true
	sfx_vol = float(m[2])
	ui_vol = float(m[3])


## A pause the player needs in order to follow what happened (a card was revealed, a bar was paid out, ...). Unlike `dur()` it never
## collapses to nothing under "reduce motion": that setting removes movement and flashes, it must not cut the game short. Reduced
## motion shortens the pause (x0.55), the animation speed scales it as usual.
const HOLD_REDUCED := 0.55


static func hold(sec: float) -> float:
	var f := float(SPEEDS.get(speed_name, 1.0))
	return sec * f * (HOLD_REDUCED if reduce_motion else 1.0)


const NAME_MAX := 12


## A typed player name made safe for every screen: no control characters or line breaks, no BBCode brackets,
## outer and repeated spaces collapsed, at most NAME_MAX characters (Korean and English count the same). "" = use the default.
static func clean_name(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if c < 32 or c == 127 or ch in ["[", "]", "{", "}"]:
			ch = " "
		out += ch
	while out.find("  ") >= 0:
		out = out.replace("  ", " ")
	out = out.strip_edges()
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX).strip_edges()
	return out


## The name the engine gets for the human seat: the chosen one, or the default "나" (shown as "You" in English).
static func seat_name() -> String:
	return player_name if player_name != "" else "나"


static func set_language(code: String) -> void:
	language = code if code in I18n.LANGS else "ko"
	I18n.apply(language)
	save_settings()
