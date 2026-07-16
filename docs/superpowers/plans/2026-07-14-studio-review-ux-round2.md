# Caption Studio review UX — round 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five review-UX refinements to the multi-track Caption Studio: adjustable EP-title duration, multi-line EP title, an optional read-only subtitle list, Select-All + move-the-whole-stack, and a visible cut/delete toolbar.

**Architecture:** Extend the existing `TimelineView` (`scripts/timeline_view.gd`) with a `title_dur` + title edge-resize, a pure `shift_all_delta` static + a `sel_kind == "all"` group-drag, and richer `_draw`. `caption_studio.gd` wires these to the studio: a `TextEdit` title editor, `_title_dur`, an optional read-only cue-list panel, and a cut/delete/select-all toolbar. `preview_maker.gd` stops flattening the burned title's newlines. Pure geometry/shift math stays static so it is unit-testable headless; UI is verified by parse (`ci_check`) + existing suites + manual studio.

**Tech Stack:** Godot 4 / GDScript. Headless SceneTree tests run via `godot --headless --path . --quit-after 600 -s res://tools/<script>.gd` (or `tools/run_test.sh <script>`).

## Global Constraints

- Godot engine floor **4.6.1**; use no API newer than 4.6.
- Headless runs MUST pass `--quit-after 600` (an unbounded `-s` run once leaked to 150GB / OOM). Test output baseline: ~58 pre-existing `ERROR:` lines about missing `.fontdata`/`.sample` caches are environment noise — judge by the `=== N passed, N failed ===` line and (for parse) the absence of `SCRIPT ERROR`.
- Constants: `MIN_DUR = 0.2`, `EDGE_PX = 7.0`, `TITLE_SEC = 2.5` (existing). New: `MIN_TITLE_DUR = 0.5` (shortest EP-title duration).
- Cue dict shape `{"start": float, "end": float, "text": String}`; cues stay sorted, never overlap.
- Burn backward-compat: with no `title_start`/`title_end`, the title still burns `0:00:00.00 → 0:00:02.50` at size 100.
- The title box is hit-testable / drawn / burned ONLY when `title_text` is non-empty (existing invariant — preserve it in every change).
- Commit after each task; end messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: `shift_all_delta` static (group-shift math) + tests

**Files:**
- Modify: `scripts/timeline_view.gd` (add one static)
- Test: `tools/test_timeline_view.gd` (add a block)

**Interfaces:**
- Produces: `TimelineView.shift_all_delta(cues: Array, title_start: float, title_dur: float, delta: float, duration: float, has_title: bool) -> float` — returns the requested `delta` clamped so that shifting every cue AND (if `has_title`) the title by it keeps the whole block within `[0, duration]`. `0.0` when there is nothing to shift.

- [ ] **Step 1: Write the failing test**

In `tools/test_timeline_view.gd`, add just before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: FAIL — `shift_all_delta` not defined.

- [ ] **Step 3: Implement**

In `scripts/timeline_view.gd`, add after `split_span` (with the other statics):

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 48 passed, 0 failed ===` (42 prior + 6 new), exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: TimelineView.shift_all_delta group-shift clamp\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 2: Multi-line EP title (editor `TextEdit` + burn `\N`)

**Files:**
- Modify: `scripts/caption_studio.gd` (the `_title_edit` construction block)
- Modify: `scripts/autoload/preview_maker.gd` (title `Dialogue` newline handling)
- Test: `tools/test_ass_title.gd` (add a `\n`→`\N` case)

**Interfaces:**
- Consumes: nothing new.
- Produces: the EP-title editor accepts newlines; the burned title `Dialogue` renders multi-line (`\N`).

- [ ] **Step 1: Write the failing burn test**

In `tools/test_ass_title.gd`, add after the existing title cases (before the "nothing → no title event" check):

```gdscript
	# multi-line title: newlines become ASS \N (not spaces)
	pm.write_ass(cues, {"title_text": "EP7 LINE1\nLINE2"}, p)
	t = FileAccess.get_file_as_string(p)
	_check("title newline -> \\N", t.contains(",Title,,0,0,0,,{\\pos(540,960)}EP7 LINE1\\NLINE2"))
	_check("title has no flattened space", not t.contains("EP7 LINE1 LINE2"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd`
Expected: FAIL on "title newline -> \N" (the code currently emits `.replace("\n", " ")`).

- [ ] **Step 3: Implement the burn change**

In `scripts/autoload/preview_maker.gd`, in the title `Dialogue` emission, change the text transform from space to ASS newline. Find:

```gdscript
			_fmt_ass(t_start), _fmt_ass(t_end), tx, ty, title_text.left(80).replace("\n", " ")])
