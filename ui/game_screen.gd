extends "res://ui/board/board_results.gd"
## The board. Reads the engine state through the controller and REPLAYS engine events as animation.
## The UI never decides anything (RULE-034): who wins, who gets money, whether Razzia fires — all come from events.
##
## Layout roles (docs/05, UI_UX_DESIGN.md §3):
##   landscape (width >= height) = "casino table mode": bars as tall venue cards in one row, hand in one row.
##   portrait                    = "comfortable mode": bars as list rows, hand in one row of five, big buttons.

## (Phase 27) This file keeps the flow: begin / Continue / the tutorial hooks, asking the player, replaying the
## controller's events. The rest of the board lives in ui/board/*.gd, one topic per file, chained by inheritance.


func _ready() -> void:
	Settings.load_settings()
	add_to_group("quality_listeners")
	Audio.cue("table")
	Audio.start_music()
	Audio.mute_feedback = func(on: bool): _toast(tr("소리 켜짐") if on else (tr("소리 꺼짐 (%s)") % IMM.prompt_for(get_tree(), "mute")), 1.2)
	if int(state.get("round", 0)) <= 1:
		Audio.play("game_start")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_relayout)
	if not (get_parent() is Control):
		_fit_viewport()
		get_viewport().size_changed.connect(_fit_viewport)


func _exit_tree() -> void:
	_alive = false
	_coach_hide()
	Audio.mute_feedback = Callable()
	if is_inside_tree() and get_tree() != null and get_tree().paused:
		get_tree().paused = false      # never leave the menu behind a paused tree
	Audio.reset_mood()           # the menu must never inherit a ducked / muffled mix from a game


## Sal's tutorial on its fixed table (ui/tutorial_plan.gd)
func begin_tutorial() -> void:
	tutorial_mode = true
	begin(Eng.create_game(TutorialPlan.config()))


func begin(new_state: Dictionary, resume: bool = false, ai_rng_state = null, actions: Array = []) -> void:
	state = new_state
	_seen_plays = {}
	_shown_discard = {}
	_shown_table = []
	_reshuffles = 0
	human_id = str(state["config"]["humanPlayerId"]) if state["config"]["humanPlayerId"] != null else ""
	ctl = Ctl.new(state)
	if ai_script.is_valid():
		ctl.script_ai = ai_script
	if tutorial_mode:
		ctl.script_ai = func(kind, pid, _view): return TutorialPlan.decide(ctl.state, kind, pid)
		autosave_enabled = false          # a tutorial is never the game you Continue
	if ai_rng_state != null:
		ctl.ai_rng["rngState"] = int(ai_rng_state)
	names = {}
	for p in state["players"]:
		names[p["id"]] = p["name"]
	_build_ui()
	if size.x < 10.0 or size.y < 10.0:
		await get_tree().process_frame    # wait for the first layout pass so _relayout() sees a real size
		if not _alive:
			return
	_relayout()           # metrics must exist before anything is placed (strip cards, narration label)
	if tutorial_mode:
		tutorial = TutorialDirector.new(self)
		add_child(tutorial)
		tutorial.finished.connect(_on_tutorial_finished)
	if resume:
		for ev in state["events"]:
			_track_cards(ev)               # what the board had shown up to the checkpoint (venue card, play history)
		_rebuild_from_state()
		_relayout()
		if not actions.is_empty():
			# the display above shows the checkpoint; the controller moves on with the recorded decisions and the
			# board replays the events they produced (same path as a decision made live)
			var res: Dictionary = SaveStore.replay(state.duplicate(true), int(ctl.ai_rng["rngState"]), actions)
			if res["ok"]:
				ctl = res["ctl"]
				state = ctl.state
				for a in actions:
					if a["type"] == "SELECT_CARD":
						my_selected_id = str(a["cardId"])
			else:
				push_warning("RAZZIA: saved actions no longer fit the checkpoint, resuming from the checkpoint")
	else:
		ctl.buffer = state["events"].duplicate(true)
	var RelicManager = preload("res://engine/relic_manager.gd")
	if RelicManager.is_relic_mode(state) and RelicManager.get_player_relics(state, human_id).is_empty() and not resume and not tutorial_mode:
		await _open_starter_relic_modal()
	var pending = ctl.run()
	_flow(pending)


