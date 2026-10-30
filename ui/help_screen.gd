extends Control
## HOW TO PLAY (Phase 10): a paged, illustrated rules guide. Used by the title screen and by the in-game menu.
## Rules text follows docs/02_RULEBOOK (RULE-001..028). Pure presentation; opens as an overlay and emits `closed`.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")
const CardView = preload("res://ui/card_view.gd")
const Eng = preload("res://engine/engine.gd")
const Characters = preload("res://ui/characters.gd")
const Portrait = preload("res://ui/portrait.gd")

signal closed

var _page := 0
var _panel: PanelContainer
var _title: Label
var _counter: Label
var _fit_box: Control              # W.FitBox: the page body is never scrolled (Phase 29)
var _parts: Array = []             # a page taller than the sheet is split into parts: [[child, ...], ...]
var _part := 0
var _body: VBoxContainer
var _dots: Control
var _built := false
var _prev: Button
var _next: Button
var _titles := ["목표", "한 라운드의 흐름", "카드 고르고 내기", "주사위 눈과 결과 읽기", "혼자면 전부 · RAZZIA", "협상", "결투", "술집에 쌓이는 돈", "예시 한 판", "헷갈리기 쉬운 점", "AI 상대 소개", "유물 모드 (암시장)"]

const CATEGORIES := [
	{"name": "기초 & 목표", "pages": [0, 1]},
	{"name": "카드 & 주사위", "pages": [2, 3]},
	{"name": "정산 & 협상", "pages": [4, 5]},
	{"name": "결투 & 판돈", "pages": [6, 7]},
	{"name": "실전 & 유물", "pages": [8, 9, 10, 11]},
]
var _cat_btns: Array = []


