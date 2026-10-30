extends "res://ui/board/board_replay.gd"
## Board results: the round ledger, the one-line round note, the end of the game.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


## One honest sentence about the player's own round, built only from what the board has just shown: the card they played,
## who else was at that venue, why it resolved the way it did, and what they were paid. No guesses, no "what if".
func _my_round_note(ev: Dictionary) -> String:
	if human_id == "":
		return ""
	var mine := {}
	for pc in _round_plays:
		if str(pc["playerId"]) == human_id:
			mine = pc
	if mine.is_empty():
		return ""
	var bar: String = str(mine["barId"])
	var bn: String = T.bar_name(bar)
	var gained := int(ev["gained"].get(human_id, 0))
	var zockers := 0
	var razzias := 0
	for pc in _round_plays:
		if str(pc["barId"]) != bar:
			continue
		if str(pc["type"]) == "ZOCKER":
			zockers += 1
		else:
			razzias += 1
	var reason: String = str(_round_reason.get(bar, ""))
	var head := ""
	if gained > 0:
		if reason == "단독 도박꾼":
			head = tr("%s를 혼자 차지해 +%s") % [bn, T.money(gained)]
		elif reason == "RAZZIA 단속 보상":
			head = tr("%s에서 단속 보상으로 +%s") % [bn, T.money(gained)]
		elif reason == "결투 결과":
			head = tr("%s에서 결투로 +%s") % [bn, T.money(gained)]
		elif reason == "합의 분배":
			head = tr("%s에서 %d명과 합의해 +%s") % [bn, zockers - 1, T.money(gained)]
		else:
			head = tr("%s에서 +%s") % [bn, T.money(gained)]
	else:
		if str(mine["type"]) == "ZOCKER" and razzias > 0:
			head = tr("%s에서 단속에 걸려 쫓겨났습니다 (경찰 카드 %d장)") % [bn, razzias]
		elif reason == "결투 결과":
			head = tr("%s에서 결투에 져 한 푼도 못 챙겼습니다") % bn
		elif reason == "합의 분배":
			head = tr("%s 합의에서 내 몫이 없었습니다") % bn
		elif reason == "":
			head = tr("%s는 아직 정리되지 않았습니다 — 돈이 그대로 쌓여 있어요") % bn
		elif zockers > 1:
			head = tr("%s에 %d명이 몰려 내 몫이 없었습니다") % [bn, zockers]
		else:
			head = tr("%s에서 수입이 없었습니다") % bn
	# the round's biggest single payout, so the player can see what they were up against
	var top_pid := ""
	var top_amount := 0
	for pid in _round_awards:
		for a in _round_awards[pid]:
			if int(a["amount"]) > top_amount:
				top_amount = int(a["amount"])
				top_pid = str(pid)
	if top_pid != "" and (top_pid != human_id or top_amount > gained):
		head += "   ·   " + tr("이번 라운드 최고 수입 %s %s") % [_nm(top_pid) + ("" if top_pid != human_id or str(names.get(top_pid, "")) == "나" else tr(" (나)")), T.money(top_amount)]
	return head


func _ev_round_ended(ev: Dictionary) -> void:
	Audio.play("round_end")
	_clear_highlights()
	_set_felt("")
	dim.visible = false
	for pid in ev["money"]:
		_set_player_money(pid, int(ev["money"][pid]), 0.0)
	var prev_leader := _leader_id
	await _show_round_result(ev)
	var RelicManager = preload("res://engine/relic_manager.gd")
	if RelicManager.is_relic_mode(state) and not bool(ev.get("finalRound", false)) and not bot.is_valid():
		await _open_black_market(ev)
	# I just took the lead (strictly first) from an AI: the one I passed has something to say
	var best := ""
	var best_m := -1
	var tie := false
	for pid in ev["money"]:
		var m := int(ev["money"][pid])
		if m > best_m:
			best_m = m
			best = str(pid)
			tie = false
		elif m == best_m:
			tie = true
	_leader_id = "" if tie else best
	if _alive and _leader_id == human_id and prev_leader != human_id and prev_leader != "" and int(ev.get("round", 0)) >= 3 \
			and not bool(disp.get("final", false)) and _mid_scene_ok():
		for pl in _ai_players():
			if str(pl["id"]) == prev_leader:
				await _mid_scene("lead", {"actor": pl})


