# MT Phase 2 — Footage cut/delete/reorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Media lane editable — blade-cut footage, ripple-delete segments, drag-reorder — with captions rippling along (owner rule A), preview that plays across cuts, and a one-pass ffmpeg trim+concat burn, all over a non-destructive EDL persisted to `<srt>.edl.json`.

**Architecture:** `TimelineView` gains a `segments` EDL (`[{src_start, src_end}]`, output timeline = concatenation) with pure statics (`out_len`, `out_start`, `seg_at_out`, `out_to_src`, `cut_footage`, `delete_segment`, `reorder_segment`) so every rule is headless-testable; the Media row renders one box per segment and supports select/blade/delete/drag-swap. `caption_studio.gd` owns `_segments` + open-time snapshots (reset), maps output→source for frames and audio (boundary re-seek during playback), persists the EDL, and sends it in `style_dict`. `preview_maker.gd` grows a testable `build_burn_args` that switches to a `filter_complex` trim/atrim+concat when an EDL is present.

**Tech Stack:** Godot 4 / GDScript; headless SceneTree tests via `godot --headless --path . --quit-after 600 -s res://tools/<t>.gd` (or `tools/run_test.sh`).

## Global Constraints

- Godot floor **4.6.1**; no API newer than 4.6. Files use TABS.
- Headless runs MUST pass `--quit-after 600` (an unbounded run once leaked to 150GB/OOM). ~58 pre-existing `ERROR:` lines about `.fontdata`/`.sample` caches are environment noise — judge by the `=== N passed, N failed ===` line / absence of `SCRIPT ERROR`.
- Constants: `MIN_DUR = 0.2`, `MIN_TITLE_DUR = 0.5`, new **`MIN_SEG_DUR = 0.5`** (shortest footage segment). Cue dict `{"start","end","text"}` in OUTPUT time, sorted, never overlapping. Segment dict `{"src_start": float, "src_end": float}`.
- The EP title is OUTPUT-anchored: no EDL operation moves it (only re-clamped into `[0, out_len]` by existing drag clamps).
- Burn output flags stay EXACTLY: libx264 crf20 medium, yuv420p, +faststart, aac 192k **48kHz stereo**, `aresample=async=1:first_pts=0`, 30fps.
- A TRIVIAL edit (one segment covering the whole source) must burn through the existing plain `-vf` path unchanged.
- **Match all edits by CODE CONTENT, not line numbers.** Current test totals: `test_timeline_view` 58, `test_ass_title` 8. Expected chain: T1→73, T2→88, T3→93, T4→96.
- Commit after each task; end messages with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: EDL mapping + cut statics

**Files:**
- Modify: `scripts/timeline_view.gd` (constants + 5 statics)
- Test: `tools/test_timeline_view.gd`

**Interfaces:**
- Produces (statics used by every later task):
  - `TimelineView.out_len(segments: Array) -> float` — Σ segment lengths (0.0 for empty).
  - `TimelineView.out_start(segments: Array, i: int) -> float` — output start of segment `i` (prefix sum).
  - `TimelineView.seg_at_out(segments: Array, t: float) -> int` — segment containing output time `t`; a seam belongs to the RIGHT segment; −1 outside `[0, out_len)`.
  - `TimelineView.out_to_src(segments: Array, t: float) -> float` — output→source position; clamps to the last segment's `src_end` past the end; returns `t` unchanged for an empty list.
  - `TimelineView.cut_footage(segments: Array, at_out: float) -> bool` — split the segment under `at_out` into two at the mapped source position; `false` (no mutation) when outside any segment or either half `< MIN_SEG_DUR`.

- [ ] **Step 1: Write the failing tests**

In `tools/test_timeline_view.gd`, add just before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify FAIL**

Run: `cd /Users/thanakorn/agent-town-1 && godot --headless --path . --quit-after 600 -s res://tools/test_timeline_view.gd`
Expected: SCRIPT ERROR / FAILs — `out_len` etc. not defined.

- [ ] **Step 3: Implement**

In `scripts/timeline_view.gd`: after `const MIN_TITLE_DUR := 0.5` add:

```gdscript
const MIN_SEG_DUR := 0.5
```

