extends Control
## The tutorial (Phase 24): Sal, an informant who knows every bar on the strip, walks the player through three real rounds
## on a fixed table (ui/tutorial_plan.gd). Each idea is taught at the moment it happens, by doing it:
##   talk  - Sal says one or two lines; the table is dimmed except the thing he talks about; tap / A / Enter = next
##   do    - the player must do the thing; only the lit area takes input (keyboard / pad work as usual)
## Sits on top of the game screen as its last child (mouse picking follows tree order). It never touches the rules:
## the game asks it to wait at a few points (after_event / before_prompt) and it lights the right control.
## Pause (Esc / Start) works as in a normal game: the overlay steps aside while the pause panel is up.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")
const Portrait = preload("res://ui/portrait.gd")
const IMM = preload("res://platform/input_mode_manager.gd")
const Plan = preload("res://ui/tutorial_plan.gd")

signal _advance
signal finished(choice: String)        # "play" | "menu"

const GUIDE := "Sal"
const STEPS := {0: "입문 · 환영", 1: "1/3 · 독점 (나 혼자 들어가기)", 2: "2/3 · 협상과 주사위 결투", 3: "3/3 · 딜러와 경찰 단속", 4: "마무리 · 실전 준비 완료"}

var game: Control
var mode := ""                    # "" | "talk" | "do"
var hole := Rect2()               # lit area (this control's coordinates); size 0 = no hole
var _hole_to := Rect2()
var _target_fn: Callable = Callable()
var _until_fn: Callable = Callable()
var _hint_fn: Callable = Callable()
var _busy := false
var _t := 0.0
var _typing := false
var _type_tw: Tween
var _armed_at := 0                # input frame guard: a held / repeated press never skips a line
var done := {}                    # beats already shown (watchers fire once)
var prompt_open := {}             # pending type -> true while that prompt waits for the player
var _halted := false
var _step_round := 0
var _beat_id := 0                 # every beat gets a number: a beat that ends late never clears a newer one

var guide: PanelContainer
var _face: Control
var _name: Label
var _step: Label
var _text: Label
var _hint: Label
var _skip_btn: Button
var _foot: HBoxContainer
var _choice_row: HBoxContainer


