extends Control
## RAZZIA (Phase 26): the raid as a short noir shot, drawn in one layer over the table.
##   1  the street goes dark; the raided venue stays in the light
##   2  two police searchlights sweep in from the street corners - one red, one blue - and settle on the venue
##      (soft light that swells once per colour: never a strobe, docs/05 photosensitivity rule)
##   3  the police card slams down on the venue, the table jolts
##   4  a rubber stamp "RAZZIA" hits the middle of the screen, with what this raid means in one line underneath
## Every value below is driven by the caller's tweens (game_screen._fx_razzia), so SKIP / reduced motion / speed settings
## and the timing contract stay in one place. Presentation only.

const T = preload("res://ui/tokens.gd")

var target := Rect2()          # the raided venue (this control's coordinates); empty = centre of the screen
var caption := ""              # e.g. "도박꾼 2명 퇴장  ·  판돈 $45,000 → 경찰 1명"
var venue := ""                # venue name for the stamp's top line
var u := 1.0

var dark := 0.0: set = _s_dark            # 0..1 the street goes dark
var beams := 0.0: set = _s_beams          # 0..1 searchlights sweep in and settle
var red := 0.0: set = _s_red              # 0..1 the red light swells (once)
var blue := 0.0: set = _s_blue            # 0..1 the blue light swells (once)
var card := 0.0: set = _s_card            # 0..1 the police card falls onto the venue
var stamp := 0.0: set = _s_stamp          # 0..1 the stamp lands
var ink := 0.0: set = _s_ink              # 0..1 caption types in

var _card_tex: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_tex = T.art("razzia")


func _s_dark(v: float) -> void:
	dark = v
	queue_redraw()


func _s_beams(v: float) -> void:
	beams = v
	queue_redraw()


func _s_red(v: float) -> void:
	red = v
	queue_redraw()


func _s_blue(v: float) -> void:
	blue = v
	queue_redraw()


func _s_card(v: float) -> void:
	card = v
	queue_redraw()


func _s_stamp(v: float) -> void:
	stamp = v
	queue_redraw()


func _s_ink(v: float) -> void:
	ink = v
	queue_redraw()


