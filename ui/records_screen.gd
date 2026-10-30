extends Control
## Records and achievements overlay (Phase 13), opened from the main menu. Reads user://records.json (ui/records.gd).

signal closed

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Audio = preload("res://ui/audio.gd")
const Rec = preload("res://ui/records.gd")

var highlight: Array = []              # achievement ids to mark as "NEW"
var _panel: PanelContainer
var _body: VBoxContainer
var _pages: Array = []                 # Phase 29: 전적 / 업적 / 최근 게임 as tabs (no scrolling)
var _tabs: VBoxContainer
var _confirm_reset := false


func _ready() -> void:
	Audio.play("panel_open")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.86)
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
	var head := HBoxContainer.new()
	var title := W.label("기록 · 업적", 30, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := W.button("X", "secondary", 22, Vector2(48, 44))
	x.pressed.connect(close)
	head.add_child(x)
	v.add_child(head)
	v.add_child(HSeparator.new())
	for i in range(3):
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 14)
		_pages.append(pg)
	_body = _pages[0]
	_tabs = W.tabs(["전적", "업적", "최근 게임"], _pages, 16)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_build()
	var cb := W.button("닫기", "primary", 18, Vector2(0, 48))
	cb.add_theme_font_override("font", T.font("ui", 800))
	cb.pressed.connect(close)
	v.add_child(cb)
	resized.connect(_fit)
	_fit()
	cb.grab_focus()


func _fit() -> void:
	_panel.custom_minimum_size = Vector2(maxf(280.0, minf(980.0, size.x - 40.0)), maxf(300.0, minf(680.0 if size.x > size.y else 1240.0, size.y - 40.0)))


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
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _section(text: String) -> Label:
	return W.label(text, 18, T.GOLD_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)


## `lead` is the handful of figures a player actually looks for (games, wins, win rate): those are set in a framed
## block and read large. Everything else is a plain figure with its caption - no box, so the screen stops being a grid
## of identical tiles and starts having a first and a second rank.
func _stat(parent: Container, label: String, value: String, lead: bool = false) -> void:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(W.label(value, 30 if lead else 21, T.GOLD if lead else T.TEXT, "money", HORIZONTAL_ALIGNMENT_CENTER, 800))
	vb.add_child(W.label(label, 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))
	if not lead:
		vb.custom_minimum_size = Vector2(104, 0)
		parent.add_child(vb)
		return
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", W.sb(Color("1d1710"), Color(T.GOLD, 0.65), 1, 10, Vector4(20, 10, 20, 10)))
	pc.add_child(vb)
	parent.add_child(pc)


func tab_count() -> int:
	return _pages.size()


func select_tab(i: int) -> void:
	(_tabs.get_meta("select") as Callable).call(i)


