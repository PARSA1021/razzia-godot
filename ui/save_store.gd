extends RefCounted
## Autosave (docs/03 §25). The engine state is the truth; the AI's RNG position is stored next to it so a resumed game stays reproducible.
##
## File = {"version", "gameState", "aiRngState", "actions"?}
##   gameState/aiRngState  CHECKPOINT: written when the human is asked for a card / extra-money bar (the AI has already acted then).
##   actions               optional (absent in files written before Phase 8A-1 = []): the human actions accepted by the engine
##                         since that checkpoint, in order. On resume the controller re-applies them, so a submitted card, a
##                         proposal or a response can never be taken back, and nothing is played twice.
## Writes go to a temp file first and are renamed over the save, so a crash cannot leave a half-written file; the save it
## replaces is kept as <file>.bak, and a save that cannot be read falls back to that copy.
##
## Two slots (Phase 28). Slot 1 is the file every earlier version wrote (autosave.json), so an existing game simply shows up
## in slot 1; slot 2 is autosave_2.json. Each game lives in one slot and autosaves there; starting a new game clears only
## its own slot. Optional fields (absent in older files, never required): "format" (2) and "savedAt" (unix time).
## Settings (language, volume, name) are not in here: they live in settings.cfg, so a slot never carries them.

const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const Util = preload("res://engine/util.gd")

const SLOTS := [1, 2]
const FORMAT := 2
static var slot := 1                    # the slot the current game saves to
static var path := slot_path(1)         # tests point this at a scratch file


## "user://autosave.json" (slot 1, the original file) / "user://autosave_2.json"
static func slot_path(n: int) -> String:
	return preload("res://ui/settings.gd").test_file("autosave.json" if n <= 1 else "autosave_%d.json" % n)


## Makes slot `n` the one that has_save / save / load_save / clear work on.
static func use_slot(n: int) -> void:
	slot = clampi(n, 1, SLOTS.size())
	path = slot_path(slot)


## What the menu shows for a slot, read without changing anything:
## {slot, exists, ok, players, round, final, savedAt, names, difficulty, error}. A damaged file -> exists=true, ok=false.
static func slot_info(n: int) -> Dictionary:
	var p := slot_path(n)
	var info := {"slot": n, "exists": FileAccess.file_exists(p), "ok": false, "players": 0, "round": 0, "final": false,
		"savedAt": 0, "names": [], "difficulty": "", "error": ""}
	if not info["exists"]:
		return info
	var text := FileAccess.get_file_as_string(p)
	var r := parse_save(text)
	if not r["ok"]:
		info["error"] = str(r["error"].get("message", ""))
		return info
	var st: Dictionary = r["state"]
	info["ok"] = true
	info["players"] = int(st.get("playerCount", (st["players"] as Array).size()))
	info["round"] = int(st.get("round", 0))
	info["final"] = bool(st.get("finalRound", false))
	info["difficulty"] = str(st.get("config", {}).get("aiDifficulty", ""))
	for pl in st["players"]:
		info["names"].append(str(pl.get("name", "")))
	var parsed = JSON.parse_string(text)
	var at = parsed.get("savedAt", null) if parsed is Dictionary else null
	info["savedAt"] = int(at) if (at is float or at is int) else int(FileAccess.get_modified_time(p))
	return info

const ACTION_TYPES := ["SELECT_CARD", "PLACE_EXTRA_MONEY", "MAKE_PROPOSAL", "RESPOND"]


static func has_save() -> bool:
	return FileAccess.file_exists(path)


static func _write_atomic(text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp).length() != text.length():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))      # the disk did not take it: keep the old save untouched
		return false
	var g_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var bak := ProjectSettings.globalize_path(path + ".bak")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(bak)
		DirAccess.copy_absolute(g_path, bak)                                  # the previous good save, in case this one is lost
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), g_path) == OK


## New checkpoint (clears the recorded actions).
static func save(state: Dictionary, ai_rng_state: int) -> bool:
	return _write_atomic(JSON.stringify({"version": Eng.VERSION, "format": FORMAT, "savedAt": int(Time.get_unix_time_from_system()),
		"gameState": state, "aiRngState": ai_rng_state, "actions": []}))


