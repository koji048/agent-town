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
already has font/size/colour pickers + a draggable caption (Phase 2).

**A selection model (a `[Caption]/[Title]` toggle sharing the caption's text
field + style controls) was prototyped and REJECTED as confusing** — one text
box editing two different things, and it wasn't clear which element the controls
acted on. The approved design gives the title its **own dedicated controls**.

## Design

### A — Dedicated "EP Title" strip (`caption_studio.gd`)

A self-contained title editor at the **top of the right column, above the cue
list** — always visible, separate from the caption controls (no toggle, no
shared state):
- `EP Title:` label + a `LineEdit` for the title **text** (`_title_edit`), a font
  `OptionButton` (`_title_font_pick`, the same 25 fonts), and a small colour
  control (a `ColorPickerButton` `_title_color_pick`, default yellow). Changing
  any of them updates the title immediately.
- The caption's cue list / edit box / font-size-colour bar stay exactly as they
  are. The two editors never share a widget, so there is no ambiguity about which
  element you're editing.

### B — Title state + 2D drag (`caption_studio.gd`)

- Title state: `_title_text` (default = the `EPxx : topic` passed to `open_clip`,
  fully editable), `_title_font_idx` (default Anuphan), `_title_color`
  (default yellow `Color(1,0.9,0.15)`), and 2D position `_title_x`, `_title_y` in
  **burn-canvas px** (default centre `540, 960`).
- The `_title_label` in the preview is a draggable text box: `MOUSE_FILTER_STOP`
  + `gui_input`; on left-drag, `_title_x += dx / PREVIEW_SCALE`,
  `_title_y += dy / PREVIEW_SCALE` (clamped to the 1080×1920 canvas), repositioned
  centred on `(_title_x, _title_y) * PREVIEW_SCALE`. (The drag delta is divided by
  `PREVIEW_SCALE`, and the studio's 1.2 zoom is already accounted for because
  `gui_input.relative` arrives in the control's local space.)
- `_apply_title_style()` sets the `_title_label`'s font (`FONTS[_title_font_idx]`),
  colour (`_title_color`) and size (≈`86 * PREVIEW_SCALE`), and `_place_title()`
  positions it.
- The title label is visible over its real window (`_t < TITLE_SEC`) and stays
  shown while the studio is open so it's always editable/draggable (its burn
  timing is unchanged — first 2.5 s).

### C — Burn: dynamic Title style + \pos (`preview_maker.gd`)

- `ASS_HEADER` `Title` style becomes parameterised:
  `Style: Title,{title_font},{title_size},{title_primary},&H000000FF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,4,0,5,60,60,60,1`
  (Alignment 5 = the \pos anchor is the text centre). Defaults in the format dict
  keep the old look when unset.
- `write_ass` emits the title event with the **edited** title text and a `\pos`
  override at the chosen centre:
  `Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,{\pos(%d,%d)}%s`
  where `%s` = `style["title_text"]` (the user's edited text) and the position is
  `style["title_x"]`, `style["title_y"]` (defaults 540, 960). If `title_text` is
  empty it falls back to `EP%02d : %s` from `style["ep"]/["title"]` (backward
  compatible / non-studio path). Emitted only when the resulting text is non-empty.

### D — Studio → burn flow (`caption_studio.gd` `style_dict`)

`style_dict()` gains the title fields so they reach `burn_custom` → `write_ass`:
`title_text` (the edited text), `title_font` (family), `title_size` (px),
`title_primary` (ASS BGR from the title colour, via `_ass_color`), `title_x`,
`title_y`. The pipeline still injects `style["ep"]/["title"]` as the fallback text
source. The studio's `_title_text` defaults to the `EPxx : topic` passed via
`open_clip`, so an untouched title burns exactly as Phase 4 did.

## Files touched

- **Modify:** `scripts/caption_studio.gd` — dedicated EP Title strip (text/font/
  colour), title state, 2D title drag, `_apply_title_style`/`_place_title`,
  `style_dict` additions. Removes the rejected `[Caption]/[Title]` toggle prototype.
- **Modify:** `scripts/autoload/preview_maker.gd` — parameterised `Title` style +
  `\pos` + edited-text title Dialogue.
- **(Dev)** `scripts/main.gd` — `AGENT_TOWN_STUDIO` dev hook already extended to
  pass a title (3rd `|` field) for previewing.

## Testing

- **Headless:** extend `tools/test_ass_title.gd` — `write_ass` with a title style
  (`title_font`, `title_size`, `title_primary`, `title_x`, `title_y`) emits the
  dynamic `Style: Title,<font>,<size>,<primary>,…` line AND a
  `\pos(x,y)…EP07 : …` event; unchanged (old-look) defaults still valid.
- **Manual (studio):** launch via the extended `AGENT_TOWN_STUDIO` hook with a
  title; in the EP Title strip edit the text / change font+colour, drag the title
  around the preview — the
  preview updates and `style_dict()` carries the title style.

## Out of scope

Free size handles / pinch-resize (size stays S/M/L presets), rotation, gradient
colour, per-title animation, and multiple title lines/elements — one title.
