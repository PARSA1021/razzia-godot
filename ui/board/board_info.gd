extends "res://ui/board/board_layout.gd"
## Board info: what the board has shown about the cards (venue card, play history) and rebuilding the screen on Continue.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


## ===================================================================== resume

## Money cards per venue from the event log (display only; the engine never needs this number).
func _money_card_counts_from_log() -> Dictionary:
	var count := {}
	var money := {}
	for ev in state["events"]:
		match ev["type"]:
			"MONEY_PLACED":
				var id: String = ev["barId"]
				count[id] = int(count.get(id, 0)) + 1
				money[id] = int(money.get(id, 0)) + int(ev["value"])
			"MONEY_AWARDED":
				var id2: String = ev["barId"]
				money[id2] = int(money.get(id2, 0)) - int(ev["amount"])
				if int(money[id2]) <= 0:
					count[id2] = 0
	return count


## Continue: put this round's gold "extra money" tag back where the log says the dealer placed it (unless already paid out).
func _restore_extra_tag() -> void:
	var evs: Array = state["events"]
	var start := 0
	for i in range(evs.size()):
		if str(evs[i]["type"]) == "ROUND_STARTED":
			start = i
	var found := {}
	for i in range(start, evs.size()):
		var e: Dictionary = evs[i]
		if str(e["type"]) == "MONEY_PLACED" and bool(e.get("extra", false)):
			found = e
		elif str(e["type"]) == "MONEY_AWARDED" and not found.is_empty() and str(e["barId"]) == str(found["barId"]):
			found = {}
	if found.is_empty() or not bar_views.has(str(found["barId"])):
		return
	var id := str(found["barId"])
	if int(disp["bar_money"].get(id, 0)) <= 0:
		return
	var dealer := str(state["croupierId"])
	bar_views[id].set_extra(int(found["value"]), "나" if dealer == human_id else _nm(dealer))


func _rebuild_from_state() -> void:
	disp["round"] = state["round"]
	disp["croupier"] = state["croupierId"]
	disp["final"] = state["finalRound"]
	if disp["final"]:
		Audio.intensity(1)                # Continue into the last round: its music, not the normal table's
	var in_deck: int = state["moneyDeck"].size()
	disp["deck"] = in_deck
	var piles := _money_card_counts_from_log()
	for b in state["bars"]:
		if b["active"]:
			disp["bar_money"][b["id"]] = b["money"]
			# number of money cards lying on the venue: replayed from the engine's own event log (same rule as the live
			# display: +1 per MONEY_PLACED, back to 0 when the venue is emptied); old logs without it fall back to an estimate
			var n: int = int(piles.get(b["id"], 0))
			if int(b["money"]) == 0:
				n = 0
			elif n == 0:
				n = maxi(1, int(ceil(float(b["money"]) / 20000.0)))
			disp["bar_cards"][b["id"]] = n
			var bv: BarView = bar_views[b["id"]]
			bv.money_cards = disp["bar_cards"][b["id"]]
			bv.set_money(int(b["money"]), 0.0)
	for p in state["players"]:
		_set_player_money(p["id"], int(p["money"]), 0.0)
		disp["ready"][p["id"]] = p["selectedCardId"] != null
		if p["selectedCardId"] != null:
			_add_strip_back(p["id"], false)
	_set_hand(Eng.get_public_view(state, human_id)["hand"], false)
	_restore_extra_tag()
	_update_hud()
	_now_live(func(): return tr("이어하기 — Round %d") % int(state["round"]))


func _track_cards(ev: Dictionary) -> void:
	match str(ev["type"]):
		"CARDS_REVEALED":
			_shown_table = []
			for pc in ev.get("cards", []):
				_shown_table.append(str(pc["cardId"]))
			_record_plays(ev)
		"ROUND_ENDED", "ROUND_STARTED":
			for cid in _shown_table:
				_shown_discard[cid] = true
			_shown_table = []
		"DECK_RECYCLED":
			_shown_discard.clear()       # every card that came out goes back into the deck: it can be drawn again
			_reshuffles += 1


## The cards I am holding as the board shows them (my chosen card counts as mine until it is revealed).
func _my_shown_cards() -> Array:
	var out := []
	for v in hand_views:
		if is_instance_valid(v) and not v.card.is_empty():
			out.append(str(v.card["id"]))
	if my_selected_id != "" and not (my_selected_id in out) and not (my_selected_id in _shown_table) and not _shown_discard.has(my_selected_id):
		out.append(my_selected_id)
	return out


