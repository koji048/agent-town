# Caption Timing Editor — Implementation Plan (Phase 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let the owner fix a subtitle's timing in the studio — type exact start/end seconds AND drag the cue's edges/body on the timeline — written to the `.srt`.

**Architecture:** A shared `_set_cue_time(i, ns, ne)` primitive clamps against neighbors + a min duration; both numeric SpinBox fields (Task 1) and timeline drag (Task 2) call it. `_commit_cues()` writes the SRT once per edit (on field-change / drag-release).

**Tech Stack:** Godot 4 (installed 4.7; CI 4.6.1), GDScript.

## Global Constraints

- `cues` is `[{start, end, text}]` floats (seconds); `_sel` is the selected index; `_srt_path` is the target; `PreviewMaker.write_srt(cues, _srt_path)` persists.
- `const MIN_DUR := 0.2` (seconds) minimum cue length; edits never let cues overlap or cross neighbors.
- Drag updates redraw + sync fields live but write the SRT only on release (avoid disk churn).
- In a `-s` test script reference autoloads via `root.get_node("/root/Name")`.

## File Structure

- **`scripts/caption_studio.gd`** (modify) — `_set_cue_time`, `_commit_cues`, spin fields + `_sync_time_fields` (Task 1); timeline drag modes + taller blocks (Task 2).
- **`tools/test_cue_retime.gd`** (new) — headless test of `_set_cue_time` clamping (Task 1).

---

### Task 1: Retime primitive + numeric start/end fields

**Files:**
- Modify: `scripts/caption_studio.gd`
- Test: `tools/test_cue_retime.gd` (new)

**Interfaces:**
- Produces: `_set_cue_time(i: int, ns: float, ne: float)` clamps + mutates `cues[i]`; `_commit_cues()` writes SRT + refreshes; `_sync_time_fields()` sets the spins from `cues[_sel]` under a guard.

- [ ] **Step 1: Write the failing test**

Create `tools/test_cue_retime.gd`:

```gdscript
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

	print("\n=== cue retime tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
```

- [ ] **Step 2: Run — expect failure (method missing)**

Run: `godot --headless --path . -s res://tools/test_cue_retime.gd`
Expected: it hangs or errors on `_set_cue_time` (nonexistent). If it hangs, Ctrl-equivalent: the harness kills it; that's RED.

- [ ] **Step 3: Add constants + the retime primitive + commit helper**

In `scripts/caption_studio.gd`, add near the other consts:
```gdscript
const MIN_DUR := 0.2   # shortest allowed cue, seconds
```
Add these methods (near `_save_cue`):
```gdscript
## Clamp a cue's new start/end against its neighbors and MIN_DUR, then set it.
func _set_cue_time(i: int, ns: float, ne: float) -> void:
	if i < 0 or i >= cues.size():
		return
	var lo := 0.0 if i == 0 else float(cues[i - 1]["end"])
	var hi := _duration if i == cues.size() - 1 else float(cues[i + 1]["start"])
	ne = clampf(ne, lo + MIN_DUR, hi)
	ns = clampf(ns, lo, ne - MIN_DUR)
	cues[i]["start"] = ns
	cues[i]["end"] = ne


## Persist edited cues to the .srt and refresh the list, fields and timeline.
func _commit_cues() -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_rebuild_cue_list()
	_sync_time_fields()
	_show_time()
	_timeline.queue_redraw()
```

- [ ] **Step 4: Run — expect all pass**

Run: `godot --headless --path . -s res://tools/test_cue_retime.gd`
Expected: `=== cue retime tests: 5 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Add the numeric start/end fields**

Add state near the other vars:
```gdscript
var _start_spin: SpinBox
var _end_spin: SpinBox
var _syncing := false
```
In `_ready`, after `_cue_edit` is added (the `right.add_child(_cue_edit)` line), insert a row of two spin boxes:
```gdscript
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	var tl := Label.new()
	tl.text = "⏱"
	trow.add_child(tl)
	_start_spin = SpinBox.new()
	_start_spin.step = 0.05
	_start_spin.min_value = 0.0
	_start_spin.max_value = 99999.0
	_start_spin.suffix = "s"
	_start_spin.custom_minimum_size = Vector2(96, 0)
	_start_spin.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_apply_time_fields())
	trow.add_child(_start_spin)
	var arrow := Label.new()
	arrow.text = "→"
	trow.add_child(arrow)
	_end_spin = SpinBox.new()
	_end_spin.step = 0.05
	_end_spin.min_value = 0.0
	_end_spin.max_value = 99999.0
	_end_spin.suffix = "s"
	_end_spin.custom_minimum_size = Vector2(96, 0)
	_end_spin.value_changed.connect(func(_v: float) -> void:
		if not _syncing:
			_apply_time_fields())
	trow.add_child(_end_spin)
	right.add_child(trow)
