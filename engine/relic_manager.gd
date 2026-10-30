extends RefCounted
## RelicManager (Phase 2 & 3): Roguelike Black Market & Relic System.
## Pure rules & state logic for relics; keeps classic mode 100% untouched.
##
## Relics Roster:
##   1. "lucky_coin"        (Lucky Coin)        - COMMON ($7,000): +1 to final duel score total.
##   2. "protection_racket" (Protection Racket) - COMMON ($8,000): +$5,000 bonus on solo bar claim.
##   3. "informant"         (The Informant)     - UNCOMMON ($10,000): Intel on 1 AI destination bar before card selection.
##   4. "swiss_account"     (Swiss Account)     - UNCOMMON ($14,000): 10% interest at round settlement (capped at $12k).
##   5. "bribed_judge"      (Bribed Judge)      - UNCOMMON ($15,000): Always win duel ties, even when defending.
##   6. "loaded_dice"       (Loaded Dice)       - UNCOMMON ($16,000): Duel die roll of 1 or 2 is upgraded to 3.
##   7. "dirty_cop"         (Dirty Cop)         - UNCOMMON ($18,000): Extorts 15% bribe on failed raid (capped at $50k).
##   8. "syndicate_crest"   (Syndicate Crest)   - RARE ($22,000): +$3,000 dividend per owned relic at round start.


const RELICS := {
	"lucky_coin": {
		"id": "lucky_coin",
		"icon": "🪙",
		"name": "Lucky Coin",
		"name_ko": "행운의 동전",
		"type": "DUEL",
		"rarity": "COMMON",
		"price": 7000,
		"desc": "결투 최종 점수에 상시 +1점 보너스를 부여합니다.",
		"desc_en": "Always grants a +1 bonus to your final duel score.",
	},
	"protection_racket": {
		"id": "protection_racket",
		"icon": "🥊",
		"name": "Protection Racket",
		"name_ko": "보호세 수금원",
		"type": "ECONOMY",
		"rarity": "COMMON",
		"price": 8000,
		"desc": "혼자 술집을 독점 차지했을 때 추가 보너스 +$5,000를 획득합니다.",
		"desc_en": "Gain an extra +$5,000 bonus whenever you claim a venue all to yourself.",
	},
	"informant": {
		"id": "informant",
		"icon": "🕵️",
		"name": "The Informant",
		"name_ko": "비밀 정보원",
		"type": "INFO",
		"rarity": "UNCOMMON",
		"price": 10000,
		"desc": "각 라운드 카드 선택 시, AI 1명이 방문할 술집 위치를 사전 입수합니다.",
		"desc_en": "Reveals the destination bar of 1 AI player before you choose your card.",
	},
	"swiss_account": {
		"id": "swiss_account",
		"icon": "🏦",
		"name": "Swiss Account",
		"name_ko": "스위스 비밀계좌",
		"type": "ECONOMY",
		"rarity": "UNCOMMON",
		"price": 14000,
		"desc": "매 라운드 정산 시 보유 현금의 10%를 이자로 수취합니다 (최대 $12,000).",
		"desc_en": "Earn 10% interest on your cash at round settlement (capped at $12,000).",
	},
	"bribed_judge": {
		"id": "bribed_judge",
		"icon": "⚖️",
		"name": "Bribed Judge",
		"name_ko": "매수한 판사",
		"type": "DUEL",
		"rarity": "UNCOMMON",
		"price": 15000,
		"desc": "결투 동점 시, 도전을 받았더라도 무조건 판정승합니다.",
		"desc_en": "You always win duel ties, even when you were the defending player.",
	},
	"loaded_dice": {
		"id": "loaded_dice",
		"icon": "🎲",
		"name": "Loaded Dice",
		"name_ko": "조작된 주사위",
		"type": "DUEL",
		"rarity": "UNCOMMON",
		"price": 16000,
		"desc": "결투 주사위 눈이 1 또는 2가 나오면 자동으로 3으로 보정됩니다.",
		"desc_en": "Your duel die rolls of 1 or 2 are automatically upgraded to 3.",
	},
	"dirty_cop": {
		"id": "dirty_cop",
		"icon": "🚨",
		"name": "Dirty Cop",
		"name_ko": "부패한 경관",
		"type": "ECONOMY",
		"rarity": "UNCOMMON",
		"price": 18000,
		"desc": "경찰 단속 실패 시 해당 술집 판돈의 15%를 뇌물로 수취합니다 (최대 $50,000).",
		"desc_en": "Collect 15% of the bar's money as an extortion bribe if a police raid fails (capped at $50,000).",
	},
	"syndicate_crest": {
		"id": "syndicate_crest",
		"icon": "⚜️",
		"name": "Syndicate Crest",
		"name_ko": "신디케이트 문장",
		"type": "SYNERGY",
		"rarity": "RARE",
		"price": 22000,
		"desc": "보유한 유물 1개당 매 라운드 시작 시 +$3,000의 조직 배당금을 지급받습니다.",
		"desc_en": "Collect a $3,000 syndicate dividend for every relic you own at the start of each round.",
	},
}

