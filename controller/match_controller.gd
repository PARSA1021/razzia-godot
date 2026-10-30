extends RefCounted
## Action layer between UI and engine (docs/07 §8), port of tools/js/controller.js.
## It asks the AI for its moves using public views only, stops when a human decision is needed,
## and collects the engine events produced meanwhile.
##
## Usage:
##   var ctl = MatchController.new(state)
##   var pending = ctl.run()              # plays AI moves until a human must act (returns that request) or null
##   var r = ctl.submit(action)           # human action -> {"ok", "pending", "error"}
##   var events = ctl.drain_events()      # events to animate

const Eng = preload("res://engine/engine.gd")
const AI = preload("res://ai/ai.gd")

var state: Dictionary
var buffer: Array = []
var ai_seed: int = 0
var ai_rng: Dictionary = {}
var on_action: Callable = Callable()    # func(state, action) called after every accepted action
var error: Dictionary = {}              # set when an action was rejected; empty otherwise
## Tutorial only: func(kind: String, pid: String, view: Dictionary) -> Variant. A non-null answer replaces the AI's own
## choice for that decision (card id / bar id / allocations / "ACCEPT"|"DUEL"); null = the AI decides as usual.
## Every scripted answer still goes through the engine's rule checks like any other action.
var script_ai: Callable = Callable()


func _init(p_state: Dictionary, opts: Dictionary = {}) -> void:
	state = p_state
	if opts.has("aiSeed"):
		ai_seed = int(opts["aiSeed"]) & 0xFFFFFFFF
	else:
		ai_seed = (int(state["config"]["seed"]) ^ 0x5bd1e995) & 0xFFFFFFFF
	ai_rng = AI.new_rng(ai_seed)


func _is_human(pid: String) -> bool:
	return bool(Eng.get_player(state, pid)["isHuman"])


func _view(pid: String) -> Dictionary:
	return Eng.get_public_view(state, pid)


func _act(action: Dictionary, who: String) -> bool:
	var r := Eng.reduce_in_place(state, action)
	if not r["ok"]:
		error = r["error"]
		if who == "ai":
			error = Eng.err("AI_ERROR", "AI produced an invalid action: " + str(r["error"]["message"]))
		return false
	buffer.append_array(r["events"])
	if on_action.is_valid():
		on_action.call(state, action)
	return true


## Plays every AI decision until the human must act (or the game is over).
## Returns the pending human input, or null. After a rejected AI action, `error` is set and null is returned.
func run():
	for guard in range(100000):
		var p = Eng.get_pending_input(state)
		if p == null:
			return null
		var acted := false
		match p["type"]:
			"PLACE_EXTRA_MONEY":
				if _is_human(p["playerId"]):
					return p
				var bar_id = _scripted("PLACE_EXTRA_MONEY", p["playerId"])
				if bar_id == null:
					bar_id = AI.choose_extra_bar(_view(p["playerId"]), ai_rng)
				if not _act({"type": "PLACE_EXTRA_MONEY", "playerId": p["playerId"], "barId": bar_id}, "ai"):
					return null
				acted = true
			"SELECT_CARD":
				for pid in p["playerIds"]:
					if _is_human(pid):
						continue
					var card_id = _scripted("SELECT_CARD", pid)
					if card_id == null:
						card_id = AI.choose_card(_view(pid), ai_rng)
					if not _act({"type": "SELECT_CARD", "playerId": pid, "cardId": card_id}, "ai"):
						return null
					acted = true
				if not acted:
					return p
			"MAKE_PROPOSAL":
				if _is_human(p["playerId"]):
					return p
				var alloc = _scripted("MAKE_PROPOSAL", p["playerId"])
				if alloc == null:
					alloc = AI.make_proposal(_view(p["playerId"]), ai_rng)
				if not _act({"type": "MAKE_PROPOSAL", "playerId": p["playerId"], "allocations": alloc}, "ai"):
					return null
				acted = true
			"RESPOND":
				# every AI answers from its own view before any later answer exists: responses stay independent
				var answers := []
				for pid in p["playerIds"]:
					if not _is_human(pid):
						var r = _scripted("RESPOND", pid)
						if r == null:
							r = AI.respond_to_proposal(_view(pid), ai_rng)
						answers.append({"pid": pid, "r": r})
				for x in answers:
					if not _act({"type": "RESPOND", "playerId": x["pid"], "response": x["r"]}, "ai"):
						return null
					acted = true
				if not acted:
					return p
		if not acted:
			return p
	error = Eng.state_err("controller loop did not terminate")
	return null


func _scripted(kind: String, pid: String):
	if not script_ai.is_valid():
		return null
	return script_ai.call(kind, pid, _view(pid))


## Human action. Returns {"ok": bool, "pending": Variant, "error": Dictionary}.
func submit(action: Dictionary) -> Dictionary:
	error = {}
	if not _act(action, "human"):
		return {"ok": false, "pending": null, "error": error}
	var pending = run()
	return {"ok": error.is_empty(), "pending": pending, "error": error}


func drain_events() -> Array:
	var b := buffer
	buffer = []
	return b


func get_informant_intel(human_id: String = "P1") -> Dictionary:
	var RelicManager = preload("res://engine/relic_manager.gd")
	return RelicManager.get_informant_intel(state, human_id)
