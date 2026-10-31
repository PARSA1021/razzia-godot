extends Control
## Board base: shared state, the views, small helpers. Everything else builds on it.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const SaveStore = preload("res://ui/save_store.gd")
const HelpScreen = preload("res://ui/help_screen.gd")
const Records = preload("res://ui/records.gd")
const DialogueScene = preload("res://ui/dialogue_scene.gd")
const Characters = preload("res://ui/characters.gd")
const SummaryScreen = preload("res://ui/summary_screen.gd")
const Trace = preload("res://ui/flow_trace.gd")
const SoundPanel = preload("res://ui/sound_panel.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const Audio = preload("res://ui/audio.gd")
const IMM = preload("res://platform/input_mode_manager.gd")
const FELT_ANIMATED := "res://ui/felt.gdshader"
const FELT_STATIC := "res://ui/felt_static.gdshader"     # battery saver: same cloth, no TIME (idle frames are not redrawn)
const CardView = preload("res://ui/card_view.gd")
const BarView = preload("res://ui/bar_view.gd")
const MoneyCard = preload("res://ui/money_card_view.gd")
const RaidFX = preload("res://ui/raid_fx.gd")
const NegoPanel = preload("res://ui/nego_panel.gd")
const Eng = preload("res://engine/engine.gd")
const Util = preload("res://engine/util.gd")
const Ctl = preload("res://controller/match_controller.gd")

signal exit_requested
signal new_game_requested
signal idle(pending)              # the board waits for the human (used by tests)
signal event_played(ev)
signal nego_opened                 # event panel opened (used by screenshot tests)
signal result_board_shown          # the round-result board is on screen (used by screenshot tests)
signal tutorial_finished(choice)    # "play" | "menu" (Sal's tutorial is over or was skipped)
signal _human_action(action)

# ---- game
var state: Dictionary = {}
var ctl
var human_id := "P1"
var names := {}
var bot: Callable = Callable()    # test hook: func(pending, view, screen) -> action
var ai_script: Callable = Callable()   # test hook: MatchController.script_ai for a staged table (the tutorial sets its own)
var tutorial: Control = null      # Sal's tutorial director (Phase 24), only on the tutorial table
const TutorialDirector = preload("res://ui/tutorial_director.gd")
const TutorialPlan = preload("res://ui/tutorial_plan.gd")
var autosave_enabled := true

# ---- display model (what the screen currently shows; advanced only by replayed events)
var disp := {}

# ---- layout
var landscape := true
var u := 1.0
var _built := false
var _table_rect := Rect2()
var _tray_rect := Rect2()

# ---- nodes
var bar_order: Array = []
var bar_views := {}
var chips := {}
var hand_views: Array = []
var strip_views := {}
var table_cards := {}
var selected_view: Control = null
var my_selected_id := ""
var stat_deck
var pile
var stat_round
var stat_table
var me_chip
var exit_btn: Button
var opp_btn: Button
var opp_panel: Control
var now_label: Label
var relic_tray: HBoxContainer
var felt: ColorRect
var felt_state := ""
var felt_amount := 0.0
var confirm_btn: Button
var skip_btn: Button
var dim: ColorRect
var nego
var fx_layer: Control
var modal_layer: Control
var toast_label: Label
var final_badge: Label

# ---- flow flags
var skip := false: set = _set_skip
var _alive := true
var _grid_bottom := 0.0
var _land_x0 := 0.0
var _land_x1 := 0.0
var _round_reason := {}         # barId -> short Korean reason, derived from BAR_RESOLVED (display only)
var _round_awards := {}        # playerId -> [{bar, amount}] for this round (display only; the engine owns the money)
var _round_plays: Array = []   # this round's revealed cards (public): [{playerId, barId, type, dieSymbol}]
var _money_flying := 0          # money cards still flying deck -> venue (the next prompt waits for them, see _settle_money_flights)
var _awaiting_select := false
var _awaiting_bar := false
var _opp_open := false
var focus_idx := -1        # keyboard / gamepad focus: hand card index (select phase) or bar index (extra-money phase)


func _set_skip(v: bool) -> void:
	if v != skip:
		Trace.log("skip", "%s -> %s  by %s  (select=%s bar=%s)" % [skip, v, Trace.caller(), _awaiting_select, _awaiting_bar])
	skip = v


## Keys for the pause panel. The game screen does not process while the tree is paused, so Esc / B / Start would not
## reach it; this small node runs always and closes the panel - unless something opened on top of it (help) has the key.
class PauseKeys extends Node:
	var screen: Control

	func _init(s: Control) -> void:
		screen = s
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if not screen.is_inside_tree() or not screen.get_tree().paused:
			return
		var ml: Control = screen.modal_layer
		if not ml.has_node("ExitConfirm") or ml.get_child(ml.get_child_count() - 1).name != "ExitConfirm":
			return
		var pause: bool = InputMap.has_action("pause") and event.is_action_pressed("pause")
		if (event.is_action_pressed("ui_cancel") or pause) and not (event is InputEventKey and event.echo):
			Audio.play("panel_close")
			screen._close_pause()
			get_viewport().set_input_as_handled()


## A pause that really pauses: the table, the AI turn and every animation stop where they are, so the round cannot end
## behind the panel. The panel itself keeps running (PROCESS_MODE_ALWAYS on modal_layer), and so does the audio host.
func _set_paused(on: bool) -> void:
	if not is_inside_tree():
		return
	modal_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = on


## Is a full-screen overlay up right now? (cutscene / help / records / summary sit at z_index >= 60; the round-result and
## game-over boards live in modal_layer; the negotiation panel answers for itself.)
func _overlay_open() -> bool:
	if nego != null and nego.visible:
		return true
	if modal_layer != null:
		for c in modal_layer.get_children():
			if c.name != "Coach" and not c.is_queued_for_deletion():
				return true          # the first-game tip does not count: it never blocks the table
	for c in get_children():
		if c is Control and c.visible and c.z_index >= 60:
			return true
	return false


## ===================================================================== setup

## `actions`: human actions recorded after the checkpoint (SaveStore); they are re-applied so nothing already decided is asked again.
var tutorial_mode := false


var _tutorial_halted := false


## ===================================================================== layout

## State tint of the felt: the whole table subtly shifts mood (police blue/red, tense amber, gold at the end).
const FELT_TINTS := {
	"razzia": Color("1b3a6b"),
	"nego": Color("6b4a14"),
	"end": Color("7a5f1c"),
}


var opp_rail_pos := Vector2.ZERO
var opp_rail_w := 0.0
var _hand_metrics := {}
var _strip_metrics := {}
var compact := false              # phone landscape (Phase 29): see board_layout _layout_landscape
var _chip_k := 1.0                 # rail chips grow by this in the phone layout


## Hand = a gentle fan. Layout (targets) is computed here; the cards just tween towards their targets, so selection,
## hover, focus, removal and re-sorting all share one code path and never snap.
const FAN_DEG := 5.0


## ===================================================================== helpers

func _is_fast_forward_held() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select") or Input.is_action_pressed("skip_anim"):
		return true
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
		return true
	for pad in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_A) or Input.is_joy_button_pressed(pad, JOY_BUTTON_X) or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			return true
	return false


