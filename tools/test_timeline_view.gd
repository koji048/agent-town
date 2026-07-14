## Headless test: TimelineView pure geometry + span helpers.
##   godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var TimelineView = load("res://scripts/timeline_view.gd")
	var W := 1000.0
	var D := 10.0

	# time_to_x / x_to_time round-trip + clamping
	_check("time_to_x midpoint", is_equal_approx(TimelineView.time_to_x(5.0, W, D), 500.0))
	_check("x_to_time midpoint", is_equal_approx(TimelineView.x_to_time(500.0, W, D), 5.0))
	_check("time_to_x clamps high", is_equal_approx(TimelineView.time_to_x(99.0, W, D), 1000.0))
	_check("x_to_time clamps low", is_equal_approx(TimelineView.x_to_time(-50.0, W, D), 0.0))

	var cues := [
		{"start": 1.0, "end": 2.0, "text": "a"},
		{"start": 4.0, "end": 6.0, "text": "b"},
	]
	# cue_at: inside box b, in the gap, and off the end
	_check("cue_at inside b", TimelineView.cue_at(cues, 500.0, W, D) == 1)
	_check("cue_at in gap", TimelineView.cue_at(cues, 300.0, W, D) == -1)
	_check("cue_at edge tolerance", TimelineView.cue_at(cues, 100.0 - 5.0, W, D) == 0)

	# clamp_span (TRIM): end can't cross next start; MIN_DUR held; gap allowed
	var s0: Array = TimelineView.clamp_span(cues, 0, 1.0, 9.0, D)  # end into b -> clamps to 4.0
	_check("clamp trim end to neighbour", is_equal_approx(s0[1], 4.0))
	var s1: Array = TimelineView.clamp_span(cues, 0, 1.0, 1.05, D)  # < MIN_DUR -> widened to 0.2
	_check("clamp trim holds MIN_DUR", is_equal_approx(s1[1] - s1[0], 0.2))
	var s2: Array = TimelineView.clamp_span(cues, 0, 1.0, 1.5, D)   # leaves a gap before b -> ok
	_check("clamp trim allows gap", is_equal_approx(s2[0], 1.0) and is_equal_approx(s2[1], 1.5))

	# move_span (MOVE): keeps duration, parks at the wall
	var m0: Array = TimelineView.move_span(cues, 1, 0.0, D)  # b(dur 2) pushed left, parks at a.end=2.0
	_check("move parks at left wall", is_equal_approx(m0[0], 2.0) and is_equal_approx(m0[1], 4.0))
	var m1: Array = TimelineView.move_span(cues, 0, 2.5, D)  # a(dur 1) placed in open space
	_check("move keeps duration", is_equal_approx(m1[1] - m1[0], 1.0))
	var m2: Array = TimelineView.move_span(cues, 0, 9.0, D)  # a(dur 1) pushed right, parks at b.start=4.0
	_check("move parks at right wall", is_equal_approx(m2[0], 3.0) and is_equal_approx(m2[1], 4.0))

	# split_span
	var sp: Array = TimelineView.split_span(4.0, 6.0, 5.0)
	_check("split valid", sp.size() == 2 and is_equal_approx(sp[0][1], 5.0) and is_equal_approx(sp[1][0], 5.0))
	_check("split rejects tiny left", TimelineView.split_span(4.0, 6.0, 4.1).is_empty())
	_check("split rejects tiny right", TimelineView.split_span(4.0, 6.0, 5.95).is_empty())

	# --- drag logic (call press/motion/release directly, assert on signals) ---
	var tv = TimelineView.new()
	tv.size = Vector2(1000.0, 120.0)
	tv.duration = D
	tv.cues = [
		{"start": 1.0, "end": 2.0, "text": "a"},
		{"start": 4.0, "end": 6.0, "text": "b"},
	]
	tv.title_start = 0.0
	tv.title_text = "EP7"
	tv.playhead = 5.0

	var got := {"sel": -99, "title": false, "seek": -1.0, "cleared": false}
	tv.cue_selected.connect(func(i: int) -> void: got["sel"] = i)
	tv.title_selected.connect(func() -> void: got["title"] = true)
	tv.selection_cleared.connect(func() -> void: got["cleared"] = true)
	tv.seek.connect(func(t: float) -> void: got["seek"] = t)

	# press inside caption b's body -> selects cue 1
	tv.press(Vector2(500.0, tv.caption_row_y() + 4.0))
	_check("press selects caption", got["sel"] == 1 and tv.sel_kind == "cue")
	# move b left toward the wall -> keeps duration, parks at a.end = 2.0
	tv.motion(Vector2(50.0, tv.caption_row_y() + 4.0))
	_check("drag-move parks at wall", is_equal_approx(float(tv.cues[1]["start"]), 2.0))
	tv.release()

	# press on the title box -> title_selected
	tv.press(Vector2(100.0, tv.title_row_y() + 4.0))
	_check("press selects title", got["title"] and tv.sel_kind == "title")
	# drag the title along time
	tv.motion(Vector2(600.0, tv.title_row_y() + 4.0))
	_check("title drag moves start", tv.title_start > 0.0)
	tv.release()

	# press on the ruler -> seek, clears selection stays cue? ruler seeks only
	tv.press(Vector2(200.0, 2.0))
	_check("ruler press seeks", is_equal_approx(got["seek"], 2.0))

	print("\n=== timeline view tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
