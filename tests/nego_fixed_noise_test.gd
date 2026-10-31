extends SceneTree
## Tests for negotiation fixed noise, proposer advantage presets, and threshold protection.
## Run with:
##   godot --headless --path . --fixed-fps 60 --script res://tests/nego_fixed_noise_test.gd

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
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)

	print("=== [1] Preset Rounding Rule (Proposer Advantage) ===")
	# 1. $30,000 with 1 opponent
	# 25% = $7,500. Remainder is $2,500 (exact midpoint). Floored to $5,000 (proposer keeps extra).
	var s30_25 := Nego.calc_preset_opponent_share(30000, 0.25, 1)
	_ok("30k at 25%: midpoint $7,500 floors opponent to $5,000", s30_25 == 5000, str(s30_25))

	# 50% = $15,000
	var s30_50 := Nego.calc_preset_opponent_share(30000, 0.50, 1)
	_ok("30k at 50%: exact $15,000", s30_50 == 15000, str(s30_50))

	# 75% = $22,500. Remainder $2,500. Floored to $20,000
	var s30_75 := Nego.calc_preset_opponent_share(30000, 0.75, 1)
	_ok("30k at 75%: midpoint $22,500 floors opponent to $20,000", s30_75 == 20000, str(s30_75))

	# 2. $50,000 with 1 opponent
	# 25% = $12,500. Remainder $2,500. Floored to $10,000
	var s50_25 := Nego.calc_preset_opponent_share(50000, 0.25, 1)
	_ok("50k at 25%: midpoint $12,500 floors opponent to $10,000", s50_25 == 10000, str(s50_25))

	# 50% = $25,000
	var s50_50 := Nego.calc_preset_opponent_share(50000, 0.50, 1)
	_ok("50k at 50%: exact $25,000", s50_50 == 25000, str(s50_50))

	# 75% = $37,500. Remainder $2,500. Floored to $35,000
	var s50_75 := Nego.calc_preset_opponent_share(50000, 0.75, 1)
	_ok("50k at 75%: midpoint $37,500 floors opponent to $35,000", s50_75 == 35000, str(s50_75))

	# 3. Minimum rule: 25% < $5,000 -> minimum $5,000
	# $15,000 at 25% = $3,750 < $5,000 -> minimum $5,000
	var s15_25 := Nego.calc_preset_opponent_share(15000, 0.25, 1)
	_ok("15k at 25%: $3,750 enforces minimum $5,000", s15_25 == 5000, str(s15_25))

	print("=== [2] Negotiation Fixed Noise & Slider Repeatability ===")
	var nego = Nego.new()
	nego.names = {"P1": "나", "P2": "Vito"}
	nego.human_id = "P1"
	nego.personalities = {"P2": "CONSERVATIVE"}
	host.add_child(nego)
	nego.visible = true
	await _frames(2)

	var neg_event := {
		"barId": "COLIBRI",
		"claimantIds": ["P1", "P2"],
		"kind": "ZOCKER",
		"prize": 40000,
		"proposerId": "P1",
		"symbols": {"P1": 4, "P2": 2},
		"seq": 10
	}
	nego.open(neg_event)
	await _frames(5)

	var view := {
		"you": "P1",
		"negotiation": neg_event
	}

	# Launch proposal prompt asynchronously
	var prop_task := func():
		await nego.ask_proposal(view)
	prop_task.call()
	await _frames(5)

	var sliders: Array = nego._action_box.find_children("*", "HSlider", true, false)
	_ok("slider found in action box", sliders.size() == 1, str(sliders.size()))
	var sl: HSlider = sliders[0]

	# Record reaction at $10,000, change to $25,000, change back to $10,000
	sl.value = 10000
	await _frames(2)
	var face: Control = nego._row_faces.get("P2", null)
	_ok("opponent row face portrait exists", face != null)
	var rot_10k_first := face.rotation_degrees
	var mod_10k_first := face.modulate

	# Find reaction label
	var labels: Array = nego._action_box.find_children("*", "Label", true, false)
	var rx_text_first := ""
	for l in labels:
		var txt: String = (l as Label).text
		if txt.begins_with("\"") and txt.ends_with("\""):
			rx_text_first = txt
			break
	_ok("reaction speech line displayed", rx_text_first != "", rx_text_first)

	# Change slider to 25k
	sl.value = 25000
	await _frames(2)
	var rot_25k := face.rotation_degrees
	_ok("reaction changes at higher amount ($25k)", rot_25k != rot_10k_first or face.modulate != mod_10k_first)

	# Change slider to 35k
	sl.value = 35000
	await _frames(2)

	# Change slider BACK to 10k: MUST BE IDENTICAL (noise is fixed, not re-rolled!)
	sl.value = 10000
	await _frames(2)
	var rot_10k_second := face.rotation_degrees
	var mod_10k_second := face.modulate
	var rx_text_second := ""
	for l in nego._action_box.find_children("*", "Label", true, false):
		var txt: String = (l as Label).text
		if txt.begins_with("\"") and txt.ends_with("\""):
			rx_text_second = txt
			break

	_ok("fixed noise: face rotation at $10k is exactly identical after moves", is_equal_approx(rot_10k_first, rot_10k_second))
	_ok("fixed noise: face modulate at $10k is exactly identical after moves", mod_10k_first == mod_10k_second)
	_ok("fixed noise: speech reaction line at $10k is 100% identical after moves", rx_text_first == rx_text_second, rx_text_second)

	print("=== [3] Gamepad / Preset Button Activation ===")
	# Find presets
	var hard_btn: Button = null
	var half_btn: Button = null
	var gen_btn: Button = null
	for b in nego._action_box.find_children("*", "Button", true, false):
		var btn := b as Button
		if "25%" in btn.text:
			hard_btn = btn
		elif "50%" in btn.text:
			half_btn = btn
		elif "75%" in btn.text:
			gen_btn = btn

	_ok("found preset buttons 25%, 50%, 75%", hard_btn != null and half_btn != null and gen_btn != null)

	# Click hard (25%)
	hard_btn.emit_signal("pressed")
	await _frames(2)
	_ok("preset 25% sets slider to $10k (25% of 40k)", sl.value == 10000, str(sl.value))

	# Click half (50%)
	half_btn.emit_signal("pressed")
	await _frames(2)
	_ok("preset 50% sets slider to $20k (50% of 40k)", sl.value == 20000, str(sl.value))

	# Click gen (75%)
	gen_btn.emit_signal("pressed")
	await _frames(2)
	_ok("preset 75% sets slider to $30k (75% of 40k)", sl.value == 30000, str(sl.value))

	# Clean up
	nego.decided.emit({"P1": 20000, "P2": 20000})
	await _frames(2)
	nego.close()
	await _frames(2)

	print("\n=== SUMMARY ===")
	print("%d checks, %d failed" % [checks, fails.size()])
	if fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%s)" % str(fails))
		quit(1)
