extends "res://ui/board/board_scenes.gd"
## Board fx: money cards (regular and the dealer's extra card), cards flying to the table, the RAZZIA shot.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


func _ev_money_placed(ev: Dictionary) -> void:
	var id: String = ev["barId"]
	var amount := int(ev["value"])
	disp["deck"] = int(disp["deck"]) - 1
	var before := int(disp["bar_money"][id])
	if not ev["extra"]:
		# the regular cards: one per venue, face down from the deck. Each venue shows how much it just got.
		Audio.play("coin")
		if _dealt_note_round != int(disp["round"]):
			_dealt_note_round = int(disp["round"])
			_now("머니카드 분배 — 술집마다 1장씩")
		disp["bar_cards"][id] = int(disp["bar_cards"][id]) + 1
		_set_bar_money(id, before + amount, 0.35)
		bar_views[id].pulse(Settings.dur(0.55))
		_fly_money_card(id)
		if not skip:
			_float_text("+" + T.money(amount), bar_views[id].global_center() - Vector2(0, 20.0 * u), Color("e9dcc0"), 0.72)
		await _wait(0.10)          # stagger between money cards
		return
	# The dealer's extra card: who holds it, how much it is, and which venue it goes to — shown as a real card that
	# travels from the dealer to the venue, then stays there as a gold tag for the rest of the round.
	var dealer: String = str(disp["croupier"])
	var after := before + amount
	last_extra = {"barId": id, "before": before, "amount": amount, "after": after, "by": dealer}
	var who := tr("나") if dealer == human_id else _nm(dealer)
	_now_live(func(): return tr("%s(딜러)의 추가 머니카드 %s → %s") % [tr("나") if dealer == human_id else _nm(dealer), T.money(amount), T.bar_name(id)])
	await _extra_card_flight(id, amount, dealer)
	if not _alive:
		return
	Audio.play("coin")
	disp["bar_cards"][id] = int(disp["bar_cards"][id]) + 1
	_set_bar_money(id, after, 0.45)
	bar_views[id].set_extra(amount, "나" if dealer == human_id else _nm(dealer))   # the tag translates "나" itself (live language switch)
	bar_views[id].pulse(Settings.dur(0.8))
	if not skip:
		_float_text("+" + T.money(amount), bar_views[id].global_center(), T.GOLD)
	_now_live(func(): return tr("%s(딜러) → %s에 추가 +%s  ·  %s → %s") % [tr("나") if dealer == human_id else _nm(dealer), T.bar_name(id), T.money(amount), T.money(before), T.money(after)])
	if dealer != human_id:
		_coach("extra_ai", "딜러의 추가 머니카드", "라운드마다 딜러가 머니카드 한 장을 원하는 술집에 더 놓습니다. 금색 표시가 이번 라운드에 추가된 곳이에요.")
	await _wait(0.9)


## The extra card itself: pops up at the dealer (or is already in the human dealer's hand), then flies onto the venue's tag.
func _extra_card_flight(id: String, amount: int, dealer: String) -> void:
	var held := _extra_held
	_extra_held = null
	if skip or Settings.reduce_motion or not is_inside_tree() or not bar_views.has(id):
		if held != null and is_instance_valid(held):
			held.queue_free()
		return
	var csz := Vector2(92.0, 122.0) * u
	var cv: Control = held
	var tw: Tween
	if cv == null or not is_instance_valid(cv):
		cv = MoneyCard.new()
		cv.amount = amount
		cv.caption = "추가 머니카드"
		fx_layer.add_child(cv)
		cv.size = csz
		cv.position = _extra_card_spot(dealer, csz) - fx_layer.global_position
		cv.pivot_offset = csz / 2.0
		cv.scale = Vector2(0.55, 0.55)
		cv.modulate.a = 0.0
		Audio.play("take")
		tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(cv, "scale", Vector2.ONE, Settings.dur(0.28) + 0.001).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "modulate:a", 1.0, Settings.dur(0.18) + 0.001)
		tw.tween_property(cv, "glow", 1.0, Settings.dur(0.3) + 0.001)
		tw.chain().tween_interval(Settings.dur(0.55))
		await _run_tween(tw)
	var bv: BarView = bar_views[id]
	var tag: Rect2 = bv.extra_tag_rect()
	var xf := bv.get_global_transform_with_canvas()
	var target: Vector2 = xf * tag.get_center() - fx_layer.global_position
	var to_scale := clampf((tag.size.x * xf.get_scale().x) / maxf(1.0, cv.size.x), 0.35, 1.0)
	cv.pivot_offset = cv.size / 2.0
	bv.highlight = true
	bv.z_index = 2
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "position", target - cv.size / 2.0, Settings.dur(0.55) + 0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cv, "scale", Vector2(to_scale, to_scale), Settings.dur(0.55) + 0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cv, "rotation", 0.0, Settings.dur(0.4) + 0.001)
	tw.chain().tween_property(cv, "modulate:a", 0.0, Settings.dur(0.14) + 0.001)
	await _run_tween(tw)
	bv.highlight = false
	bv.z_index = 0
	if is_instance_valid(cv):
		cv.queue_free()


