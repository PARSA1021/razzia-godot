extends Control
## One playing card (hand, table slot, bar stack). Everything is drawn in _draw(), so animations only tween
## ordinary Control properties (position / scale / rotation / modulate).
## Info is never colour-only (docs/05 §6): bar name, ZOCKER/RAZZIA text and the die pips are always drawn.

const T = preload("res://ui/tokens.gd")

signal pressed(card_view)
signal hover_changed(card_view)    # mouse entered / left (the hand fan reacts by lifting the card)

var card: Dictionary = {}          # {id, type, barId, dieSymbol}
var face_up := true: set = _set_face_up
var selected := false: set = _set_selected
var locked := false: set = _set_locked
var lock_text := "LOCKED"        # "" = a quiet veil instead of the plate (tutorial: "not this one yet")
var dimmed := false: set = _set_dimmed
var out_mark := false: set = _set_out
var interactive := false: set = _set_interactive
var hit_exclude: Control = null                  # a control the extended area must not cover (the PLAY CARD button)
var hit_extend := 0.0                              # px below the card that still count as "on the card" (a lifted card leaves its resting footprint)
var art_mini := false                              # card lying on a venue poster: art + die + player name (BarView sets it)
var caption := "": set = _set_caption       # small name tag (player name) under compact cards
var hovering := false
var lift := 0.0: set = _set_lift                # 0..1 shadow depth, tweened by the hand fan
var focused := false: set = _set_focused    # keyboard / gamepad focus (distinct from `selected`)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE     # only a card the player can pick takes the mouse (see _set_interactive)
	resized.connect(func(): pivot_offset = size / 2.0; queue_redraw())


func _set_face_up(v: bool) -> void:
	face_up = v
	queue_redraw()


func _set_lift(v: float) -> void:
	lift = v
	queue_redraw()


func _set_focused(v: bool) -> void:
	focused = v
	queue_redraw()


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _set_locked(v: bool) -> void:
	locked = v
	queue_redraw()


func _set_dimmed(v: bool) -> void:
	dimmed = v
	queue_redraw()


func _set_out(v: bool) -> void:
	out_mark = v
	queue_redraw()


func _set_caption(v: String) -> void:
	caption = v
	queue_redraw()


func is_razzia() -> bool:
	return card.get("type", "") == "RAZZIA"


## Mouse picking follows tree order, not z_index: a face-up card that is only on show (the hand during a negotiation / result board,
## cards lying on a venue) must not swallow clicks meant for the buttons and venues underneath it.
func _set_interactive(v: bool) -> void:
	interactive = v
	mouse_filter = Control.MOUSE_FILTER_PASS if v else Control.MOUSE_FILTER_IGNORE
	if not v and hovering:
		hovering = false
		queue_redraw()


## A hovered / selected card lifts off its slot: the strip it leaves behind still belongs to it, otherwise the pointer
## at the card's lower edge falls out of the lifted card, the card drops, re-enters and lifts again (clicks get lost).
func _has_point(point: Vector2) -> bool:
	if point.y > size.y and hit_exclude != null and is_instance_valid(hit_exclude) and hit_exclude.is_visible_in_tree():
		if hit_exclude.get_global_rect().has_point(get_global_transform() * point):
			return false
	return point.x >= 0.0 and point.x <= size.x and point.y >= 0.0 and point.y <= size.y + hit_extend


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovering = true
		queue_redraw()
		hover_changed.emit(self)
	elif what == NOTIFICATION_MOUSE_EXIT:
		hovering = false
		hover_changed.emit(self)
		queue_redraw()


func _sb(bg: Color, border: Color, bw: float, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(0, int(round(bw))))
	sb.set_corner_radius_all(maxi(0, int(round(radius))))
	sb.anti_aliasing = true
	return sb


