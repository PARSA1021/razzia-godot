extends Control
## Round portrait of an AI character (Phase 13c) with live subtle breathing and emotion states.
## TEMPORARY art drawn in code; to use real art, drop a square PNG at
## res://assets/characters/<CONSERVATIVE|OPPORTUNIST|AGGRESSIVE>.png or res://assets/characters/<name>.png.

const T = preload("res://ui/tokens.gd")
const Settings = preload("res://ui/settings.gd")
const ThemeAssets = preload("res://ui/theme_assets.gd")

const COLORS := {"CONSERVATIVE": Color("4f8fd0"), "OPPORTUNIST": Color("d6b274"), "AGGRESSIVE": Color("c9503f")}

## Emotion palettes: frame highlight, frame accent, and subtle inner atmosphere glow
const EMOTIONS := {
	"NEUTRAL": {"frame": T.GOLD, "accent": T.GOLD_DIM, "glow": Color(0, 0, 0, 0)},
	"CONFIDENT": {"frame": Color("f6d365"), "accent": Color("fda085"), "glow": Color(1.0, 0.85, 0.4, 0.28)},
	"NERVOUS": {"frame": Color("7fa1c3"), "accent": Color("4e6b8c"), "glow": Color(0.3, 0.5, 0.8, 0.22)},
	"ANGRY": {"frame": Color("e64c3c"), "accent": Color("962d22"), "glow": Color(0.9, 0.2, 0.15, 0.28)},
	"DEFEATED": {"frame": Color("5c5042"), "accent": Color("3b3026"), "glow": Color(0.0, 0.0, 0.0, 0.35)},
	"TRIUMPHANT": {"frame": Color("ffd700"), "accent": Color("fff0a0"), "glow": Color(1.0, 0.9, 0.3, 0.45)},
}

var personality := "CONSERVATIVE": set = _set_p
var character := "": set = _set_c          # optional name of a named character with its own art (assets/characters/<name>.png)
var emotion := "NEUTRAL": set = _set_emotion
var breathing_enabled := true

var _breath_time := 0.0
var _breath_offset := Vector2.ZERO
var _blink_timer := 3.5
var _blinking := false
var _blink_duration := 0.0


func _set_c(v) -> void:
	character = str(v)
	queue_redraw()


func _set_p(v) -> void:
	personality = str(v)
	queue_redraw()


func _set_emotion(v) -> void:
	emotion = str(v)
	queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 40)


func _process(delta: float) -> void:
	if not visible:
		return
	if Settings.reduce_motion or not breathing_enabled:
		if _breath_offset != Vector2.ZERO or _blinking:
			_breath_offset = Vector2.ZERO
			_blinking = false
			queue_redraw()
		return

	_breath_time += delta
	var s := minf(size.x, size.y)
	# subtle breathing: gentle vertical movement (<1.5% of size), keeping aspect ratio intact
	var breath_y := sin(_breath_time * 2.2) * (s * 0.012)
	var jitter_x := 0.0
	if emotion == "NERVOUS":
		# micro nervous tremor during high stakes
		jitter_x = sin(_breath_time * 18.0) * (s * 0.008)
	_breath_offset = Vector2(jitter_x, breath_y)

	# Blinking logic (every 3.5 - 5.0 seconds for 0.12s)
	if _blinking:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			_blinking = false
			_blink_timer = 3.5 + fposmod(float(hash(character)), 1.5)
			queue_redraw()
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blinking = true
			_blink_duration = 0.12
			queue_redraw()

	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return
	paint(self, Vector2(size.x, size.y) / 2.0, s / 2.0, personality, character, emotion, _breath_offset, _blinking)


