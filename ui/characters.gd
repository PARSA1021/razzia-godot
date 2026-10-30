extends RefCounted
## The AI players' characters (Phase 13). The engine already gives every AI a personality (ai/ai.gd PERSONALITY); this file only
## gives those personalities a face: a short name, a one-line description and a few spoken lines. Presentation only.

const T = preload("res://ui/tokens.gd")

const INFO := {
	"CONSERVATIVE": {
		"label": "신중파", "short": "신중",
		"blurb": "안전한 카드를 고르고, 제안은 후하게, 상대의 제안은 잘 받아들입니다.",
		"lines": {"propose": ["공평하게 가자고.", "모두가 챙기면 되잖아.", "다들 조금씩 양보하면 되지."], "accept": ["좋아, 받지.", "그 정도면 충분해.", "무리할 필요 없지."], "duel": ["...이번엔 어쩔 수 없군.", "승부를 보자.", "원치 않았지만, 좋아."], "win": ["운이 좋았어.", "조용히 챙기지.", "서두르지 않으니 이기는 법이지."], "lose": ["다음엔 다를 거야.", "...이런 날도 있는 법이지."], "win_upset": ["하늘이 도왔군. 감사히 받지.", "확률은 확률일 뿐이지."], "win_big": ["큰돈일수록 조용히 챙겨야지."], "lose_big": ["큰 수업료를 냈군."]},
	},
	"AGGRESSIVE": {
		"label": "공격파", "short": "공격",
		"blurb": "위험한 카드도 던지고, 제안은 짜게, 마음에 안 들면 바로 결투를 겁니다.",
		"lines": {"propose": ["내 몫이 먼저야.", "이게 마지막 제안이다.", "싫으면 주사위로 가든가."], "accept": ["흥, 이번만이다.", "좋아, 일단 받지.", "다음엔 이렇게 안 끝나."], "duel": ["주사위로 말하자!", "덤벼!", "이 순간을 기다렸지!"], "win": ["이게 실력이지!", "다 내 거야.", "한 판 더 붙을래?"], "lose": ["운이 나빴을 뿐이야!", "다음엔 박살 내주지!"], "win_upset": ["봤지? 불리해도 이기는 게 나야!", "숫자 따위로 날 못 막아!"], "win_big": ["이 맛에 한다니까!"], "lose_big": ["젠장! 이게 말이 돼?!"]},
	},
	"OPPORTUNIST": {
		"label": "기회주의자", "short": "기회",
		"blurb": "상황에 따라 움직이는 균형형. 손해만 아니면 협상에 응합니다.",
		"lines": {"propose": ["서로 이득이 되는 선에서.", "합리적인 제안이지?", "숫자는 거짓말을 안 해."], "accept": ["계산이 맞네.", "나쁘지 않아.", "이 정도면 남는 장사지."], "duel": ["계산이 안 맞는데?", "그럼 승부다.", "확률에 맡겨보자."], "win": ["타이밍이 좋았지.", "기회를 잡았을 뿐.", "계산대로 됐군."], "lose": ["이런, 계산 착오.", "손해가 크지 않아 다행이군."], "win_upset": ["이런 판이 터질 때를 기다렸지.", "낮은 확률이 제일 비싸게 팔리거든."], "win_big": ["큰 판은 역시 남는 장사야."], "lose_big": ["이번 손실은 장부에 적어두지."]},
	},
}


static func info(personality) -> Dictionary:
	var d: Dictionary = INFO.get(str(personality) if personality != null else "", {"label": "", "short": "", "blurb": "", "lines": {}})
	if d["label"] == "":
		return d
	# the words a player reads, in the chosen language (the lines are translated where they are picked)
	return {"label": T.t(d["label"]), "short": T.t(d["short"]), "blurb": T.t(d["blurb"]), "lines": d["lines"]}


## One spoken line for `situation`; `seed_n` picks it deterministically (no randomness: the same event always gets the same line).
static func line(personality, situation: String, seed_n: int) -> String:
	var lines: Dictionary = info(personality)["lines"]
	var list: Array = lines.get(situation, [])
	if list.is_empty() and "_" in situation:
		list = lines.get(situation.get_slice("_", 0), [])       # "win_upset" falls back to "win"
	if list.is_empty():
		return ""
	return T.t(str(list[absi(seed_n) % list.size()]))