func _init(p_game: Control) -> void:
	game = p_game
	name = "Tutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 58                  # above the board, the negotiation (45), the modal boards (46) and toasts (50)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	guide = PanelContainer.new()
	guide.mouse_filter = Control.MOUSE_FILTER_PASS        # a tap on the box itself also means "next"
	guide.add_theme_stylebox_override("panel", W.deco(Color("140f0af6"), T.GOLD, Vector4(20, 14, 22, 14), _u()))
	add_child(guide)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(16 * _u()))
	guide.add_child(hb)
	_face = Portrait.new()
	_face.character = GUIDE
	_face.personality = "OPPORTUNIST"
	_face.custom_minimum_size = Vector2(92, 92) * _u()
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_face)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(6 * _u()))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(10 * _u()))
	_name = W.label("SAL  · 정보원", int(15 * _u()), T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	_step = W.label("", int(13 * _u()), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_RIGHT, 700)
	top.add_child(_step)
	vb.add_child(top)
	_text = W.label("", int(20 * _u()), Color("f3ead6"), "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 0) * _u()
	vb.add_child(_text)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", int(12 * _u()))
	_hint = W.label("", int(15 * _u()), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.add_child(_hint)
	_skip_btn = W.button("튜토리얼 건너뛰기", "ghost", int(13 * _u()), Vector2(0, 32) * _u())
	_skip_btn.focus_mode = Control.FOCUS_NONE          # never steals a controller press meant for the table
	_skip_btn.set_meta("no_auto_focus", true)
	_skip_btn.pressed.connect(_on_skip)
	_foot.add_child(_skip_btn)
	vb.add_child(_foot)
	_choice_row = HBoxContainer.new()
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_choice_row.add_theme_constant_override("separation", int(12 * _u()))
	_choice_row.visible = false
	vb.add_child(_choice_row)
	guide.visible = false


func _u() -> float:
	return float(game.get("u")) if game != null and game.get("u") != null else 1.0


## ------------------------------------------------------------------ drawing / input

func _process(delta: float) -> void:
	_t += delta
	if game == null or not is_instance_valid(game):
		return
	# the pause panel (or anything paused) wins: step aside until it is closed
	var hidden: bool = get_tree().paused
	visible = not hidden
	if hidden:
		return
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child(self, -1)            # stay the last child: mouse picking follows tree order
	if mode != "" and _target_fn.is_valid():
		var r = _target_fn.call()
		_hole_to = r if r is Rect2 else Rect2()
	if mode != "":
		hole = Rect2(hole.position.lerp(_hole_to.position, minf(1.0, delta * 14.0)), hole.size.lerp(_hole_to.size, minf(1.0, delta * 14.0))) if hole.has_area() and _hole_to.has_area() else _hole_to
		if _hint_fn.is_valid():
			var h: String = str(_hint_fn.call())
			if h != _hint.text:
				_hint.text = h
		_place_guide()
		queue_redraw()
	if not _busy and not _halted:
		_watch()


func _draw() -> void:
	if mode == "":
		return
	var vp := size
	var a := 0.5 if mode == "do" else 0.66
	var dim := Color(0.01, 0.015, 0.012, a)
	if not hole.has_area():
		draw_rect(Rect2(Vector2.ZERO, vp), dim)
		return
	var h := hole.grow(8.0 * _u())
	draw_rect(Rect2(0, 0, vp.x, h.position.y), dim)
	draw_rect(Rect2(0, h.end.y, vp.x, vp.y - h.end.y), dim)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dim)
	draw_rect(Rect2(h.end.x, h.position.y, vp.x - h.end.x, h.size.y), dim)
	# a gold ring that breathes, so the eye finds the lit thing at once
	var pulse := 0.5 + 0.5 * sin(_t * 4.0) if not Settings.reduce_motion else 1.0
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(T.GOLD, 0.55 + 0.4 * pulse)
	ring.set_border_width_all(maxi(2, int(3.0 * _u())))
	ring.set_corner_radius_all(int(12.0 * _u()))
	ring.anti_aliasing = true
	ring.draw(get_canvas_item(), h.grow(2.0 + 3.0 * pulse))
	if mode == "do":
		# an arrow from the guide's side, bobbing towards the lit area
		var bob := (sin(_t * 5.0) * 6.0 * _u()) if not Settings.reduce_motion else 0.0
		var g := guide.get_rect()
		var above := g.get_center().y < h.get_center().y
		var tip := Vector2(h.get_center().x, h.position.y - 10.0 * _u() + bob) if above else Vector2(h.get_center().x, h.end.y + 10.0 * _u() - bob)
		var d := 1.0 if above else -1.0
		var s := 14.0 * _u()
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -s * 1.2 * d), tip + Vector2(s, -s * 1.2 * d)]), T.GOLD)


func _has_point(p: Vector2) -> bool:
	if mode == "" or not visible:
		return false
	if mode == "do" and hole.has_area() and hole.grow(8.0 * _u()).has_point(p):
		return false               # the lit area belongs to the game: clicks go through
	return true


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not press:
		return
	accept_event()
	if mode == "talk":
		_try_advance()
	elif mode == "do":
		_nudge()


func _input(event: InputEvent) -> void:
	if mode != "talk" or get_tree().paused or not visible:
		return
	if InputMap.has_action("pause") and event.is_action_pressed("pause"):
		return                     # the game opens its pause panel
	if event.is_action_pressed("ui_cancel"):
		return
	if InputMap.has_action("toggle_mute") and event.is_action_pressed("toggle_mute"):
		return
	var adv: bool = event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A) \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	if adv and not (event is InputEventKey and event.echo):
		_try_advance()
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()          # nothing reaches the table while Sal is talking


