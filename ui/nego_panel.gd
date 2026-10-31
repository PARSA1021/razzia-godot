extends PanelContainer
## Negotiation + duel board shown over the table (docs/05 §11-14).
## It only DISPLAYS what the engine decided (RULE-034) and collects the human's answer:
##   ask_proposal(view)  -> allocations Dictionary      (human is the proposer)
##   ask_response(view)  -> "ACCEPT" | "DUEL"           (human answers an offer)
##   ask_roll()          -> returns when ROLL is tapped (human takes part in a duel)
## Everything else (open / set_proposal / set_mark / begin_duel / set_rolls / finish_duel) replays engine events.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")
const Audio = preload("res://ui/audio.gd")
const Characters = preload("res://ui/characters.gd")
const Portrait = preload("res://ui/portrait.gd")

signal decided(value)
signal opened                      # the panel has just been opened (used by screenshot tests)

const PALETTE := [Color("d6b274"), Color("4f8fd0"), Color("c9503f"), Color("4fb06a"), Color("a56bd0"), Color("e08a3a"), Color("3fb5b0"), Color("d070a0")]

var names := {}              # playerId -> display name
var human_id := ""
var u := 1.0                 # ui scale
var panel_width := 560.0
var landscape := false
var dock_x0 := 0.0             # landscape bottom dock: horizontal range the panel is centred in
var dock_x1 := 0.0
var wide_width := 700.0        # landscape bottom dock: panel width (canvas px)
var dock_limit_y := -1.0       # >= 0 (portrait): dock the panel to the bottom, never above this y, so the venue grid stays visible
var side := ""                # landscape: "left" / "right" = park the panel at that side of [side_x0, side_x1] so the target venue stays uncovered
var side_x0 := 0.0
var side_x1 := 0.0
var skipping: Callable = Callable()    # returns true while the player asked to skip

var neg := {}                # NEGOTIATION_STARTED event
var proposal := {}           # playerId -> amount (empty until PROPOSAL_MADE)
var marks := {}              # playerId -> "ACCEPT" | "DUEL"

var _header: VBoxContainer
var _rows: VBoxContainer
var _split: Control
var _duel_box: VBoxContainer
var _action_box: VBoxContainer
var _status: Label
var _speech: Label
var _speech_box: HBoxContainer
var _speech_face: Control
var _die_a: Control
var _die_b: Control
var _verdict_a: Label
var _verdict_b: Label
var _sum_a: Label
var _sum_b: Label
var _duel_banner: Label
## Duel stages (spec A..G). Each transition happens once; late / duplicate callbacks and stale tweens are ignored (token).
enum DuelPhase { NONE, INTRO, ROLLING, REVEAL, SETTLEMENT, REACTION, WAITING, DONE }
var duel_phase := DuelPhase.NONE
var _duel_token := 0
var _pot_label: Label
var _duel_tag: Label
var _bubble_a: Label
var _bubble_b: Label
var _flash := 0.0: set = _set_flash
var _card_a: PanelContainer
var _card_b: PanelContainer
var _face_a: Control
var _face_b: Control
var _duel_ev := {}
var _stake := 0                # what the duel winner takes (both proposals added; 0 = not known)
var _stage := 0                # 0 offer, 1 answer, 2 duel, 3 payout (the step bar in the header)
var _stage_box: HBoxContainer


func _init() -> void:
	W.ensure_pad_bindings()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style(false)
	minimum_size_changed.connect(_queue_fit)
	resized.connect(_queue_fit)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	_header = VBoxContainer.new()
	vb.add_child(_header)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	vb.add_child(_rows)
	_split = Control.new()
	vb.add_child(_split)
	_duel_box = VBoxContainer.new()
	vb.add_child(_duel_box)
	_speech_box = HBoxContainer.new()
	_speech_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_speech_box.add_theme_constant_override("separation", 10)
	_speech_box.visible = false
	_speech_face = Portrait.new()
	_speech_face.custom_minimum_size = Vector2(64, 64)
	_speech_box.add_child(_speech_face)
	_speech = W.label("", 17, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD
	_speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speech_box.add_child(_speech)
	vb.add_child(_speech_box)
	_status = W.label("", 17, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_status)
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 8)
	vb.add_child(_action_box)


## The panel grows with its content (offer steppers, duel dice…). If it would not fit on a short screen
## (landscape phone, Steam Deck) it is scaled down so the action buttons are never pushed off-screen.
var _fit_queued := false
const MIN_READ_K := 0.9       # docked fit scale x screen scale below this -> the smallest text would drop under ~11px: undock
var _bottom := false          # this event uses the bottom dock (always in portrait; landscape only when the text stays readable)
var _stage_mode := false      # the duel is shown as a centred 'stage' (header / rows hidden, big dice)
var _compact := false         # landscape bottom dock: one-line header, smaller dice
var _eff_w := 560.0
var slide := 0.0: set = _set_slide     # extra downward offset used by the slide-in / slide-out motion (visual only)
var _base_pos := Vector2.ZERO
var _motion: Tween


## Frame: the offer phase is a dark noir card with the venue poster as a banner; the duel is a green-felt table. Presentation only.
func _apply_style(felt: bool) -> void:
	if felt:
		add_theme_stylebox_override("panel", W.sb(Color("0c2318"), T.GOLD, 3, 16, Vector4(22, 14, 22, 16)))
	else:
		add_theme_stylebox_override("panel", W.sb(Color("100c08"), T.GOLD, 3, 16, Vector4(22, 16, 22, 18)))
	queue_redraw()


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 40.0 or h < 40.0:
		return
	if _stage_mode:
		# felt: lighter in the middle, darker at the rim, plus a soft top light
		var top := Color("17402c")
		var bot := Color("08160f")
		draw_polygon(PackedVector2Array([Vector2(6, 6), Vector2(w - 6, 6), Vector2(w - 6, h - 6), Vector2(6, h - 6)]), PackedColorArray([top, top, bot, bot]))
		for i in range(24):
			draw_circle(Vector2(w / 2.0, h * 0.42), w * (0.04 + 0.02 * i), Color(1.0, 0.92, 0.7, 0.006))
	elif not neg.is_empty() and neg.has("barId"):
		var tex: Texture2D = T.art("bar", str(neg["barId"]))
		var bh := 6.0
		if _header != null and _header.get_parent() != null:
			bh = (_header.get_parent() as Control).position.y + _header.position.y + _header.size.y + _fs(8)
		bh = clampf(bh, 40.0, h * 0.5)
		if tex != null:
			T.draw_cover(self, tex, Rect2(6, 6, w - 12, bh), 0.35, Color(1, 1, 1, 0.9))
		var bg := Color("100c08")
		draw_polygon(PackedVector2Array([Vector2(6, 6), Vector2(w - 6, 6), Vector2(w - 6, 6 + bh), Vector2(6, 6 + bh)]), PackedColorArray([Color(bg, 0.25), Color(bg, 0.25), Color(bg, 1.0), Color(bg, 1.0)]))
		var vc := T.bar_color(str(neg["barId"]))
		draw_rect(Rect2(6, 6, w - 12, 4), vc)
	if _flash > 0.01:
		draw_rect(Rect2(6, 6, w - 12, h - 12), Color(T.GOLD, 0.22 * _flash))
	# Art Deco corners
	var g := T.GOLD
	var L := 22.0
	var m := 10.0
	for c in [[Vector2(m, m), Vector2(1, 1)], [Vector2(w - m, m), Vector2(-1, 1)], [Vector2(m, h - m), Vector2(1, -1)], [Vector2(w - m, h - m), Vector2(-1, -1)]]:
		var o: Vector2 = c[0]
		var d: Vector2 = c[1]
		draw_line(o, o + Vector2(L * d.x, 0), g, 2.0, true)
		draw_line(o, o + Vector2(0, L * d.y), g, 2.0, true)
		draw_rect(Rect2(o + Vector2(5 * d.x, 5 * d.y) - Vector2(2, 2), Vector2(4, 4)), g)


