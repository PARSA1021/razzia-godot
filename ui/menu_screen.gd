extends Control
## Title / new-game screen (Phase 10). Emits start_requested(config) or continue_requested.
## Landscape: title + main buttons on the left, the game-setup card on the right. Portrait: one scrolling column.
## The backdrop is the six venue posters, darkened; nothing here flashes (the only motion is a short fade-in, none with reduced motion).

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Portrait = preload("res://ui/portrait.gd")
const SaveStore = preload("res://ui/save_store.gd")
const Audio = preload("res://ui/audio.gd")
const SoundPanel = preload("res://ui/sound_panel.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const RecordsScreen = preload("res://ui/records_screen.gd")
const HelpScreen = preload("res://ui/help_screen.gd")
const I18n = preload("res://ui/i18n.gd")

signal start_requested(config)        # config["slot"] = the save slot the new game lives in
signal continue_requested(slot)
signal tutorial_requested(config)     # Sal's tutorial, then a real game with this config

const BARS := ["COLIBRI", "COTTON_CLUB", "HAVANA_BAR", "THE_JUNGLE", "LINCOLNS", "JAZZ_HOUSE"]

var player_count := 4
var difficulty := "NORMAL"
var game_mode := "CLASSIC"
var save_slot := 0                   # 0 = not chosen yet: the first empty slot (see _default_slot)
var _slot_hint: Label
var _count_label: Label
var _roster_lbl: Label
var _rule_hint: Label
var _custom_card: Control
var _custom_holder: Control
var _dots: Control
var _help: Control
var _content: Control
var _portrait := false
var _built := false


func _ready() -> void:
	Audio.cue("menu")
	Audio.start_music()
	Settings.load_settings()
	player_count = Settings.last_player_count
	difficulty = Settings.last_difficulty
	game_mode = Settings.last_game_mode
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	resized.connect(_on_resized)
	_portrait = size.y > size.x
	if save_slot == 0:
		save_slot = _default_slot()
	_build_content()
	_built = true


func _on_resized() -> void:
	if not _built:
		return
	var p := size.y > size.x
	if p != _portrait:
		_portrait = p
		_build_content()


## ------------------------------------------------------------------ backdrop

func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = T.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for id in BARS:
		var tex := T.art("bar", id)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tr.modulate = Color(0.62, 0.54, 0.46, 1.0)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	# vignette: dark edges, calmer centre; plus a vertical fade so the lower buttons stay readable
	var vg := Gradient.new()
	vg.colors = PackedColorArray([Color(0.04, 0.03, 0.02, 0.22), Color(0.04, 0.03, 0.02, 0.62), Color(0.02, 0.015, 0.01, 0.94)])
	vg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = vg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var vtex := TextureRect.new()
	vtex.texture = gt
	vtex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vtex.stretch_mode = TextureRect.STRETCH_SCALE
	vtex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vtex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vtex)


## ------------------------------------------------------------------ content

func _build_content() -> void:
	if _content != null:
		_content.queue_free()
	# Phase 29: no scroll area. The whole menu always fits the screen (FitBox scales it as one piece if a short screen
	# needs it); the preferences live in their own panel, so the column never grows past the screen.
	var fit := W.FitBox.new()
	fit.name = "MenuFit"
	fit.align_top = false
	fit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fit)
	move_child(fit, get_child_count() - 1 if _help == null else get_child_count() - 2)
	_content = fit
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 44)          # clear of the language switch in the corner
	margin.add_theme_constant_override("margin_bottom", 20)
	fit.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var left := _build_left()
	left.custom_minimum_size = Vector2(minf(480.0, maxf(320.0, size.x - 56.0)), 0)
	center.add_child(left)
	
	if _custom_holder != null and is_instance_valid(_custom_holder):
		_custom_holder.queue_free()
	_custom_holder = Control.new()
	_custom_holder.name = "CustomCardHolder"
	_custom_holder.visible = false
	add_child(_custom_holder)
	_custom_card = _build_card()
	_custom_holder.add_child(_custom_card)
	
	_refresh()
	_fade_in([left])
	_build_lang_switch()


