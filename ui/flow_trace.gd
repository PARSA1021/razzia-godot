extends RefCounted
## Flow trace (Phase 12): a ring buffer of "what state was the screen in, which input arrived, who changed what".
## Always collects the last 500 lines in memory (cheap); with RAZZIA_TRACE=1 in the environment it also prints them and
## appends them to user://flow_trace.log, so a bug report like "Enter ends the round" can be read back line by line.

const MAX := 500
static var lines: Array = []
static var enabled := OS.get_environment("RAZZIA_TRACE") != ""


static func log(tag: String, msg: String = "") -> void:
	var line := "f%06d %8.3f [%s] %s" % [Engine.get_process_frames(), Time.get_ticks_msec() / 1000.0, tag, msg]
	lines.append(line)
	if lines.size() > MAX:
		lines.pop_front()
	if enabled:
		print(line)
		var f := FileAccess.open("user://flow_trace.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://flow_trace.log") else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)


static func clear() -> void:
	lines.clear()


## Who called us: the first stack frame outside this file (debug builds only; empty in exports).
static func caller() -> String:
	var st := get_stack()
	for i in range(1, st.size()):
		if not str(st[i]["source"]).ends_with("flow_trace.gd"):
			return "%s:%d" % [st[i]["function"], st[i]["line"]]
	return ""
