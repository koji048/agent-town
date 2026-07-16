# MT Phase 2 — Footage cut / delete / reorder in the Caption Studio — design

**Date:** 2026-07-16
**Status:** Approved (design), pending implementation plan
**Follow-up to:** the multi-track timeline P1 (PR #8) and review-UX round 2
(PR #9). This phase makes the **Media lane editable**: blade-cut the footage,
ripple-delete bad takes, and drag-reorder segments — with captions following
the footage automatically — then re-assemble the final clip in one ffmpeg pass
at burn time.

## Owner decisions

- **Scope:** both cut-out-mistakes (ripple delete) AND reorder (option C).
- **Caption semantics:** captions BELONG TO THE FOOTAGE (option A) — deleting
  a footage range deletes the caption words spoken in it, cuts straddling a
  boundary are split, everything after ripples; a reordered segment carries
  its captions with it. The EP title is OUTPUT-anchored (the opening card
  stays at the head of the final clip regardless of footage edits).
- **Blade:** ONE blade (✂️ / `S`) for both tracks — it cuts the element the
  selection context points at (a selected video segment → cut footage;
  otherwise → cut the caption under the playhead, as today). Revisit if it
  confuses in practice.

## Architecture: non-destructive EDL

The studio never touches the source footage. It keeps an **edit decision
list**: `segments: Array[{src_start: float, src_end: float}]`, ordered — the
output timeline is the concatenation of the segments. Opening a clip =
one full-length segment. All edits are list operations; the real video is
assembled once, at burn.

**Two clocks.** "Output time" = what the timeline, preview, captions, title,
and the final clip use. "Source time" = positions in the original footage.
Pure statics map between them:

- `out_to_src(segments, t) -> float` — output position → source position
  (for preview frame lookup and audio seek).
- `out_len(segments) -> float` — total output duration (Σ segment lengths).
- `seg_at_out(segments, t) -> int` — which segment an output time falls in.

**Captions live in output time** (unchanged data model). Every EDL operation
transforms the cue array ONCE, deterministically:

- `cut_footage(segments, cues, at_out)` — split the segment at output time
  `at_out` into two (both halves ≥ `MIN_SEG_DUR` = 0.5 s or no-op). Cues are
  untouched (a cut alone changes nothing on screen).
- `delete_segment(segments, cues, i)` — remove segment `i`; cues fully inside
  its output range are dropped, cues straddling its edges are trimmed to the
  boundary, everything after shifts left by the segment's length. The last
  remaining segment cannot be deleted.
- `reorder_segment(segments, cues, from_i, to_i)` — move a segment (and the
  cues whose spans lie within its output range, trimming stragglers at the
  edges the same way delete does) to the new position; all affected cues get
  the block offsets applied. Cues stay sorted and non-overlapping afterward.
- The EP title (`title_start`/`title_dur`) is NOT transformed by any of these
  (output-anchored), only re-clamped into `[0, out_len]`.

## UI (Media lane becomes editable)

- The Media row renders **one box per segment**: the filmstrip + waveform
  drawn per-segment from its source range, with a visible seam line between
  boxes. Selection highlight matches caption boxes.
- **Click** a segment box → `sel_kind = "segment"`, `sel_seg = i`; the
  Inspector shows a `"segment"` mode: its source range (`src m:ss – m:ss`,
  length) and a 🗑 delete button.
- **Blade** (✂️ toolbar / `S`): if `sel_kind == "segment"` → `cut_footage` at
  the playhead (playhead must be inside a segment, both halves ≥
  `MIN_SEG_DUR`); otherwise → caption blade exactly as today.
- **Delete** (🗑 / `Del`): if `sel_kind == "segment"` → `delete_segment`
  (ripple); otherwise caption delete as today.
- **Drag** a segment box horizontally → live reorder: when the dragged box's
  centre passes a neighbour's centre, swap (CapCut-style). Drop commits via
  the existing `edit_committed`.
- **↺ เริ่มตัดใหม่** toolbar button: reset the EDL to one full segment and
  restore the pre-edit cues (the cue array snapshot taken when the EDL first
  becomes non-trivial). Confirm-free but announced in the log line.
- Empty-space press/seek/scrub on the Media lane still works when clicking
  outside any box (below the boxes' band nothing changes vs today).

## Preview across cuts

- The playhead runs in output time. Frame lookup: `out_to_src(t)` → existing
  filmstrip frame index (no re-extraction).
- Audio: keep playing the existing `preview.wav`; `_process` detects when
  playback crosses a segment boundary (`seg_at_out` changes or source
  position jumps) and re-seeks the `AudioStreamPlayer` to the mapped source
  position. Scrub-seek uses the same mapping.

## Burn (one-pass re-assembly)

When the EDL is non-trivial, `burn_custom` (and the pipeline burn path)
assembles with a `filter_complex` instead of the plain `-vf`:

```
[0:v]trim=A:B,setpts=PTS-STARTPTS[v0]; [0:a]atrim=A:B,asetpts=PTS-STARTPTS[a0]; …
[v0][a0][v1][a1]…concat=n=N:v=1:a=1[vc][ac];
[vc]<reframe 9:16 chain>,subtitles=…[vout]
```

then the existing output flags verbatim (libx264 crf20, yuv420p, +faststart,
aac 192k **48 kHz stereo**, `aresample first_pts=0`, 30 fps). A trivial EDL
(one full segment) burns through the existing unchanged path. The ASS is
written in output time — already correct.

**Persistence:** the EDL saves to `edit.json` next to the batch's exports on
every commit (same rhythm as the .srt), and `open_clip` reloads it — closing
and reopening the studio resumes the edit. The `-clean.srt` stays in output
time, so it always matches the (edited) burned clip.

## Files touched

- **Modify:** `scripts/timeline_view.gd` — segments state + pure statics
  (`out_to_src`, `out_len`, `seg_at_out`, `cut_footage`, `delete_segment`,
  `reorder_segment`), Media-row boxes (draw per segment + seams), segment
  select/drag-reorder input, `sel_kind == "segment"`, new signals
  (`segment_selected(i)`, `segments_changed()`).
- **Modify:** `scripts/caption_studio.gd` — feed/own `segments` + snapshot
  for reset; Inspector `"segment"` mode; toolbar reset button; blade/delete
  routing by selection; audio boundary re-seek in `_process`; `edit.json`
  save/load; `style_dict`/burn invocation carries the EDL.
- **Modify:** `scripts/autoload/preview_maker.gd` — `burn_custom` builds the
  trim/concat `filter_complex` when segments are non-trivial.
- **Tests:** extend `tools/test_timeline_view.gd` (mapping round-trips, cut/
  delete/reorder + caption ripple rules, title re-clamp only); new
  `tools/test_edl_burn.gd` (the generated filter_complex string for a known
  EDL; trivial EDL uses the plain path); one real fixture burn in the final
  verification (output duration = Σ segments).

## Testing

- **Headless:** `out_to_src`/`out_len`/`seg_at_out` round-trips incl. seam
  boundaries; `cut_footage` halves + MIN_SEG_DUR no-op; `delete_segment`
  cue rules (inside → dropped, straddling → trimmed, after → shifted, last
  segment protected); `reorder_segment` carries its cues and keeps the array
  sorted/non-overlapping; title untouched by all three; filter_complex string
  for a 3-segment EDL; trivial-EDL burn path unchanged.
- **Manual:** in the studio — blade a segment, delete the middle, hear audio
  jump the gap, drag to reorder, reset, burn; verify the mp4's duration and
  that captions sit on the right footage.

## Out of scope (YAGNI)

Full undo stack (reset-to-original only), transitions/crossfades between
segments, editing across multiple source files (multi-part clips keep one EDL
per part), speed ramps, keyframes, separate audio-only edits, and exporting
the EDL to external editors.