## Venue census: every card of this venue in the game falls in exactly one box -
##   out  : already revealed (this round's table + the discard pile since the last reshuffle)
##   mine : in my hand (or my chosen card, not yet revealed)
##   left : not seen - in the deck or another player's hand (I cannot know which)
## so total == out + mine + left always holds.
func _venue_census(bar_id: String) -> Dictionary:
	var out := {"total_z": 0, "total_r": 0, "out_z": 0, "out_r": 0, "zocker_left": 0, "razzia_left": 0, "top_symbol": 0,
		"left_z_syms": [], "left_r_syms": [], "my_zocker": [], "my_razzia": [], "seen_zocker": 0, "seen_razzia": 0}
	if state.is_empty() or not state.has("cards"):
		return out
	var mine := {}
	for cid in _my_shown_cards():
		mine[cid] = true
	for cid in state["cards"]:
		var c: Dictionary = state["cards"][cid]
		if str(c["barId"]) != bar_id:
			continue
		var z: bool = str(c["type"]) == "ZOCKER"
		var sym := int(c["dieSymbol"])
		out["total_z" if z else "total_r"] += 1
		if _shown_discard.has(cid) or cid in _shown_table:
			out["out_z" if z else "out_r"] += 1
		elif mine.has(cid):
			out["my_zocker" if z else "my_razzia"].append(sym)
		else:
			out["zocker_left" if z else "razzia_left"] += 1
			out["left_z_syms" if z else "left_r_syms"].append(sym)
			if z:
				out["top_symbol"] = maxi(out["top_symbol"], sym)
	out["seen_zocker"] = int(out["out_z"]) + out["my_zocker"].size()
	out["seen_razzia"] = int(out["out_r"]) + out["my_razzia"].size()
	for k in ["my_zocker", "my_razzia", "left_z_syms", "left_r_syms"]:
		out[k].sort()
	return out


func _record_plays(ev: Dictionary) -> void:
	for pc in ev.get("cards", []):
		var pid: String = str(pc["playerId"])
		if not _seen_plays.has(pid):
			_seen_plays[pid] = []
		_seen_plays[pid].append({"bar": str(pc["barId"]), "type": str(pc["type"]), "symbol": int(pc["dieSymbol"])})


## Venue card: how many of this venue's cards each player has shown so far (never what they hold).
func _venue_history(bar_id: String) -> Array:
	var out := []
	for p in state["players"]:
		var pid: String = str(p["id"])
		var z := 0
		var r := 0
		for rec in _seen_plays.get(pid, []):
			if rec["bar"] == bar_id:
				if rec["type"] == "ZOCKER":
					z += 1
				else:
					r += 1
		if z + r > 0:
			out.append({"name": _nm(pid), "me": pid == human_id, "zocker": z, "razzia": r})
	return out


func _on_bar_info(bar_id: String) -> void:
	if _overlay_open() or _awaiting_bar:
		return
	Audio.play("click")
	_show_bar_info(bar_id)


