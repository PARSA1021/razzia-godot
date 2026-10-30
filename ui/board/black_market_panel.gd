extends Control
## BlackMarketPanel (Phase 3 & Relic Mode Redesign):
## 1920s Chicago Speakeasy Black Market Shop.
## Appears between rounds in Relic Mode after round settlement.
## Features dynamic catalog, rarities, reroll, bankroll preview, and noir flavor.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Audio = preload("res://ui/audio.gd")
const Settings = preload("res://ui/settings.gd")
const RelicManager = preload("res://engine/relic_manager.gd")

signal closed
signal relic_bought(relic_id: String, price: int)

var state: Dictionary = {}
var human_id: String = "P1"
var u: float = 1.0
var landscape: bool = true

var _money_label: Label = null
var _reroll_btn: Button = null
var _offerings_box: BoxContainer = null
var _card_containers: Array = []
var _close_btn: Button = null


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

	var panel_w: float = minf(size.x - 30.0 * u, (1080.0 if landscape else 560.0) * u)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.deco(Color("0d0906fc"), T.GOLD, Vector4(24, 20, 24, 20), u))
	panel.custom_minimum_size = Vector2(panel_w, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * u))
	panel.add_child(vb)

	# --- Header ---
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", int(10 * u))
	vb.add_child(top_bar)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", int(2 * u))
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_box)

	var title_lbl := W.label(tr("부두 암시장"), int(26 * u), T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 800)
	title_box.add_child(title_lbl)

	var quote_lbl := W.label(
		tr("암거래상: '오늘 밤 부두에서 갓 들여온 물건들이오. 현금만 받소.'"),
		int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500
	)
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_box.add_child(quote_lbl)

	# Bankroll & Reroll Area
	var right_box := HBoxContainer.new()
	right_box.add_theme_constant_override("separation", int(8 * u))
	top_bar.add_child(right_box)

	_reroll_btn = W.button(
		tr("물품 새로고침 ($5,000)"), "secondary", int(13 * u), Vector2(170.0 * u, 40.0 * u)
	)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	right_box.add_child(_reroll_btn)

	var bankroll_box := PanelContainer.new()
	bankroll_box.add_theme_stylebox_override("panel", W.sb(Color("1f160ef0"), T.BRASS, 1, int(8 * u), Vector4(14, 8, 14, 8)))
	right_box.add_child(bankroll_box)

	var cur_money: int = RelicManager.get_player_money(state, human_id)
	_money_label = W.label(tr("보유 자금  %s") % T.money(cur_money), int(17 * u), T.GOLD, "money", HORIZONTAL_ALIGNMENT_RIGHT, 800)
	bankroll_box.add_child(_money_label)

	vb.add_child(W.rule(u, 1))

	# --- Offerings Grid ---
	if landscape:
		_offerings_box = HBoxContainer.new()
	else:
		_offerings_box = VBoxContainer.new()
	_offerings_box.add_theme_constant_override("separation", int(10 * u))
	vb.add_child(_offerings_box)

	_rebuild_cards()

	vb.add_child(W.rule(u, 1))

	# --- Footer ---
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", int(16 * u))
	vb.add_child(footer)

	var hint_lbl := W.label(
		tr("※ 맺은 연줄은 이번 게임이 끝날 때까지 유지됩니다."),
		int(13 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500
	)
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint_lbl)

	_close_btn = W.button(tr("다음 라운드로 ▸"), "primary", int(17 * u), Vector2(230.0 * u, 46.0 * u))
	_close_btn.pressed.connect(_on_close_pressed)
	footer.add_child(_close_btn)

	_update_reroll_button()
	W.arm_focus(_close_btn, 0.4)


func _rebuild_cards() -> void:
	for c in _offerings_box.get_children():
		c.queue_free()
	_card_containers.clear()

	var offerings: Array = RelicManager.get_shop_offerings(state, human_id)
	for item in offerings:
		var card_view := _build_relic_card(item)
		card_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_offerings_box.add_child(card_view)
		_card_containers.append({"id": item["id"], "view": card_view, "data": item})


