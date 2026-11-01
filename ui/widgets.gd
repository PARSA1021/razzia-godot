extends RefCounted
## Small reusable UI pieces: styled buttons/labels, stat block, player chip, die.

const T = preload("res://ui/tokens.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")


static func sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 8, margin: Vector4 = Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	s.anti_aliasing = true
	return s


## The game's one piece of framing: a plain dark surface held inside brass corner brackets, with the diamond from the card
## backs set into each corner. It is the same gesture as the venue posters and the duel table, and it is deliberately
## reserved for panels that matter (a result, a decision, the pause) — ordinary boxes keep `sb()` so the frame stays special.
class DecoBox extends StyleBox:
	const T = preload("res://ui/tokens.gd")
	var bg := Color("120e09")
	var line := T.GOLD            # the brackets and the diamonds
	var rule := T.BRASS           # the hairline that runs around the content
	var radius := 10
	var bracket := 26.0           # arm length of a corner bracket
	var inset := 7.0              # distance from the panel edge to the hairline
	var thick := 2.0

	func _draw(ci: RID, rect: Rect2) -> void:
		var flat := StyleBoxFlat.new()
		flat.bg_color = bg
		flat.set_corner_radius_all(radius)
		flat.anti_aliasing = true
		flat.draw(ci, rect)
		var r := rect.grow(-inset)
		if r.size.x <= 8.0 or r.size.y <= 8.0:
			return
		var c := RenderingServer
		# hairline frame: it stops short of the corners, so the brackets read as the thing holding the panel together
		var gap := bracket * 0.72
		var pts := [
			[Vector2(r.position.x + gap, r.position.y), Vector2(r.end.x - gap, r.position.y)],
			[Vector2(r.position.x + gap, r.end.y), Vector2(r.end.x - gap, r.end.y)],
			[Vector2(r.position.x, r.position.y + gap), Vector2(r.position.x, r.end.y - gap)],
			[Vector2(r.end.x, r.position.y + gap), Vector2(r.end.x, r.end.y - gap)],
		]
		for p in pts:
			c.canvas_item_add_line(ci, p[0], p[1], Color(rule, 0.55), 1.0, true)
		for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
			var o: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			c.canvas_item_add_line(ci, o, o + Vector2(bracket * d.x, 0.0), line, thick, true)
			c.canvas_item_add_line(ci, o, o + Vector2(0.0, bracket * d.y), line, thick, true)
			var dc: Vector2 = o + Vector2(7.0 * d.x, 7.0 * d.y)
			var s := 3.2
			c.canvas_item_add_polygon(ci, PackedVector2Array([dc + Vector2(0, -s), dc + Vector2(s, 0), dc + Vector2(0, s), dc + Vector2(-s, 0)]), PackedColorArray([line]))


## DecoBox with the usual arguments of `sb()`; `u` scales the bracket with the rest of the UI.
static func deco(bg: Color, line: Color = T.GOLD, margin: Vector4 = Vector4(24, 20, 24, 20), u: float = 1.0, rule: Color = T.BRASS) -> StyleBox:
	var s := DecoBox.new()
	s.bg = bg
	s.line = line
	s.rule = rule
	s.bracket = 26.0 * u
	s.inset = 7.0 * u
	s.thick = maxf(1.5, 2.0 * u)
	s.radius = int(10 * u)
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	return s


## A hairline rule for ledger-style lists; `weight` 2 draws the double rule that sits above a total.
static func rule(u: float = 1.0, weight: int = 1, color: Color = T.BRASS) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, (3.0 if weight >= 2 else 1.0) * u + 6.0 * u)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.set_meta("weight", weight)
	c.set_meta("color", color)
	c.draw.connect(func():
		var y: float = c.size.y * 0.5
		var w: int = int(c.get_meta("weight"))
		var col: Color = c.get_meta("color")
		if w >= 2:
			c.draw_line(Vector2(0, y - 2.0 * u), Vector2(c.size.x, y - 2.0 * u), Color(col, 0.8), 1.0, true)
			c.draw_line(Vector2(0, y + 1.0 * u), Vector2(c.size.x, y + 1.0 * u), Color(col, 0.8), 1.0, true)
		else:
			c.draw_line(Vector2(0, y), Vector2(c.size.x, y), Color(col, 0.35), 1.0, true))
	return c


