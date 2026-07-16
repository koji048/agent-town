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

	# --- phantom-box guard: an empty title_text must never be hit-testable ---
	var tv3 = TimelineView.new()
	tv3.size = Vector2(1000.0, 120.0)
	tv3.duration = D
	tv3.cues = []
	tv3.title_start = 0.0
	tv3.title_text = ""   # cleared title -> no box to hit
	var cleared3 := {"fired": false}
	tv3.selection_cleared.connect(func() -> void: cleared3["fired"] = true)
	# press squarely on where the (empty) title box would have been
	tv3.press(Vector2(100.0, tv3.title_row_y() + 4.0))
	_check("empty title never selects", tv3.sel_kind != "title")
	_check("empty title falls through to none", tv3.sel_kind == "none")
	_check("empty title press clears selection", cleared3["fired"])

	# --- empty-space press elsewhere also clears selection ---
	var tv4 = TimelineView.new()
	tv4.size = Vector2(1000.0, 120.0)
	tv4.duration = D
	tv4.cues = []
	tv4.title_text = ""
	var cleared4 := {"fired": false}
	tv4.selection_cleared.connect(func() -> void: cleared4["fired"] = true)
	tv4.press(Vector2(500.0, tv4.media_row_y() + 4.0))  # media row: empty space
	_check("empty-space press emits selection_cleared", cleared4["fired"])

	# --- cut / delete ---
	var tv2 = TimelineView.new()
	tv2.size = Vector2(1000.0, 120.0)
	tv2.duration = D
	tv2.cues = [{"start": 4.0, "end": 6.0, "text": "b"}]
	tv2.sel_kind = "cue"
	tv2.sel_cue = 0
	var ev := {"split": -1, "del": -1}
	tv2.cue_split.connect(func(i: int, _at: float) -> void: ev["split"] = i)
	tv2.cue_deleted.connect(func(i: int) -> void: ev["del"] = i)

	tv2.playhead = 5.0
	tv2.cut_at_playhead()
	_check("cut splits into two", tv2.cues.size() == 2)
	_check("cut left half ends at playhead", is_equal_approx(float(tv2.cues[0]["end"]), 5.0))
	_check("cut right half starts at playhead", is_equal_approx(float(tv2.cues[1]["start"]), 5.0))
	_check("cut copies text", str(tv2.cues[1]["text"]) == "b")
	_check("cut emits signal", ev["split"] == 0)

	# cut too close to an edge -> no-op
	tv2.sel_cue = 0
	tv2.playhead = 4.05
	tv2.cut_at_playhead()
	_check("cut near edge is a no-op", tv2.cues.size() == 2)

	# blade semantics: NO selection needed — cut whatever is under the playhead
	# (selecting a cue snaps the playhead to its start, so select-then-cut was
	# always a silent no-op; the blade must work straight off the playhead)
	tv2.sel_kind = "none"
	tv2.sel_cue = -1
	tv2.playhead = 5.5   # inside the right half [5.0, 6.0]
	tv2.cut_at_playhead()
	_check("blade cuts under playhead without selection", tv2.cues.size() == 3)
	_check("blade selects the left half", tv2.sel_kind == "cue" and tv2.sel_cue == 1)
	tv2.sel_kind = "none"
	tv2.playhead = 2.0   # in the gap before the first cue
	tv2.cut_at_playhead()
	_check("blade in a gap is a no-op", tv2.cues.size() == 3)

	# delete selected (3 cues remain after the blade block above)
	tv2.sel_kind = "cue"
	tv2.sel_cue = 1
	tv2.delete_selected()
	_check("delete removes cue", tv2.cues.size() == 2)
	_check("delete emits signal", ev["del"] == 1)
	_check("delete clears selection", tv2.sel_kind == "none")

	# --- clamp_span edge cases (ported from the retired test_cue_retime.gd, which
	# exercised the old CaptionStudio._set_cue_time; that logic now lives here) ---
	var cd := 3.0
	var cc := [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 2.0, "text": "b"}, {"start": 2.0, "end": 3.0, "text": "c"}]
	var r0: Array = TimelineView.clamp_span(cc, 1, 0.5, 2.0, cd)   # start can't cross prev end (1.0)
	_check("clamp start >= prev end", r0[0] >= 1.0 - 0.001)
	var r1: Array = TimelineView.clamp_span(cc, 1, 1.0, 2.5, cd)   # end can't cross next start (2.0)
	_check("clamp end <= next start", r1[1] <= 2.0 + 0.001)
	var r2: Array = TimelineView.clamp_span(cc, 1, 1.95, 2.0, cd)  # MIN_DUR enforced when window allows
	_check("clamp enforces MIN_DUR", r2[1] - r2[0] >= 0.2 - 0.001)
	var single := [{"start": 0.5, "end": 1.0, "text": "a"}]
	var r3: Array = TimelineView.clamp_span(single, 0, -1.0, 5.0, cd)  # lone cue clamps to [0, duration]
	_check("clamp lone start >= 0", r3[0] >= 0.0 - 0.001)
	_check("clamp lone end <= duration", r3[1] <= cd + 0.001)
	var tiny := [{"start": 0.0, "end": 1.0, "text": "a"}, {"start": 1.0, "end": 1.1, "text": "b"}, {"start": 1.1, "end": 2.0, "text": "c"}]
	var r4: Array = TimelineView.clamp_span(tiny, 1, 0.5, 5.0, cd)  # sub-MIN_DUR window: no overlap/inversion
	_check("clamp tiny start >= prev end", r4[0] >= 1.0 - 0.001)
	_check("clamp tiny end <= next start", r4[1] <= 1.1 + 0.001)
	_check("clamp tiny start <= end (no inversion)", r4[0] <= r4[1] + 0.001)

	# --- shift_all_delta (group move: clamp one delta against the whole set) ---
	var sc := [{"start": 1.0, "end": 2.0, "text": "a"}, {"start": 4.0, "end": 6.0, "text": "b"}]
	# with title [0, 2.5]: min_start=0, max_end=6, duration=10 -> right room = 4
	_check("shift right within room", is_equal_approx(TimelineView.shift_all_delta(sc, 0.0, 2.5, 3.0, 10.0, true), 3.0))
	_check("shift right clamps at wall", is_equal_approx(TimelineView.shift_all_delta(sc, 0.0, 2.5, 9.0, 10.0, true), 4.0))
	_check("shift left blocked by title at 0", is_equal_approx(TimelineView.shift_all_delta(sc, 0.0, 2.5, -1.0, 10.0, true), 0.0))
	# without title: min_start=1 -> left room = 1
	_check("shift left within room (no title)", is_equal_approx(TimelineView.shift_all_delta(sc, 0.0, 2.5, -1.0, 10.0, false), -1.0))
	_check("shift left clamps (no title)", is_equal_approx(TimelineView.shift_all_delta(sc, 0.0, 2.5, -5.0, 10.0, false), -1.0))
	_check("shift empty set is zero", is_equal_approx(TimelineView.shift_all_delta([], 0.0, 2.5, 3.0, 10.0, false), 0.0))

	# --- title duration: edge-resize + move keep the box within [0, duration] ---
	var tvt = TimelineView.new()
	tvt.size = Vector2(1000.0, 120.0)
	tvt.duration = D
	tvt.title_text = "EP"
	tvt.title_start = 2.0
	tvt.title_dur = 2.5
	var tgot := {"start": -1.0, "dur": -1.0}
	tvt.title_time_changed.connect(func(s: float, du: float) -> void:
		tgot["start"] = s; tgot["dur"] = du)
	# grab the RIGHT edge (at title_start+dur = 4.5 -> x=450) and drag to t=6 -> dur grows to 4
	tvt.press(Vector2(TimelineView.time_to_x(4.5, 1000.0, D), tvt.title_row_y() + 4.0))
	tvt.motion(Vector2(600.0, tvt.title_row_y() + 4.0))
	_check("title right-edge resizes dur", is_equal_approx(tvt.title_dur, 4.0) and is_equal_approx(tvt.title_start, 2.0))
	# grab the LEFT edge (at 2.0 -> x=200) and drag to t=1 -> start moves, end (4.5) fixed -> dur 3.5
	tvt.title_start = 2.0
	tvt.title_dur = 2.5
	tvt.press(Vector2(TimelineView.time_to_x(2.0, 1000.0, D), tvt.title_row_y() + 4.0))
	tvt.motion(Vector2(TimelineView.time_to_x(1.0, 1000.0, D), tvt.title_row_y() + 4.0))
	_check("title left-edge moves start keeps end", is_equal_approx(tvt.title_start, 1.0) and is_equal_approx(tvt.title_start + tvt.title_dur, 4.5))
	# min duration: drag right edge left past MIN_TITLE_DUR
	tvt.title_start = 2.0
	tvt.title_dur = 2.5
	tvt.press(Vector2(TimelineView.time_to_x(4.5, 1000.0, D), tvt.title_row_y() + 4.0))
	tvt.motion(Vector2(TimelineView.time_to_x(2.0, 1000.0, D), tvt.title_row_y() + 4.0))
	_check("title dur holds MIN_TITLE_DUR", tvt.title_dur >= 0.5 - 0.001)
	tvt.release()

	# --- select all + group move ---
	var tva = TimelineView.new()
	tva.size = Vector2(1000.0, 120.0)
	tva.duration = D
	tva.title_text = "EP"
	tva.title_start = 0.0
	tva.title_dur = 2.5
	tva.cues = [{"start": 1.0, "end": 2.0, "text": "a"}, {"start": 4.0, "end": 6.0, "text": "b"}]
	tva.select_all()
	_check("select_all sets sel_kind all", tva.sel_kind == "all")
	# grab anywhere on the caption row and drag +3s (from t=5 to t=8)
	tva.press(Vector2(TimelineView.time_to_x(5.0, 1000.0, D), tva.caption_row_y() + 4.0))
	tva.motion(Vector2(TimelineView.time_to_x(8.0, 1000.0, D), tva.caption_row_y() + 4.0))
	_check("group move shifts cue a", is_equal_approx(float(tva.cues[0]["start"]), 4.0))
	_check("group move shifts cue b end", is_equal_approx(float(tva.cues[1]["end"]), 9.0))
	_check("group move shifts title", is_equal_approx(tva.title_start, 3.0))
	tva.release()

	# --- EDL statics: output<->source mapping ---
	var eg := [{"src_start": 10.0, "src_end": 14.0}, {"src_start": 2.0, "src_end": 5.0}]
	_check("out_len sums segments", is_equal_approx(TimelineView.out_len(eg), 7.0))
	_check("out_len empty", is_equal_approx(TimelineView.out_len([]), 0.0))
	_check("out_start first", is_equal_approx(TimelineView.out_start(eg, 0), 0.0))
	_check("out_start second", is_equal_approx(TimelineView.out_start(eg, 1), 4.0))
	_check("seg_at_out inside first", TimelineView.seg_at_out(eg, 1.0) == 0)
	_check("seg_at_out at seam -> right segment", TimelineView.seg_at_out(eg, 4.0) == 1)
	_check("seg_at_out past end", TimelineView.seg_at_out(eg, 7.5) == -1)
	_check("seg_at_out negative", TimelineView.seg_at_out(eg, -0.1) == -1)
	_check("out_to_src first", is_equal_approx(TimelineView.out_to_src(eg, 1.0), 11.0))
	_check("out_to_src across seam", is_equal_approx(TimelineView.out_to_src(eg, 5.0), 3.0))
	_check("out_to_src end clamps", is_equal_approx(TimelineView.out_to_src(eg, 99.0), 5.0))
	var eg2 := [{"src_start": 0.0, "src_end": 10.0}]
	_check("cut splits segment", TimelineView.cut_footage(eg2, 4.0) and eg2.size() == 2)
	_check("cut halves correct", is_equal_approx(float(eg2[0]["src_end"]), 4.0) and is_equal_approx(float(eg2[1]["src_start"]), 4.0))
	_check("cut near edge no-op", not TimelineView.cut_footage(eg2, 0.2) and eg2.size() == 2)
	_check("cut maps through seam to source", TimelineView.cut_footage(eg2, 6.0) and eg2.size() == 3 and is_equal_approx(float(eg2[1]["src_end"]), 6.0))

	# --- delete_segment: cues ripple with the footage (owner rule A) ---
	var ds := [{"src_start": 0.0, "src_end": 4.0}, {"src_start": 4.0, "src_end": 8.0}, {"src_start": 8.0, "src_end": 12.0}]
	var dcs := [
		{"start": 1.0, "end": 2.0, "text": "a"},
		{"start": 3.5, "end": 5.0, "text": "b"},
		{"start": 5.0, "end": 6.0, "text": "c"},
		{"start": 7.5, "end": 9.0, "text": "d"},
		{"start": 10.0, "end": 11.0, "text": "e"},
	]
	_check("delete middle ok", TimelineView.delete_segment(ds, dcs, 1) and ds.size() == 2)
	_check("inside cue dropped -> 4 remain", dcs.size() == 4)
	_check("cue before untouched", is_equal_approx(float(dcs[0]["start"]), 1.0))
	_check("straddle-in tail-trimmed", is_equal_approx(float(dcs[1]["end"]), 4.0))
	_check("straddle-out head-trimmed+rippled", is_equal_approx(float(dcs[2]["start"]), 4.0) and is_equal_approx(float(dcs[2]["end"]), 5.0))
	_check("cue after shifted", is_equal_approx(float(dcs[3]["start"]), 6.0))
	_check("last segment protected", not TimelineView.delete_segment([{"src_start": 0.0, "src_end": 4.0}], [], 0))
	var ds2 := [{"src_start": 0.0, "src_end": 2.0}, {"src_start": 2.0, "src_end": 4.0}, {"src_start": 4.0, "src_end": 6.0}]
	var dc2 := [{"start": 1.0, "end": 5.0, "text": "x"}]
	TimelineView.delete_segment(ds2, dc2, 1)
	_check("spanning cue shrinks", is_equal_approx(float(dc2[0]["start"]), 1.0) and is_equal_approx(float(dc2[0]["end"]), 3.0))
	var ds3 := [{"src_start": 0.0, "src_end": 2.0}, {"src_start": 2.0, "src_end": 4.0}]
	var dc3 := [{"start": 1.95, "end": 3.0, "text": "t"}]
	TimelineView.delete_segment(ds3, dc3, 1)
	_check("sub-MIN_DUR leftover dropped", dc3.is_empty())

	# --- reorder_segment: cues travel with their footage (midpoint rule) ---
	var rs := [{"src_start": 0.0, "src_end": 4.0}, {"src_start": 4.0, "src_end": 8.0}]
	var rcs := [{"start": 1.0, "end": 2.0, "text": "A"}, {"start": 5.0, "end": 6.0, "text": "B"}]
	_check("reorder ok", TimelineView.reorder_segment(rs, rcs, 1, 0))
	_check("segments swapped", is_equal_approx(float(rs[0]["src_start"]), 4.0))
	_check("B now first block", str(rcs[0]["text"]) == "B" and is_equal_approx(float(rcs[0]["start"]), 1.0))
	_check("A now second block", str(rcs[1]["text"]) == "A" and is_equal_approx(float(rcs[1]["start"]), 5.0))
	_check("reorder same index no-op", not TimelineView.reorder_segment(rs, rcs, 0, 0))
	_check("reorder bad index no-op", not TimelineView.reorder_segment(rs, rcs, 0, 5))

	# --- media segments: select + blade/delete routing ---
	var tvs = TimelineView.new()
	tvs.size = Vector2(1000.0, 120.0)
	tvs.src_duration = 10.0
	tvs.segments = [{"src_start": 0.0, "src_end": 10.0}]
	tvs.duration = TimelineView.out_len(tvs.segments)
	tvs.cues = []
	var sev := {"sel": -1, "changed": 0}
	tvs.segment_selected.connect(func(i: int) -> void: sev["sel"] = i)
	tvs.segments_changed.connect(func() -> void: sev["changed"] += 1)
	tvs.press(Vector2(500.0, tvs.media_row_y() + 4.0))
	_check("press media selects segment", sev["sel"] == 0 and tvs.sel_kind == "segment")
	tvs.release()
	tvs.playhead = 5.0
	tvs.cut_at_playhead()
	_check("blade cuts footage when segment selected", tvs.segments.size() == 2 and sev["changed"] == 1)
	tvs.sel_kind = "segment"
	tvs.sel_seg = 0
	tvs.delete_selected()
	_check("delete removes segment", tvs.segments.size() == 1 and sev["changed"] == 2)
	_check("delete clears segment selection", tvs.sel_kind == "none")
	tvs.sel_kind = "segment"
	tvs.sel_seg = 0
	tvs.delete_selected()
	_check("last segment protected via UI", tvs.segments.size() == 1)

	# --- segment drag reorder ---
	var tvr = TimelineView.new()
	tvr.size = Vector2(1000.0, 120.0)
	tvr.src_duration = 10.0
	tvr.segments = [{"src_start": 0.0, "src_end": 4.0}, {"src_start": 4.0, "src_end": 10.0}]
	tvr.duration = TimelineView.out_len(tvr.segments)
	tvr.cues = [{"start": 1.0, "end": 2.0, "text": "A"}]
	tvr.press(Vector2(TimelineView.time_to_x(2.0, 1000.0, 10.0), tvr.media_row_y() + 4.0))
	tvr.motion(Vector2(TimelineView.time_to_x(8.0, 1000.0, 10.0), tvr.media_row_y() + 4.0))
	_check("drag swaps segments", is_equal_approx(float(tvr.segments[0]["src_start"]), 4.0))
	_check("cue followed its segment", is_equal_approx(float(tvr.cues[0]["start"]), 7.0))
	_check("selection follows the drag", tvr.sel_seg == 1)
	tvr.release()

	print("\n=== timeline view tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
