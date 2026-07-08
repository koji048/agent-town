## Real transcription in the edit bay: shells out to mlx-whisper on a
## worker thread (same battle-tested script-file invocation pattern as
## the Claude Code CLI — the bare script path is all OS.execute sees).
extends Node

signal done(srt: String, ok: bool)

var whisper_path := ""
var _thread: Thread


func _ready() -> void:
	whisper_path = _find_whisper()
	if whisper_path.is_empty():
		push_warning("Agent Town: mlx_whisper not found — clip transcription disabled.")


func available() -> bool:
	return not whisper_path.is_empty()


## Fire-and-await: `var r: Array = await Transcriber.done` after calling.
func transcribe(clip_abs: String) -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	var out_dir := ProjectSettings.globalize_path("user://transcripts")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var run_f := ProjectSettings.globalize_path("user://whisper_run.zsh")
	var fr := FileAccess.open(run_f, FileAccess.WRITE)
	fr.store_string("exec " + _shq(whisper_path) + " " + _shq(clip_abs)
		+ " --model mlx-community/whisper-large-v3-turbo"
		+ " --output-format srt --output-dir " + _shq(out_dir) + " < /dev/null\n")
	fr.close()
	var srt_path := out_dir.path_join(clip_abs.get_file().get_basename() + ".srt")
	_thread = Thread.new()
	_thread.start(func() -> void:
		var output: Array = []
		var code := OS.execute("/bin/zsh", PackedStringArray([run_f]), output, true)
		var srt := ""
		if code == 0 and FileAccess.file_exists(srt_path):
			srt = FileAccess.get_file_as_string(srt_path)
		call_deferred("_finish", srt, code == 0 and not srt.is_empty()))


func _finish(srt: String, ok: bool) -> void:
	done.emit(srt, ok)


func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


func _find_whisper() -> String:
	var home := OS.get_environment("HOME")
	var candidates: Array[String] = ["/opt/homebrew/bin/mlx_whisper", home + "/.local/bin/mlx_whisper"]
	for v in ["3.9", "3.10", "3.11", "3.12", "3.13"]:
		candidates.append(home + "/Library/Python/" + v + "/bin/mlx_whisper")
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""