func _try_advance() -> void:
	if Engine.get_process_frames() < _armed_at:
		return
	if _typing:
		_finish_typing()
		return
	Audio.play("page")
	_advance.emit()


func _nudge() -> void:
	if Settings.reduce_motion:
		return
	var x0 := guide.position.x
	var tw := create_tween()
	for dx in [10.0, -8.0, 5.0, 0.0]:
		tw.tween_property(guide, "position:x", x0 + dx * _u(), 0.05)


## Where the guide box goes: the felt band between the venues and the hand, unless the lit area is there; then the top
## or the bottom edge, whichever keeps clear of it.
var place := "auto"               # "auto" | "top" | "side" | "bottom": where this beat would rather have Sal
var _avoid_fn: Callable = Callable()   # a second area to keep clear (the panel the lit button belongs to)


## Where the guide box goes: never on the lit area, and as little as possible on the panel it belongs to.
## Candidates: the felt band between venues and hand, right under / over the lit area, the bottom and top edges, and a
## narrower box beside it. The one covering the least wins (the lit area counts a thousand times more).
func _place_guide() -> void:
	var vp := size
	var u := _u()
	var full_w := minf(660.0 * u, vp.x - 24.0)
	var avoid: Array = []
	if hole.has_area():
		avoid.append([hole.grow(14.0 * u), 1000.0])
	if _avoid_fn.is_valid():
		var ar = _avoid_fn.call()
		if ar is Rect2:
			avoid.append([ar.grow(6.0 * u), 1.0])
	var cands: Array = []      # [x, y, w]
	var gh := _guide_h(full_w)
	var cx := (vp.x - full_w) / 2.0
	var mid := [cx, vp.y * 0.47 - gh / 2.0, full_w]
	var bottom := [cx, vp.y - gh - 12.0, full_w]
	var top := [cx, 12.0, full_w]
	var sides: Array = []
	if hole.has_area():
		var h := hole.grow(18.0 * u)
		var ref := h
		if avoid.size() > 1:
			ref = h.merge(avoid[1][0])
		for side in ["right", "left"]:
			var free: float = (vp.x - ref.end.x - 24.0) if side == "right" else (ref.position.x - 24.0)
			var w := minf(full_w, free)
			if w >= 300.0 * u:
				var sh := _guide_h(w)
				var sx: float = (ref.end.x + 12.0) if side == "right" else (ref.position.x - w - 12.0)
				sides.append([sx, clampf(h.get_center().y - sh / 2.0, 12.0, vp.y - sh - 12.0), w])
		cands.append([cx, h.end.y + 4.0, full_w])
		cands.append([cx, h.position.y - gh - 4.0, full_w])
	match place:
		"top":
			cands = [top] + cands + [mid, bottom] + sides
		"bottom":
			cands = [bottom] + cands + [mid, top] + sides
		"side":
			cands = sides + [mid] + cands + [bottom, top]
		_:
			cands = [mid] + cands + [bottom, top] + sides
	var best = null
	var best_score := INF
	for c in cands:
		var w: float = c[2]
		var r := Rect2(Vector2(clampf(c[0], 12.0, vp.x - w - 12.0), clampf(c[1], 8.0, maxf(8.0, vp.y - _guide_h(w) - 8.0))), Vector2(w, _guide_h(w)))
		var score := 0.0
		for a in avoid:
			var inter: Rect2 = r.intersection(a[0])
			if inter.has_area():
				score += inter.get_area() * float(a[1])
		if score < best_score - 0.5:
			best_score = score
			best = r
	if best == null:
		best = Rect2(Vector2(cx, mid[1]), Vector2(full_w, gh))
	_set_guide_width(best.size.x)
	guide.size = Vector2(best.size.x, guide.get_combined_minimum_size().y)
	guide.position = best.position


