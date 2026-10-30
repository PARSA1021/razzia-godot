extends SceneTree
## Duel stage (UI only, synthesized engine-shaped events): phase order, once-only settlement, skip, reduced motion, tie, upset, big pot,
## reaction lines, one confirmation prompt that needs a real press.
##   godot --headless --path . --fixed-fps 60 --script res://tests/ui_duel_stage_test.gd
const Nego = preload("res://ui/nego_panel.gd")
const Eng = preload("res://engine/engine.gd")
const Settings = preload("res://ui/settings.gd")
const DP = Nego.DuelPhase
var checks := 0
var fails: Array = []
var started := false
var host: Control

func _ok(n: String, c: bool, x: String = "") -> void:
	checks += 1
	if not c: fails.append(n)
	print("  %s %s %s" % ["ok  " if c else "FAIL", n, x])

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _process(_d: float) -> bool:
	if started: return false
	started = true
	_run.call_deferred()
	return false

func _make(skipping := false) -> Control:
	var n = Nego.new()
	n.names = {"P1": "나", "P2": "Vito", "P3": "Lola"}
	n.human_id = "P1"
	n.personalities = {"P2": "CONSERVATIVE", "P3": "AGGRESSIVE"}
	n.u = 1.0
	if skipping:
		n.skipping = func(): return true
	host.add_child(n)
	return n

func _open(n, sym1: int, sym2: int, prize: int, prop1: int, prop2: int) -> void:
	var ev := {"barId": "COLIBRI", "prize": prize, "kind": "BAR", "claimantIds": ["P1", "P2"], "symbols": {"P1": sym1, "P2": sym2}, "proposerId": "P2"}
	n.open(ev)
	n.set_proposal({"proposal": {"P1": prop1, "P2": prop2}, "proposerId": "P2"})

func _duel(n, sym1: int, sym2: int) -> Dictionary:
	var ev := {"playerA": "P2", "playerB": "P1", "symbolA": sym2, "symbolB": sym1, "challengerId": "P1"}
	n.begin_duel(ev)
	return ev

func _resolved(winner: String, ra: int, rb: int, sa: int, sb: int, tie := false) -> Dictionary:
	return {"playerA": "P2", "playerB": "P1", "rollA": ra, "rollB": rb, "scoreA": sa + ra, "scoreB": sb + rb, "winnerId": winner, "tie": tie, "seq": 3}