func _ready() -> void:
	Audio.play("panel_open")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", W.deco(Color("15110cf8"), T.GOLD, Vector4(30, 22, 30, 22), 1.0))
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_title = W.label("", 28, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_counter = W.label("", 16, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_RIGHT, 700)
	head.add_child(_counter)
	var x := W.button("✕", "secondary", 22, Vector2(48, 44))
	x.pressed.connect(close)
	head.add_child(x)
	v.add_child(head)
	
	# Category quick navigation bar
	v.add_child(_build_cat_bar())
	v.add_child(W.rule(1.0, 1))
	# Phase 29: no scroll area. A page that is taller than the sheet is split into parts (the arrows walk through them),
	# and whatever is left over is scaled as one piece by the FitBox.
	_fit_box = W.FitBox.new()
	_fit_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_box.align_top = false
	_fit_box.min_scale = 0.75
	v.add_child(_fit_box)
	_body = VBoxContainer.new()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER     # a short page sits in the middle of the sheet, not pinned to the top
	_body.add_theme_constant_override("separation", 16)
	_fit_box.add_child(_body)
	# footer
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_prev = W.button("◀  이전", "secondary", 18, Vector2(140, 48))
	_ko(_prev)
	_prev.pressed.connect(_back)
	foot.add_child(_prev)
	_dots = Dots.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.custom_minimum_size = Vector2(0, 30)
	foot.add_child(_dots)
	_next = W.button("다음  ▶", "primary", 18, Vector2(140, 48))
	_ko(_next)
	_next.pressed.connect(func():
		if _part < _parts.size() - 1:
			_show_part(_part + 1)
		elif _page >= _titles.size() - 1:
			close()
		else:
			_go(_page + 1))
	foot.add_child(_next)
	v.add_child(foot)
	resized.connect(_fit)
	_fit()
	_go(0)
	_next.grab_focus()


## Korean labels: the title face (Cinzel) has no Hangul, so use the UI face for those buttons
func _ko(b: Button) -> void:
	b.add_theme_font_override("font", T.font("ui", 800))


func _fit() -> void:
	var w := minf(980.0, size.x - 40.0)
	var h := minf(680.0, size.y - 40.0)
	_panel.custom_minimum_size = Vector2(maxf(280.0, w), maxf(300.0, h))


## 모달 포커스: 열릴 때의 포커스를 기억했다가 닫힐 때 되돌립니다(컨트롤러로 연 곳으로 돌아가도록).
var _prev_focus: Control = null


func _enter_tree() -> void:
	var vp := get_viewport()
	if vp != null:
		_prev_focus = vp.gui_get_focus_owner()


func close() -> void:
	closed.emit()
	var back := _prev_focus
	if back != null and is_instance_valid(back) and back.is_visible_in_tree() and back.focus_mode != Control.FOCUS_NONE:
		back.grab_focus.call_deferred()
	queue_free()


func _input(event: InputEvent) -> void:
	# the overlay owns the keyboard while it is open (the game screen would otherwise move its card focus)
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close()
	elif event.is_action_pressed("ui_left"):
		_back()
	elif event.is_action_pressed("ui_right"):
		if _part < _parts.size() - 1:
			_show_part(_part + 1)
		else:
			_go(_page + 1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			for i in range(CATEGORIES.size()):
				if CATEGORIES[i]["pages"].has(_page) and i > 0:
					_go(CATEGORIES[i - 1]["pages"][0])
					break
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			for i in range(CATEGORIES.size()):
				if CATEGORIES[i]["pages"].has(_page) and i < CATEGORIES.size() - 1:
					_go(CATEGORIES[i + 1]["pages"][0])
					break
		else:
			return
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_SPACE]:
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _back() -> void:
	if _part > 0:
		_show_part(_part - 1)
	elif _page > 0:
		_go(_page - 1, true)


func _go(i: int, last_part: bool = false) -> void:
	var np := clampi(i, 0, _titles.size() - 1)
	if np != _page and _built:
		Audio.play("page")
	_page = np
	for c in _body.get_children():
		c.queue_free()
	_title.text = _titles[_page]
	_counter.text = "%d / %d" % [_page + 1, _titles.size()]
	_prev.disabled = _page == 0
	_next.text = "시작하기  ✓" if _page == _titles.size() - 1 else "다음  ▶"
	(_dots as Dots).set_state(_titles.size(), _page)
	call("_page_%d" % _page)
	_parts = [_body.get_children()]
	_part = 0
	_update_nav()
	_built = true
	_split_parts.call_deferred(last_part)


## After the page is laid out at the sheet's width: if it is taller than the sheet, cut it into parts that each fit.
func _split_parts(last_part: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var room: float = _fit_box.size.y
	var sep := float(_body.get_theme_constant("separation"))
	var kids: Array = _body.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var total := 0.0
	for c in kids:
		total += (c as Control).size.y + sep
	total -= sep
	# a page that fits when drawn a little smaller (>= 85 %) stays one page; the FitBox scales it
	if total * 0.85 <= room + 1.0 or kids.size() < 2:
		return
	# otherwise cut it into parts of about one sheet each; a heading line always stays with the block after it
	var budget := room / 0.92
	var parts: Array = [[]]
	var acc := 0.0
	var i := 0
	while i < kids.size():
		var group: Array = [kids[i]]
		var gh: float = (kids[i] as Control).size.y
		if kids[i] is Label and i + 1 < kids.size():
			group.append(kids[i + 1])
			gh += sep + (kids[i + 1] as Control).size.y
			i += 1
		if not parts[-1].is_empty() and acc + gh > budget:
			parts.append([])
			acc = 0.0
		parts[-1].append_array(group)
		acc += gh + sep
		i += 1
	_parts = parts
	_show_part(parts.size() - 1 if last_part else 0)


func _show_part(i: int) -> void:
	_part = clampi(i, 0, _parts.size() - 1)
	for pi in range(_parts.size()):
		for c in _parts[pi]:
			if is_instance_valid(c):
				c.visible = pi == _part
	_update_nav()


func _build_cat_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_cat_btns.clear()
	for i in range(CATEGORIES.size()):
		var cat: Dictionary = CATEGORIES[i]
		var b := Button.new()
		b.text = T.t(cat["name"])
		b.custom_minimum_size = Vector2(130, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", T.font("ui", 700))
		b.add_theme_font_size_override("font_size", 13)
		var target_page: int = cat["pages"][0]
		b.pressed.connect(func():
			Audio.play("page")
			_go(target_page)
		)
		row.add_child(b)
		_cat_btns.append(b)
	return row


func _update_nav() -> void:
	var more := _part < _parts.size() - 1
	_prev.disabled = _page == 0 and _part == 0
	_next.text = "다음  ▶" if (more or _page < _titles.size() - 1) else "시작하기  ✓"
	_counter.text = ("%d / %d" % [_page + 1, _titles.size()]) + (("  (%d/%d)" % [_part + 1, _parts.size()]) if _parts.size() > 1 else "")
	for i in range(CATEGORIES.size()):
		if i < _cat_btns.size():
			var b: Button = _cat_btns[i]
			var is_active: bool = CATEGORIES[i]["pages"].has(_page)
			if is_active:
				b.add_theme_color_override("font_color", T.GOLD)
				b.add_theme_stylebox_override("normal", W.sb(Color("2a1f13"), T.GOLD, 2, 8, Vector4(10, 4, 10, 4)))
				b.add_theme_stylebox_override("hover", W.sb(Color("352718"), T.GOLD, 2, 8, Vector4(10, 4, 10, 4)))
			else:
				b.add_theme_color_override("font_color", T.TEXT_DIM)
				b.add_theme_stylebox_override("normal", W.sb(Color("16120e"), Color(T.BRASS, 0.4), 1, 8, Vector4(10, 4, 10, 4)))
				b.add_theme_stylebox_override("hover", W.sb(Color("221a12"), Color(T.BRASS, 0.7), 1, 8, Vector4(10, 4, 10, 4)))


## ------------------------------------------------------------------ helpers

func _lead(text: String) -> void:
	var l := W.label(text, 21, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(l)


func _bullets(items: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var dot := W.label("◆", 12, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		dot.custom_minimum_size = Vector2(18, 0)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		hb.add_child(dot)
		var l := W.label(it, 18, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		box.add_child(hb)
	_body.add_child(box)


func _illus(children: Array, sep: int = 14) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", W.sb(Color("0d1a12"), Color(T.BRASS, 0.5), 1, 12, Vector4(14, 14, 14, 14)))
	var hb := HFlowContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("h_separation", sep)
	hb.add_theme_constant_override("v_separation", 10)
	hb.alignment = FlowContainer.ALIGNMENT_CENTER
	for ch in children:
		hb.add_child(ch)
	p.add_child(hb)
	_body.add_child(p)


func _card(type: String, bar: String, sym: int, w: float = 96.0) -> CardView:
	var cv := CardView.new()
	cv.card = {"id": "help-%s-%s-%d" % [type, bar, sym], "type": type, "barId": bar, "dieSymbol": sym}
	cv.face_up = true
	cv.custom_minimum_size = Vector2(w, w * 1.385)
	cv.size = cv.custom_minimum_size
	return cv


func _tile(title: String, body: String, accent: Color = T.GOLD, w: float = 220.0) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0)
	p.add_theme_stylebox_override("panel", W.sb(Color("1a140c"), accent, 2, 10, Vector4(14, 12, 14, 14)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(W.label(title, 20, accent, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var b := W.label(body, 16, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.custom_minimum_size = Vector2(w - 28.0, 0)
	v.add_child(b)
	return p


func _arrow(text: String = "→") -> Label:
	var l := W.label(text, 34, T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	l.custom_minimum_size = Vector2(36, 0)
	return l


func _chip(text: String, color: Color, size: int = 18) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", W.sb(Color(color, 0.18), color, 2, 20, Vector4(16, 6, 16, 6)))
	p.add_child(W.label(text, size, color, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800))
	return p


## a venue poster with the cards lying on it
func _bar_scene(bar: String, money: String, cards: Array, out: Array = []) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var poster := PosterView.new()
	poster.bar = bar
	poster.custom_minimum_size = Vector2(150, 96)
	v.add_child(poster)
	var m := W.label(money, 24, T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
	v.add_child(m)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in range(cards.size()):
		var c: Array = cards[i]
		var cv := _card(c[0], bar, c[1], 64.0)
		if i in out:
			cv.dimmed = true
			cv.out_mark = true
		row.add_child(cv)
	v.add_child(row)
	return v


## ------------------------------------------------------------------ pages

func _page_0() -> void:
	_lead("가장 돈이 많은 사람이 이깁니다.")
	var chips: Array = []
	for amt in ["$5,000", "$20,000", "$50,000"]:
		chips.append(_chip(amt, T.GOLD, 22))
	chips.append(_arrow())
	chips.append(_chip("마지막에 가장 부자 = 승리", T.OK, 20))
	_illus(chips)
	_bullets([
		"3~8명이 6개의 술집(COLIBRI · COTTON CLUB · HAVANA BAR · THE JUNGLE · LINCOLN'S · JAZZ HOUSE)에 쌓인 돈을 두고 겨룹니다.",
		"매 라운드 손패 5장 중 카드 1장을 비밀리에 내고, 같은 술집에 낸 사람들끼리 그 술집의 돈을 차지해요.",
		"머니 덱이 거의 바닥나면 마지막 라운드가 시작됩니다(화면에 FINAL ROUND 표시). 마지막 라운드까지 끝난 뒤 가진 돈이 가장 많은 사람이 승리!",
	])


func _page_1() -> void:
	_lead("한 라운드는 세 단계로 흘러갑니다.")
	var t: Array = [
		_tile("① 돈 배치", "딜러가 머니카드를 술집 위에 올려요. 안 가져간 돈은 다음 라운드에도 그 술집에 남아 쌓입니다.", T.GOLD),
		_arrow(),
		_tile("② 비밀 선택", "손패 5장 중 1장을 몰래 골라 내요. 다른 사람이 무엇을 냈는지는 공개 전까지 알 수 없어요.", Color("4f8fd0")),
		_arrow(),
		_tile("③ 공개 · 정산", "모두 동시에 카드를 공개하고, 술집마다 따로 결판을 내요. 끝나면 카드를 1장 받아 손패를 다시 5장으로 채웁니다.", T.OK),
	]
	_illus(t, 8)
	_bullets([
		"딜러(DEALER 표시)는 라운드마다 다음 사람으로 넘어갑니다.",
		"내 차례가 되면 손패에서 카드를 눌러 고른 뒤 PLAY CARD를 누르면 확정돼요.",
	])


func _die(v: int, sz: float = 54.0) -> Control:
	var d := W.DieView.new()
	d.custom_minimum_size = Vector2(sz, sz)
	d.value = v
	return d


func _ctr(c: Control) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(c)
	return h


func _eq(parts: Array) -> Control:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in parts:
		f.add_child(p if p is Control else W.label(str(p), 30, T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800))
	return f


func _cap(text: String, color: Color = T.TEXT_DIM) -> Label:
	return W.label(text, 16, color, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)


## 카드 아래 설명이 붙은 카드 한 장
func _card_cap(type: String, bar: String, sym: int, caption: String, color: Color = T.GOLD) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_ctr(_card(type, bar, sym, 112.0)))
	v.add_child(W.label(caption, 16, color, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800))
	return v


func _page_2() -> void:
	_lead("손패 5장 중 1장을 몰래 골라 내세요. 확정하기 전에는 얼마든지 바꿀 수 있어요.")
	var hand: Array = []
	var defs := [["ZOCKER", "COLIBRI", 4], ["ZOCKER", "THE_JUNGLE", 2], ["RAZZIA", "HAVANA_BAR", 3], ["ZOCKER", "LINCOLNS", 5], ["ZOCKER", "JAZZ_HOUSE", 1]]
	for d in defs:
		hand.append(_card(d[0], d[1], d[2], 84.0))
	_illus(hand, 8)
	_illus([_tile("① 고르기", "카드를 클릭·터치하거나 ← → 로 옮겨 Enter. 고른 카드는 위로 올라와요.", T.GOLD, 210.0), _arrow(),
		_tile("② 확정하기", "PLAY CARD 버튼(또는 고른 카드를 다시 Enter)을 누르면 확정돼요. 확정 뒤에는 바꿀 수 없어요.", T.OK, 210.0), _arrow(),
		_tile("③ 공개 대기", "모두 낼 때까지 기다렸다가 한꺼번에 공개돼요. 그 전에는 남의 카드를 알 수 없어요.", Color("4f8fd0"), 210.0)], 8)
	_bullets([
		"카드의 술집(색·이름)이 내가 노리는 술집이에요. 같은 술집에 카드를 낸 사람끼리 그 술집의 돈을 두고 겨룹니다.",
		"카드는 종류(ZOCKER 도박꾼 / RAZZIA 경찰)와 주사위 눈(1~6)이 있어요.",
	])


func _page_3() -> void:
	_lead("카드의 점(주사위 눈)은 두 군데에 쓰여요. 이 게임에 별(★)은 없어요.")
	_illus([_card_cap("ZOCKER", "HAVANA_BAR", 5, "눈 5"), _card_cap("ZOCKER", "HAVANA_BAR", 2, "눈 2")], 36)
	var win := Eng.duel_win_probability(5, 2, true)
	var f := _eq([W.label("눈", 17, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700), "5", "+", _die(4, 46), "=", "9"])
	_illus([_tile("용도 ①  제안 순서", "협상에서 눈이 가장 높은 사람이 먼저 돈을 나눠 제안해요. 눈이 같으면 딜러에게서 더 먼 자리의 사람이 먼저예요.", T.GOLD, 300.0),
		_tile("용도 ②  결투 점수", "결투에서 점수 = 카드의 눈 + 굴린 주사위(1~6). 점수가 높은 쪽이 이겨요.", T.DANGER, 300.0)], 12)
	_illus([W.label("결투 점수 계산 예 (카드 눈 5, 주사위 4)", 17, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700), f], 16)
	_bullets([
		T.t("예: 눈 5 대 눈 2 결투에서 눈 5 쪽이 결투를 선언했다면 이길 확률은 약 %d%%예요(엔진이 36가지 주사위 조합을 모두 센 값). 눈 차이가 클수록 유리하지만, 주사위 운이 남아 있어요.") % roundi(win * 100.0),
		"동점이면 결투를 선언한 사람이 이겨요.",
		"결과는 색만으로 알려주지 않아요. 승/패 글자와 ▲▼ 표시, 점수 숫자가 함께 나와요.",
	])


func _page_4() -> void:
	_lead("술집마다 따로 결판을 냅니다. 먼저 혼자인지, 경찰이 있는지를 봅니다.")
	var s1 := _bar_scene("HAVANA_BAR", "$35,000", [["ZOCKER", 4]])
	var r1 := VBoxContainer.new()
	r1.add_child(_chip("도박꾼 혼자 → 돈 전부", T.OK, 17))
	var s2 := _bar_scene("COTTON_CLUB", "$30,000", [["ZOCKER", 4], ["ZOCKER", 2], ["RAZZIA", 3]], [0, 1])
	var r2 := VBoxContainer.new()
	r2.add_child(_chip("도박꾼 ✕ 쫓겨남", T.DANGER, 17))
	r2.add_child(_chip("RAZZIA가 돈 차지", T.OK, 17))
	var s3 := _bar_scene("LINCOLNS", "$20,000", [["RAZZIA", 5]])
	var r3 := VBoxContainer.new()
	r3.add_child(_chip("도박꾼 없음 → 돈 그대로", T.TEXT_DIM, 17))
	_illus([s1, r1, _spacer(20), s2, r2, _spacer(20), s3, r3], 10)
	_bullets([
		"도박꾼이 한 명뿐이면 그 술집의 돈이 전부 그 사람 몫이에요.",
		"RAZZIA와 도박꾼이 함께 있으면 도박꾼은 한 푼도 못 받고, RAZZIA를 낸 사람들이 돈을 두고 겨룹니다(RAZZIA가 여럿이면 눈이 가장 높은 사람이 먼저 제안).",
		"RAZZIA만 있고 도박꾼이 없으면 아무도 돈을 못 받고 돈은 술집에 남아요.",
		"아무도 카드를 내지 않은 술집의 돈도 그대로 남아 다음 라운드에 쌓여요.",
	])


func _page_5() -> void:
	_lead("같은 술집을 두고 겨루는 사람이 둘 이상이면 협상이 열립니다.")
	_illus([
		_tile("① 제안", "눈이 가장 높은 사람이 술집의 돈을 나눠 제안해요. 자기 몫도 정할 수 있어요.", T.GOLD, 200.0),
		_arrow(),
		_tile("② 응답", "나머지는 각자 수락(ACCEPT) 하거나 결투(DUEL)를 선언해요.", Color("4f8fd0"), 200.0),
		_arrow(),
		_tile("③ 정산", "모두 수락하면 제안대로 받아요. 거절이 있으면 결투로 남은 돈을 가려요.", T.OK, 200.0),
	], 8)
	_bullets([
		"수락한 사람은 제안받은 금액을 받고 빠져요. 나머지 돈은 결투 승자가 가져갑니다.",
		"협상 화면은 단계(제안 → 응답 → 결투 → 정산)를 위에 보여주고, 지금 내가 할 일을 한 줄로 알려줘요.",
		"제안할 때는 상대가 결투를 걸었을 때의 기대값(화면에 표시)보다 후하게 주면 수락될 가능성이 높아요.",
	])


func _page_6() -> void:
	_lead("결투는 각자 주사위를 한 번 굴려 점수를 비교합니다.")
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 6)
	a.add_child(_ctr(_card("ZOCKER", "THE_JUNGLE", 5, 96.0)))
	a.add_child(_eq(["5", "+", _die(3, 44), "=", "8"]))
	a.add_child(_chip("동점 · 패", T.DANGER, 16))
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 6)
	b.add_child(_ctr(_card("ZOCKER", "THE_JUNGLE", 2, 96.0)))
	b.add_child(_eq(["2", "+", _die(6, 44), "=", "8"]))
	b.add_child(_chip("결투 선언 · 동점이라 승", T.OK, 16))
	var a2 := a
	_illus([a2, W.label("VS", 30, T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800), b], 26)
	_bullets([
		"점수 = 카드의 눈 + 굴린 주사위. 높은 쪽이 이기고, 위 예처럼 동점이면 결투를 선언한 사람이 이겨요(위 그림은 눈 2 쪽이 선언한 경우).",
		"승자는 그 술집에 남은 돈을 전부 가져가요.",
		"3명 이상이 거절하면 결투가 이어져요. 셋이 모두 거절하면 눈이 가장 높은 사람과 가장 낮은 사람이 먼저 겨루고, 이긴 쪽이 남은 한 명과 겨뤄요. 넷 이상이면 눈이 낮은 순서대로 도전자가 현재 승자와 차례로 겨룹니다.",
		"결투 화면은 (1) 누가 왜 겨루는지 (2) 주사위 굴리기 (3) 결과 공개 (4) 점수 계산 (5) 승패 (6) 돈이 어떻게 움직였는지 순서로 보여줘요. 결과를 보기 전에는 넘어가지 않아요.",
	])


func _page_7() -> void:
	_lead("안 가져간 돈은 술집에 남고, 딜러가 7번째 머니카드를 얹을 술집을 고를 수 있어요.")
	var before := _bar_scene("JAZZ_HOUSE", "$20,000", [])
	var plus := _chip("+ $10,000 (딜러가 올림)", T.GOLD, 18)
	var after := _bar_scene("JAZZ_HOUSE", "$30,000", [])
	_illus([before, _arrow(), plus, _arrow(), after], 10)
	_bullets([
		"라운드 시작에 딜러가 머니카드를 뽑아 왼쪽 술집부터 한 장씩 올려요(4~8명 기준 6장).",
		"남는 한 장(총 7장)은 딜러가 고른 술집에 올려요. 화면에는 \"전 → +금액 → 후\"로 표시됩니다.",
		"누가 얼마를 얹었는지 기록되는 것은 딜러의 이 한 장뿐이에요. 플레이어들이 따로 돈을 보태는 규칙은 없어서 그런 표시는 하지 않아요.",
		"3명일 때는 쓰는 술집과 장수가 달라요(활성 술집만 사용).",
	])


func _page_8() -> void:
	_lead("한 라운드를 처음부터 끝까지 따라가 봅시다.")
	_illus([_bar_scene("THE_JUNGLE", "$30,000", [["ZOCKER", 5], ["ZOCKER", 2]]), _arrow("①"), _chip("눈 5가 제안", T.GOLD, 17)], 10)
	_bullets([
		"1. 정글에 $30,000이 쌓였고, 나(눈 5)와 상대(눈 2)가 모두 ZOCKER를 냈어요.",
		"2. 눈이 더 높은 내가 제안자예요. 나 $20,000 / 상대 $10,000으로 제안했어요.",
		"3a. 상대가 ACCEPT → 나 +$20,000, 상대 +$10,000. 정글은 $0.",
		"3b. 상대가 DUEL → 눈 5 + 주사위 대 눈 2 + 주사위. 높은 쪽이 $30,000 전부를 가져가요(동점이면 결투를 선언한 상대 승).",
		"4. 라운드가 끝나면 카드를 1장 받고 딜러가 다음 사람으로 넘어가요.",
		"5. 머니 덱이 바닥나는 마지막 라운드(FINAL ROUND)까지 끝났을 때 가장 부자가 승리!",
	])


func _page_9() -> void:
	_lead("처음 하면 많이 헷갈리는 점들")
	var rows := [
		["별(★)이 있나요?", "없어요. 카드의 점(주사위 눈)과 굴린 주사위 숫자만 써요.", T.GOLD],
		["내 눈이 높으면 항상 이기나요?", "아니에요. 결투 점수에는 주사위(1~6)가 더해져 눈 차이가 작으면 뒤집혀요.", T.DANGER],
		["동점이면?", "결투를 선언한 사람이 이겨요.", T.OK],
		["RAZZIA만 내면?", "도박꾼이 없으면 돈을 못 받아요. 돈은 술집에 남아요.", T.POLICE_BLUE.lightened(0.3)],
		["건너뛰기(SKIP)는?", "연출만 빠르게 넘겨요. 결과는 바뀌지 않고, 이긴 사람·금액은 항상 화면에 남아요.", T.TEXT_DIM],
	]
	var sum := VBoxContainer.new()
	sum.add_theme_constant_override("separation", 10)
	for r in rows:
		var hb := VBoxContainer.new()
		hb.add_child(W.label(r[0], 18, r[2], "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
		var l := W.label(r[1], 17, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		hb.add_child(l)
		sum.add_child(hb)
	_illus([sum])
	_bullets(["조작: 카드는 클릭/터치 또는 ←→ + Enter, 취소는 Esc, 소리 끄기는 M."])


func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _page_10() -> void:
	_lead("AI는 자리마다 성격이 달라요. 협상 화면에 이름 옆에 표시됩니다.")
	# duel-call share measured by tools/ai_sim.gd (6 players, all NORMAL, 1500 games): how often the AI answers an offer with DUEL
	var stat := {"CONSERVATIVE": 51, "OPPORTUNIST": 69, "AGGRESSIVE": 86}
	var tiles: Array = []
	var cols := {"CONSERVATIVE": Color("4f8fd0"), "OPPORTUNIST": T.GOLD, "AGGRESSIVE": T.DANGER}
	for k in ["CONSERVATIVE", "OPPORTUNIST", "AGGRESSIVE"]:
		var inf: Dictionary = Characters.info(k)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var face := Portrait.new()
		face.personality = k
		face.custom_minimum_size = Vector2(72, 72)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(face)
		col.add_child(_tile("%s" % inf["label"], T.t("%s\n제안에 결투로 답하는 비율: 약 %d%%") % [inf["blurb"], stat[k]], cols[k], 280.0))
		tiles.append(col)
	_illus(tiles, 12)
	_bullets([
		"비율은 AI끼리 1500판을 시뮬레이션해 센 값이에요(보통 난이도, 6인). 사람과의 판에서는 달라질 수 있어요.",
		"난이도는 쉬움 / 보통 / 어려움이에요. 어려움은 실수 없이 확률을 계산하고 과감하게 승부해요.",
		"성격은 자리(순서)로 정해져 있어 같은 자리의 AI는 늘 같은 성격이에요.",
	])


func _page_11() -> void:
	_lead("유물 모드는 특별한 암시장 유물을 모아 나만의 전략을 구축하는 로그라이크 모드입니다.")
	var t: Array = [
		_tile("① 시작 유물 선택", "게임 시작 시 결투형·경제형·정보형 3개 중 1개 유물을 무료로 선택합니다.", T.GOLD, 210.0),
		_arrow(),
		_tile("② 라운드 사이 암시장", "라운드 종료 후 암시장을 방문해 새 유물을 구매하거나 $5,000으로 새로고침합니다.", Color("4f8fd0"), 210.0),
		_arrow(),
		_tile("③ 시너지와 전략 완성", "보유 유물 효과가 매 라운드 패시브/결투에 발동되어 최종 승부를 뒤집습니다.", T.OK, 210.0),
	]
	_illus(t, 8)
	_bullets([
		"시작 유물 3종: 행운의 동전(결투 점수 +1), 구역 갈취(독점 보너스 +$5,000), 밀고자(AI 목적지 1명 사전 투시).",
		"고급 유물 5종: 스위스 비밀계좌(이자 10%), 매수한 판사(결투 방어 시 동점승), 눈속임 주사위(1~2눈 → 3), 부패 경찰(단속 실패 시 15% 뇌물), 신디케이트 문장(보유 유물당 +$3,000 배당).",
		"자금 보존 원칙: 암시장에서 소비된 금액은 금고로 안전하게 이동하며, 전체 자금 보존 법칙(INV-002)을 엄격히 준수합니다.",
		"클래식 모드 보호: 클래식 모드에서는 유물이 일절 등장하지 않으며 1992년 정통 보드게임 규칙 그대로 진행됩니다.",
		"크레딧 및 라이선스: 게임 원작 Stefan Dorra (1992) · 벡터 아이콘 game-icons.net (CC BY 3.0: Delapouite, Lorc, Andy Meneely, Skoll). 상세 내용은 CREDITS.md 파일 참조.",
	])


## ------------------------------------------------------------------ small drawn controls

class Dots extends Control:
	const T = preload("res://ui/tokens.gd")
	var n := 1
	var cur := 0

	func set_state(p_n: int, p_cur: int) -> void:
		n = p_n
		cur = p_cur
		queue_redraw()

	func _draw() -> void:
		var step := 26.0
		var x0 := (size.x - step * float(n - 1)) / 2.0
		for i in range(n):
			var c := Vector2(x0 + step * i, size.y / 2.0)
			if i == cur:
				draw_circle(c, 7.0, T.GOLD)
			else:
				draw_circle(c, 5.0, Color(T.BRASS, 0.45))


## venue poster (cover-cropped) with a coloured frame
class PosterView extends Control:
	const T = preload("res://ui/tokens.gd")
	var bar := "COLIBRI"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := T.bar_color(bar)
		var tex := T.art("bar", bar)
		if tex != null:
			T.draw_cover(self, tex, r, 0.35)
		else:
			draw_rect(r, col.darkened(0.5))
		draw_rect(r, col, false, 3.0)
		var f := T.font("title", 800)
		var name := T.bar_name(bar)
		var band := Rect2(0, size.y - 24.0, size.x, 24.0)
		draw_rect(band, Color(0, 0, 0, 0.62))
		draw_string(f, Vector2(0, size.y - 7.0), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, T.GOLD)
