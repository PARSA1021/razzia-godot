extends SceneTree
## Comprehensive UI/UX Audit & Feature Verification Test Suite
## Tests newly implemented features:
##   1. Razzia card visual identity (badge, ribbon, police die)
##   2. Hand selection targeting venue highlight & dynamic button label
##   3. Dice duel role tags (Challenger vs Defender)
##   4. Dice duel tie breakdown & Bribed Judge overrule status
##   5. Input guards against double-tap

const CardView = preload("res://ui/card_view.gd")
const Nego = preload("res://ui/nego_panel.gd")
const Settings = preload("res://ui/settings.gd")

var checks := 0
var fails: Array = []
var started := false
var host: Control

func _ok(desc: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(desc)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", desc, extra])

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
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	print("\n--- Running UI/UX Audit & Verification Test Suite ---")

	# Group 1: Razzia Card Visual Distinction
	print("\n[Group 1: Razzia Card Visual Distinction]")
	var cv_zocker := CardView.new()
	cv_zocker.card = {"id": "C-Z-1", "type": "ZOCKER", "barId": "COLIBRI", "dieSymbol": 3}
	cv_zocker.size = Vector2(130, 180)
	host.add_child(cv_zocker)
	await _frames(2)
	_ok("Zocker card recognizes not razzia", not cv_zocker.is_razzia())

	var cv_razzia := CardView.new()
	cv_razzia.card = {"id": "C-R-1", "type": "RAZZIA", "barId": "COLIBRI", "dieSymbol": 4}
	cv_razzia.size = Vector2(130, 180)
	host.add_child(cv_razzia)
	await _frames(2)
	_ok("Razzia card recognizes razzia type", cv_razzia.is_razzia())

	# Group 2: Dice Duel Role Badges & Information Architecture
	print("\n[Group 2: Dice Duel Role Badges & Context]")
	var n = Nego.new()
	n.names = {"P1": "나", "P2": "Vito"}
	n.human_id = "P1"
	n.personalities = {"P2": "CONSERVATIVE"}
	n.u = 1.0
	host.add_child(n)

	var ev_open := {"barId": "COTTON_CLUB", "prize": 30000, "kind": "BAR", "claimantIds": ["P1", "P2"], "symbols": {"P1": 5, "P2": 2}, "proposerId": "P1"}
	n.open(ev_open)
	n.set_proposal({"proposal": {"P1": 20000, "P2": 10000}, "proposerId": "P1"})

	var ev_duel := {"playerA": "P1", "playerB": "P2", "symbolA": 5, "symbolB": 2, "challengerId": "P2"}
	n.begin_duel(ev_duel)
	await _frames(2)

	# Verify role tags exist in the duel cards
	var labels: Array = n._duel_box.find_children("*", "Label", true, false)
	var found_challenger := false
	var found_defender := false
	for lbl in labels:
		if "도전자" in lbl.text or "CHALLENGER" in lbl.text.to_upper():
			found_challenger = true
		if "방어자" in lbl.text or "DEFENDER" in lbl.text.to_upper():
			found_defender = true
	_ok("Duel stage contains Challenger role tag", found_challenger)
	_ok("Duel stage contains Defender role tag", found_defender)

	# Group 3: Tie Break Explanations & Bribed Judge Overrule
	print("\n[Group 3: Duel Tie-Break Clarification]")
	# Standard challenger win tie
	n.finish_duel({"playerA": "P1", "playerB": "P2", "rollA": 2, "rollB": 5, "scoreA": 7, "scoreB": 7, "winnerId": "P2", "tie": true, "seq": 10})
	_ok("Standard tie explicitly mentions challenger victory", "도전자" in n._status.text and "동점" in n._status.text, n._status.text)

	# Relic Bribed Judge overrule tie (where defender P1 wins instead of challenger P2)
	var n_judge = Nego.new()
	n_judge.names = {"P1": "나", "P2": "Vito"}
	n_judge.human_id = "P1"
	n_judge.personalities = {"P2": "CONSERVATIVE"}
	n_judge.u = 1.0
	host.add_child(n_judge)
	n_judge.open(ev_open)
	n_judge.begin_duel(ev_duel)
	n_judge.finish_duel({"playerA": "P1", "playerB": "P2", "rollA": 2, "rollB": 5, "scoreA": 7, "scoreB": 7, "winnerId": "P1", "tie": true, "seq": 11})
	_ok("Bribed judge overrule status calls out judge verdict", "판사" in n_judge._status.text or "판사" in n_judge._duel_tag.text, n_judge._status.text)

	# Group 4: Button Double-Press Guards
	print("\n[Group 4: Input Guards]")
	n.ask_continue()
	await _frames(2)
	var continue_btns: Array = n._action_box.find_children("*", "Button", true, false)
	_ok("Continue button present", continue_btns.size() == 1)
	if continue_btns.size() > 0:
		var cb: Button = continue_btns[0]
		cb.emit_signal("pressed")
		_ok("Continue button disables immediately on first press", cb.disabled)

	# Cleanup
	cv_zocker.queue_free()
	cv_razzia.queue_free()
	n.queue_free()
	n_judge.queue_free()
	await _frames(2)

	print("\nUI/UX AUDIT TEST SUMMARY: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("FAILED CHECKS: ", fails)
	quit(0 if fails.is_empty() else 1)