func _open_starter_relic_modal() -> void:
	if not _alive or human_id.is_empty():
		return
	var StarterModal = preload("res://ui/board/starter_relic_modal.gd")
	var modal = StarterModal.new()
	modal.setup(state, human_id, u, landscape)
	dim.visible = true
	modal_layer.add_child(modal)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	Audio.play("menu")
	var chosen_id: String = await modal.relic_selected
	var RelicManager = preload("res://engine/relic_manager.gd")
	RelicManager.add_relic(state, human_id, chosen_id)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.queue_free()
	dim.visible = false
	_toast(tr("초기 유물 획득: %s") % RelicManager.get_definition(chosen_id).get("name_ko", chosen_id), 2.5)
	_update_hud()
	_update_relic_tray()


func _on_tutorial_finished(choice: String) -> void:
	_tutorial_halted = true
	_alive = false                      # the tutorial table stops here; the next screen takes over
	if get_tree().paused:
		get_tree().paused = false
	tutorial_finished.emit(choice)


## ===================================================================== main flow

func _flow(pending) -> void:
	while _alive:
		await _play_events(ctl.drain_events())
		if not _alive or _tutorial_halted:
			return
		if not ctl.error.is_empty():
			_toast(tr("오류: %s") % str(ctl.error.get("message", "")), 6.0)
			push_error("RAZZIA UI: " + str(ctl.error))
			return
		if pending == null:
			return    # game over (GAME_ENDED was replayed) or nothing to do
		if autosave_enabled and (pending["type"] == "SELECT_CARD" or pending["type"] == "PLACE_EXTRA_MONEY"):
			SaveStore.save(state, int(ctl.ai_rng["rngState"]))
		var action: Dictionary = await _ask_human(pending)
		if not _alive or action.is_empty():
			return
		if action["type"] == "SELECT_CARD":
			my_selected_id = str(action["cardId"])
		var r: Dictionary = ctl.submit(action)
		if not r["ok"]:
			_toast(str(r["error"].get("message", "invalid action")), 3.0)
			ctl.error = {}
			continue
		if autosave_enabled:
			SaveStore.record_action(action)      # accepted by the engine: it can no longer be taken back after Continue
		pending = r["pending"]


func _play_events(events: Array) -> void:
	Trace.log("replay", "begin %d events: %s" % [events.size(), ",".join(events.map(func(e): return str(e["type"])))])
	skip = false          # every replay starts un-skipped; skip is only set while a replay runs (SKIP button / tap)
	skip_btn.visible = true
	for ev in events:
		if not _alive:
			return
		while get_tree().paused and _alive:
			await get_tree().process_frame      # a paused game never starts the next event
		if not _alive:
			return
		Trace.log("event", "%s start (skip=%s)" % [ev["type"], skip])
		if tutorial != null and tutorial.should_halt(ev):
			skip_btn.visible = false
			_tutorial_halted = true
			await tutorial.finale()
			return
		_track_cards(ev)
		await _play_event(ev)
		event_played.emit(ev)
		if tutorial != null and _alive:
			skip = false                   # Sal never talks over a skipped animation: the next one plays again
			await tutorial.after_event(ev)
	await _settle_money_flights()
	skip_btn.visible = false
	skip = false
	Trace.log("replay", "end")


## The money cards are launched 0.10 s apart and fly 0.32 s: the last one lands after the last event. The board does not ask
## the human for anything before it has landed (at most one flight, ~0.2 s at NORMAL). SKIP / reduced motion create no flights.
func _settle_money_flights() -> void:
	var t := Settings.dur(0.6)           # safety cap: a stuck counter can never freeze the board
	while _money_flying > 0 and t > 0.0 and not skip and _alive:
		await get_tree().process_frame
		t -= get_process_delta_time()


