## Headless test: PreviewMaker.build_burn_args — trivial EDL keeps the plain
## -vf path; a real EDL assembles via trim/atrim+concat before the reframe.
##   godot --headless --path . --quit-after 600 -s res://tools/test_edl_burn.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pm: Node = root.get_node("/root/PreviewMaker")
	var vfr := "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
	var plain := " ".join(pm.build_burn_args("in.mp4", vfr, "/tmp/x.ass", "/fonts", [], "out.mp4"))
	_check("trivial: plain -vf path", plain.contains("-vf") and not plain.contains("-filter_complex"))
	_check("trivial: subtitles appended", plain.contains("subtitles=filename=/tmp/x.ass:fontsdir=/fonts"))
	_check("trivial: 48k stereo kept", plain.contains("-ar 48000") and plain.contains("-ac 2"))

	var edl := [[1.0, 2.5], [5.0, 7.0]]
	var fc := " ".join(pm.build_burn_args("in.mp4", vfr, "/tmp/x.ass", "/fonts", edl, "out.mp4"))
	_check("edl: filter_complex path", fc.contains("-filter_complex") and not fc.contains("-vf "))
	_check("edl: trims both segments", fc.contains("trim=start=1.000:end=2.500") and fc.contains("atrim=start=5.000:end=7.000"))
	_check("edl: concat pair", fc.contains("concat=n=2:v=1:a=1"))
	_check("edl: reframe+subs after concat", fc.contains("[vc]" + vfr + ",subtitles="))
	_check("edl: maps assembled streams", fc.contains("-map [vout]") and fc.contains("-map [ac]"))
	_check("edl: 48k stereo kept", fc.contains("-ar 48000") and fc.contains("-ac 2"))

	print("\n=== edl burn tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
