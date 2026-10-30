extends SceneTree
## A real restart (two processes): what the player set and saved must still be there when the game is started again.
## Run by tools/run_all_tests.sh as:
##   RAZZIA_TEST_TAG=rs RAZZIA_TEST_KEEP=1 godot --headless --path . --script res://tests/restart_test.gd -- step=1
##   RAZZIA_TEST_TAG=rs                    godot --headless --path . --script res://tests/restart_test.gd -- step=2
## step 1 chooses English, a name, master mute and a lower music volume through Settings, and leaves a game in each
## slot; step 2 (a new process) loads everything from disk and checks it, then the files are removed.

const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const I18n = preload("res://ui/i18n.gd")
const Eng = preload("res://engine/engine.gd")

var checks := 0
var fails: Array = []


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _init() -> void:
	var step := "1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("step="):
			step = a.substr(5)
	_ok("the two processes share the tagged test files", Settings.path.contains("test_rs_"), Settings.path)
	if step == "1":
		Settings.load_settings()
		Settings.set_language("en")
		Settings.player_name = Settings.clean_name("  Parsa  ")
		Settings.mute_all = true
		Settings.music_vol = 0.4
		Settings.save_settings()
		for n in [1, 2]:
			SaveStore.use_slot(n)
			var s := Eng.create_game({"playerCount": 2 + n, "seed": 100 + n, "humanPlayerId": "P1", "names": ["Parsa", "Vito", "Lola", "Mack"].slice(0, 2 + n)})
			_ok("slot %d written" % n, SaveStore.save(s, 7 * n))
	else:
		Settings.load_settings()
		_ok("after a restart: English", Settings.language == "en" and I18n.lang == "en" and TranslationServer.translate("닫기") == "Close")
		_ok("after a restart: my name", Settings.player_name == "Parsa")
		_ok("after a restart: master mute and the music volume", Settings.mute_all and absf(Settings.music_vol - 0.4) < 0.001)
		for n in [1, 2]:
			var info := SaveStore.slot_info(n)
			_ok("after a restart: slot %d holds its game" % n, info["ok"] and int(info["players"]) == 2 + n and info["names"][0] == "Parsa")
			SaveStore.use_slot(n)
			var r := SaveStore.load_save()
			_ok("after a restart: slot %d loads (seed %d)" % [n, 100 + n], r["ok"] and int(r["state"]["config"]["seed"]) == 100 + n and int(r["aiRngState"]) == 7 * n)
	print("RESTART TEST step %s: checks=%d failed=%d -> %s" % [step, checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
