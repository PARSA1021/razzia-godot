extends Control
## Game summary overlay (Phase 13): money over the rounds, the titles of the game, highlights and a table per player.
## Everything comes from GameSummary.compute() over the engine's event log. Opened from the end-of-game board.

signal closed

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Audio = preload("res://ui/audio.gd")
const Sum = preload("res://ui/game_summary.gd")
const Portrait = preload("res://ui/portrait.gd")
const Chars = preload("res://ui/characters.gd")
const PALETTE := [Color("d6b274"), Color("4f8fd0"), Color("c9503f"), Color("4fb06a"), Color("a56bd0"), Color("e08a3a"), Color("3fb5b0"), Color("d070a0")]

var state: Dictionary
var human_id := ""
var summary: Dictionary
var _panel: PanelContainer


func setup(p_state: Dictionary, p_human: String) -> void:
	state = p_state
	human_id = p_human
	summary = Sum.compute(state["events"], state["players"])


func _nm(pid: String) -> String:
	var n := str(Eng_player(pid)["name"])
	return T.t(n) if n == "나" else n


func Eng_player(pid: String) -> Dictionary:
	for p in state["players"]:
		if p["id"] == pid:
			return p
	return {"name": pid}


func _color(pid: String) -> Color:
	for p in state["players"]:
		if p["id"] == pid:
			return PALETTE[int(p["seatIndex"]) % PALETTE.size()]
	return T.TEXT


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
	var title := W.label("게임 요약", 30, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := W.button("X", "secondary", 22, Vector2(48, 44))
	x.pressed.connect(close)
	head.add_child(x)
	v.add_child(head)
	v.add_child(HSeparator.new())
	# Phase 29: tabs instead of one long scrolling column
	for i in range(3):
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 14)
		pg.custom_minimum_size = Vector2(minf(900.0, size.x - 120.0), 0)
		_pages.append(pg)
	_build(_pages[0])
	_tabs = W.tabs(["흐름", "하이라이트", "플레이어별"], _pages, 16)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	var close_btn := W.button("닫기", "primary", 18, Vector2(0, 48))
	close_btn.add_theme_font_override("font", T.font("ui", 800))
	close_btn.pressed.connect(close)
	v.add_child(close_btn)
	resized.connect(_fit)
	_fit()
	close_btn.grab_focus()


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


var _pages: Array = []
var _tabs: VBoxContainer


func tab_count() -> int:
	return _pages.size()


func select_tab(i: int) -> void:
	(_tabs.get_meta("select") as Callable).call(i)