func _run() -> void:
	Settings.music_on = false
	Settings.sfx_on = false
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	# 1) normal animated duel: phases in order, once-only
	Settings.reduce_motion = false
	var n = _make()
	_open(n, 1, 4, 20000, 5000, 15000)
	var dev := _duel(n, 1, 4)
	_ok("INTRO after the duel starts", n.duel_phase == DP.INTRO)
	n.set_rolls({"rollA": 5, "rollB": 6})
	await _frames(3)
	_ok("ROLLING while the dice tumble", n.duel_phase == DP.ROLLING)
	n.set_rolls({"rollA": 1, "rollB": 1})                       # duplicate DICE_ROLLED while rolling
	_ok("a duplicate DICE_ROLLED is ignored", n.duel_phase == DP.ROLLING)
	await _frames(150)
	_ok("REVEAL once both dice have landed", n.duel_phase == DP.REVEAL, str(n.duel_phase))
	_ok("dice show the engine's numbers (5 and 6)", n._die_a.value == 5 and n._die_b.value == 6)
	n.finish_duel(_resolved("P2", 5, 6, 4, 1))
	_ok("SETTLEMENT starts at the result", n.duel_phase == DP.SETTLEMENT)
	n.finish_duel(_resolved("P1", 5, 6, 4, 1))                  # duplicate / contradictory second result
	_ok("a second DUEL_RESOLVED changes nothing", "VITO" in n._duel_banner.text)
	await _frames(70)
	_ok("REACTION after the count-up", n.duel_phase == DP.REACTION, str(n.duel_phase))
	_ok("winner counted up to the full pot", "+$20,000" in n._verdict_a.text, n._verdict_a.text)
	_ok("pot plaque emptied", n._pot_label.text == "$0", n._pot_label.text)
	_ok("loser shows $0 and words, not colour alone", "패배" in n._verdict_b.text and "$0" in n._verdict_b.text)
	_ok("AI winner has an in-character line", n._bubble_a.text.strip_edges() != "", n._bubble_a.text)
	_ok("the human has no scripted line", n._bubble_b.text.strip_edges() == "")
	n.ask_continue()
	await _frames(2)
	_ok("WAITING for the confirmation", n.duel_phase == DP.WAITING)
	n.ask_continue()                                             # a second prompt must not stack up
	var btns: Array = n._action_box.find_children("*", "Button", true, false)
	_ok("exactly one confirm button", btns.size() == 1, str(btns.size()))
	if n.duel_phase == DP.WAITING and is_instance_valid(btns[0]):
		btns[0].emit_signal("pressed")
		btns[0].emit_signal("pressed")                           # double click
	await _frames(3)
	_ok("DONE after the confirmation", n.duel_phase == DP.DONE)
	n.close()
	_ok("close resets the phase", n.duel_phase == DP.NONE)
	n.queue_free()
	await _frames(2)

	# 2) skip: everything lands at once, and still reaches REACTION immediately
	n = _make(true)
	_open(n, 1, 4, 20000, 5000, 15000)
	_duel(n, 1, 4)
	await n.set_rolls({"rollA": 2, "rollB": 3})
	_ok("skip: dice landed at once", n._die_a.value == 2 and n._die_b.value == 3 and n.duel_phase == DP.REVEAL)
	n.finish_duel(_resolved("P2", 2, 3, 4, 1))
	_ok("skip: settlement and reaction without waiting", n.duel_phase == DP.REACTION and "+$20,000" in n._verdict_a.text)
	n.queue_free()
	await _frames(2)

	# 3) reduced motion: the result is complete on the very first frame
	Settings.reduce_motion = true
	n = _make()
	_open(n, 1, 4, 20000, 5000, 15000)
	_duel(n, 1, 4)
	await n.set_rolls({"rollA": 6, "rollB": 1})
	n.finish_duel(_resolved("P2", 6, 1, 4, 1))
	_ok("reduced motion: complete result, no waiting", n.duel_phase == DP.REACTION and "+$20,000" in n._verdict_a.text and n._duel_banner.modulate.a > 0.99)
	n.queue_free()
	await _frames(2)

	# 4) tie: the challenger (me) wins; words explain it
	n = _make()
	_open(n, 3, 3, 10000, 5000, 5000)
	_duel(n, 3, 3)
	await n.set_rolls({"rollA": 4, "rollB": 4})
	n.finish_duel(_resolved("P1", 4, 4, 3, 3, true))
	_ok("tie: the challenger is named the winner", "나" in n._duel_banner.text and n._die_b.glow and not n._die_a.glow)
	_ok("tie: the status says why", "동점" in n._status.text)
	n.queue_free()
	await _frames(2)

	# 5) upset + big pot flags (words only; odds come from the engine function)
	n = _make()
	_open(n, 6, 1, 50000, 25000, 25000)                          # I hold the weak card (eye 1) against eye 6
	_duel(n, 1, 6)
	await n.set_rolls({"rollA": 1, "rollB": 6})
	n.finish_duel(_resolved("P1", 1, 6, 6, 1))
	_ok("upset: the low-odds winner is called out", "역전승" in n._duel_tag.text, n._duel_tag.text)
	_ok("big pot: stake read from the proposals", n._stake == 50000)
	n.queue_free()
	await _frames(2)
	n = _make()
	_open(n, 3, 3, 60000, 30000, 30000)
	_duel(n, 3, 3)
	await n.set_rolls({"rollA": 5, "rollB": 2})
	n.finish_duel(_resolved("P2", 5, 2, 3, 3))
	_ok("big pot without an upset: tagged as a big stake", "큰 판돈" in n._duel_tag.text, n._duel_tag.text)
	n.queue_free()
	await _frames(2)

	Settings.reduce_motion = false
	print("DUEL STAGE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED: ", fails)
	quit(0 if fails.is_empty() else 1)
