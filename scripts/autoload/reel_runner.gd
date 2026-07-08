## The bridge to the REAL reels-pipeline (the owner's production skill):
## the town doesn't reimplement it — it calls the actual scripts
## (reel.sh ingest/subs/burn) so clips land in the true content tree
## (02_PRODUCTION batches, 05_EXPORTS naming, EP auto-numbering,
## faster-whisper large-v3 + pythainlp + glossary). Threaded via the
## same script-file OS.execute pattern as the Claude CLI.
extends Node

signal finished(output: String, code: int)

var _thread: Thread


func reel_sh() -> String:
	return OS.get_environment("HOME") + "/Downloads/reels-pipeline/scripts/reel.sh"


func available() -> bool:
	return FileAccess.file_exists(reel_sh())


## The user's content tree (config.json content_dir, GSBattery default).
func content_dir() -> String:
	var env := OS.get_environment("REELS_CONTENT")
	if not env.is_empty():
		return env
	var cfg_path := OS.get_environment("HOME") + "/.reels-pipeline/config.json"
	if FileAccess.file_exists(cfg_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
		if data is Dictionary and data.has("content_dir"):
			return str(data["content_dir"]).replace("~", OS.get_environment("HOME"))
	return OS.get_environment("HOME") + "/Movies/CONTENT"


## Newest batch dir in 02_PRODUCTION (rc.latest_batch equivalent).
func latest_batch() -> String:
	var prod := content_dir().path_join("02_PRODUCTION")
	var best := ""
	var best_t := 0
	var dir := DirAccess.open(prod)
	if dir == null:
		return ""
	for d in dir.get_directories():
		var p := prod.path_join(d)
		var t := FileAccess.get_modified_time(p)
		if t > best_t:
			best_t = t
			best = p
	return best


## Newest file matching a suffix inside a folder ("" = any file).
func newest_file(folder: String, suffix: String) -> String:
	var best := ""
	var best_t := 0
	var dir := DirAccess.open(folder)
	if dir == null:
		return ""
	for f in dir.get_files():
		if not suffix.is_empty() and not f.ends_with(suffix):
			continue
		var t := FileAccess.get_modified_time(folder.path_join(f))
		if t > best_t:
			best_t = t
			best = folder.path_join(f)
	return best


## Run one reel.sh stage; `var r: Array = await ReelRunner.finished`.
func run(args: PackedStringArray) -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	var run_f := ProjectSettings.globalize_path("user://reel_run.zsh")
	var cmd := "exec /bin/bash " + _shq(reel_sh())
	for a in args:
		cmd += " " + _shq(a)
	var fr := FileAccess.open(run_f, FileAccess.WRITE)
	fr.store_string(cmd + " < /dev/null 2>&1\n")
	fr.close()
	_thread = Thread.new()
	_thread.start(func() -> void:
		var output: Array = []
		var code := OS.execute("/bin/zsh", PackedStringArray([run_f]), output, true)
		var text := ""
		for o in output:
			text += str(o)
		call_deferred("_finish", text, code))


func _finish(text: String, code: int) -> void:
	finished.emit(text, code)


func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"
