extends SceneTree
## Phase 28: languages, the player's name and the two save slots, through the real menu and the real game screen.
##   A  tests never touch the player's own files (settings / saves / records live under user://test_<pid>_*)
##   B  the translation layer: Korean passes through, English is looked up, a missing key falls back, placeholders survive
##   C  the menu in English: every screen the menu opens shows no Korean (setup card, settings, help pages, records,
##      the slot list, the overwrite question, the tutorial offer) and switching back restores Korean
##   D  the name: cleaned (spaces, length, control characters), saved, used for my seat only; the AI cast is untouched
##   E  two slots: a game in each, both listed, each loads its own game, a new game replaces only its own slot, a damaged
##      file is set aside without a crash, the copy before the last write rescues a damaged save, a file from before
##      slots existed still loads in slot 1
##   F  changing the language in the middle of a game changes no game state
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/i18n_slots_test.gd

const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const I18n = preload("res://ui/i18n.gd")
const TextAudit = preload("res://tests/text_audit.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const Game = preload("res://ui/game_screen.gd")

var checks := 0
var fails: Array = []
var started := false
var main: Control
var rng := {"rngState": 99}


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _btn(from: Node, needle: String) -> Button:
	if from == null:
		return null
	for b in from.find_children("*", "Button", true, false):
		if not b.is_visible_in_tree() or b.disabled:
			continue
		if needle in b.text:
			return b
		if needle == "NEW GAME" and (b.name == "NewGameButton" or "QUICK START" in b.text or "빠른 시작" in b.text):
			return b
		if needle == "환경 설정" and (b.name == "SettingsButton" or "SETTINGS" in b.text or "설정" in b.text):
			return b
		if needle == "HOW TO PLAY" and (b.name == "HowToPlayButton" or "게임 방법" in b.text):
			return b
	return null


func _press(b: Button) -> void:
	if b != null:
		b.pressed.emit()
	await _frames(4)


func _korean(where: String) -> Array:
	var left := TextAudit.hangul(root)
	if not left.is_empty():
		print("     korean @%s: %s" % [where, str(left.slice(0, 6))])
	return left


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run.call_deferred()
	return false


func _run() -> void:
	Settings.load_settings()
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.dialogue_on = false
	Settings.reduce_motion = true
	Settings.tutorial_done = true
	Settings.coach_on = false
	root.content_scale_size = Vector2i(1280, 720)

	# ---------------- A) isolation
	_ok("A settings file is the test's own", Settings.path.begins_with("user://test_"), Settings.path)
	_ok("A both save slots are the test's own", SaveStore.slot_path(1).begins_with("user://test_") and SaveStore.slot_path(2).begins_with("user://test_"))
	_ok("A slot 1 is the original autosave file name", SaveStore.slot_path(1).ends_with("_autosave.json"))
	_ok("A a test runs in Korean whatever the system language", Settings.language == "ko" and I18n.lang == "ko")

	# ---------------- B) translation layer
	_ok("B Korean passes through", I18n.t("닫기") == "닫기" and TranslationServer.translate("닫기") == "닫기")
	I18n.apply("en")
	_ok("B English is looked up", I18n.t("닫기") == "Close" and TranslationServer.translate("닫기") == "Close")
	_ok("B a missing key shows the source text, never a blank", I18n.t("없는 문장 키") == "없는 문장 키")
	_ok("B a template keeps its placeholders", (I18n.t("슬롯 %d") % 2) == "Slot 2")
	var tbl: Dictionary = load("res://i18n/en.gd").EN
	var bad_ph: Array = []
	var ph := RegEx.create_from_string("%[-0-9.]*[sdf]|\\{[a-z_]+\\}")
	for k in tbl:
		var a: Array = ph.search_all(str(k).replace("%%", "")).map(func(m): return m.get_string())
		var b: Array = ph.search_all(str(tbl[k]).replace("%%", "")).map(func(m): return m.get_string())
		a.sort()
		b.sort()
		if a != b:
			bad_ph.append(k)
	_ok("B every English line keeps the same blanks as its Korean key (%d lines)" % tbl.size(), bad_ph.is_empty(), str(bad_ph))
	I18n.apply("ko")
	_ok("B back to Korean", I18n.t("닫기") == "닫기")
	Settings.set_language("xx")
	_ok("B an unknown language falls back to Korean", Settings.language == "ko" and I18n.lang == "ko")

	# ---------------- C) the menu in English
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)
	var lang_seg: Node = main.current.get_node_or_null("LangSwitch")
	_ok("C the language switch is on the menu", lang_seg != null)
	await _press(_btn(lang_seg, "English"))
	await _frames(10)
	_ok("C English is chosen and saved", Settings.language == "en")
	var cf := ConfigFile.new()
	cf.load(Settings.path)
	_ok("C the choice is in the settings file (kept after a restart)", str(cf.get_value("general", "language", "")) == "en")
	_ok("C the menu reads NEW GAME", _btn(main.current, "NEW GAME") != null)
	var fold := _btn(main.current, "환경 설정")
	await _press(fold)
	await _frames(6)
	var left := _korean("menu + settings")
	_ok("C menu and its settings: no Korean", left.is_empty(), str(left))
	# help: every page
	await _press(_btn(main.current, "HOW TO PLAY"))
	await _frames(6)
	var help: Node = main.current._help
	var help_left: Array = []
	for i in range(14):
		help_left.append_array(_korean("help page %d" % i))
		var nx := _btn(help, "다음  ▶")
		if nx == null:
			break
		await _press(nx)
		await _frames(4)
	_ok("C every help page: no Korean", help_left.is_empty(), str(help_left.slice(0, 4)))
	if is_instance_valid(help):
		main.current._toggle_help()
	await _frames(4)
	# records (empty and with a finished game on file)
	var Rec = load("res://ui/records.gd")
	var r: Dictionary = Rec.blank()
	r["games"] = 3
	r["wins"] = 1
	r["history"] = [{"players": 4, "rounds": 7, "rank": 1, "money": 230000, "won": true}]
	r["achievements"] = {"first_win": 1}
	Rec.save_records(r)
	await _press(main.current.find_child("RecordsButton", true, false))
	await _frames(8)
	left = _korean("records")
	_ok("C records screen: no Korean", left.is_empty(), str(left))
	for c in main.current.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("records_screen.gd"):
			c.queue_free()
	Rec.save_records(Rec.blank())
	await _frames(4)
	# tutorial offer
	Settings.tutorial_done = false
	await _press(main.current.find_child("NewGameButton", true, false))
	await _frames(6)
	left = _korean("tutorial offer")
	_ok("C the tutorial offer: no Korean", main.current.has_node("TutorialAsk") and left.is_empty(), str(left))
	if main.current.has_node("TutorialAsk"):
		main.current.get_node("TutorialAsk").free()
	Settings.tutorial_done = true

	# ---------------- D) the name
	_ok("D blank or only spaces = the default", Settings.clean_name("") == "" and Settings.clean_name("    ") == "")
	_ok("D outer and double spaces go", Settings.clean_name("  Mr   Kim  ") == "Mr Kim")
	_ok("D at most %d characters" % Settings.NAME_MAX, Settings.clean_name("ABCDEFGHIJKLMNOPQRST").length() == Settings.NAME_MAX)
	_ok("D line breaks, tabs and brackets cannot get in", Settings.clean_name("a\nb\tc[b]x{y}") == "a b c b x y", Settings.clean_name("a\nb\tc[b]x{y}"))
	_ok("D Korean and symbols are kept", Settings.clean_name("김철수 ♠#1") == "김철수 ♠#1")
	var ne: LineEdit = main.current.find_child("NameEdit", true, false)
	_ok("D the setup card has a name field limited to %d characters" % Settings.NAME_MAX, ne != null and ne.max_length == Settings.NAME_MAX)
	if ne != null:
		ne.text = "  Parsa  "
		ne.text_changed.emit(ne.text)
		ne.text_submitted.emit(ne.text)
		await _frames(2)
	_ok("D typing a name saves it cleaned", Settings.player_name == "Parsa")
	cf = ConfigFile.new()
	cf.load(Settings.path)
	_ok("D the name is in the settings file", str(cf.get_value("general", "player_name", "")) == "Parsa")
	var cfg: Dictionary = main.current._config()
	_ok("D a new game seats me with my name, the AI cast unchanged", cfg["names"][0] == "Parsa" and cfg["names"].slice(1) == ["Vito", "Lola", "Mack"].slice(0, cfg["names"].size() - 1))

	# ---------------- E) two slots
	SaveStore.use_slot(1)
	SaveStore.clear()
	SaveStore.use_slot(2)
	SaveStore.clear()
	# slot list with both empty: CONTINUE is not offered
	main.show_menu()
	await _frames(8)
	_ok("E no saves: no CONTINUE", _btn(main.current, "CONTINUE") == null)
	var seed1 := 1111
	var seed2 := 2222
	await _play_to_round(1, seed1, 3, "Parsa")
	var info1 := SaveStore.slot_info(1)
	_ok("E game 1 saved in slot 1 (round 3)", info1["exists"] and info1["ok"] and int(info1["round"]) == 3, str(info1))
	_ok("E slot 1 knows players, time and that the game is running", int(info1["players"]) == 4 and int(info1["savedAt"]) > 0 and info1["names"][0] == "Parsa")
	_ok("E slot 2 is still empty", not SaveStore.slot_info(2)["exists"])
	await _play_to_round(2, seed2, 2, "Parsa")
	var info2 := SaveStore.slot_info(2)
	_ok("E game 2 saved in slot 2 (round 2)", info2["exists"] and int(info2["round"]) == 2)
	_ok("E slot 1 untouched by game 2", SaveStore.slot_info(1)["round"] == 3)
	# the slot list in English
	main.show_menu()
	await _frames(8)
	await _press(_btn(main.current, "CONTINUE"))
	await _frames(6)
	left = _korean("slot list")
	_ok("E CONTINUE lists both slots, in English", main.current.has_node("SlotPanel") and left.is_empty(), str(left))
	var l1: Button = main.current.find_child("Load1", true, false)
	var l2: Button = main.current.find_child("Load2", true, false)
	_ok("E both slots can be loaded", l1 != null and not l1.disabled and l2 != null and not l2.disabled)
	# load slot 2, then slot 1, then slot 2 again: each is its own game
	for pair in [[2, seed2, 2], [1, seed1, 3], [2, seed2, 2]]:
		main.show_menu()
		await _frames(6)
		await _press(_btn(main.current, "CONTINUE"))
		await _frames(4)
		await _press(main.current.find_child("Load%d" % pair[0], true, false))
		await _frames(30)
		var g = main.current
		var okg: bool = g != null and g.get("state") != null and not g.state.is_empty()
		_ok("E loading slot %d brings back its own game (seed, round)" % pair[0], okg and int(g.state["config"]["seed"]) == pair[1] and int(g.state["round"]) == pair[2],
			"%s" % (str([g.state["config"]["seed"], g.state["round"]]) if okg else "no game"))
		if okg:
			var me: Dictionary = Eng.get_player(g.state, g.human_id)
			_ok("E slot %d: my name and my hand came back" % pair[0], str(me["name"]) == "Parsa" and (me["hand"] as Array).size() == 5)
	# a new game in slot 1 asks first, then replaces only slot 1
	main.show_menu()
	await _frames(8)
	main.current.save_slot = 1
	main.current._refresh_slot_hint()
	await _press(main.current.find_child("NewGameButton", true, false))
	await _frames(4)
	_ok("E starting over a used slot asks first", main.current.has_node("OverwriteAsk"))
	left = _korean("overwrite question")
	_ok("E the question is in English", left.is_empty(), str(left))
	await _press(_btn(main.current.get_node("OverwriteAsk"), "취소"))     # a button keeps its key; it shows "Cancel"
	await _frames(4)
	_ok("E cancel keeps slot 1", SaveStore.slot_info(1)["round"] == 3 and not main.current.has_node("OverwriteAsk"))
	await _press(main.current.find_child("NewGameButton", true, false))
	await _frames(4)
	await _press(main.current.find_child("OverwriteOk", true, false))
	await _frames(40)
	_ok("E replacing slot 1 starts a new game there", main.current.get("state") != null and int(main.current.state["round"]) <= 1)
	_ok("E slot 2 survives a new game in slot 1", SaveStore.slot_info(2)["exists"] and int(SaveStore.slot_info(2)["round"]) == 2)
	# a damaged slot: listed as damaged, set aside on load, no crash
	main.show_menu()
	await _frames(6)
	var f := FileAccess.open(SaveStore.slot_path(2), FileAccess.WRITE)
	f.store_string("{ this is not a save")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.slot_path(2) + ".bak"))
	var bad := SaveStore.slot_info(2)
	_ok("E a damaged slot is listed as damaged", bad["exists"] and not bad["ok"])
	main._continue(2)
	await _frames(10)
	_ok("E loading a damaged slot returns to the menu (no crash)", main.current.get("state") == null)
	_ok("E the damaged file is set aside, not deleted", not FileAccess.file_exists(SaveStore.slot_path(2)) and _has_corrupt())
	# the copy before the last write rescues a save that was damaged afterwards
	SaveStore.use_slot(2)
	var s1 := Eng.create_game({"playerCount": 3, "seed": 5, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola"]})
	SaveStore.save(s1, 7)
	SaveStore.save(s1, 8)                      # second write: the first one becomes the .bak
	f = FileAccess.open(SaveStore.slot_path(2), FileAccess.WRITE)
	f.store_string("{ broken")
	f.close()
	var rb := SaveStore.load_save()
	_ok("E a damaged save falls back to the copy before the last write", rb["ok"] and rb.get("fromBackup", false))
	SaveStore.clear()
	_ok("E clearing a slot removes its copy too", not FileAccess.file_exists(SaveStore.slot_path(2) + ".bak"))
	# a file written before slots existed (no format / savedAt) still loads in slot 1
	SaveStore.use_slot(1)
	f = FileAccess.open(SaveStore.slot_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Eng.VERSION, "gameState": s1, "aiRngState": 3, "actions": []}))
	f.close()
	var old := SaveStore.slot_info(1)
	_ok("E an old save (no slot fields) shows in slot 1 with a time", old["ok"] and int(old["players"]) == 3 and int(old["savedAt"]) > 0)
	main._continue(1)
	await _frames(20)
	_ok("E and it loads", main.current.get("state") != null and int(main.current.state["config"]["seed"]) == 5)

	# ---------------- F) language switch mid-game
	var g = main.current
	if g != null and g.get("state") != null:
		await _frames(30)
		var before := Eng.serialize_game(g.state)
		g._on_exit_pressed()
		await _frames(4)
		var seg: Node = g.modal_layer.find_child("LangChoice", true, false)
		_ok("F the pause panel has the language choice", seg != null)
		await _press(_btn(seg, "한국어"))
		await _frames(8)
		_ok("F switching language mid-game changes no game state", Eng.serialize_game(g.state) == before)
		_ok("F the panel is rebuilt in Korean", _btn(g.modal_layer, "계속하기") != null and I18n.lang == "ko")
		await _press(_btn(seg, "English") if is_instance_valid(seg) else _btn(g.modal_layer.find_child("LangChoice", true, false), "English"))
		await _frames(8)
		_ok("F and back to English", I18n.lang == "en" and Eng.serialize_game(g.state) == before)
		var shown: String = g.now_label.atr(g.now_label.text)
		_ok("F the narration line switched with it (no Korean left in it)", RegEx.create_from_string("[가-힣]").search(shown) == null, shown)
		left = _korean("pause panel")
		_ok("F the pause panel in English: no Korean", left.is_empty(), str(left))
		g._close_pause()
		await _frames(4)

	_finish()