func _tween() -> Tween:
	var tw := create_tween()
	if skip or Settings.reduce_motion:
		tw.set_speed_scale(100.0)
	elif Settings.speed_name == "FAST":
		tw.set_speed_scale(2.0)
	return tw


func _wait(sec: float) -> void:
	var t := Settings.hold(sec)
	while t > 0.0 and not skip and _alive:
		await get_tree().process_frame
		if get_tree().paused:
			continue                      # the pause panel is open: the clock stops with the table
		var dt := get_process_delta_time()
		if _is_fast_forward_held():
			dt *= 4.0
		t -= dt


var _now_fn: Callable = Callable()        # how the current narration line was built (re-run when the language changes)


func _now(text: String) -> void:
	_now_fn = Callable()
	now_label.text = text              # a fixed line is a translation key: the label translates it by itself, live


## A narration line put together from values: kept as a function, so a language switch rebuilds it in the new language
## at once (Phase 29) instead of waiting for the next event.
func _now_live(fn: Callable) -> void:
	_now_fn = fn
	now_label.text = str(fn.call())


func _refresh_now() -> void:
	if _now_fn.is_valid():
		now_label.text = str(_now_fn.call())


func _toast(text: String, sec: float = 2.2) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.reset_size()
	toast_label.position = Vector2((size.x - toast_label.size.x) / 2.0, size.y * 0.42)
	toast_label.z_index = 50
	# a scene-tree timer, not a tween: a toast must also clear itself while the game is paused
	get_tree().create_timer(sec, true, false, true).timeout.connect(func():
		if is_instance_valid(toast_label):
			toast_label.visible = false)


## "  (나)" / "  (you)" after MY name when I chose one; nothing when the name already is the default "나" / "You"
func _me_tag(pid) -> String:
	if not _is_me(str(pid)) or str(names.get(pid, "")) == "나":
		return ""
	return "  " + tr("(나)")