## Draws the portrait on any CanvasItem (used by the player chips too). Real art at res://assets/characters/<personality>.png wins.
static func paint(ci: CanvasItem, c: Vector2, r: float, pers: String, character: String = "", p_emotion: String = "NEUTRAL", p_breath_offset: Vector2 = Vector2.ZERO, p_blinking: bool = false) -> void:
	var s := r * 2.0
	var col: Color = COLORS.get(pers, T.BRASS)
	var emo: Dictionary = EMOTIONS.get(p_emotion, EMOTIONS["NEUTRAL"])
	var path := ThemeAssets.resolve_art_path("character", pers)
	if character != "":
		# big portraits get the whole bust (characters_full), small ones the face close-up (characters)
		var big := ThemeAssets.resolve_art_path("character_full", character)
		var close := ThemeAssets.resolve_art_path("character", character)
		if r >= 30.0 and big != "":
			path = big
		elif close != "":
			path = close
	ci.draw_circle(c, r, Color("1a140d"))
	if emo["glow"].a > 0.0:
		ci.draw_circle(c, r * 0.94, emo["glow"])
	var c_face := c + p_breath_offset
	if path != "":
		var tex: Texture2D = _tex(path)
		ci.draw_texture_rect(tex, Rect2(c_face - Vector2(r, r) * 0.92, Vector2(r, r) * 1.84), false)
		if p_blinking:
			var eye_y := c_face.y - r * 0.08
			ci.draw_line(Vector2(c.x - r * 0.35, eye_y), Vector2(c.x + r * 0.35, eye_y), Color(0.08, 0.06, 0.05, 0.75), maxf(2.0, r * 0.06), true)
	else:
		_figure(ci, c_face, r, col, pers, p_blinking)
	var rw := clampf(s * 0.06, 2.0, 7.0)
	ci.draw_arc(c, r - rw / 2.0, 0, TAU, 64, emo["accent"], rw, true)
	ci.draw_arc(c, r - rw / 2.0, 0, TAU, 64, emo["frame"], maxf(1.0, rw * 0.4), true)
	if p_emotion == "TRIUMPHANT":
		ci.draw_arc(c, r + rw * 0.25, 0, TAU, 48, Color(1, 0.85, 0.3, 0.45), rw * 0.4, true)
	elif p_emotion == "ANGRY":
		ci.draw_arc(c, r - rw * 1.2, -PI * 0.8, -PI * 0.2, 24, Color(0.9, 0.2, 0.15, 0.4), rw * 0.6, true)


static var _cache := {}


## Portrait art as an ImageTexture: a lazily uploaded CompressedTexture2D could draw white on its very first frame.
static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		var t: Texture2D = load(path)
		_cache[path] = ImageTexture.create_from_image(t.get_image())
	return _cache[path]


