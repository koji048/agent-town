# Multi-track Timeline (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Caption Studio's single-lane bottom strip into a Resolve/CapCut-style 3-row timeline (Title / Caption / Media) whose boxes drive one context-sensitive Inspector, with caption move/trim/cut/delete and a time-draggable title.

**Architecture:** A new `TimelineView` (`Control` subclass) owns all timeline geometry, hit-testing, drag/trim/cut/delete and the playhead, exposing pure static math (`time_to_x`, `x_to_time`, `cue_at`, `clamp_span`, `move_span`, `split_span`) and callable input methods (`press`/`motion`/`release`/`cut_at_playhead`/`delete_selected`) so the interaction logic is unit-testable headless. `caption_studio.gd` becomes the wiring hub + single source of truth (`cues`, `_title_*`), feeding data down and reacting to signals; the scrolling cue list and always-on EP Title strip are removed in favour of a selection-driven Inspector. The burn path is unchanged except the title `Dialogue` start/end now derive from a `title_start` field.

**Tech Stack:** Godot 4 / GDScript. Headless SceneTree test scripts run via `godot --headless --path . --quit-after 600 -s res://tools/<script>.gd` (or `tools/run_test.sh <script>`). The `--quit-after 600` ceiling is mandatory: `-s` boots the whole project (autoloads included), so a test that errors before its `quit()` would otherwise loop forever and leak to OOM — this exact failure once ballooned an orphaned test process to 150 GB and OOM-killed the editor. Never launch a headless test without it.

## Global Constraints

- Godot engine floor: **4.6.1** (CI uses the `barichello/godot-ci` container); local dev is 4.7.stable. Use no API newer than 4.6.
- Tests are headless SceneTree scripts that `print` a `=== ... N passed, N failed ===` line and `quit(1 if fails else 0)`. Follow the existing `tools/test_ass_title.gd` shape.
- `MIN_DUR = 0.2` s (shortest cue), `EDGE_PX = 7.0` (edge grab tolerance), `TITLE_SEC = 2.5` s (title card width) — copy these exact values.
- Caption cue dict shape is `{"start": float, "end": float, "text": String}`. Cues stay sorted by time and never overlap.
- The burn/preview contract in `PreviewMaker.write_ass` must stay backward-compatible: with no `title_start`, the title still burns `0:00:00.00 → 0:00:02.50`.
- Commit after every task. End commit messages with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

### Task 1: TimelineView pure math (statics) + tests

**Files:**
- Create: `scripts/timeline_view.gd`
- Test: `tools/test_timeline_view.gd`

**Interfaces:**
- Produces (static, called by later tasks and the studio):
  - `TimelineView.time_to_x(t: float, w: float, duration: float) -> float`
  - `TimelineView.x_to_time(x: float, w: float, duration: float) -> float`
  - `TimelineView.cue_at(cues: Array, px: float, w: float, duration: float) -> int`
  - `TimelineView.clamp_span(cues: Array, i: int, ns: float, ne: float, duration: float) -> Array` (returns `[start, end]`, used for TRIM)
  - `TimelineView.move_span(cues: Array, i: int, ns: float, duration: float) -> Array` (returns `[start, end]`, keeps duration, used for MOVE)
  - `TimelineView.split_span(s: float, e: float, at: float) -> Array` (returns `[[s, at], [at, e]]`, or `[]` if invalid)

- [ ] **Step 1: Write the failing test**

Create `tools/test_timeline_view.gd`:

