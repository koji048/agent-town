# Caption Size Fidelity + Interactive Placement — Implementation Plan (Phase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Caption Review Studio true WYSIWYG — previewed caption size/outline match the burn, the owner drags the caption up/down in the preview to set where it burns, and an Instagram safe-zone guide shows where IG's UI covers the frame.

**Architecture:** Two changes. (1) Fix the preview font math and parameterize the burn `MarginV` in the ASS style, with a headless test proving the chosen margin reaches the ASS. (2) Add an interactive drag control + `_margin_v` state + safe-zone overlay in `caption_studio.gd`, verified by running the studio via `AGENT_TOWN_STUDIO`.

**Tech Stack:** Godot 4 (installed 4.7; CI floor 4.6.1), GDScript, headless `SceneTree` test scripts.

## Global Constraints

- `PREVIEW_SCALE = 576/1920 = 0.3` — the single scale that maps burn-canvas px ↔ preview px. Every preview↔burn number derives from it.
- Governs the studio Burn path (`burn_custom` → `write_ass`) + the preview only. The external `reel.sh` fallback burn is out of scope.
- Engine floor 4.3 / CI 4.6.1; in a `-s` SceneTree test script reference autoloads via `root.get_node("/root/Name")` (see `tools/ci_check.gd`).
- No new dependencies; mirror the existing headless-test convention.
- Default caption position `MarginV = 360` (just clears Instagram's ~320px bottom UI band); owner-draggable, clamped to `[120, 1400]`.

---

## File Structure

- **`scripts/autoload/preview_maker.gd`** (modify) — parameterize the ASS `MarginV` (Task 1).
- **`scripts/caption_studio.gd`** (modify) — preview size fidelity (Task 1); draggable placement + safe-zone guide (Task 2).
- **`tools/test_ass_margin.gd`** (new) — headless test that `write_ass` emits the chosen `margin_v` (Task 1).

---

### Task 1: WYSIWYG size + parameterized burn MarginV

**Files:**
- Modify: `scripts/autoload/preview_maker.gd` (ASS_HEADER line 23; `write_ass` format dict lines 175-181)
- Modify: `scripts/caption_studio.gd` (`_apply_style`, the `font_size`/`outline_size` lines)
- Test: `tools/test_ass_margin.gd` (new)

**Interfaces:**
- Produces: `write_ass(cues, style, path)` honors `style["margin_v"]` (default 360) in the ASS Style line.

- [ ] **Step 1: Write the failing test**

Create `tools/test_ass_margin.gd`:

```gdscript
## Headless test: PreviewMaker.write_ass emits the chosen MarginV into the ASS
## style line (the "where you place it is where it burns" guarantee). Run:
##   godot --headless --path . -s res://tools/test_ass_margin.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pm: Node = root.get_node("/root/PreviewMaker")
	var cues := [{"start": 0.0, "end": 1.0, "text": "hi"}]
	var p := ProjectSettings.globalize_path("user://_tmp_margin.ass")

	pm.write_ass(cues, {"margin_v": 500}, p)
	var t := FileAccess.get_file_as_string(p)
	_check("chosen margin 500 in style line", t.contains("70,70,500,1"))
	_check("old hardcoded 220 is gone", not t.contains("70,70,220,1"))

	pm.write_ass(cues, {}, p)   # no margin_v -> default 360
	t = FileAccess.get_file_as_string(p)
	_check("default margin 360 when unset", t.contains("70,70,360,1"))

	DirAccess.remove_absolute(p)
	print("\n=== ass margin tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
```

- [ ] **Step 2: Run the test — expect failure**

Run: `godot --headless --path . -s res://tools/test_ass_margin.gd`
Expected: FAIL — the ASS still hard-codes `220`, so "chosen margin 500" and "default 360" fail, and "old 220 gone" fails. RED.

- [ ] **Step 3: Parameterize the ASS MarginV**

In `scripts/autoload/preview_maker.gd`, change the ASS_HEADER Style line (line 23) from ending `...,70,70,220,1` to `...,70,70,{margin_v},1`. The full line becomes:
```
Style: Default,{font},{size},{primary},&H000000FF,{outline_col},&H78000000,0,0,0,0,100,100,0,0,1,{outline},1,2,70,70,{margin_v},1
```

In `write_ass` (lines 175-181), add the `margin_v` key to the `.format({...})` dict:
```gdscript
	f.store_string(ASS_HEADER.format({
		"font": str(style.get("font_name", "Anuphan")),
		"size": int(style.get("size", 72)),
		"primary": str(style.get("primary", "&H00FFFFFF")),
		"outline_col": str(style.get("outline_col", "&H00000000")),
		"outline": 3,
		"margin_v": int(style.get("margin_v", 360)),
	}))
```

- [ ] **Step 4: Run the test — expect all pass**

Run: `godot --headless --path . -s res://tools/test_ass_margin.gd`
Expected: `=== ass margin tests: 3 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Fix the preview size + outline (true WYSIWYG)**

In `scripts/caption_studio.gd`, `_apply_style()`, change the font size line from:
```gdscript
	ls.font_size = int(round(int(SIZES[_size_pick.selected][1]) * PREVIEW_SCALE * 1.9))
```
to:
```gdscript
	ls.font_size = int(round(int(SIZES[_size_pick.selected][1]) * PREVIEW_SCALE))
```
and the outline line from:
```gdscript
	ls.outline_size = 8
```
to (the burn outline is 3 on the 1920 canvas → ~1px in the 0.3-scale preview):
```gdscript
	ls.outline_size = maxi(1, int(round(3.0 * PREVIEW_SCALE)))
```

- [ ] **Step 6: Verify it compiles cleanly**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3`
Expected: `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/preview_maker.gd scripts/caption_studio.gd tools/test_ass_margin.gd
git commit -m "feat: caption preview matches burn size + parameterized burn MarginV

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Interactive drag-to-place caption + Instagram safe-zone guide

**Files:**
- Modify: `scripts/caption_studio.gd` (constants + `_margin_v`; `_cap_label` creation; new `_place_caption`; `open_clip`; `style_dict`; safe-zone `ColorRect`)

**Interfaces:**
- Consumes: `write_ass` honoring `style["margin_v"]` (Task 1).
- Produces: `style_dict()` includes `"margin_v"`, so `burn_custom` burns at the dragged position.

- [ ] **Step 1: Add placement state + constants**

In `scripts/caption_studio.gd`, near the other `const`s at the top (after `const PREVIEW_SCALE ...`), add:
```gdscript
const MARGIN_MIN := 120.0
const MARGIN_MAX := 1400.0
const CAP_BAND := 160.0   # preview-px height of the caption's grab band
```
And near the other state vars (e.g. after `var _scale_idx := 0`), add:
```gdscript
var _margin_v := 360.0    # burn-canvas px from the bottom; owner-draggable
```

- [ ] **Step 2: Add the safe-zone guide + make the caption draggable**

In `_ready`, the `_cap_label` block currently reads:
```gdscript
	_cap_label = Label.new()
	_cap_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap_label.offset_top = -170
	_cap_label.offset_bottom = -66  # MarginV 220 * preview scale
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame_holder.add_child(_cap_label)
```
Replace it with (adds the IG guide BEFORE the caption, drops the hard-coded offsets in favor of `_place_caption`, and wires the drag):
```gdscript
	# Instagram safe-zone guide: a dim band over the bottom ~320px (burn) the
	# app UI covers — drag the caption to sit ABOVE it. Ignores mouse so it
	# never blocks the caption drag.
	var ig_guide := ColorRect.new()
	ig_guide.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ig_guide.offset_top = -320.0 * PREVIEW_SCALE
	ig_guide.color = Color(0, 0, 0, 0.35)
	ig_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_holder.add_child(ig_guide)
	_cap_label = Label.new()
	_cap_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# drag the caption up/down to choose where it burns (CapCut-style)
	_cap_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_cap_label.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_cap_label.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var dy := (ev as InputEventMouseMotion).relative.y
			_margin_v = clampf(_margin_v - dy / PREVIEW_SCALE, MARGIN_MIN, MARGIN_MAX)
			_place_caption())
	frame_holder.add_child(_cap_label)
	_place_caption()