func _build() -> void:
	for pg in _pages:
		for c in pg.get_children():
			c.queue_free()
	_body = _pages[0]
	var r := Rec.load_records()
	if int(r["games"]) == 0:
		var l := W.label("아직 끝낸 게임이 없어요. 한 판을 끝내면 여기에 기록과 업적이 쌓입니다.", 17, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_body.add_child(l)
	else:
		_body.add_child(_section("내 전적"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stat(flow, "게임", "%d" % int(r["games"]), true)
		_stat(flow, "우승", "%d" % int(r["wins"]), true)
		_stat(flow, "승률", "%d%%" % int(round(Rec.win_rate(r) * 100.0)), true)
		_stat(flow, "현재 연승", "%d" % int(r["streak"]))
		_stat(flow, "최고 연승", "%d" % int(r["best_streak"]))
		_stat(flow, "최고 보유금", T.money(int(r["best"]["money"])))
		_body.add_child(flow)
		var t: Dictionary = r["totals"]
		_body.add_child(_section("누적 기록"))
		var flow2 := HFlowContainer.new()
		flow2.add_theme_constant_override("h_separation", 10)
		flow2.add_theme_constant_override("v_separation", 10)
		flow2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stat(flow2, "결투", T.t("%d승 %d패") % [int(t["duel_wins"]), int(t["duels"]) - int(t["duel_wins"])])
		_stat(flow2, "RAZZIA 발동", "%d" % int(t["razzias"]))
		_stat(flow2, "독점한 술집", "%d" % int(t["solo_wins"]))
		_stat(flow2, "통과된 제안", "%d" % int(t["deals"]))
		_stat(flow2, "최고 한 방", T.money(int(r["best"]["award"])))
		_body.add_child(flow2)
		if not r["by_count"].is_empty():
			var keys: Array = r["by_count"].keys()
			keys.sort_custom(func(a, b): return int(a) < int(b))
			var parts: Array = []
			for k in keys:
				parts.append(T.t("%s인 %d승/%d판") % [k, int(r["by_count"][k]["wins"]), int(r["by_count"][k]["games"])])
			var l2 := W.label(T.t("인원별:") + " " + "  ·  ".join(parts), 15, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
			l2.autowrap_mode = TextServer.AUTOWRAP_WORD
			_body.add_child(l2)
	# achievements
	_body = _pages[1]
	var got := 0
	for id in Rec.ORDER:
		if r["achievements"].has(id):
			got += 1
	_body.add_child(_section(T.t("업적  %d / %d") % [got, Rec.ORDER.size()]))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in Rec.ORDER:
		var info: Array = Rec.ACHIEVEMENTS[id]
		var unlocked: bool = r["achievements"].has(id)
		var pc := PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.custom_minimum_size = Vector2(250, 0)
		# earned entries are stamped in brass; the ones still to come sit quietly behind them with no frame at all
		if unlocked:
			pc.add_theme_stylebox_override("panel", W.sb(Color("241c11"), T.GOLD if id in highlight else Color(T.BRASS, 0.85), 2 if id in highlight else 1, 10, Vector4(12, 8, 12, 8)))
		else:
			pc.add_theme_stylebox_override("panel", W.sb(Color("16110b"), Color(0, 0, 0, 0), 0, 10, Vector4(12, 8, 12, 8)))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 1)
		pc.add_child(vb)
		var title: String = ("[달성] " if unlocked else "") + T.t(str(info[0])) + ("   NEW" if id in highlight else "")
		vb.add_child(W.label(title if unlocked else "???  " + T.t(str(info[0])), 17, T.GOLD if unlocked else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
		var d := W.label(str(info[1]), 13, T.TEXT if unlocked else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		vb.add_child(d)
		if not unlocked and info[2] == "total":
			vb.add_child(W.label(_progress(id, r), 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700))
		grid.add_child(pc)
	_body.add_child(grid)
	# recent games
	_body = _pages[2]
	if r["history"].is_empty():
		var l3 := W.label("아직 끝낸 게임이 없어요. 한 판을 끝내면 여기에 기록과 업적이 쌓입니다.", 17, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD
		_body.add_child(l3)
	if not r["history"].is_empty():
		_body.add_child(_section("최근 게임"))
		var hist: Array = r["history"].duplicate()
		hist.reverse()
		for h in hist.slice(0, 8):
			var line := T.t("%d인 · %d라운드 · %d등 · %s") % [int(h["players"]), int(h["rounds"]), int(h["rank"]), T.money(int(h["money"]))]
			_body.add_child(W.label(((T.t("우승") + "  ") if h["won"] else "     ") + line, 15, T.GOLD if h["won"] else T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
		var rb := W.button("기록 초기화" if not _confirm_reset else "정말 지울까요? 한 번 더 누르면 삭제", "danger", 15, Vector2(0, 42))
		rb.add_theme_font_override("font", T.font("ui", 800))
		rb.pressed.connect(func():
			if not _confirm_reset:
				_confirm_reset = true
				rb.text = "정말 지울까요? 한 번 더 누르면 삭제"
			else:
				Rec.save_records(Rec.blank())
				_confirm_reset = false
				_build())
		_body.add_child(rb)


func _progress(id: String, r: Dictionary) -> String:
	match id:
		"games_10": return T.t("진행 %d / 10") % int(r["games"])
		"wins_5": return T.t("진행 %d / 5") % int(r["wins"])
		"streak_3": return T.t("최고 연승 %d / 3") % int(r["best_streak"])
	return ""
