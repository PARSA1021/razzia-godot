extends "res://ui/board/board_base.gd"
## Board layout: building the screen, landscape / portrait placement, the hand fan, the opponents rail, the felt.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


func _fit_viewport() -> void:
	# a Control under the root Window is not anchored automatically in every setup; size it explicitly
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	bar_views.clear()
	chips.clear()
	hand_views.clear()
	strip_views.clear()
	table_cards.clear()
	bar_order.clear()
	disp = {
		"round": 0, "croupier": "", "deck": 0, "final": false,
		"bar_money": {}, "bar_cards": {}, "money": {}, "ready": {},
	}
	for b in state["bars"]:
		if b["active"]:
			bar_order.append(b["id"])
			disp["bar_money"][b["id"]] = 0
			disp["bar_cards"][b["id"]] = 0
	for p in state["players"]:
		disp["money"][p["id"]] = 0
		disp["ready"][p["id"]] = false
	disp["deck"] = 84 if int(state["playerCount"]) >= 4 else 72

	# felt table cloth (behind everything; z -1 so the tray band / table outline drawn by this node stay on top)
	felt = ColorRect.new()
	felt.color = Color.WHITE
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	felt.z_index = -1
	var fm := ShaderMaterial.new()
	fm.shader = load(FELT_STATIC if Settings.quality_effective == "BATTERY" else FELT_ANIMATED)
	fm.set_shader_parameter("animated", 0.0 if Settings.reduce_motion else 1.0)
	felt.material = fm
	add_child(felt)
	felt_state = ""
	felt_amount = 0.0

	# bars
	for id in bar_order:
		var bv := BarView.new()
		bv.setup(id)
		bv.chosen.connect(_on_bar_chosen)
		bv.info_requested.connect(_on_bar_info)
		add_child(bv)
		bar_views[id] = bv

	# strip (face-down cards before the reveal) + narration
	now_label = W.label("", 20, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	now_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	now_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# the line sits straight on the felt now: a dark outline keeps it readable without a panel
	now_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03, 0.95))
	now_label.add_theme_constant_override("outline_size", 5)
	add_child(now_label)

	# hand tray
	confirm_btn = W.button("PLAY CARD", "primary", 22, Vector2(260, 46))
	confirm_btn.set_meta("no_auto_focus", true)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	add_child(confirm_btn)
	skip_btn = W.button("SKIP ▶▶", "secondary", 14, Vector2(100, 34))
	skip_btn.set_meta("no_auto_focus", true)
	skip_btn.pressed.connect(func(): skip = true)
	skip_btn.visible = false
	add_child(skip_btn)

	# HUD
	exit_btn = W.button("⎋", "secondary", 22, Vector2(46, 46))
	exit_btn.set_meta("no_auto_focus", true)
	exit_btn.pressed.connect(_on_exit_pressed)
	add_child(exit_btn)
	stat_deck = W.StatView.new()
	stat_deck.title = "MONEY DECK"
	stat_deck.value = "0"
	add_child(stat_deck)
	pile = W.PileView.new()
	pile.total = int(disp["deck"])
	pile.count = int(disp["deck"])
	add_child(pile)
	stat_round = W.StatView.new()
	stat_round.title = "ROUND"
	stat_round.value = "00"
	add_child(stat_round)
	stat_table = W.StatView.new()
	stat_table.title = "ON THE TABLE"
	stat_table.short_title = "TABLE"
	stat_table.value = "$0"
	add_child(stat_table)
	final_badge = W.label("FINAL ROUND", 14, Color("1a120e"), "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	final_badge.add_theme_stylebox_override("normal", W.sb(T.GOLD, Color(0, 0, 0, 0), 0, 9, Vector4(12, 3, 12, 3)))
	final_badge.visible = false
	add_child(final_badge)

	me_chip = _make_chip(human_id, true)
	add_child(me_chip)    # (was never added to the tree: the player's own money was not shown anywhere)
	relic_tray = HBoxContainer.new()
	relic_tray.add_theme_constant_override("separation", int(6 * u))
	relic_tray.name = "RelicTray"
	relic_tray.visible = false
	add_child(relic_tray)
	_update_relic_tray()
	opp_btn = W.button("다른 플레이어 정보 보기 ▼", "secondary", 14, Vector2(240, 30))
	opp_btn.set_meta("no_auto_focus", true)
	opp_btn.pressed.connect(func(): _toggle_opp(not _opp_open))
	add_child(opp_btn)
	opp_panel = Control.new()
	opp_panel.visible = false
	add_child(opp_panel)
	for p in state["players"]:
		if p["id"] != human_id:
			opp_panel.add_child(_make_chip(p["id"], false))

	# overlays
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 40
	add_child(dim)
	nego = NegoPanel.new()
	nego.skipping = func(): return skip
	nego.z_index = 45
	nego.opened.connect(func(): nego_opened.emit())
	add_child(nego)
	add_child(PauseKeys.new(self))
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.z_index = 46
	add_child(modal_layer)
	# 마지막 모달이 어떤 경로로 사라지든(닫기 버튼·B·직접 해제) 빈 레이어가 탁자 입력을 막지 않게
	modal_layer.child_exiting_tree.connect(func(_n):
		(func():
			if is_instance_valid(modal_layer) and modal_layer.get_children().filter(func(c): return not c.is_queued_for_deletion()).is_empty():
				modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE).call_deferred())
	fx_layer = Control.new()
	fx_layer.name = "FxLayer"          # cards and money in flight: moving, never something to read at rest (text audit skips it)
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.z_index = 30
	add_child(fx_layer)
	toast_label = W.label("", 18, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	toast_label.add_theme_stylebox_override("normal", W.sb(Color("1a1208ee"), T.BRASS, 1, 10, Vector4(16, 8, 16, 8)))
	toast_label.visible = false
	add_child(toast_label)
	_built = true


func _make_chip(pid: String, is_me: bool) -> Control:
	var c := W.PlayerChip.new()
	c.player_id = pid
	c.player_name = _nm(pid)
	c.is_me = is_me
	if not is_me:
		for pl in state.get("players", []):
			if pl["id"] == pid and pl.get("personality") != null and not pl.get("isHuman", false):
				c.personality = str(pl["personality"])
	chips[pid] = c
	c.set_money(0)
	return c


## SteamDeckManager -> call_group("quality_listeners"): the felt follows the preset without a restart.
func on_quality_changed(preset: String) -> void:
	if felt == null or not is_instance_valid(felt):
		return
	var m := felt.material as ShaderMaterial
	var want: String = FELT_STATIC if preset == "BATTERY" else FELT_ANIMATED
	if m != null and m.shader != null and m.shader.resource_path != want:
		m.shader = load(want)


func _set_felt(state_name: String) -> void:
	if felt == null or not is_instance_valid(felt) or state_name == felt_state:
		return
	felt_state = state_name
	var m := felt.material as ShaderMaterial
	if state_name != "":
		m.set_shader_parameter("tint", FELT_TINTS[state_name])
	var to := 0.0 if state_name == "" else (0.5 if state_name == "razzia" else 0.38)
	if skip or Settings.reduce_motion:
		felt_amount = to
		m.set_shader_parameter("tint_amount", to)
		return
	var from: float = felt_amount
	var tw := create_tween()
	tw.tween_method(func(v: float): felt_amount = v; m.set_shader_parameter("tint_amount", v), from, to, 0.5)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if felt == null:
		var top := Color("0f1914")
		var bot := Color("07090a")
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bot, bot]))
	# Speakeasy table atmosphere: refined double brass hairline rail with Art Deco corner ornaments
	if size.x > 100.0 and size.y > 100.0:
		var inset := 8.0 * u
		var tr := Rect2(inset, inset, size.x - 2.0 * inset, size.y - 2.0 * inset)
		# Outer brass rail hairline
		draw_rect(tr, Color(T.BRASS, 0.35), false, maxf(1.0, 1.5 * u))
		# Inner subtle gold hairline
		var tr2 := tr.grow(-4.0 * u)
		draw_rect(tr2, Color(T.GOLD, 0.20), false, maxf(1.0, 1.0 * u))
		# Deco corner diamonds
		var s := 3.5 * u
		for pt in [tr.position + Vector2(10 * u, 10 * u), Vector2(tr.end.x - 10 * u, tr.position.y + 10 * u), Vector2(tr.position.x + 10 * u, tr.end.y - 10 * u), tr.end - Vector2(10 * u, 10 * u)]:
			draw_polygon(PackedVector2Array([pt + Vector2(0, -s), pt + Vector2(s, 0), pt + Vector2(0, s), pt + Vector2(-s, 0)]), PackedColorArray([Color(T.GOLD, 0.45)]))