func _build_relic_card(item: Dictionary) -> Control:
	var p := PanelContainer.new()
	var is_owned: bool = bool(item.get("owned", false))
	var can_afford: bool = bool(item.get("canAfford", false))
	var rarity: String = str(item.get("rarity", "COMMON"))
	var price: int = int(item.get("price", 0))
	var cur_m: int = RelicManager.get_player_money(state, human_id)

	var border_col: Color = T.BRASS
	if is_owned:
		border_col = Color("385038") # subtle emerald/gold for owned
	elif rarity == "RARE":
		border_col = T.GOLD
	elif rarity == "UNCOMMON":
		border_col = Color("6888aa") # steel blue
	else:
		border_col = T.BRASS

	var bw: int = 2 if (is_owned or rarity == "RARE") else 1
	p.add_theme_stylebox_override("panel", W.sb(Color("140f0af6"), border_col, bw, int(8 * u), Vector4(12, 10, 12, 10)))

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", int(6 * u))
	p.add_child(cv)

	# Top Badges: Rarity & Type
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", int(6 * u))
	cv.add_child(badge_row)

	var r_name: String = "[일반]" if rarity == "COMMON" else ("[고급]" if rarity == "UNCOMMON" else "[희귀]")
	var r_col: Color = T.BRASS if rarity == "COMMON" else (Color("8cb0d0") if rarity == "UNCOMMON" else T.GOLD)
	var r_lbl := W.label(r_name, int(11 * u), r_col, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	badge_row.add_child(r_lbl)

	var type_str: String = str(item.get("type", ""))
	var type_name: String = "[정보]" if type_str == "INFO" else ("[결투]" if type_str == "DUEL" else ("[시너지]" if type_str == "SYNERGY" else "[경제]"))
	var type_lbl := W.label(type_name, int(11 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	badge_row.add_child(type_lbl)

	# Icon + Name
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(8 * u))
	cv.add_child(head)

	var icon_tex: Texture2D = T.relic_icon(str(item.get("id", "")))
	var icon_img := W.icon_rect(icon_tex, Vector2(26.0 * u, 26.0 * u), T.GOLD)
	head.add_child(icon_img)

	var name_txt: String = tr(str(item.get("name_ko", item.get("name", ""))))
	var name_lbl := W.label(name_txt, int(15 * u), T.GOLD if (is_owned or rarity == "RARE") else T.TEXT, "title", HORIZONTAL_ALIGNMENT_LEFT, 800)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.add_child(name_lbl)

	# Description
	var desc_txt: String = tr(str(item.get("desc", "")))
	var desc_lbl := W.label(desc_txt, int(12 * u), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_LEFT, 500)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(0, 50.0 * u)
	cv.add_child(desc_lbl)

	cv.add_child(W.rule(u, 1))

	# Price and Balance Calculation
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", int(6 * u))
	cv.add_child(price_row)

	var price_lbl := W.label(T.money(price), int(18 * u), T.GOLD if can_afford else T.TEXT_DIM, "money", HORIZONTAL_ALIGNMENT_LEFT, 800)
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(price_lbl)

	if not is_owned:
		if can_afford:
			var remain: int = cur_m - price
			var remain_lbl := W.label(tr("잔액 %s") % T.money(remain), int(11 * u), T.TEXT_DIM, "money", HORIZONTAL_ALIGNMENT_RIGHT, 500)
			price_row.add_child(remain_lbl)
		else:
			var deficit: int = price - cur_m
			var deficit_lbl := W.label(tr("부족 %s") % T.money(deficit), int(11 * u), T.DANGER, "money", HORIZONTAL_ALIGNMENT_RIGHT, 600)
			price_row.add_child(deficit_lbl)

	# Action Button
	var btn: Button
	if is_owned:
		btn = W.button(tr("보유 중"), "secondary", int(13 * u), Vector2(0, 36.0 * u))
		btn.disabled = true
	elif can_afford:
		btn = W.button(tr("구매"), "primary", int(14 * u), Vector2(0, 36.0 * u))
		btn.pressed.connect(func(): _on_buy_pressed(item["id"]))
	else:
		btn = W.button(tr("자금 부족"), "secondary", int(12 * u), Vector2(0, 36.0 * u))
		btn.disabled = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(btn)

	return p


func _on_buy_pressed(relic_id: String) -> void:
	var res: Dictionary = RelicManager.buy_relic(state, human_id, relic_id)
	if not res.get("ok", false):
		return

	Audio.play("relic_chime")
	Audio.play("chip_clink")
	relic_bought.emit(relic_id, int(res.get("price", 0)))
	_refresh_views()


func _on_reroll_pressed() -> void:
	var res: Dictionary = RelicManager.reroll_shop(state, human_id)
	if not res.get("ok", false):
		return

	Audio.play("shuffle")
	_refresh_views()


func _update_reroll_button() -> void:
	if _reroll_btn != null and is_instance_valid(_reroll_btn):
		var can_reroll: bool = RelicManager.can_afford_reroll(state, human_id)
		_reroll_btn.disabled = not can_reroll


func _refresh_views() -> void:
	var cur_money: int = RelicManager.get_player_money(state, human_id)
	if _money_label != null and is_instance_valid(_money_label):
		_money_label.text = tr("보유 자금  %s") % T.money(cur_money)

	_update_reroll_button()
	_rebuild_cards()


func _on_close_pressed() -> void:
	Audio.play("coin")
	closed.emit()