## Optional per-character lines (by display name) that win over the personality lines. Add a name here to give one character its own voice.
const BY_NAME := {
	"Vito": {"propose": ["이 정도면 다들 불만 없을 거야."], "accept": ["좋아, 거래 성립이군."], "duel": ["...어쩔 수 없지. 던져."], "win": ["이 바닥에서 오래 살아남는 비결이지.", "조용히 챙기지."], "lose": ["...다음 판에서 보자고."], "win_upset": ["운도 실력이라고 하더군."]},
	"Lola": {"propose": ["내 몫은 이만큼, 어때?"], "accept": ["흥, 봐줄게."], "duel": ["좋아, 한 판 붙자!"], "win": ["어머, 내 거네?", "미안, 이 판은 내 거야."], "lose": ["흥, 두고 봐."], "win_upset": ["불리하다고 누가 그래?"]},
	"Mack": {"propose": ["깔끔하게 반반으로 가지."], "accept": ["계산 끝. 받겠어."], "duel": ["그럼 숫자로 정리하자고."], "win": ["깔끔하게 가자고.", "계산이 맞았군."], "lose": ["한 판 졌을 뿐이야."]},
	"Dutch": {"propose": ["젊은이, 이쯤에서 타협하지."], "accept": ["허허, 좋네."], "duel": ["늙은이를 얕보지 마라."], "win": ["허허, 늙은이가 아직 안 죽었지.", "경험이란 게 이런 거야."], "lose": ["나이 먹어도 주사위는 어렵군."]},
	"Rosie": {"propose": ["우리 사이좋게 나누자, 응?"], "accept": ["후후, 고마워."], "duel": ["어머, 승부를 원해?"], "win": ["행운의 여신이 나랑 놀고 싶은가 봐.", "후후, 고마워."], "lose": ["아쉽네, 다음엔 내가 웃을게."]},
	"Sal": {"propose": ["내 몫은 챙겨야지."], "accept": ["됐어, 받는다."], "duel": ["거리식으로 가자."], "win": ["이게 거리의 법칙이야.", "받을 건 받아야지."], "lose": ["빚은 갚아주지."]},
	"Nico": {"propose": ["이 정도면 괜찮지?"], "accept": ["오케이, 콜!"], "duel": ["재밌겠는데? 가자!"], "win": ["오늘 감이 좋은데?", "운이 따라주네!"], "lose": ["에이, 다시 하자!"]},
}


## `line()` for a named character: a name-specific line if there is one, otherwise the personality's line.
static func line_for(name: String, personality, situation: String, seed_n: int) -> String:
	var by: Dictionary = BY_NAME.get(name, {})
	var list: Array = by.get(situation, [])
	if not list.is_empty():
		return T.t(str(list[absi(seed_n) % list.size()]))
	return line(personality, situation, seed_n)


