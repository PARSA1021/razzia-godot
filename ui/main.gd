extends Control
## Root: switches between menu and game, and keeps the content scale matched to window orientation.

const T = preload("res://ui/tokens.gd")
const Menu = preload("res://ui/menu_screen.gd")
const Game = preload("res://ui/game_screen.gd")
const SaveStore = preload("res://ui/save_store.gd")
const Eng = preload("res://engine/engine.gd")

var current: Control = null
var _last_portrait := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	_fit()
	get_viewport().size_changed.connect(_fit)
	show_menu()


func _fit() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _update_scale() -> void:
	var w := get_window()
	var sz := Vector2(w.size)
	var portrait := sz.y > sz.x
	var target := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	if w.content_scale_size != target:
		w.content_scale_size = target
	# real screen px per design px: small text is raised from this everywhere (T.fs), the menu included
	T.screen_scale = minf(sz.x / float(target.x), sz.y / float(target.y))


func _swap(n: Control) -> void:
	if current != null:
		current.queue_free()
	current = n
	add_child(n)


func show_menu() -> void:
	var m := Menu.new()
	m.start_requested.connect(_start_new)
	m.continue_requested.connect(_continue)
	m.tutorial_requested.connect(_start_tutorial)
	_swap(m)


## Sal's tutorial (fixed table), then - if the player wants - a real game with the menu's settings.
func _start_tutorial(config: Dictionary) -> void:
	var g := _new_game()
	g.tutorial_finished.connect(func(choice):
		if choice == "play":
			var cfg := config.duplicate()
			cfg["seed"] = int(Time.get_unix_time_from_system()) & 0x7fffffff
			_start_new(cfg)
		else:
			show_menu())
	g.begin_tutorial()


func _start_new(config: Dictionary) -> void:
	var cfg := config.duplicate()
	var slot := int(cfg.get("slot", SaveStore.slot))
	cfg.erase("slot")                  # the engine only gets the rules config
	var s := Eng.create_game(cfg)
	if s.has("error"):
		push_error(str(s["error"]))
		return
	SaveStore.use_slot(slot)
	SaveStore.clear()                  # this slot only: the other slot keeps its game
	var g := _new_game()
	g.begin(s)


func _continue(slot: int = 1) -> void:
	SaveStore.use_slot(slot)
	var r := SaveStore.load_save()
	if not r["ok"]:
		push_warning("RAZZIA: save slot %d unreadable (%s); kept as *.corrupt.*.json" % [slot, str(r["error"].get("message", ""))])
		SaveStore.quarantine()          # never delete a save that merely failed to load
		show_menu()
		return
	if r.get("fromBackup", false):
		push_warning("RAZZIA: save slot %d was damaged; resumed from the copy before the last write" % slot)
	if r["actionsDropped"]:
		push_warning("RAZZIA: autosave actions were malformed; resuming from the checkpoint")
	var g := _new_game()
	g.begin(r["state"], true, r["aiRngState"], r["actions"])


func _new_game() -> Control:
	var g := Game.new()
	g.exit_requested.connect(show_menu)
	g.new_game_requested.connect(func():
		var cfg: Dictionary = g.state["config"].duplicate()
		var names: Array = []
		for p in g.state["players"]:
			names.append(p["name"])
		cfg["playerCount"] = g.state["playerCount"]
		cfg["names"] = names
		cfg["seed"] = int(Time.get_unix_time_from_system()) & 0x7fffffff
		cfg["slot"] = SaveStore.slot     # NEW GAME after a game: the same slot
		_start_new(cfg))
	_swap(g)
	return g
