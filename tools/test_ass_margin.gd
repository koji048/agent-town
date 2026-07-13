## Headless test: PreviewMaker.write_ass emits the chosen MarginV into the ASS
## style line (the "where you place it is where it burns" guarantee). Run:
##   godot --headless --path . -s res://tools/test_ass_margin.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pm: Node = root.get_node("/root/PreviewMaker")
	var cues := [{"start": 0.0, "end": 1.0, "text": "hi"}]
	var p := ProjectSettings.globalize_path("user://_tmp_margin.ass")

	pm.write_ass(cues, {"margin_v": 500}, p)
	var t := FileAccess.get_file_as_string(p)
	_check("chosen margin 500 in style line", t.contains("70,70,500,1"))
	_check("old hardcoded 220 is gone", not t.contains("70,70,220,1"))

	pm.write_ass(cues, {}, p)   # no margin_v -> default 360
	t = FileAccess.get_file_as_string(p)
	_check("default margin 360 when unset", t.contains("70,70,360,1"))

	DirAccess.remove_absolute(p)

	# caption colour -> ASS BGR (regression guard for the byte order); _ass_color
	# is pure string formatting, so a bare instance (no _ready) is enough
	var cs: Node = load("res://scripts/caption_studio.gd").new()
	_check("ass colour red -> &H000000FF", cs._ass_color(Color(1, 0, 0)) == "&H000000FF")
	_check("ass colour blue -> &H00FF0000", cs._ass_color(Color(0, 0, 1)) == "&H00FF0000")
	cs.free()

	print("\n=== ass margin tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