func _relayout() -> void:
	if not _built:
		return
	var W_ := size.x
	var H := size.y
	if W_ < 10.0 or H < 10.0:
		return
	landscape = W_ >= H
	var win := get_window()
	if win != null and win.content_scale_size.x > 0:
		T.screen_scale = minf(float(win.size.x) / float(win.content_scale_size.x), float(win.size.y) / float(win.content_scale_size.y))
	u = clampf(minf(W_ / 1280.0, H / 720.0), 0.5, 1.6) if landscape else clampf(minf(W_ / 720.0, H / 1280.0), 0.5, 1.6)
	var m := 20.0 * u
	if landscape:
		_layout_landscape(W_, H, m)
	else:
		_layout_portrait(W_, H, m)
	nego.personalities = {}
	for pl in state.get("players", []):
		if not pl.get("isHuman", false) and pl.get("personality") != null:
			nego.personalities[pl["id"]] = pl["personality"]
	nego.setup(names, human_id, u, minf(W_ - 2.0 * m, (560.0 if landscape else 720.0) * u))
	nego.dock_limit_y = _grid_bottom + 8.0 * u
	nego.landscape = landscape
	nego.dock_x0 = _land_x0
	nego.dock_x1 = _land_x1
	nego.wide_width = minf(_land_x1 - _land_x0, 760.0 * u)
	nego._queue_fit()
	now_label.add_theme_font_size_override("font_size", int(round((20.0 if landscape else 22.0) * u)))
	_layout_hand()
	_layout_opp()          # before the strip: in the phone layout the played cards sit next to the rail chips
	_layout_strip()
	queue_redraw()


