# EP opening title card — design (Phase 4)

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan
**Part of:** clip/caption improvements (Phase 4 of 4, the finale). Phases 1–3
merged. See `clip-caption-roadmap`.

## Goal

Every reel opens with a title card — **`EPxx : <title>`, yellow Anuphan,
centered** — for the first ~2.5 s, both **burned into the video** and **shown in
the studio preview** (WYSIWYG, consistent with Phase 2). The EP number and title
come from the reels ingest.

## Design

### A — Burn the card (ASS style + one Dialogue), `preview_maker.gd`

The burn already renders subtitles via libass ASS (`write_ass` → `burn_custom`).
Add a centered yellow opener with a second style + one event — no extra ffmpeg pass.

- **`ASS_HEADER`**: add a `Title` style after `Default`:
  `Style: Title,Anuphan,100,&H0000FFFF,&H00000000,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,4,0,5,60,60,60,1`
  — Anuphan, size 100, **yellow primary** (`&H0000FFFF` = BGR), black outline,
  bold (`-1`), **Alignment 5** (middle-center on the 1080×1920 canvas), outline 4.
- **`write_ass`**: after the header, if the style dict carries a positive `ep`
  and a non-empty `title`, emit one event on the `Title` style for 0:00–2.5 s:
  `Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,EP%02d : %s` (title trimmed to
  a sane length, e.g. `.left(60)`; `\N`-escape newlines as the cue writer does).
  When `ep`/`title` are absent, nothing changes (backward compatible).

### B — Feed ep + title into the burn, `pipeline.gd` (`_run_clip_reels`)

`ep` (line 254) and `topic` are already in scope. In the burn block, before the
`action == "custom"` call to `burn_custom` (line ~340), add to the style dict:
`style["ep"] = ep` and `style["title"] = topic`. So the studio-Burn path (the
only studio outcome after Phase 1) burns the card. (The `reel.sh` fallback burn
is external and unchanged — no card there, acceptable.)

### C — Show the card in the studio preview, `caption_studio.gd`

- Add `_title_label` in the preview `frame_holder`: **Anuphan, yellow, centered**
  (anchors center), font ≈ `100 * PREVIEW_SCALE` (≈30 px) to match the burn size.
- Store the title text; in `_show_time`, set
  `_title_label.visible = (_t < TITLE_SEC and not _title_text.is_empty())`
  with `const TITLE_SEC := 2.5`, so it appears only over the opening — exactly
  where it burns.
- `open_clip(srt, frames, title := "")` gains an optional title param that sets
  `_title_text` / `_title_label.text` (default "" = no card, unchanged behavior).

### D — Plumb ep + title to the studio, `pipeline.gd` + `main.gd`

- `pipeline.gd`: before `EventBus.clip_review_requested.emit(...)` (line 318),
  set `request["_ep"] = ep` so the request carries the EP number.
- `main.gd`: the `clip_review_requested` handler (line 240) already receives the
  request — build `EP%02d : <topic>` from `request["_ep"]` + `request["topic"]`
  (empty when there's no EP) and pass it to `_studio.open_clip(srt, prev, title)`.

## Files touched

- **Modify:** `scripts/autoload/preview_maker.gd` — Title style + title Dialogue (A).
- **Modify:** `scripts/pipeline.gd` — inject ep/title into style; set `request["_ep"]` (B, D).
- **Modify:** `scripts/caption_studio.gd` — `_title_label` + `open_clip` param (C).
- **Modify:** `scripts/main.gd` — build the title, pass to `open_clip` (D).

## Testing

- **Headless (A):** extend `tools/test_ass_margin.gd` (or a new `test_ass_title.gd`):
  `write_ass` with `style = {ep: 7, title: "hi"}` emits a `Title` style line AND a
  `Dialogue: ...,Title,...,EP07 : hi` event; with no ep/title it emits neither.
- **Manual (C, D):** launch via `AGENT_TOWN_STUDIO` with a title (extend the dev
  hook or set it) — the yellow centered `EPxx : …` shows for the first ~2.5 s of
  the preview, then hides. The burn card itself needs ffmpeg/a real clip (manual).

## Out of scope

Custom title fonts/colors (fixed yellow Anuphan per the owner), animated intros,
and the `reel.sh` fallback title (external tool).