func _text(s: String, pos: Vector2, font: Font, fsize: float, color: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var px := int(round(T.fs(fsize)))
	if width > 0.0:
		while px > int(round(fsize)) and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			px -= 1          # raised small text may never overflow its box: shrink back towards the design size
	T.note_text(self, px, s)
	draw_string(font, pos, s, align, width, px, color)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	if card.is_empty() or not face_up:
		_draw_back(w, h)
	elif art_mini and w >= 48.0:
		_draw_mini_face(w, h)
	elif w < 84.0:
		_draw_compact(w, h)
	else:
		_draw_face(w, h)
	if dimmed:
		_sb(Color(0, 0, 0, 0.58), Color(0, 0, 0, 0), 0, 8.0 * w / 130.0).draw(get_canvas_item(), Rect2(0, 0, w, h))
	if out_mark:
		var k := w / 130.0
		var f := T.font("stamp")
		var fs := maxf(9.0, 20.0 * k)
		draw_set_transform(Vector2(w / 2.0, h / 2.0), -0.35, Vector2.ONE)
		_sb(Color(0.1, 0.0, 0.0, 0.7), T.DANGER, maxf(1.0, 2.0 * k), 4.0 * k).draw(get_canvas_item(), Rect2(-w * 0.4, -fs * 0.8, w * 0.8, fs * 1.5))
		_text("OUT", Vector2(-w * 0.4, fs * 0.45), f, fs, T.DANGER, w * 0.8, HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selected:
		_sb(Color(0, 0, 0, 0), T.GOLD, maxf(2.0, 3.0 * w / 130.0), 9.0 * w / 130.0).draw(get_canvas_item(), Rect2(-3, -3, w + 6, h + 6))
	elif interactive and hovering:
		_sb(Color(0, 0, 0, 0), Color(T.GOLD, 0.55), 2.0, 9.0 * w / 130.0).draw(get_canvas_item(), Rect2(-2, -2, w + 4, h + 4))
	if focused:
		# cream double ring: visible on top of the gold "selected" ring, so focus and selection never look the same
		_sb(Color(0, 0, 0, 0), Color("fff4d6"), maxf(2.0, 2.5 * w / 130.0), 11.0 * w / 130.0).draw(get_canvas_item(), Rect2(-7, -7, w + 14, h + 14))
	if locked and lock_text == "":
		_sb(Color(0.02, 0.02, 0.015, 0.62), Color(0, 0, 0, 0), 0, 9.0 * w / 130.0).draw(get_canvas_item(), Rect2(0, 0, w, h))
	elif locked:
		var k2 := w / 130.0
		_sb(Color(0.05, 0.04, 0.02, 0.88), T.GOLD, 1.0, 4.0 * k2).draw(get_canvas_item(), Rect2(w * 0.12, h * 0.42, w * 0.76, 22.0 * k2))
		_text(lock_text, Vector2(w * 0.12, h * 0.42 + 16.0 * k2), T.font("title", 700), 12.0 * k2, T.GOLD, w * 0.76, HORIZONTAL_ALIGNMENT_CENTER)


## ----- full face (hand / big) -----
func _draw_face(w: float, h: float) -> void:
	var k := w / 130.0
	var col := T.bar_color(card["barId"])
	var razzia := is_razzia()
	# drop shadow (deeper and softer while lifted: the card reads as hovering above the table)
	var sh := 4.0 * k + 10.0 * k * lift
	_sb(Color(0, 0, 0, 0.45 + 0.1 * lift), Color(0, 0, 0, 0), 0, 9.0 * k).draw(get_canvas_item(), Rect2(2.5 * k + 3.0 * k * lift, sh, w, h))
	if lift > 0.01:
		_sb(Color(0, 0, 0, 0.18 * lift), Color(0, 0, 0, 0), 0, 14.0 * k).draw(get_canvas_item(), Rect2(-3.0 * k, sh + 3.0 * k, w + 8.0 * k, h + 6.0 * k))
	# body + bar-coloured frame (the border colour tells which bar the card belongs to)
	_sb(Color("1a140d") if not razzia else Color("14100c"), col, 4.0 * k, 9.0 * k).draw(get_canvas_item(), Rect2(0, 0, w, h))
	if razzia:
		# police inner warning border matching venue color
		draw_rect(Rect2(3.5 * k, 3.5 * k, w - 7.0 * k, h - 7.0 * k), Color(col.lightened(0.25), 0.65), false, maxf(1.0, 1.4 * k))
	# header
	var hf := T.font("title", 700)
	var header_rect := Rect2(5 * k, 5 * k, w - 10 * k, 22 * k)
	if razzia:
		draw_rect(header_rect, Color("3d0d0b", 0.90))
		draw_rect(header_rect, Color(T.DANGER, 0.85), false, maxf(1.0, k))
		var p_icon: Texture2D = T.police_icon()
		if p_icon != null:
			draw_texture_rect(p_icon, Rect2(8 * k, 8 * k, 16 * k, 16 * k), false, Color("ffd770"))
			draw_texture_rect(p_icon, Rect2(w - 24 * k, 8 * k, 16 * k, 16 * k), false, Color("ffd770"))
		else:
			_draw_police_star(Vector2(14 * k, 16.0 * k), 4.5 * k, T.GOLD)
			_draw_police_star(Vector2(w - 14 * k, 16.0 * k), 4.5 * k, T.GOLD)
	else:
		draw_rect(header_rect, Color(col, 0.32).darkened(0.25))
		draw_rect(header_rect, Color(col.lightened(0.3), 0.7), false, maxf(1.0, k))
		var v_icon: Texture2D = T.venue_icon(str(card.get("barId", "")))
		if v_icon != null:
			draw_texture_rect(v_icon, Rect2(8 * k, 8 * k, 16 * k, 16 * k), false, Color(col.lightened(0.45), 0.95))
			draw_texture_rect(v_icon, Rect2(w - 24 * k, 8 * k, 16 * k, 16 * k), false, Color(col.lightened(0.45), 0.95))
		else:
			_draw_police_star(Vector2(14 * k, 16.0 * k), 3.5 * k, T.GOLD)
			_draw_police_star(Vector2(w - 14 * k, 16.0 * k), 3.5 * k, T.GOLD)
	# the venue is the card's identity: fitted title text between flanking icons
	var fit := T.fit_bar_name(str(card["barId"]), hf, int(round(T.fs(12.5 * k, 1.5))), int(round(9.0 * k)), w - 52 * k)
	T.note_text(self, fit["px"], fit["text"])
	draw_string(hf, Vector2(26 * k, 21.0 * k), fit["text"], HORIZONTAL_ALIGNMENT_CENTER, w - 52 * k, int(fit["px"]), Color("fff2d8") if razzia else T.GOLD)

	# art window
	var art := Rect2(9 * k, 31 * k, w - 18 * k, 98 * k)
	var tex: Texture2D = T.art("razzia", str(card.get("barId", ""))) if razzia else T.art("zocker", str(card["barId"]))
	if tex != null:
		T.draw_cover(self, tex, art, 0.35)
	else:
		_draw_art_fallback(art, col, razzia, k)
	# art frame
	draw_rect(art, Color(Color(col.lightened(0.2), 0.85) if razzia else Color(T.BRASS, 0.8)), false, maxf(1.0, 1.4 * k))

	# footer: Venue symbol + Name + 28px Die (NO repeated RAZZIA/ZOCKER except police cards)
	draw_line(Vector2(7 * k, 131 * k), Vector2(w - 7 * k, 131 * k), Color(col if razzia else T.BRASS, 0.7 if razzia else 0.5), maxf(1.0, 1.2 * k))

	# 28px+ Die box
	var die_sz := 31.0 * k
	var die_rect := Rect2(w - die_sz - 6.0 * k, 137.0 * k, die_sz, die_sz)
	if razzia:
		_draw_die_police(die_rect, int(card["dieSymbol"]), k, col)
	else:
		_draw_die(die_rect, int(card["dieSymbol"]), k)

	# Left/middle info section (icon + 1~3 word label / stamp)
	var isz := 20.0 * k
	var ix := 6.0 * k
	var iy := 142.0 * k
	var avail_w := die_rect.position.x - (ix + isz + 4.0 * k)
	if razzia:
		# Police Card: Badge icon + RAZZIA stamp text
		var p_icon: Texture2D = T.police_icon()
		if p_icon != null:
			draw_texture_rect(p_icon, Rect2(ix, iy, isz, isz), false, Color("ffd770"))
		else:
			_draw_police_star(Vector2(ix + isz * 0.5, iy + isz * 0.5), 6.5 * k, Color("ffd770"))
		var sf := T.font("stamp")
		var s_text := "RAZZIA"
		var s_sz := int(round(12.0 * k))
		while s_sz > int(round(8.5 * k)) and sf.get_string_size(s_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s_sz).x > avail_w:
			s_sz -= 1
		draw_string(sf, Vector2(ix + isz + 4.0 * k + 1, iy + 15.0 * k + 1), s_text, HORIZONTAL_ALIGNMENT_LEFT, avail_w, s_sz, Color(0, 0, 0, 0.85))
		draw_string(sf, Vector2(ix + isz + 4.0 * k, iy + 15.0 * k), s_text, HORIZONTAL_ALIGNMENT_LEFT, avail_w, s_sz, Color("ffd770"))
	else:
		# Gambler Card: Venue unique vector icon + Venue name (NO "ZOCKER", NO "RAZZIA")
		var v_icon: Texture2D = T.venue_icon(str(card.get("barId", "")))
		if v_icon != null:
			draw_texture_rect(v_icon, Rect2(ix, iy, isz, isz), false, Color(col.lightened(0.4), 0.95))
		var tf := T.font("title", 700)
		var v_name: String = str(T.BAR_SHORT.get(str(card.get("barId", "")), str(card.get("barId", ""))))
		var v_sz := int(round(11.5 * k))
		while v_sz > int(round(8.0 * k)) and tf.get_string_size(v_name, HORIZONTAL_ALIGNMENT_LEFT, -1, v_sz).x > avail_w:
			v_sz -= 1
		draw_string(tf, Vector2(ix + isz + 4.0 * k + 1, iy + 15.0 * k + 1), v_name, HORIZONTAL_ALIGNMENT_LEFT, avail_w, v_sz, Color(0, 0, 0, 0.85))
		draw_string(tf, Vector2(ix + isz + 4.0 * k, iy + 15.0 * k), v_name, HORIZONTAL_ALIGNMENT_LEFT, avail_w, v_sz, T.GOLD)


func _draw_police_star(center: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(10):
		var rad := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, color)


func _draw_die_police(r: Rect2, n: int, k: float, col: Color = Color("c9402f")) -> void:
	_sb(Color("16100d"), Color(col.lightened(0.25), 0.95), maxf(1.0, 1.8 * k), 5.0 * k).draw(get_canvas_item(), r)
	var cream := Color("fff2d8")
	var pr := r.size.x * 0.085
	var m := r.size.x * 0.27
	var l := r.position.x + m
	var rr := r.end.x - m
	var t := r.position.y + m
	var b := r.end.y - m
	var cxm := r.position.x + r.size.x / 2.0
	var cym := r.position.y + r.size.y / 2.0
	var pts: Array = []
	match n:
		1: pts = [Vector2(cxm, cym)]
		2: pts = [Vector2(l, t), Vector2(rr, b)]
		3: pts = [Vector2(l, t), Vector2(cxm, cym), Vector2(rr, b)]
		4: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, b), Vector2(rr, b)]
		5: pts = [Vector2(l, t), Vector2(rr, t), Vector2(cxm, cym), Vector2(l, b), Vector2(rr, b)]
		_: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, cym), Vector2(rr, cym), Vector2(l, b), Vector2(rr, b)]
	for p in pts:
		draw_circle(p, maxf(1.4, pr), cream)