func _place(c: Control, pos: Vector2, sz: Vector2) -> void:
	c.position = pos
	c.size = sz
	c.custom_minimum_size = Vector2.ZERO if not (c is Button) else c.custom_minimum_size


## Landscape = "table mode", laid out like a console card game: a slim info rail on the left (round / deck / table money,
## every opponent, my own money), the venues in the middle, my hand big at the bottom with the PLAY button right next to it.
## Nothing is hidden behind a dropdown, the header rows are gone and the hand gets ~27% of the height.
func _layout_landscape(W_: float, H: float, m: float) -> void:
	var cw_max := minf(W_, H * 2.05)                     # ultrawide: keep the content block compact and centred
	var cx0 := (W_ - cw_max) / 2.0
	# Phone landscape (Phase 29): a 390-pt-high screen shows the 720-high table at ~54 %, so the usual layout had 5-7 px
	# text. Here the screen height goes to what is read and touched: the submission row is dropped (each player's face-down
	# card sits right beside their chip in the rail), the rail chips, the hand and the PLAY button get bigger, the venue
	# posters get shorter.
	compact = T.screen_scale < 0.75
	_chip_k = clampf(0.72 / maxf(0.3, T.screen_scale), 1.0, 1.3) if compact else 1.0
	var rail_w := 188.0 * u * (1.12 if compact else 1.0)
	var rx := cx0 + m
	var ry := 10.0 * u
	var bh := 38.0 * u
	var gap_x := 8.0 * u
	var gap_y := 8.0 * u
	exit_btn.custom_minimum_size = Vector2(bh, bh)
	_place(exit_btn, Vector2(rx, ry), Vector2(bh, bh))
	_place(stat_round, Vector2(rx + bh + gap_x, ry), Vector2(rail_w - bh - gap_x, bh))
	ry += bh + gap_y
	stat_deck.visible = false                    # the deck is a real pile of cards in the table area (landscape)
	pile.visible = true
	var table_h := 38.0 * u
	_place(stat_table, Vector2(rx, ry), Vector2(rail_w, table_h))
	ry += table_h + 10.0 * u
	opp_rail_pos = Vector2(rx, ry)
	opp_rail_w = rail_w
	var me_h := 58.0 * u * _chip_k
	if relic_tray != null and is_instance_valid(relic_tray):
		_place(relic_tray, Vector2(rx, H - 12.0 * u - me_h - 28.0 * u), Vector2(rail_w, 24.0 * u))
	_place(me_chip, Vector2(rx, H - 12.0 * u - me_h), Vector2(rail_w, me_h))
	final_badge.position = Vector2(rx + rail_w - 110.0 * u, 10.0 * u + bh - 6.0 * u)
	opp_btn.visible = false

	var played_w := (46.0 * u * _chip_k / 1.38 + 14.0 * u) if compact else 0.0     # the face-down card column beside the rail
	var bx0 := rx + rail_w + 16.0 * u + played_w
	var bw := cx0 + cw_max - m - bx0
	var pad := 12.0 * u
	var hand_h := clampf(H * 0.29, 136.0 * u, 280.0)
	if compact:
		hand_h = clampf(H * 0.41, 136.0 * u, 340.0)
	hand_h = maxf(hand_h, 136.0 * u)
	var hand_w := hand_h / 1.385
	var hand_gap := 12.0 * u
	var hand_total := 5.0 * hand_w + 4.0 * hand_gap
	# the button is as wide as its longest label needs (PICK A CARD...), so shrinking the row never pushes it off the screen
	var btn_w := maxf(190.0 * u, _confirm_text_w() + 36.0 * u)
	var btn_gap := 18.0 * u
	if hand_total + btn_gap + btn_w > bw:
		# the hand gives way; the button keeps the room its label needs
		var f := maxf(0.4, (bw - btn_gap - btn_w) / hand_total)
		hand_h *= f
		hand_w *= f
		hand_gap *= f
		hand_total *= f
	var group_w := hand_total + btn_gap + btn_w
	var gx := bx0 + (bw - group_w) / 2.0
	# bottom safe area: the fan dips (outer cards) and rotates, so keep the whole fan inside the screen
	var hand_y := H - pad - hand_h - (10.0 * u + hand_h * 0.05) - 4.0 * u
	var now_y := hand_y - 58.0 * u          # clear of the lifted / focused card ring (up to ~29u above the hand)
	# submission row: big enough to read "who has played" at a glance (was a fixed 46x64 strip)
	var strip_h := clampf(H * 0.19, 100.0 * u, 190.0 * u)
	var strip_card_h := strip_h - 14.0 * u
	var strip_y := now_y - strip_h - 4.0 * u
	if compact:
		strip_h = 0.0
		strip_y = now_y
	var y0 := 12.0 * u
	# the PLAY button sits right beside the hand (short thumb / stick travel); it is the only big button on the board
	confirm_btn.custom_minimum_size = Vector2(btn_w, 68.0 * u)
	_place(confirm_btn, Vector2(gx + hand_total + btn_gap, hand_y + hand_h * 0.5 - 34.0 * u), Vector2(btn_w, 68.0 * u))
	_place(now_label, Vector2(bx0, now_y), Vector2(bw - 110.0 * u, 26.0 * u))
	skip_btn.custom_minimum_size = Vector2(100.0 * u, 30.0 * u)
	_place(skip_btn, Vector2(bx0 + bw - 100.0 * u, now_y - 2.0 * u), Vector2(100.0 * u, 30.0 * u))

	# venues: width-limited, then as tall as the free height allows (the posters are portrait)
	var avail := strip_y - 16.0 * u - y0
	var n := bar_order.size()
	var gap_b := 12.0 * u
	var venue_w := minf((bw - (n - 1) * gap_b) / float(n), 200.0 * u)
	# Layout B ("card-centred"): no reserved landing zone under the posters. Played cards land ON the lower part of the
	# poster (BarView.mini_rects), so every pixel under the venues goes to the submission row and the hand.
	var venue_h := clampf(avail, venue_w * 1.25, venue_w * 1.85)
	if venue_h > avail:
		var f2 := avail / venue_h
		venue_w *= f2
		venue_h *= f2
	var mini_w := venue_w * 0.4
	var mini_h := mini_w * 1.38
	var bars_w := n * venue_w + (n - 1) * gap_b
	var bx := bx0 + (bw - bars_w) / 2.0
	var by := y0
	_land_x0 = bx0
	_land_x1 = bx0 + bw
	for i in range(n):
		var bv: BarView = bar_views[bar_order[i]]
		bv.mode = "card"
		bv.venue_h = venue_h
		bv.mini_size = Vector2(mini_w, mini_h)
		bv.position = Vector2(bx + i * (venue_w + gap_b), by)
		bv.size = Vector2(venue_w, venue_h)
		bv.layout_minis()
		bv.queue_redraw()
	_table_rect = Rect2()
	_grid_bottom = by + venue_h
	_tray_rect = Rect2(bx0 - 10.0 * u, now_y - 6.0 * u, bw + 20.0 * u, H - (now_y - 6.0 * u))
	_set_hand_metrics(hand_w, hand_h, hand_y, hand_total, hand_gap, gx)
	if compact:
		# the deck sits above the PLAY button; the played cards go beside the rail chips (see _layout_strip)
		var ph2 := clampf(hand_h * 0.5, 60.0 * u, 140.0 * u)
		pile.size = Vector2(ph2 / 1.3135, ph2)
		pile.position = Vector2(confirm_btn.position.x + (btn_w - pile.size.x) / 2.0, confirm_btn.position.y - ph2 - 10.0 * u)
		var ch := 46.0 * u * _chip_k
		_strip_metrics = {"card": Vector2(ch / 1.38, ch), "rail": true, "x": rx + rail_w + 8.0 * u}
		return
	var pile_h := strip_h * 0.9
	pile.size = Vector2(pile_h / 1.3135, pile_h)   # card face keeps the 1:1.38 ratio after the 5 stack offsets
	pile.position = Vector2(bx0 + bw - pile.size.x, strip_y + (strip_h - pile.size.y) / 2.0)
	_set_strip_metrics(Vector2(strip_card_h / 1.38, strip_card_h), strip_y, strip_h, bw - pile.size.x - 14.0 * u, bx0)