func _set_guide_width(w: float) -> void:
	var narrow := w < 520.0 * _u()
	# a narrow box (beside a panel) drops the long labels so its minimum width really is `w`
	_skip_btn.text = "건너뛰기" if narrow else "튜토리얼 건너뛰기"
	_step.text = str(STEPS.get(_step_round, "")).get_slice(" ·", 0) if narrow else str(STEPS.get(_step_round, ""))
	_name.text = "SAL" if narrow else "SAL  · 정보원"
	var tw := maxf(160.0, w - (92.0 + 16.0 + 46.0) * _u())
	if not is_equal_approx(_text.custom_minimum_size.x, tw):
		_text.custom_minimum_size = Vector2(tw, 0)
		_hint.custom_minimum_size = Vector2(maxf(60.0, tw - 130.0 * _u()), 0)
	guide.custom_minimum_size = Vector2(w, 0)


## height of the box at a width (lines of Sal's text at that width + the fixed rows)
func _guide_h(w: float) -> float:
	var tw := maxf(160.0, w - (92.0 + 16.0 + 46.0) * _u())
	var f: Font = _text.get_theme_font("font")
	var fs: int = _text.get_theme_font_size("font_size")
	var lines := 1
	if f != null:
		var tsz: Vector2 = f.get_multiline_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		lines = maxi(1, int(round(tsz.y / maxf(1.0, f.get_height(fs)))))
	var text_h: float = lines * (f.get_height(fs) if f != null else 26.0)
	var foot := 34.0 * _u() if _foot.visible else 0.0
	var choice := 56.0 * _u() if _choice_row.visible else 0.0
	return maxf(92.0 * _u(), 22.0 * _u() + text_h + foot + choice) + 30.0 * _u()


## ------------------------------------------------------------------ beats

func _show(text: String, step_round: int) -> void:
	var first := not guide.visible
	guide.visible = true
	_step_round = step_round
	_step.text = STEPS.get(step_round, "")
	_text.text = text
	_choice_row.visible = false
	_foot.visible = true
	if Settings.reduce_motion:
		_text.visible_ratio = 1.0
		_typing = false
	else:
		_text.visible_ratio = 0.0
		_typing = true
		if _type_tw != null and _type_tw.is_valid():
			_type_tw.kill()
		_type_tw = create_tween()
		_type_tw.tween_property(_text, "visible_ratio", 1.0, maxf(0.25, text.length() / 48.0))
		_type_tw.tween_callback(func(): _typing = false)
		if first:
			guide.modulate.a = 0.0
			create_tween().tween_property(guide, "modulate:a", 1.0, 0.18)
	_armed_at = Engine.get_process_frames() + 8
	_place_guide()


func _finish_typing() -> void:
	if _type_tw != null and _type_tw.is_valid():
		_type_tw.kill()
	_text.visible_ratio = 1.0
	_typing = false


func _continue_hint() -> String:
	var mode_name := ""
	var imm: Node = get_node_or_null("/root/InputModeManager")
	if imm != null:
		mode_name = imm.mode_name()
	if mode_name == "GAMEPAD":
		return "▶  A 버튼으로 계속"
	if mode_name == "TOUCH":
		return "▶  화면을 눌러 계속"
	return "▶  클릭 · Enter · Space로 계속"


## Sal says something; `target` = a Callable returning the Rect2 to light (or null for the whole table dimmed).
func talk(text: String, target: Callable = Callable(), step_round: int = -1, where: String = "auto", avoid: Callable = Callable()) -> void:
	place = where
	_avoid_fn = avoid
	_beat_id += 1
	_busy = true
	mode = "talk"
	_target_fn = target
	_hint_fn = Callable()
	_until_fn = Callable()
	var r0 = target.call() if target.is_valid() else null
	_hole_to = r0 if r0 is Rect2 else Rect2()
	hole = _hole_to
	_show(text, step_round if step_round >= 0 else _round())
	_hint.text = _continue_hint()
	_hint.add_theme_color_override("font_color", T.TEXT_DIM)
	await _advance
	_busy = false


