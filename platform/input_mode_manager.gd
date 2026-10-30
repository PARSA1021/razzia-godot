extends Node
## InputModeManager (오토로드 "InputModeManager")
## 플레이어가 "마지막으로 실제로 사용한" 입력 장치를 추적하고, 컨트롤러만으로 게임 전체를 조작할 수 있게 받쳐 줍니다.
## - 게임패드가 "연결되어 있다"는 사실만으로 게임패드 모드라고 판단하지 않습니다. 실제 입력 이벤트로만 바꿉니다.
## - 키보드·마우스·터치·게임패드는 언제나 동시에 동작합니다. 어떤 장치도 막지 않습니다.
## - 이벤트를 소비하는 곳은 "포커스가 아무 데도 없을 때의 첫 방향키/확인" 하나뿐입니다(포커스 복구).

enum Mode { UNKNOWN, KEYBOARD_MOUSE, GAMEPAD, TOUCH }

signal input_mode_changed(mode: int, device: int)
signal gamepad_connected(device: int, pad_name: String)
signal gamepad_disconnected(device: int)

const STICK_DEADZONE := 0.5        # 이 값을 넘는 스틱 입력만 "게임패드를 쓰는 중"으로 봅니다 (중앙 복귀·잡음 무시)
const TRIGGER_DEADZONE := 0.5
const SCROLL_DEADZONE := 0.25      # 오른쪽 스틱 스크롤
const SCROLL_SPEED := 900.0        # px/s (스틱 끝까지 밀었을 때)
const MOUSE_SWITCH_PX := 12.0      # 마우스가 이만큼 움직여야 키보드·마우스 모드로 돌아갑니다 (책상 위 미세 떨림 무시)

## 게임 고유 액션. 기본 ui_* 액션은 이름을 바꾸지 않고 게임패드 버튼만 보강합니다.
## [액션, 키보드 키(0=없음), 게임패드 버튼(-1=없음)]
const EXTRA_ACTIONS := [
	["pause", 0, JOY_BUTTON_START],               # 일시정지 (키보드는 기존 Esc = ui_cancel)
	["toggle_mute", KEY_M, JOY_BUTTON_BACK],      # 음소거 (Steam Deck의 "보기" 버튼)
	["venue_info", KEY_I, JOY_BUTTON_Y],          # 고른 카드의 술집 정보 (마우스 없이 술집 카드를 여는 방법)
	["skip_anim", KEY_S, JOY_BUTTON_X],           # 진행 중인 연출 건너뛰기 (탭과 같은 동작)
]

var mode: int = Mode.UNKNOWN
var last_device: int = -1
var headless: bool = false
var _mouse_travel: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	ensure_bindings()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## ---------------------------------------------------------------- 입력 맵

