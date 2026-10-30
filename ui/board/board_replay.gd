extends "res://ui/board/board_fx.gd"
## Board replay: one engine event at a time, as animation (rounds, cards, venues, negotiations, duels, payouts).
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.

## Centralized pacing and animation timing constants (Task 2)
const TIMINGS := {
	"EMPTY_BAR": 0.08,             # 빈 술집: 0.05~0.1초 어두워지는 효과 후 바로 다음으로
	"SOLO_RESOLVE": 0.10,          # 혼자 들어간 술집 판정 연출
	"SOLO_AWARD": 0.10,            # 혼자 들어간 술집 돈 획득 연출 (합계 <= 0.2초)
	"RAZZIA_NO_ZOCKER": 1.10,      # 허탕 단속 (기존 유지)
	"RAZZIA_SOLE": 0.50,           # 단속 보상 (기존 유지)
	"CONTESTED_RESOLVE": 0.40,     # 충돌/협상/결투 정리 (기존 유지)
	"NEGO_START": 1.30,            # 협상 시작 (기존 유지)
	"PROPOSAL_MADE": 0.90,         # 제안 (기존 유지)
	"PROPOSAL_ACCEPTED": 0.55,     # 수락 (기존 유지)
	"DUEL_CALLED": 0.55,           # 결투 선언 (기존 유지)
	"DICE_ROLLED": 0.40,           # 주사위 굴림 (기존 유지)
	"DUEL_RESOLVE_AI": 1.30,       # AI 결투 결과 (기존 유지)
	"AWARD_NORMAL": 0.40,          # 일반 돈 지급 연출 (기존 유지)
	"AWARD_NEGO": 0.60,            # 협상 타결 돈 지급 연출 (기존 유지)
}


## ===================================================================== event replay

func _play_event(ev: Dictionary) -> void:
	match ev["type"]:
		"GAME_STARTED":
			_update_hud()
		"ROUND_STARTED":
			await _ev_round_started(ev)
		"HAND_FILLED":
			_ev_hand_filled(ev)
		"MONEY_PLACED":
			await _ev_money_placed(ev)
		"FINAL_ROUND_ANNOUNCED":
			Audio.play("final_round")
			Audio.intensity(1)                 # the last round keeps a quiet tension bed under the music
			disp["final"] = true
			_update_hud()
			_now("FINAL ROUND — 마지막 라운드입니다")
			await _wait(0.7)
			await _play_scene("final")
		"DECK_RECYCLED":
			Audio.play("shuffle")
			_toast("카드 덱을 다시 섞었습니다", 1.6)
		"CARD_SELECTED":
			await _ev_card_selected(ev)
		"CARDS_REVEALED":
			await _ev_cards_revealed(ev)
		"RAZZIA_ACTIVATED":
			await _ev_razzia(ev)
		"BAR_RESOLVED":
			await _ev_bar_resolved(ev)
		"NEGOTIATION_STARTED":
			await _ev_negotiation_started(ev)
		"PROPOSAL_MADE":
			Audio.play("offer")
			nego.set_proposal(ev)
			nego.say(ev["proposerId"], "propose", int(ev.get("seq", 0)))
			await _wait(TIMINGS.PROPOSAL_MADE)
		"PROPOSAL_ACCEPTED":
			Audio.play("accept")
			nego.set_mark(ev["playerId"], "ACCEPT")
			nego.say(ev["playerId"], "accept", int(ev.get("seq", 0)))
			await _wait(TIMINGS.PROPOSAL_ACCEPTED)
		"DUEL_CALLED":
			Audio.play("duel")
			nego.set_mark(ev["playerId"], "DUEL")
			nego.say(ev["playerId"], "duel", int(ev.get("seq", 0)))
			await _wait(TIMINGS.DUEL_CALLED)
		"DUEL_STARTED":
			await _ev_duel_started(ev)
		"DICE_ROLLED":
			Audio.play("dice")
			await nego.set_rolls(ev)
			await _wait(TIMINGS.DICE_ROLLED)
		"DUEL_RESOLVED":
			if _is_me(ev["playerA"]) or _is_me(ev["playerB"]):
				Audio.play("duel_win" if _is_me(ev["winnerId"]) else "duel_lose")
			nego.finish_duel(ev)
			var loser_id: String = ev["playerB"] if ev["winnerId"] == ev["playerA"] else ev["playerA"]
			nego.say(ev["winnerId"], "win", int(ev.get("seq", 0)))
			if _is_me(ev["winnerId"]):
				nego.say(loser_id, "lose", int(ev.get("seq", 0)))
			if (_is_me(ev["playerA"]) or _is_me(ev["playerB"])) and not skip and not bot.is_valid():
				Trace.log("duel", "result shown, waiting for the player's confirmation")
				await nego.ask_continue()
				# a big pot decided against the human gets a short reaction (at most twice a game, never two rounds in a row)
				var pot := int(nego.neg.get("prize", 0)) if not nego.neg.is_empty() else 0
				if pot >= 50000 and _scene_big_duels < 2 and _mid_scene_ok():
					var opp_id: String = ev["playerB"] if _is_me(ev["playerA"]) else ev["playerA"]
					for pl in _ai_players():
						if pl["id"] == opp_id:
							_scene_big_duels += 1
							await _mid_scene("duel", {"actor": pl, "ai_won": ev["winnerId"] == opp_id, "ctx": {"bar": T.bar_name(str(ev["barId"])), "pot": T.money(pot)}})
			else:
				await _wait(TIMINGS.DUEL_RESOLVE_AI)
		"MONEY_AWARDED":
			await _ev_money_awarded(ev)
		"ROUND_ENDED":
			await _ev_round_ended(ev)
		"GAME_ENDED":
			await _ev_game_ended(ev)
		"RELIC_TRIGGERED":
			Audio.play("coin")
			var rid: String = str(ev.get("relicId", ""))
			if rid == "bribed_judge":
				_toast(tr("⚖️ [매수한 판사] 판사가 매수되어 결투 동점에서 승리했습니다!"), 2.2)
			elif rid == "dirty_cop":
				_toast(tr("🚨 [부패한 경관] 단속 실패 뇌물 %s 수취!") % T.money(int(ev.get("amount", 0))), 2.2)
		_:
			pass