## The player must do something: only `target` takes input until `until` is true.
func do(text: String, target: Callable, until: Callable, hint: Callable, step_round: int = -1, where: String = "auto", avoid: Callable = Callable()) -> int:
	place = where
	_avoid_fn = avoid
	_beat_id += 1
	var my := _beat_id
	_busy = true
	mode = "do"
	_target_fn = target
	_until_fn = until
	_hint_fn = hint
	var r = target.call()
	_hole_to = r if r is Rect2 else Rect2()
	hole = _hole_to
	_show(text, step_round if step_round >= 0 else _round())
	_hint.add_theme_color_override("font_color", T.GOLD)
	_hint.text = str(hint.call()) if hint.is_valid() else ""
	while is_inside_tree() and not until.call():
		await get_tree().process_frame
	if my == _beat_id:
		_busy = false
	return my


## clear only if no newer beat has started since `id`
func clear_beat(id: int) -> void:
	if id == _beat_id:
		clear()


func clear() -> void:
	mode = ""
	hole = Rect2()
	_target_fn = Callable()
	_hint_fn = Callable()
	guide.visible = false
	queue_redraw()


## ------------------------------------------------------------------ geometry helpers (rects in this control's space)

func _r(c) -> Variant:
	if c == null or not is_instance_valid(c) or not (c is Control) or not c.is_visible_in_tree():
		return null
	var gr: Rect2 = c.get_global_rect()
	return Rect2(gr.position - global_position, gr.size)


func _union(list: Array) -> Variant:
	var out = null
	for c in list:
		var r = _r(c)
		if r == null:
			continue
		out = r if out == null else out.merge(r)
	return out


func _bar(id: String) -> Variant:
	return _r(game.bar_views.get(id))


func _all_bars() -> Variant:
	return _union(game.bar_views.values())


func _hand_view(cid: String) -> Control:
	for v in game.hand_views:
		if is_instance_valid(v) and str(v.card.get("id", "")) == cid:
			return v
	return null


func _nego_btn(needle: String) -> Button:
	if game.nego == null or not game.nego.visible:
		return null
	for b in game.nego._action_box.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _modal_btn(needle: String) -> Button:
	for b in game.modal_layer.find_children("*", "Button", true, false):
		if needle in b.text and b.is_visible_in_tree():
			return b
	return null


func _p(action: String) -> String:
	return IMM.prompt_for(get_tree(), action)


func _pad() -> bool:
	var imm: Node = get_node_or_null("/root/InputModeManager")
	return imm != null and imm.mode_name() == "GAMEPAD"


## ------------------------------------------------------------------ the script

