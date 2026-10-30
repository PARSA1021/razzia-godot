extends RefCounted
## Languages (Korean / English). Godot's own TranslationServer does the work, so there is no library and no import step:
##  - The KEY of every string is the Korean text written in the code. Korean is the source language, so in Korean nothing is
##    looked up at all; a key missing from the English table falls back to that Korean text (never a blank, never a crash).
##  - The English table lives in one place: res://i18n/en.gd (key = the Korean source text, value = the English text).
##  - Labels and buttons translate their own text (Control.auto_translate), so they switch language the moment the locale
##    changes. Text built at run time (a number in a sentence) or drawn in _draw() goes through tr() / T.t() at the moment it
##    is shown, and the screens redraw / rebuild on `changed`.
##  - Not translated on purpose: player names (typed by the player or the AI cast), venue names and card words (COLIBRI,
##    ZOCKER, RAZZIA: names on the cards themselves), money amounts.

const LANGS := ["ko", "en"]
const LABELS := {"ko": "한국어", "en": "English"}

static var lang := "ko"
static var _registered := false


static func _register() -> void:
	if _registered:
		return
	_registered = true
	var tbl: Dictionary = load("res://i18n/en.gd").EN
	var t := Translation.new()
	t.locale = "en"
	for k in tbl:
		t.add_message(k, tbl[k])
	TranslationServer.add_translation(t)


## Applies a language ("ko" | "en"). Unknown values fall back to Korean.
static func apply(code: String) -> void:
	_register()
	lang = code if code in LANGS else "ko"
	TranslationServer.set_locale(lang)


## The default for a player who never chose: Korean on a Korean system, English elsewhere.
static func system_default() -> String:
	return "ko" if OS.get_locale_language() == "ko" else "en"


static func t(s: String) -> String:
	if lang == "ko" or s == "":
		return s
	return String(TranslationServer.translate(s))


static func is_en() -> bool:
	return lang == "en"
