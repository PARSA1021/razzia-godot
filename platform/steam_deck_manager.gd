extends Node
## SteamDeckManager (오토로드 "SteamDeckManager")
## 실행 환경을 감지하고, 그 결과에 맞춰 화면 모드·프레임 제한·그래픽 프리셋을 적용합니다.
## - 게임 규칙, 진행, 저장 데이터와는 무관합니다(표현 계층만 다룹니다).
## - 감지에 실패해도 게임은 데스크톱 기본값으로 정상 실행됩니다.
## - "Linux이므로 Steam Deck"이라고 판단하지 않습니다. 근거(evidence)가 있을 때만 확정합니다.
## - 헤드리스 실행(자동 테스트, CI)에서는 화면·프레임 설정을 건드리지 않습니다.

const Settings = preload("res://ui/settings.gd")

## 감지 결과. 확정할 수 없으면 확정하지 않습니다.
enum PlatformKind { UNKNOWN, DESKTOP, LINUX_HANDHELD_CANDIDATE, STEAM_DECK_CONFIRMED }
## 그래픽 프리셋. 이 게임은 2D 카드 게임이라 실제로 바꿀 수 있는 것만 담았습니다:
## 프레임 상한, VSync, 저전력 렌더링(변화 없을 때 다시 그리지 않음), 테이블 펠트 셰이더의 움직임.
enum Quality { HIGH, BALANCED, BATTERY_SAVER }

signal platform_detected(kind: int)
signal quality_changed(preset: int)
signal display_mode_changed(fullscreen: bool)

const DECK_SCREEN := Vector2i(1280, 800)
## DMI 정보 (Linux). Steam Deck LCD 모델은 "Jupiter", OLED 모델은 "Galileo"로 보고됩니다.
const DMI_VENDOR := "/sys/class/dmi/id/sys_vendor"
const DMI_PRODUCT := "/sys/class/dmi/id/product_name"
const DECK_PRODUCTS: PackedStringArray = ["Jupiter", "Galileo"]
const QUALITY_KEYS: PackedStringArray = ["HIGH", "BALANCED", "BATTERY"]

var kind: int = PlatformKind.UNKNOWN
var evidence: PackedStringArray = []          # 판단 근거 (진단 로그용)
var launched_by_steam: bool = false
var headless: bool = false
var quality: int = Quality.HIGH
var log_lines: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	Settings.load_settings()
	detect()
	apply_display()
	apply_quality()
	_log("ready: %s" % diagnostics_line())


## ---------------------------------------------------------------- 감지

## 근거를 모아 PlatformKind를 정합니다. 어떤 단계가 실패해도 예외 없이 DESKTOP/UNKNOWN으로 끝납니다.
func detect() -> int:
	evidence = []
	var os_name: String = OS.get_name()
	launched_by_steam = OS.has_environment("SteamAppId") or OS.has_environment("SteamGameId")
	if launched_by_steam:
		evidence.append("Steam에서 실행됨(SteamAppId/SteamGameId)")
	# 1) Steam 클라이언트가 직접 알려주는 값: Steam Deck에서 실행하면 SteamDeck=1 이 설정됩니다.
	if OS.get_environment("SteamDeck") == "1":
		evidence.append("환경 변수 SteamDeck=1")
		return _set_kind(PlatformKind.STEAM_DECK_CONFIRMED)
	if os_name != "Linux":
		evidence.append("OS=%s" % os_name)
		return _set_kind(PlatformKind.DESKTOP)
	# 2) 하드웨어 정보 (Linux DMI). 제조사 Valve + 제품명 Jupiter/Galileo 이면 Steam Deck 본체입니다.
	var vendor := _read_line(DMI_VENDOR)
	var product := _read_line(DMI_PRODUCT)
	if vendor != "" or product != "":
		evidence.append("DMI %s / %s" % [vendor, product])
	if vendor == "Valve" and product in DECK_PRODUCTS:
		return _set_kind(PlatformKind.STEAM_DECK_CONFIRMED)
	# 3) 확정할 수는 없지만 휴대용 Linux일 가능성: 1280x800 화면 + (gamescope 세션 또는 게임패드 연결)
	var screen := _screen_size()
	var gamescope := OS.get_environment("XDG_CURRENT_DESKTOP").to_lower().contains("gamescope") or OS.has_environment("GAMESCOPE_WAYLAND_DISPLAY")
	if gamescope:
		evidence.append("gamescope 세션")
	if screen == DECK_SCREEN and (gamescope or not Input.get_connected_joypads().is_empty()):
		evidence.append("화면 %dx%d" % [screen.x, screen.y])
		return _set_kind(PlatformKind.LINUX_HANDHELD_CANDIDATE)
	evidence.append("Linux 데스크톱으로 판단")
	return _set_kind(PlatformKind.DESKTOP)


func _set_kind(k: int) -> int:
	kind = k
	platform_detected.emit(k)
	return k


