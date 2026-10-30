extends SceneTree
## Automated test suite for Phase 2 & 3 Relic System.
## Run headless: godot --headless --path . --script res://tests/relic_system_test.gd

const Eng = preload("res://engine/engine.gd")
const RelicManager = preload("res://engine/relic_manager.gd")
const MatchController = preload("res://controller/match_controller.gd")

var _checks := 0
var _failed := 0


func _init() -> void:
	print("--- Running Relic System Test Suite ---")
	test_relic_definitions_and_common()
	test_starter_choices()
	test_informant_relic()
	test_bribed_judge_relic()
	test_dirty_cop_relic()
	test_lucky_coin_relic()
	test_loaded_dice_relic()
	test_protection_racket_relic()
	test_swiss_account_relic()
	test_syndicate_crest_relic()
	test_save_load_persistence()
	test_classic_mode_isolation()

	print("\nRELIC TEST SUMMARY: %d checks, %d failed" % [_checks, _failed])
	if _failed > 0:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


func assert_eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual != expected:
		_failed += 1
		print("FAIL: %s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func assert_true(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failed += 1
		print("FAIL: %s" % msg)


func test_relic_definitions_and_common() -> void:
	print("\n[Group 1: Relic Definitions & Common Management]")
	var all_ids: Array = RelicManager.all_relic_ids()
	assert_eq(all_ids.size(), 8, "Exactly 8 relics defined in catalog")
	var seen := {}
	for id in all_ids:
		assert_true(not seen.has(id), "Relic ID '%s' is not duplicated" % id)
		seen[id] = true
		var def: Dictionary = RelicManager.get_definition(id)
		assert_true(def.has("rarity"), "Relic '%s' has rarity defined" % id)
		assert_true(def.has("price"), "Relic '%s' has price defined" % id)
		assert_true(int(def["price"]) > 0, "Relic '%s' price is positive" % id)

	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 42})
	var invalid_res: bool = RelicManager.add_relic(s, "P1", "nonexistent_super_gun")
	assert_eq(invalid_res, false, "Adding invalid relic ID returns false")
	assert_eq(RelicManager.has_relic(s, "P1", "nonexistent_super_gun"), false, "Invalid relic not present")

	var r1: bool = RelicManager.add_relic(s, "P1", "informant")
	assert_eq(r1, true, "First addition of valid relic returns true")
	var r2: bool = RelicManager.add_relic(s, "P1", "informant")
	assert_eq(r2, false, "Duplicate addition of same relic returns false")
	assert_eq(RelicManager.get_player_relics(s, "P1").size(), 1, "Player holds exactly 1 copy")

	RelicManager.add_relic(s, "P2", "bribed_judge")
	assert_true(RelicManager.has_relic(s, "P1", "informant"), "P1 has informant")
	assert_true(not RelicManager.has_relic(s, "P1", "bribed_judge"), "P1 does not have bribed judge")
	assert_true(RelicManager.has_relic(s, "P2", "bribed_judge"), "P2 has bribed judge")


func test_starter_choices() -> void:
	print("\n[Group 2: Starter Relic Draft]")
	var starters: Array = RelicManager.get_starter_choices()
	assert_eq(starters.size(), 3, "Starter draft provides exactly 3 choices")
	var s_ids := []
	for st in starters:
		s_ids.append(st["id"])
	assert_true(s_ids.has("lucky_coin"), "Starter includes lucky_coin (Duel)")
	assert_true(s_ids.has("protection_racket"), "Starter includes protection_racket (Economy)")
	assert_true(s_ids.has("informant"), "Starter includes informant (Intel)")