func _layout_portrait(W_: float, H: float, m: float) -> void:
	var y := 10.0 * u
	var h1 := 50.0 * u
	_place(exit_btn, Vector2(m, y), Vector2(h1, h1))
	_place(stat_round, Vector2(m + h1 + 8.0 * u, y), Vector2(W_ - 2.0 * m - h1 - 232.0 * u - 16.0 * u, h1))
	_place(me_chip, Vector2(W_ - m - 232.0 * u, y), Vector2(232.0 * u, h1 + 4.0 * u))
	if relic_tray != null and is_instance_valid(relic_tray):
		_place(relic_tray, Vector2(W_ - m - 232.0 * u, y + h1 + 6.0 * u), Vector2(232.0 * u, 24.0 * u))
	var y2 := y + h1 + 8.0 * u
	var h2 := 46.0 * u
	var half := (W_ - 2.0 * m - 12.0 * u) / 2.0
	stat_deck.visible = true
	pile.visible = false
	_place(stat_deck, Vector2(m, y2), Vector2(half, h2))
	_place(stat_table, Vector2(m + half + 12.0 * u, y2), Vector2(half, h2))
	final_badge.position = Vector2((W_ - 120.0 * u) / 2.0, y + h1 - 2.0 * u)
	_place(opp_btn, Vector2((W_ - 290.0 * u) / 2.0, y2 + h2 + 8.0 * u), Vector2(290.0 * u, 32.0 * u))
	var y0 := y2 + h2 + 8.0 * u + 32.0 * u + 10.0 * u

	var hand_gap := 10.0 * u
	var hand_w := minf((W_ - 2.0 * m - 4.0 * hand_gap) / 5.0, 140.0 * u)        # tablets: the hand must not eat the posters
	var hand_h := hand_w * 1.385
	var confirm_h := 62.0 * u
	var pad := 16.0 * u
	var hand_y := H - pad - confirm_h - 18.0 * u - hand_h
	var now_y := hand_y - 92.0 * u
	var n_pl: int = state["players"].size()
	var s_gap := 12.0 * u
	var s_w := minf((W_ - 2.0 * m - float(n_pl - 1) * s_gap) / float(n_pl), 84.0 * u)    # as big as the row allows (was fixed 48u)
	var strip_h := s_w * 1.38 + 16.0 * u
	var strip_y := now_y - strip_h - 4.0 * u
	_tray_rect = Rect2(0, now_y - 6.0 * u, W_, H - (now_y - 6.0 * u))
	var avail := strip_y - 10.0 * u - y0
	var n := bar_order.size()
	# Portrait = a poster GRID (same venue cards as landscape, same design language). 3x2 or 6x1, whichever gives bigger posters.
	var g := 12.0 * u
	var best := {"score": -1.0}
	for cols in [3, 2, 6]:
		var rows := ceili(float(n) / float(cols))
		var pw := minf((W_ - 2.0 * m - float(cols - 1) * g) / float(cols), 240.0 * u)
		var ph_avail := (avail - float(rows - 1) * g) / float(rows)
		var ph := clampf(ph_avail, 0.0, pw * 1.85)
		if ph < pw * 1.2:
			pw = ph / 1.2
		var score := pw * ph * (1.0 if cols != 6 else 0.9)
		if pw >= 70.0 * u and score > float(best["score"]):
			best = {"score": score, "cols": cols, "rows": rows, "pw": pw, "ph": ph}
	if best["score"] < 0.0:
		best = {"score": 0.0, "cols": 3, "rows": 2, "pw": 80.0 * u, "ph": 100.0 * u}
	var cols_b: int = best["cols"]
	var rows_b: int = best["rows"]
	var pw_b: float = best["pw"]
	var ph_b: float = best["ph"]
	var grid_h := float(rows_b) * ph_b + float(rows_b - 1) * g
	var by := y0 + maxf(0.0, (avail - grid_h) / 2.0)
	for i in range(n):
		var bv: BarView = bar_views[bar_order[i]]
		var rr := i / cols_b
		var cc := i % cols_b
		var in_row := mini(cols_b, n - rr * cols_b)
		var row_w := float(in_row) * pw_b + float(in_row - 1) * g
		bv.mode = "card"
		bv.venue_h = ph_b
		bv.mini_size = Vector2(pw_b * 0.44, pw_b * 0.44 * 1.38)
		bv.position = Vector2((W_ - row_w) / 2.0 + float(cc) * (pw_b + g), by + float(rr) * (ph_b + g))
		bv.size = Vector2(pw_b, ph_b)
		bv.layout_minis()
		bv.queue_redraw()
	_table_rect = Rect2()
	_grid_bottom = by + grid_h
	_place(now_label, Vector2(m, now_y), Vector2(W_ - 2.0 * m - 124.0 * u, 62.0 * u))
	confirm_btn.custom_minimum_size = Vector2(W_ - 2.0 * m, confirm_h)
	_place(confirm_btn, Vector2(m, H - pad - confirm_h), Vector2(W_ - 2.0 * m, confirm_h))
	_place(skip_btn, Vector2(W_ - m - 112.0 * u, now_y + 2.0 * u), Vector2(112.0 * u, 38.0 * u))
	_set_hand_metrics(hand_w, hand_h, hand_y, W_, hand_gap)
	_set_strip_metrics(Vector2(s_w, s_w * 1.38), strip_y, strip_h, W_)


