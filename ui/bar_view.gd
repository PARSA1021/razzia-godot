extends Control
## One bar (venue). Two presentations of the same data:
##   "card": tall venue card + room below it for the cards played there (landscape / casino table mode)
##   "row" : one compact row with the played cards on the right            (portrait / comfortable mode)
## Never colour-only (docs/05 §6): name, icon and amount are always drawn.

const T = preload("res://ui/tokens.gd")
const CardView = preload("res://ui/card_view.gd")

signal chosen(bar_id)
signal info_requested(bar_id)      # a tap while the venue is not an answer to a prompt: show what is known about it

var bar_id := ""
var mode := "card"
var money := 0                   # target amount (engine truth as last replayed)
var shown := 0.0                 # animated amount
var money_cards := 0             # number of money cards lying here (the green pills)
var highlight := false: set = _set_highlight
var clickable := false: set = _set_clickable
var flash := 0.0: set = _set_flash
var venue_h := 200.0             # card mode: height of the venue card, the rest of `size.y` holds the stack
var mini_size := Vector2(52, 72)
var minis: Array = []
var hovering := false
var focused := false: set = _set_focused
var _tween: Tween
## This round's extra money card (the dealer's free card): stays on the venue as a gold tag until the venue is paid out
## or the next round starts, so "where did the extra money go?" can always be answered by looking at the table.
var extra_amount := 0
var extra_by := ""
## While the human dealer is choosing: the hovered / focused venue previews what the card would do ("+$20,000 → $65,000").
var preview_extra := 0
var intel_target := ""
var _tag: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_bar_id: String) -> void:
	bar_id = p_bar_id
	queue_redraw()


func _set_highlight(v: bool) -> void:
	highlight = v
	queue_redraw()
	_redraw_tag()


func set_extra(amount: int, by: String) -> void:
	extra_amount = amount
	extra_by = by
	_ensure_tag()
	_redraw_tag()


func set_preview(amount: int) -> void:
	preview_extra = amount
	_ensure_tag()
	_redraw_tag()


func set_intel(target_name: String) -> void:
	intel_target = target_name
	_ensure_tag()
	_redraw_tag()


func sibling_hovered() -> bool:
	var par := get_parent()
	if par == null:
		return false
	for c in par.get_children():
		if c != self and c.get_script() == get_script() and c.hovering and c.clickable:
			return true
	return false


func _ensure_tag() -> void:
	if _tag == null or not is_instance_valid(_tag):
		_tag = ExtraTag.new()
		_tag.bar = self
		add_child(_tag)


func _redraw_tag() -> void:
	if _tag != null and is_instance_valid(_tag):
		_tag.size = size
		_tag.queue_redraw()


## The gold tag rect (bar-local), for the flight that lands on it.
func extra_tag_rect() -> Rect2:
	if mode == "card":
		var k := size.x / 190.0
		return Rect2(9.0 * k, 37.0 * k, size.x - 18.0 * k, 42.0 * k)
	var h := size.y
	return Rect2(size.x * 0.30, h * 0.52, size.x * 0.24, h * 0.40)