static func label(text: String, size: int, color: Color = T.TEXT, kind: String = "ui", align: int = HORIZONTAL_ALIGNMENT_LEFT, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", T.font(kind, weight))
	l.add_theme_font_size_override("font_size", int(T.fs(size, 1.5)))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func icon_rect(tex: Texture2D, min_size: Vector2 = Vector2.ZERO, modulate: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = min_size
	tr.modulate = modulate
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Applies the look of a button kind: "primary" (gold) | "secondary" (dark) | "danger" (red) | "active" (selected segment: gold outline on dark).
static func set_kind(b: Button, kind: String, size: int = -1) -> void:
	if size > 0:
		b.add_theme_font_size_override("font_size", int(T.fs(size, 1.35)))     # never unreadable on a small screen (T.fs)
	var bg := Color("2a2014")
	var border := T.BRASS
	var fg := T.GOLD
	if kind == "primary":
		bg = Color("b88f46")
		border = Color("e6c98c")
		fg = Color("1a120e")
	elif kind == "danger":
		bg = Color("5a1a14")
		border = T.DANGER
		fg = Color("ffd7cf")
	elif kind == "active":
		bg = Color("4a3a1c")
		border = T.GOLD
		fg = Color("fff0c8")
	elif kind == "ghost":
		# a quiet text row that opens something; it must not compete with the real choices around it
		bg = Color(0, 0, 0, 0)
		border = Color(0, 0, 0, 0)
		fg = T.TEXT_DIM
	b.add_theme_stylebox_override("normal", sb(bg, border, 2, 8, Vector4(18, 8, 18, 8)))
	b.add_theme_stylebox_override("hover", sb(bg.lightened(0.14), border.lightened(0.2), 2, 8, Vector4(18, 8, 18, 8)))
	b.add_theme_stylebox_override("pressed", sb(bg.darkened(0.2), border, 2, 8, Vector4(18, 9, 18, 7)))
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), T.GOLD, 3, 9, Vector4(18, 8, 18, 8)))
	b.add_theme_stylebox_override("disabled", sb(Color(0.02, 0.05, 0.03, 0.4), Color(T.BRASS, 0.4), 2, 8, Vector4(18, 8, 18, 8)))    # translucent: sits on the felt, not a brown block
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color("8f8266"))


## Segmented choice (one of N): returns an HBoxContainer; `on_select.call(index)` runs when another segment is picked.
## Looks: selected = "active", others = "secondary". Meta "select" (Callable(index)) moves the highlight without firing on_select.
static func segmented(labels: Array, selected: int, on_select: Callable, size: int = 18, min_h: float = 46.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var btns: Array = []
	var cur := [selected]
	var apply := func():
		for i in range(btns.size()):
			set_kind(btns[i], "active" if i == cur[0] else "secondary", size)
	for i in range(labels.size()):
		var b := button(str(labels[i]), "secondary", size, Vector2(0, min_h))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func():
			if cur[0] == idx:
				return
			cur[0] = idx
			apply.call()
			on_select.call(idx))
		btns.append(b)
		hb.add_child(b)
	apply.call()
	hb.set_meta("select", func(i: int):
		cur[0] = i
		apply.call())
	return hb