func _queue_fit() -> void:
	queue_redraw()
	if not _fit_queued:
		_fit_queued = true
		_fit_to_screen.call_deferred()


func _fit_to_screen() -> void:
	_fit_queued = false
	var par := get_parent() as Control
	var pw: float = par.size.x if par != null and par.size.x > 10.0 else get_viewport_rect().size.x
	var ph: float = par.size.y if par != null and par.size.y > 10.0 else get_viewport_rect().size.y
	var m := get_combined_minimum_size()
	var target := Vector2(maxf(m.x, _eff_w), m.y)
	if _stage_mode:
		target.x = maxf(m.x, minf(pw - 24.0, 860.0 * u))
	if not size.is_equal_approx(target):
		size = target
	var room := ph - 16.0
	if _bottom and not _stage_mode:
		room = minf(room, ph - dock_limit_y - 12.0)
	var k := minf(1.0, minf(room / maxf(1.0, target.y), (pw - 16.0) / maxf(1.0, target.x)))
	# 가독성 우선 (Steam Deck 1280x800 기준 최소 글자 크기): 아래쪽 도킹 공간에 맞추느라 글자가 너무 작아지면
	# 도킹을 풀고 옆자리(목표 술집 반대편)로 옮겨 화면 높이 전체를 씁니다. 내용·규칙은 그대로, 위치만 바뀝니다.
	if _bottom and landscape and not _stage_mode and side != "" and k * T.screen_scale < MIN_READ_K:
		_bottom = false
		_eff_w = panel_width
		_fit_to_screen()
		return
	# portrait (Phase 28): on a phone the bottom dock left the panel at ~5 px text. When docking would make it unreadable,
	# the panel takes the whole screen height instead (the venue and the pot are in its own header)
	if _bottom and not landscape and not _stage_mode and k * T.screen_scale < MIN_READ_K:
		_bottom = false
		_fit_to_screen()
		return
	pivot_offset = target / 2.0
	scale = Vector2(k, k)
	var cy := (ph - target.y) / 2.0
	var px := (pw - target.x) / 2.0
	if _stage_mode:
		pass
	elif _bottom:
		cy = ph - 12.0 - target.y * k / 2.0 - target.y / 2.0       # visual bottom edge 12px above the screen edge
		if landscape and dock_x1 > dock_x0:
			px = (dock_x0 + dock_x1) / 2.0 - target.x / 2.0
	elif side == "left":
		px = side_x0 - target.x * (1.0 - k) / 2.0
	elif side == "right":
		px = side_x1 - target.x * (1.0 + k) / 2.0
	_base_pos = Vector2(px, cy)
	position = _base_pos + Vector2(0.0, slide)


func _set_slide(v: float) -> void:
	slide = v
	position = _base_pos + Vector2(0.0, v)