## Drawn above the cards lying on the venue (z_index), never takes input.
class ExtraTag extends Control:
	var bar: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 20                  # above the cards on the venue (z = their index), below the wash (40) and the panels (45+)
		z_as_relative = true

	func _draw() -> void:
		if bar == null:
			return
		var amount: int = bar.extra_amount
		var preview: bool = false
		if amount <= 0 and bar.preview_extra > 0 and bar.clickable and (bar.hovering or (bar.focused and not bar.sibling_hovered())):
			preview = true          # one preview at a time: the mouse wins over the keyboard / pad focus
		var intel: bool = (amount <= 0 and not preview and bar.intel_target != "")
		if amount <= 0 and not preview and not intel:
			return
		var T2 = T
		var r: Rect2 = bar.extra_tag_rect()
		var k: float = r.size.y / 42.0
		var line1 := ""
		var line2 := ""
		if intel:
			line1 = "🕵️ %s" % bar.intel_target
			line2 = T2.t("첩보 입수")
		elif preview:
			line1 = "+%s" % T2.money(bar.preview_extra)
			line2 = T2.t("놓으면 %s") % T2.money(bar.money + bar.preview_extra)
		else:
			line1 = T2.t("추가 +%s") % T2.money(amount)
			line2 = (T2.t("딜러 %s") % T2.t(bar.extra_by)) if bar.extra_by != "" else T2.t("딜러의 추가 카드")
		var f1: Font = T2.font("money", 800)
		var f2: Font = T2.font("ui", 700)
		var s1: int = int(round(T2.fs(17.0 * k, 1.3)))
		var s2: int = int(round(T2.fs(12.5 * k, 1.4)))
		# shrink to the plate (never below 10 px)
		while s1 > 10 and f1.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, s1).x > r.size.x - 12.0 * k:
			s1 -= 1
		while s2 > 10 and f2.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, s2).x > r.size.x - 12.0 * k:
			s2 -= 1
		var tw: float = maxf(f1.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, s1).x, f2.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, s2).x) + 16.0 * k
		var plate := Rect2(r.position + Vector2((r.size.x - minf(tw, r.size.x)) / 2.0, 0), Vector2(minf(tw, r.size.x), maxf(r.size.y, s1 + s2 + 8.0)))
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.set_corner_radius_all(int(7.0 * k))
		if intel:
			sb.bg_color = Color(0.12, 0.08, 0.04, 0.94)
			sb.border_color = T2.BRASS
			sb.set_border_width_all(2)
		elif preview:
			sb.bg_color = Color(0.06, 0.05, 0.03, 0.88)
			sb.border_color = T2.GOLD
			sb.set_border_width_all(2)
		else:
			sb.bg_color = T2.GOLD
			sb.border_color = Color("fff4d8")
			sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.55)
			sb.shadow_size = int(5.0 * k)
		sb.draw(get_canvas_item(), plate)
		var c1: Color = T2.GOLD if (preview or intel) else Color("1a120e")
		var c2: Color = Color("e9dcc0") if (preview or intel) else Color("3a2a14")
		T2.note_text(self, s1, line1)
		T2.note_text(self, s2, line2)
		draw_string(f1, Vector2(plate.position.x, plate.position.y + 4.0 + s1 * 0.95), line1, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, s1, c1)
		draw_string(f2, Vector2(plate.position.x, plate.position.y + 6.0 + s1 + s2 * 0.9), line2, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, s2, c2)


func _set_clickable(v: bool) -> void:
	clickable = v
	queue_redraw()
	_redraw_tag()


func _set_flash(v: float) -> void:
	flash = v
	queue_redraw()