After `shift_all_delta` (end of the statics block) add:

```gdscript
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
	# seam times fall through to the NEXT iteration via strict <, so a t
	# exactly at a boundary lands in the right-hand segment above
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
```

⚠ NOTE on `seg_at_out`: the comment line inside the loop above is illustrative — implement the loop correctly with `acc += l` INSIDE the for body after the `if` (standard prefix walk):

```gdscript
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
```
Use THIS version verbatim.

- [ ] **Step 4: Run to verify PASS**

Expected: `=== timeline view tests: 73 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/thanakorn/agent-town-1
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: EDL statics — output/source mapping + footage blade\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 2: delete_segment + reorder_segment (caption ripple)

**Files:**
- Modify: `scripts/timeline_view.gd` (2 statics)
- Test: `tools/test_timeline_view.gd`

**Interfaces:**
- Produces:
  - `TimelineView.delete_segment(segments: Array, cues: Array, i: int) -> bool` — remove segment `i` (never the last one), rippling `cues` (all in OUTPUT time, mutated in place): cues fully inside the removed output range are dropped; a cue straddling INTO it is tail-trimmed to the range start; one straddling OUT is head-trimmed then shifted; one spanning the whole range shrinks by its length; everything after shifts left. Trimmed cues shorter than `MIN_DUR` are dropped.
  - `TimelineView.reorder_segment(segments: Array, cues: Array, from_i: int, to_i: int) -> bool` — move a segment; each cue is assigned to the segment containing its MIDPOINT, trimmed to that segment's old output range (drop `< MIN_DUR` leftovers), shifted by its segment's block offset; result re-sorted by start. `false` on same/invalid indices.

- [ ] **Step 1: Write the failing tests**

Add before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify FAIL** (functions missing).

- [ ] **Step 3: Implement**

Append after `cut_footage` in `scripts/timeline_view.gd`:

```gdscript
## Ripple-delete segment i (never the last). Cues are OUTPUT-time and mutate
## in place: inside the removed range -> dropped; straddling in -> tail-trim;
## straddling out -> head-trim + ripple; spanning -> shrink; after -> shift.
## Trims shorter than MIN_DUR are dropped.
static func delete_segment(segments: Array, cues: Array, i: int) -> bool:
	if segments.size() <= 1 or i < 0 or i >= segments.size():
		return false
	var o0 := out_start(segments, i)
	var seg_l := float(segments[i]["src_end"]) - float(segments[i]["src_start"])
	var o1 := o0 + seg_l
	segments.remove_at(i)
	var kept: Array = []
	for c in cues:
		var s := float(c["start"])
		var e := float(c["end"])
		if s >= o0 and e <= o1:
			continue
		if s < o0 and e > o0 and e <= o1:
			e = o0
		elif s >= o0 and s < o1 and e > o1:
			s = o1 - seg_l
			e = e - seg_l
		elif s < o0 and e > o1:
			e = e - seg_l
		elif s >= o1:
			s = s - seg_l
			e = e - seg_l
		if e - s < MIN_DUR:
			continue
		c["start"] = s
		c["end"] = e
		kept.append(c)
	cues.clear()
	for c in kept:
		cues.append(c)
	return true


## Move segment from_i to to_i. Each cue is assigned to the segment holding
## its midpoint, trimmed to that segment's old output range (drop < MIN_DUR),
## and shifted by its segment's block offset; result re-sorted.
static func reorder_segment(segments: Array, cues: Array, from_i: int, to_i: int) -> bool:
	var n := segments.size()
	if from_i == to_i or from_i < 0 or from_i >= n or to_i < 0 or to_i >= n:
		return false
	var old_start: Array = []
	var old_len: Array = []
	for k in n:
		old_start.append(out_start(segments, k))
		old_len.append(float(segments[k]["src_end"]) - float(segments[k]["src_start"]))
	var assign: Array = []
	for c in cues:
		assign.append(seg_at_out(segments, (float(c["start"]) + float(c["end"])) * 0.5))
	var moved = segments[from_i]
	segments.remove_at(from_i)
	segments.insert(to_i, moved)
	# old index k -> new index after the move
	var new_index: Array = []
	for k in n:
		if k == from_i:
			new_index.append(to_i)
		elif from_i < to_i and k > from_i and k <= to_i:
			new_index.append(k - 1)
		elif to_i < from_i and k >= to_i and k < from_i:
			new_index.append(k + 1)
		else:
			new_index.append(k)
	var kept: Array = []
	for ci in cues.size():
		var k: int = assign[ci]
		if k < 0:
			continue
		var c = cues[ci]
		var s := maxf(float(c["start"]), float(old_start[k]))
		var e := minf(float(c["end"]), float(old_start[k]) + float(old_len[k]))
		if e - s < MIN_DUR:
			continue
		var d := out_start(segments, int(new_index[k])) - float(old_start[k])
		c["start"] = s + d
		c["end"] = e + d
		kept.append(c)
	kept.sort_custom(func(a, b): return float(a["start"]) < float(b["start"]))
	cues.clear()
	for c in kept:
		cues.append(c)
	return true
