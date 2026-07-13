## Headless test for CaptionStudio._set_cue_time clamping. Run:
##   godot --headless --path . -s res://tools/test_cue_retime.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var cs: Node = load("res://scripts/caption_studio.gd").new()
	cs._duration = 3.0

	# start can't cross the previous cue's end (1.0)
	cs.cues = [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 2.0, "text": "b"}, {"start": 2.0, "end": 3.0, "text": "c"}]
	cs._set_cue_time(1, 0.5, 2.0)
	_check("start clamped to prev end", cs.cues[1]["start"] >= 1.0 - 0.001)

	# end can't cross the next cue's start (2.0)
	cs.cues = [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 2.0, "text": "b"}, {"start": 2.0, "end": 3.0, "text": "c"}]
	cs._set_cue_time(1, 1.0, 2.5)
	_check("end clamped to next start", cs.cues[1]["end"] <= 2.0 + 0.001)

	# minimum duration enforced (>= 0.2s)
	cs.cues = [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 2.0, "text": "b"}, {"start": 2.0, "end": 3.0, "text": "c"}]
	cs._set_cue_time(1, 1.95, 2.0)
	_check("MIN_DUR enforced", cs.cues[1]["end"] - cs.cues[1]["start"] >= 0.2 - 0.001)

	# first/last cue clamp to 0 and _duration
	cs.cues = [{"start": 0.5, "end": 1.0, "text": "a"}]
	cs._set_cue_time(0, -1.0, 5.0)
	_check("first cue start >= 0", cs.cues[0]["start"] >= 0.0)
	_check("last cue end <= duration", cs.cues[0]["end"] <= 3.0 + 0.001)

	# sub-MIN_DUR window: a contiguous <0.2s middle cue must NOT overlap/invert
	cs.cues = [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 1.1, "text": "b"}, {"start": 1.1, "end": 2.0, "text": "c"}]
	cs._set_cue_time(1, 0.5, 5.0)
	_check("tiny cue start >= prev end", cs.cues[1]["start"] >= 1.0 - 0.001)
	_check("tiny cue end <= next start", cs.cues[1]["end"] <= 1.1 + 0.001)
	_check("tiny cue start <= end (no inversion)", cs.cues[1]["start"] <= cs.cues[1]["end"] + 0.001)

	print("\n=== cue retime tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