func set_money(n: int, dur: float = 0.0) -> void:
	money = n
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if dur <= 0.0 or not is_inside_tree():
		shown = float(n)
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(func(v: float): shown = v; queue_redraw(), shown, float(n), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func pulse(dur: float = 0.6) -> void:
	if not is_inside_tree() or dur <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(self, "flash", 1.0, dur * 0.25)
	tw.tween_property(self, "flash", 0.0, dur * 0.75)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if clickable:
		chosen.emit(bar_id)           # placing the extra money card: the venue is the answer to a prompt
	else:
		info_requested.emit(bar_id)   # otherwise a tap just asks about the venue (card count, who is in)
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		hovering = what == NOTIFICATION_MOUSE_ENTER
		queue_redraw()
		var par := get_parent()
		if par != null:                 # the focused venue's preview steps aside while the mouse is on another venue
			for c in par.get_children():
				if c.get_script() == get_script():
					c._redraw_tag()
	elif what == NOTIFICATION_RESIZED:
		layout_minis()
		queue_redraw()
		_redraw_tag()


## ---------- played cards under / beside the bar ----------

var expected := 0                # how many cards will lie here once the reveal is over (so earlier landings never reflow)


## Card mode: cards lie on the lower part of the poster in a grid of 2 columns (no overlap, so art + name + die stay readable);
## the grid is as large as the poster allows and fills from the bottom up. Row mode (list view): a single row on the right.
func mini_rects(n: int) -> Array:
	var out := []
	if n <= 0:
		return out
	if mode == "card":
		var k := size.x / 190.0
		var gap := 5.0 * k
		var top := 36.0 * k
		var bottom := venue_h - 56.0 * k
		var reg_h := maxf(10.0, bottom - top)
		var cols := 1 if n == 1 else 2
		var rows := ceili(float(n) / float(cols))
		if rows > 3:
			cols = 3
			rows = ceili(float(n) / 3.0)
		var mw := minf(size.x * (0.52 if n == 1 else 0.44 if cols == 2 else 0.30), (reg_h - float(rows - 1) * gap) / float(rows) / 1.38)
		var mh := mw * 1.38
		for i in range(n):
			var r := i / cols                       # row counted from the bottom
			var c := i % cols
			var in_row := mini(cols, n - r * cols)
			var row_w := float(in_row) * mw + float(in_row - 1) * gap
			var x := (size.x - row_w) / 2.0 + float(c) * (mw + gap)
			var y := bottom - mh - float(r) * (mh + gap)
			out.append(Rect2(Vector2(x, y), Vector2(mw, mh)))
	else:
		var avail_w := size.x * 0.52
		var step_x := 0.0 if n == 1 else minf(mini_size.x * 1.04, (avail_w - mini_size.x) / float(n - 1))
		var total := mini_size.x + step_x * (n - 1)
		var x0 := size.x - total - 10.0
		for i in range(n):
			out.append(Rect2(Vector2(x0 + step_x * i, (size.y - mini_size.y) / 2.0), mini_size))
	return out


func layout_minis() -> void:
	var rects := mini_rects(maxi(minis.size(), expected))
	for i in range(minis.size()):
		var cv: Control = minis[i]
		cv.size = rects[i].size
		cv.position = rects[i].position
		cv.z_index = i


## Adds a (compact) card to the stack. Returns the CardView.
func add_mini(card: Dictionary, caption: String, face_up := true) -> Control:
	var cv := CardView.new()
	cv.card = card
	cv.face_up = face_up
	cv.caption = caption
	cv.art_mini = mode == "card"
	add_child(cv)
	minis.append(cv)
	layout_minis()
	return cv


func clear_minis() -> void:
	expected = 0
	for m in minis:
		if is_instance_valid(m):
			m.queue_free()
	minis.clear()


## Where card number `index` (of `total` that will lie here) lands, in global coordinates.
func slot_global_rect(index: int, total: int) -> Rect2:
	var rects := mini_rects(maxi(total, index + 1))
	var r: Rect2 = rects[index]
	var xf := get_global_transform_with_canvas()
	return Rect2(xf * r.position, r.size * xf.get_scale())


func global_center() -> Vector2:
	return get_global_transform_with_canvas() * (size / 2.0)


## ---------- drawing ----------

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


func _set_focused(v: bool) -> void:
	focused = v
	queue_redraw()
	_redraw_tag()


func _draw() -> void:
	if bar_id == "":
		return
	if mode == "card":
		_draw_card_mode()
	else:
		_draw_row_mode()
	if focused:
		var fh := venue_h if mode == "card" else size.y
		_sb(Color(0, 0, 0, 0), Color("fff4d6"), 3.0, 12.0).draw(get_canvas_item(), Rect2(-7, -7, size.x + 14, fh + 14))


func _frame_color() -> Color:
	if highlight or flash > 0.0:
		return T.GOLD.lerp(Color.WHITE, flash * 0.5)
	if clickable and hovering:
		return T.GOLD
	return T.BRASS


func _draw_deco_diamond(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r * 0.75, 0),
		center + Vector2(0, r),
		center + Vector2(-r * 0.75, 0)
	]), color)