static func _figure(ci: CanvasItem, c: Vector2, r: float, col: Color, pers: String, blinking: bool = false) -> void:
	var suit := Color("1a1714")
	var skin := Color("d9b48f")
	# shoulders + shirt + tie (clipped to the circle by staying inside it)
	var sh := PackedVector2Array([c + Vector2(-0.78, 0.9) * r, c + Vector2(-0.6, 0.45) * r, c + Vector2(0.6, 0.45) * r, c + Vector2(0.78, 0.9) * r])
	ci.draw_colored_polygon(sh, suit)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.18, 0.45) * r, c + Vector2(0.18, 0.45) * r, c + Vector2(0, 0.85) * r]), Color("e8e0d0"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.07, 0.5) * r, c + Vector2(0.07, 0.5) * r, c + Vector2(0.05, 0.85) * r, c + Vector2(-0.05, 0.85) * r]), col)
	# head
	ci.draw_circle(c + Vector2(0, -0.08) * r, 0.42 * r, skin)
	var eye_y := -0.1
	match pers:
		"CONSERVATIVE":
			# fedora with a band, round glasses, calm flat mouth
			ci.draw_rect(Rect2(c + Vector2(-0.7, -0.4) * r, Vector2(1.4, 0.13) * r), Color("2b2a33"))
			ci.draw_rect(Rect2(c + Vector2(-0.4, -0.78) * r, Vector2(0.8, 0.42) * r), Color("2b2a33"))
			ci.draw_rect(Rect2(c + Vector2(-0.4, -0.5) * r, Vector2(0.8, 0.09) * r), col)
			for sx in [-1.0, 1.0]:
				if blinking:
					ci.draw_line(c + Vector2((0.17 * sx - 0.08), eye_y) * r, c + Vector2((0.17 * sx + 0.08), eye_y) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
				else:
					ci.draw_arc(c + Vector2(0.17 * sx, eye_y) * r, 0.12 * r, 0, TAU, 16, Color("2a2018"), maxf(1.5, r * 0.05), true)
			ci.draw_line(c + Vector2(-0.12, 0.15) * r, c + Vector2(0.12, 0.15) * r, Color("5a3a2a"), maxf(1.5, r * 0.05), true)
		"OPPORTUNIST":
			# flat cap, one raised brow, sideways smile
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, -0.3) * r, c + Vector2(-0.3, -0.7) * r, c + Vector2(0.4, -0.7) * r, c + Vector2(0.6, -0.3) * r]), Color("5b4a30"))
			ci.draw_rect(Rect2(c + Vector2(-0.1, -0.35) * r, Vector2(0.7, 0.08) * r), Color("3a2e1c"))
			if blinking:
				ci.draw_line(c + Vector2(-0.24, eye_y) * r, c + Vector2(-0.08, eye_y) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
				ci.draw_line(c + Vector2(0.08, eye_y) * r, c + Vector2(0.24, eye_y) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
			else:
				ci.draw_circle(c + Vector2(-0.16, eye_y) * r, 0.055 * r, Color("2a2018"))
				ci.draw_circle(c + Vector2(0.16, eye_y) * r, 0.055 * r, Color("2a2018"))
			ci.draw_line(c + Vector2(0.08, -0.22) * r, c + Vector2(0.26, -0.27) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
			ci.draw_arc(c + Vector2(0.03, 0.04) * r, 0.2 * r, 0.25, 2.3, 12, Color("5a3a2a"), maxf(1.5, r * 0.05), true)
			ci.draw_circle(c + Vector2(0.62, 0.62) * r, 0.1 * r, col)       # coin in the lapel
		"AGGRESSIVE":
			# slicked hair, angry brows, scar, frown
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.44, -0.2) * r, c + Vector2(-0.38, -0.62) * r, c + Vector2(0.1, -0.7) * r, c + Vector2(0.44, -0.4) * r, c + Vector2(0.44, -0.2) * r, c + Vector2(0.0, -0.38) * r]), Color("141010"))
			ci.draw_line(c + Vector2(-0.28, -0.22) * r, c + Vector2(-0.06, -0.14) * r, Color("2a2018"), maxf(2.0, r * 0.08), true)
			ci.draw_line(c + Vector2(0.28, -0.22) * r, c + Vector2(0.06, -0.14) * r, Color("2a2018"), maxf(2.0, r * 0.08), true)
			if blinking:
				ci.draw_line(c + Vector2(-0.24, -0.07) * r, c + Vector2(-0.08, -0.07) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
				ci.draw_line(c + Vector2(0.08, -0.07) * r, c + Vector2(0.24, -0.07) * r, Color("2a2018"), maxf(1.5, r * 0.05), true)
			else:
				ci.draw_circle(c + Vector2(-0.16, -0.07) * r, 0.05 * r, Color("2a2018"))
				ci.draw_circle(c + Vector2(0.16, -0.07) * r, 0.05 * r, Color("2a2018"))
			ci.draw_line(c + Vector2(0.18, -0.02) * r, c + Vector2(0.3, 0.2) * r, Color("a04030"), maxf(1.5, r * 0.05), true)
			ci.draw_arc(c + Vector2(0, 0.22) * r, 0.14 * r, PI + 0.4, TAU - 0.4, 10, Color("5a3a2a"), maxf(1.5, r * 0.05), true)