func _ev_round_started(ev: Dictionary) -> void:
	disp["round"] = ev["round"]
	disp["croupier"] = ev["croupierId"]
	for pid in disp["ready"]:
		disp["ready"][pid] = false
	for id in bar_views:
		bar_views[id].clear_minis()
		bar_views[id].set_extra(0, "")
	_drop_held_extra()
	_round_awards.clear()
	_round_reason.clear()
	_round_plays.clear()
	table_cards.clear()
	for pid in strip_views:
		if is_instance_valid(strip_views[pid]):
			strip_views[pid].queue_free()
	strip_views.clear()
	my_selected_id = ""
	_clear_highlights()
	_update_hud()
	_now_live(func(): return tr("ROUND %d — %s 딜러") % [int(ev["round"]), _nm(ev["croupierId"])])
	if int(ev["round"]) == 1:
		await _play_scene("intro")
	await _wait(0.25)           # banner beat (was 0.5 s; Phase 8B-4). The hand fan and the money cards follow at once.


func _ev_hand_filled(_ev: Dictionary) -> void:
	if not skip:
		Audio.play("deal" if int(_ev.get("drawn", {}).get(human_id, 0)) >= 3 else "take")
	_set_hand(Eng.get_public_view(state, human_id)["hand"], not skip)


func _ev_card_selected(ev: Dictionary) -> void:
	var pid: String = ev["playerId"]
	Audio.play("take")
	disp["ready"][pid] = true
	var hv: Control = _hand_view_by_id(my_selected_id) if _is_me(pid) else null
	if hv == null:
		_add_strip_back(pid, not skip)
	else:
		# my own card: leaves the hand (the fan closes up), flies to my slot on the table and turns face-down there
		hand_views.erase(hv)
		if hv == selected_view:
			selected_view = null
		hv.selected = false
		hv.interactive = false
		hv.hovering = false
		hv.z_index = 25
		var old = hv.get_meta("tw") if hv.has_meta("tw") else null
		if old != null and old.is_valid():
			old.kill()
		hv.caption = "" if compact else _nm(pid)
		_layout_hand()
		strip_views[pid] = hv
		var slot := strip_slot_pos(pid)
		var card_sz: Vector2 = _strip_metrics["card"]
		if skip or Settings.reduce_motion:
			hv.position = slot
			hv.size = card_sz
			hv.rotation = 0.0
			hv.card = {}
			hv.face_up = false
		else:
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(hv, "position", slot, Settings.dur(0.34) + 0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hv, "size", card_sz, Settings.dur(0.34) + 0.001).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hv, "rotation", 0.0, Settings.dur(0.34) + 0.001)
			await tw.finished
			if not _alive or not is_instance_valid(hv):
				return
			var tw2 := create_tween()
			tw2.tween_property(hv, "scale:x", 0.0, Settings.dur(0.07) + 0.001)
			await tw2.finished
			hv.card = {}
			hv.face_up = false
			var tw3 := create_tween()
			tw3.tween_property(hv, "scale:x", 1.0, Settings.dur(0.07) + 0.001)
			tw3.tween_property(hv, "scale", Vector2(1.1, 1.1), Settings.dur(0.07) + 0.001)    # little landing bump
			tw3.tween_property(hv, "scale", Vector2.ONE, Settings.dur(0.1) + 0.001)
			await tw3.finished
	if _is_me(pid):
		_now("카드를 냈습니다 — 다른 플레이어를 기다리는 중")
	_update_hud()
	await _wait(0.12)