func _nm(pid) -> String:
	var n := str(names.get(pid, pid))
	return tr(n) if n == "나" else n          # the default name is a word ("나" / "You"), a chosen name is shown as typed


## ===================================================================== first-game guide (Phase 19)

## A short tip at the moment it is needed, shown at most once per game and only while `Settings.coach_on` is on
## (it turns itself off after one finished game). The card body ignores the mouse, so it never swallows a click on the
## board underneath; only its own button does. Each tip disappears as soon as the move it explains is made.
var _coach_shown := {}
var _coach_panel: Control = null


func _is_me(pid) -> bool:
	return pid == human_id


func _update_hud() -> void:
	stat_round.value = "%02d" % int(disp["round"])
	stat_deck.value = tr("%d 장") % int(disp["deck"])
	pile.count = int(disp["deck"])
	var total := 0
	for id in bar_order:
		total += int(disp["bar_money"][id])
	stat_table.value = T.money(total)
	# Last round: the rail's own ROUND box carries it (title + gold accent). The floating pill used to sit on top of the
	# "ON THE TABLE" box and hid the pot, in both landscape and portrait, so it is no longer shown.
	var is_final := bool(disp["final"])
	stat_round.title = "FINAL ROUND" if is_final else "ROUND"
	stat_round.short_title = "FINAL" if is_final else ""
	stat_round.accent = is_final
	final_badge.visible = false
	for pid in chips:
		var c = chips[pid]
		c.dealer = pid == disp["croupier"]
		c.is_ready = bool(disp["ready"].get(pid, false))
	_update_relic_tray()


func _update_relic_tray() -> void:
	if relic_tray == null or not is_instance_valid(relic_tray):
		return
	for c in relic_tray.get_children():
		c.queue_free()
	var RelicManager = preload("res://engine/relic_manager.gd")
	if not RelicManager.is_relic_mode(state):
		relic_tray.visible = false
		return
	var relics: Array = RelicManager.get_player_relics(state, human_id)
	if relics.is_empty():
		relic_tray.visible = false
		return
	relic_tray.visible = true
	for r in relics:
		var badge := Button.new()
		badge.text = tr(str(r.get("name_ko", r.get("name", ""))))
		badge.icon = T.relic_icon(str(r.get("id", "")))
		badge.expand_icon = true
		badge.tooltip_text = tr(str(r.get("desc", "")))
		badge.focus_mode = Control.FOCUS_NONE
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		W.set_kind(badge, "active", int(11 * u))
		badge.custom_minimum_size = Vector2(0, 24.0 * u)
		badge.pressed.connect(func(): _toast(tr("[%s] %s") % [r.get("name_ko", r.get("name", "")), r.get("desc", "")], 3.0))
		relic_tray.add_child(badge)


func _set_bar_money(id: String, amount: int, dur: float = 0.25) -> void:
	disp["bar_money"][id] = amount
	var bv: BarView = bar_views[id]
	if amount <= 0:
		disp["bar_cards"][id] = 0
		if bv.extra_amount > 0:
			bv.set_extra(0, "")          # paid out: this round's extra money has left the venue with the rest
	bv.money_cards = int(disp["bar_cards"][id])
	bv.set_money(amount, Settings.dur(dur) if not skip else 0.0)
	_update_hud()


func _set_player_money(pid: String, amount: int, dur: float = 0.4) -> void:
	disp["money"][pid] = amount
	if chips.has(pid):
		chips[pid].set_money(amount, Settings.dur(dur) if not skip else 0.0)


## Small scale bump on a control (score feedback). Purely visual.
func _pop(c) -> void:
	if c == null or not is_instance_valid(c) or skip or Settings.reduce_motion:
		return
	c.pivot_offset = c.size / 2.0
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(1.07, 1.07), Settings.dur(0.12) + 0.001).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, Settings.dur(0.2) + 0.001).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _float_text(text: String, from_global: Vector2, color: Color, size_k: float = 1.0) -> void:
	var l := W.label(text, int(round(26.0 * u * size_k)), color, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	fx_layer.add_child(l)
	l.size = Vector2(160.0 * u, 36.0 * u)
	l.position = from_global - fx_layer.global_position - Vector2(l.size.x / 2.0, 0)
	if Settings.reduce_motion:
		# reduced motion: no drifting, but the amount stays readable for a moment (a real timer: tweens are collapsed)
		get_tree().create_timer(1.2).timeout.connect(l.queue_free)
		return
	var tw := _tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0 * u, Settings.dur(0.9) + 0.001)
	tw.tween_property(l, "modulate:a", 0.0, Settings.dur(0.9) + 0.001).set_delay(Settings.dur(0.5))
	tw.chain().tween_callback(l.queue_free)


