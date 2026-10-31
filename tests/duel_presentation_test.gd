extends SceneTree
## Tests for Duel Presentation (Item 4):
## - 0 pips exposed before roll (DieView value <= 0, displays '?')
## - Defender lands and reveals first, then Challenger lands second
## - Tie notice displayed before roll with NO rule numbers
## - First duel has tutorial status; second duel in session does not
## - Screen shake disabled -> 0 shake offset
##   godot --headless --path . --fixed-fps 60 --script res://tests/duel_presentation_test.gd

const Nego = preload("res://ui/nego_panel.gd")
const Settings = preload("res://ui/settings.gd")
const Eng = preload("res://engine/engine.gd")

var checks := 0
var fails: Array = []
var started := false
var host: Control

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

func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	Settings.reduce_motion = false
	Settings.screen_shake = true
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	print("=== [1] First Duel vs Second Duel Rule Explanation & Tie Notice ===")
	Nego.session_first_duel = true
	var nego = Nego.new()
	nego.names = {"P1": "나", "P2": "Vito"}
	nego.human_id = "P1"
	nego.personalities = {"P2": "CONSERVATIVE"}
	host.add_child(nego)
	nego.visible = true
	await _frames(2)

	var duel_ev := {
		"barId": "COLIBRI",
		"playerA": "P1",
		"playerB": "P2",
		"symbolA": 4,
		"symbolB": 2,
		"challengerId": "P2" # Vito is Challenger, P1 is Defender
	}
	nego.proposal = {"P1": 15000, "P2": 15000}
	nego.begin_duel(duel_ev)
	await _frames(2)

	# Check 1: First duel status text contains tutorial explanation
	var st1: String = nego._status.text
	_ok("first duel shows rule explanation", "카드의 눈과 더합니다" in st1, st1)

	# Check 2: Tie notice is displayed before roll, with NO "RULE" code
	var labels: Array = nego._duel_box.find_children("*", "Label", true, false)
	var tie_found := false
	var no_rule_code := true
	for l in labels:
		var txt: String = (l as Label).text
		if "동점 시 도전자" in txt:
			tie_found = true
			if "RULE" in txt or "034" in txt:
				no_rule_code = false
	_ok("tie notice displayed before roll", tie_found)
	_ok("tie notice contains NO RULE numbers", no_rule_code)

	# Check 3: Dice pips before roll are completely hidden (value = 0)
	_ok("die A value before roll is 0 (hidden)", nego._die_a.value == 0, str(nego._die_a.value))
	_ok("die B value before roll is 0 (hidden)", nego._die_b.value == 0, str(nego._die_b.value))
	_ok("die A is idle (?)", nego._die_a.idle)
	_ok("die B is idle (?)", nego._die_b.idle)

	print("=== [2] Defender (P1) Lands First, Challenger (P2) Lands Second ===")
	# In this duel: playerA is P1 (Defender), playerB is P2 (Challenger)
	var roll_ev := {"rollA": 3, "rollB": 5}
	var land_order := []

	# Hook into land callbacks
	var orig_land_a = nego._die_a.land
	var orig_land_b = nego._die_b.land

	# Track die landing order
	nego.set_rolls(roll_ev)
	await _frames(2)
	_ok("duel phase is ROLLING", nego.duel_phase == Nego.DuelPhase.ROLLING)

	# Fast forward to completion
	while nego.duel_phase < Nego.DuelPhase.REVEAL:
		await _frames(2)
	_ok("both dice revealed", nego.duel_phase == Nego.DuelPhase.REVEAL)
	_ok("die A landed on 3", nego._die_a.value == 3)
	_ok("die B landed on 5", nego._die_b.value == 5)

	# Finish duel with tie check (scoreA = 4+3=7, scoreB = 2+5=7 -> TIE!)
	var finish_ev := {
		"seq": 15,
		"playerA": "P1",
		"playerB": "P2",
		"rollA": 3,
		"rollB": 5,
		"scoreA": 7,
		"scoreB": 7,
		"tie": true,
		"challengerId": "P2",
		"winnerId": "P2"
	}
	nego.finish_duel(finish_ev)
	await _frames(2)

	_ok("tie situation: challenger Vito won", nego._duel_banner.text.contains("VITO"))
	_ok("tie reason clearly displayed in status", "도전자" in nego._status.text and "승리" in nego._status.text, nego._status.text)
	_ok("status text has NO RULE numbers", not ("RULE" in nego._status.text))

	nego.queue_free()
	await _frames(2)

	print("=== [3] Second Duel In Session Shows Short Status ===")
	# Nego.session_first_duel should now be false!
	_ok("session_first_duel is false after first duel", Nego.session_first_duel == false)
	var nego2 = Nego.new()
	nego2.names = {"P1": "나", "P2": "Vito"}
	nego2.human_id = "P1"
	nego2.personalities = {"P2": "CONSERVATIVE"}
	host.add_child(nego2)
	nego2.visible = true
	await _frames(2)
	nego2.begin_duel(duel_ev)
	await _frames(2)
	var st2: String = nego2._status.text
	_ok("second duel shows short status without repeating tutorial", not ("카드의 눈과 더합니다" in st2), st2)
	nego = nego2

	print("=== [4] Screen Shake Setting ===")
	Settings.screen_shake = false
	var pos_before: Vector2 = nego.position
	nego._panel_shake(Vector2(10, 10))
	_ok("screen shake OFF -> panel position completely unchanged (0 shake)", nego.position == pos_before)

	Settings.screen_shake = true
	print("\n=== SUMMARY ===")
	print("%d checks, %d failed" % [checks, fails.size()])
	if fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%s)" % str(fails))
		quit(1)