func _focus() -> Rect2:
	if target.has_area():
		return target
	return Rect2(size / 2.0 - Vector2(80, 110) * u, Vector2(160, 220) * u)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var f := _focus()
	# 1 the street goes dark, the venue keeps a pool of light (soft edge: a few widening frames)
	var a := 0.62 * dark
	if a > 0.001:
		var hole := f.grow(14.0 * u)
		draw_rect(Rect2(0, 0, w, hole.position.y), Color(0, 0, 0, a))
		draw_rect(Rect2(0, hole.end.y, w, h - hole.end.y), Color(0, 0, 0, a))
		draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(hole.end.x, hole.position.y, w - hole.end.x, hole.size.y), Color(0, 0, 0, a))
		for i in range(6):
			draw_rect(hole.grow(-2.0 * i * u), Color(0, 0, 0, a * 0.12 * (6 - i) / 6.0), false, 3.0 * u)
	# 2 searchlights: a cone from each lower corner; the aim sweeps across the table and settles on the venue
	if beams > 0.001:
		var settle := clampf(beams, 0.0, 1.0)
		var aim := f.get_center() + Vector2(0, -f.size.y * 0.1)
		for side in [-1.0, 1.0]:
			# the lamps sit low at the two street corners (the squad cars), so the beams cross the table on the diagonal
			var src := Vector2(w * (0.5 + 0.58 * side), h * 1.06)
			var sweep_from := Vector2(w * (0.5 - 0.3 * side), h * 0.12)
			var hit := sweep_from.lerp(aim, ease(settle, 0.4))
			var dir := (hit - src).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var reach := src.distance_to(hit) + f.size.y * 0.55
			var spread := maxf(f.size.x, 140.0 * u) * 0.62
			var tip := src + dir * reach
			var col: Color = Color(1.0, 0.22, 0.16) if side < 0 else Color(0.28, 0.48, 1.0)
			var level: float = red if side < 0 else blue
			var alpha := (0.16 + 0.30 * level) * minf(1.0, beams * 2.0)
			# the cone: narrow at the lamp, wide where it lands; brighter near the lamp
			draw_polygon(PackedVector2Array([src - nrm * 10.0 * u, src + nrm * 10.0 * u, tip + nrm * spread, tip - nrm * spread]),
				PackedColorArray([Color(col, alpha * 1.6), Color(col, alpha * 1.6), Color(col, alpha * 0.35), Color(col, alpha * 0.35)]))
			# a hot core down the middle of the beam
			draw_polygon(PackedVector2Array([src - nrm * 3.0 * u, src + nrm * 3.0 * u, tip + nrm * spread * 0.35, tip - nrm * spread * 0.35]),
				PackedColorArray([Color(col.lightened(0.4), alpha), Color(col.lightened(0.4), alpha), Color(col, alpha * 0.2), Color(col, alpha * 0.2)]))
			# the lit spot where the beam lands
			for i in range(5):
				draw_circle(hit, spread * (0.25 + 0.14 * i), Color(col, alpha * 0.22))
	# 3 the police card on the venue
	if card > 0.001 and _card_tex != null:
		var k := 1.0 + 0.7 * (1.0 - ease(card, 0.35))
		var cs := Vector2(f.size.x * 0.62, f.size.x * 0.62 * 1.38)
		cs = cs.min(Vector2(f.size.y * 0.72 / 1.38, f.size.y * 0.72))
		var c := f.get_center() + Vector2(0, f.size.y * 0.05)
		draw_set_transform(c, deg_to_rad(-9.0 + 6.0 * (1.0 - card)), Vector2(k, k))
		var r := Rect2(-cs / 2.0, cs)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1a0d0b")
		sb.border_color = Color("e0392b")
		sb.set_border_width_all(maxi(2, int(3.0 * u)))
		sb.set_corner_radius_all(int(8.0 * u))
		sb.shadow_color = Color(0, 0, 0, 0.6 * card)
		sb.shadow_size = int(10.0 * u)
		sb.draw(get_canvas_item(), r)
		T.draw_cover(self, _card_tex, r.grow(-5.0 * u), 0.3, Color(1, 1, 1, minf(1.0, card * 1.6)))
		var lf := T.font("title", 800)
		var lp := int(clampf(cs.x * 0.15, 11.0, 22.0))
		draw_string(lf, Vector2(r.position.x, r.end.y - lp * 0.5), "RAZZIA", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, lp, Color("ff6b5a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 4 the rubber stamp + what it means
	if stamp > 0.001:
		var sf := T.font("stamp")
		var px := int(round(104.0 * u))
		var word := "RAZZIA"
		var tw := sf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var box := Vector2(tw + 70.0 * u, px * 1.15 + 54.0 * u)
		var k2 := 1.0 + 1.3 * (1.0 - ease(stamp, 0.3))
		var al := minf(1.0, stamp * 2.2)
		var ink_col := Color(0.86, 0.17, 0.13, 0.92 * al)
		draw_set_transform(Vector2(w / 2.0, h * 0.5), deg_to_rad(-8.0), Vector2(k2, k2))
		var outer := Rect2(-box / 2.0, box)
		# a soft paper shadow so the stamp reads over anything
		draw_rect(outer.grow(16.0 * u), Color(0, 0, 0, 0.35 * al))
		draw_rect(outer, ink_col, false, 7.0 * u)
		draw_rect(outer.grow(-12.0 * u), ink_col, false, 2.5 * u)
		if venue != "":
			var vf := T.font("title", 800)
			var vp := int(round(22.0 * u))
			draw_string(vf, Vector2(outer.position.x, outer.position.y + 12.0 * u + vp), venue.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, outer.size.x, vp, ink_col)
		T.note_text(self, px, word)
		draw_string(sf, Vector2(-tw / 2.0, outer.end.y - 22.0 * u), word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink_col)
		# worn ink: a fixed scatter of paper-coloured specks (same every time, so it never flickers)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7151
		for i in range(90):
			var p := Vector2(rng.randf_range(outer.position.x, outer.end.x), rng.randf_range(outer.position.y, outer.end.y))
			draw_circle(p, rng.randf_range(0.8, 2.6) * u, Color(0.08, 0.05, 0.04, 0.55 * al))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ink > 0.001 and caption != "":
		var cf := T.font("ui", 800)
		var cp := int(round(T.fs(22.0 * u)))
		var shown := caption.substr(0, int(ceil(caption.length() * clampf(ink, 0.0, 1.0))))
		var cy := h * 0.5 + 125.0 * u
		var cw := cf.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cp).x
		var plate := Rect2(Vector2((w - cw) / 2.0 - 20.0 * u, cy - cp - 8.0 * u), Vector2(cw + 40.0 * u, cp + 22.0 * u))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.04, 0.03, 0.02, 0.86)
		sb2.border_color = Color(0.86, 0.17, 0.13, 0.8)
		sb2.set_border_width_all(1)
		sb2.set_corner_radius_all(int(6.0 * u))
		sb2.draw(get_canvas_item(), plate)
		T.note_text(self, cp, caption)
		draw_string(cf, Vector2((w - cw) / 2.0, cy + 2.0 * u), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, cp, Color("f3ead6"))
