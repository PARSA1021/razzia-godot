extends Control
## StarterRelicModal (Relic Mode Redesign):
## Starter draft modal offering 3 free archetype relics at match start.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Audio = preload("res://ui/audio.gd")
const RelicManager = preload("res://engine/relic_manager.gd")

signal relic_selected(relic_id: String)

var state: Dictionary = {}
var human_id: String = "P1"
var u: float = 1.0
var landscape: bool = true


func setup(p_state: Dictionary, p_human_id: String, p_scale: float = 1.0, p_landscape: bool = true) -> void:
	state = p_state
	human_id = p_human_id
	u = p_scale
	landscape = p_landscape
	_build_ui()


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel_w: float = minf(size.x - 40.0 * u, (860.0 if landscape else 520.0) * u)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("0d0906fc"), T.GOLD, Vector4(24, 22, 24, 22), u))
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(12 * u))
	panel.add_child(vb)

	# Title & Subtitle
	var title_lbl := W.label(tr("STARTING RELIC · 초기 유물 지원"), int(24 * u), T.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	vb.add_child(title_lbl)

	var sub_lbl := W.label(
		tr("시카고 거리에 나설 준비를 하십시오. 시작 유물 1종을 무료로 획득합니다."),
		int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500
	)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(sub_lbl)

	vb.add_child(W.rule(u, 1))

	# 3 Starter Choices Grid
	var choices_box: BoxContainer
	if landscape:
		choices_box = HBoxContainer.new()
	else:
		choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", int(12 * u))
	vb.add_child(choices_box)

	var starters: Array = RelicManager.get_starter_choices()
	var first_btn: Button = null

	for item in starters:
		var card := _build_starter_card(item)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices_box.add_child(card)

		var sel_btn: Button = card.get_node_or_null("SelectButton")
		if sel_btn != null and first_btn == null:
			first_btn = sel_btn

	if first_btn != null:
		W.arm_focus(first_btn, 0.3)


func _build_starter_card(item: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", W.sb(Color("140f0af6"), T.BRASS, 1, int(8 * u), Vector4(14, 12, 14, 12)))

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", int(8 * u))
	p.add_child(cv)

	# Archetype Tag
	var type_str: String = str(item.get("type", ""))
	var tag: String = "[정보 특화]" if type_str == "INFO" else ("[결투 특화]" if type_str == "DUEL" else "[경제 특화]")
	var tag_lbl := W.label(tag, int(11 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	cv.add_child(tag_lbl)

	# Icon
	var icon_lbl := W.label(str(item.get("icon", "🎁")), int(32 * u), T.GOLD, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	cv.add_child(icon_lbl)

	# Name
	var name_txt: String = tr(str(item.get("name_ko", item.get("name", ""))))
	var name_lbl := W.label(name_txt, int(16 * u), T.TEXT, "title", HORIZONTAL_ALIGNMENT_CENTER, 800)
	cv.add_child(name_lbl)

	# Description
	var desc_txt: String = tr(str(item.get("desc", "")))
	var desc_lbl := W.label(desc_txt, int(12 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 500)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(0, 56.0 * u)
	cv.add_child(desc_lbl)

	cv.add_child(W.rule(u, 1))

	# Free Badge
	var free_lbl := W.label(tr("무료 지급 (FREE)"), int(13 * u), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 700)
	cv.add_child(free_lbl)

	var btn := W.button(tr("선택 (SELECT)"), "primary", int(14 * u), Vector2(0, 38.0 * u))
	btn.name = "SelectButton"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rid: String = item["id"]
	btn.pressed.connect(func(): _on_select(rid))
	cv.add_child(btn)

	return p


func _on_select(relic_id: String) -> void:
	Audio.play("relic_chime")
	relic_selected.emit(relic_id)