```
Add the two handler methods (near `_set_cue_time`):
```gdscript
## Push the spin values into the selected cue (with clamping), then persist.
func _apply_time_fields() -> void:
	if _sel < 0 or _sel >= cues.size():
		return
	_set_cue_time(_sel, _start_spin.value, _end_spin.value)
	_commit_cues()


## Reflect the selected cue's start/end into the spins without re-triggering.
func _sync_time_fields() -> void:
	if not _start_spin or _sel < 0 or _sel >= cues.size():
		return
	_syncing = true
	_start_spin.value = float(cues[_sel]["start"])
	_end_spin.value = float(cues[_sel]["end"])
	_syncing = false
```

- [ ] **Step 6: Sync the fields when a cue is selected**

In `_rebuild_cue_list`, the per-cue button handler currently sets `_sel` and loads the text. Add a `_sync_time_fields()` call. Change:
```gdscript
		b.pressed.connect(func() -> void:
			_sel = i
			_cue_edit.text = str(cues[i]["text"])
			_seek(float(cues[i]["start"]))
			_rebuild_cue_list())
```
to:
```gdscript
		b.pressed.connect(func() -> void:
			_sel = i
			_cue_edit.text = str(cues[i]["text"])
			_sync_time_fields()
			_seek(float(cues[i]["start"]))
			_rebuild_cue_list())
```

- [ ] **Step 7: Verify compile + test, then commit**

```bash
godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -1     # all checks passed
godot --headless --path . -s res://tools/test_cue_retime.gd             # 5 passed
git add scripts/caption_studio.gd tools/test_cue_retime.gd
git commit -m "feat(studio): type exact cue start/end seconds (retime primitive + fields)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Drag cue edges/body on the timeline

**Files:**
- Modify: `scripts/caption_studio.gd` (`_draw_timeline`, `_timeline_input`, drag state)

**Interfaces:**
- Consumes: `_set_cue_time`, `_commit_cues`, `_sync_time_fields` (Task 1).

- [ ] **Step 1: Add drag state + constants**

Add near the consts:
```gdscript
const EDGE_PX := 7.0   # grab tolerance for a cue's start/end edge, in px
```
Add state vars:
```gdscript
var _drag_mode := ""    # "" | "seek" | "start" | "end" | "move"
var _drag_cue := -1
var _drag_grab := 0.0   # for "move": grab offset within the cue, seconds
```

- [ ] **Step 2: Draw taller cue blocks + selected-edge handles**

Replace the cue-block loop in `_draw_timeline` (the block that draws each cue at `y = size_v.y - 14`):
```gdscript
	# cue blocks along the bottom
	for i in cues.size():
		var c: Dictionary = cues[i]
		var x0: float = float(c["start"]) / _duration * size_v.x
		var x1: float = float(c["end"]) / _duration * size_v.x
		var col := Color(1.0, 0.78, 0.32, 0.85) if i == _sel else Color(0.55, 0.75, 1.0, 0.6)
		_timeline.draw_rect(Rect2(x0, size_v.y - 14, maxf(x1 - x0 - 1.0, 2.0), 11), col)
```
with (taller 22px band, plus bright edge handles on the selected cue):
```gdscript
	# cue blocks (draggable) along the bottom; taller so edges are grabbable
	var band_h := 22.0
	var by := size_v.y - band_h
	for i in cues.size():
		var c: Dictionary = cues[i]
		var x0: float = float(c["start"]) / _duration * size_v.x
		var x1: float = float(c["end"]) / _duration * size_v.x
		var col := Color(1.0, 0.78, 0.32, 0.85) if i == _sel else Color(0.55, 0.75, 1.0, 0.55)
		_timeline.draw_rect(Rect2(x0, by, maxf(x1 - x0 - 1.0, 2.0), band_h), col)
		if i == _sel:
			var hc := Color(1.0, 0.95, 0.6, 0.95)
			_timeline.draw_rect(Rect2(x0, by, 3.0, band_h), hc)
			_timeline.draw_rect(Rect2(x1 - 3.0, by, 3.0, band_h), hc)
```