```

- [ ] **Step 3: Add `_place_caption` and reset it per clip**

Add this method (near `_apply_style`):
```gdscript
## Position the preview caption from _margin_v (burn px), so what you see is
## exactly where it burns.
func _place_caption() -> void:
	_cap_label.offset_bottom = -_margin_v * PREVIEW_SCALE
	_cap_label.offset_top = _cap_label.offset_bottom - CAP_BAND
```

In `open_clip`, where the per-clip state resets (near `_playing = false` / `_tex_cache.clear()`), add:
```gdscript
	_margin_v = 360.0
	_place_caption()
```

- [ ] **Step 4: Carry the chosen margin into the burn**

In `style_dict()`, add the `margin_v` key so `burn_custom` → `write_ass` uses it. Change:
```gdscript
func style_dict() -> Dictionary:
	return {
		"font_name": str(FONTS[_font_pick.selected][0]),
		"size": int(SIZES[_size_pick.selected][1]),
		"primary": str(COLORS[_color_idx][1]),
		"outline_col": str(COLORS[_color_idx][2]),
	}
```
to:
```gdscript
func style_dict() -> Dictionary:
	return {
		"font_name": str(FONTS[_font_pick.selected][0]),
		"size": int(SIZES[_size_pick.selected][1]),
		"primary": str(COLORS[_color_idx][1]),
		"outline_col": str(COLORS[_color_idx][2]),
		"margin_v": int(round(_margin_v)),
	}