func _draw_art_fallback(art: Rect2, col: Color, razzia: bool, k: float) -> void:
	var top_c := Color(col, 0.55).darkened(0.35)
	var bot_c := Color("0b0806")
	if razzia:
		top_c = Color("3b0f0d")
	draw_polygon(
		PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)]),
		PackedColorArray([top_c, top_c, bot_c, bot_c]))
	# sunburst rays
	var cx := art.position.x + art.size.x / 2.0
	var cy := art.end.y + 6 * k
	for i in range(-5, 6):
		var ang := -PI / 2.0 + i * 0.2
		var p2 := Vector2(cx + cos(ang) * 120.0 * k, cy + sin(ang) * 120.0 * k)
		var p2c := Vector2(clampf(p2.x, art.position.x, art.end.x), clampf(p2.y, art.position.y, art.end.y))
		draw_line(Vector2(cx, cy), p2c, Color(col.lightened(0.3), 0.10), 1.6 * k)
	if razzia:
		_draw_badge(Vector2(cx, art.position.y + art.size.y * 0.5), k)
	else:
		_draw_gambler(Vector2(cx, art.position.y), art, col, k)


func _draw_gambler(top: Vector2, art: Rect2, col: Color, k: float) -> void:
	var cx := top.x
	var base := art.end.y
	var sil := Color("060504")
	# shoulders / suit
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 38 * k, base), Vector2(cx - 34 * k, base - 26 * k), Vector2(cx - 17 * k, base - 36 * k),
		Vector2(cx + 17 * k, base - 36 * k), Vector2(cx + 34 * k, base - 26 * k), Vector2(cx + 38 * k, base)]), sil)
	# shirt / tie accent
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 7 * k, base - 36 * k), Vector2(cx + 7 * k, base - 36 * k), Vector2(cx, base - 20 * k)]), Color("d9cfb8"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 2.5 * k, base - 33 * k), Vector2(cx + 2.5 * k, base - 33 * k), Vector2(cx + 3.5 * k, base - 14 * k), Vector2(cx - 3.5 * k, base - 14 * k)]), Color("8e2118"))
	# head
	var head := Vector2(cx, base - 50 * k)
	draw_circle(head, 14 * k, sil)
	# hat
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 15 * k, head.y - 6 * k), Vector2(cx - 12 * k, head.y - 24 * k), Vector2(cx + 12 * k, head.y - 24 * k), Vector2(cx + 15 * k, head.y - 6 * k)]), sil)
	var brim: PackedVector2Array = []
	for i in range(0, 25):
		var a := TAU * i / 24.0
		brim.append(Vector2(cx + cos(a) * 28 * k, head.y - 6 * k + sin(a) * 5.5 * k))
	draw_colored_polygon(brim, sil)
	draw_rect(Rect2(cx - 14 * k, head.y - 13 * k, 28 * k, 4.5 * k), Color(col, 0.9))
	# rim light
	draw_arc(head, 14.5 * k, -PI * 0.15, PI * 0.55, 12, Color(col.lightened(0.4), 0.6), maxf(1.0, 1.4 * k))

	# Venue crest medallion on chest (ensures instant venue recognition in monochrome)
	var med_c := Vector2(cx, base - 20 * k)
	var med_r := 15.0 * k
	draw_circle(med_c, med_r, Color("14100c"))
	draw_circle(med_c, med_r, Color(col, 0.35))
	draw_arc(med_c, med_r, 0, TAU, 24, Color(T.BRASS, 0.85), maxf(1.0, 1.2 * k))
	var v_icon: Texture2D = T.venue_icon(str(card.get("barId", "")))
	if v_icon != null:
		var isz := 20.0 * k
		draw_texture_rect(v_icon, Rect2(med_c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color(col.lightened(0.5), 0.98))


func _draw_badge(center: Vector2, k: float) -> void:
	# Police raid aura and spotlight
	draw_circle(center, 38 * k, Color(T.DANGER, 0.22))
	draw_circle(center, 28 * k, Color(T.POLICE_BLUE, 0.20))

	# Inked raid stamp circle
	draw_arc(center, 34 * k, 0, TAU, 32, Color(T.DANGER, 0.85), maxf(1.5, 2.0 * k))
	draw_arc(center, 30 * k, 0, TAU, 32, Color(T.DANGER, 0.45), maxf(1.0, 1.0 * k))

	# Chicago Police Star Shield Badge (Vector SVG)
	var p_icon: Texture2D = T.police_icon()
	if p_icon != null:
		var bsz := 46.0 * k
		draw_texture_rect(p_icon, Rect2(center - Vector2(bsz, bsz) * 0.5, Vector2(bsz, bsz)), false, Color("ffd770"))
	else:
		var pts: PackedVector2Array = []
		for i in range(10):
			var r := 26.0 * k if i % 2 == 0 else 11.5 * k
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, T.GOLD)
		draw_circle(center, 8.5 * k, Color("2a1210"))
		draw_circle(center, 5.0 * k, T.DANGER)

	# Raid siren beams
	draw_line(center + Vector2(-38 * k, -26 * k), center + Vector2(-26 * k, -18 * k), Color(T.POLICE_BLUE, 0.9), 2.2 * k)
	draw_line(center + Vector2(38 * k, -26 * k), center + Vector2(26 * k, -18 * k), Color(T.DANGER, 0.9), 2.2 * k)