```gdscript
## Headless test: TimelineView pure geometry + span helpers.
##   godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
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
	var s0 := TimelineView.clamp_span(cues, 0, 1.0, 9.0, D)  # end into b -> clamps to 4.0
	_check("clamp trim end to neighbour", is_equal_approx(s0[1], 4.0))
	var s1 := TimelineView.clamp_span(cues, 0, 1.0, 1.05, D)  # < MIN_DUR -> widened to 0.2
	_check("clamp trim holds MIN_DUR", is_equal_approx(s1[1] - s1[0], 0.2))
	var s2 := TimelineView.clamp_span(cues, 0, 1.0, 1.5, D)   # leaves a gap before b -> ok
	_check("clamp trim allows gap", is_equal_approx(s2[0], 1.0) and is_equal_approx(s2[1], 1.5))

	# move_span (MOVE): keeps duration, parks at the wall
	var m0 := TimelineView.move_span(cues, 1, 0.0, D)  # b(dur 2) pushed left, parks at a.end=2.0
	_check("move parks at left wall", is_equal_approx(m0[0], 2.0) and is_equal_approx(m0[1], 4.0))
	var m1 := TimelineView.move_span(cues, 0, 2.5, D)  # a(dur 1) placed in open space
	_check("move keeps duration", is_equal_approx(m1[1] - m1[0], 1.0))
	var m2 := TimelineView.move_span(cues, 0, 9.0, D)  # a(dur 1) pushed right, parks at b.start=4.0
	_check("move parks at right wall", is_equal_approx(m2[0], 3.0) and is_equal_approx(m2[1], 4.0))

	# split_span
	var sp := TimelineView.split_span(4.0, 6.0, 5.0)
	_check("split valid", sp.size() == 2 and is_equal_approx(sp[0][1], 5.0) and is_equal_approx(sp[1][0], 5.0))
	_check("split rejects tiny left", TimelineView.split_span(4.0, 6.0, 4.1).is_empty())
	_check("split rejects tiny right", TimelineView.split_span(4.0, 6.0, 5.95).is_empty())

	print("\n=== timeline view tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: parse/identifier error — `TimelineView` not found (the class doesn't exist yet).

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/timeline_view.gd`:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 15 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: TimelineView pure geometry + span helpers\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 2: Burn — title Dialogue start/end from `title_start`

**Files:**
- Modify: `scripts/autoload/preview_maker.gd:195-199` (the title `Dialogue` emission inside `write_ass`)
- Test: `tools/test_ass_title.gd` (add one case)

**Interfaces:**
- Consumes: `style` dict passed to `write_ass` — now also reads `style["title_start"]` (float, default `0.0`) and `style["title_end"]` (float, default `title_start + TITLE_SEC` where `TITLE_SEC = 2.5`).
- Produces: title `Dialogue` line timed `_fmt_ass(title_start) → _fmt_ass(title_end)` instead of the hard-coded `0:00:00.00,0:00:02.50`.

- [ ] **Step 1: Write the failing test**

In `tools/test_ass_title.gd`, add these two lines immediately after the existing fallback check block (after the line `_check("fallback EP07 : hi at default \\pos", ...)`):

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd`
Expected: FAIL on "title honours title_start/title_end" (still emits the hard-coded `0:00:00.00,0:00:02.50`).

- [ ] **Step 3: Write the implementation**

In `scripts/autoload/preview_maker.gd`, replace the title emission block (currently lines 195-199):

```gdscript
	if not title_text.is_empty():
		var tx: int = int(style.get("title_x", 540))
		var ty: int = int(style.get("title_y", 960))
		f.store_string("Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,{\\pos(%d,%d)}%s\n" % [
			tx, ty, title_text.left(80).replace("\n", " ")])
```

with:

```gdscript
	if not title_text.is_empty():
		var tx: int = int(style.get("title_x", 540))
		var ty: int = int(style.get("title_y", 960))
		var t_start: float = float(style.get("title_start", 0.0))
		var t_end: float = float(style.get("title_end", t_start + 2.5))
		f.store_string("Dialogue: 0,%s,%s,Title,,0,0,0,,{\\pos(%d,%d)}%s\n" % [
			_fmt_ass(t_start), _fmt_ass(t_end), tx, ty, title_text.left(80).replace("\n", " ")])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd`
Expected: `=== ass title tests: 6 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/autoload/preview_maker.gd tools/test_ass_title.gd
git commit -m "$(printf 'feat: title burn window derives from title_start/title_end\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 3: TimelineView instance state + drag logic (select / move / trim / seek / title-drag)

**Files:**
- Modify: `scripts/timeline_view.gd` (add instance state, signals, `press`/`motion`/`release`)
- Test: `tools/test_timeline_view.gd` (add a drag-logic block)

**Interfaces:**
- Consumes: the statics from Task 1.
- Produces (used by the studio in Task 6):
  - Instance state assigned by the studio: `cues: Array`, `duration: float`, `wave: PackedFloat32Array`, `frames: Array`, `title_text: String`, `title_start: float`, `playhead: float`, `sel_kind: String` (`"none"|"cue"|"title"`), `sel_cue: int`.
  - Signals: `cue_selected(i)`, `title_selected()`, `selection_cleared()`, `cue_time_changed(i, start, end)`, `title_time_changed(start)`, `edit_committed()`, `cue_split(i, at)`, `cue_deleted(i)`, `seek(t)`.
  - Methods: `press(pos: Vector2)`, `motion(pos: Vector2)`, `release()`.
  - Row geometry constants: `RULER_H`, `ROW_H`, `ROW_GAP`, and helpers `title_row_y()`, `caption_row_y()`, `media_row_y()`.