func _ev_cards_revealed(ev: Dictionary) -> void:
	_round_plays = ev["cards"].duplicate()
	_now("ALL PLAYERS READY")
	await _wait(0.5)
	var played: Array = ev["cards"]
	# 1) flip everything together
	var flips: Array = []
	for pc in played:
		var sv = strip_views.get(pc["playerId"])
		if sv == null:
			sv = _make_strip_card_late(pc["playerId"])
		flips.append([sv, pc])
	Audio.play("flip")
	var tw := _tween()
	tw.set_parallel(true)
	for f in flips:
		tw.tween_property(f[0], "scale:x", 0.0, Settings.dur(0.14) + 0.001)
	await tw.finished
	for f in flips:
		f[0].card = _card_dict(f[1])
		f[0].face_up = true
	var tw2 := _tween()
	tw2.set_parallel(true)
	for f in flips:
		tw2.tween_property(f[0], "scale:x", 1.0, Settings.dur(0.14) + 0.001)
	await tw2.finished
	await _wait(0.5)
	# the human's own card leaves the hand
	var mine := _hand_view_by_id(my_selected_id)
	if mine != null:
		hand_views.erase(mine)
		mine.queue_free()
		_layout_hand()
	# 2) every card flies to its bar
	var flights: Array = []
	var idx := 0
	var last_tw: Tween = null
	var per_bar := {}
	for f in flips:
		var bid: String = f[1]["barId"]
		per_bar[bid] = int(per_bar.get(bid, 0)) + 1
	for bid in per_bar:
		bar_views[bid].expected = bar_views[bid].minis.size() + int(per_bar[bid])
	var slot_of := {}
	for f in flips:
		var sv: Control = f[0]
		var pc: Dictionary = f[1]
		var bar: BarView = bar_views[pc["barId"]]
		var slot: int = bar.minis.size() + int(slot_of.get(pc["barId"], 0))
		slot_of[pc["barId"]] = int(slot_of.get(pc["barId"], 0)) + 1
		var target: Rect2 = bar.slot_global_rect(slot, bar.expected)
		var fly := CardView.new()
		fly.card = _card_dict(pc)
		fly.face_up = true
		fly.art_mini = true
		fx_layer.add_child(fly)
		fly.size = sv.size
		fly.global_position = sv.global_position
		sv.visible = false
		var t3 := _tween()
		t3.set_parallel(true)
		t3.tween_property(fly, "global_position", target.position, Settings.dur(0.42) + 0.001).set_delay(Settings.dur(0.08) * idx).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t3.tween_property(fly, "size", target.size, Settings.dur(0.42) + 0.001).set_delay(Settings.dur(0.08) * idx)
		flights.append([fly, pc, bar])
		last_tw = t3
		idx += 1
	if last_tw != null:
		await last_tw.finished
	Audio.play("take")
	for fl in flights:
		var pc2: Dictionary = fl[1]
		var mini: Control = fl[2].add_mini(_card_dict(pc2), _nm(pc2["playerId"]))
		table_cards[pc2["playerId"]] = {"card": _card_dict(pc2), "bar": pc2["barId"], "mini": mini}
		fl[0].queue_free()
		fl[2].pulse(Settings.dur(0.5))    # the venue reacts when a card lands on it (follows the speed setting; none with reduced motion)
	for pid in strip_views:
		if is_instance_valid(strip_views[pid]):
			strip_views[pid].queue_free()
	strip_views.clear()
	_now("카드가 공개되었습니다")
	await _wait(0.5)


