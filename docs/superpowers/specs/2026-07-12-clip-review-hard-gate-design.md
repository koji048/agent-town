# Clip review hard gate + scrollable caption window — design (Phase 1)

**Date:** 2026-07-12
**Status:** Approved (design), pending implementation plan
**Part of:** the clip/caption improvements set (Phase 1 of 4). Later phases —
subtitle safe-zone placement, CapCut-style caption retiming, EP opening title
card — each get their own spec.

## Goal

A clip must never burn unless the owner explicitly approved its subtitles, and
the caption review window's controls must always be reachable. Today two hidden
timers auto-approve a clip when the owner steps away, and the review panel can
render its Burn button off-screen.

## Background — the two leaks

The clip subtitle review has two code paths, and BOTH auto-pass:

1. **Studio path** (`pipeline.gd:307-322`): when the ffmpeg preview can be
   built, the pipeline waits on `clip_review_resolved`. But the studio itself
   emits that signal after a **90-second countdown** (`caption_studio.gd:26`
   `AUTO_SEC`, and `_process` at `caption_studio.gd:272-275` calls
   `_resolve("custom")` when `_auto_left <= 0`). So the clip auto-burns after
   90 s of inactivity.
2. **Fallback path** (`pipeline.gd:324`): when the preview can't be built
   (ffmpeg missing/failing), the pipeline calls `_await_approval`, which
   **auto-approves after 45 seconds** (`pipeline.gd:602-610`). Worse, the
   return value is discarded — even an explicit "No" proceeds to burn.
3. **Legacy path** (`pipeline.gd:442`): same 45 s auto-approve via
   `_await_approval`.

The 45 s auto-approve is intentional for idea/script jobs (documented in
README) and stays. Only the CLIP subtitle review changes.

Separately, the studio panel is a fixed `1300×860` at `position (310,60)`
(`caption_studio.gd:66-67`) with a resize control that scales it to 140%
(`caption_studio.gd:88-96`). Scaled up or on a smaller viewport, the bottom
controls (timeline, Burn button) fall off-screen with no outer scroll.

## Design

### A1 — `_await_approval` gains an auto-approve opt-out

Add a parameter: `func _await_approval(request, preview, allow_auto := true)`.
When `allow_auto` is `false`, remove the 45 s cap so the wait loop runs until
the owner decides (`while not decided[0]:`), and do NOT emit the auto-approve
resolution. When `true`, behaviour is exactly as today. Return value is the
owner's real Yes/No in both cases.

### A2 — Clip fallback path honors the owner (`pipeline.gd:296-345`)

Setting `want_burn = false` at the fallback would NOT skip the burn: the burn
block (`pipeline.gd:326-345`) runs unconditionally as the next statements in the
same `else` branch and never re-checks `want_burn`. So introduce an explicit
guard.

1. At the top of the `else` (want_burn) branch, before the review
   (after `pipeline.gd:295`), add: `var do_burn := true`.
2. In the fallback branch (`pipeline.gd:323-324`), block and honor the result:
   ```gdscript
   else:
       var approved := await _await_approval(request, reviewed, false)
       if not approved:
           do_burn = false
           EventBus.log_line.emit("🛑 Subtitles rejected — no burn. The clean .srt is ready to fix.")
   ```
3. Guard the burn block (`pipeline.gd:326-345`) with `if do_burn:`; in the
   `else`, set `results["burn_note"]` to a "no burn — .srt delivered for manual
   fixing" note (mirrors the existing no-burn message shape).

The studio path never sets `do_burn = false`, so a studio Burn click always
proceeds — in the studio, clicking **Burn** IS the approval. "No" only exists in
the fallback (approval-desk) path, where it delivers the reviewed `.srt` for
manual fixing.

**Known limitation (out of scope):** after A4 removes the auto-timer, the studio
panel's only resolution is the **Burn** button — there is no in-studio "cancel."
For this tool the owner always intends to eventually burn, so this is acceptable;
a studio cancel/close can be a later addition.

### A3 — Legacy clip path blocks (`pipeline.gd:442`)

Change `if not await _await_approval(request, cleaned):` to
`if not await _await_approval(request, cleaned, false):`. Its existing
"No → caption revision" pass is unchanged.

### A4 — Remove the studio's 90 s auto-burn (`caption_studio.gd`)

The studio must wait for an explicit Burn click:
- Delete the `AUTO_SEC` constant use in `_process`: remove the
  `_auto_left -= delta` / `if _auto_left <= 0.0: _resolve("custom")` block
  (`caption_studio.gd:270-276`).
- Repurpose `_auto_label`: instead of the countdown, show a static
  "waiting for your review — press Burn when ready" hint (a new i18n string).
- `_auto_left` / `AUTO_SEC` become unused; remove them and the `open_clip`
  reset line (`caption_studio.gd:251`) to keep the file clean.

The studio only resolves via the Burn button (`_resolve("custom")` at
`caption_studio.gd:215`). The pipeline's studio wait (`pipeline.gd:316`) is
already unbounded, so removing the auto-timer makes the whole path a true gate.

### B — Scrollable caption window (`caption_studio.gd`)

Make every control reachable regardless of scale/viewport:
- Wrap the studio's top-level `root` VBoxContainer in a `ScrollContainer` that
  fills the panel; the `ScrollContainer` becomes the panel's single child.
- Cap the panel's height to the viewport: set
  `custom_minimum_size` height to `min(860, viewport_height - 2*margin)` and let
  the ScrollContainer scroll the content beyond it. Keep the width at 1300 (fits
  1920 wide). Vertical scrollbar appears only when content exceeds the panel.
- The existing inner cue-list ScrollContainer (`caption_studio.gd:192`) stays;
  the outer scroll handles the whole-window overflow (timeline, Burn button).

## Files touched

- **Modify:** `scripts/pipeline.gd` — `_await_approval` signature + 2 call
  sites (A1, A2, A3).
- **Modify:** `scripts/caption_studio.gd` — remove auto-burn, add waiting hint,
  wrap in ScrollContainer, cap height (A4, B).
- **Modify:** `scripts/autoload/i18n.gd` — one new string
  (`studio_waiting`), replacing/alongside `studio_auto`.

## Testing

- **A1 logic (headless-testable):** extend `tools/test_pipeline.gd`'s fake
  renderer so it can decline to answer an `approval_requested`, and assert that
  with `allow_auto = false` the pipeline does NOT auto-resolve within a bounded
  window (the run stays pending until the fake renderer answers). This reuses
  the existing harness pattern. (The full clip flow needs ffmpeg/footage and is
  not headless-testable; A2/A3/A4/B are verified by running the app.)
- **A4 + B (manual, in-app):** launch the town, trigger a clip review, confirm
  the studio no longer counts down/auto-burns, that it waits indefinitely, and
  that the window scrolls to the Burn button at 140% scale.

## Out of scope (later phases)

- Phase 2: subtitle safe-zone placement (raise MarginV out of IG's bottom UI
  band; enforce ≤30 char lines / ≥42 px).
- Phase 3: CapCut/Resolve-style drag-to-retime cue editing.
- Phase 4: EP opening title card (`EPxx : Title`, yellow Anuphan, centered).