func _draw_card_mode() -> void:
	var w := size.x
	var vh := venue_h
	var k := w / 190.0
	var col := T.bar_color(bar_id)

	# 1. Soft atmospheric drop shadow
	_sb(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 9.0 * k).draw(get_canvas_item(), Rect2(2.5 * k, 4.5 * k, w, vh))

	# 2. Signature venue aura & targeting glow
	if highlight or flash > 0.0 or (clickable and hovering):
		# Outer diffuse club-color bloom
		_sb(Color(0, 0, 0, 0), Color(col, 0.40 + 0.35 * flash), 7.0 * k, 13.0 * k).draw(get_canvas_item(), Rect2(-5 * k, -5 * k, w + 10 * k, vh + 10 * k))
		# Inner crisp gold ring
		_sb(Color(0, 0, 0, 0), Color(T.GOLD, 0.85 + 0.15 * flash), 2.5 * k, 10.0 * k).draw(get_canvas_item(), Rect2(-2 * k, -2 * k, w + 4 * k, vh + 4 * k))

	# 3. Base Card Plaque (Deep mahogany/noir body + double frame)
	var base_frame_col: Color = _frame_color()
	if highlight:
		base_frame_col = Color(col.lightened(0.3), 0.95)
	_sb(Color("14100b"), base_frame_col, maxf(2.0, 2.6 * k), 8.5 * k).draw(get_canvas_item(), Rect2(0, 0, w, vh))

	# Inner club-tinted accent hairline
	draw_rect(Rect2(3.5 * k, 3.5 * k, w - 7.0 * k, vh - 7.0 * k), Color(col, 0.42), false, maxf(1.0, 1.2 * k))

	# Art Deco corner accents on the outer plaque
	var bracket_len := 10.0 * k
	var b_pts := [
		[Vector2(5 * k, 5 * k), Vector2(1, 1)],
		[Vector2(w - 5 * k, 5 * k), Vector2(-1, 1)],
		[Vector2(5 * k, vh - 5 * k), Vector2(1, -1)],
		[Vector2(w - 5 * k, vh - 5 * k), Vector2(-1, -1)]
	]
	for b in b_pts:
		var p: Vector2 = b[0]
		var d: Vector2 = b[1]
		draw_line(p, p + Vector2(bracket_len * d.x, 0), Color(T.GOLD, 0.65), maxf(1.0, 1.2 * k))
		draw_line(p, p + Vector2(0, bracket_len * d.y), Color(T.GOLD, 0.65), maxf(1.0, 1.2 * k))

	# 4. Embossed Nameplate Header
	var header_rect := Rect2(5.0 * k, 5.0 * k, w - 10.0 * k, 25.0 * k)
	draw_rect(header_rect, Color(col, 0.40).darkened(0.25))
	draw_rect(header_rect, Color(col.lightened(0.3), 0.65), false, maxf(1.0, k))
	draw_line(Vector2(6 * k, header_rect.end.y), Vector2(w - 6 * k, header_rect.end.y), Color(T.GOLD, 0.75), maxf(1.0, 1.4 * k))

	var tf := T.font("title", 700)
	var fit := T.fit_bar_name(bar_id, tf, int(T.fs(14.0 * k, 1.35)), int(minf(14.0 * k, T.fs(11.0 * k, 1.35))), w - 36.0 * k)
	var hs: int = fit["px"]
	var title: String = fit["text"]
	var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
	T.note_text(self, hs, title)

	# Art Deco diamond pins flanking the club title
	var mid_y := 17.5 * k
	_draw_deco_diamond(Vector2(14 * k, mid_y), 3.8 * k, T.GOLD)
	_draw_deco_diamond(Vector2(w - 14 * k, mid_y), 3.8 * k, T.GOLD)
	draw_line(Vector2(20 * k, mid_y), Vector2((w - tw) / 2.0 - 6 * k, mid_y), Color(T.BRASS, 0.6), maxf(1.0, k))
	draw_line(Vector2((w + tw) / 2.0 + 6 * k, mid_y), Vector2(w - 20 * k, mid_y), Color(T.BRASS, 0.6), maxf(1.0, k))

	# Club Title with subtle drop shadow
	draw_string(tf, Vector2((w - tw) / 2.0 + 1, 22.0 * k + 1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(0, 0, 0, 0.85))
	draw_string(tf, Vector2((w - tw) / 2.0, 22.0 * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, T.GOLD)

	# 5. Recessed Poster Artwork Window
	var art := Rect2(7 * k, 33 * k, w - 14 * k, vh - 33 * k - 54 * k)
	var poster: Texture2D = T.art("bar", bar_id)
	if poster != null:
		T.draw_cover(self, poster, art, 0.38)
	else:
		var top_c := Color(col, 0.6).darkened(0.45)
		var bot_c := Color("0a0705")
		draw_polygon(PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)]),
			PackedColorArray([top_c, top_c, bot_c, bot_c]))
		var c := art.get_center() + Vector2(0, art.size.y * 0.05)
		for i in range(-7, 8):
			var ang := -PI / 2.0 + i * 0.16
			var p := Vector2(c.x + cos(ang) * art.size.x, c.y + art.size.y * 0.55 + sin(ang) * art.size.x)
			var from := Vector2(c.x, art.end.y)
			var to := Vector2(clampf(p.x, art.position.x, art.end.x), clampf(p.y, art.position.y, art.end.y))
			draw_line(from, to, Color(col.lightened(0.35), 0.09), maxf(1.0, 1.4 * k))
		_draw_icon(c, minf(art.size.x, art.size.y) * 0.30, col)

	# Art bevel frame with inner depth
	draw_rect(art, Color(T.BRASS, 0.9), false, maxf(1.0, 1.4 * k))
	draw_rect(art.grow(-1.2 * k), Color(0, 0, 0, 0.4), false, maxf(1.0, 1.0 * k))

	# 6. Casino Vault / Pot Plaque (Money + Cash Tokens)
	var vault_rect := Rect2(6 * k, vh - 52 * k, w - 12 * k, 46 * k)
	_sb(Color("0d0a07"), Color(T.BRASS, 0.7), maxf(1.0, 1.4 * k), 5.0 * k).draw(get_canvas_item(), vault_rect)
	draw_rect(vault_rect.grow(-2.0 * k), Color(col, 0.14))

	# Vault top accent line
	draw_line(Vector2(vault_rect.position.x + 4 * k, vault_rect.position.y + 1), Vector2(vault_rect.end.x - 4 * k, vault_rect.position.y + 1), Color(T.GOLD, 0.45), maxf(1.0, k))

	var mf := T.font("money", 800)
	var ms := 23.0 * k
	var money_str := T.money(int(round(shown)))
	_text(money_str, Vector2(0, vh - 26.0 * k), mf, ms, T.GOLD.lerp(Color.WHITE, flash * 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_pills(Vector2(w / 2.0, vh - 13.0 * k), k, true)


func _draw_pills(center: Vector2, k: float, centered: bool) -> void:
	var n := mini(money_cards, 7)
	var pw := 15.0 * k
	var ph := 6.5 * k
	var gap := 4.5 * k
	var total := n * pw + maxi(0, n - 1) * gap
	var x := center.x - total / 2.0 if centered else center.x
	for i in range(n):
		var pr := Rect2(x + i * (pw + gap), center.y - ph * 0.5, pw, ph)
		# Emerald cash ingot: dark shadow, emerald body, emerald-glow border
		_sb(Color("196f3d"), Color("2ecc71"), maxf(1.0, 1.0 * k), 2.5 * k).draw(get_canvas_item(), pr)
		# Subtle gloss line across top of ingot
		draw_line(Vector2(pr.position.x + 2 * k, pr.position.y + 1.2 * k), Vector2(pr.end.x - 2 * k, pr.position.y + 1.2 * k), Color("a9dfbf", 0.75), maxf(1.0, k))
	if money_cards > 7:
		_text("+%d" % (money_cards - 7), Vector2(x + total + 4 * k, center.y + 4 * k), T.font("ui", 700), 9.5 * k, Color("2ecc71"))


func _draw_row_mode() -> void:
	var w := size.x
	var h := size.y
	var k := h / 74.0
	var col := T.bar_color(bar_id)
	if highlight or flash > 0.0 or (clickable and hovering):
		_sb(Color(0, 0, 0, 0), Color(col, 0.40 + 0.35 * flash), 5.0, 13.0).draw(get_canvas_item(), Rect2(-4, -4, w + 8, h + 8))
		_sb(Color(0, 0, 0, 0), Color(T.GOLD, 0.85), 2.0, 10.0).draw(get_canvas_item(), Rect2(-2, -2, w + 4, h + 4))
	_sb(Color("14100b"), _frame_color(), 2.0, 9.0).draw(get_canvas_item(), Rect2(0, 0, w, h))
	_sb(col, Color(col.lightened(0.3), 0.7), 1.0, 7.0).draw(get_canvas_item(), Rect2(4, 4, 9, h - 8))
	# icon plate
	var plate := Rect2(20, 8, h - 16, h - 16)
	var poster_r: Texture2D = T.art("bar", bar_id)
	if poster_r != null:
		T.draw_cover(self, poster_r, plate, 0.4)
	else:
		draw_polygon(PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]),
			PackedColorArray([Color(col, 0.55).darkened(0.4), Color(col, 0.55).darkened(0.4), Color("0a0705"), Color("0a0705")]))
		_draw_icon(plate.get_center(), plate.size.x * 0.30, col)
	draw_rect(plate, Color(T.BRASS, 0.9), false, 1.4)
	var x0 := plate.end.x + 14.0
	_text(T.bar_name(bar_id), Vector2(x0, h * 0.40), T.font("title", 700), 19.0 * k, T.GOLD)
	_text(T.money(int(round(shown))), Vector2(x0, h * 0.82), T.font("money", 800), 24.0 * k, T.GOLD.lerp(Color.WHITE, flash * 0.6))
	var name_w := T.font("title", 700).get_string_size(T.bar_name(bar_id), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * k)).x
	_draw_pills(Vector2(x0 + name_w + 14.0, h * 0.34), k * 0.9, false)