func _ev_bar_resolved(ev: Dictionary) -> void:
	var id: String = ev["barId"]
	var kind: String = ev["kind"]
	match kind:
		"SINGLE_ZOCKER":
			_round_reason[id] = "단독 도박꾼"          # a key: compared in board_results, translated where shown
		"RAZZIA_SOLE_CLAIMANT":
			_round_reason[id] = "RAZZIA 단속 보상"
		"ZOCKER", "RAZZIA":
			_round_reason[id] = "합의 분배" if str(ev.get("outcome", "")) == "DEAL" else "결투 결과"
	match kind:
		"EMPTY":
			# 빈 술집(카드 0장): 카메라 이동 없이 0.05~0.1초 살짝 어두워지는 효과만, 바로 다음으로
			if bar_views.has(id) and is_instance_valid(bar_views[id]):
				var bv: Control = bar_views[id]
				var orig_col: Color = bv.modulate
				bv.modulate = Color(0.65, 0.65, 0.65, 0.85)
				await _wait(TIMINGS.EMPTY_BAR)
				if is_instance_valid(bv):
					bv.modulate = orig_col
			return
		"RAZZIA_NO_ZOCKER":
			bar_views[id].highlight = true
			var cops: Array = ev.get("razzias", [])
			if human_id in cops:
				Audio.play("denied")
				_now_live(func(): return tr("🚨 RAZZIA 허탕! %s에 도박꾼이 없어 단속 실패 · 판돈 %s 유지") % [T.bar_name(id), T.money(int(ev.get("money", 0)))])
			elif not cops.is_empty():
				_now_live(func(): return tr("🚨 RAZZIA 허탕 · %s에 도박꾼이 없어 %s의 단속 실패 · 판돈 %s 유지") % [T.bar_name(id), _nm(cops[0]), T.money(int(ev.get("money", 0)))])
			else:
				_now_live(func(): return tr("도박꾼이 없어 돈이 그대로 남습니다"))
			await _wait(TIMINGS.RAZZIA_NO_ZOCKER)
			bar_views[id].highlight = false
		"SINGLE_ZOCKER":
			# 혼자 들어간 술집(충돌 없음): 0.2초 이내로 짧게, 돈 획득 연출만
			bar_views[id].highlight = true
			_now_live(func(): return tr("%s · 단독 도박꾼 — %s 가 %s 를 가져갑니다") % [T.bar_name(id), _nm(ev["winnerId"]), T.money(int(ev["money"]))])
			await _wait(TIMINGS.SOLO_RESOLVE)
		"RAZZIA_SOLE_CLAIMANT":
			bar_views[id].highlight = true
			_now_live(func(): return tr("RAZZIA · %s — %s 가 단속 보상으로 %s 를 가져갑니다") % [T.bar_name(id), _nm(ev["winnerId"]), T.money(int(ev["money"]))])
			await _wait(TIMINGS.RAZZIA_SOLE)
			_set_felt("")
		_:
			nego.close()
			bar_views[id].z_index = 0
			_set_felt("")
			dim.visible = false
			_now_live(func(): return "%s · %s" % [T.bar_name(id), tr(str(_round_reason.get(id, "정리 완료")))])
			await _wait(TIMINGS.CONTESTED_RESOLVE)
			bar_views[id].highlight = false


