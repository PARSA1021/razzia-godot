extends RefCounted
## Shared sound controls (Phase 11): mix presets + master / music / effects / interface sliders with on-off switches.
## Used by the in-game ⎋ panel and the main menu. Every change is saved at once and applied live (Audio.refresh()).

const T = preload("res://ui/tokens.gd")
const W = preload("res://ui/widgets.gd")
const Settings = preload("res://ui/settings.gd")
const Audio = preload("res://ui/audio.gd")

## [label, key, has on/off switch]
const ROWS := [["전체 음량", "master", true], ["배경음악", "music", true], ["효과음", "sfx", true], ["버튼 소리", "ui", false]]


static func _vol(key: String) -> float:
	match key:
		"master": return Settings.master_vol
		"music": return Settings.music_vol
		"sfx": return Settings.sfx_vol
	return Settings.ui_vol


## a row's switch: master = not muted, music / effects = their own on-off
static func _on(key: String) -> bool:
	match key:
		"master": return not Settings.mute_all
		"music": return Settings.music_on
	return Settings.sfx_on


static func _set_vol(key: String, v: float) -> void:
	match key:
		"master": Settings.master_vol = v
		"music": Settings.music_vol = v
		"sfx": Settings.sfx_vol = v
		_: Settings.ui_vol = v


static func _ko(c: Node) -> void:
	for b in c.find_children("*", "Button", true, false):
		b.add_theme_font_override("font", T.font("ui", 800))


## compact = presets + master volume only (main menu); the full set lives in the in-game panel.
static func build(u: float = 1.0, compact: bool = false) -> Control:
	var box := VBoxContainer.new()
	box.name = "SoundRows"
	box.add_theme_constant_override("separation", int(8 * u))
	var sliders := {}
	var toggles := {}
	var sync := func() -> void:
		for k in sliders:
			sliders[k].set_value_no_signal(_vol(k))
		for k in toggles:
			toggles[k].text = "ON" if _on(k) else "OFF"
	# presets
	var labels: Array = []
	for m in Settings.MIX_PRESETS:
		labels.append(m[0])
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", int(8 * u))
	var pl := W.label("분위기", int(17 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
	pl.custom_minimum_size = Vector2(96.0 * u, 0)
	pr.add_child(pl)
	for i in range(labels.size()):
		var b := W.button(labels[i], "secondary", int(15 * u), Vector2(0, 40.0 * u))
		b.name = "Preset_%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", T.font("ui", 800))
		b.pressed.connect(func():
			Settings.apply_mix(i)
			Settings.save_settings()
			Audio.refresh()
			sync.call())
		pr.add_child(b)
	box.add_child(pr)
	for spec in ROWS:
		var key: String = spec[1]
		if compact and key != "master":
			continue
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(10 * u))
		var nl := W.label(spec[0], int(17 * u), T.TEXT, "ui", HORIZONTAL_ALIGNMENT_LEFT, 700)
		nl.custom_minimum_size = Vector2(96.0 * u, 0)
		hb.add_child(nl)
		var sl := HSlider.new()
		sl.name = "Slider_" + key
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = _vol(key)
		sl.custom_minimum_size = Vector2(170.0 * u, 40.0 * u)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sliders[key] = sl
		hb.add_child(sl)
		if spec[2]:
			var tg := W.button("", "secondary", int(15 * u), Vector2(64.0 * u, 40.0 * u))
			tg.name = "Toggle_" + key
			toggles[key] = tg
			hb.add_child(tg)
			tg.pressed.connect(func():
				if key == "music":
					Settings.music_on = not Settings.music_on
				elif key == "master":
					Settings.mute_all = not Settings.mute_all        # the master switch = mute everything
				else:
					Settings.sfx_on = not Settings.sfx_on
				Settings.save_settings()
				Audio.refresh()
				sync.call()
				Audio.play("toggle_on" if _on(key) else "toggle_off"))
		if not spec[2]:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(64.0 * u, 0)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(sp)
		sl.value_changed.connect(func(v: float):
			_set_vol(key, v)
			Settings.save_settings()
			Audio.refresh()
			if key == "sfx":
				Audio.play("coin")                  # audible feedback while dragging
			elif key == "ui":
				Audio.play("tick"))
		box.add_child(hb)
	var fm := W.segmented(["창이 비활성이면 음소거", "계속 재생"], 0 if Settings.focus_mute else 1, func(i):
		Settings.focus_mute = i == 0
		Settings.save_settings(), int(14 * u))
	_ko(fm)
	if not compact:
		box.add_child(fm)
	else:
		fm.queue_free()
	sync.call()
	return box