## Where the extra card appears: beside the dealer's chip (inside the screen).
func _extra_card_spot(dealer: String, csz: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var p := vp / 2.0 - csz / 2.0
	if chips.has(dealer) and is_instance_valid(chips[dealer]) and chips[dealer].is_visible_in_tree():
		var r: Rect2 = chips[dealer].get_global_rect()
		p = Vector2(r.end.x + 14.0 * u, r.get_center().y - csz.y / 2.0)
		if p.x + csz.x > vp.x - 8.0:
			p.x = r.position.x - csz.x - 14.0 * u
	p.x = clampf(p.x, 8.0, maxf(8.0, vp.x - csz.x - 8.0))
	p.y = clampf(p.y, 8.0, maxf(8.0, vp.y - csz.y - 8.0))
	return p


func _show_held_extra(amount: int) -> void:
	_drop_held_extra()
	var cv := MoneyCard.new()
	cv.amount = amount
	cv.caption = "내 추가 머니카드"
	fx_layer.add_child(cv)
	var csz := Vector2(92.0, 122.0) * u
	cv.size = csz
	var gp := _extra_card_spot(human_id, csz)
	if confirm_btn != null and confirm_btn.is_visible_in_tree():
		var br := confirm_btn.get_global_rect()
		gp = Vector2(br.get_center().x - csz.x / 2.0, br.position.y - csz.y - 14.0 * u)
		var vp := get_viewport_rect().size
		gp.x = clampf(gp.x, 8.0, vp.x - csz.x - 8.0)
		gp.y = clampf(gp.y, 8.0, vp.y - csz.y - 8.0)
	cv.position = gp - fx_layer.global_position
	cv.pivot_offset = csz / 2.0
	cv.glow = 1.0
	_extra_held = cv
	if not Settings.reduce_motion:
		cv.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.tween_property(cv, "scale", Vector2.ONE, Settings.dur(0.25) + 0.001).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drop_held_extra() -> void:
	if _extra_held != null and is_instance_valid(_extra_held):
		_extra_held.queue_free()
	_extra_held = null


## Where money cards leave the deck: the pile (landscape) or the deck stat (portrait), in this node's local coordinates.
func _deck_anchor() -> Vector2:
	var c: Control = pile if pile.visible else stat_deck
	return c.position + c.size / 2.0


## A face-down money card flies from the deck to the venue it is placed on (matches the MONEY_PLACED event).
func _fly_money_card(id: String) -> void:
	if skip or Settings.reduce_motion or not is_inside_tree() or not bar_views.has(id):
		return
	var cv := CardView.new()
	cv.card = {}
	cv.face_up = false
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(cv)
	var sz := Vector2(44.0, 60.0) * u
	cv.size = sz
	var from := _deck_anchor() - sz / 2.0
	var to: Vector2 = bar_views[id].global_center() - fx_layer.global_position - sz / 2.0
	cv.position = from
	cv.rotation = -0.25
	var dur := Settings.dur(0.32) + 0.001
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "position", to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", 0.0, dur)
	tw.tween_property(cv, "modulate:a", 0.0, Settings.dur(0.12) + 0.001).set_delay(dur * 0.85)
	_money_flying += 1
	tw.chain().tween_callback(func():
		_money_flying -= 1
		cv.queue_free())


func _add_strip_back(pid: String, animate: bool) -> void:
	var cv := CardView.new()
	cv.card = {}
	cv.face_up = false
	cv.caption = "" if compact else _nm(pid)      # phone layout: the card sits beside the player's own chip
	_add_below_overlays(cv)
	strip_views[pid] = cv
	cv.size = _strip_metrics["card"]
	cv.position = strip_slot_pos(pid)
	if animate:
		cv.scale = Vector2(0.4, 0.4)
		cv.modulate.a = 0.0
		var tw := _tween()
		tw.set_parallel(true)
		tw.tween_property(cv, "scale", Vector2.ONE, Settings.dur(0.25) + 0.001).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "modulate:a", 1.0, Settings.dur(0.2) + 0.001)


