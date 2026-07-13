## Headless test for OutputWriter.write_clip_extras. Run:
##   godot --headless --path . -s res://tools/test_clip_extras.gd
## Verifies a clip's text deliverables land in ONE folder with NO duplicate
## script/caption files. Exits non-zero on any failure.
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var ow: Node = root.get_node("/root/OutputWriter")
	var abs := ProjectSettings.globalize_path("user://test_clip_extras_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(abs)
	var req := {"topic": "my clip", "_file": "x.json", "_batch": "/b"}
	var res := {
		"publish": "caption text #tag",
		"plan": "the plan",
		"review": "GO",
		"burn_note": "burned ep1.mp4",
		"script": "1\n00:00:00,000 --> 00:00:01,000\nhi",
		"edit": "1\n00:00:00,000 --> 00:00:01,000\nhi",
	}
	ow.write_clip_extras(abs, req, res)

	_check("post caption written (3_โพสต์.txt)", FileAccess.file_exists(abs.path_join("3_โพสต์.txt")))
	_check("NO duplicate script file (1_สคริปต์.md)", not FileAccess.file_exists(abs.path_join("1_สคริปต์.md")))
	_check("NO duplicate caption srt (2_แคปชั่น.srt)", not FileAccess.file_exists(abs.path_join("2_แคปชั่น.srt")))
	_check("request.json in _เบื้องหลัง", FileAccess.file_exists(abs.path_join("_เบื้องหลัง/request.json")))
	_check("plan paper written", FileAccess.file_exists(abs.path_join("_เบื้องหลัง/แผนงานผู้กำกับ.md")))

	_rmrf(abs)
	print("\n=== clip extras tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)


func _rmrf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_rmrf(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)
