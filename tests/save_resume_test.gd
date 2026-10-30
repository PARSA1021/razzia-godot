extends SceneTree
## Autosave / Continue: a decision the engine accepted can never be taken back or played twice (Phase 8A-1).
##   godot --headless --path . --script res://tests/save_resume_test.gd           (expected output: "... -> PASS")
##   godot --headless --path . --script res://tests/save_resume_test.gd -- norecord=1   (negative control: old protocol, must FAIL)
## The harness plays whole games with a stateless human policy and the SAME save protocol as GameScreen._flow
## (checkpoint when asked for a card / extra-money bar, record_action after every accepted human action).
## For EVERY point where the human could quit (before each decision and after each accepted one) the saved file is parsed,
## the controller restored with SaveStore.replay(), the game played to the end, and the final state compared with the
## uninterrupted game: full engine state incl. RNG state, hands, money, deck, phase and the complete event log.
const Eng = preload("res://engine/engine.gd")
const Ctl = preload("res://controller/match_controller.gd")
const AI = preload("res://ai/ai.gd")
const SaveStore = preload("res://ui/save_store.gd")
const Util = preload("res://engine/util.gd")

const TEST_PATH := "user://save_resume_test.json"
var checks := 0
var fails: Array = []
var cover := {}                  # kind of quit point -> how many were restored and verified
var t0 := 0
var _no_record := false          # negative control: `-- norecord=1` plays with the pre-8A-1 protocol (must make the test FAIL)


func _process(_d: float) -> bool:
	t0 = Time.get_ticks_msec()
	_no_record = OS.get_cmdline_user_args().has("norecord=1")
	SaveStore.path = TEST_PATH
	_cleanup()
	_run()
	_cleanup()
	print("SAVE RESUME TEST: checks=%d failed=%d secs=%.1f -> %s" % [checks, fails.size(), (Time.get_ticks_msec() - t0) / 1000.0, "PASS" if fails.is_empty() else "FAIL"])
	if not fails.is_empty():
		print("  failed: ", fails)
	quit(0 if fails.is_empty() else 1)
	return true


func _ok(name: String, cond: bool, info: String = "") -> void:
	checks += 1
	if not cond:
		fails.append(name)
		print("  FAIL %s %s" % [name, info])


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("save_resume_test"):
			dir.remove(f)


func _read() -> String:
	return FileAccess.get_file_as_string(TEST_PATH)