func _make_strip_card_late(pid: String) -> Control:
	_add_strip_back(pid, false)
	return strip_views[pid]


func _ev_razzia(ev: Dictionary) -> void:
	var id: String = ev["barId"]
	bar_views[id].highlight = true
	bar_views[id].z_index = 41            # the raided venue stays lit above the wash
	_set_felt("razzia")
	_now_live(func(): return tr("RAZZIA · %s — 도박꾼은 쫓겨납니다") % T.bar_name(id))
	_coach("razzia", "단속", "경찰 카드가 나오면 그 술집의 도박꾼은 모두 쫓겨나고, 경찰 카드를 낸 사람들이 그 돈을 나눠 갖습니다.", true)
	await _fx_razzia(ev)
	for pid in ev["shutOut"]:
		if _is_me(pid):
			Audio.play("denied")
		var tc = table_cards.get(pid)
		if tc != null and is_instance_valid(tc["mini"]):
			tc["mini"].out_mark = true
			tc["mini"].dimmed = true
			if not skip and not Settings.reduce_motion:
				# the gambler is thrown out: the card jolts and is left askew
				var m: Control = tc["mini"]
				m.pivot_offset = m.size / 2.0
				var jt := create_tween()
				jt.tween_property(m, "rotation", deg_to_rad(-9.0), 0.06)
				jt.tween_property(m, "rotation", deg_to_rad(6.0), 0.07)
				jt.tween_property(m, "rotation", deg_to_rad(-4.0), 0.08)
	await _wait(0.7)
	if _coach_panel != null:
		await _wait(2.2)                 # the raid tip is not a prompt: it reads, then goes
		_coach_hide()
	# a big raid between me and an AI gets a line from the AI involved
	var pot := int(ev.get("money", 0))
	if pot >= 40000 and _mid_scene_ok():
		var me_police: bool = human_id in ev["razzias"]
		var me_out: bool = human_id in ev["shutOut"]
		var actor := {}
		for pl in _ai_players():
			if me_police and str(pl["id"]) in ev["shutOut"] and actor.is_empty():
				actor = pl
			elif me_out and str(pl["id"]) in ev["razzias"] and actor.is_empty():
				actor = pl
		if not actor.is_empty():
			await _mid_scene("raid", {"actor": actor, "me_raided_them": me_police, "ctx": {"bar": T.bar_name(id), "pot": T.money(pot)}})


