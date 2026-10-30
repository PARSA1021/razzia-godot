extends Control
## Dialogue scene (Phase 14, restaged in Phase 25): a short noir "cut" between two characters.
##  - cinematic letterbox bars slide in, the table sinks into a dark vignette, a title says where we are and what is at stake
##  - each character stands as a framed dossier photo (their own art); the speaker steps forward, the listener falls back
##    into the shadow, so who is talking is clear at a glance
##  - the line types out in a gold-framed box with the speaker's name plate (in their personality colour) and a 1/2 counter
## Tap / click / Enter / Space / A = next (a tap while typing completes the line), SKIP / Esc / B = leave.
## lines: Array of {"who": name, "personality": "...", "text": "..."}; the first speaker stands left, the next different one right.
## Input is ignored for a moment after the scene (and every line) appears, so a stray Enter cannot skip it.
## Reduced motion: no slides, no typing, no bobbing.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")
const Portrait = preload("res://ui/portrait.gd")
const Characters = preload("res://ui/characters.gd")

signal finished(skipped: bool)

var lines: Array = []
var title := ""                      # e.g. "결투 · COLIBRI · $45,000" (optional)
var _i := 0
var _chars: Array = []              # [{who, personality}] left, right
var _faces: Array = []              # Dossier cards
var _tags: Array = []               # kept for older callers: the name plate (one, re-labelled per line)
var _text: Label
var _box: PanelContainer
var _name_plate: PanelContainer
var _name_label: Label
var _count: Label
var _arrow: Label
var _title_label: Label
var _typing := false
var _tween: Tween
var _armed_frame := 0
var _done := false
var _skip_btn: Button
var _t := 0.0
var _bars := 0.0                    # letterbox 0..1
var _speaker := -1


