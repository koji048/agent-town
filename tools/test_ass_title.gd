## Headless test: PreviewMaker.write_ass emits a styled, positioned EP title
## event from the studio's title fields (edited text + font/colour/pos), falls
## back to EP.. : topic, and emits nothing without either. Run:
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

	# edited title with its own font / colour / position
	pm.write_ass(cues, {
		"title_text": "EP7 HELLO", "title_font": "Kanit", "title_size": 90,
		"title_primary": "&H000000FF", "title_x": 300, "title_y": 800}, p)
	var t := FileAccess.get_file_as_string(p)
	_check("Title style uses the chosen font/size/colour", t.contains("Style: Title,Kanit,90,&H000000FF"))
	_check("title event: \\pos + edited text", t.contains(",Title,,0,0,0,,{\\pos(300,800)}EP7 HELLO"))

	# fallback: no title_text -> build EP.. : topic, default centre
	pm.write_ass(cues, {"ep": 7, "title": "hi"}, p)
	t = FileAccess.get_file_as_string(p)
	_check("fallback EP07 : hi at default \\pos", t.contains(",Title,,0,0,0,,{\\pos(540,960)}EP07 : hi"))

	# shifted title window: title_start / title_end move the Dialogue timing
	pm.write_ass(cues, {"title_text": "EP7 HELLO", "title_start": 3.0, "title_end": 5.5}, p)
	t = FileAccess.get_file_as_string(p)
	_check("title honours title_start/title_end",
		t.contains("Dialogue: 0,0:00:03.00,0:00:05.50,Title,,0,0,0,,"))

	# default (no title_start) still burns 0:00:00.00 -> 0:00:02.50
	pm.write_ass(cues, {"title_text": "EP7 HELLO"}, p)
	t = FileAccess.get_file_as_string(p)
	_check("title default window unchanged",
		t.contains("Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,"))

	# multi-line title: newlines become ASS \N (not spaces)
	pm.write_ass(cues, {"title_text": "EP7 LINE1\nLINE2"}, p)
	t = FileAccess.get_file_as_string(p)
	_check("title newline -> \\N", t.contains(",Title,,0,0,0,,{\\pos(540,960)}EP7 LINE1\\NLINE2"))
	_check("title has no flattened space", not t.contains("EP7 LINE1 LINE2"))

	# nothing -> no title event
	pm.write_ass(cues, {}, p)
	t = FileAccess.get_file_as_string(p)
	_check("no title event without text/ep", not t.contains(",Title,,0,0,0,,"))

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
