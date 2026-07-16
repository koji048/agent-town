# Multi-track timeline for the Caption Review Studio — design (Phase 1)

**Date:** 2026-07-14
**Status:** Approved (design), pending implementation plan
**Follow-up to:** the editable-EP-title work (dedicated Title strip, merged) and
the Phase-3 caption timing editor. Reworks the studio's single-lane bottom strip
into a **DaVinci-Resolve/CapCut-style multi-track timeline** whose boxes drive a
single context-sensitive Inspector.

## Phasing

The full request (a Resolve-like editor including cutting and reordering the
**footage** itself) is split into two specs, built in order:

- **Phase 1 — this spec.** The `TimelineView` control + all box mechanics on the
  **Caption** and **Title** tracks: select, drag-move (free, gaps allowed),
  trim, **cut/split**, delete, and a **time-draggable title**. The **Media** lane
  is read-only scrubbing context. The burn stays per-cue (unchanged).
- **Phase 2 — separate spec, next.** Editing the **footage** on the Media lane:
  cut / reorder / move source segments, burn **re-assembly** (ffmpeg trim+concat
  for video *and* audio), preview/​waveform output→source remapping, and the
  caption-timing-vs-footage semantics. Phase 2 is built on Phase 1's box + cut +
  drag machinery, so Phase 1 is its prerequisite.

## Goal (Phase 1)

Replace the studio's one-lane timeline + separate scrolling cue list + always-on
EP Title strip with **three stacked track-rows of boxes** (Title / Caption /
Media). Clicking a box selects it and the right-column **Inspector** shows *that
element's* editor. Caption and title boxes can be dragged along time, trimmed,
cut at the playhead into two, and deleted. This is the interaction the user
pointed at in their live Resolve session (EP33): a Subtitle track of caption
boxes, a `Text+` box for the title, footage + audio underneath, and a right-hand
Inspector that edits whatever box is selected.

It also resolves earlier feedback that a shared/duplicated text area was
confusing: a *track* and a *list* are two views of the same cue data. Showing
only the track and making the Inspector selection-driven gives one source of
truth and one editor — the selected box is highlighted, so which element is being
edited is never ambiguous.

## Background (from the user's Resolve reference + CapCut)

The user's Resolve timeline has four stacked tracks — Subtitle (44 caption
clips), a `Text+` clip = the EP title, Video (filmstrip), Audio (waveform) — and
a right-hand Inspector that, when a box is clicked, shows *that* box's Text /
Font / Colour / Size. Boxes are draggable (move), trimmable (edge drag), and can
be bladed/split at the playhead. Our studio only *edits* two of those layers
(title, captions) in Phase 1; video+audio are read-only scrubbing context until
Phase 2.

## Design

### 1. Track layout — 3 rows (Title / Caption / Media)

The bottom of the studio becomes a full-width **`TimelineView`** with a time
ruler and three stacked rows:

- **Title** — one box for the EP title, `TITLE_SEC` (2.5 s) wide, **draggable
  along time** (its burn window follows where it is dropped). Only one title box.
- **Caption** — one box per cue, laid out from the cues' start/end; draggable,
  trimmable, cuttable, deletable.
- **Media** — filmstrip thumbnails + waveform drawn together in one read-only
  lane (scrubbing reference). Video and audio are folded into a single lane
  because Phase 1 never edits them independently; Phase 2 revisits this.

A single **playhead** (vertical line) spans all three rows; dragging it (or
clicking the ruler / Media lane) seeks. Cut/split happens at the playhead.

### 2. Components (clean boundaries)

- **`TimelineView`** — *new control*, `scripts/timeline_view.gd`. Owns time↔pixel
  mapping, the three rows, box layout, hit-testing, selection highlight, drag
  (move/trim), cut/split, delete, and the playhead/scrub. Knows nothing about ASS
  or the pipeline.
  - **Inputs (set by the studio):** the cue array, the title element (text +
    window), media assets (filmstrip textures + waveform buckets), total
    duration, and the current playhead time + selection.
  - **Signals (out):** `cue_selected(i)`, `title_selected()`,
    `selection_cleared()`, `cue_time_changed(i, start, end)`,
    `title_time_changed(start)`, `cue_split(i, at)`, `cue_deleted(i)`,
    `seek(t)`.
  - **Pure, unit-testable helpers:** `time_to_x(t) -> float`,
    `x_to_time(x) -> float`, `cue_at(local_pos) -> int` (−1 = none),
    a **placement clamp** `clamp_span(i, start, end) -> [start, end]` that keeps a
    moved/trimmed box `>= MIN_DUR` and **non-overlapping** with the other cues on
    the track (blocks at the nearest collision; gaps are allowed), and a
    **split** `split_span(start, end, at) -> [[start, at], [at, end]]` valid only
    when both halves are `>= MIN_DUR`.
- **Inspector** — in `caption_studio.gd`'s right column; a thin
  `_show_inspector(kind, i)` that swaps which widgets are visible:
  - `caption` → text edit + start/end SpinBoxes + font/size/colour (today's
    widgets, reused).
  - `title` → title text edit + font + colour (its on-frame position is still
    dragged in the preview; its *time* is dragged on the track).
  - `none` → a short hint.
  No new editor widgets are introduced; the Inspector re-parents/toggles the
  existing ones and points them at the selected element.
