# Editable EP title (styleable + draggable) — design

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan
**Follow-up to:** Phase 4 (EP title card, merged). Makes the fixed yellow-Anuphan
title a **CapCut-like text element**: pick its style, drag it anywhere.

## Goal

In the Caption Review Studio, the EP title becomes a first-class editable text
element — **select it, restyle it (font / colour / size), and drag it anywhere
on the 9:16 frame (2D)** — and those choices flow to the burn. Default look is
today's yellow Anuphan centred, so doing nothing is unchanged.

## Background (from CapCut/IG text editing)

Text in CapCut/IG is a draggable, styleable element: tap to select, drag on the
canvas (2D), and a style panel sets font/colour/size/alignment. Our studio
already has font/size/colour pickers + a draggable caption (Phase 2). This
applies the **same controls** to a second element (the title) via a selection
model, and adds 2D drag for the title.

## Design

### A — Selection model (`caption_studio.gd`)

- Add a target toggle **`[Caption] [Title]`** at the top of the style bar; state
  `_target: String` ("caption" | "title", default "caption").
- The existing font (`_font_pick`), size (`_size_pick`) and colour (presets +
  custom picker) controls act on the **active target**. Their handlers branch on
  `_target`: caption path sets the existing caption style; title path sets the
  title style.
- `_sync_style_controls()` sets the pickers to reflect the active target's style
  when the target switches (guarded like `_syncing`, so the programmatic set
  doesn't re-fire the handlers).
- **Direct-drag also selects:** grabbing the caption sets `_target = "caption"`;
  grabbing the title sets `_target = "title"` (CapCut-style — you drag the thing
  you want to move, and it becomes the styled element).

### B — Title style state + 2D drag (`caption_studio.gd`)

- Title style vars, defaulting to today's look: `_title_font_idx` (Anuphan),
  `_title_size_idx` (into `SIZES`, default L), `_title_use_custom`/
  `_title_color_idx`/`_title_custom_color` (default yellow), and 2D position
  `_title_x`, `_title_y` in **burn-canvas px** (default centre `540, 960`).
- The `_title_label` becomes draggable in BOTH axes: `MOUSE_FILTER_STOP` +
  `gui_input`; on left-drag, `_title_x += dx / PREVIEW_SCALE`,
  `_title_y += dy / PREVIEW_SCALE` (clamped to the canvas), then reposition. Its
  position anchors on the label's centre = `(_title_x, _title_y) * PREVIEW_SCALE`
  in the preview frame.
- `_apply_title_style()` sets the `_title_label`'s font/colour/size (from the
  title style, scaled by `PREVIEW_SCALE`) — mirrors `_apply_style` for captions.
- The title stays visible in the studio when `_target == "title"` (so it's
  editable) OR `_t < TITLE_SEC` (its real on-screen window).

### C — Burn: dynamic Title style + \pos (`preview_maker.gd`)

- `ASS_HEADER` `Title` style becomes parameterised:
  `Style: Title,{title_font},{title_size},{title_primary},&H000000FF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,4,0,5,60,60,60,1`
  (Alignment 5 = the \pos anchor is the text centre). Defaults in the format dict
  keep the old look when unset.
- `write_ass` emits the title event with a `\pos` override at the chosen centre:
  `Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,{\pos(%d,%d)}EP%02d : %s`
  using `style["title_x"]`, `style["title_y"]` (defaults 540, 960).

### D — Studio → burn flow (`caption_studio.gd` `style_dict`)

`style_dict()` gains the title fields so they reach `burn_custom` → `write_ass`:
`title_font` (family), `title_size` (px), `title_primary` (ASS BGR from the title
colour, via the existing `_ass_color`), `title_x`, `title_y`. The EP number +
title TEXT are still injected by the pipeline (`style["ep"]/["title"]`), unchanged.

## Files touched

- **Modify:** `scripts/caption_studio.gd` — target toggle, title style state, 2D
  title drag, target-aware pickers, `_apply_title_style`, `style_dict` additions.
- **Modify:** `scripts/autoload/preview_maker.gd` — parameterised `Title` style +
  `\pos` in the title Dialogue.
- **(Dev)** `scripts/main.gd` — `AGENT_TOWN_STUDIO` dev hook already extended to
  pass a title (3rd `|` field) for previewing.

## Testing

- **Headless:** extend `tools/test_ass_title.gd` — `write_ass` with a title style
  (`title_font`, `title_size`, `title_primary`, `title_x`, `title_y`) emits the
  dynamic `Style: Title,<font>,<size>,<primary>,…` line AND a
  `\pos(x,y)…EP07 : …` event; unchanged (old-look) defaults still valid.
- **Manual (studio):** launch via the extended `AGENT_TOWN_STUDIO` hook with a
  title; toggle to Title, change font/colour/size, drag the title around — the
  preview updates and `style_dict()` carries the title style.

## Out of scope

Free size handles / pinch-resize (size stays S/M/L presets), rotation, gradient
colour, per-title animation, and multiple title lines/elements — one title.
