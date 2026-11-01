class_name ThemeAssets
extends RefCounted

## ThemeAssets: Theme-aware asset resolver with automatic fallback to classic noir.
## Resolves art paths across active theme (e.g. res://themes/circus/) and fallback assets (res://assets/).
## Supports bars, zockers, razzia, and character portraits (both 256px face and 384px bust).

const Settings = preload("res://ui/settings.gd")

static var _cache: Dictionary = {}


## Clear texture cache (e.g. when theme switches)
static func clear_cache() -> void:
	_cache.clear()


## Resolves and loads a texture with caching. Returns null if neither theme nor fallback exists.
static func get_art(kind: String, id: String = "") -> Texture2D:
	var path := resolve_art_path(kind, id)
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


## Returns the best existing resource path for the requested art piece.
## Precedence: Active Theme -> Default Noir Assets -> "" (Empty string -> triggers procedural fallback).
static func resolve_art_path(kind: String, id: String = "") -> String:
	var cur_theme: String = Settings.theme if Settings.theme != "" else "noir"

	# 1. Active theme path check (if not default noir)
	if cur_theme != "noir":
		var theme_candidates: Array[String] = _get_candidates("res://themes/%s" % cur_theme, kind, id)
		for p in theme_candidates:
			if _path_exists(p):
				return p

	# 2. Classic Noir default/fallback path check
	var noir_candidates: Array[String] = _get_candidates("res://assets", kind, id)
	for p in noir_candidates:
		if _path_exists(p):
			return p

	return ""


static func _get_candidates(root: String, kind: String, id: String) -> Array[String]:
	var list: Array[String] = []
	match kind:
		"bar":
			if id != "":
				list.append("%s/bars/%s.jpg" % [root, id])
				list.append("%s/art/bars/%s.jpg" % [root, id])
		"zocker":
			if id != "":
				list.append("%s/cards/zocker_%s.jpg" % [root, id])
				list.append("%s/art/cards/zocker_%s.jpg" % [root, id])
		"razzia":
			if id != "":
				list.append("%s/cards/razzia_%s.jpg" % [root, id])
				list.append("%s/art/cards/razzia_%s.jpg" % [root, id])
			list.append("%s/cards/razzia.jpg" % root)
			list.append("%s/art/cards/razzia.jpg" % root)
		"character":
			if id != "":
				list.append("%s/characters/%s.png" % [root, id])
		"character_full":
			if id != "":
				list.append("%s/characters_full/%s.png" % [root, id])
	return list


static func _path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if FileAccess.file_exists(path):
		return true
	var global_p := ProjectSettings.globalize_path(path)
	return FileAccess.file_exists(global_p)
