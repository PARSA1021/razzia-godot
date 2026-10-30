extends RefCounted
## The settings, shared by the main menu and the in-game pause panel (Phase 29). They used to be one long column inside a
## scroll area; now they are split into tabs that each fit on the screen, so nothing has to be scrolled:
##   게임   language (pause), animation speed (menu), reduce motion, dialogue scenes, first-game tips (menu)
##   소리   mix presets, master (with mute) / music / effects / buttons, mute in background
##   화면   performance preset and window mode (only where the platform manager runs)
##   조작   (pause) the buttons of the device in use + the rules screen
## Every change is saved at once, as before.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const SoundPanel = preload("res://ui/sound_panel.gd")


static func _row(u: float, label_text: String, ctl: Control, translate := true) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(10 * u))
	var l := W.label(label_text, int(17 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	l.custom_minimum_size = Vector2(118.0 * u, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not translate:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hb.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctl)
	return hb


static func _page(u: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(12 * u))
	return v


## ctx: {"menu": bool, "tree": SceneTree, "on_language": Callable(code), "extra": [[label, Control], ...], "max_size": Vector2}
static func build(u: float, ctx: Dictionary) -> VBoxContainer:
	var menu: bool = ctx.get("menu", false)
	var tree: SceneTree = ctx.get("tree", null)
	var labels: Array = []
	var pages: Array = []

	# --- 게임
	var g := _page(u)
	if not menu:
		var lgseg := W.segmented(["한국어", "English"], 0 if Settings.language == "ko" else 1, func(i):
			var code: String = "ko" if i == 0 else "en"
			if code != Settings.language:
				Settings.set_language(code)
				var cb: Callable = ctx.get("on_language", Callable())
				if cb.is_valid():
					cb.call(code), int(15 * u))
		lgseg.name = "LangChoice"
		for b in lgseg.get_children():
			if b is Button:
				b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # each language names itself
		g.add_child(_row(u, "언어 · Language", lgseg, false))
	if menu:
		g.add_child(_row(u, "연출 속도", W.segmented(["보통 (1.0x)", "빠르게 (2.0x)"], 1 if Settings.speed_name == "FAST" else 0, func(i):
			Settings.speed_name = "FAST" if i == 1 else "NORMAL"
			Settings.save_settings(), int(16 * u))))
	g.add_child(_row(u, "모션 줄이기", W.segmented(["OFF", "ON  (움직임만 줄임)"], 1 if Settings.reduce_motion else 0, func(i):
		Settings.reduce_motion = i == 1
		Settings.save_settings(), int(15 * u))))
	g.add_child(_row(u, "대화 장면", W.segmented(["전체", "핵심만", "OFF"], 2 if not Settings.dialogue_on else (0 if Settings.dialogue_mid else 1), func(i):
		Settings.dialogue_on = i != 2
		Settings.dialogue_mid = i == 0
		Settings.save_settings(), int(15 * u))))
	if menu:
		g.add_child(_row(u, "처음 안내", W.segmented(["ON", "OFF"], 0 if Settings.coach_on else 1, func(i):
			Settings.coach_on = i == 0
			Settings.save_settings(), int(16 * u))))
	var rmh := W.label("모션 줄이기를 켜면 카드 이동·깜빡임 연출이 줄어 진행이 빨라져요. 평소엔 OFF 권장.", int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	rmh.autowrap_mode = TextServer.AUTOWRAP_WORD
	rmh.custom_minimum_size = Vector2(380.0 * u, 0)
	g.add_child(rmh)
	labels.append("게임 진행")
	pages.append(g)

	# --- 소리
	var s := _page(u)
	s.add_child(SoundPanel.build(u))
	labels.append("소리")
	pages.append(s)

	# --- 화면 (performance / window), only with the platform manager
	var sdm: Node = tree.root.get_node_or_null("SteamDeckManager") if tree != null else null
	if sdm != null:
		var d := _page(u)
		var qkeys := ["HIGH", "BALANCED", "BATTERY"]
		d.add_child(_row(u, "성능", W.segmented(["고품질", "균형", "배터리 절약"], maxi(0, qkeys.find(Settings.quality_effective)), func(i):
			sdm.set_quality(qkeys[i]), int(15 * u))))
		var dkeys := ["fullscreen", "windowed"]
		var full: bool = DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		d.add_child(_row(u, "화면", W.segmented(["전체 화면", "창"], 0 if full else 1, func(i):
			sdm.set_display_mode(dkeys[i]), int(15 * u))))
		var dh := W.label("배터리 절약은 30fps로 그리고, 화면이 바뀌지 않으면 다시 그리지 않습니다.", int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
		dh.autowrap_mode = TextServer.AUTOWRAP_WORD
		dh.custom_minimum_size = Vector2(380.0 * u, 0)
		d.add_child(dh)
		labels.append("화면")
		pages.append(d)

	# --- 저장 관리 (Save Management)
	var sm := _page(u)
	var SaveStore = preload("res://ui/save_store.gd")
	var slot_labels: Array = []
	for n in SaveStore.SLOTS:
		slot_labels.append(T.t("슬롯 %d") % n)
	var active_slot_idx: int = clampi(SaveStore.slot - 1, 0, slot_labels.size() - 1)
	var slot_hint := W.label("", int(14 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	slot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	var update_slot_hint := func(sn: int) -> void:
		var info := SaveStore.slot_info(sn)
		if not info["exists"]:
			slot_hint.text = T.t("슬롯 %d: 비어 있음 (새 게임 시작 시 여기에 자동 저장됩니다)") % sn
			slot_hint.add_theme_color_override("font_color", T.TEXT_DIM)
		elif not info["ok"]:
			slot_hint.text = T.t("슬롯 %d: 읽을 수 없는 저장 파일") % sn
			slot_hint.add_theme_color_override("font_color", T.DANGER)
		else:
			var rnd: String = T.t("마지막 라운드") if info["final"] else (T.t("라운드 %d") % int(info["round"]))
			slot_hint.text = T.t("슬롯 %d: %d인 · %s · 진행 중") % [sn, int(info["players"]), rnd]
			slot_hint.add_theme_color_override("font_color", T.GOLD)
			
	update_slot_hint.call(SaveStore.slot)
	
	var slot_seg := W.segmented(slot_labels, active_slot_idx, func(i):
		var chosen: int = i + 1
		SaveStore.use_slot(chosen)
		update_slot_hint.call(chosen)
	, int(15 * u))
	sm.add_child(_row(u, "저장 슬롯", slot_seg))
	sm.add_child(slot_hint)
	var sm_desc := W.label(T.t("게임은 활성 슬롯에 자동으로 저장됩니다. 기존 저장 파일은 안전하게 보관됩니다."), int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	sm_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	sm.add_child(sm_desc)
	labels.append("저장 관리")
	pages.append(sm)

	for e in ctx.get("extra", []):
		labels.append(e[0])
		pages.append(e[1])
	var t := W.tabs(labels, pages, int(16 * u), 0, ctx.get("max_size", Vector2(-1, -1)))
	t.name = "SettingsTabs"
	return t