func _ask_human(pending: Dictionary) -> Dictionary:
	Trace.log("ask", str(pending.get("type", "?")))
	_clear_highlights()
	idle.emit(pending)
	var view := Eng.get_public_view(state, human_id)
	if bot.is_valid():
		await get_tree().process_frame
		return bot.call(pending, view, self)
	if tutorial != null:
		await tutorial.before_prompt(pending)
		if not _alive:
			return {}
	match pending["type"]:
		"PLACE_EXTRA_MONEY":
			var extra: int = int(state["extraMoneyCard"]["value"]) if state["extraMoneyCard"] != null else 0
			_now_live(func(): return tr("내가 딜러 — 추가 머니카드 %s를 놓을 술집을 고르세요") % T.money(extra))
			confirm_btn.text = "PICK A BAR"
			confirm_btn.disabled = true
			_show_held_extra(extra)
			for id in bar_order:
				bar_views[id].clickable = true
				bar_views[id].highlight = true
				bar_views[id].set_preview(extra)
			_awaiting_bar = true
			_coach("extra", "추가 머니카드", "라운드마다 딜러가 머니카드를 한 장 더 올립니다. 내가 노리는 술집에 쌓아두면 그만큼 크게 벌 수 있어요.")
			Audio.thinking(true)
			_clear_focus()
			_move_focus(1)
			if tutorial != null:
				tutorial.prompt_ready(pending)
			var a = await _human_action
			if tutorial != null:
				tutorial.prompt_done(pending)
			_awaiting_bar = false
			_coach_hide()
			Audio.play("chip_clink")
			Audio.thinking(false)
			confirm_btn.text = "PLACED"
			_clear_focus()
			for id in bar_order:
				bar_views[id].clickable = false
				bar_views[id].highlight = false
				bar_views[id].set_preview(0)
			return a
		"SELECT_CARD":
			var RelicManager = preload("res://engine/relic_manager.gd")
			var intel: Dictionary = RelicManager.get_informant_intel(state, human_id) if human_id != "" else {}
			if not intel.is_empty():
				_now(tr("정보원: %s 가 %s 로 향합니다") % [intel["targetName"], intel["barName"]])
				_toast(tr("[정보원] %s → %s") % [intel["targetName"], intel["barName"]], 2.8)
				if bar_views.has(intel["barId"]):
					bar_views[intel["barId"]].set_intel(intel["targetName"])
			else:
				_now("")
			for v in hand_views:
				v.interactive = true
			confirm_btn.text = "PLAY CARD" if selected_view != null else "PICK A CARD"
			confirm_btn.disabled = selected_view == null
			_awaiting_select = true
			_coach("card", "카드 고르기", tr("카드 한 장을 골라 그 술집에 놓습니다. 돈이 많은 술집일수록 경쟁도 치열해요. 술집을 누르면(또는 %s) 아직 안 나온 카드를 볼 수 있습니다.") % IMM.prompt_for(get_tree(), "venue_info"))
			Audio.thinking(true)
			Audio.play("your_turn")
			_clear_focus()
			_move_focus(1)
			if tutorial != null:
				tutorial.prompt_ready(pending)
			var a2 = await _human_action
			if tutorial != null:
				tutorial.prompt_done(pending)
			_awaiting_select = false
			_coach_hide()
			Audio.play("card_snap")
			Audio.thinking(false)
			_clear_focus()
			for bv in bar_views.values():
				bv.set_intel("")
			for v in hand_views:
				v.interactive = false
			confirm_btn.disabled = true
			confirm_btn.text = "PLAYED"
			return a2
		"MAKE_PROPOSAL":
			if tutorial != null:
				tutorial.prompt_ready(pending)
			var alloc: Dictionary = await nego.ask_proposal(view)
			if tutorial != null:
				tutorial.prompt_done(pending)
			return {"type": "MAKE_PROPOSAL", "playerId": human_id, "allocations": alloc}
		"RESPOND":
			_coach("respond", "협상", "상대가 돈을 나누자고 제안했어요. 수락하면 적어도 그만큼은 확실히 받고, 결투는 이기면 전부·지면 0입니다. 승률은 카드의 눈으로 정해집니다.", true)
			var resp: String = await nego.ask_response(view)
			_coach_hide()
			return {"type": "RESPOND", "playerId": human_id, "response": resp}
	return {}