const STARTER_RELICS := ["lucky_coin", "protection_racket", "informant"]
const REROLL_PRICE := 5000


static func all_relic_ids() -> Array:
	return RELICS.keys()


static func get_definition(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func is_relic_mode(s: Dictionary) -> bool:
	return s.has("relics") and (s["relics"] is Dictionary)


static func get_starter_choices() -> Array:
	var out: Array = []
	for id in STARTER_RELICS:
		if RELICS.has(id):
			out.append(RELICS[id].duplicate(true))
	return out


static func get_player_money(s: Dictionary, pid: String) -> int:
	for p in s.get("players", []):
		if p["id"] == pid:
			return int(p.get("money", 0))
	return 0


static func can_afford(s: Dictionary, pid: String, relic_id: String) -> bool:
	if not RELICS.has(relic_id) or has_relic(s, pid, relic_id):
		return false
	var price: int = int(RELICS[relic_id].get("price", 0))
	return get_player_money(s, pid) >= price


static func can_afford_reroll(s: Dictionary, pid: String) -> bool:
	return get_player_money(s, pid) >= REROLL_PRICE


static func buy_relic(s: Dictionary, pid: String, relic_id: String) -> Dictionary:
	if not RELICS.has(relic_id):
		return {"ok": false, "reason": "INVALID_RELIC"}
	if has_relic(s, pid, relic_id):
		return {"ok": false, "reason": "ALREADY_OWNED"}
	var def: Dictionary = RELICS[relic_id]
	var price: int = int(def.get("price", 0))
	var target_p = _find_player(s, pid)
	if target_p == null:
		return {"ok": false, "reason": "PLAYER_NOT_FOUND"}
	if int(target_p.get("money", 0)) < price:
		return {"ok": false, "reason": "INSUFFICIENT_FUNDS"}

	# Atomic transaction: money moves to Black Market Vault (INV-002 preserved)
	target_p["money"] -= price
	s["blackMarketVault"] = int(s.get("blackMarketVault", 0)) + price
	add_relic(s, pid, relic_id)

	s["seq"] = int(s.get("seq", 0)) + 1
	var ev := {
		"seq": s["seq"],
		"type": "RELIC_PURCHASED",
		"round": s.get("round", 1),
		"playerId": pid,
		"relicId": relic_id,
		"price": price,
		"remainingMoney": target_p["money"],
	}
	s["events"].append(ev)
	return {"ok": true, "event": ev, "price": price}


static func reroll_shop(s: Dictionary, pid: String) -> Dictionary:
	var target_p = _find_player(s, pid)
	if target_p == null:
		return {"ok": false, "reason": "PLAYER_NOT_FOUND"}
	if int(target_p.get("money", 0)) < REROLL_PRICE:
		return {"ok": false, "reason": "INSUFFICIENT_FUNDS"}

	target_p["money"] -= REROLL_PRICE
	s["blackMarketVault"] = int(s.get("blackMarketVault", 0)) + REROLL_PRICE
	s["shopRerolls"] = int(s.get("shopRerolls", 0)) + 1

	s["seq"] = int(s.get("seq", 0)) + 1
	var ev := {
		"seq": s["seq"],
		"type": "SHOP_REROLLED",
		"round": s.get("round", 1),
		"playerId": pid,
		"price": REROLL_PRICE,
		"remainingMoney": target_p["money"],
	}
	s["events"].append(ev)
	return {"ok": true, "event": ev, "remainingMoney": target_p["money"]}


static func get_shop_offerings(s: Dictionary, pid: String) -> Array:
	var offerings: Array = []
	var cur_m: int = get_player_money(s, pid)
	var reroll_cnt: int = int(s.get("shopRerolls", 0))
	var rnd: int = int(s.get("round", 1))
	var seed_v: int = int(s.get("config", {}).get("seed", 0))

	# Deterministic presentation: select up to 4 unowned relics
	var unowned: Array = []
	var owned_items: Array = []
	for id in all_relic_ids():
		if has_relic(s, pid, id):
			owned_items.append(id)
		else:
			unowned.append(id)

	# Rotate unowned relics based on round, reroll count and seed
	var count_to_pick: int = mini(4, unowned.size())
	var selected_ids: Array = []
	if unowned.size() > 0:
		var offset: int = (rnd * 3 + reroll_cnt * 5 + seed_v) % unowned.size()
		for i in range(count_to_pick):
			selected_ids.append(unowned[(offset + i) % unowned.size()])

	# If all owned, display full catalog marked owned
	if selected_ids.is_empty():
		selected_ids = all_relic_ids().slice(0, 4)

	for id in selected_ids:
		var def: Dictionary = RELICS[id].duplicate(true)
		var owned: bool = has_relic(s, pid, id)
		var price: int = int(def.get("price", 0))
		def["owned"] = owned
		def["canAfford"] = (not owned) and (cur_m >= price)
		offerings.append(def)
	return offerings


## Initializes relic state in game state dictionary.
static func init_game_relics(s: Dictionary, relic_ids: Array = [], target_pid: String = "") -> void:
	if not s.has("relics"):
		s["relics"] = {}
	var pid: String = target_pid
	if pid == "":
		pid = str(s.get("config", {}).get("humanPlayerId", "P1"))
	if not s["relics"].has(pid):
		s["relics"][pid] = []
	for rid in relic_ids:
		add_relic(s, pid, str(rid))


static func add_relic(s: Dictionary, pid: String, relic_id: String) -> bool:
	if not RELICS.has(relic_id):
		return false
	if not s.has("relics"):
		s["relics"] = {}
	if not s["relics"].has(pid):
		s["relics"][pid] = []
	var list: Array = s["relics"][pid]
	if not list.has(relic_id):
		list.append(relic_id)
		return true
	return false


static func has_relic(s: Dictionary, pid: String, relic_id: String) -> bool:
	if not s.has("relics"):
		return false
	var list = s["relics"].get(pid, null)
	return list != null and (list is Array) and list.has(relic_id)


static func get_player_relics(s: Dictionary, pid: String) -> Array:
	if not s.has("relics"):
		return []
	var list = s["relics"].get(pid, [])
	var out: Array = []
	for id in list:
		if RELICS.has(id):
			out.append(RELICS[id].duplicate(true))
	return out


## Relic: The Informant
static func get_informant_intel(s: Dictionary, human_id: String) -> Dictionary:
	if not has_relic(s, human_id, "informant"):
		return {}
	var ais: Array = []
	for p in s.get("players", []):
		if not bool(p.get("isHuman", false)) and p.get("selectedCardId") != null:
			ais.append(p)
	if ais.is_empty():
		return {}
	var seed_v: int = int(s.get("config", {}).get("seed", 0))
	var rnd: int = int(s.get("round", 1))
	var target = ais[(rnd + seed_v) % ais.size()]
	var card = s.get("cards", {}).get(target.get("selectedCardId", ""), {})
	if card.is_empty():
		return {}
	var bar_id: String = card.get("barId", "")
	var bar_name: String = ""
	for b in s.get("bars", []):
		if b.get("id", "") == bar_id:
			bar_name = str(b.get("name", bar_id))
			break
	return {
		"ok": true,
		"relicId": "informant",
		"targetId": target["id"],
		"targetName": target["name"],
		"barId": bar_id,
		"barName": bar_name,
	}


## Relic: Loaded Dice (upgrade 1 or 2 to 3)
static func apply_duel_die_bonus(s: Dictionary, pid: String, roll: int) -> int:
	if has_relic(s, pid, "loaded_dice") and roll < 3:
		_emit_relic(s, pid, "loaded_dice", "DIE_UPGRADED", roll)
		return 3
	return roll


## Relic: Lucky Coin (+1 to total score)
static func apply_duel_score_bonus(s: Dictionary, pid: String) -> int:
	if has_relic(s, pid, "lucky_coin"):
		_emit_relic(s, pid, "lucky_coin", "SCORE_BOOST", 1)
		return 1
	return 0


## Relic: Bribed Judge (win tie on defense)
static func resolve_duel_tie(s: Dictionary, a_id: String, b_id: String, challenger_id: String) -> String:
	var a_bribed: bool = has_relic(s, a_id, "bribed_judge")
	var b_bribed: bool = has_relic(s, b_id, "bribed_judge")

	if a_bribed and not b_bribed:
		if challenger_id != a_id:
			_emit_relic(s, a_id, "bribed_judge", "TIE_OVERRULED")
		return a_id
	elif b_bribed and not a_bribed:
		if challenger_id != b_id:
			_emit_relic(s, b_id, "bribed_judge", "TIE_OVERRULED")
		return b_id
	return challenger_id


## Relic: Dirty Cop (15% bribe on empty raid)
static func handle_failed_raid(s: Dictionary, bar: Dictionary, razzia_pids: Array) -> Array:
	var awarded: Array = []
	if int(bar.get("money", 0)) <= 0:
		return awarded

	for pid in razzia_pids:
		if has_relic(s, str(pid), "dirty_cop"):
			var cur_money: int = int(bar.get("money", 0))
			if cur_money <= 0:
				break
			var cut: int = mini(50000, int(floor(float(cur_money) * 0.15)))
			if cut > 0:
				bar["money"] -= cut
				var p = _find_player(s, str(pid))
				if p != null:
					p["money"] += cut
				s["seq"] = int(s.get("seq", 0)) + 1
				s["events"].append({
					"seq": s["seq"], "type": "MONEY_AWARDED", "round": s.get("round", 1),
					"playerId": str(pid), "amount": cut, "barId": bar["id"],
				})
				var ev := _emit_relic(s, str(pid), "dirty_cop", "BRIBE_COLLECTED", cut, bar["id"])
				awarded.append(ev)
	return awarded


## Relic: Protection Racket (+$5,000 solo venue bonus)
static func handle_solo_bar_bonus(s: Dictionary, pid: String, bar_id: String) -> int:
	if not has_relic(s, pid, "protection_racket"):
		return 0
	var bonus: int = 5000
	var p = _find_player(s, pid)
	if p != null:
		p["money"] = int(p.get("money", 0)) + bonus
		s["totalMoney"] = int(s.get("totalMoney", 0)) + bonus
		s["seq"] = int(s.get("seq", 0)) + 1
		s["events"].append({
			"seq": s["seq"], "type": "MONEY_AWARDED", "round": s.get("round", 1),
			"playerId": pid, "amount": bonus, "barId": bar_id,
		})
		_emit_relic(s, pid, "protection_racket", "SOLO_VENUE_BONUS", bonus, bar_id)
		return bonus
	return 0


## Relic: Swiss Account (10% interest at round cleanup, max $12k)
static func handle_round_cleanup(s: Dictionary) -> Array:
	var events: Array = []
	for p in s.get("players", []):
		var pid: String = p["id"]
		if has_relic(s, pid, "swiss_account"):
			var cur_m: int = int(p.get("money", 0))
			var interest: int = mini(12000, int(floor(float(cur_m) * 0.10)))
			if interest > 0:
				p["money"] += interest
				s["totalMoney"] = int(s.get("totalMoney", 0)) + interest
				s["seq"] = int(s.get("seq", 0)) + 1
				s["events"].append({
					"seq": s["seq"], "type": "MONEY_AWARDED", "round": s.get("round", 1),
					"playerId": pid, "amount": interest, "barId": "",
				})
				var ev := _emit_relic(s, pid, "swiss_account", "INTEREST_AWARDED", interest)
				events.append(ev)
	return events


## Relic: Syndicate Crest (+$3,000 dividend per owned relic at round start)
static func handle_round_start(s: Dictionary) -> Array:
	var events: Array = []
	for p in s.get("players", []):
		var pid: String = p["id"]
		if has_relic(s, pid, "syndicate_crest"):
			var count: int = get_player_relics(s, pid).size()
			var div: int = count * 3000
			if div > 0:
				p["money"] += div
				s["totalMoney"] = int(s.get("totalMoney", 0)) + div
				s["seq"] = int(s.get("seq", 0)) + 1
				s["events"].append({
					"seq": s["seq"], "type": "MONEY_AWARDED", "round": s.get("round", 1),
					"playerId": pid, "amount": div, "barId": "",
				})
				var ev := _emit_relic(s, pid, "syndicate_crest", "DIVIDEND_AWARDED", div)
				events.append(ev)
	return events


static func _find_player(s: Dictionary, pid: String):
	for p in s.get("players", []):
		if p["id"] == pid:
			return p
	return null


static func _emit_relic(s: Dictionary, pid: String, relic_id: String, detail: String, amount: int = 0, bar_id: String = "") -> Dictionary:
	s["seq"] = int(s.get("seq", 0)) + 1
	var ev := {
		"seq": s["seq"],
		"type": "RELIC_TRIGGERED",
		"round": s.get("round", 1),
		"relicId": relic_id,
		"playerId": pid,
		"detail": detail,
	}
	if amount > 0:
		ev["amount"] = amount
	if bar_id != "":
		ev["barId"] = bar_id
	s["events"].append(ev)
	return ev