```

- [ ] **Step 4: Run to verify PASS**

Expected: `=== timeline view tests: 88 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: EDL delete/reorder with caption ripple (owner rule A)\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 3: Media lane UI — segment boxes, select, blade/delete routing

**Files:**
- Modify: `scripts/timeline_view.gd`
- Test: `tools/test_timeline_view.gd`

**Interfaces:**
- Produces (instance):
  - State: `segments: Array` (empty = legacy full-strip mode), `src_duration: float` (source length, for thumbnail/wave mapping), `sel_seg: int`; `sel_kind` gains `"segment"`.
  - Signals: `segment_selected(i: int)`, `segments_changed()`.
  - `press()` on the Media row with non-empty `segments`: selects the segment under the pointer (`sel_kind="segment"`, emits `segment_selected` + `seek`), arms `_drag_mode = "segment_move"`.
  - `cut_at_playhead()` / `delete_selected()`: when `sel_kind == "segment"` route to `cut_footage` / `delete_segment` and emit `segments_changed` (+ `selection_cleared` after delete); otherwise the caption paths are byte-identical to today.
  - `_draw`: one box per segment (thumbnails + waveform mapped through the segment's source range), seam lines between boxes, selection highlight. Empty `segments` draws the legacy full strip (keeps all 58 old checks green).

- [ ] **Step 1: Write the failing tests**

Add before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify FAIL** (`src_duration`/`segments`/signals missing).

- [ ] **Step 3: Implement**

(a) State, after `var title_dur := TITLE_SEC`:
```gdscript
var segments: Array = []        # EDL: [{src_start, src_end}]; empty = no edit UI
var src_duration := 1.0         # source length (thumbnail/waveform mapping)
var sel_seg := -1
```
Update the `sel_kind` comment to `# "none" | "cue" | "title" | "segment"` and `_drag_mode` comment to include `"segment_move"`.

(b) Signals, after `signal cue_deleted(i: int)`:
```gdscript
signal segment_selected(i: int)
signal segments_changed()
```

(c) In `press()`, immediately BEFORE the final empty-space fallback block (the one starting `# empty space / media lane -> clear selection and seek`):
```gdscript
	if pos.y >= media_row_y() and not segments.is_empty():
		var mt := x_to_time(pos.x, w, duration)
		var si := seg_at_out(segments, mt)
		if si >= 0:
			sel_kind = "segment"
			sel_seg = si
			sel_cue = -1
			_drag_mode = "segment_move"
			_drag_grab = mt
			segment_selected.emit(si)
			seek.emit(mt)
			queue_redraw()
			return
```

(d) In `cut_at_playhead()`, insert at the very top (before the under-playhead caption search):
```gdscript
	if sel_kind == "segment":
		if cut_footage(segments, playhead):
			segments_changed.emit()
			queue_redraw()
		return
```

(e) In `delete_selected()`, insert at the very top:
```gdscript
	if sel_kind == "segment":
		if delete_segment(segments, cues, sel_seg):
			sel_kind = "none"
			sel_seg = -1
			_drag_mode = ""
			segments_changed.emit()
			selection_cleared.emit()
		queue_redraw()
		return
```

(f) In `_draw()`, replace the media-row block (from `# media row: filmstrip thumbnails (if any) + waveform` through the waveform loop, KEEPING the playhead lines after it) with:
```gdscript
	# media row: EDL segment boxes (thumbnails + waveform mapped through each
	# segment's source range, seams between); legacy full strip when no EDL
	var my := media_row_y()
	var mh := maxf(sz.y - my, 8.0)
	if segments.is_empty():
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
	else:
		var mo := 0.0
		for si in segments.size():
			var s0 := float(segments[si]["src_start"])
			var s1 := float(segments[si]["src_end"])
			var sl := s1 - s0
			var bx0 := time_to_x(mo, w, duration)
			var bx1 := time_to_x(mo + sl, w, duration)
			if not frames.is_empty() and src_duration > 0.0:
				var cols := maxi(1, int((bx1 - bx0) / 36.0))
				var cw := (bx1 - bx0) / cols
				for cidx in cols:
					var fsrc := s0 + (cidx + 0.5) / float(cols) * sl
					var fi := clampi(int(fsrc / src_duration * frames.size()), 0, frames.size() - 1)
					var tex := frames[fi] as Texture2D
					if tex:
						draw_texture_rect(tex, Rect2(bx0 + cidx * cw, my, cw, mh), false)
			if not wave.is_empty() and src_duration > 0.0:
				var mid := my + mh * 0.5
				var nb := wave.size()
				var px0 := int(maxf(bx0, 0.0))
				var px1 := int(minf(bx1, w))
				for x in range(px0, px1):
					var fsrc := s0 + (x - bx0) / maxf(bx1 - bx0, 1.0) * sl
					var bi := clampi(int(fsrc / src_duration * nb), 0, nb - 1)
					var h := wave[bi] * (mh * 0.48)
					draw_line(Vector2(x, mid - h), Vector2(x, mid + h), Color(0.35, 0.45, 0.55, 0.9), 1.0)
			if si > 0:
				draw_rect(Rect2(bx0 - 1.0, my, 2.0, mh), Color(0.95, 0.85, 0.4, 0.9))
			if sel_kind == "segment" and si == sel_seg:
				var sc := Color(1.0, 0.78, 0.32, 0.95)
				draw_rect(Rect2(bx0, my, maxf(bx1 - bx0, 2.0), 2.0), sc)
				draw_rect(Rect2(bx0, my + mh - 2.0, maxf(bx1 - bx0, 2.0), 2.0), sc)
				draw_rect(Rect2(bx0, my, 3.0, mh), sc)
				draw_rect(Rect2(bx1 - 3.0, my, 3.0, mh), sc)
			mo += sl
```

- [ ] **Step 4: Run to verify PASS + no regressions**

Expected: `=== timeline view tests: 93 passed, 0 failed ===`; ci_check no SCRIPT ERROR.

- [ ] **Step 5: Commit**

```bash
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: Media lane segment boxes — select + blade/delete routing\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 4: Segment drag-reorder

**Files:**
- Modify: `scripts/timeline_view.gd` (motion arm + release)
- Test: `tools/test_timeline_view.gd`

**Interfaces:**
- Produces: dragging a selected segment box horizontally swaps it with the adjacent neighbour when the pointer enters that neighbour's range (`reorder_segment`, adjacent-only per motion tick — repeated ticks walk further); each swap emits `segments_changed`; `release()` also emits `edit_committed` for `"segment_move"`.

- [ ] **Step 1: Write the failing tests**

Add before the final `print(...)`:

```gdscript
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
```

- [ ] **Step 2: Run to verify FAIL** (segments don't swap — no motion arm yet).

- [ ] **Step 3: Implement**

(a) In `motion()`, add a `match` arm (alongside the existing ones):
```gdscript
		"segment_move":
			if sel_seg < 0 or sel_seg >= segments.size():
				return
			var over := seg_at_out(segments, t)
			if over >= 0 and over != sel_seg and absi(over - sel_seg) == 1:
				if reorder_segment(segments, cues, sel_seg, over):
					sel_seg = over
					segments_changed.emit()
					queue_redraw()
```
(b) In `release()`, extend the persist list to include `"segment_move"`:
```gdscript
	if _drag_mode in ["start", "end", "move", "title", "title_start", "title_end", "all", "segment_move"]:
		edit_committed.emit()
```

- [ ] **Step 4: Run to verify PASS**

Expected: `=== timeline view tests: 96 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```bash
git add scripts/timeline_view.gd tools/test_timeline_view.gd
git commit -m "$(printf 'feat: drag a segment box to reorder footage (cues travel along)\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 5: Studio integration — EDL ownership, preview across cuts, reset, persistence

**Files:**
- Modify: `scripts/caption_studio.gd`
- Verify: ci_check + existing suites (no new unit tests — GUI); manual deferred to controller

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces:
  - State: `_segments: Array`, `_segments_snapshot: Array`, `_cues_snapshot: Array`, `_play_seg: int`, `_seg_row: HBoxContainer`, `_seg_info: Label`.
  - `_out_dur() -> float`; `_edl_path() -> String` (= `_srt_path + ".edl.json"`); `_save_edl()` / `_load_edl() -> Array`; `_reset_edit()`.
  - Handlers `_on_segment_selected(i)`, `_on_segments_changed()`; `_show_inspector` gains `"segment"`; toolbar gains `↺ เริ่มตัดใหม่`.
  - Playback: `_toggle_play`/`_seek`/`_process` map output↔source and hop segment boundaries.
  - `style_dict()` gains `"edl"` (list of `[src_start, src_end]`, EMPTY when the edit is trivial).

- [ ] **Step 1: State fields**

Near the other state vars (after `var _title_dur := TITLE_SEC`):
```gdscript
var _segments: Array = []          # EDL: [{src_start, src_end}] in source seconds
var _segments_snapshot: Array = []
var _cues_snapshot: Array = []     # cues as opened (for ↺ reset)
var _play_seg := 0                 # segment currently playing (audio hop)
var _seg_row: HBoxContainer
var _seg_info: Label
```

- [ ] **Step 2: Helpers**

Add near `_show_time`:
```gdscript
## Output duration of the current edit (falls back to the source length).
func _out_dur() -> float:
	return TimelineView.out_len(_segments) if not _segments.is_empty() else _duration


func _edl_path() -> String:
	return _srt_path + ".edl.json"


func _save_edl() -> void:
	var arr: Array = []
	for sg in _segments:
		arr.append([float(sg["src_start"]), float(sg["src_end"])])
	var f := FileAccess.open(_edl_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"segments": arr}))