## kind: "primary" (gold) | "secondary" (dark) | "danger" (red)
static func button(text: String, kind: String = "primary", size: int = 20, min_size: Vector2 = Vector2(0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", T.font("title", 800))
	set_kind(b, kind, size)
	b.pressed.connect(func(): Audio.play("click"))
	# press feedback: a quick 4 % squash (visual only; the `pressed` signal is untouched). Skipped with reduced motion.
	b.button_down.connect(func():
		if Settings.reduce_motion or not b.is_inside_tree():
			return
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), Settings.dur(0.05) + 0.001))
	b.button_up.connect(func():
		if not b.is_inside_tree():
			return
		if Settings.reduce_motion:
			b.scale = Vector2.ONE
			return
		b.create_tween().tween_property(b, "scale", Vector2.ONE, Settings.dur(0.09) + 0.001).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


## "ROUND 01", "ON THE TABLE $170,000": small caps title + big value in one pill.
class StatView extends Control:
	const T = preload("res://ui/tokens.gd")
	var title := "": set = _set_title
	var short_title := ""          # used when the pill is too narrow for the title at a readable size ("FINAL ROUND" -> "FINAL")
	var value := "": set = _set_value
	var accent := false: set = _set_accent

	func _set_title(v: String) -> void:
		title = v
		queue_redraw()

	func _set_value(v: String) -> void:
		value = v
		queue_redraw()

	func _set_accent(v: bool) -> void:
		accent = v
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("120e09")
		sb.border_color = T.GOLD if accent else T.BRASS
		sb.set_border_width_all(2 if accent else 1)
		sb.set_corner_radius_all(int(h * 0.18))
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var tf := T.font("subtitle", 600)
		var vf := T.font("money", 800)
		var ts := int(T.fs(h * 0.36, 1.4))
		var vs := int(h * 0.50)
		var ttl := title
		var tw := tf.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var vw := vf.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
		var gap := h * 0.22
		var fit := (size.x - h * 0.5) / maxf(1.0, tw + gap + vw)    # shrink to fit long values ("$150,000")
		if fit < 0.85 and short_title != "":
			ttl = short_title                                            # the value is what matters: keep it large
			tw = tf.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
			fit = (size.x - h * 0.5) / maxf(1.0, tw + gap + vw)
		if fit < 1.0:
			ts = maxi(10, int(ts * fit))
			vs = maxi(10, int(vs * fit))
			tw *= fit
			vw *= fit
			gap *= fit
		var x := (size.x - tw - gap - vw) / 2.0
		T.note_text(self, ts, ttl)
		T.note_text(self, vs, value)
		draw_string(tf, Vector2(x, h * 0.65), ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, T.TEXT_DIM)
		draw_string(vf, Vector2(x + tw + gap, h * 0.69), value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs, T.GOLD)


## One player: avatar, name, money, dealer tag, ready mark.
class PlayerChip extends Control:
	const T = preload("res://ui/tokens.gd")
	const Portrait = preload("res://ui/portrait.gd")
	var player_id := ""
	var player_name := ""
	var is_me := false
	var dealer := false: set = _set_dealer
	var is_ready := false: set = _set_ready
	var hand_size := 5
	var personality := ""        # AI characters get their portrait instead of the initial
	var money := 0
	var shown := 0.0
	var _tween: Tween

	func _set_dealer(v: bool) -> void:
		dealer = v
		queue_redraw()

	func _set_ready(v: bool) -> void:
		is_ready = v
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

	func _draw() -> void:
		var h := size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("14100b")
		sb.border_color = T.GOLD if is_me else T.BRASS
		sb.set_border_width_all(2 if is_me else 1)
		sb.set_corner_radius_all(int(h * 0.22))
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var art := personality != ""
		var c := Vector2(h * (0.6 if art else 0.55), h * 0.5)
		if not art:
			draw_circle(c, h * 0.34, Color("2a2014"))
			draw_arc(c, h * 0.34, 0, TAU, 28, T.GOLD if is_me else T.GOLD_DIM, 2.0, true)
		if personality != "":
			Portrait.paint(self, c, h * 0.56, personality, player_name)    # the portrait pops out of the chip a little
		else:
			var ini := player_name.substr(0, 1).to_upper()
			var f := T.font("title", 800)
			var fs := int(h * 0.38)
			var iw := f.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - iw / 2.0, c.y + fs * 0.34), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.GOLD)
		var x0 := h * (1.28 if art else 1.08)
		# the name and the money each keep clear of what sits on their right (the DEALER pill / the ready tick), so a long
		# name or a seven-figure total is shortened instead of running underneath them
		var dfs := int(T.fs(h * 0.19, 1.6))
		var tw := T.font("title", 800).get_string_size("DEALER", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs).x
		var npx := int(T.fs(h * 0.27, 1.5))
		# when the DEALER pill would squeeze the name to a few letters, the dealer is marked with a "D" badge on the
		# avatar instead (Phase 29, narrow rail on a phone): the name stays readable
		var badge: bool = dealer and T.font("ui", 700).get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x > size.x - x0 - 8 - (tw + 20.0)
		var name_w := size.x - x0 - 8 - ((tw + 20.0) if (dealer and not badge) else 0.0)
		var money_w := size.x - x0 - 8 - ((h * 0.46) if is_ready else 0.0)
		var shown_name := T.ellipsize(T.font("ui", 700), player_name, npx, maxf(24.0, name_w))
		T.note_text(self, npx, shown_name)
		draw_string(T.font("ui", 700), Vector2(x0, h * 0.42), shown_name, HORIZONTAL_ALIGNMENT_LEFT, maxf(24.0, name_w), npx, T.TEXT)
		var mstr := T.money(int(round(shown)))
		var mf := T.font("money", 800)
		var mfs := int(T.fs(h * 0.36, 1.4))
		while mfs > 9 and mf.get_string_size(mstr, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x > money_w:
			mfs -= 1                                  # a seven-figure total shrinks to fit; it is never cut off
		T.note_text(self, mfs, mstr)
		draw_string(mf, Vector2(x0, h * 0.84), mstr, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, T.GOLD)
		if badge:
			var bc := Vector2(h * 0.24, h * 0.24)
			var br := h * 0.2
			draw_circle(bc, br, T.GOLD)
			draw_arc(bc, br, 0, TAU, 20, Color("1a120e"), 1.5, true)
			var bfs := int(br * 1.3)
			T.note_text(self, bfs, "D")
			draw_string(T.font("title", 800), Vector2(bc.x - br, bc.y + bfs * 0.36), "D", HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, bfs, Color("1a120e"))
		elif dealer:
			var r := Rect2(size.x - tw - 24, maxf(4.0, h * 0.09), tw + 12, maxf(h * 0.28, dfs * 1.3))   # keeps clear of the rounded border
			var pill := StyleBoxFlat.new()
			pill.bg_color = T.GOLD
			pill.set_corner_radius_all(int(r.size.y * 0.5))
			pill.draw(get_canvas_item(), r)
			T.note_text(self, dfs, "DEALER")
			draw_string(T.font("title", 800), Vector2(r.position.x + 6, r.position.y + r.size.y * 0.5 + dfs * 0.35), "DEALER", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color("1a120e"))
		if is_ready:
			var cx := size.x - h * 0.32
			var cy := h * 0.55
			var cs := h * 0.16
			draw_line(Vector2(cx - cs, cy), Vector2(cx - cs * 0.2, cy + cs), T.OK, 2.0, true)
			draw_line(Vector2(cx - cs * 0.2, cy + cs), Vector2(cx + cs * 1.2, cy - cs), T.OK, 2.0, true)


## A six-sided die face (used by the duel scene). `value` 0 = blank ("?" while `idle`).
## Presentation only: `tumble()` spins / hops the die and lands on a number the engine already decided.
class DieView extends Control:
	const T = preload("res://ui/tokens.gd")
	const Settings = preload("res://ui/settings.gd")
	var value := 0: set = _set_value
	var glow := false: set = _set_glow
	var idle := false: set = _set_idle        # waiting for the roll: blank face with a "?"
	var dim := false: set = _set_dim          # the loser after the result
	var hop := 0.0                            # lift off the table, as a fraction of the die size
	var _tw: Tween
	var _breath: Tween
	var _pulse := 0.0

	func _set_value(v: int) -> void:
		value = v
		queue_redraw()

	func _set_glow(v: bool) -> void:
		glow = v
		queue_redraw()
		if v and not Settings.reduce_motion and is_inside_tree():
			_win_pulse()

	func _set_idle(v: bool) -> void:
		idle = v
		queue_redraw()
		if _breath != null and _breath.is_valid():
			_breath.kill()
		scale = Vector2.ONE
		if v and not Settings.reduce_motion and is_inside_tree():
			_breath = create_tween().set_loops()
			_breath.tween_property(self, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_SINE)
			_breath.tween_property(self, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)

	func _set_dim(v: bool) -> void:
		dim = v
		modulate = Color(0.55, 0.55, 0.55, 1.0) if v else Color.WHITE

	func _init() -> void:
		resized.connect(func(): pivot_offset = size / 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Spin, bounce and settle on `final` over `secs` (the faces flicker faster at first and slow down like a real die).
	## Returns when it has landed. Reduced motion / skip: lands at once.
	func tumble(final: int, secs: float, spin_dir: float = 1.0) -> void:
		stop_motion()
		if secs <= 0.0 or not is_inside_tree():
			land(final)
			return
		var steps := 14
		var last := [-1]
		_tw = create_tween()
		_tw.tween_method(func(p: float):
			var q := pow(p, 0.55)
			var k := int(q * steps)
			if k != last[0] and p < 1.0:
				last[0] = k
				var nv := randi() % 6 + 1
				while nv == value:
					nv = randi() % 6 + 1
				value = nv
			rotation = spin_dir * (1.0 - p) * (1.0 - p) * TAU * 1.5
			hop = absf(sin(p * PI * 3.0)) * (1.0 - p) * 0.55
			queue_redraw(), 0.0, 1.0, secs)
		await _tw.finished
		if is_inside_tree():
			land(final)
			await get_tree().create_timer(0.12).timeout

	func stop_motion() -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if _breath != null and _breath.is_valid():
			_breath.kill()
		idle = false
		scale = Vector2.ONE

	## Lands on `final` with a small squash-and-settle.
	func land(final: int) -> void:
		stop_motion()
		value = final
		rotation = 0.0
		hop = 0.0
		queue_redraw()
		if Settings.reduce_motion or not is_inside_tree():
			return
		scale = Vector2(1.22, 0.82)
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _win_pulse() -> void:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.14, 1.14), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", Vector2(1.06, 1.06), 0.25)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# contact shadow on the table: shrinks and fades while the die is in the air
		var sh := 1.0 - clampf(hop * 1.2, 0.0, 0.6)
		draw_set_transform(Vector2(size.x * 0.5, size.y * 1.02), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, size.x * 0.46 * sh, Color(0, 0, 0, 0.38 * sh))
		draw_set_transform(Vector2(0.0, -hop * size.y), 0.0, Vector2.ONE)
		if glow:
			var halo := StyleBoxFlat.new()
			halo.bg_color = Color(T.GOLD, 0.0)
			halo.border_color = Color(T.GOLD, 0.35)
			halo.set_border_width_all(int(size.x * 0.07))
			halo.set_corner_radius_all(int(size.x * 0.22))
			halo.anti_aliasing = true
			halo.draw(get_canvas_item(), r.grow(size.x * 0.05))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("efe6cf")
		sb.border_color = T.GOLD if glow else Color("8a6d3b")
		sb.set_border_width_all(4 if glow else 2)
		sb.set_corner_radius_all(int(size.x * 0.16))
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), r)
		# ivory shading: lighter top edge, darker bottom edge
		var hi := StyleBoxFlat.new()
		hi.bg_color = Color(1, 1, 1, 0.34)
		hi.set_corner_radius_all(int(size.x * 0.12))
		hi.anti_aliasing = true
		hi.draw(get_canvas_item(), Rect2(size.x * 0.1, size.y * 0.07, size.x * 0.8, size.y * 0.3))
		var lo := StyleBoxFlat.new()
		lo.bg_color = Color(0.35, 0.25, 0.1, 0.18)
		lo.set_corner_radius_all(int(size.x * 0.12))
		lo.anti_aliasing = true
		lo.draw(get_canvas_item(), Rect2(size.x * 0.1, size.y * 0.72, size.x * 0.8, size.y * 0.2))
		if value <= 0:
			if idle:
				var f := T.font("title", 800)
				var fs := int(size.y * 0.6)
				var qw := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2((size.x - qw) / 2.0, size.y * 0.7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8a6d3b"))
			return
		var pr := size.x * 0.085
		var m := size.x * 0.27
		var l := m
		var rr := size.x - m
		var t := m
		var b := size.y - m
		var cx := size.x / 2.0
		var cy := size.y / 2.0
		var pts: Array = []
		match value:
			1: pts = [Vector2(cx, cy)]
			2: pts = [Vector2(l, t), Vector2(rr, b)]
			3: pts = [Vector2(l, t), Vector2(cx, cy), Vector2(rr, b)]
			4: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, b), Vector2(rr, b)]
			5: pts = [Vector2(l, t), Vector2(rr, t), Vector2(cx, cy), Vector2(l, b), Vector2(rr, b)]
			_: pts = [Vector2(l, t), Vector2(rr, t), Vector2(l, cy), Vector2(rr, cy), Vector2(l, b), Vector2(rr, b)]
		for p in pts:
			draw_circle(p, pr, Color("1a120e"))
			draw_circle(p + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.3, Color(1, 1, 1, 0.22))