## Dialogue scenes (Phase 14): short exchanges at key moments. Lines are written per personality; the pick is deterministic.
const SCENE_LINES := {
	"intro": {
		"CONSERVATIVE": ["처음 뵙겠소. 서두르지 않고 천천히 갑시다.", "무리하지 않는 게 오래 가는 법이지."],
		"AGGRESSIVE": ["오늘 밤 이 테이블은 내가 접수한다.", "잔말 말고 카드나 내."],
		"OPPORTUNIST": ["좋은 밤이야. 기회는 어디서든 생기는 법이지.", "손해 볼 장사는 안 해. 서로 좋게 가자고."],
	},
	"final": {
		"CONSERVATIVE": ["마지막 라운드군. 차분하게 마무리하지.", "여기까지 왔으니 실수만 하지 말자."],
		"AGGRESSIVE": ["이제 끝장을 볼 시간이야!", "남은 돈은 전부 내 거다."],
		"OPPORTUNIST": ["막판이 제일 재미있지.", "계산은 끝났어. 이제 움직일 때야."],
	},
	"duel_win": {
		"CONSERVATIVE": ["운이 따라 줬군. 미안하게 됐소.", "조용히 챙기겠소."],
		"AGGRESSIVE": ["봤지? 이게 실력이야!", "주사위도 내 편이군."],
		"OPPORTUNIST": ["타이밍이 좋았지.", "이런 날도 있는 거야."],
	},
	"duel_lose": {
		"CONSERVATIVE": ["...이번엔 내가 졌소. 인정하지.", "역시 쉽지 않군."],
		"AGGRESSIVE": ["젠장! 운이 나빴을 뿐이야!", "다음엔 어림없어!"],
		"OPPORTUNIST": ["이런, 계산 착오였나.", "한 번쯤은 져 줄 수도 있지."],
	},
	"react": {
		"CONSERVATIVE": ["무서운 승부군.", "저런 판은 피하는 게 상책이야."],
		"AGGRESSIVE": ["하하, 볼만한 승부였어!", "다음은 내 차례야."],
		"OPPORTUNIST": ["흥미롭군. 판세가 바뀌겠어.", "저 돈이 어디로 흐를지 지켜보자고."],
	},
	"end_win": {
		"CONSERVATIVE": ["꾸준함이 이긴다는 걸 보여 줬군.", "좋은 승부였소."],
		"AGGRESSIVE": ["당연한 결과지! 내가 이겼다!", "다들 수고했어. 내가 제일 잘했지만."],
		"OPPORTUNIST": ["끝까지 기회를 노린 보람이 있군.", "이번 판은 내가 가져가지."],
	},
	"end_lose": {
		"CONSERVATIVE": ["훌륭한 승부였소. 축하하오.", "다음 판에서는 지지 않겠소."],
		"AGGRESSIVE": ["한 판 더 해! 이대로는 못 끝내!", "다음엔 가만 안 둬."],
		"OPPORTUNIST": ["아쉽지만 배운 게 있었어.", "다음 판은 좀 더 영리하게 해 보지."],
	},
}


static func scene_line(kind: String, personality, seed_n: int) -> String:
	var list: Array = SCENE_LINES.get(kind, {}).get(str(personality) if personality != null else "", [])
	return "" if list.is_empty() else T.t(str(list[absi(seed_n) % list.size()]))


