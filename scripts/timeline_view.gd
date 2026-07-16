## The Caption Studio's timeline: three stacked track-rows (Title / Caption /
## Media) of boxes with a playhead. Owns geometry, hit-testing, drag/trim/cut/
## delete; the studio owns the data and reacts to signals. Pure math is static
## so it is unit-testable headless.
class_name TimelineView
extends Control

const MIN_DUR := 0.2
const EDGE_PX := 7.0
const TITLE_SEC := 2.5
const MIN_TITLE_DUR := 0.5
const MIN_SEG_DUR := 0.5

const RULER_H := 16.0
const ROW_H := 22.0
const ROW_GAP := 4.0

# --- state, assigned by the studio ---
var cues: Array = []
var duration := 1.0
var wave: PackedFloat32Array
var frames: Array = []          # a few ImageTextures for the media strip (optional)
var title_text := ""
var title_start := 0.0
var title_dur := TITLE_SEC
var playhead := 0.0
var sel_kind := "none"          # "none" | "cue" | "title"
var sel_cue := -1

var _drag_mode := ""            # "" | "seek" | "start" | "end" | "move" | "title"
var _drag_grab := 0.0           # grab offset within the dragged element, seconds

signal cue_selected(i: int)
signal title_selected()
signal selection_cleared()
signal cue_time_changed(i: int, start: float, end: float)
signal title_time_changed(start: float, dur: float)
signal edit_committed()
signal cue_split(i: int, at: float)
signal cue_deleted(i: int)
signal seek(t: float)


func title_row_y() -> float:
	return RULER_H + ROW_GAP


func caption_row_y() -> float:
	return title_row_y() + ROW_H + ROW_GAP


func media_row_y() -> float:
	return caption_row_y() + ROW_H + ROW_GAP