## the game waits for this after every event it shows
func after_event(ev: Dictionary) -> void:
	var r := int(ev.get("round", 0))
	var t := str(ev["type"])
	var nego_r := func(): return _r(game.nego)
	if t == "ROUND_STARTED" and r == 1 and not done.has("intro"):
		done["intro"] = true
		await talk("어이, 신입. 난 Sal. 이 거리 술집 여섯 곳 사정은 내가 다 알지.", Callable(), 0)
		await talk("규칙은 하나. 판이 끝날 때 돈을 제일 많이 쥔 놈이 이긴다.", Callable(), 0)
		await talk("세 라운드만 같이 돌자. 직접 해 보면 금방 감이 와.", Callable(), 0)
		clear()
	elif t == "MONEY_PLACED" and bool(ev.get("extra", false)) and r == 1 and not done.has("money"):
		done["money"] = true
		var x := str(ev["barId"])
		await talk("라운드마다 술집마다 머니카드가 한 장씩 깔려. 아래 숫자가 거기 쌓인 돈이야.", _all_bars)
		await talk(T.t("딜러는 한 장을 더 원하는 곳에 얹어. 금색 표시가 그 돈이지. 이번엔 %s.") % T.bar_name(x), func(): return _bar(x))
		clear()
	elif t == "MONEY_AWARDED" and str(ev["playerId"]) == Plan.ME and r == 1 and not done.has("r1won"):
		done["r1won"] = true
		Audio.play("tutorial_bell")
		var x1 := str(ev["barId"])
		await talk(T.t("봤지? %s엔 너 혼자였어. 그래서 %s 통째로 네 몫이야.") % [T.bar_name(x1), T.money(int(ev["amount"]))], func(): return _r(game.chips.get(Plan.ME)))
		clear()
	elif t == "NEGOTIATION_STARTED" and r == 2 and not done.has("nego"):
		done["nego"] = true
		await talk("한 술집에 도박꾼이 둘 이상이면 협상이야. 눈이 높은 네가 먼저 제안해.", nego_r, -1, "side")
		await talk("상대가 받으면 그대로 나누고, 거절하면 결투. 결투는 이긴 쪽이 전부 가져가.", nego_r, -1, "side")
		clear()
	elif t == "DUEL_CALLED" and r == 2 and not done.has("duelcall"):
		done["duelcall"] = true
		Audio.play("gavel")
		await talk("Vito가 거절했다. 결투다. 카드 눈 + 주사위, 높은 쪽이 판돈을 다 먹는다.", nego_r, -1, "side")
		clear()
	elif t == "MONEY_AWARDED" and str(ev["playerId"]) == Plan.ME and r == 3 and not done.has("raid"):
		done["raid"] = true
		Audio.play("police_whistle")
		Audio.play("tutorial_bell")
		var z := str(ev["barId"])
		await talk(T.t("단속 성공. Mack은 쫓겨났고, %s 돈은 경찰을 낸 네가 다 가져갔어.") % T.bar_name(z), func(): return _bar(z))
		await talk("경찰은 남이 키운 판을 뺏는 칼이야. 도박꾼 없는 곳에 내면 헛걸음이고.", func(): return _bar(z))
		clear()


## the game waits for this before it sets up a prompt for the player
func before_prompt(pending: Dictionary) -> void:
	var r := int(game.state.get("round", 0))
	var t := str(pending["type"])
	if t == "SELECT_CARD" and r == 1 and not done.has("hand"):
		done["hand"] = true
		await talk("네 손패야. 카드에 적힌 술집에만 낼 수 있어. 다들 동시에 한 장씩 엎어서 낸다.", func(): return _union(game.hand_views))
		clear()
	elif t == "SELECT_CARD" and r == 2 and not done.has("r2"):
		done["r2"] = true
		var tgt := Plan.human_target(game.state)
		var yb := str(tgt.get("barId", ""))
		await talk(T.t("이번엔 %s. 그런데 Vito도 거길 노린다는 소문이야.") % T.bar_name(yb), func(): return _bar(yb))
		clear()
	elif t == "PLACE_EXTRA_MONEY" and r == 3 and not done.has("dealer"):
		done["dealer"] = true
		await talk("이번엔 네가 딜러야. 추가 머니카드 한 장을 원하는 술집에 얹을 수 있어.", Callable())
		clear()
	elif t == "SELECT_CARD" and r == 3 and not done.has("r3"):
		done["r3"] = true
		var tg3 := Plan.human_target(game.state)
		var zb := str(tg3.get("barId", ""))
		await talk(T.t("%s를 봐. Mack이 도박꾼을 깔았어. 이번엔 파란 카드, 경찰을 써 보자.") % T.bar_name(zb), func(): return _bar(zb))
		clear()