## Language (한국어 / English): always in the top corner, readable in either language, so a player who cannot read the
## current one can still find it. Changing it rebuilds the menu at once; the game setup chosen so far is kept.
func _build_lang_switch() -> void:
	var old := get_node_or_null("LangSwitch")
	if old != null:
		old.queue_free()
	var seg := W.segmented([I18n.LABELS["ko"], I18n.LABELS["en"]], 0 if Settings.language == "ko" else 1, func(i):
		var code: String = "ko" if i == 0 else "en"
		if code != Settings.language:
			Settings.set_language(code)
			_build_content.call_deferred(), 14, 34.0)
	seg.name = "LangSwitch"
	for b in seg.get_children():
		if b is Button:
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # each language names itself
			b.focus_mode = Control.FOCUS_ALL
	seg.custom_minimum_size = Vector2(200, 0)
	add_child(seg)
	# pinned to the top-right corner, growing to the left by whatever its labels need (never past the screen edge)
	seg.anchor_left = 1.0
	seg.anchor_right = 1.0
	seg.anchor_top = 0.0
	seg.anchor_bottom = 0.0
	seg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	seg.offset_right = -12.0
	seg.offset_left = -12.0
	seg.offset_top = 12.0


func _fade_in(nodes: Array) -> void:
	var d := Settings.dur(0.45)
	var i := 0
	for n in nodes:
		if d <= 0.0:
			n.modulate.a = 1.0
			continue
		n.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 1.0, d).set_delay(0.12 * i)
		i += 1


static func _chip(text: String, color: Color, size: int = 12) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", W.sb(Color(color, 0.15), color, 1, 14, Vector4(10, 4, 10, 4)))
	p.add_child(W.label(text, size, color, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700))
	return p