func _set_hand_metrics(cw: float, ch: float, y: float, W_: float, gap: float, x_off: float = 0.0) -> void:
	_hand_metrics = {"w": cw, "h": ch, "y": y, "W": W_, "gap": gap, "x": x_off}


func _set_strip_metrics(card: Vector2, y: float, h: float, W_: float, x_off: float = 0.0) -> void:
	_strip_metrics = {"card": card, "y": y, "h": h, "W": W_, "x": x_off}

func _hand_target(i: int, n: int) -> Dictionary:
	var cw: float = _hand_metrics["w"]
	var gap: float = _hand_metrics["gap"]
	var total := n * cw + maxi(0, n - 1) * gap
	var x0: float = float(_hand_metrics.get("x", 0.0)) + (float(_hand_metrics["W"]) - total) / 2.0
	var cv: Control = hand_views[i]
	var t := 0.0 if n <= 1 else (float(i) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)    # -1 .. 1 across the hand
	var rot := deg_to_rad(FAN_DEG) * t
	var dy := 10.0 * u * t * t                                                                # outer cards dip a little
	var dy_rest := dy
	var up := 0.0
	var front := false
	if cv == selected_view:
		up = -22.0 * u
		front = true
	elif cv.get("hovering") and cv.interactive:
		up = -12.0 * u
		front = true
	elif cv.get("focused"):
		up = -8.0 * u
		front = true
	if front:
		rot *= 0.25            # lifted cards straighten up so their text is easy to read
		dy *= 0.3
	return {"pos": Vector2(x0 + i * (cw + gap), float(_hand_metrics["y"]) + dy + up), "rot": rot, "front": front, "rise": ((dy_rest - dy) - up) if front else 0.0}