## The money deck as a pile of card backs (Balatro-style deck pile). `count` is the REAL remaining deck size
## (driven by the display model, which replays engine events); the number of visible layers only reflects how full it is.
class PileView extends Control:
	const T = preload("res://ui/tokens.gd")
	const CV = preload("res://ui/card_view.gd")
	const MAX_LAYERS := 5
	var count := 0: set = set_count
	var total := 84
	var _top: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_top = CV.new()
		_top.card = {}
		_top.face_up = false
		_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_top)
		resized.connect(_relayout)

	func set_count(v: int) -> void:
		count = v
		if _top != null:
			_top.caption = "DECK %d" % v
		queue_redraw()

	func _layers() -> int:
		return clampi(ceili(float(MAX_LAYERS) * float(count) / float(maxi(1, total))), 0, MAX_LAYERS) if count > 0 else 0

	func _relayout() -> void:
		var off := size.x * 0.035
		_top.position = Vector2.ZERO
		_top.size = size - Vector2(off, off) * float(MAX_LAYERS)
		queue_redraw()

	func _draw() -> void:
		var off := size.x * 0.035
		var n := _layers()
		var cw := size.x - off * float(MAX_LAYERS)
		var ch := size.y - off * float(MAX_LAYERS)
		_top.visible = count > 0
		if count <= 0:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.18)
			sb.border_color = Color(T.BRASS, 0.4)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(int(cw * 0.07))
			sb.draw(get_canvas_item(), Rect2(0, 0, cw, ch))
			return
		for i in range(n, 0, -1):
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color("120d09")
			sb2.border_color = T.BRASS
			sb2.set_border_width_all(2)
			sb2.set_corner_radius_all(int(cw * 0.07))
			sb2.draw(get_canvas_item(), Rect2(off * i, off * i, cw, ch))


