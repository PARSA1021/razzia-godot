extends SceneTree
## Phase 25: cutscenes that know what happened. Checks the line pools (every kind x personality, blanks filled,
## no Korean particle glued to a blank, short enough for the box), the titles, the mid-game budget and the "핵심만" setting,
## and that the restaged scene still behaves (speaker lit, counter, Esc).
##   godot --headless --fixed-fps 60 --path . --script res://tests/ui_scene_story_test.gd
const Characters = preload("res://ui/characters.gd")
const Game = preload("res://ui/game_screen.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const DS = preload("res://ui/dialogue_scene.gd")

var checks := 0
var fails: Array = []
var started := false


func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c:
		fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])


func _process(_d: float) -> bool:
	if not started:
		started = true
		_run.call_deferred()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var ctx := {"total": "$290,000", "bar": "COLIBRI", "pot": "$45,000", "gap": "$20,000", "leader": "Vito"}
	var kinds: Array = Characters.SCENES.keys()
	var bad := []
	var glued := []
	var long := []
	var particle := RegEx.new()
	particle.compile("\\}(가|이 |이$|을|를|은|는|와|과|라고|이라|의 )")
	for k in kinds:
		for pers in ["CONSERVATIVE", "AGGRESSIVE", "OPPORTUNIST"]:
			for n in range(6):
				var t := Characters.scene_text(k, "Nobody", pers, n, ctx)
				if t == "" or "{" in t:
					bad.append("%s/%s" % [k, pers])
				if t.length() > 48:
					long.append(t)
			for raw in Characters.SCENES[k][pers]:
				if particle.search(raw) != null:
					glued.append(raw)
	for nm in Characters.SCENES_BY_NAME:
		for k in Characters.SCENES_BY_NAME[nm]:
			for raw in Characters.SCENES_BY_NAME[nm][k]:
				if particle.search(raw) != null:
					glued.append(raw)
	_ok("every scene kind has a line for every personality, blanks filled", bad.is_empty(), str(bad))
	_ok("no Korean particle glued to a blank (a name or an amount reads right whatever it is)", glued.is_empty(), str(glued))
	_ok("every line fits the box (<= 48 characters)", long.is_empty(), str(long))
	_ok("a line that needs a venue is never picked without one", not ("{" in Characters.scene_text("duel_win", "X", "CONSERVATIVE", 0, {})) and Characters.scene_text("duel_win", "X", "CONSERVATIVE", 0, {}) != "")
	_ok("per-name voice wins over the personality", Characters.scene_text("intro", "Dutch", "CONSERVATIVE", 0, ctx).begins_with("허허"))
	_ok("titles carry the stakes", Characters.scene_title("duel", ctx) == "결투 · COLIBRI · $45,000" and Characters.scene_title("raid", {}) == "RAZZIA")
	# English (ui/i18n.gd): every line is drawn in the same box, so it must be no wider than the widest Korean line that
	# passes the 48-character rule (measured in pixels with the dialogue font), and keep its blanks filled
	var I18n = load("res://ui/i18n.gd")
	var font: Font = load("res://ui/tokens.gd").font("ui", 600)
	var widest_ko := 0.0
	var all_lines: Array = []
	for k in kinds:
		for pers in ["CONSERVATIVE", "AGGRESSIVE", "OPPORTUNIST"]:
			for n in range(6):
				all_lines.append([k, pers, n])
				var t := Characters.scene_text(k, "Nobody", pers, n, ctx)
				widest_ko = maxf(widest_ko, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	I18n.apply("en")
	var en_bad: Array = []
	var en_long: Array = []
	for spec in all_lines:
		var t := Characters.scene_text(spec[0], "Nobody", spec[1], spec[2], ctx)
		if t == "" or "{" in t or RegEx.create_from_string("[가-힣]").search(t) != null:
			en_bad.append(t)
		elif font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > widest_ko + 1.0:
			en_long.append(t)
	_ok("English: every scene line is translated with its blanks filled", en_bad.is_empty(), str(en_bad))
	_ok("English: no line is wider than the widest Korean line (%.0f px)" % widest_ko, en_long.is_empty(), str(en_long))
	_ok("English: titles translated and filled", Characters.scene_title("duel", ctx) == "DUEL · COLIBRI · $45,000")
	I18n.apply("ko")
	var seen := {}
	for sd in range(20):
		seen[Characters.scene_text("intro", "Nobody", "AGGRESSIVE", sd, ctx)] = true
	_ok("the opening varies between games (several different lines)", seen.size() >= 3, str(seen.size()))

	# ---- in a game
	Settings.load_settings()
	var saved := [Settings.dialogue_on, Settings.dialogue_mid, Settings.music_on, Settings.sfx_on]
	Settings.dialogue_on = true
	Settings.dialogue_mid = true
	Settings.music_on = false
	Settings.sfx_on = false
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 720)
	var s := Eng.create_game({"playerCount": 4, "seed": 9, "humanPlayerId": "P1", "names": ["나", "Vito", "Lola", "Mack"]})
	var g = Game.new()
	g.autosave_enabled = false
	root.add_child(g)
	g.begin(s)
	await _frames(20)
	var sc: Node = null
	for c in g.get_children():
		if c is DS:
			sc = c
	_ok("the opening scene plays with a title", sc != null and str(sc.title).begins_with("ROUND 1"), str(sc.title) if sc != null else "")
	if sc != null:
		await _frames(30)
		_ok("the speaker's photo is lit, the listener's in shadow", sc._faces.size() == 2 and sc._faces[0].lit > 0.9 and sc._faces[1].lit < 0.1)
		_ok("the counter shows the line number", sc._count.text == "1 / %d" % sc.lines.size(), sc._count.text)
		_ok("the name plate names the speaker", str(sc.lines[0]["who"]) in sc._name_label.text, sc._name_label.text)
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(3)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await _frames(5)
		_ok("Esc leaves the scene", not is_instance_valid(sc) or sc.is_queued_for_deletion())
	# the mid-game budget
	var w := 0
	while not (g._awaiting_select or g._awaiting_bar) and w < 1200:
		w += 1
		await process_frame
	g.disp["round"] = 3
	_ok("a mid-game scene is allowed at first", g._mid_scene_ok())
	Settings.dialogue_mid = false
	_ok("'핵심만' turns mid-game scenes off", not g._mid_scene_ok())
	Settings.dialogue_mid = true
	g._scene_mid = 3
	_ok("at most three mid-game scenes a game", not g._mid_scene_ok())
	g._scene_mid = 0
	g._scene_last_round = 2
	_ok("never two rounds in a row", not g._mid_scene_ok())
	g._scene_last_round = -9
	# a raid scene knows the venue and the pot
	var actor: Dictionary = g._ai_players()[0]
	g._play_scene("raid", {"actor": actor, "me_raided_them": true, "ctx": {"bar": "COLIBRI", "pot": "$60,000"}})
	await _frames(5)
	sc = null
	for c in g.get_children():
		if c is DS and not c.is_queued_for_deletion():
			sc = c
	_ok("a raid scene shows the venue and the money at stake", sc != null and sc.title == "RAZZIA · COLIBRI · $60,000", str(sc.title) if sc != null else "")
	if sc != null:
		sc._leave(true)
	Settings.dialogue_on = saved[0]
	Settings.dialogue_mid = saved[1]
	Settings.music_on = saved[2]
	Settings.sfx_on = saved[3]
	print("SCENE STORY TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