func _layout_hand(animate: bool = true) -> void:
	if _hand_metrics.is_empty():
		return
	var n := hand_views.size()
	var cw: float = _hand_metrics["w"]
	var ch: float = _hand_metrics["h"]
	for i in range(n):
		var cv: Control = hand_views[i]
		if not is_instance_valid(cv) or cv.has_meta("intro"):
			continue                # still flying in from the deck; re-laid out when it lands
		cv.size = Vector2(cw, ch)
		var tg := _hand_target(i, n)
		cv.z_index = 10 if tg["front"] else 0
		cv.hit_extend = (float(tg["rise"]) + 6.0 * u) if tg["front"] else 0.0       # how far the lifted card left its resting footprint (+ a little for the straightening)
		cv.hit_exclude = confirm_btn          # the extended footprint never takes clicks meant for PLAY CARD (it may reach it on a narrow screen)
		var lift_to := (1.0 if cv == selected_view else 0.6) if tg["front"] else 0.0
		var old =cv.get_meta("tw") if cv.has_meta("tw") else null
		if old != null and old.is_valid():
			old.kill()
		if not animate or skip or Settings.reduce_motion or not cv.is_inside_tree():
			cv.position = tg["pos"]
			cv.rotation = tg["rot"]
			cv.lift = lift_to
			continue
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(cv, "position", tg["pos"], Settings.dur(0.16) + 0.001).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "rotation", tg["rot"], Settings.dur(0.16) + 0.001).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "lift", lift_to, Settings.dur(0.16) + 0.001)
		cv.set_meta("tw", tw)


