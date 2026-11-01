extends RefCounted
## Design tokens (docs/05 UI, UI_UX_DESIGN.md): colors, type, money formatting. One place, no magic values in the views.

const BG_DEEP := Color("0a0907")
const BG_PANEL := Color("15110c")
const BG_PANEL_2 := Color("1f1810")
const FELT := Color("0f1a14")
const BRASS := Color("a8854a")
const GOLD := Color("d6b274")
const GOLD_DIM := Color("7d6743")
const TEXT := Color("ece0c4")
const TEXT_DIM := Color("a89674")
const DANGER := Color("c9402f")
const POLICE_BLUE := Color("2f6fd0")
const OK := Color("3ecf6e")
const INK := Color("120d09")

const BAR_COLORS := {
	"COLIBRI": Color("2f6fb0"),
	"COTTON_CLUB": Color("b23a3a"),
	"HAVANA_BAR": Color("c9a431"),
	"THE_JUNGLE": Color("2f9e55"),
	"LINCOLNS": Color("8a4fb0"),
	"JAZZ_HOUSE": Color("d9731f"),
}
const BAR_NAMES := {
	"COLIBRI": "COLIBRI", "COTTON_CLUB": "COTTON CLUB", "HAVANA_BAR": "HAVANA BAR",
	"THE_JUNGLE": "THE JUNGLE", "LINCOLNS": "LINCOLN'S", "JAZZ_HOUSE": "JAZZ HOUSE",
}
## Short venue names for small cards (Phase 28): when the full name would have to shrink below what can be read, the short
## one is drawn larger instead. The colour frame and the poster art carry the same identity, so nothing is lost.
const BAR_SHORT := {
	"COLIBRI": "COLIBRI", "COTTON_CLUB": "COTTON", "HAVANA_BAR": "HAVANA",
	"THE_JUNGLE": "JUNGLE", "LINCOLNS": "LINCOLN'S", "JAZZ_HOUSE": "JAZZ",
}
const AI_NAMES := ["Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"]

## Text size policy. Design px are scaled by the window (content scale), so a size that looks fine at 1280x720 is tiny on a
## 430 px wide phone. `fs()` raises small text so it is never below MIN_SCREEN_PX on the real screen (bounded growth, so
## compact cards and chips keep their layout). `screen_scale` (real px per design px) is set by the game screen on resize.
const MIN_SCREEN_PX := 11.0
static var screen_scale := 1.0
static var _fonts := {}


## Text-size audit (tests only, off by default): the smallest text actually drawn with draw_string, in real screen px.
static var audit_on := false
static var drawn_min := 999.0
static var drawn_min_text := ""


static var drawn_hangul: Array = []        # tests (English run): Korean text drawn with draw_string


static func note_text(ci: CanvasItem, px: float, s: String) -> void:
	if audit_on and preload("res://ui/i18n.gd").lang == "en" and ci.is_visible_in_tree() and s.unicode_at(0) >= 0:
		for ch in s:
			if ch >= "가" and ch <= "힣":
				if drawn_hangul.size() < 50 and not s in drawn_hangul:
					drawn_hangul.append(s)
				break
	if not audit_on or not ci.is_visible_in_tree() or s.strip_edges() == "":
		return
	if ci is Control and not (ci as Control).scale.is_equal_approx(Vector2.ONE):
		return          # mid-animation (a card flying / popping): not a resting size anyone has to read
	if ci.get_parent() != null and ci.get_parent().name == "FxLayer":
		return          # in flight between two places (see board_layout fx_layer)
	var vp := ci.get_viewport()
	var win: float = (vp as Window).get_final_transform().get_scale().y if vp is Window else 1.0
	var eff: float = px * ci.get_global_transform_with_canvas().get_scale().y * win
	if eff < drawn_min:
		drawn_min = eff
		drawn_min_text = "%s (%s)" % [s.substr(0, 24), ci.get_class() if ci.get_script() == null else str(ci.get_script().resource_path).get_file()]


static func fs(design_px: float, cap: float = 1.7) -> float:
	var want := MIN_SCREEN_PX / maxf(0.2, screen_scale)
	return clampf(maxf(design_px, want), design_px, design_px * cap)


## `s` cut to `width` with "…" (a long player name in a narrow chip ends visibly instead of being sliced mid-letter)
static func ellipsize(font: Font, s: String, px: int, width: float) -> String:
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
		return s
	var t := s
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