func _float_pot_to_winner(amount: int, from_global: Vector2, to_global: Vector2) -> void:
	var l := W.label("+" + T.money(amount), int(round(20.0 * u)), T.GOLD, "money", HORIZONTAL_ALIGNMENT_CENTER, 800)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	fx_layer.add_child(l)
	l.size = Vector2(140.0 * u, 30.0 * u)
	l.position = from_global - fx_layer.global_position - Vector2(l.size.x / 2.0, l.size.y / 2.0)
	if Settings.reduce_motion:
		get_tree().create_timer(0.8).timeout.connect(l.queue_free)
		return
	var tw := _tween()
	tw.set_parallel(true)
	var target := to_global - fx_layer.global_position - Vector2(l.size.x / 2.0, l.size.y / 2.0)
	tw.tween_property(l, "position", target, Settings.dur(0.55) + 0.001).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, Settings.dur(0.2) + 0.001)
	tw.chain().tween_callback(l.queue_free)



func _clear_highlights() -> void:
	for id in bar_views:
		bar_views[id].highlight = false
		bar_views[id].z_index = 0


func _card_dict(pc: Dictionary) -> Dictionary:
	return {"id": pc["cardId"], "type": pc["type"], "barId": pc["barId"], "dieSymbol": pc["dieSymbol"]}


## ===================================================================== venue info (Phase 17)

## What the board has SHOWN so far about the venue cards. Kept in step with the replay (not with the engine, which is
## already ahead while the board animates), and rebuilt from the event log on Continue. Nothing here is hidden state.
var _shown_discard := {}      # card id -> true: revealed in an earlier round, now on the discard pile (since the last reshuffle)
var _shown_table: Array = []  # card ids revealed this round (still on the table)
var _reshuffles := 0          # how often the discard pile went back into the deck


## Public play history, built from the events the board has already shown (CARDS_REVEALED): playerId -> [{bar, type, symbol}].
var _seen_plays := {}


## ---------------------------------------------------------------- dialogue scenes (Phase 14)

var _scene_big_duels := 0
var _scene_last_round := -9
var scenes_shown: Array = []          # kinds shown this game (tests read it)


func _ai_players() -> Array:
	var out := []
	for pl in state.get("players", []):
		if not pl.get("isHuman", false) and pl.get("personality") != null:
			out.append(pl)
	return out


## Mid-game scenes (big duel, raid, lead change) share one budget: at most 3 a game and never two rounds in a row,
## so the story punctuates the game instead of interrupting it. The opening, the last round and the end always play.
const MID_SCENES_MAX := 3
var _scene_mid := 0
var _leader_id := ""            # who was strictly first after the last round ("" = tie / nobody yet)


var _dealt_note_round := -1


## Await a tween, but let SKIP cut it short (a pause just holds it: the tween belongs to this screen).
func _run_tween(tw: Tween) -> void:
	while _alive and tw.is_valid() and tw.is_running():
		if skip:
			tw.kill()
			return
		await get_tree().process_frame


## The human dealer's extra card, shown while they choose (it then flies from there).
var _extra_held: Control = null


## Mouse/touch picking follows tree order, so cards created later (every round) must sit BELOW the dim layer, the negotiation
## panel and the modal layer, or they swallow clicks meant for a window drawn over them (the "back to menu?" panel bug).
func _add_below_overlays(n: Node) -> void:
	add_child(n)
	if dim != null and dim.get_parent() == self:
		move_child(n, dim.get_index())


var settle_mismatch := 0        # display record vs engine ROUND_ENDED totals (tests assert it stays 0)


var new_achievements: Array = []
var last_extra: Dictionary = {}      # achievement ids unlocked by the game that just ended


## ---------------------------------------------------------------- defined in the parts above (ui/board/*.gd)
## The parts lower in the chain call these; the real bodies override them higher up.


func _add_strip_back(pid: String, animate: bool) -> void:
	pass


func _ev_game_ended(ev: Dictionary) -> void:
	pass


func _ev_round_ended(ev: Dictionary) -> void:
	pass


func _input(event: InputEvent) -> void:
	pass


func _on_bar_chosen(bar_id: String) -> void:
	pass


func _on_bar_info(bar_id: String) -> void:
	pass


func _on_confirm() -> void:
	pass


func _on_exit_pressed() -> void:
	pass


func _set_hand(cards: Array, animate: bool) -> void:
	pass