## Simple venue icons (one per bar) so the bars differ by shape, not only by colour.
func _draw_icon(c: Vector2, u: float, col: Color) -> void:
	var lt := col.lightened(0.45)
	var line := maxf(1.2, u * 0.07)
	match bar_id:
		"COLIBRI":    # martini glass with olive
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u, -u * 0.9), c + Vector2(u, -u * 0.9), c + Vector2(0, u * 0.15)]), Color(lt, 0.85))
			draw_line(c + Vector2(0, u * 0.15), c + Vector2(0, u * 0.95), lt, line)
			draw_line(c + Vector2(-u * 0.5, u * 0.95), c + Vector2(u * 0.5, u * 0.95), lt, line)
			draw_circle(c + Vector2(u * 0.25, -u * 0.35), u * 0.14, Color("5da04a"))
			draw_line(c + Vector2(u * 0.25, -u * 0.35), c + Vector2(u * 0.75, -u * 1.15), lt, line * 0.7)
		"COTTON_CLUB":    # spotlight cone on a stage
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.12, -u), c + Vector2(u * 0.12, -u), c + Vector2(u * 0.95, u * 0.85), c + Vector2(-u * 0.95, u * 0.85)]), Color(1, 0.93, 0.7, 0.22))
			draw_circle(c + Vector2(0, -u), u * 0.2, lt)
			draw_line(c + Vector2(-u, u * 0.9), c + Vector2(u, u * 0.9), lt, line * 1.3)
			draw_circle(c + Vector2(0, u * 0.35), u * 0.17, Color("0a0705"))
		"HAVANA_BAR":    # palm tree
			draw_line(c + Vector2(-u * 0.1, u), c + Vector2(u * 0.1, -u * 0.3), lt, line * 1.4)
			for a in [-2.6, -2.0, -1.2, -0.5, 0.2]:
				var tip := c + Vector2(u * 0.1, -u * 0.3) + Vector2(cos(a), sin(a)) * u * 0.95
				draw_line(c + Vector2(u * 0.1, -u * 0.3), tip, lt, line)
				draw_line(tip, tip + Vector2(0, u * 0.28), lt, line * 0.8)
		"THE_JUNGLE":    # three leaves
			for i in range(3):
				var ang := -PI / 2.0 + (i - 1) * 0.75
				var pts: PackedVector2Array = []
				for j in range(17):
					var t := TAU * j / 16.0
					var p := Vector2(cos(t) * u * 0.28, sin(t) * u * 0.85)
					pts.append(c + Vector2(0, u * 0.2) + (p + Vector2(0, -u * 0.8)).rotated(ang + PI / 2.0 - PI / 2.0))
				draw_colored_polygon(pts, Color(lt, 0.8 - i * 0.12))
		"LINCOLNS":    # spade
			draw_circle(c + Vector2(-u * 0.38, u * 0.05), u * 0.46, lt)
			draw_circle(c + Vector2(u * 0.38, u * 0.05), u * 0.46, lt)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 1.0), c + Vector2(u * 0.82, u * 0.2), c + Vector2(-u * 0.82, u * 0.2)]), lt)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, u * 0.2), c + Vector2(u * 0.3, u * 0.95), c + Vector2(-u * 0.3, u * 0.95)]), lt)
		"JAZZ_HOUSE":    # beamed notes
			draw_circle(c + Vector2(-u * 0.55, u * 0.6), u * 0.3, lt)
			draw_circle(c + Vector2(u * 0.5, u * 0.4), u * 0.3, lt)
			draw_line(c + Vector2(-u * 0.27, u * 0.6), c + Vector2(-u * 0.27, -u * 0.8), lt, line * 1.3)
			draw_line(c + Vector2(u * 0.77, u * 0.4), c + Vector2(u * 0.77, -u), lt, line * 1.3)
			draw_line(c + Vector2(-u * 0.27, -u * 0.8), c + Vector2(u * 0.77, -u), lt, line * 2.6)
		_:
			draw_circle(c, u * 0.6, lt)
