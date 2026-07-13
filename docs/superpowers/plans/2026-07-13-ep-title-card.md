# EP Opening Title Card — Implementation Plan (Phase 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Every reel opens with `EPxx : <title>` — yellow Anuphan, centered — for the first ~2.5 s, burned into the video AND shown in the studio preview.

**Architecture:** A second ASS `Title` style + one conditional Dialogue in `write_ass` (driven by `style["ep"]`/`style["title"]` the pipeline injects); the studio shows a matching centered label over the opening; ep+title are plumbed to the studio via the request.

**Tech Stack:** Godot 4 (installed 4.7; CI 4.6.1), GDScript, libass/ASS.

## Global Constraints

- Card = **yellow (`&H0000FFFF` BGR) Anuphan, Alignment 5 (middle-center), bold**, ~100 px on the 1080×1920 burn canvas; text `EP%02d : <title>` for **0:00–2.5 s**.
- **Backward compatible:** with no `ep`/`title` in the style dict, `write_ass` output is unchanged (no title event). Preview title defaults to "" (hidden).
- Governs the studio-Burn path (`burn_custom`) + preview only; the `reel.sh` fallback burn is external/unchanged.
- Preview size derives from `PREVIEW_SCALE` (≈30 px) to match the burn.

## File Structure

- **`scripts/autoload/preview_maker.gd`** (modify) — Title style + title Dialogue (Task 1).
- **`tools/test_ass_title.gd`** (new) — headless test of the title event (Task 1).
- **`scripts/pipeline.gd`** + **`scripts/main.gd`** (modify) — feed ep/title to burn + studio (Task 2).
- **`scripts/caption_studio.gd`** (modify) — preview title label (Task 3).

---

### Task 1: Burn the title card (ASS style + Dialogue) + test

**Files:**
- Modify: `scripts/autoload/preview_maker.gd` (ASS_HEADER ~line 23; `write_ass` ~line 175)
- Test: `tools/test_ass_title.gd` (new)

**Interfaces:**
- Produces: `write_ass(cues, style, path)` emits a `Title`-styled Dialogue `EP%02d : <title>` for 0:00–2.5 s when `style["ep"] > 0` and `style["title"]` is non-empty.

- [ ] **Step 1: Write the failing test**

Create `tools/test_ass_title.gd`:

```gdscript
## Headless test: PreviewMaker.write_ass emits the EP title Dialogue when the
## style carries ep+title, and nothing when it doesn't. Run:
##   godot --headless --path . -s res://tools/test_ass_title.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var pm: Node = root.get_node("/root/PreviewMaker")
	var cues := [{"start": 0.0, "end": 1.0, "text": "x"}]
	var p := ProjectSettings.globalize_path("user://_tmp_title.ass")

	pm.write_ass(cues, {"ep": 7, "title": "hi there"}, p)
	var t := FileAccess.get_file_as_string(p)
	_check("Title style in header", t.contains("Style: Title,Anuphan"))
	_check("EP07 title event present", t.contains(",Title,,0,0,0,,EP07 : hi there"))

	pm.write_ass(cues, {}, p)   # no ep/title -> no title event
	t = FileAccess.get_file_as_string(p)
	_check("no title event without ep/title", not t.contains(",Title,,0,0,0,,"))

	DirAccess.remove_absolute(p)
	print("\n=== ass title tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
```

- [ ] **Step 2: Run — expect failure**

Run: `godot --headless --path . -s res://tools/test_ass_title.gd`
Expected: FAIL — no `Title` style, no title event yet. RED.

- [ ] **Step 3: Add the `Title` ASS style**