func _build_left() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var title_size := 88 if _portrait else 96
	
	# Header & Logo Section
	var logo_box := VBoxContainer.new()
	logo_box.add_theme_constant_override("separation", 3)
	
	var t := W.label("RAZZIA", title_size, T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	t.add_theme_color_override("font_outline_color", Color("140b04"))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	t.add_theme_constant_override("shadow_offset_y", 6)
	logo_box.add_child(t)
	
	var orn := Ornament.new()
	orn.custom_minimum_size = Vector2(0, 16)
	logo_box.add_child(orn)
	
	logo_box.add_child(W.label(T.t("시카고 루프의 마지막 한 판"), 16, T.BRASS, "title", HORIZONTAL_ALIGNMENT_CENTER, 700))
	var sub := W.label(T.t("여섯 술집, 한 번의 단속 · 3~8인 카드 게임"), 14, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500)
	logo_box.add_child(sub)
	v.add_child(logo_box)
	
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	
	var first: Button = null
	
	# ① QUICK START (가장 크고 눈에 띄게, 기본 포커스)
	var quick_start := W.button(T.t("빠른 시작"), "primary", 22, Vector2(0, 64))
	quick_start.name = "NewGameButton"
	quick_start.pressed.connect(_on_quick_start)
	v.add_child(quick_start)
	first = quick_start
	
	if not Settings.tutorial_done:
		var tut_hint := W.label(T.t("💡 처음이라면 튜토리얼을 추천해요 (3분)"), 13, Color(T.GOLD, 0.95), "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)
		v.add_child(tut_hint)
	
	# ② 이어하기 (저장된 게임이 있을 때만 표시)
	var any := SaveStore.any_save()
	if any:
		var c := W.button(T.t("이어하기"), "secondary", 19, Vector2(0, 52))
		c.name = "ContinueButton"
		c.pressed.connect(_show_slots)
		v.add_child(c)
	
	# ③ 튜토리얼
	var tut_btn := W.button(T.t("튜토리얼"), "secondary", 18, Vector2(0, 48))
	tut_btn.name = "TutorialButton"
	tut_btn.pressed.connect(func():
		Audio.play("card_snap")
		tutorial_requested.emit(_config())
	)
	v.add_child(tut_btn)
	
	# ④ 사용자 지정 게임
	var custom_btn := W.button(T.t("사용자 지정 게임"), "secondary", 18, Vector2(0, 48))
	custom_btn.name = "CustomGameButton"
	custom_btn.pressed.connect(_show_custom_game)
	v.add_child(custom_btn)
	
	# ⑤ 게임 방법 및 기록
	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	
	var how := W.button(T.t("게임 방법"), "secondary", 16, Vector2(0, 44))
	how.name = "HowToPlayButton"
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.pressed.connect(_toggle_help)
	util_row.add_child(how)
	
	var rec := W.button(T.t("기록"), "secondary", 16, Vector2(0, 44))
	rec.name = "RecordsButton"
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.pressed.connect(func(): add_child(RecordsScreen.new()))
	util_row.add_child(rec)
	
	v.add_child(util_row)
	
	# ⑥ 설정
	var settings_btn := W.button(T.t("설정"), "secondary", 17, Vector2(0, 46))
	settings_btn.name = "SettingsButton"
	settings_btn.pressed.connect(_show_settings)
	v.add_child(settings_btn)
	
	# ⑦ 종료 (PC에서만)
	if OS.get_name() in ["macOS", "Windows", "Linux", "FreeBSD"] and not OS.has_feature("mobile"):
		var quit_btn := W.button(T.t("게임 종료"), "ghost", 15, Vector2(0, 38))
		quit_btn.name = "QuitButton"
		quit_btn.pressed.connect(func(): get_tree().quit())
		v.add_child(quit_btn)
	
	first.set_meta("default_focus", true)
	_default_btn = first
	(func():
		var fo := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if is_instance_valid(first) and first.is_inside_tree() and (fo == null or not is_ancestor_of(fo)):
			first.grab_focus()).call_deferred()
	
	return v


## 1920s Chicago Speakeasy VIP Voucher Card (Balatro-style interactive tutorial)
func _build_tutorial_card() -> Control:
	var card := PanelContainer.new()
	var bg_col := Color("140f0af6")
	var border_col := Color(T.GOLD, 0.85) if not Settings.tutorial_done else Color(T.BRASS, 0.55)
	card.add_theme_stylebox_override("panel", W.sb(bg_col, border_col, 2, 12, Vector4(16, 12, 16, 12)))
	card.custom_minimum_size = Vector2(0, 114)
	
	# Micro-interaction: subtle hover border glow
	card.mouse_entered.connect(func():
		if not Settings.reduce_motion and is_instance_valid(card):
			card.add_theme_stylebox_override("panel", W.sb(Color("1a140df8"), T.GOLD, 2, 12, Vector4(16, 12, 16, 12)))
	)
	card.mouse_exited.connect(func():
		if is_instance_valid(card):
			card.add_theme_stylebox_override("panel", W.sb(bg_col, border_col, 2, 12, Vector4(16, 12, 16, 12)))
	)
	
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	
	# Top voucher ribbon
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	var sticker := _chip(T.t("🃏 시카고 카드룸 VIP 바우처"), T.GOLD if not Settings.tutorial_done else T.TEXT_DIM, 11)
	top_row.add_child(sticker)
	if Settings.tutorial_done:
		var done_badge := _chip(T.t("✓ 이수 완료 (복습 가능)"), T.OK, 11)
		top_row.add_child(done_badge)
	else:
		var rec_badge := _chip(T.t("★ 신입 추천 코스"), T.DANGER, 11)
		top_row.add_child(rec_badge)
	var time_lbl := W.label(T.t("약 5분 실전 코스"), 12, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_RIGHT, 500)
	time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(time_lbl)
	vb.add_child(top_row)
	
	# Middle Section: Sal portrait + Description + Action
	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 14)
	mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Sal Portrait in ornate brass frame
	var face_box := PanelContainer.new()
	face_box.add_theme_stylebox_override("panel", W.sb(Color("22180e"), T.GOLD, 2, 12, Vector4(4, 4, 4, 4)))
	var face := Portrait.new()
	face.character = "Sal"
	face.personality = "OPPORTUNIST"
	face.custom_minimum_size = Vector2(56, 56)
	face_box.add_child(face)
	mid_row.add_child(face_box)
	
	# Text Column
	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 4)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head_lbl := W.label(T.t("신입 탈출 과외 · Sal과 첫 3라운드"), 17, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 700)
	text_col.add_child(head_lbl)
	var desc_lbl := W.label(T.t("Sal: '신입, 카드 선택부터 판돈 협상, 경찰 단속과 결투까지 직접 플레이하며 익혀봐.'"), 12, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(desc_lbl)
	
	# 4 Core rule chips
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 6)
	for b_text in [T.t("🎲 주사위 결투"), T.t("🤝 판돈 협상"), T.t("🚨 경찰 단속"), T.t("💰 독점 보너스")]:
		badges.add_child(_chip(b_text, Color(T.BRASS, 0.8), 11))
	text_col.add_child(badges)
	mid_row.add_child(text_col)
	
	# Action buttons column (Start + Rules shortcut)
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 6)
	btn_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var tut_text := tr("튜토리얼 복습") if Settings.tutorial_done else tr("튜토리얼 시작")
	var tut_btn := W.button(tut_text, "primary" if not Settings.tutorial_done else "secondary", 14, Vector2(175, 42))
	tut_btn.name = "TutorialButton"
	tut_btn.pressed.connect(func():
		Audio.play("card_snap")
		tutorial_requested.emit(_config())
	)
	btn_col.add_child(tut_btn)
	
	var rule_btn := W.button(T.t("📖 규칙 먼저 보기"), "ghost", 12, Vector2(175, 30))
	rule_btn.name = "TutorialRuleButton"
	rule_btn.pressed.connect(func():
		Audio.play("click")
		_toggle_help()
	)
	btn_col.add_child(rule_btn)
	
	mid_row.add_child(btn_col)
	vb.add_child(mid_row)
	return card