func _draw_die(r: Rect2, n: int, k: float) -> void:
	_sb(Color("0e0b08"), T.BRASS, maxf(1.0, 1.4 * k), 5.0 * k).draw(get_canvas_item(), r)
	var cream := Color("efe6cf")
	var pr := r.size.x * 0.085
	var m := r.size.x * 0.27
	var l := r.position.x + m
	var rr := r.end.x - m
	var t := r.position.y + m
	var b := r.end.y - m
	var cxm := r.position.x + r.size.x / 2.0
	var cym := r.position.y + r.size.y / 2.0
	var pts: Array = []
	match n:
		1: pts = [Vector2(cxm, cym)]
		2: pts = [Vector2(l, t), Vector2(rr, b)]
		3: pts = [Vector2(l, t), Vector2(cxm, cym), Vector2(rr, b)]
		4: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, b), Vector2(rr, b)]
		5: pts = [Vector2(l, t), Vector2(rr, t), Vector2(cxm, cym), Vector2(l, b), Vector2(rr, b)]
		_: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, cym), Vector2(rr, cym), Vector2(l, b), Vector2(rr, b)]
	for p in pts:
		draw_circle(p, maxf(1.4, pr), cream)


## ----- poster face: a card lying on a venue poster. Keeps the artwork, the die, ZOCKER/RAZZIA and the PLAYER NAME legible.
func _draw_mini_face(w: float, h: float) -> void:
	var k := w / 100.0
	var col := T.bar_color(card["barId"])
	var razzia := is_razzia()
	_sb(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 7.0 * k).draw(get_canvas_item(), Rect2(2.0 * k, 3.5 * k, w, h))
	_sb(Color("1a140d") if not razzia else Color("14100c"), col, maxf(2.0, 3.0 * k), 7.0 * k).draw(get_canvas_item(), Rect2(0, 0, w, h))
	if razzia:
		draw_rect(Rect2(2.5 * k, 2.5 * k, w - 5.0 * k, h - 5.0 * k), Color(col.lightened(0.25), 0.6), false, maxf(1.0, 1.2 * k))
	var nfs := T.fs(10.5 * k, 1.6)
	var nb := nfs * 1.35
	var r1 := maxf(nfs * 1.5, h * 0.17)
	var art := Rect2(4.0 * k, 4.0 * k, w - 8.0 * k, h - 4.0 * k - 3.0 * k - r1 - 2.0 * k - nb - 3.0 * k)
	var tex: Texture2D = T.art("razzia", str(card.get("barId", ""))) if razzia else T.art("zocker", str(card["barId"]))
	if tex != null:
		T.draw_cover(self, tex, art, 0.35)
	else:
		_draw_art_fallback(art, col, razzia, art.size.x / 130.0)
	draw_rect(art, Color(Color(col.lightened(0.2), 0.85) if razzia else Color(T.BRASS, 0.8)), false, maxf(1.0, 1.2 * k))
	var y1 := art.end.y + 3.0 * k
	var d := minf(r1, w * 0.4)
	if razzia:
		_draw_die_police(Rect2(w - 4.0 * k - d, y1, d, d), int(card["dieSymbol"]), k * 0.9, col)
	else:
		_draw_die(Rect2(w - 4.0 * k - d, y1, d, d), int(card["dieSymbol"]), k * 0.9)
	var label: String = "RAZZIA" if razzia else str(T.BAR_SHORT.get(str(card.get("barId", "")), ""))
	var lf := T.font("stamp" if razzia else "title", 800)
	var lpx := int(round(T.fs(9.5 * k, 1.5)))
	var room := w - 8.0 * k - d - 4.0 * k
	while lpx > 10 and lf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x > room:
		lpx -= 1
	var readable_word: bool = lpx * T.phys(self) >= 6.5 and lf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x <= room
	if razzia and not readable_word:
		# too small for the word: a police band with a star across the top of the art says RAZZIA by shape, not by colour
		var band := Rect2(art.position, Vector2(art.size.x, maxf(6.0, art.size.y * 0.2)))
		draw_rect(band, Color(col, 0.92))
		var sc := band.get_center()
		var sr := band.size.y * 0.38
		_draw_police_star(sc, sr, Color("fff4d8"))
	elif not razzia and not readable_word:
		var v_ico: Texture2D = T.venue_icon(str(card.get("barId", "")))
		if v_ico != null:
			draw_texture_rect(v_ico, Rect2(5.0 * k, y1 + (d - 12.0 * k) * 0.5, 12.0 * k, 12.0 * k), false, Color(col.lightened(0.4), 0.95))
	if readable_word:
		T.note_text(self, lpx, label)
		draw_string(lf, Vector2(5.0 * k, y1 + d * 0.5 + lpx * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, room, lpx, Color("ffd770") if razzia else T.GOLD)
	if caption != "":
		var by := y1 + r1 + 2.0 * k
		draw_rect(Rect2(4.0 * k, by, w - 8.0 * k, nb), Color(0, 0, 0, 0.66))
		var nf := T.font("ui", 700)
		var npx := int(round(nfs))
		while npx > 10 and nf.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x > w - 10.0 * k:
			npx -= 1
		T.note_text(self, npx, caption)
		draw_string(nf, Vector2(5.0 * k, by + nb * 0.5 + npx * 0.36), caption, HORIZONTAL_ALIGNMENT_CENTER, w - 10.0 * k, npx, T.TEXT)


## ----- compact face (stack under a bar, table slots) -----
func _draw_compact(w: float, h: float) -> void:
	var k := w / 52.0
	var col := T.bar_color(card["barId"])
	var razzia := is_razzia()
	_sb(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0, 6.0 * k).draw(get_canvas_item(), Rect2(1.5 * k, 2.5 * k, w, h))
	_sb(Color("1a140d") if not razzia else Color("14100c"), col, 2.6 * k, 6.0 * k).draw(get_canvas_item(), Rect2(0, 0, w, h))
	if razzia:
		draw_rect(Rect2(1.8 * k, 1.8 * k, w - 3.6 * k, h - 3.6 * k), Color(col.lightened(0.25), 0.5), false, maxf(1.0, k))
	var f := T.font("stamp" if razzia else "title", 800)
	var label: String = "RAZZIA" if razzia else str(T.BAR_SHORT.get(str(card.get("barId", "")), ""))
	var tcol := Color("ffd770") if razzia else T.GOLD
	draw_rect(Rect2(3 * k, 3 * k, w - 6 * k, 11 * k), Color(col, 0.40) if razzia else Color(col, 0.30))
	var phys := T.phys(self)
	var words_ok: bool = 8.2 * k * phys >= 6.0          # too small to read (a played card beside a rail chip on a phone)?
	if words_ok:
		_text(label, Vector2(3 * k, 11.8 * k), f, 7.8 * k if razzia else 8.2 * k, tcol, w - 6 * k, HORIZONTAL_ALIGNMENT_CENTER)
	elif razzia:
		draw_rect(Rect2(3 * k, 3 * k, w - 6 * k, 11 * k), Color(col, 0.95))     # the police band says RAZZIA by shape
		var sc := Vector2(w / 2.0, 8.5 * k)
		_draw_police_star(sc, 4.2 * k, Color("fff4d8"))
	else:
		var v_ico: Texture2D = T.venue_icon(str(card.get("barId", "")))
		if v_ico != null:
			draw_texture_rect(v_ico, Rect2((w - 9.0 * k) / 2.0, 4.0 * k, 9.0 * k, 9.0 * k), false, Color(col.lightened(0.4), 0.95))
	var d := minf(w - 14 * k, h * (0.32 if caption != "" else 0.40))
	_draw_die(Rect2((w - d) / 2.0, 17 * k, d, d), int(card["dieSymbol"]), k * 0.9)
	if h > 56.0 * k and words_ok:
		var cf := T.font("title", 600)
		var fit := T.fit_bar_name(str(card["barId"]), cf, int(round(T.fs(6.4 * k, 1.6))), int(round(5.0 * k)), w - 4 * k)
		T.note_text(self, fit["px"], fit["text"])
		draw_string(cf, Vector2(2 * k, h - (22.0 * k if caption != "" else 5 * k)), fit["text"], HORIZONTAL_ALIGNMENT_CENTER, w - 4 * k, int(fit["px"]), Color(T.TEXT_DIM, 0.9))
	_caption_band(w, h, k)


## Player-name tag: a dark band INSIDE the bottom of the card (readable, never clipped by the tray edge).
func _caption_band(w: float, h: float, k: float) -> void:
	if caption == "":
		return
	var fsz := T.fs(7.4 * k if w < 84.0 else 9.5 * k, 1.9)
	var bh := fsz * 1.45
	draw_rect(Rect2(3.0 * k, h - bh - 3.0 * k, w - 6.0 * k, bh), Color(0, 0, 0, 0.62))
	_text(caption, Vector2(3.0 * k, h - 3.0 * k - bh * 0.24), T.font("ui", 700), fsz, T.TEXT, w - 6.0 * k, HORIZONTAL_ALIGNMENT_CENTER)


## ----- back -----
func _draw_back(w: float, h: float) -> void:
	var k := w / 130.0
	_sb(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0, 9.0 * k).draw(get_canvas_item(), Rect2(2.5 * k, 4.0 * k, w, h))
	_sb(Color("120d09"), T.BRASS, maxf(1.5, 3.0 * k), 9.0 * k).draw(get_canvas_item(), Rect2(0, 0, w, h))
	var inner := Rect2(7 * k, 7 * k, w - 14 * k, h - 14 * k)
	draw_rect(inner, Color(T.GOLD_DIM, 0.55), false, maxf(1.0, 1.2 * k))
	# diamond lattice
	var step := 18.0 * k
	var x := inner.position.x - inner.size.y
	while x < inner.end.x:
		var a := Vector2(x, inner.end.y)
		var b := Vector2(x + inner.size.y, inner.position.y)
		_draw_clipped_line(a, b, inner, Color(T.GOLD_DIM, 0.28), maxf(1.0, k))
		var a2 := Vector2(x, inner.position.y)
		var b2 := Vector2(x + inner.size.y, inner.end.y)
		_draw_clipped_line(a2, b2, inner, Color(T.GOLD_DIM, 0.28), maxf(1.0, k))
		x += step
	var c := Vector2(w / 2.0, h / 2.0)
	var dr := minf(w, h) * 0.26
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -dr), c + Vector2(dr * 0.78, 0), c + Vector2(0, dr), c + Vector2(-dr * 0.78, 0)]), Color("120d09"))
	draw_polyline(PackedVector2Array([c + Vector2(0, -dr), c + Vector2(dr * 0.78, 0), c + Vector2(0, dr), c + Vector2(-dr * 0.78, 0), c + Vector2(0, -dr)]), T.GOLD, maxf(1.0, 1.6 * k))
	_text("R", Vector2(c.x - dr, c.y + dr * 0.32), T.font("stamp"), dr * 0.95, T.GOLD, dr * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	_caption_band(w, h, w / 52.0 if w < 84.0 else k)


func _draw_clipped_line(a: Vector2, b: Vector2, r: Rect2, color: Color, width: float) -> void:
	# clip a 45 degree line to the rect (simple parametric clip)
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in [0, 1]:
		var p := a[axis]
		var q := d[axis]
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(q) < 0.0001:
			if p < lo or p > hi:
				return
		else:
			var ta := (lo - p) / q
			var tb := (hi - p) / q
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return
	draw_line(a + d * t0, a + d * t1, color, width)