- [ ] **Step 1: Write the failing test**

In `tools/test_timeline_view.gd`, add a new block just before the final `print(...)` line:

```gdscript
	# --- drag logic (call press/motion/release directly, assert on signals) ---
	var tv := TimelineView.new()
	tv.size = Vector2(1000.0, 120.0)
	tv.duration = D
	tv.cues = [
		{"start": 1.0, "end": 2.0, "text": "a"},
		{"start": 4.0, "end": 6.0, "text": "b"},
	]
	tv.title_start = 0.0
	tv.title_text = "EP7"   # title box is only hit-testable when it has text (matches _draw)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: FAIL — `caption_row_y`/`press`/signals not defined yet.

- [ ] **Step 3: Write the implementation**

In `scripts/timeline_view.gd`, add after the constants (before `time_to_x`):

```gdscript
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
```

Then add the input methods at the end of the file:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 21 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: TimelineView state + select/move/trim/title-drag logic\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 4: TimelineView cut/split + delete

**Files:**
- Modify: `scripts/timeline_view.gd` (add `cut_at_playhead`, `delete_selected`)
- Test: `tools/test_timeline_view.gd` (add a cut/delete block)

**Interfaces:**
- Consumes: `split_span` (Task 1); state + signals (Task 3).
- Produces: `cut_at_playhead()` (splits the selected cue at `playhead`, inserts the new cue after it, emits `cue_split(i, at)`), `delete_selected()` (removes the selected cue, emits `cue_deleted(i)` then `selection_cleared()`).

- [ ] **Step 1: Write the failing test**

In `tools/test_timeline_view.gd`, add before the final `print(...)`:

```gdscript
	# --- cut / delete ---
	var tv2 := TimelineView.new()
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

	# cut too close to an edge -> no change
	tv2.sel_cue = 0
	tv2.playhead = 4.05
	tv2.cut_at_playhead()
	_check("cut near edge is a no-op", tv2.cues.size() == 2)

	# delete selected
	tv2.sel_kind = "cue"
	tv2.sel_cue = 1
	tv2.delete_selected()
	_check("delete removes cue", tv2.cues.size() == 1)
	_check("delete emits signal", ev["del"] == 1)
	_check("delete clears selection", tv2.sel_kind == "none")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: FAIL — `cut_at_playhead`/`delete_selected` not defined.

- [ ] **Step 3: Write the implementation**

Append to `scripts/timeline_view.gd`:

```gdscript
## Blade: split the selected caption at the playhead into two adjacent cues,
## each inheriting the text. No-op unless the playhead is well inside the box.
func cut_at_playhead() -> void:
	if sel_kind != "cue" or sel_cue < 0 or sel_cue >= cues.size():
		return
	var c: Dictionary = cues[sel_cue]
	var parts := split_span(float(c["start"]), float(c["end"]), playhead)
	if parts.is_empty():
		return
	cues[sel_cue]["end"] = parts[0][1]
	cues.insert(sel_cue + 1, {"start": parts[1][0], "end": parts[1][1], "text": str(c["text"])})
	cue_split.emit(sel_cue, playhead)
	queue_redraw()


## Remove the selected caption cue.
func delete_selected() -> void:
	if sel_kind != "cue" or sel_cue < 0 or sel_cue >= cues.size():
		return
	var i := sel_cue
	cues.remove_at(i)
	sel_kind = "none"
	sel_cue = -1
	cue_deleted.emit(i)
	selection_cleared.emit()
	queue_redraw()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 30 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: TimelineView cut/split + delete\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 5: TimelineView rendering (3 rows) + input/keyboard routing

**Files:**
- Modify: `scripts/timeline_view.gd` (add `_init`, `_draw`, `_gui_input`)
- Verify: `tools/ci_check.gd` (parse) + the Task 1–4 tests still pass

**Interfaces:**
- Consumes: all state + methods from Tasks 3–4.
- Produces: a self-wiring control — the studio only needs to `TimelineView.new()`, assign state, and connect signals (Task 6). `_gui_input` routes mouse to `press`/`motion`/`release`; `Delete`/`Backspace` → `delete_selected`; `S` → `cut_at_playhead`.

- [ ] **Step 1: Add `_init`, `_draw`, `_gui_input`**

Append to `scripts/timeline_view.gd`:

```gdscript
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

	# title row: one box start..start+TITLE_SEC
	if not title_text.is_empty():
		var ty := title_row_y()
		var tx0 := time_to_x(title_start, w, duration)
		var tx1 := time_to_x(title_start + TITLE_SEC, w, duration)
		var tcol := Color(1.0, 0.85, 0.35, 0.9) if sel_kind == "title" else Color(1.0, 0.85, 0.35, 0.55)
		draw_rect(Rect2(tx0, ty, maxf(tx1 - tx0, 3.0), ROW_H), tcol)
		draw_string(get_theme_default_font(), Vector2(tx0 + 4, ty + ROW_H - 6),
			"EP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.12))

	# caption row: one box per cue
	var cy := caption_row_y()
	for i in cues.size():
		var x0 := time_to_x(float(cues[i]["start"]), w, duration)
		var x1 := time_to_x(float(cues[i]["end"]), w, duration)
		var col := Color(1.0, 0.78, 0.32, 0.9) if (sel_kind == "cue" and i == sel_cue) else Color(0.55, 0.75, 1.0, 0.6)
		draw_rect(Rect2(x0, cy, maxf(x1 - x0 - 1.0, 2.0), ROW_H), col)
		if sel_kind == "cue" and i == sel_cue:
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
```

- [ ] **Step 2: Verify it parses (ci_check) and tests still pass**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`; ci_check reports success.

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 30 passed, 0 failed ===` (adding `_init`/`_draw` must not change logic).

- [ ] **Step 3: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd
git commit -m "$(printf 'feat: TimelineView 3-row rendering + input/keyboard routing\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 6: Studio swap — TimelineView in, cue list out, signals wired

**Files:**
- Modify: `scripts/caption_studio.gd` (state, `_ready` timeline construction + cue-list removal, `open_clip`, `_show_time`, new signal handlers, `style_dict`; remove old timeline methods)
- Verify: `tools/ci_check.gd` + manual studio launch

**Interfaces:**
- Consumes: `TimelineView` (Tasks 1–5) — assigns `cues`, `duration`, `wave`, `frames`, `title_text`, `title_start`, `playhead`, `sel_kind`, `sel_cue`; connects `cue_selected`, `cue_time_changed`, `edit_committed`, `cue_split`, `cue_deleted`, `seek` (title signals wired in Task 7). Calls `TimelineView.clamp_span(...)` for the spin fields.
- Produces: `style_dict()` gains `title_start` + `title_end`; the studio holds `_title_start := 0.0`.

- [ ] **Step 1: Add `_title_start` state**

In `scripts/caption_studio.gd`, after the line `var _title_font_idx := 0` (line 51), add:

```gdscript
var _title_start := 0.0    # EP title window start on the timeline, seconds
```

- [ ] **Step 2: Replace the cue-list scroll block with nothing (Inspector keeps the edit widgets)**

In `_ready`, delete the `ScrollContainer`/`_cue_list` block (currently lines 293-299):

```gdscript
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	_cue_list = VBoxContainer.new()
	_cue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cue_list)
	right.add_child(scroll)
```

Leave `_cue_edit`, the timing `trow` (start/end spins), the save button, the burn `actions`, and `_auto_label` exactly as they are — those become the caption Inspector.

- [ ] **Step 3: Replace the bottom timeline construction with a TimelineView**

Replace the timeline block (currently lines 357-362):

```gdscript
	# ---- bottom: waveform timeline with cue blocks + playhead
	_timeline = Control.new()
	_timeline.custom_minimum_size = Vector2(0, 96)
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_timeline_input)
	root.add_child(_timeline)
```

with:

```gdscript
	# ---- bottom: 3-row timeline (Title / Caption / Media)
	_timeline = TimelineView.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.cue_selected.connect(_on_cue_selected)
	_timeline.cue_time_changed.connect(_on_cue_time_changed)
	_timeline.edit_committed.connect(_on_edit_committed)
	_timeline.cue_split.connect(_on_cue_split)
	_timeline.cue_deleted.connect(_on_cue_deleted)
	_timeline.seek.connect(_seek)
	root.add_child(_timeline)