func _on_hand_hover(_cv: Control) -> void:
	if _awaiting_select:
		if _cv.get("hovering") and _cv.interactive:
			Audio.play("hover")
		_layout_hand()
		_update_hint()


## Contextual card hint (Balatro-style "what does this do"), shown in the narration line while choosing.
## Wording follows the engine rules: RAZZIA shuts zockers out, a lone claimant takes the bar,
## otherwise a negotiation where the highest die symbol proposes first.
func _card_hint(card: Dictionary) -> String:
	var bn := T.bar_name(str(card.get("barId", "")))
	if card.get("type", "") == "RAZZIA":
		return tr("RAZZIA %s · 도박꾼을 쫓아내고 이 바의 돈을 차지 · 도박꾼 없으면 돈 유지") % bn
	# "RAZZIA에" would wrap between the Latin word and the Korean particle on a narrow screen: keep a real space there
	return tr("%s 도박꾼 · 혼자면 전부 · 여럿이면 협상 · RAZZIA 단속 시 쫓겨남") % bn


func _update_hint() -> void:
	if not _awaiting_select:
		return
	_now("")


func _layout_strip() -> void:
	if _strip_metrics.is_empty():
		return
	if _strip_metrics.get("rail", false):
		for pid in strip_views:
			var sv = strip_views[pid]
			if sv != null and is_instance_valid(sv):
				sv.size = _strip_metrics["card"]
				sv.position = strip_slot_pos(pid)
				sv.caption = ""
		return
	var ids: Array = []
	for p in state["players"]:
		ids.append(p["id"])
	var card: Vector2 = _strip_metrics["card"]
	var gap := 12.0 * u
	var n := ids.size()
	var total := n * card.x + (n - 1) * gap
	var x0: float = float(_strip_metrics.get("x", 0.0)) + (float(_strip_metrics["W"]) - total) / 2.0
	var y: float = float(_strip_metrics["y"]) + (float(_strip_metrics["h"]) - card.y) / 2.0
	for i in range(n):
		var sv = strip_views.get(ids[i])
		if sv != null and is_instance_valid(sv):
			sv.size = card
			sv.position = Vector2(x0 + i * (card.x + gap), y)