func _show_bar_info(bar_id: String) -> void:
	if modal_layer.has_node("BarInfo"):
		modal_layer.get_node("BarInfo").queue_free()
	var cen := _venue_census(bar_id)
	var panel := PanelContainer.new()
	panel.name = "BarInfo"
	panel.add_theme_stylebox_override("panel", W.deco(Color("120e09f8"), T.bar_color(bar_id), Vector4(26, 18, 26, 20), u))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", int(10 * u))
	panel.add_child(outer)
	# --- header: venue + money on it now (+ this round's extra card, if it went here)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(18 * u))
	var hn := W.label(T.bar_name(bar_id), int(24 * u), T.bar_color(bar_id), "title", HORIZONTAL_ALIGNMENT_LEFT, 800)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	head.add_child(W.label(T.money(int(disp["bar_money"].get(bar_id, 0))), int(24 * u), T.GOLD, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800))
	outer.add_child(head)
	var bv: BarView = bar_views[bar_id]
	if bv.extra_amount > 0:
		outer.add_child(W.label(tr("이번 라운드: 딜러 %s가 추가 머니카드 +%s를 여기에 놓았습니다") % [tr(bv.extra_by), T.money(bv.extra_amount)], int(15 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700))
	# Phase 29: never scrolled. On a short screen the card's body is scaled to fit as one piece (FitBox)
	var fit := W.FitBox.new()
	fit.min_scale = 0.6
	outer.add_child(fit)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	fit.add_child(vb)
	var total := int(cen["total_z"]) + int(cen["total_r"])
	vb.add_child(W.label(tr("이 술집 카드는 게임 전체에 %d장 — 각 카드는 아래 칸 중 한 곳에만 셉니다") % total, int(14 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
	# --- the count table: total = out + mine + left, row by row
	var grid := GridContainer.new()
	grid.name = "CountTable"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(6 * u))
	grid.add_theme_constant_override("v_separation", int(6 * u))
	var heads := ["", "전체", "이미 나옴", "내 손", "남은 카드"]
	for h in heads:
		var hl := W.label(h, int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
		hl.custom_minimum_size = Vector2((86.0 if h != "" else 64.0) * u, 0)
		grid.add_child(hl)
	var rows := [
		["도박꾼", T.GOLD, int(cen["total_z"]), int(cen["out_z"]), cen["my_zocker"].size(), int(cen["zocker_left"])],
		["경찰", T.POLICE_BLUE, int(cen["total_r"]), int(cen["out_r"]), cen["my_razzia"].size(), int(cen["razzia_left"])],
	]
	for r in rows:
		grid.add_child(W.label(str(r[0]), int(17 * u), r[1], "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
		for ci in range(4):
			var v: int = int(r[2 + ci])
			var cell := PanelContainer.new()
			var last := ci == 3
			cell.add_theme_stylebox_override("panel", W.sb(Color(r[1], 0.16) if last else Color("1d1710"), Color(r[1], 0.85) if last else Color(T.BRASS, 0.35), 2 if last else 1, 8, Vector4(8, 3, 8, 3)))
			var vl := W.label(tr("%d 장") % v, int((22 if last else 18) * u), r[1] if last else T.TEXT, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
			cell.add_child(vl)
			grid.add_child(cell)
	vb.add_child(grid)
	vb.add_child(W.label("남은 카드 = 아직 공개되지 않은 카드. 덱이나 다른 사람 손에 있습니다 (어느 쪽인지는 알 수 없음)", int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
	vb.add_child(W.rule(u, 1))
	# --- the eyes still out there (public deduction: printed set minus what has been shown)
	var zs: Array = cen["left_z_syms"]
	if zs.is_empty():
		vb.add_child(W.label("이 술집의 도박꾼 카드는 모두 나왔거나 내 손에 있습니다", int(16 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700))
	else:
		var zrow := HBoxContainer.new()
		zrow.add_theme_constant_override("separation", int(6 * u))
		var zl := W.label("남은 도박꾼 눈", int(16 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
		zl.custom_minimum_size = Vector2(128.0 * u, 0)
		zrow.add_child(zl)
		for sym in zs:
			var chip := PanelContainer.new()
			var top: bool = int(sym) == int(cen["top_symbol"])
			chip.add_theme_stylebox_override("panel", W.sb(Color("f3ead6") if top else Color("2a2218"), T.GOLD if top else Color(T.BRASS, 0.6), 2 if top else 1, 6, Vector4(7, 1, 7, 1)))
			chip.add_child(W.label(str(sym), int(17 * u), Color("1a120e") if top else T.TEXT, "money", HORIZONTAL_ALIGNMENT_CENTER, 800))
			zrow.add_child(chip)
		vb.add_child(zrow)
		vb.add_child(W.label(tr("밝게 표시한 %d — 아직 안 나온 이 술집 도박꾼 중 가장 높은 눈") % int(cen["top_symbol"]), int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
	# --- my hand for this venue
	var mine: Array = cen["my_zocker"]
	var mine_r: Array = cen["my_razzia"]
	var mine_txt := tr("내 손: ")
	if mine.is_empty() and mine_r.is_empty():
		mine_txt += tr("이 술집 카드 없음")
	else:
		var parts := []
		if not mine.is_empty():
			parts.append(tr("도박꾼 %d장 (눈 %s)") % [mine.size(), ", ".join(mine.map(func(v): return str(v)))])
		if not mine_r.is_empty():
			parts.append(tr("경찰 %d장") % mine_r.size())
		mine_txt += " · ".join(parts)
	vb.add_child(W.label(mine_txt, int(16 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700))
	if _reshuffles > 0:
		var rl := W.label(tr("덱을 %d번 다시 섞었습니다. 섞을 때 버린 카드가 덱으로 돌아가므로, 그 전에 나온 카드도 다시 '남은 카드'로 셉니다.") % _reshuffles, int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD
		rl.custom_minimum_size = Vector2(440.0 * u, 0)
		vb.add_child(rl)
	# --- public history: who has shown what here (whole game)
	var hist := _venue_history(bar_id)
	vb.add_child(W.rule(u, 1))
	if hist.is_empty():
		vb.add_child(W.label("이번 게임에서 아직 아무도 이 술집 카드를 내지 않았습니다", int(14 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
	else:
		vb.add_child(W.label("이번 게임에서 이 술집에 낸 카드 (공개된 것)", int(14 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
		for h in hist:
			var bits := []
			if int(h["zocker"]) > 0:
				bits.append(tr("도박꾼 %d장") % int(h["zocker"]))
			if int(h["razzia"]) > 0:
				bits.append(tr("경찰 %d장") % int(h["razzia"]))
			vb.add_child(W.label("%s%s — %s" % [(tr("나") if str(h["name"]) == "나" else str(h["name"])), tr(" (나)") if bool(h["me"]) and str(h["name"]) != "나" else "", " · ".join(bits)], int(15 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600))
	var close := W.button("닫기", "primary", int(18 * u), Vector2(150.0 * u, 44.0 * u))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(close)
	modal_layer.add_child(panel)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	close.pressed.connect(func():
		panel.queue_free()
		modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	# as tall as its content, but never taller than the screen allows (then scaled, not scrolled)
	var other_h: float = outer.get_combined_minimum_size().y - fit.get_combined_minimum_size().y
	var avail: float = get_viewport_rect().size.y * 0.92 - other_h - 50.0 * u
	fit.set_max(Vector2(get_viewport_rect().size.x * 0.94, maxf(140.0 * u, avail)))
	W.arm_focus(close, 0.3)
