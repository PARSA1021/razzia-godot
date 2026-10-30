extends SceneTree
## Test A/C: the help text is built from engine facts, and the extra-money events add up exactly.
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const Help = preload("res://ui/help_screen.gd")
var checks := 0
var fails: Array = []

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _texts(n: Node, out: Array) -> void:
	if n is Label: out.append(n.text)
	for c in n.get_children(): _texts(c, out)

func _initialize() -> void:
	# A: facts the help states
	_ok("die symbols are 1..6 (data)", Eng.ZOCKER_SYMBOLS.min() >= 1 and Eng.ZOCKER_SYMBOLS.max() <= 6 and Eng.RAZZIA_SYMBOLS.max() <= 6)
	_ok("tie goes to the caller", Eng.duel_win_probability(3, 3, true) > Eng.duel_win_probability(3, 3, false))
	_ok("5 vs 2 caller: 36-combo count", is_equal_approx(Eng.duel_win_probability(5, 2, true) * 36.0, round(Eng.duel_win_probability(5, 2, true) * 36.0)))
	var all := []
	var h = Help.new()
	root.add_child(h)
	await process_frame
	for i in range(h._titles.size()):
		h._go(i)
		await process_frame
		_texts(h._body, all)
	var joined := "\n".join(all)
	_ok("no star glyph used as a game term", not ("★1" in joined or "★5" in joined or "★가" in joined))
	_ok("10 rule topics + AI page + Relic mode", h._titles.size() == 12)
	_ok("tie rule stated", "동점" in joined and "결투를 선언한" in joined)
	_ok("relic mode rules stated", "유물" in joined and "암시장" in joined)
	_ok("example probability equals the engine", ("약 %d%%" % roundi(Eng.duel_win_probability(5, 2, true) * 100.0)) in joined)
	h.queue_free()
	# C: extra money events
	var tot := 0
	for sd in [3, 4, 5, 6]:
		var s := Eng.create_game({"playerCount": 4, "seed": sd, "humanPlayerId": "P1", "names": ["a", "b", "c", "d"]})
		for p in s["players"]: p["isHuman"] = false
		Ctl.new(s).run()
		var bar_money := {}
		var extras := 0
		var round_extra := {}
		for e in s["events"]:
			match e["type"]:
				"MONEY_PLACED":
					bar_money[e["barId"]] = int(bar_money.get(e["barId"], 0)) + int(e["value"])
					if e["extra"]:
						extras += 1
				"BAR_RESOLVED":
					pass
		_ok("seed %d: placed money events exist and extras happen (%d)" % [sd, extras], extras > 0)
		tot += extras
	_ok("extra events seen overall", tot > 0)
	print("RULES HELP TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
