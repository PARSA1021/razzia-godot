extends SceneTree

const Nego = preload("res://ui/nego_panel.gd")
const Settings = preload("res://ui/settings.gd")

func _initialize() -> void:
	var checks := 0
	var fails: Array = []
	var ok := func(desc: String, cond: bool):
		checks += 1
		if not cond: fails.append(desc)
		print("  %s: %s" % ["ok" if cond else "FAIL", desc])

	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(1280, 800)
	root.add_child(root_ctrl)
	var nego := Nego.new()
	root_ctrl.add_child(nego)
	nego.setup({"P1": "나", "P2": "Vito"}, "P1", 1.0, 1280)
	nego.neg = {"claimantIds": ["P1", "P2"], "symbols": {"P1": 5, "P2": 2}}

	# 1. Test beginner_hints == false
	Settings.beginner_hints = false
	var view_resp := {
		"you": "P2",
		"negotiation": {
			"barId": "HAVANA_BAR",
			"proposerId": "P1",
			"proposal": {"P1": 20000, "P2": 10000},
			"symbols": {"P1": 5, "P2": 2}
		}
	}
	nego.ask_response(view_resp)
	var all_labels := []
	var collect := func(n: Node, c: Callable) -> void:
		if n is Label: all_labels.append(n.text)
		for ch in n.get_children(): c.call(ch, c)
	collect.call(nego._action_box, collect)
	var joined_off := " ".join(all_labels)
	ok.call("hints OFF: no win rate in ask_response", not ("승률" in joined_off or "%" in joined_off))
	ok.call("hints OFF: no EV in ask_response", not ("기대값" in joined_off))
	ok.call("hints OFF: no better note in ask_response", not ("유리" in joined_off))

	# 2. Test beginner_hints == true
	Settings.beginner_hints = true
	nego.ask_response(view_resp)
	all_labels.clear()
	collect.call(nego._action_box, collect)
	var joined_on := " ".join(all_labels)
	ok.call("hints ON: win rate present in ask_response", "승률" in joined_on)
	ok.call("hints ON: EV present in ask_response", "기대값" in joined_on)

	# 3. Test proposal hints & 추천 button
	var prop_view := {
		"you": "P1",
		"negotiation": {
			"barId": "HAVANA_BAR",
			"prize": 30000,
			"claimantIds": ["P1", "P2"],
			"symbols": {"P1": 5, "P2": 2}
		}
	}
	Settings.beginner_hints = false
	nego.ask_proposal(prop_view)
	all_labels.clear()
	collect.call(nego._action_box, collect)
	var prop_off := " ".join(all_labels)
	ok.call("hints OFF: no recommendation hints in proposal", not ("기대값" in prop_off))
	var sugg_off := false
	for b in nego._action_box.find_children("*", "Button", true, false):
		if b.text == "추천" or "추천" in b.text: sugg_off = true
	ok.call("hints OFF: 추천 button not present", not sugg_off)

	Settings.beginner_hints = true
	nego.ask_proposal(prop_view)
	all_labels.clear()
	collect.call(nego._action_box, collect)
	var prop_on := " ".join(all_labels)
	ok.call("hints ON: recommendation hint present in proposal", "기대값" in prop_on)
	var sugg_on := false
	for b in nego._action_box.find_children("*", "Button", true, false):
		if b.text == "추천" or "추천" in b.text: sugg_on = true
	ok.call("hints ON: 추천 button present", sugg_on)

	print("BEGINNER HINTS TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
