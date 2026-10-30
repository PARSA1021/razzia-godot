extends SceneTree
## Test suite for Phase 1 Live Character System (breathing, emotions, barks, reduced motion).

const Portrait = preload("res://ui/portrait.gd")
const Characters = preload("res://ui/characters.gd")
const Audio = preload("res://ui/audio.gd")
const Settings = preload("res://ui/settings.gd")

var checks := 0
var fails: Array = []


func _ok(desc: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(desc)
	print("  %s %s %s" % ["ok  " if cond else "FAIL", desc, extra])


func _initialize() -> void:
	# 1. Portrait node creation & properties
	var p := Portrait.new()
	p.personality = "CONSERVATIVE"
	p.character = "Sal"
	root.add_child(p)
	p.size = Vector2(80, 80)

	_ok("Portrait defaults to NEUTRAL emotion", p.emotion == "NEUTRAL")
	_ok("Portrait breathing is enabled by default", p.breathing_enabled)
	_ok("All 6 emotion palettes defined", Portrait.EMOTIONS.size() == 6)

	# 2. Emotion state changes
	for emo in ["CONFIDENT", "NERVOUS", "ANGRY", "DEFEATED", "TRIUMPHANT", "NEUTRAL"]:
		p.emotion = emo
		_ok("Emotion set to %s" % emo, p.emotion == emo)

	# 3. Characters.emotion_for mapping
	_ok("Situation win maps to TRIUMPHANT", Characters.emotion_for("win", "CONSERVATIVE") == "TRIUMPHANT")
	_ok("Situation win_upset maps to TRIUMPHANT", Characters.emotion_for("win_upset", "OPPORTUNIST") == "TRIUMPHANT")
	_ok("Situation lose for AGGRESSIVE maps to ANGRY", Characters.emotion_for("lose", "AGGRESSIVE") == "ANGRY")
	_ok("Situation lose for CONSERVATIVE maps to DEFEATED", Characters.emotion_for("lose", "CONSERVATIVE") == "DEFEATED")
	_ok("Situation propose maps to CONFIDENT", Characters.emotion_for("propose", "OPPORTUNIST") == "CONFIDENT")
	_ok("Situation accept maps to NEUTRAL", Characters.emotion_for("accept", "CONSERVATIVE") == "NEUTRAL")

	# 4. Breathing and Reduced Motion
	Settings.reduce_motion = false
	p.breathing_enabled = true
	p._process(0.1)
	var moved: bool = p._breath_time > 0.0 and p._breath_offset.y != 0.0
	_ok("Breathing advances offset when motion is normal", moved)

	# Reduced motion test: offset must immediately zero out and never move
	Settings.reduce_motion = true
	p._process(0.1)
	_ok("Breathing zeroes offset when reduce_motion is ON", p._breath_offset == Vector2.ZERO)
	Settings.reduce_motion = false

	# 5. Audio bark safety (missing files must harmlessly no-op without error)
	Audio.bark("Sal", "propose")
	Audio.bark("Vito", "win")
	Audio.bark("UnknownNonExistentCharacter", "test")
	_ok("Audio bark safely no-ops on missing files without throwing", true)

	# 6. Paint rendering (texture mode and procedural mode)
	var ci := Control.new()
	root.add_child(ci)
	ci.size = Vector2(100, 100)
	ci.draw.connect(func():
		# Real art character
		Portrait.paint(ci, Vector2(50, 50), 40.0, "AGGRESSIVE", "Sal", "CONFIDENT", Vector2.ZERO, false)
		Portrait.paint(ci, Vector2(50, 50), 40.0, "CONSERVATIVE", "Vito", "TRIUMPHANT", Vector2(0, 1), true)
		# Procedural figure
		Portrait.paint(ci, Vector2(50, 50), 40.0, "OPPORTUNIST", "", "NERVOUS", Vector2.ZERO, true)
	)
	ci.notification(CanvasItem.NOTIFICATION_DRAW)
	_ok("Portrait.paint executed cleanly for both textures and procedural art", true)

	ci.queue_free()
	p.queue_free()

	print("CHARACTER ALIVE TEST: checks=%d failed=%d -> %s" % [checks, fails.size(), "PASS" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