```

- [ ] **Step 4: Change the `_timeline` field type**

Change line 52 from:

```gdscript
var _timeline: Control
```

to:

```gdscript
var _timeline: TimelineView
```

- [ ] **Step 5: Feed the timeline in `open_clip` and drop the cue-list rebuild**

In `open_clip`, replace the line `_rebuild_cue_list()` (line 401) with:

```gdscript
	_title_start = 0.0
	_timeline.cues = cues
	_timeline.duration = _duration
	_timeline.wave = _wave
	_timeline.frames = _sample_strip()
	_timeline.title_text = _title_text
	_timeline.title_start = _title_start
	_timeline.sel_kind = "none"
	_timeline.sel_cue = -1
```

- [ ] **Step 6: Add the media-strip sampler**

Add this method near `_show_time` in `scripts/caption_studio.gd`:

```gdscript
## Up to 12 evenly-spaced filmstrip thumbnails for the timeline's Media row.
func _sample_strip() -> Array:
	var out: Array = []
	if _frame_total <= 0:
		return out
	var count := mini(12, _frame_total)
	for k in count:
		var idx := clampi(int(float(k) / count * _frame_total) + 1, 1, _frame_total)
		var img := Image.new()
		if img.load(_frames_dir.path_join("f_%05d.jpg" % idx)) == OK:
			out.append(ImageTexture.create_from_image(img))
	return out
```

- [ ] **Step 7: Update `_show_time` to push playhead + selection into the timeline**

In `_show_time`, replace the trailing `_timeline.queue_redraw()` (line 450) with:

```gdscript
	_timeline.playhead = _t
	_timeline.title_start = _title_start
	_timeline.queue_redraw()
```

- [ ] **Step 8: Add the signal handlers**

Add these methods to `scripts/caption_studio.gd` (near `_save_cue`):

```gdscript
## A caption box was clicked: load it into the Inspector and seek to its start.
func _on_cue_selected(i: int) -> void:
	_sel = i
	_cue_edit.text = str(cues[i]["text"])
	_sync_time_fields()
	_show_inspector("caption")
	_seek(float(cues[i]["start"]))


## Live drag of a caption edge/body: reflect timing into the spins + preview.
func _on_cue_time_changed(i: int, _s: float, _e: float) -> void:
	if i == _sel:
		_sync_time_fields()
	_show_time()


## Drag/keyboard edit finished: persist the cues to the .srt.
func _on_edit_committed() -> void:
	PreviewMaker.write_srt(cues, _srt_path)


## A caption was split: persist, keep the left half selected, refresh Inspector.
func _on_cue_split(i: int, _at: float) -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_on_cue_selected(i)


## A caption was deleted: persist and clear the Inspector.
func _on_cue_deleted(_i: int) -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_sel = -1
	_show_inspector("none")
```

- [ ] **Step 9: Repoint the spin fields + `_save_cue` at the timeline clamp; remove the old timeline methods**

Replace `_set_cue_time` (lines 484-500) — delete it. Replace `_apply_time_fields` (lines 512-517) body to use the static clamp:

```gdscript
## Push the spin values into the selected cue (clamped), persist, redraw.
func _apply_time_fields() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	var sp := TimelineView.clamp_span(cues, _sel, _start_spin.value, _end_spin.value, _duration)
	cues[_sel]["start"] = sp[0]
	cues[_sel]["end"] = sp[1]
	PreviewMaker.write_srt(cues, _srt_path)
	_sync_time_fields()
	_show_time()
```

Delete the now-unused `_commit_cues` (lines 503-509), `_rebuild_cue_list` (lines 460-477), `_mmss` (lines 480-481), `_draw_timeline` (lines 657-683), `_timeline_input` (686-698), `_begin_timeline_drag` (701-723), and `_update_timeline_drag` (726-748). Remove the now-dead fields `_cue_list`, `_drag_mode`, `_drag_cue`, `_drag_grab` (lines 53-55, 58).

Update `_save_cue` (lines 530-538) to stop calling `_rebuild_cue_list`:

```gdscript
func _save_cue() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	cues[_sel]["text"] = _cue_edit.text.strip_edges()
	PreviewMaker.write_srt(cues, _srt_path)
	EventBus.log_line.emit("✏ Caption %d fixed -> %s" % [_sel + 1, _srt_path.get_file()])
	Sfx.play_ui("paper", -10.0)
	_timeline.title_text = _title_text
	_timeline.queue_redraw()
	_show_time()