## Load a saved EDL; [] when absent or invalid (caller falls back to full clip).
func _load_edl() -> Array:
	if not FileAccess.file_exists(_edl_path()):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_edl_path()))
	if not (data is Dictionary) or not data.has("segments"):
		return []
	var out: Array = []
	for pair in data["segments"]:
		if not (pair is Array) or pair.size() != 2:
			return []
		var s := float(pair[0])
		var e := float(pair[1])
		if s < 0.0 or e <= s or e > _duration + 0.5:
			return []
		out.append({"src_start": s, "src_end": e})
	return out


## ↺ back to the state the clip was opened with (EDL + cues).
func _reset_edit() -> void:
	_segments = _segments_snapshot.duplicate(true)
	cues = []
	for c in _cues_snapshot:
		cues.append(c.duplicate())
	_timeline.cues = cues
	_timeline.segments = _segments
	_timeline.sel_kind = "none"
	_timeline.sel_cue = -1
	_timeline.sel_seg = -1
	_sel = -1
	PreviewMaker.write_srt(cues, _srt_path)
	_save_edl()
	_on_segments_changed_shared()
	_show_inspector("none")
	EventBus.log_line.emit("↺ กลับสภาพตอนเปิดคลิป (ตัดต่อ + ซับ)")
```

- [ ] **Step 3: open_clip wiring**

In `open_clip`, right after `_duration` is final (after the wav-duration line) add:
```gdscript
	_segments = _load_edl()
	if _segments.is_empty():
		_segments = [{"src_start": 0.0, "src_end": _duration}]
	_segments_snapshot = _segments.duplicate(true)
	_cues_snapshot = []
	for c in cues:
		_cues_snapshot.append(c.duplicate())
	_play_seg = 0