## Seconds -> pixel X within a strip of width w (clamped to [0, w]).
static func time_to_x(t: float, w: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(t / duration, 0.0, 1.0) * w


## Pixel X -> seconds within a strip of width w (clamped to [0, duration]).
static func x_to_time(x: float, w: float, duration: float) -> float:
	if w <= 0.0:
		return 0.0
	return clampf(x / w, 0.0, 1.0) * duration


## Index of the caption box under px (edges count as inside); -1 if none.
static func cue_at(cues: Array, px: float, w: float, duration: float) -> int:
	for i in cues.size():
		var x0 := time_to_x(float(cues[i]["start"]), w, duration)
		var x1 := time_to_x(float(cues[i]["end"]), w, duration)
		if px >= x0 - EDGE_PX and px <= x1 + EDGE_PX:
			return i
	return -1


## TRIM helper: clamp cue i's new [ns, ne] inside its neighbour walls with
## start <= end, then enforce MIN_DUR when the window allows. Gaps are fine.
static func clamp_span(cues: Array, i: int, ns: float, ne: float, duration: float) -> Array:
	var lo := 0.0 if i == 0 else float(cues[i - 1]["end"])
	var hi := duration if i == cues.size() - 1 else float(cues[i + 1]["start"])
	if hi < lo:
		hi = lo
	ne = clampf(ne, lo, hi)
	ns = clampf(ns, lo, ne)
	if hi - lo >= MIN_DUR and ne - ns < MIN_DUR:
		ne = minf(ns + MIN_DUR, hi)
		ns = maxf(ne - MIN_DUR, lo)
	return [ns, ne]


## MOVE helper: shift cue i to start at ns keeping its duration, parked at the
## neighbour walls (never reorders).
static func move_span(cues: Array, i: int, ns: float, duration: float) -> Array:
	var dur := float(cues[i]["end"]) - float(cues[i]["start"])
	var lo := 0.0 if i == 0 else float(cues[i - 1]["end"])
	var hi := duration if i == cues.size() - 1 else float(cues[i + 1]["start"])
	var s := clampf(ns, lo, maxf(hi - dur, lo))
	return [s, s + dur]


## Split [s, e] at `at`; [] if either half would be < MIN_DUR.
static func split_span(s: float, e: float, at: float) -> Array:
	if at - s < MIN_DUR or e - at < MIN_DUR:
		return []
	return [[s, at], [at, e]]


## Clamp `delta` so shifting every cue (and the title when `has_title`) by it
## keeps the whole block inside [0, duration]. Returns the allowed shift.
static func shift_all_delta(cues: Array, title_start: float, title_dur: float, delta: float, duration: float, has_title: bool) -> float:
	var min_start := INF
	var max_end := -INF
	for c in cues:
		min_start = minf(min_start, float(c["start"]))
		max_end = maxf(max_end, float(c["end"]))
	if has_title:
		min_start = minf(min_start, title_start)
		max_end = maxf(max_end, title_start + title_dur)
	if min_start == INF:
		return 0.0
	return clampf(delta, -min_start, duration - max_end)


## ---- EDL (Phase 2): the output timeline is the ordered concatenation of
## source segments; the source footage itself is never touched. ----


## Total output duration (sum of segment lengths).
static func out_len(segments: Array) -> float:
	var acc := 0.0
	for seg in segments:
		acc += float(seg["src_end"]) - float(seg["src_start"])
	return acc


## Output start time of segment i (prefix sum).
static func out_start(segments: Array, i: int) -> float:
	var acc := 0.0
	for k in mini(i, segments.size()):
		acc += float(segments[k]["src_end"]) - float(segments[k]["src_start"])
	return acc


## Which segment contains output time t (a seam belongs to the RIGHT segment);
## -1 outside [0, out_len).
static func seg_at_out(segments: Array, t: float) -> int:
	if t < 0.0:
		return -1
	var acc := 0.0
	for k in segments.size():
		var l := float(segments[k]["src_end"]) - float(segments[k]["src_start"])
		if t < acc + l:
			return k
		acc += l
	return -1


## Map an output position to the source position (clamps past the end).
static func out_to_src(segments: Array, t: float) -> float:
	if segments.is_empty():
		return t
	var acc := 0.0
	for seg in segments:
		var l := float(seg["src_end"]) - float(seg["src_start"])
		if t < acc + l:
			return float(seg["src_start"]) + maxf(t - acc, 0.0)
		acc += l
	return float(segments[-1]["src_end"])


## Blade the footage: split the segment under at_out at the mapped source
## position. False (no mutation) outside any segment or if a half < MIN_SEG_DUR.
static func cut_footage(segments: Array, at_out: float) -> bool:
	var i := seg_at_out(segments, at_out)
	if i < 0:
		return false
	var s0 := float(segments[i]["src_start"])
	var s1 := float(segments[i]["src_end"])
	var split_src := s0 + (at_out - out_start(segments, i))
	if split_src - s0 < MIN_SEG_DUR or s1 - split_src < MIN_SEG_DUR:
		return false
	segments[i]["src_end"] = split_src
	segments.insert(i + 1, {"src_start": split_src, "src_end": s1})
	return true


## Route a left-press to a title/caption box (select + arm drag), the ruler
## (seek), or empty space (clear selection + seek).
func press(pos: Vector2) -> void:
	var w := size.x
	if pos.y < RULER_H:
		_drag_mode = "seek"
		seek.emit(x_to_time(pos.x, w, duration))
		return
	if sel_kind == "all":
		if pos.y >= title_row_y() and pos.y < caption_row_y() + ROW_H:
			_drag_mode = "all"
			_drag_grab = x_to_time(pos.x, w, duration)  # last-seen time
			return
		# a press outside the title/caption rows drops the group selection
		_drag_mode = "seek"
		sel_kind = "none"
		selection_cleared.emit()
		seek.emit(x_to_time(pos.x, w, duration))
		queue_redraw()
		return
	if pos.y >= title_row_y() and pos.y < title_row_y() + ROW_H and not title_text.is_empty():
		var tx0 := time_to_x(title_start, w, duration)
		var tx1 := time_to_x(title_start + title_dur, w, duration)
		if pos.x >= tx0 - EDGE_PX and pos.x <= tx1 + EDGE_PX:
			if absf(pos.x - tx0) <= EDGE_PX:
				_drag_mode = "title_start"
			elif absf(pos.x - tx1) <= EDGE_PX:
				_drag_mode = "title_end"
			else:
				_drag_mode = "title"
				_drag_grab = x_to_time(pos.x, w, duration) - title_start
			sel_kind = "title"
			sel_cue = -1
			title_selected.emit()
			queue_redraw()
			return
	if pos.y >= caption_row_y() and pos.y < caption_row_y() + ROW_H:
		var i := cue_at(cues, pos.x, w, duration)
		if i >= 0:
			var x0 := time_to_x(float(cues[i]["start"]), w, duration)
			var x1 := time_to_x(float(cues[i]["end"]), w, duration)
			if absf(pos.x - x0) <= EDGE_PX:
				_drag_mode = "start"
			elif absf(pos.x - x1) <= EDGE_PX:
				_drag_mode = "end"
			else:
				_drag_mode = "move"
				_drag_grab = x_to_time(pos.x, w, duration) - float(cues[i]["start"])
			sel_kind = "cue"
			sel_cue = i
			cue_selected.emit(i)
			queue_redraw()
			return
	# empty space / media lane -> clear selection and seek
	_drag_mode = "seek"
	sel_kind = "none"
	sel_cue = -1
	selection_cleared.emit()
	seek.emit(x_to_time(pos.x, w, duration))
	queue_redraw()


## Apply the in-progress drag (live). The studio persists on `edit_committed`.
func motion(pos: Vector2) -> void:
	var w := size.x
	var t := x_to_time(pos.x, w, duration)
	match _drag_mode:
		"seek":
			seek.emit(t)
		"title":
			title_start = clampf(t - _drag_grab, 0.0, maxf(duration - title_dur, 0.0))
			title_time_changed.emit(title_start, title_dur)
			queue_redraw()
		"title_start":
			var end_t := title_start + title_dur
			var ns := clampf(t, 0.0, end_t - MIN_TITLE_DUR)
			title_start = ns
			title_dur = end_t - ns
			title_time_changed.emit(title_start, title_dur)
			queue_redraw()
		"title_end":
			var ne := clampf(t, title_start + MIN_TITLE_DUR, duration)
			title_dur = ne - title_start
			title_time_changed.emit(title_start, title_dur)
			queue_redraw()
		"start":
			_apply_span(sel_cue, clamp_span(cues, sel_cue, t, float(cues[sel_cue]["end"]), duration))
		"end":
			_apply_span(sel_cue, clamp_span(cues, sel_cue, float(cues[sel_cue]["start"]), t, duration))
		"move":
			_apply_span(sel_cue, move_span(cues, sel_cue, t - _drag_grab, duration))
		"all":
			var d := shift_all_delta(cues, title_start, title_dur, t - _drag_grab, duration, not title_text.is_empty())
			for i in cues.size():
				cues[i]["start"] = float(cues[i]["start"]) + d
				cues[i]["end"] = float(cues[i]["end"]) + d
				cue_time_changed.emit(i, float(cues[i]["start"]), float(cues[i]["end"]))
			if not title_text.is_empty():
				title_start += d
				title_time_changed.emit(title_start, title_dur)
			_drag_grab += d
			queue_redraw()


func _apply_span(i: int, sp: Array) -> void:
	if i < 0 or i >= cues.size():
		return
	cues[i]["start"] = sp[0]
	cues[i]["end"] = sp[1]
	cue_time_changed.emit(i, sp[0], sp[1])
	queue_redraw()


## End a drag; ask the studio to persist if the drag actually edited something.
func release() -> void:
	if _drag_mode in ["start", "end", "move", "title", "title_start", "title_end", "all"]:
		edit_committed.emit()
	_drag_mode = ""


## Blade (CapCut/Resolve semantics): split whatever caption is UNDER the
## playhead into two cues inheriting the text — no selection required.
## (Requiring a selection was a trap: selecting a cue snaps the playhead to
## its START, so the natural select-then-cut flow always hit the
## zero-length-half no-op and looked like a dead button.)
func cut_at_playhead() -> void:
	var i := -1
	for k in cues.size():
		if playhead > float(cues[k]["start"]) and playhead < float(cues[k]["end"]):
			i = k
			break
	if i < 0:
		return
	var c: Dictionary = cues[i]
	var parts := split_span(float(c["start"]), float(c["end"]), playhead)
	if parts.is_empty():
		return
	var cut_text := str(c["text"])
	cues[i]["end"] = parts[0][1]
	cues.insert(i + 1, {"start": parts[1][0], "end": parts[1][1], "text": cut_text})
	sel_kind = "cue"
	sel_cue = i
	cue_split.emit(i, playhead)
	_drag_mode = ""
	queue_redraw()


## Select every caption + the title as one block (Select All).
func select_all() -> void:
	sel_kind = "all"
	sel_cue = -1
	queue_redraw()


## Remove the selected caption cue.
func delete_selected() -> void:
	if sel_kind != "cue" or sel_cue < 0 or sel_cue >= cues.size():
		return
	var i := sel_cue
	cues.remove_at(i)
	sel_kind = "none"
	sel_cue = -1
	_drag_mode = ""
	cue_deleted.emit(i)
	selection_cleared.emit()
	queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	custom_minimum_size = Vector2(0, 120)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				press(mb.position)
			else:
				release()
	elif ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		motion((ev as InputEventMouseMotion).position)
	elif ev is InputEventKey and (ev as InputEventKey).pressed:
		var k := ev as InputEventKey
		if k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
			delete_selected()
			edit_committed.emit()
		elif k.keycode == KEY_S:
			cut_at_playhead()
			edit_committed.emit()


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.10, 0.10, 0.14))
	var w := sz.x

	# ruler ticks (every ~2s)
	var step := 2.0
	var t := 0.0
	while t <= duration:
		var rx := time_to_x(t, w, duration)
		draw_line(Vector2(rx, 0), Vector2(rx, RULER_H), Color(0.3, 0.32, 0.4), 1.0)
		t += step

	# title row: one box start..start+title_dur
	if not title_text.is_empty():
		var ty := title_row_y()
		var tx0 := time_to_x(title_start, w, duration)
		var tx1 := time_to_x(title_start + title_dur, w, duration)
		var tcol := Color(1.0, 0.85, 0.35, 0.9) if (sel_kind == "title" or sel_kind == "all") else Color(1.0, 0.85, 0.35, 0.55)
		draw_rect(Rect2(tx0, ty, maxf(tx1 - tx0, 3.0), ROW_H), tcol)
		draw_string(get_theme_default_font(), Vector2(tx0 + 4, ty + ROW_H - 6),
			"EP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.12))
		if sel_kind == "title" or sel_kind == "all":
			var thc := Color(1.0, 0.95, 0.6, 0.95)
			draw_rect(Rect2(tx0, ty, 3.0, ROW_H), thc)
			draw_rect(Rect2(tx1 - 3.0, ty, 3.0, ROW_H), thc)

	# caption row: one box per cue
	var cy := caption_row_y()
	for i in cues.size():
		var x0 := time_to_x(float(cues[i]["start"]), w, duration)
		var x1 := time_to_x(float(cues[i]["end"]), w, duration)
		var on := (sel_kind == "cue" and i == sel_cue) or sel_kind == "all"
		var col := Color(1.0, 0.78, 0.32, 0.9) if on else Color(0.55, 0.75, 1.0, 0.6)
		draw_rect(Rect2(x0, cy, maxf(x1 - x0 - 1.0, 2.0), ROW_H), col)
		if on:
			var hc := Color(1.0, 0.95, 0.6, 0.95)
			draw_rect(Rect2(x0, cy, 3.0, ROW_H), hc)
			draw_rect(Rect2(x1 - 3.0, cy, 3.0, ROW_H), hc)

	# media row: filmstrip thumbnails (if any) + waveform
	var my := media_row_y()
	var mh := maxf(sz.y - my, 8.0)
	if not frames.is_empty():
		var fw := w / frames.size()
		for i in frames.size():
			var tex := frames[i] as Texture2D
			if tex:
				draw_texture_rect(tex, Rect2(i * fw, my, fw, mh), false)
	if not wave.is_empty():
		var n := wave.size()
		var mid := my + mh * 0.5
		for i in n:
			var x := i * w / n
			var h := wave[i] * (mh * 0.48)
			draw_line(Vector2(x, mid - h), Vector2(x, mid + h), Color(0.35, 0.45, 0.55, 0.9), 1.0)

	# playhead across all rows
	var px := time_to_x(playhead, w, duration)
	draw_line(Vector2(px, 0), Vector2(px, sz.y), Color(0.95, 0.45, 0.33), 2.0)