func is_handheld() -> bool:
	return kind == PlatformKind.STEAM_DECK_CONFIRMED or kind == PlatformKind.LINUX_HANDHELD_CANDIDATE


func kind_name() -> String:
	return ["UNKNOWN", "DESKTOP", "LINUX_HANDHELD_CANDIDATE", "STEAM_DECK_CONFIRMED"][kind]


func _read_line(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_line().strip_edges()


func _screen_size() -> Vector2i:
	if headless:
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## ---------------------------------------------------------------- 화면 모드

## 자동("")이면 휴대용에서는 전체 화면, 데스크톱에서는 프로젝트 기본(창 1280x720)을 그대로 둡니다.
## 해상도는 강제하지 않습니다: SteamOS(gamescope)가 화면에 맞춰 출력하고, 게임은 Stretch(canvas_items + expand)로
## 1280x800 / 1280x720 / 1920x1080 어디서든 레이아웃을 다시 계산합니다.
func apply_display() -> void:
	if headless:
		return
	var want_full := false
	match Settings.display_mode:
		"fullscreen":
			want_full = true
		"windowed":
			want_full = false
		_:
			want_full = is_handheld()
	var cur := DisplayServer.window_get_mode()
	var is_full := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full == is_full:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	var now := DisplayServer.window_get_mode()
	var ok := (now == DisplayServer.WINDOW_MODE_FULLSCREEN) == want_full
	if not ok:
		# 실패 시 창 모드로 복구 (일부 창 관리자는 전체 화면 요청을 거부합니다)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_log("display: fullscreen request failed, back to windowed")
	display_mode_changed.emit(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_log("display: %s" % ("fullscreen" if want_full else "windowed"))


func set_display_mode(mode: String) -> void:
	Settings.display_mode = mode
	Settings.save_settings()
	apply_display()


## ---------------------------------------------------------------- 프레임 / 품질

## 자동("")이면 휴대용은 BALANCED, 데스크톱은 HIGH.
func resolve_quality() -> int:
	match Settings.quality:
		"HIGH":
			return Quality.HIGH
		"BALANCED":
			return Quality.BALANCED
		"BATTERY":
			return Quality.BATTERY_SAVER
	return Quality.BALANCED if is_handheld() else Quality.HIGH


## 프리셋 적용.
## - HIGH: VSync 켬, 프레임 상한 없음(모니터 주사율까지).
## - BALANCED: VSync 켬, 60fps 상한. Steam Deck OLED(90Hz)에서도 60에 묶어 GPU 작업을 줄입니다.
## - BATTERY_SAVER: 30fps 상한 + 저전력 렌더링(화면이 바뀔 때만 다시 그림) + 움직이지 않는 펠트.
##   카드 게임은 대부분의 시간을 "플레이어의 선택을 기다리며" 보내므로, 이 상태에서 다시 그리지 않는 것이 핵심입니다.
## VSync만으로 배터리가 절약되지는 않습니다. 실제 절감은 그리는 횟수와 GPU 작업량에서 나옵니다.
func apply_quality() -> void:
	quality = resolve_quality()
	Settings.quality_effective = QUALITY_KEYS[quality]
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		match quality:
			Quality.HIGH:
				Engine.max_fps = 0
				OS.low_processor_usage_mode = false
			Quality.BALANCED:
				Engine.max_fps = 60
				OS.low_processor_usage_mode = false
			Quality.BATTERY_SAVER:
				Engine.max_fps = 30
				OS.low_processor_usage_mode = true
	quality_changed.emit(quality)
	# 펠트 등 화면 쪽 반응: 오토로드에 직접 의존하지 않도록 그룹 호출을 씁니다.
	if is_inside_tree():
		get_tree().call_group("quality_listeners", "on_quality_changed", Settings.quality_effective)
	_log("quality: %s (max_fps=%d, low_processor=%s, headless=%s)" % [Settings.quality_effective, Engine.max_fps, OS.low_processor_usage_mode, headless])


func set_quality(key: String) -> void:
	Settings.quality = key
	Settings.save_settings()
	apply_quality()


## ---------------------------------------------------------------- 진단

func diagnostics_line() -> String:
	var scr := _screen_size()
	return "platform=%s evidence=[%s] os=%s screen=%dx%d window_mode=%d vsync=%d max_fps=%d quality=%s joypads=%s steam=%s" % [
		kind_name(), "; ".join(evidence), OS.get_name(), scr.x, scr.y,
		DisplayServer.window_get_mode() if not headless else -1, DisplayServer.window_get_vsync_mode() if not headless else -1,
		Engine.max_fps, Settings.quality_effective, str(Input.get_connected_joypads()), launched_by_steam]


func _exit_tree() -> void:
	Settings.cleanup_test_files()          # test / tool processes leave no settings, saves or records behind


func _log(line: String) -> void:
	log_lines.append(line)
	if OS.is_debug_build():
		print("[SteamDeckManager] ", line)