```

- [ ] **Step 10: Add `title_start`/`title_end` to `style_dict`**

In `style_dict` (before the closing `}` at line 640), add:

```gdscript
		"title_start": _title_start,
		"title_end": _title_start + TITLE_SEC,
```

- [ ] **Step 11: Add a temporary `_show_inspector` stub (full version in Task 7)**

Add to `scripts/caption_studio.gd`:

```gdscript
## Show the editor for the current selection. Full title branch in Task 7.
func _show_inspector(kind: String) -> void:
	_cue_edit.visible = kind == "caption"
```

- [ ] **Step 12: Verify parse + run studio**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`.

Manual: launch the studio with a seeded clip and confirm the 3-row timeline shows, the cue list is gone, clicking a caption box loads it into the edit box + spins, dragging a caption body/edge works and no longer overlaps, `S` splits at the playhead, `Delete` removes a caption, and Burn still works:

```bash
cd /Users/thanakorn/agent-town-1
AGENT_TOWN_STUDIO="$(pwd)/tools/fixtures/demo-clean.srt|$(pwd)/tools/fixtures/frames|EP07 : ตั้งกล้องถ่าย Reels" godot --path . scenes/main.tscn
```

(If `tools/fixtures/` does not exist, use whatever seeded SRT + frames dir the prior studio demos used — the same hook the earlier phases were tested with.)

- [ ] **Step 13: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/caption_studio.gd
git commit -m "$(printf 'feat: studio hosts TimelineView; drop cue list; wire timeline signals\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 7: Studio context Inspector for the title + remove the EP Title strip

**Files:**
- Modify: `scripts/caption_studio.gd` (title Inspector widgets, full `_show_inspector`, wire `title_selected`/`selection_cleared`/`title_time_changed`, remove the always-on EP Title strip)
- Verify: `tools/ci_check.gd` + manual studio

**Interfaces:**
- Consumes: the TimelineView `title_selected`, `selection_cleared`, `title_time_changed` signals; the existing `_title_edit`/`_title_font_idx`/`_title_color` state.
- Produces: `_show_inspector(kind)` toggles caption widgets vs. title widgets vs. a hint; the EP Title strip is no longer always visible — its widgets live in the Inspector, shown only when the title box is selected.

- [ ] **Step 1: Turn the EP Title strip into an Inspector panel (hidden until selected)**

In `_ready`, the EP Title strip block (currently lines 260-292) builds `title_row` with `_title_edit`, the title font `tfp`, and the title colour `tcp`. Keep that block but:
- capture the row and the font picker into fields so `_show_inspector` can toggle/read them. Change `var title_row :=` to assign a new field `_title_inspector`, and change `var tfp :=` to assign a new field `_title_font_pick`.

Add these fields near the other title state (after `var _title_start := 0.0`):

```gdscript
var _title_inspector: HBoxContainer
var _title_font_pick: OptionButton
```

Change line 261 `var title_row := HBoxContainer.new()` to:

```gdscript
	_title_inspector = HBoxContainer.new()
	var title_row := _title_inspector
```

Change line 278 `var tfp := OptionButton.new()` to:

```gdscript
	_title_font_pick = OptionButton.new()
	var tfp := _title_font_pick
```

- [ ] **Step 2: Wire the title signals in the timeline construction**

In the `_timeline` construction (Task 6, Step 3), add three more connections:

```gdscript
	_timeline.title_selected.connect(_on_title_selected)
	_timeline.selection_cleared.connect(_on_selection_cleared)
	_timeline.title_time_changed.connect(_on_title_time_changed)
```

- [ ] **Step 3: Add the title signal handlers**

```gdscript
func _on_title_selected() -> void:
	_sel = -1
	_show_inspector("title")


func _on_selection_cleared() -> void:
	_sel = -1
	_show_inspector("none")


func _on_title_time_changed(start: float) -> void:
	_title_start = start
	_show_time()
```

- [ ] **Step 4: Replace the `_show_inspector` stub with the full version**

Replace the Task 6 stub with:

```gdscript
## Show only the editor widgets for the current selection.
##   "caption" -> text edit + timing spins (+ the shared style bar on the left)
##   "title"   -> the EP Title strip (text + font + colour)
##   "none"    -> neither; just the hint
func _show_inspector(kind: String) -> void:
	_cue_edit.visible = kind == "caption"
	_start_spin.get_parent().visible = kind == "caption"
	if _title_inspector:
		_title_inspector.visible = kind == "title"
```

- [ ] **Step 5: Default the Inspector to the title strip hidden on open**

At the end of `open_clip` (after the timeline feed block from Task 6, Step 5), add:

```gdscript
	_show_inspector("none")
```

And in `_ready`, immediately after `right.add_child(title_row)` (line 292), hide it initially:

```gdscript
	_title_inspector.visible = false
```

- [ ] **Step 6: Verify parse + run studio**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`.

Manual (same hook as Task 6, Step 12): confirm that on open the Inspector shows the hint only; clicking a **caption** box shows the text box + timing spins; clicking the **title** box shows the EP Title strip (text/font/colour) and hides the caption widgets; dragging the title box along the timeline moves its window and the burn preview; nothing shows both at once.

- [ ] **Step 7: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/caption_studio.gd
git commit -m "$(printf 'feat: selection-driven Inspector (caption vs title); drop always-on EP strip\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 8: Full verification sweep + roadmap memory

**Files:**
- Verify only (no product code); update `/Users/thanakorn/.claude/projects/-Users-thanakorn-agent-town-1/memory/clip-caption-roadmap.md`

- [ ] **Step 1: Run every headless test**

```bash
cd /Users/thanakorn/agent-town-1
godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd
godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd
godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd
```
Expected: `30 passed, 0 failed`; `6 passed, 0 failed`; ci_check clean.

- [ ] **Step 2: Manual end-to-end in the studio**

Launch via the `AGENT_TOWN_STUDIO` hook and exercise, in one session: select caption → edit text (save) → drag body (no overlap) → drag both edges (MIN_DUR holds) → `S` split at playhead → `Delete` one half → select title → change font/colour → drag title along time → Burn. Confirm the burned ASS (`/tmp/at_studio.ass`) has the moved/split cues and the title `Dialogue` at the dragged start.

- [ ] **Step 3: Update the roadmap memory**

Add a line to `clip-caption-roadmap.md` recording that the multi-track timeline Phase 1 (Title/Caption/Media rows, box move/trim/cut/delete, draggable title, selection-driven Inspector) is implemented, and that Phase 2 (footage cut/reorder + ffmpeg burn re-assembly) remains, per `docs/superpowers/specs/2026-07-14-multitrack-timeline-design.md`.

- [ ] **Step 4: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add -A
git commit -m "$(printf 'chore: verify multi-track timeline P1; note P2 in roadmap\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage:**
- §1 three rows (Title/Caption/Media) → Task 5 `_draw`. ✅
- §2 `TimelineView` control + pure helpers → Tasks 1,3,4,5; Inspector → Tasks 6–7; studio shrinks (cue list + EP strip removed) → Tasks 6–7. ✅
- §3 caption select/move/trim/cut/delete → Tasks 3–4; title select + time-drag → Tasks 3 (+7 wiring); media scrub + playhead → Tasks 3,5. ✅
- §4 single source of truth + burn `title_start` → Tasks 2,6. ✅
- §5 new `test_timeline_view.gd` (geometry/clamp/split) → Tasks 1,3,4; `test_ass_title.gd` title_start case → Task 2; manual studio → Tasks 6–8. ✅
- §6 out of scope (footage, multi-select, snapping) → none added. ✅

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to". The one soft spot is the `AGENT_TOWN_STUDIO` fixture path in Task 6 Step 12 — flagged inline to use whatever seeded SRT+frames the earlier phases used, since the exact fixture dir isn't in the spec.

**Type consistency:** `clamp_span` (trim, returns `[start,end]`) vs `move_span` (move, returns `[start,end]`) used consistently in Task 3 `motion`. `cue_split(i, at)`/`cue_deleted(i)`/`cue_time_changed(i,start,end)`/`edit_committed()`/`seek(t)`/`title_time_changed(start)` names match between TimelineView (Tasks 3–4) and the studio handlers (Tasks 6–7). `sel_kind`/`sel_cue` names consistent. `style_dict` keys `title_start`/`title_end` match `write_ass`'s `style.get("title_start"/"title_end")` in Task 2.
