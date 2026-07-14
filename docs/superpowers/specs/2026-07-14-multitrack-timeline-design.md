# Multi-track timeline for the Caption Review Studio — design

**Date:** 2026-07-14
**Status:** Approved (design), pending implementation plan
**Follow-up to:** the editable-EP-title work (dedicated Title strip, merged) and
the Phase-3 caption timing editor. Reworks the studio's single-lane bottom strip
into a **DaVinci-Resolve/CapCut-style multi-track timeline** whose boxes drive a
single context-sensitive Inspector.

## Goal

Replace the studio's one-lane timeline + separate scrolling cue list + always-on
EP Title strip with **three stacked track-rows of boxes** (Title / Caption /
Media). Clicking a box selects it and the right-column **Inspector** shows *that
element's* editor. This is the interaction the user pointed at in their live
Resolve session (EP33): a Subtitle track of caption boxes, a Text+ box for the
title, footage + audio underneath, and a right-hand Inspector that edits whatever
box is selected.

It also resolves earlier feedback that a shared/duplicated text area was
confusing: a *track* and a *list* are two views of the same cue data. Showing
only the track and making the Inspector selection-driven gives one source of
truth and one editor — the selected box is highlighted, so which element is being
edited is never ambiguous.

## Background (from the user's Resolve reference + CapCut)

The user's Resolve timeline has four stacked tracks — Subtitle (44 caption
clips), a `Text+` clip = the EP title, Video (filmstrip), Audio (waveform) — and
a right-hand Inspector that, when a box is clicked, shows *that* box's Text /
Font / Colour / Size. Boxes are draggable (move) and trimmable (edge drag). Our
studio only ever *edits* two of those layers (title, captions); video+audio are
read-only scrubbing context.

## Design

### 1. Track layout — 3 rows (Title / Caption / Media)

The bottom of the studio becomes a full-width **`TimelineView`** with a time
ruler and three stacked rows:

- **Title** — one box for the EP title, fixed at `0 – TITLE_SEC` (2.5 s).
- **Caption** — one box per cue, laid out along time from the cues' start/end.
- **Media** — filmstrip thumbnails + waveform drawn together in one read-only
  lane (scrubbing reference). Video and audio are folded into a single lane
  because the studio never edits them independently — giving each its own
  labelled track (as Resolve does, because there you can cut them) would only
  cost vertical space in a 9:16-dominated window.

A single **playhead** (vertical line) spans all three rows; dragging it (or
clicking the ruler / Media lane) seeks.

### 2. Components (clean boundaries)

- **`TimelineView`** — *new control*, `scripts/timeline_view.gd`. Owns time↔pixel
  mapping, the three rows, box layout, hit-testing, selection highlight, drag
  (move/trim), and the playhead/scrub. Knows nothing about ASS or the pipeline.
  - **Inputs (set by the studio):** the cue array, the title element (text +
    window), media assets (filmstrip textures + waveform buckets), total
    duration, and the current playhead time + selection.
  - **Signals (out):** `cue_selected(i: int)`, `title_selected()`,
    `selection_cleared()`, `cue_time_changed(i: int, start: float, end: float)`,
    `seek(t: float)`.
  - **Pure, unit-testable helpers:** `time_to_x(t) -> float`,
    `x_to_time(x) -> float`, `cue_at(local_pos) -> int` (−1 = none),
    and a trim helper that clamps a dragged edge (reuses the Phase-3
    `_set_cue_time` clamping: `MIN_DUR` + neighbour windows, start ≤ end, no
    overlaps/inversions).
- **Inspector** — in `caption_studio.gd`'s right column; a thin
  `_show_inspector(kind, i)` that swaps which widgets are visible:
  - `caption` → text edit + start/end SpinBoxes + font/size/colour (today's
    widgets, reused).
  - `title` → title text edit + font + colour (its on-frame position is still
    dragged in the preview).
  - `none` → a short hint.
  No new editor widgets are introduced; the Inspector just re-parents/toggles the
  existing ones and points them at the selected element.
- **`caption_studio.gd`** — the wiring hub and single source of truth (`_cues`,
  `_title_*`). It builds the `TimelineView` child, feeds it data, reacts to its
  signals (update `_cues` / selection / playhead), and refreshes the preview +
  Inspector. It gets *smaller*: the scrolling cue-list construction and the
  always-visible EP Title strip are removed and replaced by the TimelineView +
  the context Inspector.

### 3. Interaction (Resolve/CapCut parity)

- **Caption box:** click = select (highlight + fill Inspector, snap playhead to
  the cue start so the preview shows it). Drag **body** = move in time (both edges
  shift together). Drag **left/right edge** = trim that edge. Move and trim both
  route through the shared clamp so cues never overlap or invert.
- **Title box:** click = select → Inspector shows title text/font/colour. Fixed
  at `0 – TITLE_SEC`; **not** time-draggable. On-frame position is dragged in the
  preview, unchanged.
- **Media lane:** read-only; click/drag scrubs the playhead.
- **Playhead:** vertical across all rows; drag on the ruler to seek.

### 4. Data flow & burn

Single source of truth stays in `caption_studio.gd` (`_cues`, `_title_*`).
`TimelineView` is a pure view+input layer: it renders from the data and emits
intents; the studio mutates the data and pushes it back. The **burn path is
unchanged** — `style_dict()` → `PreviewMaker.write_ass` already carries the
captions + title fields, so `preview_maker.gd` and `test_ass_title.gd` need no
changes.

### 5. Testing

- **New headless test** (`tools/test_timeline_view.gd`) for `TimelineView`'s pure
  helpers: `time_to_x`/`x_to_time` round-trip within tolerance, `cue_at()`
  hit-testing on box bounds/gaps, and trim-clamp behaviour (extends the existing
  `_set_cue_time` regression cases: sub-`MIN_DUR` neighbour windows, edge past
  neighbour, start/end inversion).
- Existing `tools/test_ass_title.gd` still passes (burn untouched).
- **Manual (studio):** launch via the `AGENT_TOWN_STUDIO` hook — select a caption
  box (Inspector shows its text/timing/style; edits reflect on the box + preview),
  drag its body and edges (no overlap), select the title box (Inspector switches
  to title fields), scrub the playhead.

## Files touched

- **New:** `scripts/timeline_view.gd` — the 3-row timeline control (mapping,
  boxes, hit-testing, drag/trim, playhead, signals, pure helpers).
- **Modify:** `scripts/caption_studio.gd` — host the `TimelineView`; add the
  context Inspector (`_show_inspector`); remove the scrolling cue list and the
  always-visible EP Title strip; wire signals ↔ data ↔ preview.
- **New:** `tools/test_timeline_view.gd` — headless geometry/trim tests.
- **Unchanged:** `scripts/autoload/preview_maker.gd`, `tools/test_ass_title.gd`
  (burn path unaffected).

## Out of scope (YAGNI)

Adding/deleting caption boxes from the track (the studio edits the pipeline's
existing SRT cues; there is no add/delete today and none is added), multi-select,
track reordering, magnetic/snapping timeline, editable title *timing*, per-title
or per-cue animation, and audio-playback changes.