## real screen px per px of this canvas item (window stretch x every parent's scale)
static func phys(ci: CanvasItem) -> float:
	var vp := ci.get_viewport()
	var win: float = (vp as Window).get_final_transform().get_scale().y if vp is Window else 1.0
	return ci.get_global_transform_with_canvas().get_scale().y * win


## Translated text for static code (instance code can use tr()). See ui/i18n.gd.
static func t(s: String) -> String:
	return preload("res://ui/i18n.gd").t(s)


static func bar_color(bar_id: String) -> Color:
	return BAR_COLORS.get(bar_id, GOLD)


static func bar_name(bar_id: String) -> String:
	return BAR_NAMES.get(bar_id, bar_id)


## The venue name that reads best in `width` px: {"text", "px"}. Starts at want_px, shrinks to min_px; when the full name
## had to shrink, the short name is tried and wins if it can be drawn larger.
static func fit_bar_name(bar_id: String, font: Font, want_px: int, min_px: int, width: float) -> Dictionary:
	var best := {"text": bar_name(bar_id), "px": want_px}
	var names := [bar_name(bar_id)]
	if BAR_SHORT.get(bar_id, "") != "" and BAR_SHORT[bar_id] != bar_name(bar_id):
		names.append(BAR_SHORT[bar_id])
	var first := true
	for nm in names:
		var px := want_px
		while px > min_px and font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			px -= 1
		if first or px > int(best["px"]):
			best = {"text": nm, "px": px}
		if first and px >= want_px:
			break               # the full name fits as it is
		first = false
	return best


## "$35,000"
static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "," + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-$" if n < 0 else "$") + out


static func _load_font_file(path: String) -> FontFile:
	var res = load(path) if ResourceLoader.exists(path) else null
	if res is FontFile:
		return res
	# not imported yet (first run without the editor): read the bytes directly
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		return ff
	return null


## kind: "title" (Josefin Sans) | "money" (Playfair Display / Abril Fatface) | "stamp" (Special Elite) | "ui" (Pretendard) | "dialogue" (Lora + Hahmlet)
static func font(kind: String, weight: int = 600) -> Font:
	var key := "%s-%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var pret_path := "res://assets/fonts/Pretendard-SemiBold.ttf" if weight >= 600 else "res://assets/fonts/Pretendard-Regular.ttf"
	var paths := {
		"title": "res://assets/fonts/JosefinSans.ttf",
		"money": "res://assets/fonts/PlayfairDisplay.ttf",
		"big_money": "res://assets/fonts/AbrilFatface.ttf",
		"stamp": "res://assets/fonts/SpecialElite.ttf",
		"ui": pret_path,
		"dialogue": "res://assets/fonts/Lora.ttf",
		"story": "res://assets/fonts/Lora.ttf",
	}
	var base := _load_font_file(paths.get(kind, pret_path))
	var f: Font
	if base == null:
		f = ThemeDB.fallback_font
	else:
		var fv := FontVariation.new()
		fv.base_font = base
		if kind in ["money", "big_money"]:
			fv.opentype_features = {"tnum": 1}
		if kind == "title":
			fv.variation_opentype = {_tag("wght"): 700}
			var hahmlet := _load_font_file("res://assets/fonts/Hahmlet-Subset.ttf")
			var kr := _load_font_file(pret_path)
			var fbs: Array[Font] = []
			if hahmlet != null:
				fbs.append(hahmlet)
			if kr != null:
				fbs.append(kr)
			fv.fallbacks = fbs
		elif kind in ["dialogue", "story"]:
			var hahmlet := _load_font_file("res://assets/fonts/Hahmlet-Subset.ttf")
			var kr := _load_font_file(pret_path)
			var fbs: Array[Font] = []
			if hahmlet != null:
				fbs.append(hahmlet)
			if kr != null:
				fbs.append(kr)
			fv.fallbacks = fbs
		elif kind != "ui":
			var kr := _load_font_file(pret_path)
			if kr != null:
				fv.fallbacks = [kr]
		f = fv
	_fonts[key] = f
	return f


static func _tag(name: String) -> int:
	var ts := TextServerManager.get_primary_interface()
	return ts.name_to_tag(name) if ts != null else 0


