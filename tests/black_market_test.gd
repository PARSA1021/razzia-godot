extends SceneTree
## Automated test suite for Phase 3-A Black Market Shop & Roguelike Loop.
## Run headless: godot --headless --path . --script res://tests/black_market_test.gd

const Eng = preload("res://engine/engine.gd")
const RelicManager = preload("res://engine/relic_manager.gd")
const MatchController = preload("res://controller/match_controller.gd")
const BlackMarketPanel = preload("res://ui/board/black_market_panel.gd")

var _checks := 0
var _failed := 0


func _init() -> void:
	print("--- Running Black Market Shop Test Suite ---")
	test_relic_pricing_and_offerings()
	test_purchase_success_and_ledger()
	test_insufficient_funds_rejection()
	test_duplicate_purchase_prevention()
	test_black_market_vault_inv002_conservation()
	test_reroll_shop_functionality()
	test_save_load_persistence()
	test_classic_mode_isolation()
	test_ui_panel_instantiation()

	print("\nBLACK MARKET TEST SUMMARY: %d checks, %d failed" % [_checks, _failed])
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


func test_relic_pricing_and_offerings() -> void:
	print("\n[Group 1: Relic Pricing & Shop Offerings]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 101, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 28000

	var offerings: Array = RelicManager.get_shop_offerings(s, "P1")
	assert_eq(offerings.size(), 4, "Shop presents exactly 4 relic offerings")

	for o in offerings:
		assert_true(o.has("rarity"), "Offering has rarity")
		assert_true(o.has("price"), "Offering has price")
		assert_true(o.has("canAfford"), "Offering has canAfford flag")
		assert_true(o.has("owned"), "Offering has owned flag")

	p1["money"] = 1000 # cannot afford any relic
	var off2 = RelicManager.get_shop_offerings(s, "P1")
	for o in off2:
		assert_eq(o["canAfford"], false, "Cannot afford with $1,000")


func test_purchase_success_and_ledger() -> void:
	print("\n[Group 2: Purchase Success & Ledger]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 202, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 60000

	# Buy Informant for $10,000
	var res = RelicManager.buy_relic(s, "P1", "informant")
	assert_true(res["ok"], "Purchase succeeds")
	assert_eq(p1["money"], 50000, "P1 money deducted correctly ($60k - $10k = $50k)")
	assert_eq(int(s["blackMarketVault"]), 10000, "Black Market Vault holds $10,000")
	assert_true(RelicManager.has_relic(s, "P1", "informant"), "P1 now owns informant relic")

	# Verify transaction event was appended
	var events: Array = s["events"]
	var last_ev: Dictionary = events[-1]
	assert_eq(last_ev["type"], "RELIC_PURCHASED", "Event type is RELIC_PURCHASED")
	assert_eq(last_ev["playerId"], "P1", "Event playerId is P1")
	assert_eq(last_ev["relicId"], "informant", "Event relicId is informant")
	assert_eq(last_ev["price"], 10000, "Event price is 10000")


func test_insufficient_funds_rejection() -> void:
	print("\n[Group 3: Insufficient Funds Rejection]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 303, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 5000 # not enough for any relic

	var res = RelicManager.buy_relic(s, "P1", "informant")
	assert_eq(res["ok"], false, "Purchase rejected")
	assert_eq(res["reason"], "INSUFFICIENT_FUNDS", "Rejection reason is INSUFFICIENT_FUNDS")
	assert_eq(p1["money"], 5000, "P1 money completely untouched")
	assert_eq(RelicManager.has_relic(s, "P1", "informant"), false, "Relic was not granted")


func test_duplicate_purchase_prevention() -> void:
	print("\n[Group 4: Duplicate Purchase Prevention]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 404, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 100000

	# First purchase: success
	var r1 = RelicManager.buy_relic(s, "P1", "bribed_judge")
	assert_true(r1["ok"], "First purchase succeeded")
	assert_eq(p1["money"], 85000, "P1 money is $85,000 ($100k - $15k)")

	# Second purchase of same relic: rejected
	var r2 = RelicManager.buy_relic(s, "P1", "bribed_judge")
	assert_eq(r2["ok"], false, "Second purchase rejected")
	assert_eq(r2["reason"], "ALREADY_OWNED", "Reason is ALREADY_OWNED")
	assert_eq(p1["money"], 85000, "Money not deducted twice")
	assert_eq(RelicManager.get_player_relics(s, "P1").size(), 1, "Player holds exactly 1 copy")


func test_black_market_vault_inv002_conservation() -> void:
	print("\n[Group 5: INV-002 Money Conservation]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 505, "relics": []})
	var p1 = Eng.get_player(s, "P1")

	# Give P1 initial money legally by taking from a bar
	var bar = s["bars"][0]
	var old_money: int = int(bar["money"])
	bar["money"] = 100000
	s["totalMoney"] += (100000 - old_money)
	Eng.award_money(s, "P1", 70000, bar["id"])

	# Initial invariant check passes
	var errs0 = Eng.check_invariants(s)
	assert_eq(errs0.size(), 0, "Initial invariant check has 0 errors")

	# Buy Bribed Judge ($15k) and Informant ($10k) -> total $25k spent
	RelicManager.buy_relic(s, "P1", "bribed_judge")
	RelicManager.buy_relic(s, "P1", "informant")

	assert_eq(p1["money"], 45000, "P1 remaining money is $45,000 ($70k - $25k)")
	assert_eq(int(s["blackMarketVault"]), 25000, "Vault holds $25,000")

	# Invariant check strictly satisfied with vault
	var errs = Eng.check_invariants(s)
	assert_eq(errs.size(), 0, "INV-002 strictly preserved across black market purchases")


func test_reroll_shop_functionality() -> void:
	print("\n[Group 6: Shop Reroll Functionality]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 606, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	s["totalMoney"] += 30000
	p1["money"] = 30000

	# Reroll shop for $5,000
	var res = RelicManager.reroll_shop(s, "P1")
	assert_true(res["ok"], "Reroll succeeds with sufficient funds")
	assert_eq(p1["money"], 25000, "P1 money deducted by $5,000 reroll cost")
	assert_eq(int(s["blackMarketVault"]), 5000, "Reroll fee moved to vault")
	assert_eq(int(s["shopRerolls"]), 1, "Reroll counter incremented")

	var errs = Eng.check_invariants(s)
	assert_eq(errs.size(), 0, "INV-002 strictly preserved after shop reroll")

	# Attempt reroll with insufficient funds
	p1["money"] = 2000
	var res_fail = RelicManager.reroll_shop(s, "P1")
	assert_eq(res_fail["ok"], false, "Reroll fails with insufficient funds")
	assert_eq(res_fail["reason"], "INSUFFICIENT_FUNDS", "Reason is INSUFFICIENT_FUNDS")


func test_save_load_persistence() -> void:
	print("\n[Group 7: Save/Load Persistence of Roguelike State]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 707, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 50000

	# Purchase relic
	RelicManager.buy_relic(s, "P1", "dirty_cop")
	assert_eq(p1["money"], 32000, "P1 money deducted for dirty_cop ($18k)")
	assert_eq(int(s["blackMarketVault"]), 18000, "Vault holds $18,000")

	# Serialize & reload
	var serialized: String = Eng.serialize_game(s)
	var loaded: Dictionary = Eng.load_game(serialized)
	assert_true(loaded["ok"], "Game loaded successfully")
	var restored = loaded["state"]

	assert_true(RelicManager.has_relic(restored, "P1", "dirty_cop"), "Dirty cop relic retained after reload")
	var restored_p1 = Eng.get_player(restored, "P1")
	assert_eq(restored_p1["money"], 32000, "Deducted balance preserved after reload ($32,000)")
	assert_eq(int(restored.get("blackMarketVault", 0)), 18000, "Vault balance preserved after reload ($18,000)")

	var re_buy = RelicManager.buy_relic(restored, "P1", "dirty_cop")
	assert_eq(re_buy["ok"], false, "Cannot re-purchase dirty_cop after reload")


func test_classic_mode_isolation() -> void:
	print("\n[Group 8: Classic Mode 100% Isolation]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 808})
	assert_eq(RelicManager.is_relic_mode(s), false, "Classic mode is not relic mode")
	assert_eq(s.has("relics"), false, "Classic state has no relics key")
	assert_eq(s.has("blackMarketVault"), false, "Classic state has no blackMarketVault")


func test_ui_panel_instantiation() -> void:
	print("\n[Group 9: UI Panel Instantiation & Responsiveness]")
	var s: Dictionary = Eng.create_game({"playerCount": 3, "seed": 909, "relics": []})
	var p1 = Eng.get_player(s, "P1")
	p1["money"] = 40000

	var panel = BlackMarketPanel.new()
	panel.setup(s, "P1", 1.0, true)
	assert_true(panel != null, "BlackMarketPanel instantiated cleanly")
	assert_true(panel._money_label != null, "Money label created")
	assert_true("$40,000" in panel._money_label.text, "Money label displays current player balance")
	assert_eq(panel._card_containers.size(), 4, "4 relic offering cards rendered")
	assert_true(panel._reroll_btn != null, "Reroll button rendered")
	panel.queue_free()
