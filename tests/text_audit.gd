extends RefCounted
## 화면 위 글자 크기 점검 (Steam Deck 가독성). 지금 보이는 모든 Label / Button / RichTextLabel / LineEdit 의
## 글꼴 크기에 실제 화면 배율(창 스트레치 x 노드 변환)을 곱해 "실제 화면 픽셀" 크기를 구합니다.
## Valve 기준: 1280x800 에서 가장 작은 글자 높이 9px 이상, 권장 12px. (글꼴 크기 px 는 글자 높이보다 약간 큽니다:
## 한글은 글꼴 크기의 약 0.9, 라틴 대문자는 약 0.7)
## _draw() 로 직접 그리는 글자(카드 위 숫자 등)는 여기서 잡히지 않으므로 코드의 최소값(바닥값)으로 따로 점검합니다.


static func font_px(c: Control) -> float:
	if c is Label and (c as Label).label_settings != null:
		return float((c as Label).label_settings.font_size)
	if c is RichTextLabel:
		return float(c.get_theme_font_size("normal_font_size"))
	return float(c.get_theme_font_size("font_size"))


## returns [{text, px, path}] for every visible text control, sorted by px
static func scan(root: Window) -> Array:
	var out: Array = []
	var win_scale: float = root.get_final_transform().get_scale().x
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Label or c is Button or c is RichTextLabel or c is LineEdit):
			continue
		if not c.is_visible_in_tree():
			continue
		var txt: String = c.text if not (c is RichTextLabel) else (c as RichTextLabel).get_parsed_text()
		txt = txt.strip_edges()
		if txt == "" or c.modulate.a < 0.05:
			continue
		var r := c.get_global_rect()
		if r.size.x < 1 or r.size.y < 1:
			continue
		var node_scale: float = c.get_global_transform().get_scale().y
		var px: float = font_px(c) * node_scale * win_scale
		out.append({"text": txt.substr(0, 40).replace("\n", " "), "px": px, "path": str(c.get_path()).get_file()})
	out.sort_custom(func(a, b): return a["px"] < b["px"])
	return out


static func report(root: Window, where: String, limit: float = 12.0) -> Dictionary:
	var all := scan(root)
	var small: Array = all.filter(func(e): return e["px"] < limit - 0.01)
	var mn: float = all[0]["px"] if not all.is_empty() else 0.0
	print("  [text] %-14s n=%3d min=%.1fpx  <%dpx: %d" % [where, all.size(), mn, int(limit), small.size()])
	var seen := {}
	for e in small:
		var key := "%s|%.1f" % [e["text"], e["px"]]
		if seen.has(key):
			continue
		seen[key] = true
		if seen.size() <= 12:
			print("         %.1fpx  '%s'" % [e["px"], e["text"]])
	return {"min": mn, "small": small.size(), "n": all.size()}


## Korean left on screen in the English game (ui/i18n.gd): every visible text control, as it is actually displayed
## (a label shows atr(text): its key translated). Returns ["text (node)", ...]. Player names are never Korean in tests.
static func hangul(root: Window) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("[가-힣]")
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Label or c is Button or c is RichTextLabel or c is LineEdit):
			continue
		if not c.is_visible_in_tree() or c.modulate.a < 0.05:
			continue
		if c.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue          # deliberately not translated (the language names: 한국어 / English)
		var txt: String = (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else c.text
		if c is Label or c is Button:
			txt = c.atr(txt)          # what the control really shows (its auto-translated text)
		if re.search(txt) != null:
			out.append("%s (%s)" % [txt.substr(0, 60).replace("\n", " "), str(c.get_path()).get_file()])
	return out


## English run of a whole QA test: switches the game to English and watches the screen every few frames until the test
## ends, collecting any Korean that is shown (controls and drawn text). Call start_en(tree) first, report_en() at the end.
static var _en_left: Array = []
static var _en_on := false


static func start_en(tree: SceneTree) -> void:
	preload("res://ui/settings.gd").language = "en"
	preload("res://ui/i18n.gd").apply("en")
	preload("res://ui/tokens.gd").audit_on = true
	_en_on = true
	_en_watch(tree)


static func _en_watch(tree: SceneTree) -> void:
	while _en_on:
		for i in range(6):
			await tree.process_frame
		for h in hangul(tree.root):
			var key: String = h.get_slice(" (", 0)
			if not key in _en_left:
				_en_left.append(key)
				print("  [ko left] %s" % h)


## returns the Korean texts seen (empty = clean) and prints them
static func report_en() -> Array:
	_en_on = false
	for h in preload("res://ui/tokens.gd").drawn_hangul:
		if not ("drawn: " + str(h)) in _en_left:
			_en_left.append("drawn: " + str(h))
	print("I18N: %d Korean text(s) left in the English game" % _en_left.size())
	for h in _en_left:
		print("   ", h)
	return _en_left