func _ev_negotiation_started(ev: Dictionary) -> void:
	bar_views[ev["barId"]].highlight = true
	_set_felt("nego")
	# the venue being negotiated stays lit above the dim, and the panel parks on the side away from it (landscape)
	var tid: String = ev["barId"]
	bar_views[tid].z_index = 41
	var ti := bar_order.find(tid)
	nego.side = "" if not landscape else ("right" if ti < bar_order.size() / 2 else "left")
	nego.side_x0 = _land_x0
	nego.side_x1 = _land_x1
	if not skip and Settings.dur(0.25) > 0.0:
		await _wait(0.25)              # the venue is lit first; the panel follows (never both at once)
	nego.open(ev)
	nego._queue_fit()
	# bottom dock (portrait, or landscape with room): the table stays lit; side dock: dim the rest of the table
	dim.color = Color(0, 0, 0, 0.55)
	dim.visible = not nego._bottom
	_now_live(func(): return tr("협상 · %s %s") % [T.bar_name(tid), T.money(int(ev["prize"]))])
	await _wait(TIMINGS.NEGO_START)


func _ev_duel_started(ev: Dictionary) -> void:
	nego.begin_duel(ev)
	dim.color = Color(0.01, 0.03, 0.02, 0.78)          # the duel stage: the table steps back
	dim.visible = true
	if not skip:
		Audio.play("drumroll")
	var me_in := _is_me(ev["playerA"]) or _is_me(ev["playerB"])
	if me_in and not skip:
		if bot.is_valid():
			await get_tree().process_frame
		else:
			await nego.ask_roll()
	else:
		await _wait(0.7)


func _ev_money_awarded(ev: Dictionary) -> void:
	var pid: String = ev["playerId"]
	var id: String = ev["barId"]
	var amount: int = int(ev["amount"])
	var bv: BarView = bar_views[id]
	if not _round_awards.has(pid):
		_round_awards[pid] = []
	_round_awards[pid].append({"bar": id, "amount": amount})
	if amount > 0:
		Audio.play(("cash_big" if amount >= 60000 else "ching") if _is_me(pid) else "coin")          # my own payout is the big cash register, the others' a quiet clink
	_float_text("+" + T.money(amount), bv.global_center(), T.OK if _is_me(pid) else T.GOLD)
	if chips.has(pid) and is_instance_valid(chips[pid]) and chips[pid].is_visible_in_tree():
		var ch: Control = chips[pid]
		_float_text("+" + T.money(amount), ch.get_global_transform_with_canvas() * Vector2(ch.size.x * 0.5, 0.0), T.OK if _is_me(pid) else T.GOLD)
	var negotiated: bool = nego.visible and not nego.neg.is_empty()
	if negotiated:
		nego.set_stage(3)
		nego.set_status(tr("%s 님이 %s 를 받습니다.") % [_nm(pid) + ("" if str(names.get(pid, "")) == "나" or not _is_me(pid) else tr(" (나)")), T.money(amount)])      # result inside the panel
	elif not _round_reason.has(id):
		_now_live(func(): return "%s  +%s  ←  %s" % [_nm(pid) + _me_tag(pid), T.money(amount), T.bar_name(id)])
	var is_solo := not negotiated and str(_round_reason.get(id, "")) == "단독 도박꾼"
	var bar_dur := 0.15 if is_solo else 0.45
	var pl_dur := 0.18 if is_solo else 0.50
	_set_bar_money(id, int(disp["bar_money"][id]) - amount, bar_dur)
	_set_player_money(pid, int(disp["money"][pid]) + amount, pl_dur)
	_pop(chips.get(pid))
	_pop(bv)
	var wait_dur: float = TIMINGS.AWARD_NEGO if negotiated else (TIMINGS.SOLO_AWARD if is_solo else TIMINGS.AWARD_NORMAL)
	await _wait(wait_dur)