func test_informant_relic() -> void:
	print("\n[Group 3: Relic 01 — The Informant]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 777, "relics": ["informant"], "humanPlayerId": "P1", "firstCroupierId": "P2"})
	var ctl = MatchController.new(s)
	var p = ctl.run()
	assert_true(p != null, "Controller paused for human input")
	assert_eq(p["type"], "SELECT_CARD", "Human input is SELECT_CARD")

	var intel: Dictionary = RelicManager.get_informant_intel(s, "P1")
	assert_true(not intel.is_empty(), "Informant intel available when human chooses card")
	assert_eq(intel.get("relicId"), "informant", "Intel relicId is informant")
	assert_true(intel.has("targetId"), "Intel includes targetId")
	assert_true(intel.has("barId"), "Intel includes barId")

	var target_pid: String = intel["targetId"]
	var target_p = Eng.get_player(s, target_pid)
	assert_true(not target_p["isHuman"], "Target is an AI player")
	var card = s["cards"][target_p["selectedCardId"]]
	assert_eq(card["barId"], intel["barId"], "Intel accurately reported the target bar")

	var p2_intel: Dictionary = RelicManager.get_informant_intel(s, "P2")
	assert_true(p2_intel.is_empty(), "P2 without Informant receives empty intel")


func test_bribed_judge_relic() -> void:
	print("\n[Group 4: Relic 02 — Bribed Judge]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 101, "relics": ["bribed_judge"], "humanPlayerId": "P1"})
	# P2 challenges P1. Standard tie rule: P2 wins. Bribed Judge rule: P1 wins.
	var winner1: String = RelicManager.resolve_duel_tie(s, "P1", "P2", "P2")
	assert_eq(winner1, "P1", "Defender P1 with Bribed Judge wins tie against challenger P2")

	# P1 challenges P2. Challenger P1 wins naturally and judge overrule is not needed.
	var winner2: String = RelicManager.resolve_duel_tie(s, "P1", "P2", "P1")
	assert_eq(winner2, "P1", "Challenger P1 wins tie")

	# Both players have Bribed Judge: falls back to challenger rule
	RelicManager.add_relic(s, "P2", "bribed_judge")
	var winner3: String = RelicManager.resolve_duel_tie(s, "P1", "P2", "P2")
	assert_eq(winner3, "P2", "Both bribed: falls back to challenger P2")


func test_dirty_cop_relic() -> void:
	print("\n[Group 5: Relic 03 — Dirty Cop]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 202, "relics": ["dirty_cop"], "humanPlayerId": "P1"})
	var bar: Dictionary = s["bars"][0]
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 0
	var old_money: int = int(bar["money"])
	bar["money"] = 100000
	s["totalMoney"] += (100000 - old_money)

	var awarded = RelicManager.handle_failed_raid(s, bar, ["P1"])
	assert_eq(awarded.size(), 1, "Extortion event generated on failed raid")
	assert_eq(p1["money"], 15000, "P1 received 15% bribe ($15,000 on $100,000)")
	assert_eq(bar["money"], 85000, "Bar safe reduced by exactly $15,000")

	var inv_errs = Eng.check_invariants(s)
	assert_eq(inv_errs.size(), 0, "INV-002 strictly preserved after Dirty Cop bribe")


func test_lucky_coin_relic() -> void:
	print("\n[Group 6: Relic 04 — Lucky Coin]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 303, "relics": ["lucky_coin"], "humanPlayerId": "P1"})
	var boost_p1: int = RelicManager.apply_duel_score_bonus(s, "P1")
	assert_eq(boost_p1, 1, "Lucky Coin grants +1 score boost")

	var boost_p2: int = RelicManager.apply_duel_score_bonus(s, "P2")
	assert_eq(boost_p2, 0, "P2 without Lucky Coin receives 0 boost")


func test_loaded_dice_relic() -> void:
	print("\n[Group 7: Relic 05 — Loaded Dice]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 404, "relics": ["loaded_dice"], "humanPlayerId": "P1"})
	assert_eq(RelicManager.apply_duel_die_bonus(s, "P1", 1), 3, "Roll of 1 upgraded to 3")
	assert_eq(RelicManager.apply_duel_die_bonus(s, "P1", 2), 3, "Roll of 2 upgraded to 3")
	assert_eq(RelicManager.apply_duel_die_bonus(s, "P1", 4), 4, "Roll of 4 unchanged")
	assert_eq(RelicManager.apply_duel_die_bonus(s, "P1", 6), 6, "Roll of 6 unchanged")

	assert_eq(RelicManager.apply_duel_die_bonus(s, "P2", 1), 1, "P2 roll of 1 not upgraded")


func test_protection_racket_relic() -> void:
	print("\n[Group 8: Relic 06 — Protection Racket]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 505, "relics": ["protection_racket"], "humanPlayerId": "P1"})
	var p1 = Eng.get_player(s, "P1")
	s["totalMoney"] += 10000
	p1["money"] = 10000
	var bonus: int = RelicManager.handle_solo_bar_bonus(s, "P1", "COLIBRI")
	assert_eq(bonus, 5000, "Protection racket awards +$5,000 on solo bar")
	assert_eq(p1["money"], 15000, "P1 money updated to $15,000")

	var inv_errs = Eng.check_invariants(s)
	assert_eq(inv_errs.size(), 0, "INV-002 strictly preserved across solo bonus")

	var p2_bonus: int = RelicManager.handle_solo_bar_bonus(s, "P2", "COLIBRI")
	assert_eq(p2_bonus, 0, "P2 without relic receives 0 bonus")


func test_swiss_account_relic() -> void:
	print("\n[Group 9: Relic 07 — Swiss Account]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 606, "relics": ["swiss_account"], "humanPlayerId": "P1"})
	var p1 = Eng.get_player(s, "P1")
	s["totalMoney"] += 50000
	p1["money"] = 50000
	var evs = RelicManager.handle_round_cleanup(s)
	assert_eq(evs.size(), 1, "Interest event generated")
	assert_eq(p1["money"], 55000, "10% interest awarded ($5,000 on $50,000)")

	# Check cap at $12,000
	s["totalMoney"] += (200000 - 55000)
	p1["money"] = 200000 # 10% would be $20k, capped at $12k
	RelicManager.handle_round_cleanup(s)
	assert_eq(p1["money"], 212000, "Interest capped at $12,000")

	var inv_errs = Eng.check_invariants(s)
	assert_eq(inv_errs.size(), 0, "INV-002 strictly preserved across interest")


func test_syndicate_crest_relic() -> void:
	print("\n[Group 10: Relic 08 — Syndicate Crest]")
	var s: Dictionary = Eng.create_game({
		"playerCount": 3, "seed": 707,
		"relics": [],
		"humanPlayerId": "P1"
	})
	RelicManager.init_game_relics(s, ["syndicate_crest", "lucky_coin", "loaded_dice"], "P1")
	var p1 = Eng.get_player(s, "P1")
	var initial_p1_money: int = int(p1["money"])
	# 3 relics owned -> 3 * $3,000 = $9,000 dividend
	var evs = RelicManager.handle_round_start(s)
	assert_eq(evs.size(), 1, "Dividend event generated")
	assert_eq(p1["money"], initial_p1_money + 9000, "Received $9,000 dividend for 3 owned relics")

	var inv_errs = Eng.check_invariants(s)
	assert_eq(inv_errs.size(), 0, "INV-002 strictly preserved across dividend")


func test_save_load_persistence() -> void:
	print("\n[Group 11: Save/Load Persistence]")
	var s: Dictionary = Eng.create_game({
		"playerCount": 3, "seed": 808,
		"relics": ["informant", "bribed_judge", "lucky_coin", "loaded_dice"],
		"humanPlayerId": "P1",
	})
	var json_str: String = Eng.serialize_game(s)
	assert_true(json_str.length() > 0, "Serialization produces valid JSON string")

	var loaded = Eng.load_game(json_str)
	assert_true(loaded["ok"], "load_game succeeds")
	var restored_state: Dictionary = loaded["state"]

	assert_true(RelicManager.has_relic(restored_state, "P1", "informant"), "P1 has informant")
	assert_true(RelicManager.has_relic(restored_state, "P1", "bribed_judge"), "P1 has bribed_judge")
	assert_true(RelicManager.has_relic(restored_state, "P1", "lucky_coin"), "P1 has lucky_coin")
	assert_true(RelicManager.has_relic(restored_state, "P1", "loaded_dice"), "P1 has loaded_dice")
	assert_true(not RelicManager.has_relic(restored_state, "P1", "dirty_cop"), "P1 does not have dirty_cop")


func test_classic_mode_isolation() -> void:
	print("\n[Group 12: Classic Mode 100% Isolation]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 999})
	assert_true(not s.has("relics"), "Classic mode state does not have relics dictionary")
	assert_eq(RelicManager.has_relic(s, "P1", "lucky_coin"), false, "No lucky_coin in classic mode")
	assert_eq(RelicManager.has_relic(s, "P1", "loaded_dice"), false, "No loaded_dice in classic mode")
	assert_eq(RelicManager.has_relic(s, "P1", "protection_racket"), false, "No protection_racket in classic mode")

	var roll = RelicManager.apply_duel_die_bonus(s, "P1", 1)
	assert_eq(roll, 1, "Classic mode die roll unchanged")
	var boost = RelicManager.apply_duel_score_bonus(s, "P1")
	assert_eq(boost, 0, "Classic mode duel boost is 0")
	var solo = RelicManager.handle_solo_bar_bonus(s, "P1", "COLIBRI")
	assert_eq(solo, 0, "Classic mode solo bonus is 0")

	var res = RelicManager.resolve_duel_tie(s, "P1", "P2", "P2")
	assert_eq(res, "P2", "Classic mode tie always awards to challenger")