## A framed photo of a character: their art cropped to a portrait rectangle inside the round painting, a gold frame,
## a thin coloured rule for their personality. Falls back to the drawn round portrait when there is no art.
class Dossier extends Control:
	var who := ""
	var personality := ""
	var lit := 1.0: set = _set_lit
	var _tex: Texture2D = null
	var _fallback: Control = null

	func _init(p_who: String, p_pers: String) -> void:
		who = p_who
		personality = p_pers
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := "res://assets/characters_full/%s.png" % who
		if ResourceLoader.exists(path):
			_tex = Portrait._tex(path)
		else:
			_fallback = Portrait.new()
			_fallback.character = who
			_fallback.personality = personality
			add_child(_fallback)

	func _set_lit(v: float) -> void:
		lit = v
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10.0:
			return
		var col: Color = Portrait.COLORS.get(personality, T.GOLD)
		# drop shadow + mat
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0.0)
		sh.shadow_color = Color(0, 0, 0, 0.6)
		sh.shadow_size = int(w * 0.06)
		sh.set_corner_radius_all(int(w * 0.03))
		sh.draw(get_canvas_item(), Rect2(0, 0, w, h))
		draw_rect(Rect2(0, 0, w, h), Color("16110b"))
		var inner := Rect2(w * 0.045, w * 0.045, w * 0.91, h - w * 0.09)
		if _tex != null:
			# a 3:4 window inside the round painting (it fits: 0.6² + 0.8² = 1)
			var ts := _tex.get_size()
			var ar := inner.size.x / inner.size.y
			var sh_h := ts.y * 0.84
			var sw := minf(ts.x * 0.66, sh_h * ar)
			sh_h = sw / ar
			var src := Rect2((ts.x - sw) / 2.0, ts.y * 0.06, sw, sh_h)
			draw_texture_rect_region(_tex, inner, src)
		elif _fallback != null:
			_fallback.position = inner.position
			_fallback.size = inner.size
		# shade (the listener falls back into the dark)
		if lit < 0.999:
			draw_rect(inner, Color(0.02, 0.02, 0.015, 0.62 * (1.0 - lit)))
		# bottom fade for the name plate to sit on
		var fade_h := inner.size.y * 0.22
		draw_polygon(PackedVector2Array([Vector2(inner.position.x, inner.end.y - fade_h), Vector2(inner.end.x, inner.end.y - fade_h), inner.end, Vector2(inner.position.x, inner.end.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.75)]))
		draw_rect(inner, Color(T.GOLD, 0.35 + 0.5 * lit), false, maxf(1.5, w * 0.012))
		draw_rect(Rect2(0, 0, w, h), Color(T.GOLD, 0.25 + 0.6 * lit), false, maxf(2.0, w * 0.018))
		draw_rect(Rect2(inner.position.x, inner.end.y - maxf(3.0, w * 0.02), inner.size.x, maxf(3.0, w * 0.02)), Color(col, 0.5 + 0.5 * lit))
		# the name, on the photo
		var f := T.font("title", 800)
		var fs := int(clampf(w * 0.11, 14.0, 30.0))
		T.note_text(self, fs, who)
		draw_string(f, Vector2(inner.position.x, inner.end.y - fs * 0.55), who.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, fs, Color(1, 0.96, 0.86, 0.55 + 0.45 * lit))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 70
	Audio.play("panel_open")
	for l in lines:
		var known := false
		for c in _chars:
			if c["who"] == l["who"]:
				known = true
		if not known and _chars.size() < 2:
			_chars.append({"who": l["who"], "personality": l.get("personality", "")})
	for c in _chars:
		var card := Dossier.new(str(c["who"]), str(c["personality"]))
		add_child(card)
		_faces.append(card)
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override("panel", W.deco(Color("100c08f2"), T.GOLD, Vector4(30, 22, 30, 20), 1.0))
	_text = W.label("", 24, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(200, 64)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_text)
	add_child(_box)
	_name_plate = PanelContainer.new()
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = W.label("", 19, Color("1a120e"), "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_plate.add_child(_name_label)
	_name_plate.z_index = 5
	add_child(_name_plate)
	_tags.append(_name_plate)
	_count = W.label("", 14, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_RIGHT, 700)
	_count.z_index = 5
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_arrow = W.label("▼", 20, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_title_label = W.label(title, 18, T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.visible = title != ""
	add_child(_title_label)
	_skip_btn = W.button("SKIP ▶▶", "ghost", 16, Vector2(112, 38))
	_skip_btn.focus_mode = Control.FOCUS_NONE           # Esc / B leave; A must never land on SKIP by accident
	add_child(_skip_btn)
	_skip_btn.pressed.connect(func(): _leave(true))
	resized.connect(_layout)
	_layout()
	# entrance: bars close in, the cards slide from their sides
	if Settings.reduce_motion:
		_bars = 1.0
	else:
		var tw := create_tween()
		tw.tween_method(func(v): _bars = v; queue_redraw(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for k in range(_faces.size()):
			var c: Control = _faces[k]
			var to := c.position
			c.position = to + Vector2(-90.0 if k == 0 else 90.0, 0)
			c.modulate.a = 0.0
			var ft := create_tween().set_parallel(true)
			ft.tween_property(c, "position", to, 0.34).set_delay(0.06 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ft.tween_property(c, "modulate:a", 1.0, 0.24).set_delay(0.06 * k)
		_box.modulate.a = 0.0
		create_tween().tween_property(_box, "modulate:a", 1.0, 0.2).set_delay(0.12)
	_show_line(0)
	set_process(true)


var _base: Array = []              # card resting rects (before the speaker / listener offset)


func _layout() -> void:
	var w := size.x
	var h := size.y
	var portrait_mode := h > w
	var box_w := minf(w - 40.0, 960.0)
	var box_h := maxf(112.0, h * (0.15 if portrait_mode else 0.21))
	var bar_h := h * 0.075
	var box_y := h - box_h - bar_h - (8.0 if portrait_mode else 6.0)
	_box.position = Vector2((w - box_w) / 2.0, box_y)
	_box.custom_minimum_size = Vector2(box_w, box_h)
	_box.size = Vector2(box_w, box_h)
	_text.custom_minimum_size = Vector2(box_w - 64.0, 0)
	_arrow.position = Vector2(_box.position.x + box_w - 46.0, box_y + box_h - 36.0)
	_count.position = Vector2(_box.position.x + box_w - 150.0, box_y + box_h - 32.0)
	_count.size = Vector2(90, 20)
	_skip_btn.position = Vector2(w - 124.0, (bar_h - 38.0) / 2.0)
	_title_label.position = Vector2(0, (bar_h - 26.0) / 2.0)
	_title_label.size = Vector2(w, 26)
	# dossier cards stand behind the box's top edge, at its two ends
	var avail := box_y - bar_h - 16.0
	var ch := minf(avail * (0.96 if portrait_mode else 0.98), 430.0)
	var cw := ch * 0.75
	if portrait_mode:
		cw = minf(cw, (box_w - 24.0) / 2.0)
		ch = cw / 0.75
	_base.clear()
	for k in range(_faces.size()):
		var left := k == 0
		var x := (_box.position.x + 18.0) if left else (_box.position.x + box_w - 18.0 - cw)
		var y := box_y - ch + 22.0
		_base.append(Rect2(x, y, cw, ch))
		_faces[k].size = Vector2(cw, ch)
		_faces[k].pivot_offset = Vector2(cw / 2.0, ch)
		_faces[k].position = Vector2(x, y)
	_apply_speaker(false)
	_place_plate()
	queue_redraw()


## the name plate sits on the box's top edge, just inside the speaker's photo
func _place_plate() -> void:
	_name_plate.reset_size()
	var pw := _name_plate.size.x
	var left := _speaker <= 0
	var y := _box.position.y - _name_plate.size.y * 0.5
	var x := _box.position.x + 28.0
	if size.y > size.x:
		# tall screens: the photos fill the width, so the plate goes inside the box, on the speaker's side
		y = _box.position.y + 10.0
		x = (_box.position.x + 20.0) if left else (_box.position.x + _box.size.x - 20.0 - pw)
	elif _speaker >= 0 and _speaker < _base.size():
		var b: Rect2 = _base[_speaker]
		x = (b.end.x + 12.0) if left else (b.position.x - 12.0 - pw)
	elif not left:
		x = _box.position.x + _box.size.x - 28.0 - pw
	_name_plate.position = Vector2(clampf(x, 8.0, size.x - pw - 8.0), y)


## the speaker steps forward (full light, full size, a little lift); the listener falls back into the shadow
func _apply_speaker(animate: bool) -> void:
	for k in range(_faces.size()):
		if k >= _base.size():
			continue
		var on := k == _speaker
		var b: Rect2 = _base[k]
		var pos := b.position + (Vector2(0, -8.0) if on else Vector2(-16.0 if k == 0 else 16.0, 10.0))
		var sc := Vector2.ONE if on else Vector2(0.9, 0.9)
		var c: Control = _faces[k]
		c.z_index = 2 if on else 1
		if animate and not Settings.reduce_motion:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(c, "position", pos, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", sc, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "lit", 1.0 if on else 0.0, 0.22)
		else:
			c.position = pos
			c.scale = sc
			c.lit = 1.0 if on else 0.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	# the table sinks into a vignette
	draw_rect(Rect2(0, 0, w, h), Color(0.015, 0.02, 0.018, 0.62 * _bars + 0.1))
	var steps := 10
	for i in range(steps):
		var t := float(i) / float(steps)
		var inset := minf(w, h) * 0.06 * float(i)
		draw_rect(Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0), Color(0, 0, 0, 0.035 * _bars * (1.0 - t)), false, minf(w, h) * 0.06)
	# letterbox bars
	var bh := h * 0.075 * _bars
	draw_rect(Rect2(0, 0, w, bh), Color("050403"))
	draw_rect(Rect2(0, h - bh, w, bh), Color("050403"))
	draw_line(Vector2(0, bh), Vector2(w, bh), Color(T.GOLD, 0.35 * _bars), 1.0)
	draw_line(Vector2(0, h - bh), Vector2(w, h - bh), Color(T.GOLD, 0.35 * _bars), 1.0)
	if title != "" and _bars > 0.5:
		# deco rules either side of the title
		var f := T.font("title", 800)
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var cy := bh / 2.0
		var gap := 18.0
		draw_line(Vector2(w / 2.0 - tw / 2.0 - gap - 120.0, cy), Vector2(w / 2.0 - tw / 2.0 - gap, cy), Color(T.GOLD, 0.6), 1.0)
		draw_line(Vector2(w / 2.0 + tw / 2.0 + gap, cy), Vector2(w / 2.0 + tw / 2.0 + gap + 120.0, cy), Color(T.GOLD, 0.6), 1.0)


func _show_line(i: int) -> void:
	_i = i
	var l: Dictionary = lines[i]
	var who_idx := 0
	for k in range(_chars.size()):
		if _chars[k]["who"] == l["who"]:
			who_idx = k
	var changed := who_idx != _speaker
	_speaker = who_idx
	_apply_speaker(changed and i > 0)
	var info: Dictionary = Characters.info(_chars[who_idx]["personality"])
	_name_label.text = "%s%s" % [_chars[who_idx]["who"], ("  · " + info["label"]) if info["label"] != "" else ""]
	var col: Color = Portrait.COLORS.get(str(_chars[who_idx]["personality"]), T.GOLD)
	_name_plate.add_theme_stylebox_override("panel", W.sb(T.GOLD.lerp(col, 0.35), Color("fff4d8"), 1, 16, Vector4(16, 4, 16, 4)))
	_place_plate()
	_count.text = "%d / %d" % [i + 1, lines.size()]
	_armed_frame = Engine.get_process_frames() + 15
	_text.text = str(l["text"])
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if Settings.reduce_motion or _text.text.length() == 0:
		_text.visible_ratio = 1.0
		_typing = false
	else:
		_typing = true
		_text.visible_ratio = 0.0
		_tween = create_tween()
		_tween.tween_property(_text, "visible_ratio", 1.0, 0.028 * float(_text.text.length()) + 0.05)
		_tween.finished.connect(func(): _typing = false)
	_arrow.visible = true


func _process(d: float) -> void:
	if Settings.reduce_motion:
		_arrow.modulate.a = 1.0
		return
	_t += d
	_arrow.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)
	_arrow.position.y = _box.position.y + _box.size.y - 36.0 + sin(_t * 5.0) * 3.0


func _advance() -> void:
	if _done or Engine.get_process_frames() < _armed_frame:
		return
	if _typing:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_text.visible_ratio = 1.0
		_typing = false
		_armed_frame = Engine.get_process_frames() + 8
		return
	Audio.play("page")
	if _i + 1 >= lines.size():
		_leave(false)
	else:
		_show_line(_i + 1)


func _leave(skipped: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(skipped)
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_advance()
		accept_event()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_cancel"):
		_leave(true)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT, KEY_DOWN]:
		_advance()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_advance()
	elif event is InputEventAction and event.is_action_pressed("ui_accept"):
		_advance()              # a remapped / injected accept (Steam Input actions, accessibility tools)
	else:
		return
	get_viewport().set_input_as_handled()
