## Headless test: PreviewMaker.write_ass emits the EP title Dialogue when the
## style carries ep+title, and nothing when it doesn't. Run:
##   godot --headless --path . -s res://tools/test_ass_title.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pm: Node = root.get_node("/root/PreviewMaker")
	var cues := [{"start": 0.0, "end": 1.0, "text": "x"}]
	var p := ProjectSettings.globalize_path("user://_tmp_title.ass")

	pm.write_ass(cues, {"ep": 7, "title": "hi there"}, p)
	var t := FileAccess.get_file_as_string(p)
	_check("Title style in header", t.contains("Style: Title,Anuphan"))
	_check("EP07 title event present", t.contains(",Title,,0,0,0,,EP07 : hi there"))

	pm.write_ass(cues, {}, p)   # no ep/title -> no title event
	t = FileAccess.get_file_as_string(p)
	_check("no title event without ep/title", not t.contains(",Title,,0,0,0,,"))

	DirAccess.remove_absolute(p)
	print("\n=== ass title tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