func _write_raw(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Stateless: depends only on the engine state, so the policy behaves identically before and after a restore.
func _policy(s: Dictionary, p: Dictionary) -> Dictionary:
	var v := Eng.get_public_view(s, "P1")
	var rng := AI.new_rng(int(s["seq"]) * 31 + 7)
	match str(p["type"]):
		"SELECT_CARD": return {"type": "SELECT_CARD", "playerId": "P1", "cardId": AI.choose_card(v, rng)}
		"PLACE_EXTRA_MONEY": return {"type": "PLACE_EXTRA_MONEY", "playerId": "P1", "barId": AI.choose_extra_bar(v, rng)}
		"MAKE_PROPOSAL": return {"type": "MAKE_PROPOSAL", "playerId": "P1", "allocations": AI.make_proposal(v, rng)}
		"RESPOND": return {"type": "RESPOND", "playerId": "P1", "response": AI.respond_to_proposal(v, rng)}
	return {}


## GameScreen._flow without the animations. `cut`: stop at that human decision point (0-based, 2 points per decision:
## 2k = asked (checkpoint written, nothing decided), 2k+1 = decision accepted and recorded). cut < 0: play to the end.
## Returns {"cut": bool, "state", "kind": String} where kind describes the quit point.
func _play(ctl, cut: int) -> Dictionary:
	var point := 0
	var pending = ctl.run()
	var last_events: Array = []
	while pending != null:
		if pending["type"] == "SELECT_CARD" or pending["type"] == "PLACE_EXTRA_MONEY":
			SaveStore.save(ctl.state, int(ctl.ai_rng["rngState"]))
		if point == cut:
			return {"cut": true, "kind": "asked:" + str(pending["type"]), "state": ctl.state}
		point += 1
		var action := _policy(ctl.state, pending)
		var r: Dictionary = ctl.submit(action)
		_ok("engine accepts the human action", r["ok"], str(r["error"]))
		if not _no_record:
			SaveStore.record_action(action)
		last_events = ctl.drain_events()
		if point == cut:
			var kind := "after:" + str(action["type"])
			var types := last_events.map(func(e): return e["type"])
			if types.has("DUEL_RESOLVED"):
				kind += "+duel"
			if types.has("ROUND_ENDED"):
				kind += "+round_end"
			if types.has("GAME_ENDED"):
				kind += "+game_end"
			if types.has("CARDS_REVEALED"):
				kind += "+reveal"
			return {"cut": true, "kind": kind, "state": ctl.state}
		point += 1
		pending = r["pending"]
	return {"cut": false, "kind": "end", "state": ctl.state}


func _new_game(players: int, seed_v: int) -> Dictionary:
	return Eng.create_game({"playerCount": players, "seed": seed_v, "humanPlayerId": "P1",
		"names": ["나", "Vito", "Lola", "Mack", "Dutch", "Rosie", "Sal", "Nico"].slice(0, players)})


func _restore_from_file() -> Dictionary:
	var parsed := SaveStore.load_save()
	if not parsed["ok"]:
		return {"ok": false, "parsed": parsed}
	var res := SaveStore.replay(parsed["state"].duplicate(true), int(parsed["aiRngState"]), parsed["actions"])
	res["parsed"] = parsed
	return res


func _run() -> void:
	var configs := [[4, 5], [3, 9], [5, 21], [6, 12], [4, 33], [8, 4]]
	var total_points := 0
	for cfg in configs:
		var n: int = cfg[0]
		var sd: int = cfg[1]
		# uninterrupted reference
		var ref_ctl := Ctl.new(_new_game(n, sd))
		SaveStore.clear()
		_play(ref_ctl, -1)
		var ref_final := Eng.serialize_game(ref_ctl.state)
		_ok("[%dp seed %d] reference game finished" % [n, sd], ref_ctl.state["phase"] == "GAME_OVER" or ref_ctl.state["phase"] == "GAME_ENDED" or Eng.get_pending_input(ref_ctl.state) == null)
		# every quit point
		var point := 0
		while true:
			SaveStore.clear()
			var ctl := Ctl.new(_new_game(n, sd))
			var cut := _play(ctl, point)
			if not cut["cut"]:
				break
			total_points += 1
			# "quit the app": drop every in-memory object, keep only the file
			var text_before := _read()
			var res := _restore_from_file()
			var file_after_restore := _read()
			var tag := "[%dp seed %d point %d %s]" % [n, sd, point, cut["kind"]]
			if not res["ok"]:
				_ok(tag + " saved file restores", false, str(res.get("parsed", {}).get("error", "")))
				point += 1
				continue
			var parsed: Dictionary = res["parsed"]
			_ok(tag + " every recorded action re-applied", res["applied"] == parsed["actions"].size() and not parsed["actionsDropped"])
			# already-decided players are not asked again / nothing selected twice: at most one selection per player per round
			var sel := {}
			var dup := false
			for e in res["ctl"].state["events"]:
				if e["type"] == "CARD_SELECTED":
					var k := "%s-%s" % [e["round"], e["playerId"]]
					if sel.has(k):
						dup = true
					sel[k] = true
			_ok(tag + " no player has two CARD_SELECTED in one round", not dup)
			# restored state is exactly the state the quitting session had
			_ok(tag + " restored engine state == state at quit", Eng.serialize_game(res["ctl"].state) == Eng.serialize_game(cut["state"]))
			# play on from the restored controller to the end
			var tail := _play(res["ctl"], -1)
			var kind: String = str(cut["kind"])
			cover[kind] = int(cover.get(kind, 0)) + 1
			_ok(tag + " finishing after Continue gives the uninterrupted result", Eng.serialize_game(tail["state"]) == ref_final)
			_ok(tag + " restoring left the file untouched", file_after_restore == text_before)
			point += 1
			if point > 400:
				_ok("quit point count sane", false)
				break
		_ok("[%dp seed %d] had quit points" % [n, sd], point > 10, "(%d)" % point)
	print("  quit points restored and verified: %d" % total_points)
	for k in cover:
		print("    %-40s %d" % [k, cover[k]])
	# coverage: the scenarios the task lists must really have been created and restored
	for need in ["asked:SELECT_CARD", "after:SELECT_CARD+reveal", "asked:PLACE_EXTRA_MONEY", "after:PLACE_EXTRA_MONEY"]:
		_ok("covered quit point '%s'" % need, _covered(need))
	_ok("covered: quit after a proposal", _covered("after:MAKE_PROPOSAL"))
	_ok("covered: quit after a response", _covered("after:RESPOND"))
	_ok("covered: quit after a duel", _covered("+duel"))
	_ok("covered: quit when a round ended", _covered("+round_end"))
	_ok("covered: quit when the game ended", _covered("+game_end"))
	_ok("covered: quit while asked for a proposal or a response", _covered("asked:MAKE_PROPOSAL") or _covered("asked:RESPOND"))
	_formats()


func _covered(part: String) -> bool:
	for k in cover:
		if str(k).contains(part):
			return true
	return false


## 10 old file, 11 damaged/missing fields, 12 repeated loads, atomic write
func _formats() -> void:
	# --- 10: a file written by the pre-8A-1 SaveStore (tests/fixtures), no "actions" field
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/autosave_v1_before_8a1.json")
	_ok("10 fixture present", fixture != "")
	var old := SaveStore.parse_save(fixture)
	_ok("10 old file parses", old["ok"] and old["actions"].is_empty() and not old["actionsDropped"])
	var r1 := SaveStore.replay(old["state"].duplicate(true), int(old["aiRngState"]), old["actions"])
	_ok("10 old file restores at its card prompt", r1["ok"] and r1["pending"] != null and r1["pending"]["type"] == "SELECT_CARD" and int(r1["ctl"].state["round"]) == 4)
	var a_final: Dictionary = _play(r1["ctl"], -1)["state"]
	var r2 := SaveStore.replay(old["state"].duplicate(true), int(old["aiRngState"]), [])
	var b_final: Dictionary = _play(r2["ctl"], -1)["state"]
	_ok("10 old file: two independent resumes finish identically", Eng.serialize_game(a_final) == Eng.serialize_game(b_final))
	_ok("10 old file: finished game keeps the invariants", Eng.check_invariants(a_final).is_empty())
	# --- 11: damaged / missing fields
	var good := Eng.serialize_game(_new_game(4, 5))
	var good_d: Dictionary = JSON.parse_string(fixture)
	var bad_cases := {
		"not json": "{ this is not json",
		"json array": "[1, 2, 3]",
		"empty": "",
		"no gameState": JSON.stringify({"version": 1, "aiRngState": 5}),
		"wrong version": JSON.stringify({"version": 99, "gameState": good_d["gameState"], "aiRngState": 5}),
		"no aiRngState": JSON.stringify({"version": 1, "gameState": good_d["gameState"]}),
		"aiRngState is text": JSON.stringify({"version": 1, "gameState": good_d["gameState"], "aiRngState": "x"}),
		"gameState without players": JSON.stringify({"version": 1, "gameState": {"round": 1}, "aiRngState": 5}),
		"truncated file": fixture.substr(0, fixture.length() / 2),
	}
	for name in bad_cases:
		var r := SaveStore.parse_save(bad_cases[name])
		_ok("11 damaged save rejected without crashing: %s" % name, not r["ok"] and r.has("error"))
	var soft_cases := {
		"actions is not an array": {"actions": "x"},
		"action is not an object": {"actions": [5]},
		"action without type": {"actions": [{"playerId": "P1"}]},
		"action with unknown type": {"actions": [{"type": "FLY", "playerId": "P1"}]},
		"action without player": {"actions": [{"type": "SELECT_CARD"}]},
	}
	for name in soft_cases:
		var d: Dictionary = good_d.duplicate(true)
		d["actions"] = soft_cases[name]["actions"]
		var r := SaveStore.parse_save(JSON.stringify(d))
		_ok("11 bad actions are dropped, checkpoint kept: %s" % name, r["ok"] and r["actions"].is_empty() and r["actionsDropped"])
	# an action that no longer fits the checkpoint: replay reports it, nothing is half-applied silently
	var wrong: Dictionary = good_d.duplicate(true)
	wrong["actions"] = [{"type": "RESPOND", "playerId": "P1", "response": "ACCEPT"}]
	var wr := SaveStore.parse_save(JSON.stringify(wrong))
	var wres := SaveStore.replay(wr["state"].duplicate(true), int(wr["aiRngState"]), wr["actions"])
	_ok("11 action of the wrong type is refused (ok=false, applied=0)", not wres["ok"] and wres["applied"] == 0)
	var fb := SaveStore.replay(wr["state"].duplicate(true), int(wr["aiRngState"]), [])
	_ok("11 fallback to the bare checkpoint works", fb["ok"] and fb["pending"] != null and fb["pending"]["type"] == "SELECT_CARD")
	var wrong2: Dictionary = good_d.duplicate(true)
	wrong2["actions"] = [{"type": "SELECT_CARD", "playerId": "P1", "cardId": "NOT-A-CARD"}]
	var w2 := SaveStore.parse_save(JSON.stringify(wrong2))
	var w2r := SaveStore.replay(w2["state"].duplicate(true), int(w2["aiRngState"]), w2["actions"])
	_ok("11 engine-rejected action is refused (ok=false, applied=0)", not w2r["ok"] and w2r["applied"] == 0)
	# on disk: unreadable save is kept (quarantined), not deleted; record_action never touches a damaged file
	SaveStore.clear()
	_ok("11 record_action without a save is a no-op", not SaveStore.record_action({"type": "SELECT_CARD", "playerId": "P1"}))
	_write_raw("{ half written")
	_ok("11 load_save reports the damaged file", not SaveStore.load_save()["ok"])
	_ok("11 record_action refuses a damaged file and leaves it alone", not SaveStore.record_action({"type": "SELECT_CARD", "playerId": "P1"}) and _read() == "{ half written")
	SaveStore.quarantine()
	var kept := false
	var dir := DirAccess.open("user://")
	for f in dir.get_files():
		if f.begins_with("save_resume_test.corrupt."):
			kept = FileAccess.get_file_as_string("user://" + f) == "{ half written"
	_ok("11 damaged save is quarantined with its content, not deleted", kept and not SaveStore.has_save())
	# atomic write: no temp file left behind, content is the complete document
	SaveStore.clear()
	SaveStore.save(_new_game(4, 5), 123)
	_ok("write: no leftover .tmp", not FileAccess.file_exists(TEST_PATH + ".tmp"))
	var back := SaveStore.load_save()
	_ok("write: file reads back (aiRngState 123, actions [])", back["ok"] and back["aiRngState"] == 123 and back["actions"].is_empty())
	SaveStore.record_action({"type": "SELECT_CARD", "playerId": "P1", "cardId": "X"})
	SaveStore.record_action({"type": "RESPOND", "playerId": "P1", "response": "ACCEPT"})
	var back2 := SaveStore.load_save()
	_ok("write: record_action appends in order and keeps the checkpoint", back2["ok"] and back2["actions"].size() == 2 and back2["actions"][0]["type"] == "SELECT_CARD" and back2["actions"][1]["type"] == "RESPOND" and Eng.serialize_game(back2["state"]) == Eng.serialize_game(back["state"]), "")
	SaveStore.save(_new_game(4, 5), 124)
	_ok("write: a new checkpoint clears the recorded actions", SaveStore.load_save()["actions"].is_empty())
	# --- 12: the same file loaded several times
	SaveStore.clear()
	var ctl := Ctl.new(_new_game(4, 5))
	var cut := _play(ctl, 5)                        # somewhere in the middle of the game
	var bytes := _read()
	var finals: Array = []
	var firsts: Array = []
	for i in range(3):
		var res := _restore_from_file()
		firsts.append(Eng.serialize_game(res["ctl"].state))
		finals.append(Eng.serialize_game(_play(res["ctl"], -1)["state"]))
		SaveStore.clear()
		_write_raw(bytes)                             # _play() rewrites the file: put the original bytes back
	_ok("12 same file, 3 loads: identical restored state", firsts[0] == firsts[1] and firsts[1] == firsts[2])
	_ok("12 same file, 3 loads: identical final result", finals[0] == finals[1] and finals[1] == finals[2])
	_ok("12 loading does not change the file", _read() == bytes)
	print("  (middle-of-game file was at point '%s')" % cut["kind"])