In `scripts/autoload/preview_maker.gd`, the `ASS_HEADER` const has the `Default` style line (line 23). Add a `Title` style line immediately after it:
```
Style: Default,{font},{size},{primary},&H000000FF,{outline_col},&H78000000,0,0,0,0,100,100,0,0,1,{outline},1,2,70,70,{margin_v},1
Style: Title,Anuphan,100,&H0000FFFF,&H00000000,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,4,0,5,60,60,60,1
```
(Anuphan, size 100, yellow primary `&H0000FFFF`, black outline, bold `-1`, Alignment 5 = middle-center, outline 4. It has no `{}` placeholders, so `ASS_HEADER.format(...)` passes it through untouched.)

- [ ] **Step 4: Emit the title Dialogue in `write_ass`**

In `write_ass`, right after the `f.store_string(ASS_HEADER.format({...}))` block and before the `for c in cues:` loop, add:
```gdscript
	var ep: int = int(style.get("ep", 0))
	var ttl: String = str(style.get("title", ""))
	if ep > 0 and not ttl.is_empty():
		f.store_string("Dialogue: 0,0:00:00.00,0:00:02.50,Title,,0,0,0,,EP%02d : %s\n" % [
			ep, ttl.left(60).replace("\n", " ")])
```

- [ ] **Step 5: Run — expect all pass**

Run: `godot --headless --path . -s res://tools/test_ass_title.gd`
Expected: `=== ass title tests: 3 passed, 0 failed ===`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/preview_maker.gd tools/test_ass_title.gd
git commit -m "feat: burn an EPxx : title opening card (ASS Title style + Dialogue)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Feed ep + title to the burn and the studio

**Files:**
- Modify: `scripts/pipeline.gd` (`_run_clip_reels`: `request["_ep"]` before the review emit ~line 318; `style["ep"]/["title"]` before `burn_custom` ~line 340)
- Modify: `scripts/main.gd` (the `clip_review_requested` handler ~line 240)

**Interfaces:**
- Consumes: `write_ass` reading `style["ep"]/["title"]` (Task 1); `open_clip(srt, frames, title)` (Task 3).

- [ ] **Step 1: Carry the EP number on the request (for the preview)**

In `scripts/pipeline.gd`, `_run_clip_reels`, just before
`EventBus.clip_review_requested.emit(request, srt_path, prev_dir)`, add:
```gdscript
				request["_ep"] = ep
```

- [ ] **Step 2: Inject ep + title into the burn style**

In the `if action == "custom":` burn branch, after
`var cues: Array = PreviewMaker.parse_srt(FileAccess.get_file_as_string(srt_path))`
and before `r = await PreviewMaker.burn_custom(footage, cues, style, mp4)`, add:
```gdscript
					style["ep"] = ep
					style["title"] = topic
```

- [ ] **Step 3: Build the title in the studio-open handler**

In `scripts/main.gd`, the `clip_review_requested` handler currently reads:
```gdscript
	EventBus.clip_review_requested.connect(func(_req: Dictionary, srt: String, prev: String) -> void:
		_studio.open_clip(srt, prev))
```
Change it to build `EPxx : <topic>` from the request and pass it in:
```gdscript
	EventBus.clip_review_requested.connect(func(req: Dictionary, srt: String, prev: String) -> void:
		var ep := int(req.get("_ep", 0))
		var ttl := ("EP%02d : %s" % [ep, str(req.get("topic", ""))]) if ep > 0 else ""
		_studio.open_clip(srt, prev, ttl))
```

- [ ] **Step 4: Verify it compiles (studio param exists after Task 3 — expected order)**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -1`
Expected: `all checks passed`. (`open_clip`'s 3rd arg is added in Task 3; if Task 3 isn't done yet, this call errors — do Task 3 before this compile check, or accept the RED until Task 3. Recommended: implement Task 3 first, then this compile passes.)

- [ ] **Step 5: Commit** (after Task 3 compiles clean)

```bash
git add scripts/pipeline.gd scripts/main.gd
git commit -m "feat: feed EP number + title into the burn and the studio preview

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Studio preview title card

**Files:**
- Modify: `scripts/caption_studio.gd` (state; `_ready` after `frame_holder.add_child(_cap_label)` ~line 157; `open_clip` ~line 316; `_show_time` ~line 385)

