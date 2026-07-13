# Caption size fidelity + interactive placement — design (Phase 2)

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan
**Part of:** clip/caption improvements set (Phase 2 of 4). See
`clip-caption-roadmap`. Phase 1 (hard gate, scroll, one-folder output) is merged.

## Goal

Make the Caption Review Studio truly WYSIWYG: the previewed caption is the
**same size** it will burn, the owner **drags the caption up/down in the preview
to choose where it burns**, and an Instagram safe-zone guide shows where IG's UI
will cover the frame.

## Background

- **Size mismatch.** The preview caption font is
  `SIZES[sel] * PREVIEW_SCALE * 1.9` (`caption_studio.gd:_apply_style`), where
  `PREVIEW_SCALE = 576/1920 = 0.3`. The burn uses `SIZES[sel]` directly on a
  1080×1920 ASS canvas (`preview_maker.gd` ASS_HEADER). The spurious `* 1.9`
  makes the preview ~1.9× larger than the burn. The preview outline is also a
  fixed `8px` vs a proportionally-correct ~1px.
- **No placement control.** The burn `MarginV` is hard-coded `220` in the ASS
  Style line (`preview_maker.gd:23`), and the preview caption is pinned to match
  it (`_cap_label.offset_bottom = -66 = 220 * 0.3`). `220` sits *inside*
  Instagram's bottom ~320px UI band, and the owner cannot change it.

## Design

### A — Size fidelity (`caption_studio.gd:_apply_style`)

- `font_size = int(round(int(SIZES[_size_pick.selected][1]) * PREVIEW_SCALE))` —
  drop the `* 1.9`.
- `outline_size = maxi(1, int(round(3.0 * PREVIEW_SCALE)))` — the burn outline
  is `3` on the 1920 canvas, so ~1px in preview (was a fixed 8).

### B — Parameterize the burn MarginV (`preview_maker.gd`)

- ASS_HEADER Style line: change the literal `...,70,70,220,1` to
  `...,70,70,{margin_v},1`.
- `write_ass`: add `"margin_v": int(style.get("margin_v", 360))` to the
  `.format({...})` dict.
- `burn_custom` already receives `style`; no change there — the studio's
  `style_dict()` will carry `margin_v` (section C).

### C — Interactive vertical placement (`caption_studio.gd`)

- Add state `var _margin_v := 360.0` (burn-canvas px, distance from bottom) and
  constants `const MARGIN_MIN := 120.0`, `const MARGIN_MAX := 1400.0`,
  `const CAP_BAND := 160.0` (preview-px height of the caption's grab band).
- `_place_caption()` positions `_cap_label` from `_margin_v`:
  `offset_bottom = -_margin_v * PREVIEW_SCALE`,
  `offset_top = offset_bottom - CAP_BAND`. Call it from `open_clip` (after
  resetting `_margin_v = 360.0`) and after every drag.
- Make the caption draggable: `_cap_label.mouse_filter = MOUSE_FILTER_STOP`,
  `_cap_label.mouse_default_cursor_shape = CURSOR_VSIZE`, and a `gui_input`
  handler: on left-drag `InputEventMouseMotion`,
  `_margin_v = clampf(_margin_v - ev.relative.y / PREVIEW_SCALE, MARGIN_MIN, MARGIN_MAX)`
  then `_place_caption()`. (Dragging up → `relative.y < 0` → `_margin_v`
  increases → caption rises; matches the burn where larger MarginV = higher.)
- `style_dict()`: add `"margin_v": int(round(_margin_v))` so the chosen position
  flows into `burn_custom` → `write_ass`.

### D — Instagram safe-zone guide (`caption_studio.gd`)

- In the preview `frame_holder`, add a dim overlay showing IG's bottom UI band:
  a `ColorRect` anchored `PRESET_BOTTOM_WIDE`, `offset_top = -320.0 * PREVIEW_SCALE`
  (≈ -96), `color = Color(0, 0, 0, 0.35)`, added **after** `_frame_rect` but
  **before** `_cap_label` (so the caption draws on top). A small dim label
  "IG UI" in it is optional.
- Purpose: the owner drags the caption to sit *above* this band.

## WYSIWYG guarantee

After A–D: preview font size, outline, and vertical position all equal the
burned values scaled by `PREVIEW_SCALE`, and the position the owner sets in the
preview is exactly the `MarginV` that burns.

## Scope

- Governs the studio Burn path (`burn_custom`) + preview only. The external
  `reel.sh` fallback burn keeps its own styling/placement (out of scope).
- Not changing caption *wrapping* / line length (a later concern).

## Files touched

- **Modify:** `scripts/autoload/preview_maker.gd` — ASS_HEADER `{margin_v}` +
  `write_ass` param (B).
- **Modify:** `scripts/caption_studio.gd` — size fidelity (A), draggable
  placement + `_margin_v` + `style_dict` (C), safe-zone guide (D).
- **Test:** `tools/test_ass_margin.gd` (new) — headless test that `write_ass`
  emits the given `margin_v` into the ASS Style line (the "position flows to the
  burn" guarantee).

## Testing

- **Headless (B):** `tools/test_ass_margin.gd` writes an ASS with
  `margin_v = 500` and asserts the Style line contains `,500,1` and NOT the old
  `,220,1`; and that a default (no margin_v) yields `,360,1`.
- **Manual (A, C, D):** launch via `AGENT_TOWN_STUDIO`; confirm the caption is
  visibly smaller (true size), can be dragged up/down and stays where dropped,
  the dim IG band shows at the bottom, and `style_dict()`/burn use the chosen
  MarginV.