- [ ] **Step 3: Replace `_timeline_input` with drag modes**

Replace the whole `_timeline_input` function:
```gdscript
func _timeline_input(ev: InputEvent) -> void:
	var w := _timeline.size.x
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_begin_timeline_drag(mb.position.x, w)
		else:
			if _drag_mode in ["start", "end", "move"]:
				_commit_cues()
			_drag_mode = ""
			_drag_cue = -1
	elif ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_update_timeline_drag((ev as InputEventMouseMotion).position.x, w)


## Decide what the press grabbed: a cue edge, a cue body, or empty (seek).
func _begin_timeline_drag(px: float, w: float) -> void:
	var t := px / w * _duration
	for i in cues.size():
		var x0: float = float(cues[i]["start"]) / _duration * w
		var x1: float = float(cues[i]["end"]) / _duration * w
		if absf(px - x0) <= EDGE_PX:
			_drag_mode = "start"
		elif absf(px - x1) <= EDGE_PX:
			_drag_mode = "end"
		elif px > x0 and px < x1:
			_drag_mode = "move"
			_drag_grab = t - float(cues[i]["start"])
		else:
			continue
		_drag_cue = i
		_sel = i
		_cue_edit.text = str(cues[i]["text"])
		_sync_time_fields()
		_timeline.queue_redraw()
		return
	_drag_mode = "seek"
	_seek(t)


## Apply the in-progress drag (redraw + field sync live; SRT written on release).
func _update_timeline_drag(px: float, w: float) -> void:
	var t := px / w * _duration
	if _drag_mode == "seek":
		_seek(t)
		return
	if _drag_cue < 0 or _drag_cue >= cues.size():
		return
	var c: Dictionary = cues[_drag_cue]
	match _drag_mode:
		"start":
			_set_cue_time(_drag_cue, t, float(c["end"]))
		"end":
			_set_cue_time(_drag_cue, float(c["start"]), t)
		"move":
			var dur := float(c["end"]) - float(c["start"])
			var ns := t - _drag_grab
			_set_cue_time(_drag_cue, ns, ns + dur)
	_sync_time_fields()
	_timeline.queue_redraw()
```

- [ ] **Step 4: Verify compile + retime test still green**

```bash
godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -1     # all checks passed
godot --headless --path . -s res://tools/test_cue_retime.gd             # 5 passed
```

- [ ] **Step 5: Verify in the running studio**

```bash
printf '1\n00:00:00,000 --> 00:00:02,000\nfirst line\n\n2\n00:00:02,500 --> 00:00:04,500\nsecond line\n\n3\n00:00:05,000 --> 00:00:07,000\nthird\n' > /tmp/at_p3.srt
mkdir -p /tmp/at_p3_frames
AGENT_TOWN_STUDIO="/tmp/at_p3.srt|/tmp/at_p3_frames" /Applications/Godot.app/Contents/MacOS/Godot --path . >/tmp/at_p3.log 2>&1 &
```
Confirm: selecting a cue shows its start/end in the ⏱ fields; typing new seconds moves it (and the `.srt` updates); dragging a cue block's left/right edge or its body on the timeline retimes it, clamped to neighbors, written on release. Quit with Cmd+Q.

- [ ] **Step 6: Commit**

```bash
git add scripts/caption_studio.gd
git commit -m "feat(studio): drag cue edges/body on the timeline to retime (CapCut-style)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **Feedback-loop guard:** `_sync_time_fields` sets `_syncing=true` while writing the spins so the `value_changed` handler no-ops; without it, syncing the fields during a drag would recursively re-apply.
- **Write on release, not per frame:** motion updates only `queue_redraw` + `_sync_time_fields`; `_commit_cues` (the SRT write) runs once on mouse-up (and on field edits).
- **Selection unifies:** clicking a cue block on the timeline selects it (same `_sel` the cue list uses), so the fields, `_cue_edit`, and highlight all track one selection.