## Keyboard / gamepad guard for a prompt that just appeared: for `secs` real seconds the button cannot take focus (so a stray or held
## Enter / A press cannot answer it), mouse and touch work all the time; afterwards it grabs focus. Answers from tests (`pressed.emit`) are not affected.
## Gamepad: A = accept, B = cancel on every focused control, even where the engine's default map lacks them (checked at run time:
## a headless / some desktop builds carry only the keyboard keys for ui_accept). Idempotent.
static func ensure_pad_bindings() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		if not InputMap.has_action(pair[0]):
			continue
		var has := false
		for e in InputMap.action_get_events(pair[0]):
			if e is InputEventJoypadButton and e.button_index == pair[1]:
				has = true
		if not has:
			var jb := InputEventJoypadButton.new()
			jb.button_index = pair[1]
			InputMap.action_add_event(pair[0], jb)


static func arm_focus(b: Button, secs: float) -> void:
	if not is_instance_valid(b):
		return
	if not b.is_inside_tree():
		b.focus_mode = Control.FOCUS_ALL
		return
	b.focus_mode = Control.FOCUS_NONE
	var release_focus_owner := b.get_viewport().gui_get_focus_owner()
	if release_focus_owner != null and release_focus_owner != b:
		release_focus_owner.release_focus()
	await b.get_tree().create_timer(secs, true, false, true).timeout
	if is_instance_valid(b) and b.is_inside_tree():
		b.focus_mode = Control.FOCUS_ALL
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()