```

Replace with:

```gdscript
			_fmt_ass(t_start), _fmt_ass(t_end), tx, ty, title_text.left(80).replace("\n", "\\N")])
```

- [ ] **Step 4: Implement the editor change**

In `scripts/caption_studio.gd`, replace the `_title_edit` construction (the `LineEdit` block) — find:

```gdscript
	_title_edit = LineEdit.new()
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.placeholder_text = "EP title text"
	_title_edit.text_changed.connect(func(t: String) -> void:
		_title_text = t
		if _title_label:
			_title_label.text = t
		if _timeline:
			_timeline.title_text = t
		_apply_title_style()
		_place_title()
		_show_time())
```

Replace with (a `TextEdit`; its `text_changed` signal has no argument, so read `.text`):

```gdscript
	_title_edit = TextEdit.new()
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.custom_minimum_size = Vector2(0, 48)
	_title_edit.placeholder_text = "EP title text"
	_title_edit.scroll_fit_content_height = true
	_title_edit.text_changed.connect(func() -> void:
		var t := _title_edit.text
		_title_text = t
		if _title_label:
			_title_label.text = t
		if _timeline:
			_timeline.title_text = t
		_apply_title_style()
		_place_title()
		_show_time())
```

(`_title_edit` is declared `var _title_edit: LineEdit` near the top — change that declaration to `var _title_edit: TextEdit`. `open_clip` sets `_title_edit.text = title`, which `TextEdit` also supports — leave it.)

- [ ] **Step 5: Run the burn test + parse check**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd`
Expected: `=== ass title tests: 8 passed, 0 failed ===`.

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR` (confirms the `TextEdit` field-type change parses).

- [ ] **Step 6: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/caption_studio.gd scripts/autoload/preview_maker.gd tools/test_ass_title.gd
git commit -m "$(printf 'feat: multi-line EP title (TextEdit editor + burn \\\\N)\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 3: Adjustable EP title duration (TimelineView resize + studio + burn end)

**Files:**
- Modify: `scripts/timeline_view.gd` (title_dur state, title edge-resize in `press`/`motion`, `title_time_changed(start, dur)`, `_draw` width, release set, `MIN_TITLE_DUR`)
- Modify: `scripts/caption_studio.gd` (`_title_dur`, feed `_timeline.title_dur`, `_on_title_time_changed(start, dur)`, `style_dict` `title_end`)
- Test: `tools/test_timeline_view.gd` (title resize via press/motion)

**Interfaces:**
- Consumes: existing `time_to_x`/`x_to_time`/`clampf`.
- Produces: `TimelineView.title_dur: float` (default `TITLE_SEC`); title box `[title_start, title_start+title_dur]`; signal `title_time_changed(start: float, dur: float)` (was `(start)`). Studio holds `_title_dur` and sends `title_end = _title_start + _title_dur`.

- [ ] **Step 1: Write the failing test**

In `tools/test_timeline_view.gd`, add before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: FAIL — `title_dur` / the 2-arg `title_time_changed` don't exist yet.

- [ ] **Step 3: TimelineView — add state, resize, draw**

In `scripts/timeline_view.gd`:

(a) After `const TITLE_SEC := 2.5` add:
```gdscript
const MIN_TITLE_DUR := 0.5
```
(b) After `var title_start := 0.0` add:
```gdscript
var title_dur := TITLE_SEC
```
(c) Change the signal `signal title_time_changed(start: float)` to:
```gdscript
signal title_time_changed(start: float, dur: float)
```
(d) In `press()`, replace the title-row branch body so it detects edges:
```gdscript
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
```
(e) In `motion()`, replace the `"title":` match arm with these three arms:
```gdscript
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
```
(f) In `release()`, extend the persist set to include the new modes:
```gdscript
	if _drag_mode in ["start", "end", "move", "title", "title_start", "title_end"]:
		edit_committed.emit()