**Interfaces:**
- Produces: `open_clip(srt, frames, title := "")` shows a centered yellow title over the first `TITLE_SEC` seconds of the preview.

- [ ] **Step 1: Add state**

Near the other consts/vars in `scripts/caption_studio.gd`:
```gdscript
const TITLE_SEC := 2.5
```
```gdscript
var _title_label: Label
var _title_text := ""
```

- [ ] **Step 2: Build the centered title label**

In `_ready`, right after `frame_holder.add_child(_cap_label)` and `_place_caption()`, add:
```gdscript
	# EP opening title card — centered yellow Anuphan, shown over the first
	# TITLE_SEC seconds (matches the burn)
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tls := LabelSettings.new()
	var tfont := FontFile.new()
	tfont.load_dynamic_font("res://assets/fonts/Anuphan.ttf")
	tls.font = tfont
	tls.font_size = int(round(100.0 * PREVIEW_SCALE))
	tls.font_color = Color(1.0, 0.9, 0.15)
	tls.outline_size = 4
	tls.outline_color = Color(0, 0, 0)
	_title_label.label_settings = tls
	_title_label.visible = false
	frame_holder.add_child(_title_label)
```

- [ ] **Step 3: Accept the title in `open_clip`**

Change the signature `func open_clip(srt_path: String, frames_dir: String) -> void:` to:
```gdscript
func open_clip(srt_path: String, frames_dir: String, title := "") -> void:
```
and near the top of its body (e.g. right after the first line), set the title:
```gdscript
	_title_text = title
	if _title_label:
		_title_label.text = title
```

- [ ] **Step 4: Toggle visibility in `_show_time`**

In `_show_time`, after `_cap_label.text = _cue_text_at(_t)`, add:
```gdscript
	if _title_label:
		_title_label.visible = _t < TITLE_SEC and not _title_text.is_empty()
```

- [ ] **Step 5: Verify compile + Task 1 test still green**

```bash
godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -1     # all checks passed
godot --headless --path . -s res://tools/test_ass_title.gd             # 3 passed
```

- [ ] **Step 6: Verify in the running studio**

```bash
printf '1\n00:00:00,000 --> 00:00:03,000\nfirst line\n\n2\n00:00:03,000 --> 00:00:06,000\nsecond\n' > /tmp/at_p4.srt
mkdir -p /tmp/at_p4_frames
AGENT_TOWN_STUDIO="/tmp/at_p4.srt|/tmp/at_p4_frames" /Applications/Godot.app/Contents/MacOS/Godot --path . >/tmp/at_p4.log 2>&1 &
```
(The dev hook opens the studio with no title, so the card won't show via `AGENT_TOWN_STUDIO` unless the hook is extended — acceptable; the real path passes the title from `main.gd`. Primary confirmation: no `SCRIPT ERROR`, studio opens. To see the card, temporarily call `_studio.open_clip(srt, prev, "EP07 : demo")` or scrub to t<2.5 with a title set.)

- [ ] **Step 7: Commit**

```bash
git add scripts/caption_studio.gd
git commit -m "feat: studio preview shows the EP title card over the opening

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **Task order:** do Task 1 (burn+test), then **Task 3 before Task 2's compile step** — Task 2's `open_clip(srt, prev, ttl)` call needs Task 3's 3rd parameter to exist. (Commit order can still be 1→2→3; just run the compile check after Task 3.)
- **WYSIWYG:** preview font `100*PREVIEW_SCALE` ≈ 30 px centered mirrors the burn's Alignment-5 100 px; the 2.5 s window matches the ASS event end.
- **Backward compatible:** no ep/title → no ASS title event and a hidden preview label; idle (non-clip) jobs never set `_ep`, so nothing changes for them.
- **Out of scope:** the `reel.sh` fallback title, animated intros, configurable title style.