var _default_btn: Button = null


func _row(label_text: String, ctl: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var l := W.label(T.t(label_text), 18, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	l.custom_minimum_size = Vector2(128, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctl)
	return hb


func _build_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", W.deco(Color("120e09f0"), T.GOLD, Vector4(30, 24, 30, 26), 1.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	var title_lbl := W.label("게임 준비", 20, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(title_lbl)
	head_row.add_child(_chip("CHICAGO 1920s", Color(T.BRASS, 0.8), 11))
	v.add_child(head_row)
	v.add_child(W.rule(1.0, 1))
	# players: seat dots + − / +
	var pr := VBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	var minus := W.button("−", "secondary", 26, Vector2(56, 50))
	var plus := W.button("+", "secondary", 26, Vector2(56, 50))
	_count_label = W.label("", 22, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minus.pressed.connect(func(): _set_count(player_count - 1))
	plus.pressed.connect(func(): _set_count(player_count + 1))
	prow.add_child(minus)
	prow.add_child(_count_label)
	prow.add_child(plus)
	pr.add_child(prow)
	_dots = SeatDots.new()
	_dots.custom_minimum_size = Vector2(0, 32)
	pr.add_child(_dots)
	_roster_lbl = W.label("", 12, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500)
	_roster_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	pr.add_child(_roster_lbl)
	_rule_hint = W.label("", 13, Color(T.GOLD, 0.95), "ui", HORIZONTAL_ALIGNMENT_CENTER, 600)
	_rule_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	pr.add_child(_rule_hint)
	v.add_child(pr)
	var dkeys := ["EASY", "NORMAL", "HARD"]
	var dhint := W.label(_diff_hint(difficulty), 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500)
	dhint.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_row("AI 난이도", W.segmented(["쉬움", "보통", "어려움"], maxi(0, dkeys.find(difficulty)), func(i):
		difficulty = dkeys[i]
		dhint.text = _diff_hint(difficulty), 16)))
	v.add_child(dhint)
	var mode_hint := W.label(T.t("정통 1920s 시카고 룰"), 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500)
	mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_row("게임 모드", W.segmented([T.t("클래식"), T.t("유물 모드")], 0 if game_mode == "CLASSIC" else 1, func(i):
		game_mode = "CLASSIC" if i == 0 else "RELIC"
		mode_hint.text = T.t("정통 1920s 시카고 룰") if game_mode == "CLASSIC" else T.t("라운드 사이 암시장에서 유물 구매 & 빌드업")
	, 16)))
	v.add_child(mode_hint)
	# my name at the table (personal only: the rules, the seats and the saves of other games are not touched)
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.text = Settings.player_name
	name_edit.placeholder_text = T.t("나")
	name_edit.max_length = Settings.NAME_MAX
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.add_theme_font_override("font", T.font("ui", 700))
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.add_theme_color_override("font_color", T.TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", Color(T.TEXT_DIM, 0.7))
	name_edit.add_theme_stylebox_override("normal", W.sb(Color("1d1710"), Color(T.BRASS, 0.6), 1, 8, Vector4(12, 6, 12, 6)))
	name_edit.add_theme_stylebox_override("focus", W.sb(Color("241c11"), T.GOLD, 2, 8, Vector4(12, 6, 12, 6)))
	name_edit.select_all_on_focus = true
	var commit := func(_t = null) -> void:
		var clean := Settings.clean_name(name_edit.text)
		if clean != Settings.player_name:
			Settings.player_name = clean
			Settings.save_settings()
		if name_edit.text != clean and not name_edit.has_focus():
			name_edit.text = clean
	name_edit.text_changed.connect(commit)
	name_edit.text_submitted.connect(func(t):
		commit.call(t)
		name_edit.text = Settings.player_name
		name_edit.release_focus())
	name_edit.focus_exited.connect(func():
		commit.call()
		name_edit.text = Settings.player_name)
	v.add_child(_row("내 이름", name_edit))
	# which save slot this game lives in (hidden on main, managed in Settings -> 저장 관리)
	var slot_labels: Array = []
	for n in SaveStore.SLOTS:
		slot_labels.append(T.t("슬롯 %d") % n)
	_slot_hint = W.label("", 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	_slot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_slot_hint.name = "SlotHint"
	_slot_hint.visible = false
	var slot_seg := W.segmented(slot_labels, save_slot - 1, func(i):
		save_slot = i + 1
		_refresh_slot_hint(), 16)
	slot_seg.name = "SlotChoice"
	var slot_row := _row("저장 슬롯", slot_seg)
	slot_row.visible = false
	v.add_child(slot_row)
	v.add_child(_slot_hint)
	_refresh_slot_hint()
	# Action button to start game with chosen custom options
	var start_custom_btn := W.button(T.t("이 설정으로 시작"), "primary", 18, Vector2(0, 50))
	start_custom_btn.name = "CustomStartButton"
	start_custom_btn.pressed.connect(_on_custom_start)
	v.add_child(W.rule(1.0, 1))
	v.add_child(start_custom_btn)
	return p


## The preferences panel (Phase 29): 게임 / 소리 / 화면 tabs that each fit the screen. Closes with 닫기 or B / Esc.
func _show_settings() -> void:
	if has_node("SettingsModal"):
		return
	var vb := _modal("SettingsModal")
	vb.add_child(W.label("환경 설정", 24, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var hint := W.label(_sound_hint(), 14, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	var tabs := SettingsPanel.build(1.0, {"menu": true, "tree": get_tree(), "max_size": Vector2(size.x - 120.0, size.y - 260.0)})
	vb.add_child(tabs)
	vb.add_child(hint)
	var close := W.button("닫기", "primary", 18, Vector2(150, 46))
	close.name = "SettingsClose"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func():
		var m := get_node_or_null("SettingsModal")
		if m != null:
			m.queue_free())
	vb.add_child(close)
	var first: Button = tabs.get_meta("tab_buttons")[0]
	first.grab_focus.call_deferred()


func _set_count(n: int) -> void:
	player_count = clampi(n, 3, 8)
	_refresh()


func _refresh() -> void:
	if _count_label == null or not is_instance_valid(_count_label):
		return
	_count_label.text = T.t("%d명  (나 + AI %d)") % [player_count, player_count - 1]
	if _dots != null and is_instance_valid(_dots):
		_dots.count = player_count
	if _roster_lbl != null and is_instance_valid(_roster_lbl):
		var my_name := T.t("나") if Settings.seat_name() == "나" else Settings.seat_name()
		var who: Array = [my_name]
		for i in range(player_count - 1):
			who.append(T.AI_NAMES[i % T.AI_NAMES.size()])
		_roster_lbl.text = " · ".join(who)
	if _rule_hint != null and is_instance_valid(_rule_hint):
		if player_count == 3:
			_rule_hint.text = T.t("3인: 술집 4곳(Lincoln's, Jazz House 제외), 돈 카드 5장 분배, 빠른 게임 (RULE-030)")
		elif player_count <= 6:
			_rule_hint.text = T.t("4~6인: 술집 6곳, 돈 카드 7장 분배, 18장 제외, 결투 토너먼트 (RULE-029)")
		else:
			_rule_hint.text = T.t("7~8인: 술집 6곳, 전체 카드 사용, 돈 카드 7장 분배 (RULE-031)")


func _config() -> Dictionary:
	var names: Array = [Settings.seat_name()]
	for i in range(player_count - 1):
		names.append(T.AI_NAMES[i % T.AI_NAMES.size()])
	var cfg := {
		"playerCount": player_count, "seed": int(Time.get_unix_time_from_system()) & 0x7fffffff,
		"humanPlayerId": "P1", "names": names, "aiDifficulty": difficulty, "slot": save_slot,
	}
	if game_mode == "RELIC":
		cfg["relics"] = []
	return cfg


func _on_quick_start() -> void:
	Audio.play("card_snap")
	if Settings.is_test_run() and not Settings.tutorial_done:
		_ask_tutorial()
		return
	var target_slot := save_slot
	if SaveStore.slot_info(target_slot)["exists"]:
		var empty_slot := _default_slot()
		if not SaveStore.slot_info(empty_slot)["exists"]:
			target_slot = empty_slot
		else:
			_confirm_overwrite(SaveStore.slot_info(target_slot))
			return
	save_slot = target_slot
	start_requested.emit(_config())


func _show_custom_game() -> void:
	if has_node("CustomGameModal"):
		return
	var vb := _modal("CustomGameModal")
	vb.add_child(W.label(T.t("사용자 지정 게임"), 22, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800))
	if _custom_card.get_parent() != null:
		_custom_card.get_parent().remove_child(_custom_card)
	vb.add_child(_custom_card)
	_refresh()
	var close := W.button(T.t("닫기"), "secondary", 16, Vector2(140, 42))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func():
		var m := get_node_or_null("CustomGameModal")
		if m != null:
			if _custom_card.get_parent() == vb:
				vb.remove_child(_custom_card)
				_custom_holder.add_child(_custom_card)
			m.queue_free()
			var btn := find_child("CustomGameButton", true, false) as Button
			if btn != null:
				btn.grab_focus.call_deferred()
	)
	vb.add_child(close)
	var first := _custom_card.find_child("CustomStartButton", true, false) as Button
	if first != null:
		first.grab_focus.call_deferred()


func _on_custom_start() -> void:
	Audio.play("card_snap")
	Settings.last_player_count = player_count
	Settings.last_difficulty = difficulty
	Settings.last_game_mode = game_mode
	Settings.save_settings()
	var m := get_node_or_null("CustomGameModal")
	if m != null:
		if _custom_card.get_parent() == m:
			m.remove_child(_custom_card)
			_custom_holder.add_child(_custom_card)
		m.queue_free()
	_on_start()


func _on_start() -> void:
	var info := SaveStore.slot_info(save_slot)
	if info["exists"]:
		_confirm_overwrite(info)          # never lose a game in progress without asking
		return
	_go_start()


func _go_start() -> void:
	if not Settings.tutorial_done:
		_ask_tutorial()
		return
	start_requested.emit(_config())


## ------------------------------------------------------------------ save slots

## the first empty slot; with both in use, the one saved longest ago
func _default_slot() -> int:
	var oldest := 1
	var oldest_at := 1 << 62
	for n in SaveStore.SLOTS:
		var info := SaveStore.slot_info(n)
		if not info["exists"]:
			return n
		if int(info["savedAt"]) < oldest_at:
			oldest_at = int(info["savedAt"])
			oldest = n
	return oldest


static func _when(unix: int) -> String:
	if unix <= 0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


## One line about a slot: "비어 있음" / "4인 · 라운드 3 · 2026-10-22 21:04" / damaged
static func slot_line(info: Dictionary) -> String:
	if not info["exists"]:
		return T.t("비어 있음")
	if not info["ok"]:
		return T.t("읽을 수 없는 저장 파일 (불러올 때 따로 보관됩니다)")
	var rnd: String = T.t("마지막 라운드") if info["final"] else (T.t("라운드 %d") % int(info["round"]))
	return T.t("%d인 · %s · 진행 중") % [int(info["players"]), rnd] + "  ·  " + _when(int(info["savedAt"]))


func _refresh_slot_hint() -> void:
	if _slot_hint == null or not is_instance_valid(_slot_hint):
		return
	var info := SaveStore.slot_info(save_slot)
	if info["exists"]:
		_slot_hint.text = slot_line(info) + "\n" + T.t("새 게임을 시작하면 이 슬롯의 게임을 덮어씁니다 (시작 전에 확인).")
		_slot_hint.add_theme_color_override("font_color", Color("e0b56a"))
	else:
		_slot_hint.text = T.t("빈 슬롯에 저장합니다. 다른 슬롯의 게임은 그대로 남아요.")
		_slot_hint.add_theme_color_override("font_color", T.TEXT_DIM)


func _modal(name: String) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.name = name
	shade.color = Color(0, 0, 0, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 80
	add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("140f0af6"), T.GOLD, Vector4(28, 22, 28, 22), 1.0))
	panel.custom_minimum_size = Vector2(minf(560.0, size.x - 32.0), 0)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	return vb


## CONTINUE: both slots side by side (stacked on a narrow screen), each with what is in it; load is its own button.
func _show_slots() -> void:
	if has_node("SlotPanel"):
		return
	var vb := _modal("SlotPanel")
	vb.add_child(W.label("불러오기", 24, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var box: BoxContainer = VBoxContainer.new() if size.x < 760 else HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	vb.add_child(box)
	var first: Button = null
	for n in SaveStore.SLOTS:
		var info := SaveStore.slot_info(n)
		var card := PanelContainer.new()
		card.name = "Slot%d" % n
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var filled: bool = info["exists"] and info["ok"]
		card.add_theme_stylebox_override("panel", W.sb(Color("1d1710") if filled else Color("120e0a"), Color(T.GOLD, 0.8) if filled else Color(T.BRASS, 0.3), 2 if filled else 1, 10, Vector4(14, 12, 14, 12)))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		cv.add_child(W.label(T.t("슬롯 %d") % n, 20, T.GOLD if filled else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 800))
		var line := W.label(slot_line(info), 15, T.TEXT if filled else T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.custom_minimum_size = Vector2(200, 0)
		cv.add_child(line)
		if filled:
			var who: Array = info["names"]
			var nm := W.label(", ".join(who.map(func(x): return T.t(x) if x == "나" else x)), 13, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD
			nm.custom_minimum_size = Vector2(200, 0)
			cv.add_child(nm)
		var b := W.button("불러오기" if filled else ("비어 있음" if not info["exists"] else "불러오기"), "primary" if filled else "secondary", 18, Vector2(0, 46))
		b.name = "Load%d" % n
		b.disabled = not info["exists"]
		var slot_n: int = n
		b.pressed.connect(func():
			var shade := get_node_or_null("SlotPanel")
			if shade != null:
				shade.queue_free()
			continue_requested.emit(slot_n))
		cv.add_child(b)
		box.add_child(card)
		if first == null and filled:
			first = b
	var close := W.button("닫기", "secondary", 17, Vector2(140, 44))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func():
		var shade := get_node_or_null("SlotPanel")
		if shade != null:
			shade.queue_free())
	vb.add_child(close)
	(first if first != null else close).grab_focus.call_deferred()


func _confirm_overwrite(info: Dictionary) -> void:
	if has_node("OverwriteAsk"):
		return
	var vb := _modal("OverwriteAsk")
	vb.add_child(W.label(T.t("슬롯 %d을 덮어쓸까요?") % int(info["slot"]), 22, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var l := W.label(slot_line(info), 16, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(l)
	var l2 := W.label("이 슬롯의 게임은 지워지고 되돌릴 수 없습니다. 다른 슬롯은 그대로 남아요.", 15, T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(l2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var cancel := W.button("취소", "secondary", 18, Vector2(130, 48))
	var ok := W.button("덮어쓰고 시작", "danger", 18, Vector2(180, 48))
	ok.name = "OverwriteOk"
	row.add_child(cancel)
	row.add_child(ok)
	var shade := get_node("OverwriteAsk")
	cancel.pressed.connect(func(): shade.queue_free())
	ok.pressed.connect(func():
		shade.queue_free()
		_go_start())
	cancel.grab_focus.call_deferred()          # the safe answer is the default


## First NEW GAME ever: offer Sal's tutorial once (either answer counts; the menu keeps a button to take it later).
func _ask_tutorial() -> void:
	if has_node("TutorialAsk"):
		return
	var shade := ColorRect.new()
	shade.name = "TutorialAsk"
	shade.color = Color(0, 0, 0, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 80
	add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("140f0af6"), T.GOLD, Vector4(30, 24, 30, 24), 1.0))
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var face := Portrait.new()
	face.character = "Sal"
	face.personality = "OPPORTUNIST"
	face.custom_minimum_size = Vector2(84, 84)
	hb.add_child(face)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	hb.add_child(tv)
	tv.add_child(W.label("처음이야, 신입?", 24, T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800))
	var body := W.label("Sal이 세 라운드 동안 옆에서 알려 줍니다. 약 5분, 언제든 건너뛸 수 있어요.", 17, T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 600)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(380, 0)
	tv.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var skip := W.button("바로 시작", "secondary", 18, Vector2(140, 50))
	var go := W.button("튜토리얼 하기", "primary", 20, Vector2(200, 50))
	row.add_child(skip)
	row.add_child(go)
	var cfg := _config()
	go.pressed.connect(func():
		shade.queue_free()
		tutorial_requested.emit(cfg))
	skip.pressed.connect(func():
		Settings.tutorial_done = true
		Settings.save_settings()
		shade.queue_free()
		start_requested.emit(cfg))
	go.grab_focus.call_deferred()


func _toggle_help() -> void:
	if _help != null and is_instance_valid(_help):
		_help.queue_free()
		_help = null
		return
	_help = HelpScreen.new()
	_help.closed.connect(func():
		_help = null)
	add_child(_help)


## thin brass rule with a diamond in the middle
class Ornament extends Control:
	const T = preload("res://ui/tokens.gd")

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y / 2.0)
		var half := minf(size.x * 0.38, 170.0)
		draw_line(Vector2(c.x - half, c.y), Vector2(c.x - 16.0, c.y), T.BRASS, 2.0, true)
		draw_line(Vector2(c.x + 16.0, c.y), Vector2(c.x + half, c.y), T.BRASS, 2.0, true)
		var d := 7.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), T.GOLD)


## eight seats: me (gold) + the AI seats in play (brass) + empty seats (outline)
class SeatDots extends Control:
	const T = preload("res://ui/tokens.gd")
	var count := 4: set = _set_count

	func _set_count(v: int) -> void:
		count = v
		queue_redraw()

	func _draw() -> void:
		var n := 8
		var r := minf(14.0, size.y / 2.0 - 2.0)
		var step := minf(46.0, (size.x - 2.0 * r) / float(n - 1))
		var x0 := (size.x - step * float(n - 1)) / 2.0
		var f := T.font("ui", 800)
		for i in range(n):
			var c := Vector2(x0 + step * i, size.y / 2.0)
			if i == 0:
				draw_circle(c, r, T.GOLD)
				var me := T.t("나")
				var mfs := 14
				while mfs > 9 and f.get_string_size(me, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x > r * 2.0 - 3.0:
					mfs -= 1
				draw_string(f, c + Vector2(-r, 5), me, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, mfs, Color("1a120e"))
			elif i < count:
				draw_circle(c, r, Color("3a2d18"))
				draw_arc(c, r, 0, TAU, 28, T.BRASS, 2.0, true)
			else:
				draw_arc(c, r - 2.0, 0, TAU, 28, Color(T.BRASS, 0.28), 1.5, true)


## Plain-language level descriptions; the numbers are from tools/ai_sim.gd (4 players, one AI of that level against three NORMAL AIs).
## 지금 쓰는 장치에 맞는 안내 (키보드 / 게임패드 / 터치)
func _sound_hint() -> String:
	var IMM = load("res://platform/input_mode_manager.gd")
	var pause_k: String = IMM.prompt_for(get_tree(), "pause") if is_inside_tree() else "Esc"
	var mute_k: String = IMM.prompt_for(get_tree(), "mute") if is_inside_tree() else "M"
	return T.t("게임 중 음량은 %s(일시정지 메뉴), 음소거는 %s.") % [pause_k, mute_k]


static func _diff_hint(d: String) -> String:
	match d:
		"EASY":
			return "쉬움 — 실수가 잦고 제안을 쉽게 받아줘요. 처음 하거나 규칙을 익힐 때 좋아요."
		"HARD":
			return "어려움 — 실수 없이 확률을 계산하고 과감하게 승부해요. 익숙한 사람용."
		_:
			return "보통 — 균형 잡힌 상대. 가끔 실수해요."


## B / Esc closes the panel on top (settings, slot list, overwrite question, custom game), like the help and records screens
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	for n in ["OverwriteAsk", "SlotPanel", "SettingsModal", "CustomGameModal"]:
		var m := get_node_or_null(n)
		if m != null and not m.is_queued_for_deletion():
			if n == "CustomGameModal" and _custom_card.get_parent() != _custom_holder:
				_custom_card.get_parent().remove_child(_custom_card)
				_custom_holder.add_child(_custom_card)
			m.queue_free()
			get_viewport().set_input_as_handled()
			if n == "CustomGameModal":
				var cb := find_child("CustomGameButton", true, false) as Button
				if cb != null:
					cb.grab_focus.call_deferred()
			elif n == "SettingsModal":
				var sb := find_child("SettingsButton", true, false) as Button
				if sb != null:
					sb.grab_focus.call_deferred()
			else:
				var b := find_child("NewGameButton", true, false) as Button
				if b != null:
					b.grab_focus.call_deferred()
			return
