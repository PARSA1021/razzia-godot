extends "res://ui/board/board_info.gd"
## Board input: keys / pad / mouse on the table, the hand, the pause panel and the first-game tips.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		var fo := get_viewport().gui_get_focus_owner()
		Trace.log("key", "%s echo=%s  select=%s bar=%s skip_btn=%s focus=%s selected=%s" % [OS.get_keycode_string(event.keycode), event.echo, _awaiting_select, _awaiting_bar, skip_btn.visible, fo.name if fo != null else "-", selected_view != null])
	# Esc / Android back / gamepad B opens the in-game menu (the ⎋ button's panel), and closes it again.
	# It never fires while something else owns the key: a cutscene, help / records / summary (z_index >= 60),
	# a modal board (round result, game over) or an open negotiation. With a card selected it clears the selection first.
	var is_pause: bool = InputMap.has_action("pause") and event.is_action_pressed("pause")
	if InputMap.has_action("skip_anim") and event.is_action_pressed("skip_anim") and skip_btn.visible:
		skip = true                          # the controller's way to do what a tap on the table does
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed("ui_cancel") or is_pause) and not (event is InputEventKey and event.echo):
		for nm in ["BarInfo", "ExitConfirm"]:
			if modal_layer.has_node(nm):
				modal_layer.get_node(nm).queue_free()
				modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				Audio.play("panel_close")
				get_viewport().set_input_as_handled()
				return
		if (is_pause or not (_awaiting_select and selected_view != null)) and not _overlay_open():
			_on_exit_pressed()
			get_viewport().set_input_as_handled()
			return
	# a negotiation is open but the focus is somewhere else (lost, or taken by the ⎋ button while the answer cards were
	# still arming): the d-pad / A brings it back into the panel instead of wandering the table (Phase 29)
	if nego != null and nego.visible and _is_nav_event(event) and not _other_overlay_open():
		var fo := get_viewport().gui_get_focus_owner()
		if fo == null or not nego.is_ancestor_of(fo):
			var t: Button = nego.default_focus_target()
			if t != null:
				t.grab_focus()
				get_viewport().set_input_as_handled()
				return
	if not (_awaiting_select or _awaiting_bar):
		return
	# Y / I: the venue card for the card under the cursor (a mouse user taps the venue; this is the same card)
	if _awaiting_select and InputMap.has_action("venue_info") and event.is_action_pressed("venue_info") and not _overlay_open():
		var bar_id := ""
		if selected_view != null and is_instance_valid(selected_view):
			bar_id = str(selected_view.card.get("barId", ""))
		else:
			var lst := _focus_list()
			if focus_idx >= 0 and focus_idx < lst.size():
				bar_id = str(lst[focus_idx].card.get("barId", ""))
		if bar_id != "":
			_show_bar_info(bar_id)
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		step = 1
	if step != 0:
		Audio.play("hover")                  # keyboard / gamepad focus step
		_move_focus(step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() is Button and not (get_viewport().gui_get_focus_owner() == confirm_btn):
			return
		_accept_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _awaiting_select and selected_view != null:
		_deselect()
		get_viewport().set_input_as_handled()


func _close_pause() -> void:
	_set_paused(false)
	if modal_layer.has_node("ExitConfirm"):
		var p := modal_layer.get_node("ExitConfirm")
		modal_layer.remove_child(p)          # out of the tree now: a panel reopened in the same frame (language switch) is not refused
		p.queue_free()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _focus_list() -> Array:
	if _awaiting_bar:
		return bar_order.map(func(id): return bar_views[id])
	return hand_views.filter(func(v): return is_instance_valid(v) and not v.locked)


func _move_focus(step: int) -> void:
	var list := _focus_list()
	if list.is_empty():
		return
	for v in list:
		v.focused = false
	focus_idx = posmod(focus_idx + step, list.size()) if focus_idx >= 0 else (0 if step > 0 else list.size() - 1)
	list[focus_idx].focused = true
	if _awaiting_select:
		_layout_hand()
		_update_hint()


func _accept_focus() -> void:
	var list := _focus_list()
	if _awaiting_bar:
		if focus_idx >= 0 and focus_idx < list.size():
			_on_bar_chosen(bar_order[focus_idx])
		return
	if focus_idx < 0 or focus_idx >= list.size():
		_move_focus(1)
		return
	# Enter does exactly one thing per press: with a card selected (by keyboard OR by mouse / touch) it plays that card,
	# otherwise it selects the keyboard-focused card. (It used to re-select the focused card when the selection came from a click.)
	if selected_view != null and is_instance_valid(selected_view):
		Trace.log("accept", "confirm selected card")
		_on_confirm()
	else:
		Trace.log("accept", "select focused card")
		_on_hand_pressed(list[focus_idx])


func _clear_focus() -> void:
	for v in hand_views:
		if is_instance_valid(v):
			v.focused = false
			v.hovering = false
	for id in bar_views:
		bar_views[id].focused = false
	focus_idx = -1


func _gui_input(event: InputEvent) -> void:
	# tapping empty table space while an animation runs skips it (docs/05 §10: animations must be skippable).
	# Only while events are being replayed (the SKIP button is visible then): a tap while the human is choosing a card,
	# an extra-money bar or a negotiation answer must not leave `skip` set for the next replay.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if skip_btn.visible:
			skip = true
		if _opp_open:
			_toggle_opp(false)
	elif event is InputEventScreenTouch and event.pressed:
		if skip_btn.visible:
			skip = true


func _coach(key: String, title: String, body: String, at_top: bool = false) -> void:
	if not Settings.coach_on or _coach_shown.has(key) or human_id == "" or bot.is_valid() or skip or not _alive or tutorial != null:
		return
	if Settings.tutorial_done and key in ["card", "extra", "extra_ai"]:
		return                          # Sal already taught these, by doing them
	_coach_shown[key] = true
	_coach_hide()
	var panel := PanelContainer.new()
	panel.name = "Coach"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", W.deco(Color("17120c"), T.GOLD, Vector4(22, 14, 22, 14), u * 0.8))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", int(4 * u))
	panel.add_child(vb)
	var head := W.label(tr("처음 안내 · %s") % tr(title), int(15 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	var text := W.label(body, int(17 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(minf(size.x - 60.0 * u, 460.0 * u), 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(text)
	var btn := W.button("알겠어요", "secondary", int(15 * u), Vector2(110.0 * u, 36.0 * u))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	vb.add_child(btn)
	btn.pressed.connect(_coach_hide)
	# 안내는 판을 막지 않습니다: 컨트롤러 포커스를 가져가지 않고(설명한 동작을 하면 저절로 사라짐), 마우스·터치로만 닫습니다
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("no_auto_focus", true)
	modal_layer.add_child(panel)
	_coach_panel = panel
	panel.reset_size()
	# just under the venue row, where the felt is empty in both orientations
	var px := (size.x - panel.size.x) / 2.0
	var py := (8.0 * u) if at_top else (_grid_bottom + 10.0 * u)
	panel.position = Vector2(clampf(px, 8.0, maxf(8.0, size.x - panel.size.x - 8.0)), clampf(py, 8.0, maxf(8.0, size.y - panel.size.y - 8.0)))
	if not Settings.reduce_motion:
		panel.modulate.a = 0.0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.18)


func _coach_hide() -> void:
	if _coach_panel != null and is_instance_valid(_coach_panel):
		if _coach_panel.get_parent() != null:
			_coach_panel.get_parent().remove_child(_coach_panel)    # free the name "Coach" now: the next tip may follow at once
		_coach_panel.queue_free()
	_coach_panel = null


## ===================================================================== hand

func _set_hand(cards: Array, animate: bool) -> void:
	for v in hand_views:
		if is_instance_valid(v):
			v.queue_free()
	hand_views.clear()
	selected_view = null
	var sorted := cards.duplicate()
	var order := {}
	for i in range(Eng.BAR_DEFS.size()):
		order[Eng.BAR_DEFS[i]["id"]] = i
	sorted.sort_custom(func(a, b):
		if order[a["barId"]] != order[b["barId"]]:
			return order[a["barId"]] < order[b["barId"]]
		if a["type"] != b["type"]:
			return a["type"] == "ZOCKER"
		return a["dieSymbol"] < b["dieSymbol"])
	for c in sorted:
		var cv := CardView.new()
		cv.card = c
		cv.pressed.connect(_on_hand_pressed)
		cv.hover_changed.connect(_on_hand_hover)
		_add_below_overlays(cv)
		hand_views.append(cv)
	_layout_hand(false)
	confirm_btn.disabled = true
	if animate and not skip and not Settings.reduce_motion:
		# cards are dealt from the money-deck corner: they spin, scale up and settle into their fan slot, one after another
		var deck_pos: Vector2 = me_chip.position + me_chip.size / 2.0 - Vector2(40.0, 55.0) * u    # from my own supply (the money deck deals to the venues)
		var n := hand_views.size()
		var i := 0
		for cv in hand_views:
			var tg := _hand_target(i, n)
			cv.set_meta("intro", true)
			cv.position = deck_pos
			cv.rotation = -0.6
			cv.scale = Vector2(0.55, 0.55)
			cv.modulate.a = 0.0
			var delay := Settings.dur(0.07) * i
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(cv, "position", tg["pos"], Settings.dur(0.38) + 0.001).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "rotation", tg["rot"], Settings.dur(0.38) + 0.001).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "scale", Vector2.ONE, Settings.dur(0.38) + 0.001).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "modulate:a", 1.0, Settings.dur(0.2) + 0.001).set_delay(delay)
			tw.chain().tween_callback(func():
				if is_instance_valid(cv):
					cv.remove_meta("intro")
					_layout_hand(true))
			i += 1


func _hand_view_by_id(id: String) -> Control:
	for v in hand_views:
		if is_instance_valid(v) and v.card.get("id", "") == id:
			return v
	return null


func _deselect() -> void:
	if selected_view != null and is_instance_valid(selected_view):
		selected_view.selected = false
	selected_view = null
	_clear_bar_selection_highlights()
	confirm_btn.disabled = true
	confirm_btn.text = "PICK A CARD"
	_update_hint()
	_layout_hand()


func _clear_bar_selection_highlights() -> void:
	for id in bar_views:
		if is_instance_valid(bar_views[id]):
			bar_views[id].highlight = false


func _on_hand_pressed(cv: Control) -> void:
	Trace.log("select", "card %s locked=%s awaiting=%s" % [str(cv.card.get("id", "?")) if "card" in cv else "?", cv.locked, _awaiting_select])
	if not _awaiting_select or cv.locked:
		return
	if cv == selected_view:
		Audio.play("click")
		_deselect()               # tapping / clicking the selected card again puts it back (same as Esc / Cancel)
		return
	Audio.play("pick")
	if selected_view != null and is_instance_valid(selected_view):
		selected_view.selected = false
	selected_view = cv
	cv.selected = true
	for v in hand_views:
		if is_instance_valid(v) and v != cv:
			v.hovering = false    # touch screens never send "mouse exit": avoid a lifted card getting stuck
	_clear_bar_selection_highlights()
	var bid: String = str(cv.card.get("barId", ""))
	if bar_views.has(bid) and is_instance_valid(bar_views[bid]):
		bar_views[bid].highlight = true
	confirm_btn.disabled = false
	var is_rz: bool = cv.card.get("type", "") == "RAZZIA"
	confirm_btn.text = "RAID" if is_rz else "PLAY CARD"
	var fl := _focus_list()
	if fl.has(cv):
		for v in fl:
			v.focused = false
		focus_idx = fl.find(cv)
		cv.focused = true
	_layout_hand()
	_update_hint()


func _on_confirm() -> void:
	Trace.log("confirm", "awaiting=%s selected=%s disabled=%s" % [_awaiting_select, selected_view != null, confirm_btn.disabled])
	if not _awaiting_select or selected_view == null or confirm_btn.disabled:
		return
	confirm_btn.disabled = true            # processing: no second submit from a double tap / second Enter
	confirm_btn.text = "PLAYED"
	_clear_bar_selection_highlights()
	_human_action.emit({"type": "SELECT_CARD", "playerId": human_id, "cardId": selected_view.card["id"]})


func _on_bar_chosen(bar_id: String) -> void:
	if _awaiting_bar:
		Audio.play("click")
		_human_action.emit({"type": "PLACE_EXTRA_MONEY", "playerId": human_id, "barId": bar_id})


## Sound settings inside the in-game menu (the ⎋ button): on/off + volume for music and effects. Changes apply at once and are saved.
func _on_exit_pressed() -> void:
	if modal_layer.has_node("ExitConfirm"):
		return
	var panel := PanelContainer.new()
	panel.name = "ExitConfirm"
	panel.add_theme_stylebox_override("panel", W.deco(Color("120e09fa"), T.GOLD, Vector4(30, 22, 30, 24), u))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * u))
	panel.add_child(vb)
	vb.add_child(W.label("잠시 멈춤", int(26 * u), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800))
	var save_note := tr("튜토리얼은 저장되지 않습니다.") if not autosave_enabled else (tr("슬롯 %d에 자동 저장 중 · 카드를 고를 때마다 저장됩니다.") % SaveStore.slot)
	var sl := W.label(save_note, int(14 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)
	sl.name = "SaveNote"
	vb.add_child(sl)
	var top_btns := HBoxContainer.new()
	top_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	top_btns.add_theme_constant_override("separation", int(14 * u))
	vb.add_child(top_btns)
	vb.add_child(W.rule(u, 1))
	# Phase 29: the settings are tabs that each fit on the screen (no scrolling); the controls and the rules are a tab too
	var ctl := VBoxContainer.new()
	ctl.add_theme_constant_override("separation", int(12 * u))
	var keys_l := W.label(tr("%s 계속 · %s 확인 · %s 고른 카드의 술집 정보 · %s 연출 건너뛰기 · %s 음소거") % [
		IMM.prompt_for(get_tree(), "pause"), IMM.prompt_for(get_tree(), "accept"), IMM.prompt_for(get_tree(), "venue_info"),
		IMM.prompt_for(get_tree(), "skip_anim"), IMM.prompt_for(get_tree(), "mute")], int(15 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)
	keys_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	keys_l.custom_minimum_size = Vector2(380.0 * u, 0)
	ctl.add_child(keys_l)
	var how := W.button("게임 방법 보기", "secondary", int(16 * u), Vector2(0, 46.0 * u))
	# while paused only modal_layer runs: the help screen must live there, or it could not be read or closed
	how.pressed.connect(func(): modal_layer.add_child(HelpScreen.new()))
	ctl.add_child(how)
	var view := get_viewport_rect().size
	var tabs := SettingsPanel.build(u, {
		"menu": false, "tree": get_tree(),
		"on_language": func(_code):
			_on_language_changed()
			(func():
				_close_pause()
				_on_exit_pressed()).call_deferred(),
		"extra": [["조작", ctl]],
		"max_size": Vector2(view.x * 0.94 - 70.0 * u, view.y * 0.92 - 250.0 * u),
	})
	vb.add_child(tabs)
	var stay := W.button("계속하기", "primary", int(19 * u), Vector2(176.0 * u, 52.0 * u))
	var leave := W.button("나가기", "danger", int(19 * u), Vector2(176.0 * u, 52.0 * u))
	top_btns.add_child(stay)
	top_btns.add_child(leave)
	modal_layer.add_child(panel)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_paused(true)
	stay.pressed.connect(_close_pause)
	leave.pressed.connect(func():
		_set_paused(false)
		exit_requested.emit())
	stay.grab_focus()


## The language changed in the middle of a game: nothing about the game changes. Labels re-translate by themselves; what
## was put together from numbers is refreshed here, and everything drawn by hand redraws.
func _on_language_changed() -> void:
	for pid in chips:
		chips[pid].player_name = _nm(pid)
	_update_hud()
	_refresh_now()                      # the narration line comes back in the new language at once
	if _awaiting_select:
		_update_hint()
	get_tree().root.propagate_call("queue_redraw")


func _is_nav_event(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return false
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action_pressed(a):
			return true
	return false


## an overlay other than the negotiation panel (pause / venue card / round board / help...) owns the input
func _other_overlay_open() -> bool:
	for c in modal_layer.get_children():
		if c.name != "Coach" and not c.is_queued_for_deletion():
			return true
	for c in get_children():
		if c is Control and c.visible and c.z_index >= 60:
			return true
	return false
