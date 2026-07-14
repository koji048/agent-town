# Caption Studio review UX — round 2 — design

**Date:** 2026-07-14
**Status:** Approved (design), pending implementation plan
**Follow-up to:** the multi-track timeline (Phase 1) rework
(`2026-07-14-multitrack-timeline-design.md`), which is implemented on
`chore/studio-dev-title-hook`. This spec addresses five refinements the owner
found while reviewing that build live.

## Goal

Make the new multi-track studio comfortable to review and edit with: an
adjustable-duration and multi-line EP title, an optional at-a-glance subtitle
list, a whole-stack time shift, and visible cut/delete tools (the split action is
currently keyboard-only and undiscoverable).

## Design

### 1. Adjustable EP title duration (`timeline_view.gd`, `caption_studio.gd`, `preview_maker.gd`)

Today the title box is a fixed `TITLE_SEC` (2.5 s) wide; only its start is
draggable. Add duration:

- `TimelineView` gains `title_dur: float` (default `TITLE_SEC`). The title box
  spans `[title_start, title_start + title_dur]`.
- The title box gets the **same edge-grab model as captions**: in `press()`, the
  title-row branch detects a left-edge / right-edge / body grab (using `EDGE_PX`);
  in `motion()`, **left edge** moves `title_start` (keeping the end fixed →
  `title_dur` changes), **right edge** changes `title_dur` (end), **body** moves
  `title_start` keeping `title_dur`. Clamps: `title_start ≥ 0`,
  `title_start + title_dur ≤ duration`, and `title_dur ≥ MIN_TITLE_DUR` (0.5 s).
- The signal `title_time_changed(start)` becomes `title_time_changed(start, dur)`;
  the studio stores `_title_dur` and `style_dict()` sends
  `title_end = _title_start + _title_dur` (the burn already honors `title_end`).
- `_draw` renders the title box at its `title_dur` width with the same selection
  highlight/edge bars captions use.

### 2. Multi-line EP title (`caption_studio.gd`, `preview_maker.gd`)

- The title editor `_title_edit` becomes a **`TextEdit`** (multi-line) instead of
  `LineEdit`, so Enter inserts a newline. Its `text` (with `\n`) flows to
  `_title_text` / `_title_label` / `_timeline.title_text` as today.
- `write_ass` stops flattening the title: the title `Dialogue` converts newlines
  to ASS `\N` (`replace("\n", "\\N")`) instead of `replace("\n", " ")`, matching
  the caption path, so a two-line `EP33 …\nที่หัวหน้าชอบ` burns on two lines.
- The preview `_title_label` already word-wraps; explicit `\n` render as breaks.

### 3. Optional read-only subtitle list (`caption_studio.gd`)

- A `📋 รายการซับ` `CheckButton` in the right column toggles a `ScrollContainer`
  (default hidden) that lists every cue as `m:ss  text…` rows in the freed space.
- The row of the currently selected cue is highlighted. **Clicking a row selects
  that caption and seeks to its start** — it drives the same path as clicking the
  caption's box (`_on_cue_selected` + timeline selection), so the Inspector and
  timeline stay authoritative. The list is **read-only** (navigation/overview
  only; editing stays in the Inspector) — no second editor, no ambiguity.
- The list rebuilds only while visible, on the events that change cues or
  selection (`open_clip`, `_on_cue_selected`, `_on_cue_split`, `_on_cue_deleted`,
  `_save_cue`, `_apply_time_fields`).

### 4. Select All + move the whole stack (`timeline_view.gd`, `caption_studio.gd`)

- A **Select All** action sets `sel_kind = "all"`; `_draw` highlights every
  caption box **and** the title box.
- With `sel_kind == "all"`, a drag shifts **all captions and the title together**
  by one delta, rigidly (relative spacing preserved). The delta is clamped once,
  against the whole set, so nothing crosses the walls:
  `delta ∈ [ -min_start , duration - max_end ]` where `min_start` is the earliest
  start across all cues and the title, and `max_end` the latest end. A pure static
  `shift_all(cues, title_start, title_dur, delta, duration) -> {cues, title_start}`
  computes the clamped shift and the new positions (keeps the rigid-block rule in
  one testable place).
- Clicking a single box returns to single selection (`"cue"`/`"title"`). The
  live group-drag emits `cue_time_changed` per affected cue (studio updates the
  preview) plus `title_time_changed` for the title; on release the existing
  `edit_committed` fires so the studio persists the `.srt` — no new signal.

### 5. Visible cut/delete toolbar (`caption_studio.gd`)

- A small toolbar near the timeline with **✂️ Cut** (calls the timeline's
  `cut_at_playhead` on the selected caption at the playhead), **🗑 Delete** (calls
  `delete_selected`), and **Select All** (item 4). Buttons act on the current
  selection/playhead exactly like the keyboard paths.
- The existing `S` / `Delete` keyboard shortcuts stay, shown as hint text on the
  buttons so they remain discoverable.

## Files touched

- **Modify:** `scripts/timeline_view.gd` — `title_dur` + title edge-resize;
  `sel_kind == "all"` + `shift_all` static + group-drag; `title_time_changed`
  gains `dur`; `_draw` title width + all-selection highlight.
- **Modify:** `scripts/caption_studio.gd` — `_title_dur`; title editor →
  `TextEdit`; the read-only list toggle + rebuild; the cut/delete/select-all
  toolbar; `style_dict` `title_end` from `_title_dur`; handlers for the new
  signals.
- **Modify:** `scripts/autoload/preview_maker.gd` — title `\n` → `\N`.
- **Modify:** `tools/test_timeline_view.gd` — title edge-resize + `shift_all`
  tests.
- **Modify:** `tools/test_ass_title.gd` — title `\N` + resized `title_end`.

## Testing

- **Headless:** title edge-resize via `press`/`motion` (right edge grows
  `title_dur`, left edge moves start keeping end, `MIN_TITLE_DUR` clamp);
  `shift_all` (uniform delta, gaps preserved, clamped at both walls, title
  included); `write_ass` title with `\n` emits `\N` and honors a resized
  `title_end`.
- **Manual (studio):** multi-line title entry (Enter), the list toggle +
  click-to-jump + highlight sync, the toolbar buttons, and Select-All drag.

## Out of scope (YAGNI)

Numeric title start/end spin fields (edge-drag only), per-line title styling,
making the subtitle list editable, and rubber-band / partial multi-select
(Select All is all-or-one — no per-item multi-select set).