```

- [ ] **Step 5: Verify it compiles cleanly**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3`
Expected: `all checks passed`.

- [ ] **Step 6: Verify in the running studio**

```bash
printf '1\n00:00:00,000 --> 00:00:03,000\nsample caption line to place\n\n2\n00:00:03,000 --> 00:00:06,000\nsecond line\n' > /tmp/at_p2.srt
mkdir -p /tmp/at_p2_frames
AGENT_TOWN_STUDIO="/tmp/at_p2.srt|/tmp/at_p2_frames" /Applications/Godot.app/Contents/MacOS/Godot --path . >/tmp/at_p2.log 2>&1 &
```
Confirm by observation:
- The caption is visibly **smaller** than before (true burn size, not ~1.9×).
- A dim band covers the bottom of the preview frame (the IG guide).
- Dragging the caption up/down moves it and it **stays** where dropped (cursor shows a vertical-resize shape over it).
- Quit with Cmd+Q.
(If observation isn't possible, at minimum grep the log for no `SCRIPT ERROR`.)

- [ ] **Step 7: Commit**

```bash
git add scripts/caption_studio.gd
git commit -m "feat: drag the caption to place it + Instagram safe-zone guide

The studio caption is draggable up/down; its position flows through style_dict
-> write_ass as the burn MarginV, so where you drop it is where it burns. A dim
band marks Instagram's bottom UI zone to drag clear of.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **WYSIWYG check:** after both tasks, preview `font_size = size*0.3`, `outline ≈ 1`, and caption vertical position `= margin_v*0.3` — all the burn values scaled by `PREVIEW_SCALE`. The dragged `_margin_v` is exactly what `write_ass` emits (Task 1 test proves the ASS side).
- **Drag direction:** dragging up gives `relative.y < 0`, so `_margin_v` increases and the caption rises — matching ASS where a larger MarginV sits higher. Keep the `- dy` sign.
- **Don't let the guide block the drag:** the `ig_guide` ColorRect must keep `mouse_filter = MOUSE_FILTER_IGNORE`.
- **Out of scope (later):** caption line-length/wrapping, the `reel.sh` fallback placement, per-cue (vs whole-clip) positioning.