## ---------------------------------------------------------------- Phase 25: scenes that know what happened
## Templates per scene kind and personality. Placeholders come from the moment itself (never hidden information):
##   {total} money in the whole game · {bar} venue · {pot} amount at stake · {gap} lead in money · {leader} who leads
## A per-name entry (SCENES_BY_NAME) wins over the personality, so the seven characters keep their own voice.
const SCENES := {
	"intro": {
		"CONSERVATIVE": ["오늘 밤 이 거리에 깔릴 판돈, 모두 {total}. 서두를 것 없지.", "처음 보는 얼굴이군. 무리하지 않는 게 오래 가는 법이오.", "경찰 카드는 조심하시오. 이 거리에선 단속이 제일 무섭소.", "술집 여섯 곳, 판돈 {total}. 천천히 나눠 먹읍시다."],
		"AGGRESSIVE": ["판돈 {total}? 전부 내 주머니로 들어갈 돈이야.", "잔말 말고 카드나 내. 오늘 밤은 내가 접수한다.", "겁나면 지금 일어나도 돼. 주사위는 자비가 없거든.", "협상? 난 결투가 더 좋아."],
		"OPPORTUNIST": ["좋은 밤이야. 판돈은 모두 {total}. 기회는 어디서든 생기지.", "손해 볼 장사는 안 해. 서로 좋게 가자고.", "다들 몰리는 술집은 피하는 게 상책이지.", "숫자는 거짓말을 안 해. 오늘 밤도 계산대로 가지."],
	},
	"final_lead": {
		"CONSERVATIVE": ["지금 내가 앞서 있소. 차이는 {gap}. 차분히 마무리하지.", "마지막 라운드군. 지금 순서 그대로만 끝나면 좋겠소."],
		"AGGRESSIVE": ["차이는 {gap}. 따라올 수 있으면 따라와 봐!", "마지막 판이다. 이 자리는 아무도 못 뺏어."],
		"OPPORTUNIST": ["{gap} 차이로 1등. 막판엔 숫자가 전부야.", "마지막 라운드. 지킬 건 지키고, 먹을 건 먹고."],
	},
	"final_chase": {
		"CONSERVATIVE": ["1등은 {leader}, 차이는 {gap}. 마지막에 뒤집히는 일도 흔하오.", "아직 끝난 게 아니오. 한 술집이면 충분하지."],
		"AGGRESSIVE": ["1등, {leader}? 마지막 판에 다 뺏어 주지.", "차이는 {gap}? 결투 한 번이면 끝나는 숫자야!"],
		"OPPORTUNIST": ["차이는 {gap}. 한 판이면 뒤집히는 숫자야.", "{leader}, 막판에 방심하면 큰일 나지."],
	},
	"final_even": {
		"CONSERVATIVE": ["마지막 라운드군. 다들 엇비슷하니 한 술집이 승부를 가르겠소."],
		"AGGRESSIVE": ["막상막하라고? 이번 판에 끝장을 내주지!"],
		"OPPORTUNIST": ["숫자가 다 비슷해. 막판 한 수가 전부야."],
	},
	"duel_win": {
		"CONSERVATIVE": ["{bar}, 판돈 {pot}. 미안하게 됐소.", "운이 따라 줬군. 조용히 챙기겠소."],
		"AGGRESSIVE": ["판돈 {pot}, 내 거다! 주사위도 내 편이군.", "봤지? 이게 실력이야!"],
		"OPPORTUNIST": ["{bar} 판은 내가 가져가지. 타이밍이 좋았어.", "확률은 확률일 뿐. 판돈 {pot}, 잘 받겠어."],
	},
	"duel_lose": {
		"CONSERVATIVE": ["판돈 {pot}… 놓쳤군. 인정하지.", "역시 결투는 하는 게 아니었소."],
		"AGGRESSIVE": ["젠장! 판돈 {pot}, 날아가 버렸어!", "다음엔 어림없어! 두고 봐!"],
		"OPPORTUNIST": ["{bar} 판에서 계산 착오였나.", "판돈 {pot}짜리 수업료라… 비싸군."],
	},
	"react": {
		"CONSERVATIVE": ["판돈 {pot}짜리 결투라니, 무서운 승부군.", "저런 판은 피하는 게 상책이오."],
		"AGGRESSIVE": ["판돈 {pot}! 이제 판세가 바뀌겠는데?", "하하, 볼만한 승부였어! 다음은 내 차례야."],
		"OPPORTUNIST": ["판돈 {pot}, 주인이 바뀌었군. 판세가 바뀌겠어.", "저 돈이 어디로 흐를지 지켜보자고."],
	},
	"raided": {
		"CONSERVATIVE": ["단속이라니… {bar} 판돈 {pot}, 통째로 뺏기다니.", "경찰 카드를 그렇게 쓰는군. 기억해 두겠소."],
		"AGGRESSIVE": ["경찰을 불러? {bar}에서 이렇게 나온다 이거지!", "다음엔 각오해. 나도 경찰 카드는 있어."],
		"OPPORTUNIST": ["경찰 카드라… 판돈 {pot}짜리 한 수 배웠군.", "{bar} 판을 키운 건 나였는데. 계산 착오야."],
	},
	"raiding": {
		"CONSERVATIVE": ["미안하오, 법은 법이지. {bar}, 단속이오.", "도박꾼이 모이는 곳엔 경찰이 오기 마련이오."],
		"AGGRESSIVE": ["하하, {bar} 단속이다! 판돈 {pot}, 내가 접수하지.", "판을 키워 줘서 고마워."],
		"OPPORTUNIST": ["{bar}에 도박꾼이 몰릴 줄 알았지.", "판돈 {pot}, 깔끔하게 회수하겠어."],
	},
	"lead": {
		"CONSERVATIVE": ["자네가 1등이라… 아직 갈 길이 멀소.", "선두는 지키는 게 더 어렵다오."],
		"AGGRESSIVE": ["신입이 1등이라고? 웃기지 마!", "그 자리, 오래 못 갈 거다."],
		"OPPORTUNIST": ["선두가 바뀌었군. 이제 다들 너를 노릴 거야.", "1등은 과녁이 되는 법이지."],
	},
	"end_win": {
		"CONSERVATIVE": ["최종 {pot}. 꾸준함이 이긴다는 걸 보여 줬군.", "좋은 승부였소. 다음에 또 봅시다."],
		"AGGRESSIVE": ["최종 {pot}! 당연한 결과지!", "다들 수고했어. 내가 제일 잘했지만."],
		"OPPORTUNIST": ["최종 {pot}. 끝까지 기회를 노린 보람이 있군.", "이번 판은 내가 가져가지."],
	},
	"end_lose": {
		"CONSERVATIVE": ["훌륭한 승부였소, {leader}. 축하하오.", "다음 판에서는 지지 않겠소."],
		"AGGRESSIVE": ["한 판 더 해! 이대로는 못 끝내!", "{leader}, 다음엔 가만 안 둬."],
		"OPPORTUNIST": ["아쉽지만 배운 게 있었어.", "{leader}, 다음 판은 좀 더 영리하게 해 보지."],
	},
}