func strip_slot_pos(pid: String) -> Vector2:
	if _strip_metrics.get("rail", false):
		# phone layout: right beside that player's chip in the rail
		var chip: Control = chips.get(pid)
		var y := 0.0
		if chip != null:
			y = (chip.global_position - global_position).y + (chip.size.y - (_strip_metrics["card"] as Vector2).y) / 2.0
		return Vector2(float(_strip_metrics["x"]), y)
	var ids: Array = []
	for p in state["players"]:
		ids.append(p["id"])
	var card: Vector2 = _strip_metrics["card"]
	var gap := 12.0 * u
	var n := ids.size()
	var total := n * card.x + (n - 1) * gap
	var x0: float = float(_strip_metrics.get("x", 0.0)) + (float(_strip_metrics["W"]) - total) / 2.0
	var y: float = float(_strip_metrics["y"]) + (float(_strip_metrics["h"]) - card.y) / 2.0
	return Vector2(x0 + ids.find(pid) * (card.x + gap), y)


func _layout_opp() -> void:
	var others: Array = []
	for pid in chips:
		if pid != human_id:
			others.append(chips[pid])
	if landscape:
		# always-visible column in the info rail (no dropdown, no extra tap to see standings)
		var chh_l := 46.0 * u * _chip_k
		var gap_l := 6.0 * u
		opp_panel.visible = true
		opp_panel.z_index = 0
		opp_panel.position = opp_rail_pos
		opp_panel.size = Vector2(opp_rail_w, others.size() * (chh_l + gap_l))
		for i in range(others.size()):
			var cl: Control = others[i]
			cl.position = Vector2(0, i * (chh_l + gap_l))
			cl.size = Vector2(opp_rail_w, chh_l)
		opp_btn.visible = false
		return
	opp_btn.visible = true
	opp_panel.visible = _opp_open
	var cw := 190.0 * u
	var chh := 50.0 * u
	var gap := 8.0 * u
	var avail := size.x - 2.0 * 20.0 * u
	var per_row := maxi(1, int((avail + gap) / (cw + gap)))
	var rows := int(ceil(float(others.size()) / float(per_row)))
	var pw := minf(avail, per_row * cw + (per_row - 1) * gap) + 20.0 * u
	var ph := rows * chh + (rows - 1) * gap + 20.0 * u
	opp_panel.size = Vector2(pw, ph)
	opp_panel.position = Vector2((size.x - pw) / 2.0, opp_btn.position.y + opp_btn.size.y + 6.0 * u)
	for i in range(others.size()):
		var c: Control = others[i]
		var row_i := i / per_row
		var col_i := i % per_row
		var in_row := mini(per_row, others.size() - row_i * per_row)
		var row_w := in_row * cw + (in_row - 1) * gap
		c.position = Vector2((pw - row_w) / 2.0 + col_i * (cw + gap), 10.0 * u + row_i * (chh + gap))
		c.size = Vector2(cw, chh)
	opp_panel.queue_redraw()


func _toggle_opp(open: bool) -> void:
	_opp_open = open
	opp_panel.visible = open
	opp_btn.text = "다른 플레이어 정보 접기 ▲" if open else "다른 플레이어 정보 보기 ▼"
	if open:
		opp_panel.z_index = 20
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("120e09f5")
		bg.border_color = T.BRASS
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(12)
		if not opp_panel.has_meta("styled"):
			opp_panel.set_meta("styled", true)
			opp_panel.draw.connect(func(): if not landscape: bg.draw(opp_panel.get_canvas_item(), Rect2(Vector2.ZERO, opp_panel.size)))
		opp_panel.queue_redraw()


## width of the widest label the PLAY button can show, at its current font (1024x768: "PICK A CARD" used to run off the edge)
func _confirm_text_w() -> float:
	var f: Font = confirm_btn.get_theme_font("font")
	var fs: int = confirm_btn.get_theme_font_size("font_size")
	var w := 0.0
	for t in ["PICK A CARD", "PLAY CARD", "PICK A BAR", "PLAYED", "PLACED"]:
		w = maxf(w, f.get_string_size(tr(t), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w