## Phase 29: no scrolling. A box that always shows ALL of its content: when the content is taller (or wider) than the
## room it gets, it is scaled down as one piece instead of being cut off behind a scroll bar. Its own minimum size is zero,
## so the parent decides the room. Input keeps working on scaled controls (Godot transforms the events).
class FitBox extends Container:
	var min_scale := 0.5           # never smaller than this (should not be reached: long content is split into tabs/pages)
	var align_top := true
	var k := 1.0                   # the scale in use (tests, text audit)
	var max_size := Vector2(-1, -1)   # the most room it may ask for (the screen budget); -1 = ask for nothing (the parent decides)

	var _last_min := Vector2(-1, -1)

	func _init() -> void:
		child_entered_tree.connect(func(n):
			if n is Control and n.get_parent() == self and not n.minimum_size_changed.is_connected(_child_min_changed):
				n.minimum_size_changed.connect(_child_min_changed))

	## the content grew or shrank: only a box that sizes itself to its content (max_size set) has to ask again, and only
	## when its answer really changes (no feedback loop with the parent)
	func _child_min_changed() -> void:
		if max_size.x < 0.0 and max_size.y < 0.0:
			queue_sort()
			return
		var m := _get_minimum_size()
		if not m.is_equal_approx(_last_min):
			_last_min = m
			update_minimum_size.call_deferred()
		queue_sort()

	func set_max(v: Vector2) -> void:
		max_size = v
		update_minimum_size()
		queue_sort()

	func _get_minimum_size() -> Vector2:
		if max_size.x < 0.0 and max_size.y < 0.0:
			return Vector2.ZERO
		var ms := Vector2.ZERO
		for c in get_children():
			if c is Control and c.visible:
				ms = ms.max((c as Control).get_combined_minimum_size())
		return Vector2(minf(ms.x, max_size.x) if max_size.x >= 0.0 else 0.0, minf(ms.y, max_size.y) if max_size.y >= 0.0 else 0.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			for c in get_children():
				if not (c is Control) or not c.visible:
					continue
				var ch := c as Control
				# the content is laid out at the box's own width (never wider when scaled: a width that depended on the scale
				# would change the line wrapping, which changes the height, which changes the scale - an endless loop)
				var w := maxf(ch.get_combined_minimum_size().x, size.x)
				if not is_equal_approx(ch.size.x, w):
					ch.size = Vector2(w, ch.size.y)
				var ms := ch.get_combined_minimum_size()
				k = 1.0
				if ms.x > 0.0 and ms.y > 0.0:
					k = clampf(minf(size.x / ms.x, size.y / ms.y), min_scale, 1.0)
				ch.pivot_offset = Vector2.ZERO
				ch.scale = Vector2(k, k)
				ch.size = Vector2(w, ms.y)
				var y := 0.0 if align_top else maxf(0.0, (size.y - ms.y * k) / 2.0)
				ch.position = Vector2((size.x - w * k) / 2.0, y)


## Tabs: a row of segment buttons over pages, one page shown at a time, each page in a FitBox (nothing ever scrolls).
## max_size: the most room a page may take (the screen budget); a taller page is scaled down to it as one piece. All pages
## get the height of the tallest one, so the panel never jumps when the tab changes.
## Returns a VBoxContainer; meta "select" = Callable(index), meta "pages" = the page controls, meta "boxes" = the FitBoxes.
static func tabs(labels: Array, pages: Array, size: int = 16, first: int = 0, max_size: Vector2 = Vector2(-1, -1)) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var boxes: Array = []
	var seg := segmented(labels, first, func(i):
		for j in range(boxes.size()):
			boxes[j].visible = j == i, size, 40.0)
	seg.name = "Tabs"
	v.add_child(seg)
	for i in range(pages.size()):
		var fb := FitBox.new()
		fb.name = "Page%d" % i
		fb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.add_child(pages[i])
		fb.visible = i == first
		v.add_child(fb)
		boxes.append(fb)
	var equalize := func() -> void:
		var tallest := 0.0
		var widest := 0.0
		for p in pages:
			var ms: Vector2 = (p as Control).get_combined_minimum_size()
			tallest = maxf(tallest, ms.y)
			widest = maxf(widest, ms.x)
		var h := tallest if max_size.y <= 0.0 else minf(tallest, max_size.y)
		var w := widest if max_size.x <= 0.0 else minf(widest, max_size.x)
		for fb in boxes:
			fb.custom_minimum_size = Vector2(w, h)
	v.ready.connect(equalize)
	v.set_meta("pages", pages)
	v.set_meta("boxes", boxes)
	v.set_meta("tab_buttons", seg.get_children())
	v.set_meta("select", func(i: int):
		(seg.get_meta("select") as Callable).call(i)
		for j in range(boxes.size()):
			boxes[j].visible = j == i)
	return v
