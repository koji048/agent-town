## The Caption Studio's timeline: three stacked track-rows (Title / Caption /
## Media) of boxes with a playhead. Owns geometry, hit-testing, drag/trim/cut/
## delete; the studio owns the data and reacts to signals. Pure math is static
## so it is unit-testable headless.
class_name TimelineView
extends Control

const MIN_DUR := 0.2
const EDGE_PX := 7.0
const TITLE_SEC := 2.5


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
