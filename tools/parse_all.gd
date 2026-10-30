extends SceneTree
## 모든 GDScript 를 다시 컴파일해 파싱 오류를 찾습니다 (CI 용).
##   godot --headless --path . --script res://tools/parse_all.gd
var bad: Array = []
var n := 0


func _walk(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			var p := dir.path_join(f)
			n += 1
			var s: GDScript = ResourceLoader.load(p, "GDScript")
			# 일반 로드로 컴파일합니다(CACHE_MODE_IGNORE·reload 는 4.3 에서 실행 중 스크립트와 충돌해 엔진이 죽음): 파싱 오류면 null 이거나 인스턴스화 불가
			if s == null or not s.can_instantiate():
				bad.append(p)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_walk(dir.path_join(sub))


func _init() -> void:
	_walk("res://")
	print("PARSE: %d scripts, %d failed -> %s" % [n, bad.size(), "PASS" if bad.is_empty() else "FAIL"])
	for b in bad:
		print("  ", b)
	quit(0 if bad.is_empty() else 1)
