extends PanelContainer
## Compact Duel View: Condensed 1~1.5s on-bar presentation for AI-vs-AI duels.
## Sits directly over the venue card without dimming the screen or opening a full-screen modal.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")

var _duel_ev := {}
var _names := {}
var _u: float = 1.0

var _head_lbl: Label
var _prize_lbl: Label

var _a_box: VBoxContainer
var _a_name_lbl: Label
var _a_calc_lbl: Label

var _b_box: VBoxContainer
var _b_name_lbl: Label
var _b_calc_lbl: Label

var _status_lbl: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(duel_ev: Dictionary, names: Dictionary, u: float) -> void:
	_duel_ev = duel_ev
	_names = names
	_u = u

	custom_minimum_size = Vector2(240.0 * u, 108.0 * u)
	add_theme_stylebox_override("panel", W.deco(Color("16120ef6"), T.GOLD_DIM, Vector4(10, 8, 10, 8), u))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", int(4 * u))
	add_child(vb)

	# 1. Header: Venue name + 결투 + prize
	var hb_top := HBoxContainer.new()
	hb_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb_top.add_theme_constant_override("separation", int(6 * u))
	vb.add_child(hb_top)

	var icon_tex: Texture2D = T.system_icon("challenger")
	if icon_tex != null:
		var ic := W.icon_rect(icon_tex, Vector2(14.0 * u, 14.0 * u), T.GOLD)
		hb_top.add_child(ic)

	var bar_name: String = T.bar_name(str(duel_ev.get("barId", "")))
	_head_lbl = W.label("%s %s" % [bar_name, tr("결투")], int(round(13.0 * u)), T.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT, 700)
	_head_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_top.add_child(_head_lbl)

	var prize: int = int(duel_ev.get("prize", 0))
	_prize_lbl = W.label(T.money(prize), int(round(13.0 * u)), T.GOLD, "money", HORIZONTAL_ALIGNMENT_RIGHT, 700)
	hb_top.add_child(_prize_lbl)

	vb.add_child(W.rule(u, 1))

	# 2. Players VS row
	var hb_vs := HBoxContainer.new()
	hb_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb_vs.add_theme_constant_override("separation", int(6 * u))
	vb.add_child(hb_vs)

	var p_a: String = str(duel_ev.get("playerA", ""))
	var p_b: String = str(duel_ev.get("playerB", ""))
	var sym_a: int = int(duel_ev.get("symbolA", 0))
	var sym_b: int = int(duel_ev.get("symbolB", 0))

	# Left side: Player A
	_a_box = VBoxContainer.new()
	_a_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_a_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_a_name_lbl = W.label(str(_names.get(p_a, p_a)), int(round(12.0 * u)), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_a_calc_lbl = W.label("%d + 🎲 ?" % sym_a, int(round(12.0 * u)), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_a_box.add_child(_a_name_lbl)
	_a_box.add_child(_a_calc_lbl)
	hb_vs.add_child(_a_box)

	# VS center
	var vs_lbl := W.label("VS", int(round(11.0 * u)), T.TEXT_DIM, "title", HORIZONTAL_ALIGNMENT_CENTER, 700)
	vs_lbl.custom_minimum_size = Vector2(24.0 * u, 0)
	hb_vs.add_child(vs_lbl)

	# Right side: Player B
	_b_box = VBoxContainer.new()
	_b_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_b_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b_name_lbl = W.label(str(_names.get(p_b, p_b)), int(round(12.0 * u)), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_b_calc_lbl = W.label("%d + 🎲 ?" % sym_b, int(round(12.0 * u)), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_b_box.add_child(_b_name_lbl)
	_b_box.add_child(_b_calc_lbl)
	hb_vs.add_child(_b_box)

	# 3. Status label
	_status_lbl = W.label(tr("주사위 굴리는 중…"), int(round(11.0 * u)), T.TEXT_DIM, "ui", HORIZONTAL_ALIGNMENT_CENTER, 700)
	_status_lbl.pivot_offset = Vector2(100.0 * u, 8.0 * u)
	vb.add_child(_status_lbl)

	# Pop-in animation
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	pivot_offset = custom_minimum_size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func position_over_bar(bv: Control, u: float, screen_size: Vector2) -> void:
	if not is_instance_valid(bv):
		return
	var r: Rect2 = bv.get_global_rect()
	var tx := r.position.x + (r.size.x - custom_minimum_size.x) * 0.5
	var ty := r.position.y + maxf(8.0 * u, (r.size.y - custom_minimum_size.y) * 0.3)
	tx = clampf(tx, 10.0 * u, screen_size.x - custom_minimum_size.x - 10.0 * u)
	ty = clampf(ty, 10.0 * u, screen_size.y - custom_minimum_size.y - 10.0 * u)
	position = Vector2(tx, ty)


func set_rolls(roll_ev: Dictionary) -> void:
	var roll_a: int = int(roll_ev.get("rollA", 0))
	var roll_b: int = int(roll_ev.get("rollB", 0))
	var sym_a: int = int(_duel_ev.get("symbolA", 0))
	var sym_b: int = int(_duel_ev.get("symbolB", 0))
	var tot_a := sym_a + roll_a
	var tot_b := sym_b + roll_b

	_a_calc_lbl.text = "%d + 🎲%d = %d" % [sym_a, roll_a, tot_a]
	_b_calc_lbl.text = "%d + 🎲%d = %d" % [sym_b, roll_b, tot_b]
	_a_calc_lbl.add_theme_color_override("font_color", T.TEXT)
	_b_calc_lbl.add_theme_color_override("font_color", T.TEXT)
	_status_lbl.text = tr("점수 계산 중…")


func resolve(finish_ev: Dictionary) -> void:
	var winner_id: String = str(finish_ev.get("winnerId", ""))
	var is_a_win := winner_id == str(_duel_ev.get("playerA", ""))
	var tie := bool(finish_ev.get("tie", false))
	var win_name: String = str(_names.get(winner_id, winner_id))

	if is_a_win:
		_a_name_lbl.add_theme_color_override("font_color", T.GOLD)
		_a_calc_lbl.add_theme_color_override("font_color", T.GOLD)
		_b_name_lbl.add_theme_color_override("font_color", T.TEXT_DIM)
		_b_calc_lbl.add_theme_color_override("font_color", T.TEXT_DIM)
	else:
		_b_name_lbl.add_theme_color_override("font_color", T.GOLD)
		_b_calc_lbl.add_theme_color_override("font_color", T.GOLD)
		_a_name_lbl.add_theme_color_override("font_color", T.TEXT_DIM)
		_a_calc_lbl.add_theme_color_override("font_color", T.TEXT_DIM)

	if tie:
		_status_lbl.text = tr("★ %s 승리! (동점 도전자)") % win_name
	else:
		_status_lbl.text = tr("★ %s 승리!") % win_name
	_status_lbl.add_theme_color_override("font_color", T.OK)

	# Gentle win bounce on status
	var tw := create_tween()
	tw.tween_property(_status_lbl, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_status_lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD)


func fade_out_and_free() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
