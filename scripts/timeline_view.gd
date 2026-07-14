## The Caption Studio's timeline: three stacked track-rows (Title / Caption /
## Media) of boxes with a playhead. Owns geometry, hit-testing, drag/trim/cut/
## delete; the studio owns the data and reacts to signals. Pure math is static
## so it is unit-testable headless.
class_name TimelineView
extends Control

const MIN_DUR := 0.2
const EDGE_PX := 7.0
const TITLE_SEC := 2.5

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
var playhead := 0.0
var sel_kind := "none"          # "none" | "cue" | "title"
var sel_cue := -1

var _drag_mode := ""            # "" | "seek" | "start" | "end" | "move" | "title"
var _drag_grab := 0.0           # grab offset within the dragged element, seconds

signal cue_selected(i: int)
signal title_selected()
signal selection_cleared()
signal cue_time_changed(i: int, start: float, end: float)
signal title_time_changed(start: float)
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


## Route a left-press to a title/caption box (select + arm drag), the ruler
## (seek), or empty space (clear selection + seek).
func press(pos: Vector2) -> void:
	var w := size.x
	if pos.y < RULER_H:
		_drag_mode = "seek"
		seek.emit(x_to_time(pos.x, w, duration))
		return
	if pos.y >= title_row_y() and pos.y < title_row_y() + ROW_H and not title_text.is_empty():
		var tx0 := time_to_x(title_start, w, duration)
		var tx1 := time_to_x(title_start + TITLE_SEC, w, duration)
		if pos.x >= tx0 - EDGE_PX and pos.x <= tx1 + EDGE_PX:
			sel_kind = "title"
			sel_cue = -1
			_drag_mode = "title"
			_drag_grab = x_to_time(pos.x, w, duration) - title_start
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
			title_start = clampf(t - _drag_grab, 0.0, maxf(duration - TITLE_SEC, 0.0))
			title_time_changed.emit(title_start)
			queue_redraw()
		"start":
			_apply_span(sel_cue, clamp_span(cues, sel_cue, t, float(cues[sel_cue]["end"]), duration))
		"end":
			_apply_span(sel_cue, clamp_span(cues, sel_cue, float(cues[sel_cue]["start"]), t, duration))
		"move":
			_apply_span(sel_cue, move_span(cues, sel_cue, t - _drag_grab, duration))


func _apply_span(i: int, sp: Array) -> void:
	if i < 0 or i >= cues.size():
		return
	cues[i]["start"] = sp[0]
	cues[i]["end"] = sp[1]
	cue_time_changed.emit(i, sp[0], sp[1])
	queue_redraw()


## End a drag; ask the studio to persist if the drag actually edited something.
func release() -> void:
	if _drag_mode in ["start", "end", "move", "title"]:
		edit_committed.emit()
	_drag_mode = ""