## 실행 시점에 확인해서 빠진 것만 추가합니다(여러 번 불러도 안전).
## Godot 4.3 기본 맵은 ui_accept / ui_cancel 에 게임패드 버튼이 없습니다(실행해서 확인한 사실). 그대로 두면
## 컨트롤러로 메뉴에서 "확인"을 누를 방법이 없습니다.
static func ensure_bindings() -> void:
	_add_joy("ui_accept", JOY_BUTTON_A)
	_add_joy("ui_cancel", JOY_BUTTON_B)
	for spec in EXTRA_ACTIONS:
		var action: String = spec[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		if int(spec[1]) != 0:
			_add_key(action, int(spec[1]))
		if int(spec[2]) >= 0:
			_add_joy(action, int(spec[2]))


static func _add_joy(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = button as JoyButton
	jb.device = -1                     # 모든 패드
	InputMap.action_add_event(action, jb)


static func _add_key(action: String, key: int) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and ((e as InputEventKey).keycode == key or (e as InputEventKey).physical_keycode == key):
			return
	var k := InputEventKey.new()
	k.keycode = key as Key
	InputMap.action_add_event(action, k)


## ---------------------------------------------------------------- 입력 모드

func _input(event: InputEvent) -> void:
	var next: int = mode
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			next = Mode.GAMEPAD
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		var dz: float = TRIGGER_DEADZONE if jm.axis == JOY_AXIS_TRIGGER_LEFT or jm.axis == JOY_AXIS_TRIGGER_RIGHT else STICK_DEADZONE
		if absf(jm.axis_value) >= dz:
			next = Mode.GAMEPAD
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			next = Mode.TOUCH
	elif event is InputEventScreenDrag:
		next = Mode.TOUCH
	elif event is InputEventMouseButton:
		# 터치에서 흉내 낸 마우스 이벤트(device = -1)는 터치로 이미 처리했으므로 무시합니다.
		if event.device != InputEvent.DEVICE_ID_EMULATION and (event as InputEventMouseButton).pressed:
			next = Mode.KEYBOARD_MOUSE
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_mouse_travel += (event as InputEventMouseMotion).relative.length()
			if _mouse_travel >= MOUSE_SWITCH_PX:
				next = Mode.KEYBOARD_MOUSE
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			next = Mode.KEYBOARD_MOUSE
	if next != mode:
		_set_mode(next, event.device)


func _set_mode(m: int, device: int) -> void:
	mode = m
	last_device = device
	_mouse_travel = 0.0
	if not headless:
		# 게임패드로 조작할 때는 커서를 숨기고, 마우스를 다시 움직이면 보입니다.
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if m == Mode.GAMEPAD else Input.MOUSE_MODE_VISIBLE
	input_mode_changed.emit(m, device)


func mode_name() -> String:
	return ["UNKNOWN", "KEYBOARD_MOUSE", "GAMEPAD", "TOUCH"][mode]


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		gamepad_connected.emit(device, Input.get_joy_name(device))
	else:
		gamepad_disconnected.emit(device)
		# 쓰던 패드가 빠지면 키보드·마우스 안내로 돌아갑니다(커서도 다시 보이게).
		if mode == Mode.GAMEPAD and Input.get_connected_joypads().is_empty():
			_set_mode(Mode.KEYBOARD_MOUSE, -1)


## ---------------------------------------------------------------- 포커스 복구

## 포커스가 아무 데도 없는 상태에서 방향키/확인이 왔고, 다른 누구도 그 입력을 쓰지 않았다면(_unhandled_input),
## 지금 맨 위에 떠 있는 화면에서 알맞은 버튼에 포커스를 줍니다. 첫 입력은 "포커스만" 하고 버튼을 누르지 않습니다.
## (카드 고르기처럼 게임이 직접 처리하는 입력은 이미 handled 이므로 여기까지 오지 않습니다.)
func _unhandled_input(event: InputEvent) -> void:
	if not _is_nav(event):
		return
	var vp := get_viewport()
	if vp == null or vp.gui_get_focus_owner() != null:
		return
	var target := find_focus_target(get_tree().root)
	if target != null:
		target.grab_focus()
		vp.set_input_as_handled()


func _is_nav(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return false
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(a):
			return true
	return false


## 맨 위(실효 z 가 가장 큰) 화면 안에서 고릅니다: "default_focus" 메타가 붙은 버튼 → 없으면 트리 순서상 첫 버튼.
## 숨김/비활성/포커스 불가/"no_auto_focus" 메타가 붙은 버튼(보드의 나가기·SKIP 등)은 제외합니다.
static func find_focus_target(root: Node) -> Control:
	var best: Control = null
	var best_z := -100000
	var best_default := false
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b == null or not b.is_visible_in_tree() or b.disabled or b.focus_mode == Control.FOCUS_NONE or b.has_meta("no_auto_focus"):
			continue
		if b.get_tree() != null and b.get_tree().paused and not b.can_process():
			continue
		var z := effective_z(b)
		var is_default := b.has_meta("default_focus")
		if z > best_z or (z == best_z and is_default and not best_default):
			best = b
			best_z = z
			best_default = is_default
	return best


static func effective_z(ci: CanvasItem) -> int:
	var total := 0
	var n: Node = ci
	while n is CanvasItem:
		total += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return total


## ---------------------------------------------------------------- 오른쪽 스틱 스크롤

## 도움말·기록·요약처럼 긴 화면은 오른쪽 스틱으로 스크롤합니다(방향키는 버튼 사이 이동에 씁니다).
func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var v := 0.0
	for p in pads:
		var a := Input.get_joy_axis(p, JOY_AXIS_RIGHT_Y)
		if absf(a) > absf(v):
			v = a
	if absf(v) < SCROLL_DEADZONE:
		return
	var sc := _scroll_target()
	if sc != null:
		sc.scroll_vertical += int(v * SCROLL_SPEED * delta)


func _scroll_target() -> ScrollContainer:
	var fo := get_viewport().gui_get_focus_owner()
	var n: Node = fo
	while n != null:
		if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
			return n as ScrollContainer
		n = n.get_parent()
	var best: ScrollContainer = null
	var best_z := -100000
	for c in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var s := c as ScrollContainer
		if s.is_visible_in_tree() and s.get_v_scroll_bar().max_value > s.size.y + 1.0:
			var z := effective_z(s)
			if z >= best_z:
				best = s
				best_z = z
	return best


## ---------------------------------------------------------------- 안내 문구

## 지금 쓰는 장치에 맞는 버튼 이름. Steam Deck은 Steam Input이 기본적으로 Xbox 배치(A 아래, B 오른쪽)로 넘겨주므로
## A/B/X/Y 표기가 실제 버튼 글자와 같습니다. 메뉴(☰)·보기(⧉) 버튼은 글꼴에 기호가 없을 수 있어 이름으로 씁니다.
func prompt(action: String) -> String:
	var table: Dictionary
	match mode:
		Mode.GAMEPAD:
			table = {"accept": "A", "cancel": "B", "pause": "메뉴 버튼", "mute": "보기 버튼", "venue_info": "Y", "skip_anim": "X", "nav": "십자키"}
		Mode.TOUCH:
			table = {"accept": "탭", "cancel": "⎋ 버튼", "pause": "⎋ 버튼", "mute": "⎋ 메뉴", "venue_info": "술집 누르기", "skip_anim": "화면 탭", "nav": "-"}
		_:
			table = {"accept": "Enter", "cancel": "Esc", "pause": "Esc", "mute": "M", "venue_info": "I", "skip_anim": "S", "nav": "방향키"}
	return preload("res://ui/i18n.gd").t(str(table.get(action, action)))


## 오토로드가 없는 실행(일부 테스트)에서도 쓸 수 있는 정적 진입점.
static func prompt_for(tree: SceneTree, action: String) -> String:
	var m: Node = tree.root.get_node_or_null("InputModeManager") if tree != null else null
	if m != null:
		return m.prompt(action)
	return preload("res://ui/i18n.gd").t({"accept": "Enter", "cancel": "Esc", "pause": "Esc", "mute": "M", "venue_info": "I", "skip_anim": "S", "nav": "방향키"}.get(action, action))
