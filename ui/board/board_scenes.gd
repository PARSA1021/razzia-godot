extends "res://ui/board/board_input.gd"
## Board scenes: the dialogue scenes (cutscenes) and their budget.
## Part of the board, split by topic (Phase 27). The final class is ui/game_screen.gd; each file extends the
## previous one, so every part sees the shared state and helpers below it. Presentation only: the engine decides.


func _scene_ok() -> bool:
	return tutorial == null and Settings.dialogue_on and OS.get_environment("RAZZIA_NO_DIALOGUE") != "1" and not skip and not bot.is_valid() and is_inside_tree() and not _ai_players().is_empty()


## kind: intro | final | duel (a big duel with the human) | raid | lead | end. Two or three lines that know what just
## happened (the venue, the money at stake, who leads and by how much), then the game goes on. Never hidden information.
func _play_scene(kind: String, extra: Dictionary = {}) -> void:
	if not _scene_ok():
		return
	var ais := _ai_players()
	var seed_n := int(state.get("config", {}).get("seed", 0)) % 9973 + int(state.get("seq", 0)) + int(state.get("round", 0)) * 7
	var lines: Array = []
	var ctx := {"total": T.money(int(state.get("totalMoney", 0)))}
	ctx.merge(extra.get("ctx", {}), true)
	var say := func(pl: Dictionary, k: String, n: int) -> void:
		var t: String = Characters.scene_text(k, str(pl["name"]), pl["personality"], n, ctx)
		if t != "":
			lines.append({"who": pl["name"], "personality": pl["personality"], "text": t})
	var a: Dictionary = ais[0]
	var b: Dictionary = ais[1] if ais.size() > 1 else {}
	var money_of := func(pid: String) -> int: return int(disp["money"].get(pid, 0))
	match kind:
		"intro":
			# two AIs with different personalities if possible
			for cand in ais:
				if cand["personality"] != a["personality"]:
					b = cand
					break
			say.call(a, "intro", seed_n)
			if not b.is_empty():
				say.call(b, "intro", seed_n + 1)
		"final":
			# who leads, and by how much (the money everyone can see on the chips)
			var everyone: Array = state["players"].duplicate()
			everyone.sort_custom(func(x, y): return money_of.call(str(x["id"])) > money_of.call(str(y["id"])))
			var leader: Dictionary = everyone[0]
			var second: Dictionary = everyone[1] if everyone.size() > 1 else everyone[0]
			ctx["leader"] = _my_scene_name() if _is_me(str(leader["id"])) else str(leader["name"])
			var gap_n := maxi(0, money_of.call(str(leader["id"])) - money_of.call(str(second["id"])))
			ctx["gap"] = T.money(gap_n)
			var ranked_ai := ais.duplicate()
			ranked_ai.sort_custom(func(x, y): return money_of.call(str(x["id"])) > money_of.call(str(y["id"])))
			a = ranked_ai[0]
			if gap_n < 10000:
				# neck and neck: nobody really leads
				say.call(a, "final_even", seed_n)
				if ranked_ai.size() > 1:
					say.call(ranked_ai[1], "final_even", seed_n + 1)
			elif str(a["id"]) == str(leader["id"]):
				say.call(a, "final_lead", seed_n)
				if ranked_ai.size() > 1:
					ctx["leader"] = str(a["name"])
					ctx["gap"] = T.money(maxi(0, money_of.call(str(a["id"])) - money_of.call(str(ranked_ai[1]["id"]))))
					say.call(ranked_ai[1], "final_chase", seed_n + 1)
			else:
				say.call(a, "final_chase", seed_n)
				if ranked_ai.size() > 1:
					say.call(ranked_ai[1], "final_chase", seed_n + 1)
		"duel":
			var winner_ai: bool = bool(extra.get("ai_won", false))
			var actor: Dictionary = extra["actor"]
			say.call(actor, "duel_win" if winner_ai else "duel_lose", seed_n)
			for cand in ais:
				if cand["id"] != actor["id"]:
					say.call(cand, "react", seed_n + 2)
					break
		"raid":
			# my police card shut an AI out (raided), or an AI's police card shut me out (raiding)
			say.call(extra["actor"], "raided" if bool(extra.get("me_raided_them", false)) else "raiding", seed_n)
		"lead":
			say.call(extra["actor"], "lead", seed_n)
		"end":
			var human_won: bool = human_id in extra.get("winnerIds", [])
			var ranked := ais.duplicate()
			ranked.sort_custom(func(x, y): return int(x["money"]) > int(y["money"]))
			var top: Dictionary = ranked[0]
			if human_won:
				ctx["leader"] = _my_scene_name()
				say.call(top, "end_lose", seed_n)
				if ranked.size() > 1:
					say.call(ranked[1], "end_lose", seed_n + 1)
			else:
				var wid: String = str(extra.get("winnerIds", [""])[0])
				var wp: Dictionary = top
				for cand in ais:
					if cand["id"] == wid:
						wp = cand
				ctx["pot"] = T.money(int(wp["money"]))
				ctx["leader"] = str(wp["name"])
				say.call(wp, "end_win", seed_n)
				for cand in ranked:
					if cand["id"] != wp["id"]:
						say.call(cand, "end_lose", seed_n + 1)
						break
	lines = lines.filter(func(l): return str(l["text"]) != "")
	if lines.is_empty():
		return
	scenes_shown.append(kind)
	Trace.log("scene", "%s (%d lines)" % [kind, lines.size()])
	var sc := DialogueScene.new()
	sc.lines = lines
	sc.title = Characters.scene_title(kind, ctx)
	add_child(sc)
	var skip_was: bool = skip_btn.visible
	skip_btn.visible = false                 # one SKIP on screen at a time: the scene's own
	Audio.reading(true)                      # the music drops back so the lines can be read
	var res = await sc.finished
	Audio.reading(false)
	if is_instance_valid(skip_btn):
		skip_btn.visible = skip_was
	Trace.log("scene", "%s finished skipped=%s" % [kind, str(res)])


func _mid_scene_ok() -> bool:
	return Settings.dialogue_mid and _scene_ok() and _scene_mid < MID_SCENES_MAX and int(disp.get("round", 0)) - _scene_last_round >= 2


func _mid_scene(kind: String, extra: Dictionary) -> void:
	_scene_mid += 1
	_scene_last_round = int(disp.get("round", 0))
	await _play_scene(kind, extra)


## how the cast calls me: by the name I chose, or "신입" / "Rookie" when I kept the default
func _my_scene_name() -> String:
	var n := str(names.get(human_id, "나"))
	return tr("신입") if n == "나" else n
