extends SceneTree
## Renders a contact sheet of the UI components for visual checks:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tests/ui_gallery.gd -- out.png
const T = preload("res://ui/tokens.gd")
const CardView = preload("res://ui/card_view.gd")
const BarView = preload("res://ui/bar_view.gd")
const Eng = preload("res://engine/engine.gd")

func _init() -> void:
	var out := "gallery.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var bg := ColorRect.new()
	bg.color = T.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var bars := ["COLIBRI", "COTTON_CLUB", "HAVANA_BAR", "THE_JUNGLE", "LINCOLNS", "JAZZ_HOUSE"]
	var cards := {}
	for c in Eng.create_original_card_set():
		cards[c["id"]] = c
	var money := [35000, 10000, 5000, 50000, 20000, 85000]
	for i in range(6):
		var bv := BarView.new()
		bv.setup(bars[i])
		bv.mode = "card"
		bv.venue_h = 200
		bv.mini_size = Vector2(46, 64)
		bv.position = Vector2(16 + i * 168, 12)
		bv.size = Vector2(156, 200 + 100)
		bv.money_cards = i + 1
		bv.set_money(money[i])
		bv.highlight = i == 3
		bg.add_child(bv)
		bv.add_mini(cards["%s-Z%d-%d" % [bars[i], 5, 6]], "Vito")
		if i % 2 == 0:
			bv.add_mini(cards["%s-R%d-%d" % [bars[i], 4, 1]], "Lola")
		if i == 2:
			bv.add_mini(cards["%s-Z%d-%d" % [bars[i], 3, 2]], "Mack").out_mark = true
	var hx := 16.0
	for i in range(5):
		var cv := CardView.new()
		var b: String = bars[i]
		cv.card = cards["%s-%s%d-%d" % [b, "R" if i == 4 else "Z", 6 if i == 4 else i + 2, 3 if i == 4 else (i + 2) * 0 + (2 if i < 2 else 4 if i == 2 else 6)]] if false else {"id": "x", "type": "RAZZIA" if i == 4 else "ZOCKER", "barId": b, "dieSymbol": i + 2}
		cv.size = Vector2(104, 144)
		cv.position = Vector2(hx + i * 118, 330)
		cv.selected = i == 1
		cv.locked = i == 3
		bg.add_child(cv)
	var back := CardView.new()
	back.card = {}
	back.size = Vector2(104, 144)
	back.position = Vector2(620, 330)
	bg.add_child(back)
	var small_back := CardView.new()
	small_back.card = {}
	small_back.caption = "Dutch"
	small_back.size = Vector2(46, 64)
	small_back.position = Vector2(740, 330)
	bg.add_child(small_back)
	for i in range(6):
		var rv := BarView.new()
		rv.setup(bars[i])
		rv.mode = "row"
		rv.mini_size = Vector2(34, 48)
		rv.position = Vector2(820, 12 + i * 80)
		rv.size = Vector2(440, 74)
		rv.money_cards = 2
		rv.set_money(money[i])
		bg.add_child(rv)
		if i < 3:
			rv.add_mini(cards["%s-Z%d-%d" % [bars[i], 5, 6]], "Vito")
			rv.add_mini(cards["%s-R%d-%d" % [bars[i], 4, 1]], "Lola")
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