## the prompt is on screen (cards are live, the bars are clickable...): light what the player must do
func prompt_ready(pending: Dictionary) -> void:
	var t := str(pending["type"])
	prompt_open[t] = true
	var r := int(game.state.get("round", 0))
	if t == "SELECT_CARD":
		var tgt := Plan.human_target(game.state)
		var cid := str(tgt.get("id", ""))
		_lock_others(cid)
		if r == 1:
			_r1_select(cid, str(tgt.get("barId", "")))
		elif r == 2:
			_play_card_beat(cid, T.t("네 카드 눈은 %d. 눈이 높은 쪽이 먼저 나눌 몫을 제안해. 이 카드를 내.") % int(tgt.get("dieSymbol", 0)))
		elif r == 3:
			_play_card_beat(cid, "경찰 카드를 내면 그 술집 도박꾼은 쫓겨나. 돈은 경찰끼리 나눠, 혼자면 전부.")
	elif t == "PLACE_EXTRA_MONEY":
		_extra_beat()
	elif t == "MAKE_PROPOSAL":
		_offer_beat()


func prompt_done(pending: Dictionary) -> void:
	prompt_open.erase(str(pending["type"]))
	for v in game.hand_views:
		if is_instance_valid(v):
			v.locked = false
			v.lock_text = "LOCKED"


func _lock_others(cid: String) -> void:
	for v in game.hand_views:
		if is_instance_valid(v):
			var other := str(v.card.get("id", "")) != cid
			v.lock_text = ""
			v.locked = other
	# focus lands on the one card that can be played
	game._clear_focus()
	game._move_focus(1)


func _r1_select(cid: String, x: String) -> void:
	await do(T.t("%s를 눌러 봐. 이 술집 카드가 얼마나 남았는지 보여 주지.") % T.bar_name(x), func(): return _bar(x),
		func(): return game.modal_layer.has_node("BarInfo"),
		func(): return (T.t("▶  %s 버튼") % _p("venue_info")) if _pad() else "▶  술집을 누르세요")
	await do("나온 카드, 네 손, 아직 안 나온 카드. 남은 눈이 낮을수록 네 카드가 유리해.",
		func(): return _r(game.modal_layer.get_node_or_null("BarInfo")),
		func(): return not game.modal_layer.has_node("BarInfo"),
		func(): return "▶  %s" % T.t("B 버튼으로 닫기" if _pad() else "닫기"), -1, "side")
	await _play_card_beat(cid, T.t("이 도박꾼 카드를 %s에 내. 혼자 들어가면 그 돈은 전부 네 거야.") % T.bar_name(x))


func _play_card_beat(cid: String, text: String) -> void:
	var card_rect := func():
		var v := _hand_view(cid)
		if game.selected_view != null and game.selected_view == v:
			return _union([v, game.confirm_btn])
		return _r(v)
	var hint := func():
		var v := _hand_view(cid)
		if game.selected_view != null and game.selected_view == v:
			return "▶  %s" % T.t("A 버튼으로 내기" if _pad() else "PLAY CARD")
		return "▶  %s" % T.t("A 버튼으로 카드 고르기" if _pad() else "빛나는 카드를 고르세요")
	var k := await do(text, card_rect, func(): return not prompt_open.has("SELECT_CARD"), hint)
	clear_beat(k)


func _extra_beat() -> void:
	var k := await do("노릴 곳에 얹으면 네 몫이 커지지. 아무 데나 골라 봐. 금액이 미리 보여.", _all_bars,
		func(): return not prompt_open.has("PLACE_EXTRA_MONEY"),
		func(): return "▶  %s" % T.t("십자키로 고르고 A" if _pad() else "술집을 고르세요"))
	clear_beat(k)


func _offer_beat() -> void:
	var k := await do("몫을 정해서 제안해. 너무 짜면 거절당하고, 너무 후하면 손해지.", func(): return _r(game.nego),
		func(): return not prompt_open.has("MAKE_PROPOSAL"),
		func(): return "▶  %s" % T.t("십자키로 고르고 A" if _pad() else "MAKE OFFER를 누르세요"), -1, "side")
	clear_beat(k)


## the round the board is showing (the engine is already ahead while the board replays)
func _round() -> int:
	return int(game.disp.get("round", 0))