const SCENES_BY_NAME := {
	"Vito": {"intro": ["이 거리에서 오래 살아남는 법을 알려 주지. 욕심내지 않는 거요."], "raided": ["...{bar} 판을 빼앗기다니. 이 빚은 기억하겠소."]},
	"Lola": {"intro": ["어머, 새 얼굴이네? 오늘 밤 재밌겠다."], "duel_win": ["미안, 이 판돈은 내 거야."], "lead": ["어머, 1등? 귀여운데. 오래 가나 보자."]},
	"Mack": {"intro": ["계산은 간단해. 많이 먹는 놈이 이긴다."], "duel_lose": ["판돈 {pot}… 계산이 틀렸군."]},
	"Dutch": {"intro": ["허허, 젊은이. 이 늙은이도 아직 판을 읽을 줄 안다네."], "end_lose": ["허허, 늙은이가 졌구먼. 축하하네."]},
	"Rosie": {"intro": ["후후, 오늘 밤 행운의 여신은 누구 편일까?"], "raiding": ["미안해, {bar} 신고는 내가 했어."]},
	"Sal": {"intro": ["이 거리 정보는 내가 다 꿰고 있지. 조심하는 게 좋을 거야."]},
	"Nico": {"intro": ["오, 새 상대! 오늘 감이 좋은데?"], "duel_win": ["판돈 {pot}! 오늘 감 좋다고 했지?"]},
}

## a short title over each scene: where we are, what is at stake
const SCENE_TITLES := {
	"intro": "ROUND 1 · 오늘 밤의 테이블", "final": "FINAL ROUND · 마지막 라운드", "duel": "결투 · {bar} · {pot}",
	"raid": "RAZZIA · {bar} · {pot}", "lead": "선두 교체", "end": "게임 종료",
}


## A filled-in line for `kind`. `seed_n` picks the line deterministically; `ctx` fills the placeholders.
static func scene_text(kind: String, name: String, personality, seed_n: int, ctx: Dictionary = {}) -> String:
	var pool: Array = []
	pool.append_array(SCENES_BY_NAME.get(name, {}).get(kind, []))
	pool.append_array(SCENES.get(kind, {}).get(str(personality) if personality != null else "", []))
	# only lines whose blanks this moment can fill (a scene without a venue never shows "{bar}")
	pool = pool.filter(func(t): return not ("{" in str(t).format(ctx)))
	if pool.is_empty():
		return ""
	var t := T.t(str(pool[absi(seed_n) % pool.size()]))         # the template is translated, then filled
	return t.format(ctx)


static func scene_title(kind: String, ctx: Dictionary = {}) -> String:
	var t := T.t(str(SCENE_TITLES.get(kind, ""))).format(ctx)
	if "{" in t:
		t = t.get_slice(" · ", 0)          # a blank this moment cannot fill: keep the part that it can
	return t


## Situation to emotion mapping for live portrait expressions
static func emotion_for(situation: String, personality: String = "") -> String:
	match situation:
		"win", "win_big", "win_upset", "duel_win", "end_win", "raiding":
			return "TRIUMPHANT"
		"lose", "lose_big", "duel_lose", "raided":
			return "ANGRY" if personality == "AGGRESSIVE" else "DEFEATED"
		"propose", "lead":
			return "CONFIDENT"
		"duel", "react", "final":
			return "CONFIDENT" if personality == "AGGRESSIVE" else "NERVOUS"
		"accept", "intro":
			return "NEUTRAL"
		_:
			return "NEUTRAL"