## ---- Vector Icons: 6 venues, police badge, and money clip ----
const VENUE_ICONS := {
	"COLIBRI": "res://assets/icons/venues/colibri.svg",
	"COTTON_CLUB": "res://assets/icons/venues/cotton_club.svg",
	"HAVANA_BAR": "res://assets/icons/venues/havana_bar.svg",
	"THE_JUNGLE": "res://assets/icons/venues/the_jungle.svg",
	"LINCOLNS": "res://assets/icons/venues/lincolns.svg",
	"JAZZ_HOUSE": "res://assets/icons/venues/jazz_house.svg",
}
static var _icon_tex := {}

static func _load_tex_file(path: String) -> Texture2D:
	if _icon_tex.has(path):
		return _icon_tex[path]
	var tex = load(path) if ResourceLoader.exists(path) else null
	if not (tex is Texture2D):
		var real_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(real_p):
			var img := Image.load_from_file(real_p)
			if img != null:
				tex = ImageTexture.create_from_image(img)
	_icon_tex[path] = tex
	return tex

static func venue_icon(bar_id: String) -> Texture2D:
	var p: String = VENUE_ICONS.get(bar_id, "")
	return _load_tex_file(p) if p != "" else null

static func police_icon() -> Texture2D:
	return _load_tex_file("res://assets/icons/police_badge.svg")

static func money_clip_icon() -> Texture2D:
	return _load_tex_file("res://assets/icons/money_clip.svg")

const RELIC_ICONS := {
	"lucky_coin": "res://assets/icons/relics/lucky_coin.svg",
	"protection_racket": "res://assets/icons/relics/protection_racket.svg",
	"informant": "res://assets/icons/relics/informant.svg",
	"swiss_account": "res://assets/icons/relics/swiss_account.svg",
	"bribed_judge": "res://assets/icons/relics/bribed_judge.svg",
	"loaded_dice": "res://assets/icons/relics/loaded_dice.svg",
	"dirty_cop": "res://assets/icons/relics/dirty_cop.svg",
	"syndicate_crest": "res://assets/icons/relics/syndicate_crest.svg",
}

const SYSTEM_ICONS := {
	"reroll": "res://assets/icons/system/reroll.svg",
	"challenger": "res://assets/icons/system/challenger.svg",
	"defender": "res://assets/icons/system/defender.svg",
	"police_raid": "res://assets/icons/system/police_raid.svg",
	"lock": "res://assets/icons/system/lock.svg",
	"die_face": "res://assets/icons/system/die_face.svg",
	"fallback_relic": "res://assets/icons/relics/fallback_relic.svg",
}

static func relic_icon(relic_id: String) -> Texture2D:
	var p: String = RELIC_ICONS.get(relic_id, "res://assets/icons/relics/fallback_relic.svg")
	return _load_tex_file(p)

static func system_icon(name: String) -> Texture2D:
	var p: String = SYSTEM_ICONS.get(name, "")
	return _load_tex_file(p) if p != "" else null


## ---- illustrations (assets/art): venue posters + gambler / police portraits ----
static var _art := {}


## kind: "bar" (venue poster) | "zocker" (gambler portrait) | "razzia" (police portrait). Returns null when the file is missing,
## so every caller keeps its procedural fallback drawing.
static func art(kind: String, id: String = "") -> Texture2D:
	var path := ""
	if kind == "bar":
		path = "res://assets/art/bars/%s.jpg" % id
	elif kind == "zocker":
		path = "res://assets/art/cards/zocker_%s.jpg" % id
	elif kind == "razzia":
		if id != "":
			var club_path := "res://assets/art/cards/razzia_%s.jpg" % id
			if ResourceLoader.exists(club_path) or FileAccess.file_exists(club_path):
				path = club_path
		if path == "":
			path = "res://assets/art/cards/razzia.jpg"
	if _art.has(path):
		return _art[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null and ResourceLoader.exists(path):
		tex = load(path)
	_art[path] = tex
	return tex


## Draws `tex` so that it fills `rect` (cover fit, no distortion). focus_y 0..1 picks which part is kept when cropping vertically.
static func draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2, focus_y: float = 0.5, modulate: Color = Color.WHITE) -> void:
	var ts := tex.get_size()
	var want := rect.size.x / maxf(1.0, rect.size.y)
	var have := ts.x / ts.y
	var src := Rect2(Vector2.ZERO, ts)
	if have > want:
		src.size.x = ts.y * want
		src.position.x = (ts.x - src.size.x) / 2.0
	else:
		src.size.y = ts.x / want
		src.position.y = (ts.y - src.size.y) * focus_y
	ci.draw_texture_rect_region(tex, rect, src, modulate)
