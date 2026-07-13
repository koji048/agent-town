# Caption timing editor — design (Phase 3)

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan
**Part of:** clip/caption improvements (Phase 3 of 4). Phases 1–2 merged. See
`clip-caption-roadmap`.

## Goal

Answer the owner's repeated question — "if a subtitle's timing is off, how do I
adjust the seconds?" Today the studio can only edit a cue's *text* and *seek*;
there is no way to change a cue's start/end time. Add CapCut/Resolve-style
timing: **drag a cue's edges/body on the timeline**, AND **type exact start/end
seconds** — both written to the `.srt`.

## Background (current code, `caption_studio.gd`)

- `_draw_timeline` draws cue blocks as a thin 11px strip at the bottom
  (`y = size.y - 14`); `_timeline_input` only seeks.
- `_cue_edit` (TextEdit) + `_save_cue` edit the selected cue's TEXT and
  `PreviewMaker.write_srt(cues, _srt_path)`.
- `cues` is `[{start, end, text}]` (floats seconds); `_sel` is the selected index.

## Design

### A — Shared retime primitive

`_set_cue_time(i, ns, ne)` clamps a cue's new start/end against its neighbors and
a minimum duration, then mutates `cues[i]`:
- `lo = (i==0) ? 0.0 : cues[i-1].end`, `hi = (i==last) ? _duration : cues[i+1].start`
- `ns = clampf(ns, lo, ne - MIN_DUR)`, then `ne = clampf(ne, ns + MIN_DUR, hi)`
- `const MIN_DUR := 0.2` (seconds). Both the spin fields (B) and drag (C) call it.
A separate `_commit_cues()` writes the SRT + rebuilds the list + redraws, called
on field-change and drag-release (not every drag frame, to avoid disk churn —
drag updates redraw live but write once on release).

### B — Numeric start/end second fields

Two `SpinBox`es (start, end) beside `_cue_edit`, `step 0.05`, suffix `s`,
`min 0`, `max` = clip duration. On `value_changed` (guarded against programmatic
sync): `_set_cue_time(_sel, start_spin.value, end_spin.value)` then
`_commit_cues()`. A `_sync_time_fields()` sets the spins from the selected cue
under a `_syncing` guard (so setting them from selection/drag doesn't re-trigger
the handler). Called when a cue is selected and live during a drag.

### C — Draggable cue blocks on the timeline

- Draw cue blocks taller (a ~22px band) so edges are grabbable; draw the
  **selected** cue's left/right edges as bright handles.
- `_timeline_input` gains drag modes. On left mouse **down**, hit-test the
  cursor x against each cue's `[x0, x1]`:
  - within `EDGE_PX (7)` of `x0` → mode `"start"`; of `x1` → mode `"end"`;
  - inside the body → mode `"move"` (store grab offset `t - cue.start`);
  - a cue hit also selects it (`_sel = i`, sync fields + `_cue_edit`);
  - no cue hit → mode `"seek"` (existing behavior).
- On **motion** while held: `"seek"` seeks; `"start"`/`"end"` call
  `_set_cue_time` with the new edge time; `"move"` shifts both by the same delta
  (preserving duration, clamped to neighbors). Each motion redraws + syncs the
  fields, but does NOT write the SRT.
- On mouse **up**: if the mode was an edit, `_commit_cues()` (one SRT write);
  reset mode.
- `MOUSE_BUTTON_MASK_LEFT` gating stays; time↔x via `t = x/width*_duration`.

## Files touched

- **Modify:** `scripts/caption_studio.gd` — `_set_cue_time`, `_commit_cues`,
  spin fields + `_sync_time_fields`, timeline drag modes + taller blocks.

## Testing

- **Headless (A):** `tools/test_cue_retime.gd` — set `cues`/`_duration` on a bare
  studio instance, call `_set_cue_time` and assert: start can't cross the
  previous cue's end, end can't cross the next cue's start, and MIN_DUR is
  enforced (start can't come within 0.2s of end).
- **Manual (B, C):** launch via `AGENT_TOWN_STUDIO`; select a cue, type new
  start/end (SRT updates), and drag a cue's edges/body on the timeline (moves,
  clamps to neighbors, writes on release).

## Out of scope (later)

Per-word timing, ripple edit (shifting following cues), and the EP title card
(Phase 4).