## Appends a human action the engine has accepted to the current checkpoint. Returns false when there is no readable save.
static func record_action(action: Dictionary) -> bool:
	if not has_save():
		return false
	var parsed = Util.normalize(JSON.parse_string(FileAccess.get_file_as_string(path)))      # normalize: whole floats back to ints
	if not (parsed is Dictionary) or not (parsed.get("gameState", null) is Dictionary):
		return false
	var list: Array = parsed["actions"] if parsed.get("actions", null) is Array else []
	list.append(action)
	parsed["actions"] = list
	parsed["savedAt"] = int(Time.get_unix_time_from_system())
	return _write_atomic(JSON.stringify(parsed))


## Returns {"ok": bool, "state": Dictionary, "aiRngState": int, "actions": Array, "actionsDropped": bool, "error": Dictionary}.
## Missing "actions" -> []. Malformed actions -> dropped (resume from the checkpoint) and flagged, never a crash.
static func load_save() -> Dictionary:
	if not has_save():
		return {"ok": false, "error": Eng.err("SAVE_ERROR", "no save found")}
	var r := parse_save(FileAccess.get_file_as_string(path))
	if not r["ok"] and FileAccess.file_exists(path + ".bak"):
		var b := parse_save(FileAccess.get_file_as_string(path + ".bak"))      # the save before the last write
		if b["ok"]:
			b["fromBackup"] = true
			return b
	return r


static func parse_save(text: String) -> Dictionary:
	var r := Eng.load_game(text)
	if not r["ok"]:
		return r
	var parsed = Util.normalize(JSON.parse_string(text))
	var rng_v = parsed.get("aiRngState", null)
	if not (rng_v is int):
		return {"ok": false, "error": Eng.err("SAVE_ERROR", "aiRngState missing or not a number")}
	var bad := _check_state(r["state"])
	if bad != "":
		return {"ok": false, "error": Eng.err("SAVE_ERROR", bad)}
	r["aiRngState"] = rng_v
	var actions: Array = []
	var dropped := false
	var raw = parsed.get("actions", null)
	if raw is Array:
		for a in raw:
			if a is Dictionary and ACTION_TYPES.has(str(a.get("type", ""))) and str(a.get("playerId", "")) != "":
				actions.append(a)
			else:
				dropped = true
				actions = []
				break
	elif raw != null:
		dropped = true
	r["actions"] = actions
	r["actionsDropped"] = dropped
	return r


## Minimal structural check so a damaged file is reported instead of crashing the board later.
static func _check_state(s: Dictionary) -> String:
	for k in ["players", "bars", "round", "phase", "config", "events", "moneyDeck", "rngState"]:
		if not s.has(k):
			return "gameState.%s missing" % k
	if not (s["players"] is Array) or s["players"].is_empty() or not (s["bars"] is Array):
		return "gameState players/bars malformed"
	return ""


## Re-applies the recorded human actions to a checkpoint. `state` is mutated (pass a copy to keep the checkpoint).
## Returns {"ok", "ctl", "pending", "applied"}; ok=false when an action no longer fits the engine (the caller falls back to the
## bare checkpoint). The controller keeps the events produced, so the board can replay them.
static func replay(state: Dictionary, ai_rng_state: int, actions: Array) -> Dictionary:
	var ctl = Ctl.new(state)
	ctl.ai_rng["rngState"] = ai_rng_state
	var pending = ctl.run()
	var applied := 0
	for a in actions:
		if pending == null or str(pending["type"]) != str(a["type"]):
			return {"ok": false, "ctl": ctl, "pending": pending, "applied": applied}
		var res: Dictionary = ctl.submit(a)
		if not res["ok"]:
			return {"ok": false, "ctl": ctl, "pending": pending, "applied": applied}
		pending = res["pending"]
		applied += 1
	return {"ok": true, "ctl": ctl, "pending": pending, "applied": applied}


static func clear() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## A slot that has a game in it (readable or not)
static func any_save() -> bool:
	for n in SLOTS:
		if FileAccess.file_exists(slot_path(n)):
			return true
	return false


## A save that cannot be read is kept (renamed) instead of deleted, so it can still be inspected or repaired.
static func quarantine() -> void:
	if has_save():
		var dest := path.get_basename() + ".corrupt." + str(int(Time.get_unix_time_from_system())) + ".json"
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(dest))