func _build(body: VBoxContainer) -> void:
	var players: Array = state["players"]
	# 1) chart of the money after every round
	body.add_child(_section("라운드별 보유 금액"))
	var chart := MoneyChart.new()
	chart.custom_minimum_size = Vector2(0, 230)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.series = Sum.money_series(summary, players)
	chart.colors = {}
	chart.names = {}
	chart.human_id = human_id
	for p in players:
		chart.colors[p["id"]] = _color(p["id"])
		chart.names[p["id"]] = _nm(str(p["id"]))
	body.add_child(chart)
	# 2) titles of the game
	if not summary["awards"].is_empty():
		body.add_child(_section("이번 판의 칭호"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 8)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for a in summary["awards"]:
			var chip := PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_theme_stylebox_override("panel", W.sb(Color("1d1710"), Color(_color(a["pid"]), 0.9), 2, 10, Vector4(12, 6, 12, 6)))
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_theme_constant_override("separation", 0)
			chip.add_child(vb)
			vb.add_child(W.label("%s  ·  %s" % [T.t(str(a["title"])), _nm(a["pid"]) + _me_tag(a["pid"])], 17, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
			vb.add_child(W.label(a["desc"], 14, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
			flow.add_child(chip)
		body.add_child(flow)
	# 3) highlights
	body = _pages[1]
	body.add_child(_section("하이라이트"))
	var hl := VBoxContainer.new()
	hl.add_theme_constant_override("separation", 4)
	body.add_child(hl)
	var ba: Dictionary = summary["biggest_award"]
	if int(ba["amount"]) > 0:
		hl.add_child(_line("가장 큰 한 방", T.t("%s — %s에서 %s (라운드 %d)") % [_nm(ba["pid"]), T.bar_name(ba["barId"]), T.money(int(ba["amount"])), int(ba["round"])]))
	var bp: Dictionary = summary["biggest_prize"]
	if int(bp["prize"]) > 0:
		hl.add_child(_line("가장 큰 협상", T.t("%s %s (라운드 %d, %s)") % [T.bar_name(bp["barId"]), T.money(int(bp["prize"])), int(bp["round"]), _outcome_text(str(bp["outcome"]))]))
	var rr: int = summary["rounds"].filter(func(r): return r["razzia"]).size()
	hl.add_child(_line("RAZZIA 단속", T.t("%d라운드에서 경찰이 들이닥쳤습니다") % rr))
	if human_id != "":
		var br := Sum.best_round(summary, human_id)
		if int(br["gained"]) > 0:
			hl.add_child(_line("나의 최고의 라운드", T.t("라운드 %d, +%s") % [int(br["round"]), T.money(int(br["gained"]))]))
		var me: Dictionary = summary["players"][human_id]
		hl.add_child(_line("나의 결투 전적", T.t("%d전 %d승 %d패 · 제안 %d번 · 수락 %d번 · 결투 선언 %d번") % [int(me["duels"]), int(me["duel_wins"]), int(me["duels"]) - int(me["duel_wins"]), int(me["proposals"]), int(me["accepts"]), int(me["duel_calls"])]))
	# 4) table per player
	body = _pages[2]
	body.add_child(_section("플레이어별 기록"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for h in ["", "최종", "결투", "RAZZIA", "독점"]:
		grid.add_child(W.label(h, 14, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER if h != "" else HORIZONTAL_ALIGNMENT_LEFT, 700))
	var ranking: Array = []
	for e in state["events"]:
		if e["type"] == "GAME_ENDED":
			ranking = e["ranking"]
	for r in ranking:
		var pid: String = r["playerId"]
		var d: Dictionary = summary["players"][pid]
		var nm := W.label(_nm(pid) + _me_tag(pid), 17, _color(pid), "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pers = Eng_player(pid).get("personality", null)
		if pers != null and pid != human_id:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 8)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var face := Portrait.new()
			face.personality = str(pers)
			face.character = _nm(pid)
			face.custom_minimum_size = Vector2(40, 40)
			cell.add_child(face)
			cell.add_child(nm)
			grid.add_child(cell)
		else:
			grid.add_child(nm)
		grid.add_child(W.label(T.money(int(r["money"])), 16, T.GOLD, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800))
		grid.add_child(W.label(T.t("%d승 %d패") % [int(d["duel_wins"]), int(d["duels"]) - int(d["duel_wins"])], 15, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
		grid.add_child(W.label("%d" % int(d["razzias"]), 15, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
		grid.add_child(W.label("%d" % int(d["solo_wins"]), 15, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
	body.add_child(grid)


func _line(head: String, text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := W.label(head, 15, T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	l.custom_minimum_size = Vector2(140, 0)
	hb.add_child(l)
	var r := W.label(text, 15, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(r)
	return hb


func _outcome_text(o: String) -> String:
	match o:
		"DEAL": return T.t("합의")
		"DUEL": return T.t("결투로 결정")
		"ONE_REJECTS": return T.t("한 명이 결투")
		"TOURNAMENT": return T.t("연속 결투")
		"BOTH_REJECT": return T.t("모두 결투")
	return T.t("협상")


## "  (나)" after the human's own chosen name; nothing when the name already is the default "나" / "You"
func _me_tag(pid: String) -> String:
	return "  " + T.t("(나)") if pid == human_id and str(Eng_player(pid)["name"]) != "나" else ""


## Line chart: one polyline per player over the rounds; the human's line is thicker, names sit at the right end.
class MoneyChart extends Control:
	const T = preload("res://ui/tokens.gd")
	var series := {}
	var colors := {}
	var names := {}
	var human_id := ""

	func _draw() -> void:
		var font := T.font("ui", 700)
		var left := 70.0
		var right := 110.0
		var top := 10.0
		var bottom := 26.0
		var w := size.x - left - right
		var h := size.y - top - bottom
		var n_pts := 0
		var vmax := 1
		for pid in series:
			n_pts = maxi(n_pts, series[pid].size())
			for v in series[pid]:
				vmax = maxi(vmax, int(v))
		if n_pts == 0 or w <= 10.0:
			return
		# grid + y labels
		var step := 50000
		while vmax / step > 5:
			step *= 2
		var ymax := int(ceil(float(vmax) / float(step))) * step
		var yv := 0
		while yv <= ymax:
			var y := top + h - h * float(yv) / float(ymax)
			draw_line(Vector2(left, y), Vector2(left + w, y), Color(1, 1, 1, 0.08), 1.0)
			draw_string(font, Vector2(4, y + 5), "$%dk" % (yv / 1000), HORIZONTAL_ALIGNMENT_LEFT, left - 8, 13, T.TEXT_DIM)
			yv += step
		for i in range(n_pts):
			var x := left + (w * float(i) / float(maxi(1, n_pts - 1)))
			draw_string(font, Vector2(x - 6, size.y - 6), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 13, T.TEXT_DIM)
		# lines (human last, so it is on top)
		var order: Array = series.keys()
		order.sort_custom(func(a, b): return (a == human_id) < (b == human_id))
		var ends := []
		for pid in order:
			var pts := PackedVector2Array()
			for i in range(series[pid].size()):
				var x := left + (w * float(i) / float(maxi(1, n_pts - 1)))
				var y := top + h - h * float(series[pid][i]) / float(ymax)
				pts.append(Vector2(x, y))
			var col: Color = colors.get(pid, Color.WHITE)
			var width := 4.0 if pid == human_id else 2.0
			if pts.size() >= 2:
				draw_polyline(pts, col, width, true)
			for pnt in pts:
				draw_circle(pnt, width * 0.9, col)
			if not pts.is_empty():
				ends.append([pts[pts.size() - 1].y, pid])
		# end labels, nudged apart so they never overlap
		ends.sort_custom(func(a, b): return a[0] < b[0])
		var last_y := -100.0
		for e in ends:
			var ly: float = maxf(float(e[0]), last_y + 15.0)
			last_y = ly
			draw_string(font, Vector2(left + w + 10.0, ly + 5.0), str(names.get(e[1], e[1])), HORIZONTAL_ALIGNMENT_LEFT, right - 12.0, 14, colors.get(e[1], Color.WHITE))