## Round result board. Stages (<= ~1.2 s in total, any press / tap finishes them at once, reduced motion shows everything
## immediately): 1) venue lines "who got what and why"  2) every player's gain + new total (counted up)  3) my before -> after.
## All numbers come from engine events (MONEY_AWARDED / ROUND_ENDED); the board only animates how they appear.
func _show_round_result(ev: Dictionary) -> void:
	var order: Array = []
	for p in state["players"]:
		order.append(p["id"])
	order.sort_custom(func(a, b): return int(ev["money"][a]) > int(ev["money"][b]))
	# consistency check: what the venue lines add up to must equal the engine's per-player gain
	var sums := {}
	for pid in _round_awards:
		for a in _round_awards[pid]:
			sums[pid] = int(sums.get(pid, 0)) + int(a["amount"])
	for pid in order:
		if int(sums.get(pid, 0)) != int(ev["gained"][pid]):
			settle_mismatch += 1
			printerr("SETTLEMENT MISMATCH ", pid, " ", sums.get(pid, 0), " vs ", ev["gained"][pid])

	var fz := func(base: float) -> int: return int(round(T.fs(base * u, 1.6)))       # never below the minimum readable size
	var wrap := Control.new()            # slides up as one piece
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("120e09f8"), T.GOLD, Vector4(30, 22, 30, 24), u))
	panel.custom_minimum_size = Vector2(minf(size.x - 40.0 * u, (980.0 if landscape else 560.0) * u), 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(7 * u))
	panel.add_child(vb)
	vb.add_child(W.label("ROUND %d" % int(ev["round"]), fz.call(30), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800))
	vb.add_child(W.label("라운드 정산", fz.call(14), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
	vb.add_child(W.rule(u, 1))

	var left_vb := vb
	var right_vb := vb
	if landscape:
		# wide screens: venue lines on the left, players on the right (half the height, text can stay large)
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", int(24 * u))
		vb.add_child(cols)
		left_vb = VBoxContainer.new()
		left_vb.add_theme_constant_override("separation", int(7 * u))
		left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vb.size_flags_stretch_ratio = 1.1
		right_vb = VBoxContainer.new()
		right_vb.add_theme_constant_override("separation", int(7 * u))
		right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(left_vb)
		cols.add_child(VSeparator.new())
		cols.add_child(right_vb)
	var stages: Array = [[], [], []]
	var counters: Array = []             # {label, from, to, prefix}
	var head_row := func(parent: VBoxContainer, cols2: Array) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(10 * u))
		for spec in cols2:
			var l := W.label(str(spec[0]), fz.call(12), T.TEXT_DIM, "ui", int(spec[1]), 700)
			if float(spec[2]) > 0.0:
				l.custom_minimum_size = Vector2(float(spec[2]) * u, 0)
			else:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
		parent.add_child(h)
		parent.add_child(W.rule(u, 1))
	head_row.call(left_vb, [["술집 · 결과", HORIZONTAL_ALIGNMENT_LEFT, 0.0], ["받은 사람", HORIZONTAL_ALIGNMENT_RIGHT, 0.0]])
	# stage 1: venue lines
	for id in bar_order:
		var recips: Array = []
		var total := 0
		for pid in order:
			for a in _round_awards.get(pid, []):
				if a["bar"] == id:
					recips.append("%s %s" % [_nm(pid) + _me_tag(pid), "+" + T.money(int(a["amount"]))])
					total += int(a["amount"])
		if recips.is_empty():
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", int(10 * u))
		# venue on one line, what happened on the next: a narrow column never breaks the venue name or the reason mid-word
		var left := W.label("%s\n%s" % [T.bar_name(id), tr(str(_round_reason.get(id, "")))], fz.call(16), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.35
		left.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.add_child(left)
		var right := W.label("\n".join(recips), fz.call(16), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_RIGHT, 700)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 1.0
		right.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.add_child(right)
		left_vb.add_child(line)
		stages[0].append(line)
	if not landscape:
		var sep := HSeparator.new()
		vb.add_child(sep)
		stages[0].append(sep)
	# stage 2: players (the heading goes here, so a portrait screen - where both columns share one box - does not
	# start with two headings in a row)
	head_row.call(right_vb, [["플레이어", HORIZONTAL_ALIGNMENT_LEFT, 0.0], ["이번 라운드", HORIZONTAL_ALIGNMENT_RIGHT, 110.0], ["보유", HORIZONTAL_ALIGNMENT_RIGHT, 120.0]])
	for pid in order:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(10 * u))
		var nm := W.label(_nm(pid) + _me_tag(pid), fz.call(19), T.TEXT if not _is_me(pid) else T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nm)
		var g := int(ev["gained"][pid])
		var gl := W.label("—" if g <= 0 else "+" + T.money(g), fz.call(18), T.OK if g > 0 else T.TEXT_DIM, "money", HORIZONTAL_ALIGNMENT_RIGHT, 700)
		gl.custom_minimum_size = Vector2(110.0 * u, 0)
		hb.add_child(gl)
		var tl := W.label(T.money(int(ev["money"][pid])), fz.call(20), T.GOLD, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800)
		tl.custom_minimum_size = Vector2(120.0 * u, 0)
		hb.add_child(tl)
		right_vb.add_child(hb)
		stages[1].append(hb)
		if g > 0:
			counters.append({"label": gl, "from": 0, "to": g, "prefix": "+"})
		counters.append({"label": tl, "from": int(ev["money"][pid]) - g, "to": int(ev["money"][pid]), "prefix": ""})
	# stage 3: my own round in one sentence, then before -> after
	right_vb.add_child(W.rule(u, 2))
	var note := _my_round_note(ev)
	if note != "":
		var nl := W.label(note, fz.call(16), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD      # WORD_SMART breaks Korean inside a word ("단독 도/박꾼")
		nl.custom_minimum_size = Vector2(minf(560.0 * u, panel.custom_minimum_size.x - 40.0 * u), 0)
		right_vb.add_child(nl)
		stages[2].append(nl)
	for pid in order:
		if _is_me(pid):
			var g2 := int(ev["gained"][pid])
			var ml := W.label((tr("내 잔액  %s → %s") % [T.money(int(ev["money"][pid]) - g2), T.money(int(ev["money"][pid]))]) if g2 > 0 else (tr("내 잔액  %s (변동 없음)") % T.money(int(ev["money"][pid]))), fz.call(20), T.GOLD if g2 > 0 else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800)
			right_vb.add_child(ml)
			stages[2].append(ml)
	var RelicManager = preload("res://engine/relic_manager.gd")
	var is_relic: bool = RelicManager.is_relic_mode(state) and not bool(ev.get("finalRound", false))
	var btn_txt := "FINAL RESULT" if ev["finalRound"] else (tr("BLACK MARKET 암시장 방문 ▸") if is_relic else "NEXT ROUND")
	var btn := W.button(btn_txt, "primary", fz.call(22), Vector2((280.0 if is_relic else 240.0) * u, 52.0 * u))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(btn)

	dim.visible = true
	modal_layer.add_child(wrap)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	await get_tree().process_frame
	if is_instance_valid(panel):
		var avail_h := size.y - 24.0 * u
		var kf := minf(1.0, avail_h / maxf(1.0, panel.size.y))
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(kf, kf)       # 8 players + many venues: shrink the board rather than clip it
	result_board_shown.emit()
	Audio.reading(true)
	if bot.is_valid():
		btn.grab_focus()
	else:
		# A stray Enter (the player is still tapping it after the card) must not dismiss the board the instant it appears:
		# for a short moment only a mouse / touch press can hit the button, then it takes keyboard focus as before.
		W.arm_focus(btn, 0.6)

	var instant := skip or Settings.reduce_motion or bot.is_valid()
	var all_nodes: Array = []
	for st in stages:
		all_nodes.append_array(st)
	var tw: Tween = null
	if instant:
		# no motion: every number is on screen right away (the bot only waits a few frames so tests can photograph it)
		pass
	else:
		for n in all_nodes:
			n.modulate.a = 0.0
		wrap.position.y = 48.0 * u
		wrap.modulate.a = 0.0
		tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(wrap, "position:y", 0.0, Settings.dur(0.25)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(wrap, "modulate:a", 1.0, Settings.dur(0.2))
		# stage timing: ~1.2 s overall at NORMAL (x Settings.dur: FAST/SLOW scale it; reduced motion never gets here)
		var t0 := Settings.dur(0.25)
		var per := Settings.dur(minf(0.12, 0.9 / maxf(1.0, float(all_nodes.size()))))
		for n in all_nodes:
			tw.tween_property(n, "modulate:a", 1.0, Settings.dur(0.14)).set_delay(t0)
			t0 += per
		for c in counters:
			var cl: Label = c["label"]
			var d: float = Settings.dur(0.25) + per * float(stages[0].size())
			tw.tween_method(func(v: float): cl.text = c["prefix"] + T.money(int(round(v))), float(c["from"]), float(c["to"]), Settings.dur(0.45)).set_delay(d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			cl.text = c["prefix"] + T.money(int(c["from"]))
	var finish := func():
		if tw != null and tw.is_valid():
			tw.kill()
		wrap.position.y = 0.0
		wrap.modulate.a = 1.0
		for n in all_nodes:
			n.modulate.a = 1.0
		for c in counters:
			c["label"].text = c["prefix"] + T.money(int(c["to"]))      # always lands on the engine's number
	panel.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			if tw != null and tw.is_valid() and tw.is_running():
				finish.call())
	if bot.is_valid():
		for _i in range(4):
			await get_tree().process_frame
	else:
		# 1st press / tap while the board is still appearing completes it; the next press moves on
		var done := false
		while not done:
			await btn.pressed
			if tw != null and tw.is_valid() and tw.is_running():
				finish.call()
			else:
				done = true
	finish.call()
	Audio.reading(false)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.queue_free()
	dim.visible = false


func _open_black_market(_ev: Dictionary) -> void:
	if not _alive:
		return
	var BlackMarketPanel = preload("res://ui/board/black_market_panel.gd")
	var shop = BlackMarketPanel.new()
	shop.setup(state, human_id, u, landscape)
	dim.visible = true
	modal_layer.add_child(shop)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	Audio.play("menu")
	await shop.closed
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop.queue_free()
	dim.visible = false
	_update_hud()
	_update_relic_tray()


func _ev_game_ended(ev: Dictionary) -> void:
	Audio.intensity(0)
	Audio.cue("menu")                 # the final round's drive settles into the slow theme under the results
	_coach_hide()
	if Settings.coach_on and human_id != "" and not bot.is_valid():
		Settings.coach_on = false              # one guided game is enough; the menu can switch it back on
		Settings.save_settings()
	Audio.play("win" if human_id in ev["winnerIds"] else "game_end")
	await _play_scene("end", {"winnerIds": ev["winnerIds"]})
	new_achievements = []
	if autosave_enabled:                  # tests and the bot do not write to the player's records
		new_achievements = Records.record_game(state, human_id)["new"]
	_set_felt("end")
	_now("GAME OVER")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("120e09f8"), T.GOLD, Vector4(32, 24, 32, 26), u))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(minf(size.x - 40.0 * u, 520.0 * u), 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	panel.add_child(vb)
	var winners: Array = ev["winnerIds"]
	var headline := "SHARED WIN" if winners.size() > 1 else (_nm(winners[0]).to_upper() + " WINS")
	if winners.size() == 1 and _is_me(winners[0]):
		headline = "YOU WIN!"
	vb.add_child(W.label(headline, int(40 * u), T.GOLD, "stamp", HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(W.label(tr("%d라운드 · 최종 정산") % int(state["round"]), int(15 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
	vb.add_child(W.rule(u, 1))
	var rank := 1
	for r in ev["ranking"]:
		var is_first: bool = rank == 1
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(12 * u))
		var rl := W.label("%d" % rank, int(24 * u if is_first else 20 * u), T.GOLD if is_first else T.TEXT_DIM, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
		rl.custom_minimum_size = Vector2(32.0 * u, 0)
		hb.add_child(rl)
		var nm := W.label(_nm(r["playerId"]) + _me_tag(r["playerId"]), int(22 * u if is_first else 19 * u), T.GOLD if is_first else T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800 if is_first else 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nm)
		hb.add_child(W.label(T.money(int(r["money"])), int(24 * u if is_first else 20 * u), T.GOLD if is_first else T.TEXT, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800))
		vb.add_child(hb)
		if is_first and ev["ranking"].size() > 1:
			vb.add_child(W.rule(u, 1))      # the winner's line is set apart, the rest is the field
		rank += 1
	vb.add_child(W.rule(u, 2))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", int(14 * u))
	var sum_btn := W.button("게임 요약 보기", "secondary", int(18 * u), Vector2(0, 46.0 * u))
	sum_btn.add_theme_font_override("font", T.font("ui", 800))
	sum_btn.name = "SummaryButton"
	vb.add_child(sum_btn)
	sum_btn.pressed.connect(func():
		var ss := SummaryScreen.new()
		ss.setup(state, human_id)
		add_child(ss))
	if not new_achievements.is_empty():
		var ach := VBoxContainer.new()
		ach.add_theme_constant_override("separation", 2)
		ach.add_child(W.label("★ 새 업적 달성!", int(18 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 800))
		for id in new_achievements:
			ach.add_child(W.label("%s — %s" % [tr(Records.ACHIEVEMENTS[id][0]), tr(Records.ACHIEVEMENTS[id][1])], int(14 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600))
		vb.add_child(ach)
	var again := W.button("NEW GAME", "primary", int(20 * u), Vector2(190.0 * u, 52.0 * u))
	var menu := W.button("MENU", "secondary", int(20 * u), Vector2(150.0 * u, 52.0 * u))
	btns.add_child(again)
	btns.add_child(menu)
	vb.add_child(btns)
	again.pressed.connect(func(): new_game_requested.emit())
	menu.pressed.connect(func(): exit_requested.emit())
	dim.visible = true
	Audio.play("panel_open")
	if not new_achievements.is_empty():
		get_tree().create_timer(1.2, true, false, true).timeout.connect(func(): Audio.play("achieve"))
	modal_layer.add_child(panel)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	SaveStore.clear()
	W.arm_focus(again, 0.6)
