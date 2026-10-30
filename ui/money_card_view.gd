extends Control
## A face-up money card (the dealer's extra card): the amount is printed on it, so the player sees WHAT moves, not only
## that something moved. Presentation only.

const T = preload("res://ui/tokens.gd")

var amount := 0
var caption := "추가 머니카드"
var glow := 0.0: set = _set_glow


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_glow(v: float) -> void:
	glow = v
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var k := w / 100.0
	if glow > 0.01:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(0, 0, 0, 0)
		g.set_corner_radius_all(int(12.0 * k))
		g.shadow_color = Color(T.GOLD, 0.55 * glow)
		g.shadow_size = int(16.0 * k)
		g.draw(get_canvas_item(), Rect2(0, 0, w, h))
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.bg_color = Color("1c2a1d")
	sb.border_color = T.GOLD
	sb.set_border_width_all(maxi(2, int(3.0 * k)))
	sb.set_corner_radius_all(int(9.0 * k))
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = int(6.0 * k)
	sb.draw(get_canvas_item(), Rect2(0, 0, w, h))
	# inner guilloche frame (banknote feel)
	var inner := Rect2(7.0 * k, 7.0 * k, w - 14.0 * k, h - 14.0 * k)
	draw_rect(inner, Color(T.GOLD, 0.45), false, maxf(1.0, 1.2 * k))
	for i in range(5):
		draw_circle(Vector2(w / 2.0, h * 0.56), w * (0.18 + 0.05 * i), Color(T.OK, 0.05))
	var f2 := T.font("ui", 700)
	var s2 := int(round(maxf(10.0, 11.0 * k)))
	var cap := T.t(caption)
	T.note_text(self, s2, cap)
	draw_string(f2, Vector2(0, h * 0.20 + s2 * 0.4), cap, HORIZONTAL_ALIGNMENT_CENTER, w, s2, Color("d9caa6"))
	var txt := T.money(amount)
	var f1 := T.font("money", 800)
	var s1 := int(round(30.0 * k))
	while s1 > 10 and f1.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s1).x > w - 16.0 * k:
		s1 -= 1
	T.note_text(self, s1, txt)
	draw_string(f1, Vector2(0, h * 0.60 + s1 * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, w, s1, T.GOLD)