## Slide-in / slide-out is purely visual: engine state and the game flow never wait for it.
func _present(show_it: bool) -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	var d := Settings.dur(0.25 if show_it else 0.18)
	if d <= 0.0 or _skip() or not is_inside_tree():
		slide = 0.0
		modulate.a = 1.0 if show_it else 0.0
		if not show_it:
			_finish_close()
		return
	_motion = create_tween()
	_motion.set_parallel(true)
	if show_it:
		slide = 56.0 * u
		modulate.a = 0.0
		_motion.tween_property(self, "slide", 0.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion.tween_property(self, "modulate:a", 1.0, d * 0.8)
	else:
		_motion.tween_property(self, "slide", 56.0 * u, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_motion.tween_property(self, "modulate:a", 0.0, d)
		_motion.chain().tween_callback(_finish_close)


var personalities := {}      # playerId -> personality (AI only; display label only)


func setup(p_names: Dictionary, p_human: String, p_u: float, p_width: float) -> void:
	names = p_names
	human_id = p_human
	u = p_u
	panel_width = p_width
	custom_minimum_size = Vector2(p_width, 0)


func _me_tag(pid: String) -> String:
	return "" if pid != human_id or str(names.get(pid, "")) == "나" else "  " + T.t("(나)")


func _nm(pid: String) -> String:
	var n := str(names.get(pid, pid))
	return T.t(n) if n == "나" else n          # the default name is a word ("나" / "You"); a chosen name is shown as typed


func _fs(base: float) -> int:
	return int(round(T.fs(base * u, 1.6)))


func _pcolor(pid: String) -> Color:
	if pid == human_id:
		return PALETTE[0]
	var idx := 1
	if neg.has("claimantIds"):
		for i in range(neg["claimantIds"].size()):
			if neg["claimantIds"][i] == pid:
				idx = i + 1
	return PALETTE[1 + (idx % (PALETTE.size() - 1))] if pid != human_id else PALETTE[0]


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _skip() -> bool:
	return skipping.is_valid() and bool(skipping.call())


func _pause(sec: float) -> void:
	var d := Settings.hold(sec)
	var t := d
	while t > 0.0 and not _skip():
		await get_tree().process_frame
		t -= get_process_delta_time()


## ---------------------------------------------------------------- replay of engine events

func open(ev: Dictionary) -> void:
	neg = ev
	proposal = {}
	marks = {}
	_duel_ev = {}
	_clear(_header)
	_clear(_duel_box)
	_clear(_action_box)
	_clear_split()
	_stage_mode = false
	_apply_style(false)
	_header.visible = true
	_rows.visible = true
	_split.visible = true
	_decide_dock()
	visible = true
	var title := W.label(T.bar_name(ev["barId"]), _fs(30), Color("fff4d8"), "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	var prize := W.label(T.money(int(ev["prize"])), _fs(52), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
	for hl in [title, prize]:
		hl.add_theme_constant_override("outline_size", 10)
		hl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	if _compact:
		var hrow := HBoxContainer.new()
		hrow.alignment = BoxContainer.ALIGNMENT_CENTER
		hrow.add_theme_constant_override("separation", _fs(24))
		hrow.add_child(title)
		hrow.add_child(prize)
		_header.add_child(hrow)
	else:
		_header.add_child(title)
		_header.add_child(prize)
	var kind_text := "도박꾼들이 이 술집의 돈을 두고 다툽니다"
	if ev["kind"] == "RAZZIA":
		kind_text = "RAZZIA — 도박꾼은 쫓겨나고, 경찰 카드를 낸 사람들이 돈을 나눕니다"
	var kl := W.label(kind_text, _fs(14), T.DANGER if ev["kind"] == "RAZZIA" else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	kl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if not (_compact and ev["kind"] != "RAZZIA"):
		_header.add_child(kl)
	_stage_box = HBoxContainer.new()
	_stage_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_box.add_theme_constant_override("separation", _fs(6))
	_header.add_child(_stage_box)
	_stage = 0
	_render_stage()
	_render_rows()
	set_status(T.t("%s 님이 먼저 제안합니다 (가장 높은 눈).") % _nm(ev["proposerId"]))
	Audio.focus(true)
	Audio.play("nego_open")
	reset_size()
	_present(true)
	opened.emit()


## Step bar: 제안 -> 응답 -> 결투 -> 정산. Past steps are ticked, the current one is lit.
func set_stage(i: int) -> void:
	if i > _stage:
		Audio.play("stage")
	_stage = i
	_render_stage()


func _render_stage() -> void:
	if _stage_box == null or not is_instance_valid(_stage_box):
		return
	_clear(_stage_box)
	var labels := ["제안", "응답", "결투", "정산"]
	for i in range(labels.size()):
		var col := T.TEXT_DIM
		var txt: String = "%d %s" % [i + 1, T.t(labels[i])]
		var bg := Color("1d1710")
		var border := Color(T.BRASS, 0.35)
		if i < _stage:
			col = T.OK
			txt = T.t(labels[i])
			border = Color(T.OK, 0.5)
		elif i == _stage:
			col = Color("1a120e")
			bg = T.GOLD
			border = T.GOLD
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", W.sb(bg, border, 1, 14, Vector4(10, 2, 10, 2)))
		chip.add_child(W.label(txt, _fs(13), col, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800))
		_stage_box.add_child(chip)
		if i < labels.size() - 1:
			_stage_box.add_child(W.label("›", _fs(14), T.BRASS, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))


## Portrait: always docked at the bottom. Landscape: docked at the bottom when its text would stay readable (>= 70 % of the
## designed size after fitting under the venue row), otherwise parked at the side away from the target venue.
func _decide_dock() -> void:
	_bottom = dock_limit_y >= 0.0
	_compact = false
	_eff_w = panel_width
	if landscape and dock_limit_y >= 0.0:
		var room := get_viewport_rect().size.y - dock_limit_y - 12.0
		var par := get_parent() as Control
		if par != null and par.size.y > 10.0:
			room = par.size.y - dock_limit_y - 12.0
		var est := room / (470.0 * u)
		_bottom = minf(1.0, est) * T.screen_scale >= 0.7
		_compact = _bottom
		if _bottom:
			_eff_w = wide_width


func _clear_split() -> void:
	for c in _split.get_children():
		c.queue_free()
	_split.custom_minimum_size = Vector2.ZERO


func _render_rows() -> void:
	_clear(_rows)
	if neg.is_empty():
		return
	for pid in neg["claimantIds"]:
		var row := PanelContainer.new()
		var is_prop: bool = pid == neg["proposerId"]
		var rs := W.sb(Color("1b140c") if not is_prop else Color("2a1f10"), Color(T.BRASS, 0.45), 1, 12, Vector4(10, 6, 14, 6))
		rs.border_width_left = 7
		rs.border_color = _pcolor(pid)
		if pid == human_id:
			rs.border_width_top = 2
			rs.border_width_bottom = 2
			rs.border_width_right = 2
		row.add_theme_stylebox_override("panel", rs)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", _fs(12))
		row.add_child(hb)
		var fb := CenterContainer.new()
		fb.custom_minimum_size = Vector2(_fs(54), _fs(54))
		if personalities.has(pid) and pid != human_id:
			var face := Portrait.new()
			face.personality = personalities[pid]
			face.character = _nm(pid)
			face.custom_minimum_size = Vector2(_fs(52), _fs(52))
			fb.add_child(face)
		else:
			var me := PanelContainer.new()
			me.custom_minimum_size = Vector2(_fs(46), _fs(46))
			me.add_theme_stylebox_override("panel", W.sb(Color("2a2014"), T.GOLD, 3, _fs(23), Vector4(0, 0, 0, 0)))
			var ml := W.label(_nm(pid).substr(0, 1), _fs(22), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
			ml.size_flags_vertical = Control.SIZE_EXPAND_FILL
			ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			me.add_child(ml)
			fb.add_child(me)
		hb.add_child(fb)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		var nm := _nm(pid) + _me_tag(pid)
		nv.add_child(W.label(nm, _fs(22), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
		if is_prop:
			nv.add_child(W.label(T.t("제안자"), _fs(13), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700))
		hb.add_child(nv)
		var die := W.DieView.new()                      # the card's eye as a real die face (the same pips as the rules)
		die.custom_minimum_size = Vector2(_fs(34), _fs(34))
		die.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		die.value = int(neg["symbols"][pid])
		die.tooltip_text = T.t("카드 눈 %d") % int(neg["symbols"][pid])
		hb.add_child(die)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(sp)
		var right := ""
		var rc := T.TEXT_DIM
		if proposal.has(pid):
			right = T.money(int(proposal[pid]))
			rc = T.GOLD
		hb.add_child(W.label(right, _fs(28), rc, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800))
		var mk := ""
		var mc := T.TEXT_DIM
		if pid != neg["proposerId"] and not proposal.is_empty():
			match marks.get(pid, ""):
				"ACCEPT":
					mk = tr("수락")
					mc = T.OK
				"DUEL":
					mk = tr("결투")
					mc = T.DANGER
				_:
					mk = "대기…"
		if mk != "":
			var mp := PanelContainer.new()
			mp.add_theme_stylebox_override("panel", W.sb(Color(mc, 0.16), Color(mc, 0.8), 1, 12, Vector4(8, 2, 8, 2)))
			var ml2 := W.label(mk, _fs(15), mc, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
			ml2.custom_minimum_size = Vector2(_fs(58), 0)
			mp.add_child(ml2)
			hb.add_child(mp)
		_rows.add_child(row)


## A short in-character line from an AI player ("situation": propose / accept / duel / win / lose). Deterministic per event; never for the human.
func say(pid: String, situation: String, seed_n: int) -> void:
	if pid == human_id or not personalities.has(pid):
		return
	if _stage_mode and situation in ["win", "lose"]:
		return                                  # the duel stage shows these inside the player cards
	var line := Characters.line_for(_nm(pid), personalities[pid], situation, seed_n)
	if line == "":
		return
	_speech.text = "%s: \"%s\"" % [_nm(pid), line]
	_speech.add_theme_font_size_override("font_size", _fs(16))
	_speech_face.personality = personalities[pid]
	_speech_face.character = _nm(pid)
	_speech_face.emotion = Characters.emotion_for(situation, personalities[pid])
	_speech_face.custom_minimum_size = Vector2(_fs(64), _fs(64))
	_speech_box.visible = true
	Audio.bark(_nm(pid), situation)


func set_status(text: String) -> void:
	_status.text = text
	_status.add_theme_font_size_override("font_size", _fs(17))


func set_proposal(ev: Dictionary) -> void:
	proposal = ev["proposal"]
	_render_rows()
	_draw_split(proposal)
	set_stage(1)
	set_status(T.t("%s 님의 제안이에요. 나머지는 수락하거나 결투를 선언할 수 있습니다.") % _nm(ev["proposerId"]))
	reset_size()


func set_mark(pid: String, resp: String) -> void:
	marks[pid] = resp
	_render_rows()
	reset_size()


func _draw_split(alloc: Dictionary) -> void:
	_clear_split()
	var bar := SplitBar.new()
	bar.u = u
	var total := 0
	for pid in neg["claimantIds"]:
		total += int(alloc.get(pid, 0))
	for pid in neg["claimantIds"]:
		bar.segments.append({"label": _nm(pid), "amount": int(alloc.get(pid, 0)), "color": _pcolor(pid), "total": total})
	bar.custom_minimum_size = Vector2(0, _fs(34))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_split.custom_minimum_size = Vector2(0, _fs(36))


## --- duel -------------------------------------------------------------

func begin_duel(ev: Dictionary) -> void:
	_duel_ev = ev
	_duel_token += 1
	duel_phase = DuelPhase.INTRO
	_flash = 0.0
	_clear(_duel_box)
	_clear(_action_box)
	# the duel is the highlight: the offer rows / header step aside and the panel becomes a centred stage with big dice
	_stage_mode = true
	_speech_box.visible = false                 # the stage shows reactions inside the player cards
	_apply_style(true)
	_header.visible = false
	_rows.visible = false
	_split.visible = false
	var big := not _compact_screen()
	var dsz := _fs(144 if big else 84)
	var psz := _fs(92 if big else 60)
	var title := W.label("DUEL  ·  %s" % T.bar_name(neg.get("barId", "")), _fs(20), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_duel_box.add_child(title)
	var stake := 0
	if proposal.has(ev["playerA"]) and proposal.has(ev["playerB"]):
		stake = int(proposal[ev["playerA"]]) + int(proposal[ev["playerB"]])
	_stake = stake
	if stake > 0:
		var plaque := PanelContainer.new()
		plaque.add_theme_stylebox_override("panel", W.sb(Color("1a1208"), T.GOLD, 3, 20, Vector4(26, 4, 26, 6)))
		plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", -2)
		pv.add_child(W.label(tr("판돈 (승자 독식)"), _fs(12), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))
		_pot_label = W.label(T.money(stake), _fs(40), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
		pv.add_child(_pot_label)
		plaque.add_child(pv)
		_duel_box.add_child(plaque)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", _fs(24))
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_duel_box.add_child(hb)
	var sides := []
	for side in ["A", "B"]:
		var pid: String = ev["player" + side]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", W.sb(Color(0, 0, 0, 0.32), Color(T.GOLD, 0.55), 2, 18, Vector4(10, 10, 10, 8)))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		vb.custom_minimum_size = Vector2(_fs(230 if big else 170), 0)
		card.add_child(vb)
		# portrait (AI) or a gold monogram ring (me)
		var face_box := CenterContainer.new()
		var face: Control = null
		if personalities.has(pid) and pid != human_id:
			face = Portrait.new()
			face.personality = personalities[pid]
			face.character = _nm(pid)
			face.custom_minimum_size = Vector2(psz, psz)
			face_box.add_child(face)
		else:
			var me := PanelContainer.new()
			me.custom_minimum_size = Vector2(psz, psz)
			me.add_theme_stylebox_override("panel", W.sb(Color("2a2014"), T.GOLD, 3, psz / 2, Vector4(0, 0, 0, 0)))
			var ml := W.label(_nm(pid).substr(0, 1), int(psz * 0.5), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
			ml.size_flags_vertical = Control.SIZE_EXPAND_FILL
			ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			me.add_child(ml)
			face_box.add_child(me)
		vb.add_child(face_box)
		var is_ch: bool = pid == ev["challengerId"]
		var role_box := HBoxContainer.new()
		role_box.alignment = BoxContainer.ALIGNMENT_CENTER
		role_box.add_theme_constant_override("separation", int(_fs(4)))
		var role_icon_tex := T.system_icon("challenger" if is_ch else "defender")
		var role_icon := W.icon_rect(role_icon_tex, Vector2(_fs(14), _fs(14)), Color("ff6b5a") if is_ch else Color("6ab4ff"))
		role_box.add_child(role_icon)
		var role_lbl := W.label(tr("도전자") if is_ch else tr("방어자"), _fs(13), Color("ff6b5a") if is_ch else Color("6ab4ff"), "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
		role_box.add_child(role_lbl)
		vb.add_child(role_box)
		vb.add_child(W.label(_nm(pid) + (_me_tag(pid)), _fs(24 if big else 19), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))
		vb.add_child(W.label(T.t("카드 눈 %d") % int(ev["symbol" + side]), _fs(14), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
		var other_sym: int = int(ev["symbolB" if side == "A" else "symbolA"])
		var chance := Eng.duel_win_probability(int(ev["symbol" + side]), other_sym, is_ch)
		if Settings.beginner_hints:
			vb.add_child(W.label(T.t("이길 확률 약 %d%%") % int(round(chance * 100.0)), _fs(15), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))
		vb.add_child(Control.new())
		var die := W.DieView.new()
		die.custom_minimum_size = Vector2(dsz, dsz)
		die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		die.idle = true
		vb.add_child(die)
		var sum := W.label(T.t("눈 %d + ?") % int(ev["symbol" + side]), _fs(30 if big else 24), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
		sum.pivot_offset = Vector2(_fs(115), _fs(16))
		vb.add_child(sum)
		var verdict := W.label(" ", _fs(24 if big else 18), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
		vb.add_child(verdict)
		var bubble := W.label(" ", _fs(14), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
		bubble.custom_minimum_size = Vector2(_fs(200 if big else 150), _fs(36))
		vb.add_child(bubble)
		sides.append({"vb": card, "die": die, "sum": sum, "verdict": verdict, "card": card, "bubble": bubble, "face": face, "chance": chance})
	hb.add_child(sides[0]["vb"])
	hb.add_child(W.label("VS", _fs(44 if big else 34), T.DANGER, "stamp", HORIZONTAL_ALIGNMENT_CENTER))
	hb.add_child(sides[1]["vb"])
	_bubble_a = sides[0]["bubble"]
	_bubble_b = sides[1]["bubble"]
	_card_a = sides[0]["card"]
	_card_b = sides[1]["card"]
	_die_a = sides[0]["die"]
	_die_b = sides[1]["die"]
	_sum_a = sides[0]["sum"]
	_sum_b = sides[1]["sum"]
	_verdict_a = sides[0]["verdict"]
	_verdict_b = sides[1]["verdict"]
	_face_a = sides[0].get("face", null)
	_face_b = sides[1].get("face", null)
	if _face_a != null:
		var ch_a: float = sides[0].get("chance", 0.5)
		_face_a.emotion = "CONFIDENT" if ch_a >= 0.55 else ("NERVOUS" if ch_a < 0.45 else "NEUTRAL")
	if _face_b != null:
		var ch_b: float = sides[1].get("chance", 0.5)
		_face_b.emotion = "CONFIDENT" if ch_b >= 0.55 else ("NERVOUS" if ch_b < 0.45 else "NEUTRAL")
	_duel_banner = W.label("", _fs(30 if big else 22), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_duel_box.add_child(_duel_banner)
	_duel_tag = W.label(" ", _fs(15), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
	_duel_box.add_child(_duel_tag)
	set_stage(2)
	Audio.tension(true)
	set_status("결투! 각자 주사위를 한 번 굴려 카드의 눈과 더합니다. 점수가 높은 쪽이 남은 돈을 가져가요.")
	reset_size()
	_queue_fit()


## small / short screens keep the compact stage (smaller dice and type)
func _compact_screen() -> bool:
	var par := get_parent() as Control
	var ph: float = par.size.y if par != null and par.size.y > 10.0 else get_viewport_rect().size.y
	var pw: float = par.size.x if par != null and par.size.x > 10.0 else get_viewport_rect().size.x
	return ph < 640.0 or pw < 520.0


## Tumbling dice for show; the engine already decided the numbers (RULE-034). The two dice land one after the other
## (A, then B) so the result builds up; any skip / reduced motion lands everything at once.
func set_rolls(ev: Dictionary) -> void:
	if _die_a == null or duel_phase != DuelPhase.INTRO:
		return                                  # a second DICE_ROLLED (or one without a duel) changes nothing
	duel_phase = DuelPhase.ROLLING
	if _face_a != null:
		_face_a.emotion = "NERVOUS"
	if _face_b != null:
		_face_b.emotion = "NERVOUS"
	var token := _duel_token
	var da: Control = _die_a
	var db: Control = _die_b
	var ra := int(ev["rollA"])
	var rb := int(ev["rollB"])
	var ta := Settings.dur(0.95)
	var tb := Settings.dur(1.2)
	if _skip() or ta <= 0.0:
		da.land(ra)
		db.land(rb)
	else:
		da.tumble(ra, ta, 1.0)         # started without await: both dice roll at the same time, B simply lands a little later
		db.tumble(rb, tb, -1.0)
		var t := 0.0
		while t < ta + 0.2 and not _skip() and is_instance_valid(da):
			await get_tree().process_frame
			t += get_process_delta_time()
		if is_instance_valid(da) and da.value == ra and not _skip():
			_land_text(_sum_a, int(_duel_ev["symbolA"]), ra)
			if _face_a != null:
				_face_a.emotion = "CONFIDENT" if ra >= 4 else "NERVOUS"
		while t < tb + 0.35 and not _skip() and is_instance_valid(db):
			await get_tree().process_frame
			t += get_process_delta_time()
		if _skip() and is_instance_valid(da):
			da.land(ra)
			db.land(rb)
	if _die_a == null or token != _duel_token:
		return
	_land_text(_sum_a, int(_duel_ev["symbolA"]), ra)
	_land_text(_sum_b, int(_duel_ev["symbolB"]), rb)
	duel_phase = DuelPhase.REVEAL


func _land_text(lbl: Label, sym: int, roll: int) -> void:
	lbl.text = T.t("눈 %d + %d") % [sym, roll]
	if Settings.reduce_motion or not lbl.is_inside_tree():
		return
	lbl.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func finish_duel(ev: Dictionary) -> void:
	if _die_a == null or duel_phase >= DuelPhase.SETTLEMENT:
		return                                  # settlement is shown exactly once
	var token := _duel_token
	if duel_phase < DuelPhase.REVEAL:           # skipped / replayed fast: land the dice first
		_die_a.land(int(ev["rollA"]))
		_die_b.land(int(ev["rollB"]))
	duel_phase = DuelPhase.SETTLEMENT
	_sum_a.text = T.t("눈 %d + %d = %d") % [int(_duel_ev["symbolA"]), int(ev["rollA"]), int(ev["scoreA"])]
	_sum_b.text = T.t("눈 %d + %d = %d") % [int(_duel_ev["symbolB"]), int(ev["rollB"]), int(ev["scoreB"])]
	_die_a.glow = ev["winnerId"] == ev["playerA"]
	_die_b.glow = ev["winnerId"] == ev["playerB"]
	_die_a.dim = not _die_a.glow
	_die_b.dim = not _die_b.glow
	var win_side := "A" if _die_a.glow else "B"
	var winner_card: PanelContainer = _card_a if win_side == "A" else _card_b
	var loser_card: PanelContainer = _card_b if win_side == "A" else _card_a
	for pair in [[_card_a, _die_a.glow], [_card_b, _die_b.glow]]:
		if pair[0] != null:
			pair[0].add_theme_stylebox_override("panel", W.sb(Color(T.GOLD, 0.14) if pair[1] else Color(0, 0, 0, 0.4), T.GOLD if pair[1] else Color(T.BRASS, 0.3), 4 if pair[1] else 1, 18, Vector4(10, 10, 10, 8)))
	# how surprising / how big: shown as words, from the real symbols and the real pot (the rules and the odds are untouched)
	var loser_id: String = ev["playerB"] if win_side == "A" else ev["playerA"]
	var win_face: Control = _face_a if win_side == "A" else _face_b
	var lose_face: Control = _face_b if win_side == "A" else _face_a
	if win_face != null:
		win_face.emotion = "TRIUMPHANT"
	if lose_face != null:
		lose_face.emotion = Characters.emotion_for("lose", str(personalities.get(loser_id, "")))
	var chance_w := Eng.duel_win_probability(int(_duel_ev["symbol" + win_side]), int(_duel_ev["symbol" + ("B" if win_side == "A" else "A")]), ev["winnerId"] == _duel_ev["challengerId"])
	var upset := chance_w < 0.3 and not bool(ev["tie"])
	var big_pot := _stake >= 40000
	# verdict: words + arrows, never colour alone; the winner's gain counts up
	for side in ["A", "B"]:
		var won: bool = ev["winnerId"] == ev["player" + side]
		var lbl: Label = _verdict_a if side == "A" else _verdict_b
		lbl.add_theme_color_override("font_color", T.OK if won else T.DANGER)
		lbl.text = T.t("▲ 승리" if won else "▼ 패배") + ("  $0" if (not won and _stake > 0) else "")
	var who := _nm(ev["winnerId"]) + (_me_tag(ev["winnerId"]))
	_duel_banner.text = "%s WINS THE DUEL" % who.to_upper()
	_duel_tag.text = T.t("역전승!  승률 %d%%였던 쪽이 이겼어요") % int(round(chance_w * 100.0)) if upset else (T.t("큰 판돈의 승부") if big_pot else " ")
	var d := Settings.dur(0.7)
	var win_lbl: Label = _verdict_a if win_side == "A" else _verdict_b
	var motion := not Settings.reduce_motion and not _skip() and d > 0.0 and is_inside_tree()
	if _stake > 0 and motion:
		var tw := create_tween()
		tw.tween_method(func(v: float):
			if token == _duel_token and is_instance_valid(win_lbl):
				win_lbl.text = T.t("▲ 승리  +%s") % T.money(int(round(v / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP)
			if token == _duel_token and _pot_label != null and is_instance_valid(_pot_label):
				_pot_label.text = T.money(int(round((float(_stake) - v) / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP)
		, 0.0, float(_stake), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func(): _enter_reaction(token))
	else:
		if _stake > 0:
			win_lbl.text = T.t("▲ 승리  +%s") % T.money(_stake)
			if _pot_label != null:
				_pot_label.text = T.money(0)
		_enter_reaction(token)
	# winner steps forward, loser steps back
	if motion:
		winner_card.pivot_offset = winner_card.size / 2.0
		winner_card.scale = Vector2(1.06, 1.06)
		create_tween().tween_property(winner_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		loser_card.pivot_offset = loser_card.size / 2.0
		create_tween().tween_property(loser_card, "scale", Vector2(0.95, 0.95), 0.3).set_trans(Tween.TRANS_QUAD)
		if upset or big_pot:
			_flash = 1.0
			create_tween().tween_property(self, "_flash", 0.0, 0.8)
		_duel_banner.pivot_offset = _duel_banner.size / 2.0
		_duel_banner.scale = Vector2(0.6, 0.6)
		_duel_banner.modulate.a = 0.0
		var bt := create_tween().set_parallel()
		bt.tween_property(_duel_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_property(_duel_banner, "modulate:a", 1.0, 0.2)
	loser_card.modulate = Color(0.8, 0.8, 0.8, 1.0)
	# in-character reactions: the winner and the loser each say one line (AI players only; the human has no scripted lines)
	var seed_n := int(ev.get("seq", 0))
	var win_sit := "win_upset" if upset else ("win_big" if big_pot else "win")
	var lose_sit := "lose_big" if big_pot else "lose"
	_bubble(ev["winnerId"], win_sit, seed_n, _bubble_a if win_side == "A" else _bubble_b)
	_bubble(loser_id, lose_sit, seed_n + 1, _bubble_b if win_side == "A" else _bubble_a)
	if ev["tie"]:
		Audio.play("tie")
		if ev["winnerId"] == _duel_ev["challengerId"]:
			set_status(T.t("동점 (%d vs %d) — 룰에 따라 결투를 선언한 도전자(%s) 승리!") % [int(ev["scoreA"]), int(ev["scoreB"]), _nm(ev["winnerId"])])
		else:
			set_status(T.t("동점 (%d vs %d) — 매수한 판사 판정으로 %s 승리!") % [int(ev["scoreA"]), int(ev["scoreB"]), _nm(ev["winnerId"])])
			_duel_tag.text = T.t("매수한 판사 판정! 동점 규칙 무효화")
	else:
		set_status(T.t("점수 비교 (%d vs %d) — 점수가 높은 %s 승리!") % [int(ev["scoreA"]), int(ev["scoreB"]), _nm(ev["winnerId"])])


func _enter_reaction(token: int) -> void:
	if token == _duel_token and duel_phase == DuelPhase.SETTLEMENT:
		duel_phase = DuelPhase.REACTION


func _bubble(pid: String, situation: String, seed_n: int, lbl: Label) -> void:
	if lbl == null or pid == human_id or not personalities.has(pid):
		return
	var text := Characters.line_for(_nm(pid), personalities[pid], situation, seed_n)
	if text == "":
		return
	lbl.text = "\"%s\"" % text
	lbl.add_theme_color_override("font_color", T.GOLD)
	Audio.bark(_nm(pid), situation)


## After a duel the player is in the room for, the result stays until they confirm (never auto-advances).
func ask_continue() -> void:
	if duel_phase == DuelPhase.WAITING or duel_phase == DuelPhase.DONE:
		return                                  # one confirmation prompt per duel
	duel_phase = DuelPhase.WAITING
	_clear(_action_box)
	var b := W.button(tr("결과 확인 (계속)"), "primary", _fs(20), Vector2(_fs(300), _fs(52)))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_box.add_child(b)
	b.pressed.connect(func():
		if b.disabled:
			return
		b.disabled = true
		decided.emit(true), CONNECT_ONE_SHOT)
	W.arm_focus(b, 0.6)
	await decided
	duel_phase = DuelPhase.DONE
	_clear(_action_box)


func close() -> void:
	duel_phase = DuelPhase.NONE
	_duel_token += 1
	Audio.focus(false)
	if visible and not neg.is_empty():
		Audio.play("panel_close")
	neg = {}
	proposal = {}
	marks = {}
	_duel_ev = {}
	_speech_box.visible = false
	_die_a = null
	_die_b = null
	if visible:
		_present(false)          # the content stays on screen while it slides out; _finish_close() clears it
	else:
		_finish_close()


func _finish_close() -> void:
	if not neg.is_empty():
		return                   # a new event opened while the old one was sliding out
	visible = false
	_stage_mode = false
	_apply_style(false)
	_header.visible = true
	_rows.visible = true
	_split.visible = true
	slide = 0.0
	modulate.a = 1.0
	_clear(_header)
	_clear(_rows)
	_clear(_duel_box)
	_clear(_action_box)
	_clear_split()
	_status.text = ""


## ---------------------------------------------------------------- human input

func ask_roll() -> void:
	_clear(_action_box)
	set_status(tr("내 차례예요. 버튼을 눌러 주사위를 굴리세요."))
	var b := W.button(tr("주사위 던지기"), "primary", _fs(20), Vector2(_fs(300), _fs(56)))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_box.add_child(b)
	b.pressed.connect(func(): decided.emit(true), CONNECT_ONE_SHOT)
	W.arm_focus(b, 0.5)
	if not Settings.reduce_motion:
		b.pivot_offset = Vector2(_fs(165), _fs(28))
		var pulse := b.create_tween().set_loops()
		pulse.tween_property(b, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	await decided
	_clear(_action_box)


func ask_response(view: Dictionary) -> String:
	var n: Dictionary = view["negotiation"]
	var me: String = view["you"]
	var offer: int = n["proposal"][me]
	var prop_id: String = n["proposerId"]
	var pot: int = int(n["proposal"][me]) + int(n["proposal"][prop_id])
	var chance := Eng.duel_win_probability(int(n["symbols"][me]), int(n["symbols"][prop_id]), true)
	var ev_duel := int(round(chance * float(pot) / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP
	var duel_better := ev_duel > offer
	_clear(_action_box)
	set_stage(1)
	set_status(T.t("%s 님이 내게 %s 를 제안했어요. 수락하거나, 결투로 승부를 볼 수 있습니다.") % [_nm(prop_id), T.money(offer)])
	# two big choice cards: each IS the button. A neutral note marks the one with the higher expected value (a fact from the odds, not advice).
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", _fs(16))
	_action_box.add_child(hb)
	var mk := func(kind: String, title: String, big: String, line1: String, line2: String, better: bool, col: Color) -> Button:
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(_fs(250), _fs(128))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.focus_mode = Control.FOCUS_ALL
		bt.text = ""
		var bg := Color("1d1710")
		var normal := W.sb(bg, Color(col, 0.95) if better else Color(T.BRASS, 0.55), 3 if better else 2, 12, Vector4(10, 8, 10, 8))
		bt.add_theme_stylebox_override("normal", normal)
		bt.add_theme_stylebox_override("hover", W.sb(bg.lightened(0.1), col, 3, 12, Vector4(10, 8, 10, 8)))
		bt.add_theme_stylebox_override("pressed", W.sb(bg.lightened(0.05), col, 3, 12, Vector4(10, 8, 10, 8)))
		bt.add_theme_stylebox_override("focus", W.sb(Color(0, 0, 0, 0), T.TEXT, 3, 12, Vector4(10, 8, 10, 8)))
		bt.set_meta("kind", kind)
		bt.set_meta("col", col)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		var l0 := W.label(title, _fs(17), col, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
		bt.set_meta("title_label", l0)
		var l1 := W.label(big, _fs(32), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
		var l2 := W.label(line1, _fs(14), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		var l3 := W.label(T.t(line2), _fs(13), col if better else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		for l in [l0, l1, l2, l3]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# a long line (a translation, "◀ better on average") wraps inside the card instead of running out of it
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.custom_minimum_size = Vector2(maxf(40.0, bt.custom_minimum_size.x - 24.0), 0)
			v.add_child(l)
		bt.add_child(v)
		# the card is as tall as its lines need (a wrapped line on a small screen or in English never runs out of it)
		(func():
			if is_instance_valid(bt) and is_instance_valid(v):
				bt.custom_minimum_size.y = maxf(bt.custom_minimum_size.y, v.get_combined_minimum_size().y + 16.0)).call_deferred()
		return bt
	var acc: Button
	var duel: Button
	if Settings.beginner_hints:
		acc = mk.call("ACCEPT", tr("수락"), T.money(offer), tr("지금 바로 받는 확실한 금액"), tr("위험 없음"), offer > ev_duel, T.OK)
		duel = mk.call("DUEL", tr("결투"), T.t("승률 %d%%") % int(round(chance * 100.0)), T.t("이기면 %s · 지면 $0") % T.money(pot), T.t("기대값 약 %s") % T.money(ev_duel), duel_better, T.DANGER)
	else:
		acc = mk.call("ACCEPT", tr("수락"), T.money(offer), tr("지금 바로 받는 확실한 금액"), tr("위험 없음"), false, T.OK)
		duel = mk.call("DUEL", tr("결투"), T.money(pot), T.t("이기면 %s · 지면 $0") % T.money(pot), tr("위험 부담"), false, T.DANGER)
	acc.text = "ACCEPT"
	duel.text = "DUEL"
	acc.add_theme_color_override("font_color", Color(0, 0, 0, 0))             # the card's own labels carry the text; these keep the button text searchable
	acc.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	acc.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	acc.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		duel.add_theme_color_override(c, Color(0, 0, 0, 0))
	hb.add_child(acc)
	hb.add_child(duel)
	# which card is better on average is said in words here (the cards only mark it with their frame): a long marker
	# inside the card ran out of it on a small screen
	var better_note := ""
	if Settings.beginner_hints:
		better_note = T.t("평균적으로는 결투가 더 유리") if duel_better else (T.t("평균적으로는 수락이 더 유리") if offer > ev_duel else "")
	var note := W.label(((better_note + "  ·  ") if better_note != "" else "") + T.t("결투는 도박입니다. 동점이면 결투를 건 사람이 이겨요."), _fs(13), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_action_box.add_child(note)
	# keyboard / gamepad: left-right moves between the two cards (wraps), accept / Enter chooses the focused one
	acc.focus_neighbor_right = duel.get_path()
	acc.focus_neighbor_left = duel.get_path()
	duel.focus_neighbor_left = acc.get_path()
	duel.focus_neighbor_right = acc.get_path()
	# DECIDING -> LOCKED: the first choice wins; the cards freeze, show what was chosen, and nothing else is accepted
	var locked := [false]
	var choose := func(kind: String) -> void:
		if locked[0]:
			return
		locked[0] = true
		var chosen: Button = acc if kind == "ACCEPT" else duel
		var other: Button = duel if kind == "ACCEPT" else acc
		var col: Color = chosen.get_meta("col")
		chosen.disabled = true
		other.disabled = true
		chosen.add_theme_stylebox_override("disabled", W.sb(Color(col, 0.22), col, 4, 12, Vector4(10, 8, 10, 8)))
		other.add_theme_stylebox_override("disabled", W.sb(Color("1d1710"), Color(T.BRASS, 0.25), 1, 12, Vector4(10, 8, 10, 8)))
		other.modulate = Color(1, 1, 1, 0.45)
		(chosen.get_meta("title_label") as Label).text = tr("수락 확정") if kind == "ACCEPT" else tr("결투 선언")
		Audio.play("confirm")
		set_status(T.t("%s — 잠시만요…") % T.t("수락했어요" if kind == "ACCEPT" else "결투를 선언했어요"))
		await _pause(0.35)                                       # the choice stays visible for a moment (no extra click needed)
		decided.emit(kind)
	acc.pressed.connect(func(): choose.call("ACCEPT"))
	duel.pressed.connect(func(): choose.call("DUEL"))
	W.arm_focus(acc, 0.5)               # the default focus is the safe card (accept); Enter only answers once the card has focus
	reset_size()
	var v = await decided
	_clear(_action_box)
	return str(v)


func ask_proposal(view: Dictionary) -> Dictionary:
	var n: Dictionary = view["negotiation"]
	var me: String = view["you"]
	var prize: int = n["prize"]
	var others := []
	for id in n["claimantIds"]:
		if id != me:
			others.append(id)
	var suggestion: Dictionary = AI.make_proposal(view, {"rngState": 4242})
	var alloc := {}
	for o in others:
		alloc[o] = int(suggestion[o])
	_clear(_action_box)
	set_stage(0)
	set_status("내가 먼저 제안합니다. 상대가 거절(결투)하지 않을 만큼 주되, 내 몫은 최대한 지키세요.")
	var my_label := W.label("", _fs(26), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
	var warn := W.label("", _fs(13), T.DANGER, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	var amount_labels := {}
	var hints := {}
	var sliders := {}
	var step_small := Eng.MONEY_STEP
	var step_big := Eng.MONEY_STEP * 4
	var syncing := [false]

	var refresh := func() -> void:
		var total := 0
		for o in others:
			total += int(alloc[o])
		var mine := prize - total
		my_label.text = T.t("내 몫  %s") % T.money(mine)
		var preview := {}
		preview[me] = mine
		for o in others:
			var a: int = int(alloc[o])
			amount_labels[o].text = T.money(a)
			preview[o] = a
			# what o can expect from calling a duel against me (they would win both shares)
			if Settings.beginner_hints:
				var p_o := Eng.duel_win_probability(int(n["symbols"][o]), int(n["symbols"][me]), true)
				var ev := p_o * float(a + mine)
				var likely := float(a) >= ev
				hints[o].text = T.t("결투하면 상대 기대값 약 %s (승률 %d%%) → %s") % [T.money(int(round(ev / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP), int(round(p_o * 100.0)), T.t("수락할 가능성 높음" if likely else "결투를 걸 수 있음")]
				hints[o].add_theme_color_override("font_color", T.OK if likely else T.DANGER)
			else:
				hints[o].text = ""
			syncing[0] = true
			sliders[o].value = a
			syncing[0] = false
		_draw_split(preview)

	var set_amt := func(o: String, v: int) -> void:
		var total := 0
		for x in others:
			total += int(alloc[x])
		var nv: int = maxi(0, v)
		if total - int(alloc[o]) + nv > prize:
			nv = prize - (total - int(alloc[o]))
		alloc[o] = nv
		refresh.call()

	for o in others:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", _fs(6))
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		var nm := W.label(T.t("%s 눈 %d") % [_nm(o), int(n["symbols"][o])], _fs(16), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
		nm.custom_minimum_size = Vector2(_fs(130), 0)
		hb.add_child(nm)
		var specs := [["−20k", -step_big], ["−5k", -step_small], [null, 0], ["+5k", step_small], ["+20k", step_big]]
		for sp in specs:
			if sp[0] == null:
				var al := W.label("", _fs(20), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
				al.custom_minimum_size = Vector2(_fs(110), 0)
				amount_labels[o] = al
				hb.add_child(al)
			else:
				var bt := W.button(sp[0], "secondary", _fs(14), Vector2(_fs(54), _fs(40)))
				var delta: int = sp[1]
				bt.pressed.connect(func():
					Audio.play("tick")
					set_amt.call(o, int(alloc[o]) + delta))
				hb.add_child(bt)
		box.add_child(hb)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = prize
		sl.step = Eng.MONEY_STEP
		sl.custom_minimum_size = Vector2(0, _fs(26))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.value_changed.connect(func(v: float):
			if not syncing[0]:
				Audio.play("tick")
				set_amt.call(o, int(v)))
		sliders[o] = sl
		box.add_child(sl)
		hints[o] = W.label("", _fs(12), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		box.add_child(hints[o])
		_action_box.add_child(box)
	_action_box.add_child(my_label)
	_action_box.add_child(warn)
	var presets := HBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.add_theme_constant_override("separation", _fs(8))
	_action_box.add_child(presets)
	var sugg_btn := W.button("추천", "secondary", _fs(15), Vector2(_fs(90), _fs(44)))
	var even_btn := W.button("균등 분배", "secondary", _fs(15), Vector2(_fs(110), _fs(44)))
	var greedy_btn := W.button("내가 많이", "secondary", _fs(15), Vector2(_fs(110), _fs(44)))
	if Settings.beginner_hints:
		presets.add_child(sugg_btn)
	presets.add_child(even_btn)
	presets.add_child(greedy_btn)
	var ok_btn := W.button(tr("제안 전달"), "primary", _fs(20), Vector2(_fs(300), _fs(52)))
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_box.add_child(ok_btn)
	var apply := func(vals: Dictionary) -> void:
		for o in others:
			alloc[o] = int(vals[o])
		refresh.call()
	sugg_btn.pressed.connect(func(): apply.call(suggestion))
	even_btn.pressed.connect(func():
		var share := int(floor(float(prize) / float(others.size() + 1) / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP
		var d := {}
		for o in others:
			d[o] = share
		apply.call(d))
	greedy_btn.pressed.connect(func():
		var share := int(floor(float(prize) * 0.2 / float(others.size()) / float(Eng.MONEY_STEP))) * Eng.MONEY_STEP
		var d := {}
		for o in others:
			d[o] = share
		apply.call(d))
	ok_btn.pressed.connect(func():
		if ok_btn.disabled:
			return
		ok_btn.disabled = true
		Audio.play("confirm")
		var out := {}
		var total := 0
		for o in others:
			out[o] = int(alloc[o])
			total += int(alloc[o])
		out[me] = prize - total
		decided.emit(out), CONNECT_ONE_SHOT)
	refresh.call()
	W.arm_focus(ok_btn, 0.5)
	reset_size()
	var res = await decided
	_clear(_action_box)
	_clear_split()
	return res


## Segmented bar: who gets how much of the prize.
class SplitBar extends Control:
	const T = preload("res://ui/tokens.gd")
	var segments: Array = []
	var u := 1.0

	func _draw() -> void:
		var total := 0
		for s in segments:
			total += int(s["amount"])
		if total <= 0:
			return
		var x := 0.0
		var f := T.font("ui", 700)
		for i in range(segments.size()):
			var s: Dictionary = segments[i]
			var w := size.x * float(s["amount"]) / float(total)
			if w <= 0.5:
				continue
			var r := Rect2(x, 0, w - 2.0, size.y)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(s["color"]).darkened(0.25)
			sb.border_color = s["color"]
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			sb.draw(get_canvas_item(), r)
			var txt := "%s %s" % [s["label"], T.money(int(s["amount"]))]
			var fs := int(minf(T.fs(13.0 * u, 1.5), size.y * 0.62))
			if f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 8:
				txt = T.money(int(s["amount"]))
			if f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= r.size.x - 6:
				T.note_text(self, fs, txt)
				draw_string(f, Vector2(r.position.x, size.y * 0.66), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("fff4d8"))
			x += w


## The button a controller should land on in this panel (the answer cards, the roll / result button, the offer button):
## the first visible, enabled, focusable button of the action area. Null while the cards are still arming (W.arm_focus).
func default_focus_target() -> Button:
	if _action_box == null or not is_instance_valid(_action_box) or not is_visible_in_tree():
		return null
	for n in _action_box.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			return b
	return null