```
(g) In `_draw()`, the title box uses `title_dur` and shows edge bars when selected. Replace the title-row draw block:
```gdscript
	# title row: one box start..start+title_dur
	if not title_text.is_empty():
		var ty := title_row_y()
		var tx0 := time_to_x(title_start, w, duration)
		var tx1 := time_to_x(title_start + title_dur, w, duration)
		var tcol := Color(1.0, 0.85, 0.35, 0.9) if sel_kind == "title" else Color(1.0, 0.85, 0.35, 0.55)
		draw_rect(Rect2(tx0, ty, maxf(tx1 - tx0, 3.0), ROW_H), tcol)
		draw_string(get_theme_default_font(), Vector2(tx0 + 4, ty + ROW_H - 6),
			"EP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.12))
		if sel_kind == "title":
			var thc := Color(1.0, 0.95, 0.6, 0.95)
			draw_rect(Rect2(tx0, ty, 3.0, ROW_H), thc)
			draw_rect(Rect2(tx1 - 3.0, ty, 3.0, ROW_H), thc)
```

- [ ] **Step 4: Studio — `_title_dur`, feed, handler, burn end**

In `scripts/caption_studio.gd`:

(a) After `var _title_start := 0.0    # ...` add:
```gdscript
var _title_dur := TITLE_SEC   # EP title window length, seconds; owner-resizable
```
(b) In `open_clip`, where it sets `_title_start = 0.0` and feeds the timeline, add the duration. After `_title_start = 0.0` add `_title_dur = TITLE_SEC`; and where it sets `_timeline.title_start = _title_start` add:
```gdscript
	_timeline.title_dur = _title_dur
```
(c) In `_show_time`, where it pushes `_timeline.title_start = _title_start`, add:
```gdscript
	_timeline.title_dur = _title_dur
```
(d) Replace `_on_title_time_changed` to accept the duration:
```gdscript
## Live drag/resize of the title box: reflect its new start + duration.
func _on_title_time_changed(start: float, dur: float) -> void:
	_title_start = start
	_title_dur = dur
	_show_time()
```
(e) In `style_dict()`, change `"title_end": _title_start + TITLE_SEC,` to:
```gdscript
		"title_end": _title_start + _title_dur,
```

- [ ] **Step 5: Run tests + parse**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 51 passed, 0 failed ===` (48 + 3 new).

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR` (studio handler now matches the 2-arg signal).

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_ass_title.gd`
Expected: `8 passed` (unchanged).

- [ ] **Step 6: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd scripts/caption_studio.gd
git commit -m "$(printf 'feat: adjustable EP title duration (title box edge-resize -> burn title_end)\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 4: Select All + move the whole stack

**Files:**
- Modify: `scripts/timeline_view.gd` (`select_all()`, `sel_kind == "all"` in `press`/`motion`, `_draw` all-highlight, release set)
- Test: `tools/test_timeline_view.gd` (select-all group drag)

**Interfaces:**
- Consumes: `shift_all_delta` (Task 1).
- Produces: `TimelineView.select_all()` sets `sel_kind = "all"`; a drag in that mode shifts all cues + the title uniformly (clamped). Studio persists via the existing `edit_committed` on release.

- [ ] **Step 1: Write the failing test**

In `tools/test_timeline_view.gd`, add before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: FAIL — `select_all` not defined.

- [ ] **Step 3: Implement**

In `scripts/timeline_view.gd`:

(a) Add the method (near `cut_at_playhead`/`delete_selected`):
```gdscript
## Select every caption + the title as one block (Select All).
func select_all() -> void:
	sel_kind = "all"
	sel_cue = -1
	queue_redraw()
```
(b) In `press()`, handle "all" mode at the TOP of the function, right after the ruler check (`if pos.y < RULER_H: ... return`):
```gdscript
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
```
(c) In `motion()`, add an arm to the `match _drag_mode` for `"all"`:
```gdscript
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
```
(d) In `release()`, add `"all"` to the persist set:
```gdscript
	if _drag_mode in ["start", "end", "move", "title", "title_start", "title_end", "all"]:
		edit_committed.emit()
```
(e) In `_draw()`, when `sel_kind == "all"` highlight every caption box + the title box. In the caption loop, change the per-box colour test and the edge-bar test from `sel_kind == "cue" and i == sel_cue` to also fire in "all" mode. Replace the caption `col`/highlight lines:
```gdscript
		var on := (sel_kind == "cue" and i == sel_cue) or sel_kind == "all"
		var col := Color(1.0, 0.78, 0.32, 0.9) if on else Color(0.55, 0.75, 1.0, 0.6)
		draw_rect(Rect2(x0, cy, maxf(x1 - x0 - 1.0, 2.0), ROW_H), col)
		if on:
			var hc := Color(1.0, 0.95, 0.6, 0.95)
			draw_rect(Rect2(x0, cy, 3.0, ROW_H), hc)
			draw_rect(Rect2(x1 - 3.0, cy, 3.0, ROW_H), hc)
```
And in the title draw block change `if sel_kind == "title":` (the edge-bar guard) to `if sel_kind == "title" or sel_kind == "all":` and the title `tcol` test to `sel_kind == "title" or sel_kind == "all"`.

- [ ] **Step 4: Run tests + parse**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: `=== timeline view tests: 56 passed, 0 failed ===` (51 + 5 new).

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: Select All + rigid group move (captions + title)\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 5: Optional read-only subtitle list (toggle)

**Files:**
- Modify: `scripts/caption_studio.gd` (list toggle + panel + rebuild + sync hooks)
- Verify: `tools/ci_check.gd` + manual studio

**Interfaces:**
- Consumes: existing `_on_cue_selected`, `_seek`, `cues`, `_sel`, `_mmss`-style formatting.
- Produces: a `📋 รายการซับ` toggle that shows/hides a scrolling read-only cue list; clicking a row selects+seeks that cue.

- [ ] **Step 1: Add fields**

In `scripts/caption_studio.gd`, near the other UI fields, add:
```gdscript
var _list_toggle: CheckButton
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
```

- [ ] **Step 2: Build the toggle + panel in `_ready`**

In `_ready`, in the right column (after the Inspector widgets, before the Burn `actions`), add:
```gdscript
	_list_toggle = CheckButton.new()
	_list_toggle.text = "📋 รายการซับ"
	_list_toggle.toggled.connect(func(on: bool) -> void:
		_list_scroll.visible = on
		if on:
			_rebuild_list_view())
	right.add_child(_list_toggle)
	_list_scroll = ScrollContainer.new()
	_list_scroll.visible = false
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.custom_minimum_size = Vector2(0, 240)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_box)
	right.add_child(_list_scroll)