func _has_corrupt() -> bool:
	var d := DirAccess.open("user://")
	var pre := SaveStore.slot_path(2).get_file().get_basename()
	for fn in d.get_files():
		if fn.begins_with(pre + ".corrupt."):
			return true
	return false


## a real game in `slot`, played by a bot up to the first card prompt of round `upto`; the board autosaves as it goes
func _play_to_round(slot: int, seed_v: int, upto: int, name: String) -> void:
	main.show_menu()
	await _frames(4)
	SaveStore.use_slot(slot)
	SaveStore.clear()
	var s := Eng.create_game({"playerCount": 4, "seed": seed_v, "humanPlayerId": "P1", "names": [name, "Vito", "Lola", "Mack"], "aiDifficulty": "NORMAL"})
	var g = Game.new()
	g.skip = true
	var done := [false]
	g.bot = func(pending, view, gg):
		if int(gg.state["round"]) >= upto and str(pending["type"]) == "SELECT_CARD":
			done[0] = true
			return {}
		match str(pending["type"]):
			"SELECT_CARD":
				return {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(view, rng)}
			"PLACE_EXTRA_MONEY":
				return {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(view, rng)}
			"MAKE_PROPOSAL":
				return {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(view, rng)}
			"RESPOND":
				return {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(view, rng)}
		return {}
	main._swap(g)
	g.begin(s)
	var n := 0
	while not done[0] and n < 20000:
		n += 1
		g.skip = true
		await process_frame
	await _frames(2)


func _finish() -> void:
	Settings.language = "ko"
	I18n.apply("ko")
	for n in SaveStore.SLOTS:
		SaveStore.use_slot(n)
		SaveStore.clear()
	print("I18N/SLOTS TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