## buttons inside a running replay (no engine prompt): the dice, the duel verdict, the round board
func _watch() -> void:
	var r := _round()
	var nego_r := func(): return _r(game.nego)
	var roll := _nego_btn("ROLL")
	if roll != null and not done.has("roll%d" % r):
		done["roll%d" % r] = true
		Audio.play("dice_cup")
		_run_btn_beat(roll, "굴려! 주사위 1~6이 카드 눈에 더해져.", "ROLL", "top", nego_r)
		return
	var verdict := _nego_btn("결과 확인")
	if verdict != null and not done.has("verdict%d" % r):
		done["verdict%d" % r] = true
		Audio.play("tutorial_bell")
		_run_btn_beat(verdict, "네가 이겼다. 하지만 결투는 도박이야. 거절 못 할 제안이 진짜 기술이지.", "결과 확인", "top", nego_r)
		return
	var nxt := _modal_btn("NEXT ROUND")
	if nxt == null:
		nxt = _modal_btn("FINAL RESULT")
	if nxt != null and not done.has("board%d" % r):
		done["board%d" % r] = true
		var lines := {1: "라운드가 끝나면 장부가 정리돼. 누가 어디서 얼마 벌었는지 여기서 봐.", 2: "결투로 판돈을 통째로 챙겼군. 다음 라운드.", 3: "마지막 장부야. 넘기면 마무리하자."}
		_run_btn_beat(nxt, str(lines.get(r, "다음 라운드로.")), "NEXT ROUND")


func _run_btn_beat(btn: Button, text: String, label: String, where: String = "auto", avoid: Callable = Callable()) -> void:
	var bid := btn.get_instance_id()          # never capture the node itself: it is freed when pressed
	var alive := func() -> Button:
		var o = instance_from_id(bid)
		return o if o != null and is_instance_valid(o) and o.is_inside_tree() and not o.is_queued_for_deletion() and o.is_visible_in_tree() else null
	if not avoid.is_valid():
		# keep clear of the panel the button sits in (the round board), not of a full-screen dim behind it
		var pid := 0
		var n: Node = btn.get_parent()
		while n != null and n != game:
			if n is PanelContainer:
				pid = n.get_instance_id()
				break
			n = n.get_parent()
		if pid != 0:
			avoid = func():
				var o = instance_from_id(pid)
				return _r(o) if o != null and is_instance_valid(o) else null
	var k := await do(text, func(): return _r(alive.call()), func(): return alive.call() == null,
		func(): return "▶  %s" % T.t("A 버튼" if _pad() else label), -1, where, avoid)
	clear_beat(k)


## ------------------------------------------------------------------ end / skip

func should_halt(ev: Dictionary) -> bool:
	return _halted or (str(ev["type"]) == "ROUND_STARTED" and int(ev.get("round", 0)) > Plan.ROUNDS)


func finale() -> void:
	_halted = true
	Settings.tutorial_done = true
	Settings.save_settings()
	Audio.play("tutorial_bell")
	await talk("이게 전부야. 혼자 먹고, 나누고, 싸우고, 단속하고.", Callable(), 4)
	await talk("진짜 판은 머니카드가 바닥날 때까지 계속돼. 행운을 빌지, 신입.", Callable(), 4)
	_offer_choice()


func _offer_choice() -> void:
	mode = "choice"
	_busy = true
	_foot.visible = false
	for c in _choice_row.get_children():
		c.queue_free()
	var play := W.button("진짜 게임 시작", "primary", int(19 * _u()), Vector2(200, 50) * _u())
	var menu := W.button("메뉴로", "secondary", int(17 * _u()), Vector2(130, 50) * _u())
	_choice_row.add_child(menu)
	_choice_row.add_child(play)
	_choice_row.visible = true
	play.pressed.connect(func(): finished.emit("play"))
	menu.pressed.connect(func(): finished.emit("menu"))
	_place_guide()
	play.grab_focus.call_deferred()


func _on_skip() -> void:
	if _halted:
		return
	_halted = true
	Settings.tutorial_done = true
	Settings.save_settings()
	finished.emit("play")