```

- [ ] **Step 3: Add the rebuild + refresh helpers**

Add to `scripts/caption_studio.gd`:
```gdscript
## Read-only list of every cue; click a row to select + seek it. Rebuilt only
## while the panel is visible.
func _rebuild_list_view() -> void:
	if not _list_box:
		return
	for ch in _list_box.get_children():
		ch.queue_free()
	for i in cues.size():
		var c: Dictionary = cues[i]
		var b := Button.new()
		b.text = "%d:%04.1f  %s" % [int(float(c["start"])) / 60, fmod(float(c["start"]), 60.0), str(c["text"]).left(40)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		if i == _sel:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		var idx := i
		b.pressed.connect(func() -> void:
			_timeline.sel_kind = "cue"
			_timeline.sel_cue = idx
			_on_cue_selected(idx)
			_timeline.queue_redraw())
		_list_box.add_child(b)


## Rebuild the list only if it is currently shown.
func _refresh_list() -> void:
	if _list_scroll and _list_scroll.visible:
		_rebuild_list_view()
```

- [ ] **Step 4: Call `_refresh_list()` on the cue-changing events**

Add a `_refresh_list()` call at the end of each of: `open_clip`, `_on_cue_selected`, `_on_cue_split`, `_on_cue_deleted`, `_save_cue`, `_apply_time_fields`. (One line each — locate each `func` and append the call as its last statement.)

- [ ] **Step 5: Verify (parse + manual)**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`.

Manual: launch the studio (see Task 7's launch line). Toggle `📋 รายการซับ` on → the list appears; click a row → that caption selects (box highlights, Inspector loads) and the playhead seeks to it; the selected row is highlighted; edit/cut/delete a cue → the list updates. Toggle off → it hides.

- [ ] **Step 6: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/caption_studio.gd
git commit -m "$(printf 'feat: optional read-only subtitle list (toggle, click-to-jump)\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 6: Visible cut / delete / select-all toolbar

**Files:**
- Modify: `scripts/caption_studio.gd` (toolbar row)
- Verify: `tools/ci_check.gd` + manual studio

**Interfaces:**
- Consumes: `_timeline.cut_at_playhead()`, `_timeline.delete_selected()`, `_timeline.select_all()`.
- Produces: on-screen buttons for the timeline actions.

- [ ] **Step 1: Build the toolbar in `_ready`**

In `scripts/caption_studio.gd` `_ready`, immediately BEFORE the line that adds the timeline (`root.add_child(_timeline)`), insert a toolbar row:
```gdscript
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	var cut_btn := Button.new()
	cut_btn.text = "✂️ ตัด (S)"
	cut_btn.pressed.connect(func() -> void: _timeline.cut_at_playhead())
	tools.add_child(cut_btn)
	var del_btn := Button.new()
	del_btn.text = "🗑 ลบ (Del)"
	del_btn.pressed.connect(func() -> void: _timeline.delete_selected())
	tools.add_child(del_btn)
	var all_btn := Button.new()
	all_btn.text = "⬚ เลือกทั้งหมด"
	all_btn.pressed.connect(func() -> void: _timeline.select_all())
	tools.add_child(all_btn)
	var thint := Label.new()
	thint.text = "ตัด/ลบที่หัวอ่าน · เลือกทั้งหมดแล้วลากเพื่อเลื่อนทั้งชุด"
	thint.add_theme_font_size_override("font_size", 11)
	thint.modulate = Color(0.7, 0.7, 0.76)
	tools.add_child(thint)
	root.add_child(tools)
```

(Note: `cut_at_playhead` emits `cue_split` → `_on_cue_split` persists; `delete_selected` emits `cue_deleted` → `_on_cue_deleted` persists — so the buttons persist through the existing handlers with no extra wiring.)

- [ ] **Step 2: Verify (parse + manual)**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/ci_check.gd`
Expected: no `SCRIPT ERROR`.

Manual: launch the studio; select a caption + place the playhead inside it + click **✂️ ตัด** → it splits; click **🗑 ลบ** → it deletes; click **⬚ เลือกทั้งหมด** then drag on the timeline → the whole stack (captions + title) shifts together and stops at the walls.

- [ ] **Step 3: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/caption_studio.gd
git commit -m "$(printf 'feat: visible cut / delete / select-all toolbar\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Manual studio launch (for Tasks 5 & 6 verification)

The controller runs this (a subagent cannot drive the GUI). Fixture built earlier in the scratchpad:

```bash
cd /Users/thanakorn/agent-town-1
FIX=/private/tmp/claude-501/-Users-thanakorn-agent-town-1/6443bc08-7c4a-4d12-802d-fb35dd4d1e4b/scratchpad/studio_fix
AGENT_TOWN_STUDIO="$FIX/demo-clean.srt|$FIX/frames|EP07 : ตั้งกล้องถ่าย Reels" godot --path . scenes/main.tscn
# ...verify..., then kill the process (never leave an orphan — OOM risk).
```

---

## Self-Review

**Spec coverage:**
- §1 adjustable title duration → Task 3 (title_dur + edge-resize + burn title_end). ✅
- §2 multi-line title → Task 2 (TextEdit + burn `\N`). ✅
- §3 optional read-only list → Task 5. ✅
- §4 Select All + move stack → Task 1 (`shift_all_delta`) + Task 4 (select_all + group drag). ✅
- §5 cut/delete toolbar → Task 6. ✅

**Placeholder scan:** No TBD/vague steps; every code step shows the code. Manual steps (Tasks 5/6) name exact click sequences.

**Type consistency:** `title_time_changed(start, dur)` is changed in Task 3 (TimelineView emit) AND the studio handler `_on_title_time_changed(start, dur)` in the same task — no cross-task signature skew. `title_dur` introduced in Task 3 and consumed by Task 4's `shift_all_delta` call. `shift_all_delta(cues, title_start, title_dur, delta, duration, has_title)` signature identical in Task 1 (def), its test, and Task 4's call. `select_all()` defined in Task 4, consumed by Task 6. Test totals chain: 42 → 48 (T1) → 51 (T3) → 56 (T4); ass 6 → 8 (T2).