```
Where the timeline is fed (`_timeline.cues = cues` block), add:
```gdscript
	_timeline.segments = _segments
	_timeline.src_duration = _duration
	_timeline.duration = _out_dur()
```
(the existing `_timeline.duration = _duration` line is REPLACED by the `_out_dur()` one). Also update the spin ranges right below (`_start_spin.max_value = _duration` → `_out_dur()`, same for `_end_spin`).

- [ ] **Step 4: Timeline signal wiring**

In the `_timeline` construction block, add:
```gdscript
	_timeline.segment_selected.connect(_on_segment_selected)
	_timeline.segments_changed.connect(_on_segments_changed)
```
And the handlers (near `_on_cue_selected`):
```gdscript
## A footage segment was clicked: show its source range in the Inspector.
func _on_segment_selected(i: int) -> void:
	_sel = -1
	if i >= 0 and i < _segments.size():
		var sg: Dictionary = _segments[i]
		_seg_info.text = "ท่อน %d/%d · ต้นฉบับ %s – %s (%.1fs)" % [
			i + 1, _segments.size(), _mmss2(float(sg["src_start"])),
			_mmss2(float(sg["src_end"])),
			float(sg["src_end"]) - float(sg["src_start"])]
	_show_inspector("segment")


func _mmss2(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


## Footage edit happened (cut/delete/reorder): persist + re-derive durations.
func _on_segments_changed() -> void:
	PreviewMaker.write_srt(cues, _srt_path)
	_save_edl()
	_on_segments_changed_shared()


func _on_segments_changed_shared() -> void:
	_timeline.duration = _out_dur()
	if _start_spin:
		_start_spin.max_value = _out_dur()
		_end_spin.max_value = _out_dur()
	_t = clampf(_t, 0.0, _out_dur())
	_play_seg = maxi(TimelineView.seg_at_out(_segments, _t), 0)
	_show_time()
	_refresh_list()
```

- [ ] **Step 5: Inspector "segment" mode + reset button**

In `_ready`, right after the EP-Title strip block (`right.add_child(title_row)` / `_title_inspector.visible = false`), add:
```gdscript
	_seg_row = HBoxContainer.new()
	var sg_ic := Label.new()
	sg_ic.text = "🎞"
	_seg_row.add_child(sg_ic)
	_seg_info = Label.new()
	_seg_info.add_theme_font_size_override("font_size", 13)
	_seg_row.add_child(_seg_info)
	_seg_row.visible = false
	right.add_child(_seg_row)
```
In `_show_inspector`, add:
```gdscript
	if _seg_row:
		_seg_row.visible = kind == "segment"
```
In the toolbar block (after `all_btn`, before the hint label `thint`):
```gdscript
	var reset_btn := Button.new()
	reset_btn.text = "↺ เริ่มตัดใหม่"
	reset_btn.pressed.connect(func() -> void: _reset_edit())
	tools.add_child(reset_btn)
```

- [ ] **Step 6: Playback across cuts**

Replace `_toggle_play`'s play call (`_audio.play(_t)`) with:
```gdscript
		_play_seg = maxi(TimelineView.seg_at_out(_segments, _t), 0)
		_audio.play(TimelineView.out_to_src(_segments, _t))
```
Replace `_seek` with:
```gdscript
func _seek(t: float) -> void:
	_t = clampf(t, 0.0, _out_dur())
	_play_seg = maxi(TimelineView.seg_at_out(_segments, _t), 0)
	if _playing:
		_audio.play(TimelineView.out_to_src(_segments, _t))
	_show_time()
```
Replace the `_playing` branch of `_process` with:
```gdscript
	if _playing:
		var sp := _audio.get_playback_position()
		if _segments.is_empty():
			_t = sp
		else:
			_play_seg = clampi(_play_seg, 0, _segments.size() - 1)
			var seg: Dictionary = _segments[_play_seg]
			if sp >= float(seg["src_end"]) - 0.03:
				if _play_seg + 1 < _segments.size():
					_play_seg += 1
					seg = _segments[_play_seg]
					_audio.play(float(seg["src_start"]))
					sp = float(seg["src_start"])
				else:
					sp = float(seg["src_end"])
			_t = TimelineView.out_start(_segments, _play_seg) + maxf(sp - float(seg["src_start"]), 0.0)
		if _t >= _out_dur() - 0.05:
			_playing = false
			_audio.stop()
			_play_btn.text = "▶"
		_show_time()
```
And in `_show_time`, the frame lookup maps through the EDL — replace the `idx` line:
```gdscript
	var idx := clampi(int(TimelineView.out_to_src(_segments, _t) * PreviewMaker.FRAME_FPS) + 1, 1, maxi(_frame_total, 1))
```
and the duration label line:
```gdscript
	_time_label.text = "%.1f / %.1fs" % [_t, _out_dur()]
```

- [ ] **Step 7: style_dict carries the EDL (only when non-trivial)**

In `style_dict()`, before the closing brace add:
```gdscript
		"edl": _edl_for_burn(),
```
And the helper:
```gdscript
## The EDL for the burn — [] when the edit is trivial (whole clip, one piece).
func _edl_for_burn() -> Array:
	if _segments.size() == 1 \
			and absf(float(_segments[0]["src_start"])) < 0.01 \
			and absf(float(_segments[0]["src_end"]) - _duration) < 0.01:
		return []
	var out: Array = []
	for sg in _segments:
		out.append([float(sg["src_start"]), float(sg["src_end"])])
	return out
```

- [ ] **Step 8: Verify**

Run ci_check (no SCRIPT ERROR), `test_timeline_view` 96/96, `test_ass_title` 8/8. Report that interactive verification is deferred to the controller.

- [ ] **Step 9: Commit**

```bash
git add scripts/caption_studio.gd
git commit -m "$(printf 'feat: studio owns the EDL — segment inspector, reset, preview across cuts, persistence\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 6: Burn re-assembly (trim/atrim + concat)

**Files:**
- Modify: `scripts/autoload/preview_maker.gd`
- Test: create `tools/test_edl_burn.gd`

**Interfaces:**
- Produces: `PreviewMaker.build_burn_args(video: String, vf_reframe: String, ass_path: String, fonts_dir: String, edl: Array, final_mp4: String) -> PackedStringArray` (static). Empty `edl` → the current plain `-vf` command (byte-identical flags). Non-empty → `-filter_complex` with per-segment `trim`/`atrim` (+`asetpts`/`setpts` resets, audio `aresample=async=1:first_pts=0` per segment), `concat=n=N:v=1:a=1`, the reframe chain + subtitles applied to the concatenated video, `-map "[vout]" -map "[ac]"`, then the same output flags. `burn_custom` delegates to it, passing `style.get("edl", [])`.

- [ ] **Step 1: Write the failing test**

Create `tools/test_edl_burn.gd`:
```gdscript
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
```

- [ ] **Step 2: Run to verify FAIL** (`build_burn_args` missing).

- [ ] **Step 3: Implement**

In `scripts/autoload/preview_maker.gd`, add ABOVE `burn_custom`:
```gdscript
## Build the burn command. Empty edl = the classic single-pass -vf path.
## A non-empty edl assembles first: per-segment trim/atrim (+PTS resets,
## per-segment audio timestamp normalisation), concat, then the reframe
## chain + subtitles over the assembled video. Output flags identical.
static func build_burn_args(video: String, vf_reframe: String, ass_path: String, fonts_dir: String, edl: Array, final_mp4: String) -> PackedStringArray:
	var subs := ",subtitles=filename=%s:fontsdir=%s" % [ass_path, fonts_dir]
	var tail := PackedStringArray([
		"-c:v", "libx264", "-preset", "medium", "-crf", "20",
		"-pix_fmt", "yuv420p", "-movflags", "+faststart",
		"-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
		"-r", "30", final_mp4])
	var args: PackedStringArray
	if edl.is_empty():
		args = PackedStringArray(["-y", "-i", video, "-vf", vf_reframe + subs,
			"-af", "aresample=async=1:first_pts=0"])
	else:
		var fc := ""
		for i in edl.size():
			fc += "[0:v]trim=start=%.3f:end=%.3f,setpts=PTS-STARTPTS[v%d];" % [
				float(edl[i][0]), float(edl[i][1]), i]
			fc += "[0:a]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS,aresample=async=1:first_pts=0[a%d];" % [
				float(edl[i][0]), float(edl[i][1]), i]
		for i in edl.size():
			fc += "[v%d][a%d]" % [i, i]
		fc += "concat=n=%d:v=1:a=1[vc][ac];" % edl.size()
		fc += "[vc]" + vf_reframe + subs + "[vout]"
		args = PackedStringArray(["-y", "-i", video, "-filter_complex", fc,
			"-map", "[vout]", "-map", "[ac]"])
	args.append_array(tail)
	return args
```
Then REPLACE the body of `burn_custom` from `var vf := ""` down to the closing `run_cmd(...)` call with:
```gdscript
	var vf := ""
	if probe_portrait(video):
		vf = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
	else:
		vf = "crop=ih*9/16:ih:(iw-ih*9/16)/2+0:0,scale=1080:1920,setsar=1,fps=30"
	return await run_cmd(ffmpeg_bin(), build_burn_args(video, vf, ass,
		ProjectSettings.globalize_path("res://assets/fonts"),
		style.get("edl", []), final_mp4))
```
(the old `vf += ",subtitles=…"` line and the long inline args list are removed — `build_burn_args` owns both now; delete the now-duplicated audio-flag comment block above the old call).

- [ ] **Step 4: Run to verify PASS**

`test_edl_burn` → `=== edl burn tests: 9 passed, 0 failed ===`; `test_ass_title` 8/8 (write_ass untouched); ci_check clean.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/preview_maker.gd tools/test_edl_burn.gd
git commit -m "$(printf 'feat: burn assembles the EDL via trim/atrim+concat in one pass\n\nCo-Authored-By: Claude Fable 5 <noreply@anthropic.com>')"
```

---

### Task 7: Verification sweep + real EDL burn + roadmap

**Files:** verify only + memory update. Controller-run (needs ffmpeg + GUI).

- [ ] **Step 1: Full headless sweep** — `test_timeline_view` 96/96, `test_edl_burn` 9/9, `test_ass_title` 8/8, `test_subs_prompt` 4/4, `test_font_scale` 4/4, ci_check clean.
- [ ] **Step 2: Real assembly proof** — build a 12s synthetic source (`testsrc` + `sine`, 48k), burn with `edl = [[1,3],[5,7]]` through `PreviewMaker.burn_custom` (headless script or direct ffmpeg with `build_burn_args`), then `ffprobe` the output: duration ≈ 4.0s, audio 48kHz stereo.
- [ ] **Step 3: Manual studio pass** — blade a segment, delete the middle (hear the audio hop), drag to reorder (captions travel), ↺ reset, burn; confirm the mp4 length equals the edited length and captions sit on the right footage.
- [ ] **Step 4: Update the roadmap memory** — MT-P2 implemented (branch/PR status), note the EDL file format and the midpoint reorder rule.
- [ ] **Step 5: Commit** any doc/ledger updates.

---

## Self-Review

**Spec coverage:** EDL model + two clocks (T1), caption ripple delete/reorder incl. midpoint rule + MIN_DUR drops (T2), Media-lane boxes/seams/select/blade/delete (T3), drag-reorder (T4), Inspector segment mode + ↺ reset + `edl.json` persistence + preview frames/audio across cuts + spins/duration re-derive (T5), one-pass trim+concat burn with trivial-path preservation + `style_dict.edl` (T6), real-burn proof + manual pass (T7). Title output-anchoring needs NO code (nothing transforms it) — verified by its absence from T2's transforms. ✅
**Placeholder scan:** every code step shows complete code; the one intentionally duplicated snippet (seg_at_out) is marked "use THIS version verbatim". ✅
**Type consistency:** `segments` dict keys `src_start/src_end` everywhere; `seg_at_out`/`out_start`/`out_len`/`out_to_src` signatures identical across T1 defs, T2-T5 calls, and tests; `segments_changed()`/`segment_selected(i)` match studio connects; `style_dict.edl` = Array of `[s,e]` pairs consumed by `build_burn_args(edl)`; test totals chain 58→73→88→93→96 + new suite 9. ✅