- **`caption_studio.gd`** — the wiring hub and single source of truth (`_cues`,
  `_title_*` incl. `_title_start`). Builds the `TimelineView` child, feeds it
  data, reacts to its signals (mutate `_cues` / title / selection / playhead),
  and refreshes the preview + Inspector. It gets *smaller*: the scrolling cue-list
  construction and the always-visible EP Title strip are removed and replaced by
  the TimelineView + the context Inspector.

### 3. Interaction (Resolve/CapCut parity)

- **Caption box:**
  - Click = select (highlight + fill Inspector, snap playhead to the cue start).
  - Drag **body** = move in time, both edges together; **free** (gaps allowed),
    clamped only to avoid overlapping another caption (blocks at collision).
  - Drag **left/right edge** = trim that edge (`>= MIN_DUR`, no overlap).
  - **Cut/split** (blade action or key) at the playhead = split the box into two
    adjacent caption boxes at the playhead time; **each half inherits the text**
    and can then be moved / trimmed / edited / deleted independently. Only when
    the playhead is inside the box and both halves are `>= MIN_DUR`.
  - **Delete** (key or small ✕ on the selected box) removes the cue.
  - Move / trim / split all route through the shared `clamp_span` / `split_span`
    so cues never overlap or fall below `MIN_DUR`.
- **Title box:** click = select → Inspector shows title text/font/colour.
  **Draggable along time** (`_title_start` moves; window stays `TITLE_SEC` wide,
  clamped to `[0, total − TITLE_SEC]`). On-frame position is dragged in the
  preview, unchanged. Not cuttable/deletable (there is exactly one title).
- **Media lane:** read-only in Phase 1; click/drag scrubs the playhead.
- **Playhead:** vertical across all rows; drag on the ruler to seek; the anchor
  for cut/split.

### 4. Data flow & burn

Single source of truth stays in `caption_studio.gd` (`_cues`, `_title_*`).
`TimelineView` is a pure view+input layer: it renders from the data and emits
intents; the studio mutates the data and pushes it back. Cut adds a cue to
`_cues`; delete removes one; move/trim update a cue's start/end; title drag
updates `_title_start`.

The **burn path is essentially unchanged** — `style_dict()` →
`PreviewMaker.write_ass` already loops over `_cues` emitting one `Dialogue` per
cue, so split/deleted/moved cues fall out for free. The only addition is that the
title `Dialogue`'s start/end derive from `_title_start` (not hard-coded `0.00`):
`title_start`/`title_end` become fields in `style_dict()` and `write_ass`
(defaulting to `0.0`/`TITLE_SEC` to preserve today's behaviour).
`test_ass_title.gd` gains one case for a non-zero title start.

### 5. Testing

- **New headless test** (`tools/test_timeline_view.gd`) for `TimelineView`'s pure
  helpers:
  - `time_to_x`/`x_to_time` round-trip within tolerance.
  - `cue_at()` hit-testing on box bounds and gaps.
  - `clamp_span()`: blocks overlap with neighbours on move, holds `MIN_DUR` on
    trim, allows gaps, handles the boundary/edge-past-neighbour and
    start/end-inversion cases (extends the existing `_set_cue_time` regressions).
  - `split_span()`: valid split inside the box; rejects splits that would make a
    half `< MIN_DUR`.
- **Updated** `tools/test_ass_title.gd` — one added case: a non-zero
  `title_start` emits the title `Dialogue` at the shifted start/end; defaults
  still emit `0:00:00.00 → 0:00:02.50`.
- **Manual (studio):** launch via the `AGENT_TOWN_STUDIO` hook — select a caption
  box (Inspector shows its text/timing/style), drag its body/edges (no overlap),
  cut it at the playhead into two, delete one, drag the title box along time,
  select the title (Inspector switches to title fields), scrub the playhead.

## Files touched

- **New:** `scripts/timeline_view.gd` — the 3-row timeline control (mapping,
  boxes, hit-testing, drag/trim, cut/split, delete, playhead, signals, pure
  helpers).
- **Modify:** `scripts/caption_studio.gd` — host the `TimelineView`; add the
  context Inspector (`_show_inspector`); remove the scrolling cue list and the
  always-visible EP Title strip; add `_title_start`; wire signals ↔ data ↔
  preview.
- **Modify:** `scripts/autoload/preview_maker.gd` — title `Dialogue` start/end
  derive from `title_start`/`title_end` (default `0.0`/`TITLE_SEC`).
- **Modify:** `tools/test_ass_title.gd` — non-zero `title_start` case.
- **New:** `tools/test_timeline_view.gd` — headless geometry/clamp/split tests.

## Out of scope (Phase 1 — YAGNI)

- **Footage editing** (cut/reorder/move the Media lane + burn re-assembly) →
  **Phase 2**, its own spec.
- Multi-select, track reordering, magnetic/snapping timeline, per-cue/per-title
  animation, and audio-playback changes.