## RAZZIA shot (Phase 26, ui/raid_fx.gd): dark street, red + blue searchlights settling on the venue, the police card
## slamming down (the table jolts), the rubber stamp and one line on what the raid means. Timing contract unchanged:
## NORMAL ~2.25 s, one red and one blue swell that never strobe (their length is fixed at every speed), SKIP ends it at once,
## nothing (layer, tween, shake offset) is left behind.
func _fx_razzia(ev: Dictionary = {}) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(layer)
	var d := Settings.dur(1.0)           # 0 under reduced motion, else the speed factor (FAST 0.5, NORMAL 1, SLOW 1.6)
	if d <= 0.0 or skip:
		layer.queue_free()
		return
	layer.z_index = 13              # 30 + 13: above the raided venue (lit at 41) so the police card lands on it
	var fx := RaidFX.new()
	fx.u = u
	var bid := str(ev.get("barId", ""))
	if bar_views.has(bid):
		var gr: Rect2 = bar_views[bid].get_global_rect()
		fx.target = Rect2(gr.position - layer.global_position, Vector2(gr.size.x, bar_views[bid].venue_h if bar_views[bid].mode == "card" else gr.size.y))
		fx.venue = T.bar_name(bid)
	if not ev.is_empty():
		fx.caption = _raid_caption(ev)
	layer.add_child(fx)
	var siren_end := 0.18 + 0.12 * 4.0
	Audio.siren_start()
	var stamp_at := maxf(Settings.dur(0.72), siren_end)
	var tws: Array = []
	var tw := create_tween().set_parallel(true)
	tws.append(tw)
	tw.tween_property(fx, "dark", 1.0, Settings.dur(0.18))
	tw.tween_property(fx, "beams", 1.0, siren_end).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# one red swell, then one blue swell (fixed length at every speed: never a flicker)
	tw.tween_property(fx, "red", 1.0, 0.12).set_delay(0.18)
	tw.tween_property(fx, "red", 0.25, 0.12).set_delay(0.30)
	tw.tween_property(fx, "blue", 1.0, 0.12).set_delay(0.42)
	tw.tween_property(fx, "blue", 0.25, 0.12).set_delay(0.54)
	tw.tween_property(fx, "card", 1.0, Settings.dur(0.2)).set_delay(maxf(Settings.dur(0.45), 0.42)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fx, "stamp", 1.0, Settings.dur(0.22)).set_delay(stamp_at)
	tw.tween_property(fx, "ink", 1.0, Settings.dur(0.45)).set_delay(stamp_at + Settings.dur(0.18))
	tw.tween_callback(func(): Audio.play("stamp")).set_delay(stamp_at)
	# the table jolts when the stamp hits (a few pixels, settles in ~0.2 s)
	var base_pos := position
	if not Settings.reduce_motion:
		var shake := create_tween()
		tws.append(shake)
		shake.tween_interval(stamp_at + Settings.dur(0.12))
		for off in [Vector2(0, 7), Vector2(-5, -4), Vector2(3, 2), Vector2.ZERO]:
			shake.tween_property(self, "position", base_pos + off * u, 0.05)
	var hold := get_tree().create_timer(maxf(Settings.dur(2.0), stamp_at + Settings.dur(0.22) + 0.5))
	while hold.time_left > 0.0 and not skip and _alive:           # SKIP never has to wait for it
		await get_tree().process_frame
	var cut := skip
	Audio.siren_stop(0.05 if cut else 0.3)
	for t in tws:
		if t.is_valid():
			t.kill()
	position = base_pos
	if not _alive or not is_instance_valid(layer):
		Audio.siren_stop(0.0)
		return
	if not cut:
		var tw3 := create_tween()
		tw3.tween_property(layer, "modulate:a", 0.0, Settings.dur(0.25))
		while tw3.is_valid() and tw3.is_running() and not skip and _alive:
			await get_tree().process_frame
		if tw3.is_valid():
			tw3.kill()
	if is_instance_valid(layer):
		layer.queue_free()           # also covers SKIP during the fade: no light, card or stamp is left behind


## What this raid means, in one line (public: the cards are face up now)
func _raid_caption(ev: Dictionary) -> String:
	var outs: Array = ev.get("shutOut", [])
	var cops: Array = ev.get("razzias", [])
	var line := tr("도박꾼 %d명 퇴장  ·  판돈 %s → 경찰 %d명") % [outs.size(), T.money(int(ev.get("money", 0))), cops.size()]
	if human_id in outs:
		line = tr("🚨 [경찰 단속] 내 도박꾼이 쫓겨났습니다!") + "  ·  " + line
	elif human_id in cops:
		line = tr("🚨 [나의 경찰 단속 성공!] 도박꾼 일망타진!") + "  ·  " + line
	return line
