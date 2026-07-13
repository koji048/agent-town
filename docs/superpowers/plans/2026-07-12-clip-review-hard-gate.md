# Clip Review Hard Gate + Scrollable Caption Window — Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A clip can only burn after the owner explicitly approves its subtitles (remove both auto-pass timers), and every control in the Caption Review Studio stays reachable (add scrolling).

**Architecture:** Three focused changes: (1) `_await_approval` in `scripts/pipeline.gd` gains an `allow_auto` opt-out so clip approvals block; (2) the clip flows honor the owner's answer via a `do_burn` guard; (3) `scripts/caption_studio.gd` loses its 90-second auto-burn and gains an outer `ScrollContainer`. A small self-contained headless test covers the core approval-gate behavior; the studio changes are verified by launching the app via the existing `AGENT_TOWN_STUDIO` dev hook.

**Tech Stack:** Godot 4 (runs on installed 4.7; CI floor 4.6.1), GDScript, headless `SceneTree` test scripts.

## Global Constraints

- Only the CLIP subtitle review changes. The idea/script approval keeps the documented 45-second auto-approve — do not change its behavior.
- Engine floor 4.3 / CI container 4.6.1; installed engine is 4.7. In a `-s` SceneTree test script, reference autoloads via `root.get_node("/root/Name")` and instantiate scripts via `load(path).new()` (bare `Config`/`Pipeline` identifiers fail to resolve at compile time in that context — see `tools/ci_check.gd`, `tools/provider_test.gd`).
- No new dependencies; no test framework — mirror the `tools/ci_check.gd` convention.
- The test harness `tools/test_pipeline.gd` does NOT exist on this branch (it is on the test-suite branch/PR #1). Task 1's test is a NEW standalone file.
- Nothing may auto-approve a clip: after this change, a clip burns only after `approval_resolved(true)` (fallback) or a studio **Burn** click.

---

## File Structure

- **`scripts/pipeline.gd`** (modify) — `_await_approval` signature + wait loop (Task 1); the clip reels fallback `do_burn` guard + legacy call site (Task 2).
- **`tools/test_approval_gate.gd`** (new) — standalone headless test for `_await_approval`'s `allow_auto` behavior (Task 1).
- **`scripts/caption_studio.gd`** (modify) — remove the 90s auto-burn, add a static waiting hint, wrap content in a `ScrollContainer` capped to the viewport (Task 3).
- **`scripts/autoload/i18n.gd`** (modify) — replace the `studio_auto` countdown string with a static `studio_waiting` string (Task 3).
- **`scripts/autoload/output_writer.gd`** (modify) — add `write_clip_extras` (Task 4).
- **`tools/test_clip_extras.gd`** (new) — standalone headless test for `write_clip_extras` (Task 4).

---

### Task 1: `_await_approval` auto-approve opt-out + headless gate test

**Files:**
- Modify: `scripts/pipeline.gd:592-610` (the `_await_approval` function)
- Test: `tools/test_approval_gate.gd` (new)

**Interfaces:**
- Produces: `_await_approval(request: Dictionary, preview: String, allow_auto := true) -> bool`. When `allow_auto == false`, the wait loop has no timeout and never auto-approves; it returns the owner's real Yes/No. When `true`, behavior is exactly as today (45s → auto-approve `true`).

- [ ] **Step 1: Write the failing test**

Create `tools/test_approval_gate.gd`:

```gdscript
## Headless test for Pipeline._await_approval's allow_auto opt-out. Run:
##   godot --headless --path . -s res://tools/test_approval_gate.gd
## Verifies: with allow_auto=false the call BLOCKS until the owner answers and
## returns that answer; with allow_auto=true it auto-approves (legacy). Exits
## non-zero on any failure.
extends SceneTree

var _passes := 0
var _fails := 0
var _event_bus: Node


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	Engine.time_scale = 100.0   # collapse the 45s legacy timeout
	_event_bus = root.get_node("/root/EventBus")
	var pipe: Node = load("res://scripts/pipeline.gd").new()
	root.add_child(pipe)

	await _t_blocks_until_answered(pipe)
	await _t_honors_no(pipe)
	await _t_auto_approves_when_allowed(pipe)

	print("\n=== approval gate tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


# allow_auto=false: must NOT resolve on its own; resolves to true on Yes
func _t_blocks_until_answered(pipe: Node) -> void:
	print("\n[1] allow_auto=false blocks until answered, honors Yes")
	var done := [false, false]
	var run := func() -> void:
		var res: bool = await pipe._await_approval({"topic": "t1"}, "preview", false)
		done[0] = true
		done[1] = res
	run.call()
	for i in 40:                      # ~40 frames with no answer
		await process_frame
	_check("1: still waiting (no auto-approve)", not done[0])
	_event_bus.approval_resolved.emit(true)
	await process_frame
	await process_frame
	_check("1: resolved true after Yes", done[0] and done[1] == true)


# allow_auto=false: a No is honored (returns false)
func _t_honors_no(pipe: Node) -> void:
	print("\n[2] allow_auto=false honors No")
	var done := [false, true]
	var run := func() -> void:
		var res: bool = await pipe._await_approval({"topic": "t2"}, "preview", false)
		done[0] = true
		done[1] = res
	run.call()
	for i in 10:
		await process_frame
	_event_bus.approval_resolved.emit(false)
	await process_frame
	await process_frame
	_check("2: resolved false after No", done[0] and done[1] == false)


# allow_auto=true (default/legacy): auto-approves without an answer
func _t_auto_approves_when_allowed(pipe: Node) -> void:
	print("\n[3] allow_auto=true auto-approves (legacy behavior kept)")
	var done := [false, false]
	var run := func() -> void:
		var res: bool = await pipe._await_approval({"topic": "t3"}, "preview", true)
		done[0] = true
		done[1] = res
	run.call()
	for i in 4000:                    # 45s / 0.25 = 180 iters, collapsed by time_scale
		if done[0]:
			break
		await process_frame
	_check("3: auto-approved true with no answer", done[0] and done[1] == true)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
```

- [ ] **Step 2: Run the test — expect failure (param doesn't exist yet)**

Run: `godot --headless --path . -s res://tools/test_approval_gate.gd`
Expected: a compile/runtime error — `_await_approval` currently takes 2 args, so calling with 3 fails (e.g. "Too many arguments" / "Invalid call"). This is the RED state.

- [ ] **Step 3: Implement the `allow_auto` opt-out**

In `scripts/pipeline.gd`, change the `_await_approval` signature (line 592) from:
```gdscript
func _await_approval(request: Dictionary, preview: String) -> bool:
```
to:
```gdscript
func _await_approval(request: Dictionary, preview: String, allow_auto := true) -> bool:
```

Change the wait loop (line 601) from:
```gdscript
	while not decided[0] and waited < 45.0:
```
to:
```gdscript
	while not decided[0] and (not allow_auto or waited < 45.0):
```

Guard the auto-approve block (line 606) from:
```gdscript
	if not decided[0]:
```
to:
```gdscript
	if not decided[0] and allow_auto:
```
(Leave the two lines inside that block unchanged. When `allow_auto` is false the loop only exits once decided, so this block is already unreachable; the guard makes the intent explicit.)

- [ ] **Step 4: Run the test — expect all pass**

Run: `godot --headless --path . -s res://tools/test_approval_gate.gd`
Expected output ends with:
```
  PASS  1: still waiting (no auto-approve)
  PASS  1: resolved true after Yes
  PASS  2: resolved false after No
  PASS  3: auto-approved true with no answer

=== approval gate tests: 4 passed, 0 failed ===
```
Exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/pipeline.gd tools/test_approval_gate.gd
git commit -m "feat: _await_approval gains allow_auto opt-out + headless gate test

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Clip flows honor the owner's answer (no auto-pass)

**Files:**
- Modify: `scripts/pipeline.gd:295-345` (the `_run_clip_reels` review + burn block)
- Modify: `scripts/pipeline.gd:442` (the `_run_clip_legacy` approval call)

**Interfaces:**
- Consumes: `_await_approval(request, preview, allow_auto)` from Task 1.

- [ ] **Step 1: Add the `do_burn` guard and honor the fallback answer**

In `scripts/pipeline.gd`, `_run_clip_reels`, the `else:` (want_burn) branch currently begins at line 295 with a comment and the studio setup. Add a `do_burn` flag as the first statement inside that `else`:

Change (line 295-299):
```gdscript
		else:
			# 3) CAPTION REVIEW STUDIO — the human checks captions the way an
			# editor would in CapCut: filmstrip + audio scrub + style pick.
			# Falls back to the plain approval desk if ffmpeg can't prep.
			var footage := _first_file(batch.path_join("01_FOOTAGE"))
```
to:
```gdscript
		else:
			# a clip burns ONLY on an explicit owner OK (studio Burn click,
			# or Yes at the fallback desk) — no auto-pass
			var do_burn := true
			# 3) CAPTION REVIEW STUDIO — the human checks captions the way an
			# editor would in CapCut: filmstrip + audio scrub + style pick.
			# Falls back to the plain approval desk if ffmpeg can't prep.
			var footage := _first_file(batch.path_join("01_FOOTAGE"))
```

Change the fallback branch (line 323-324) from:
```gdscript
			else:
				await _await_approval(request, reviewed)
```
to:
```gdscript
			else:
				var approved := await _await_approval(request, reviewed, false)
				if not approved:
					do_burn = false
					EventBus.log_line.emit("🛑 Subtitles rejected — no burn. The clean .srt is ready to fix.")
```

- [ ] **Step 2: Guard the burn block with `do_burn`**

Wrap the burn block (lines 326-345) so it only runs when approved. Replace:
```gdscript
			# 4) burn — reel.sh (skill standard) or the studio's chosen style
			var mp4 := ""
			if action == "custom":
				EventBus.log_line.emit("🔥 burn with studio style (1080x1920)...")
				var base := srt_path.get_file().trim_suffix("-clean.srt")
				mp4 = exports.path_join(base + ".mp4")
				var cues: Array = PreviewMaker.parse_srt(FileAccess.get_file_as_string(srt_path))
				r = await PreviewMaker.burn_custom(footage, cues, style, mp4)
				if int(r[1]) != 0 or not FileAccess.file_exists(mp4):
					mp4 = ""
			else:
				EventBus.log_line.emit("🔥 reel.sh burn (1080x1920)...")
				ReelRunner.run(PackedStringArray(["burn"]))
				r = await ReelRunner.finished
				mp4 = ReelRunner.newest_file(exports, ".mp4")
			if not mp4.is_empty():
				results["burn_note"] = "Burned reel: %s\n\n%s" % [mp4.get_file(), str(r[0]).right(300)]
				EventBus.log_line.emit("🎞 Cut file: %s" % mp4.get_file())
			else:
				results["burn_note"] = "(burn produced no mp4 — import the .srt in your editor)\n" + str(r[0]).right(300)
```
with (same body, wrapped in `if do_burn:`, plus an `else` that records the no-burn outcome):
```gdscript
			# 4) burn — reel.sh (skill standard) or the studio's chosen style
			if do_burn:
				var mp4 := ""
				if action == "custom":
					EventBus.log_line.emit("🔥 burn with studio style (1080x1920)...")
					var base := srt_path.get_file().trim_suffix("-clean.srt")
					mp4 = exports.path_join(base + ".mp4")
					var cues: Array = PreviewMaker.parse_srt(FileAccess.get_file_as_string(srt_path))
					r = await PreviewMaker.burn_custom(footage, cues, style, mp4)
					if int(r[1]) != 0 or not FileAccess.file_exists(mp4):
						mp4 = ""
				else:
					EventBus.log_line.emit("🔥 reel.sh burn (1080x1920)...")
					ReelRunner.run(PackedStringArray(["burn"]))
					r = await ReelRunner.finished
					mp4 = ReelRunner.newest_file(exports, ".mp4")
				if not mp4.is_empty():
					results["burn_note"] = "Burned reel: %s\n\n%s" % [mp4.get_file(), str(r[0]).right(300)]
					EventBus.log_line.emit("🎞 Cut file: %s" % mp4.get_file())
				else:
					results["burn_note"] = "(burn produced no mp4 — import the .srt in your editor)\n" + str(r[0]).right(300)
			else:
				results["burn_note"] = "(subtitles rejected — no burn; the clean .srt is delivered for manual fixing)"
```

- [ ] **Step 3: Block the legacy clip approval too**

In `scripts/pipeline.gd`, `_run_clip_legacy`, change line 442 from:
```gdscript
		if not await _await_approval(request, cleaned):
```
to:
```gdscript
		if not await _await_approval(request, cleaned, false):
```
(Its existing "No → caption revision" pass is unchanged.)

- [ ] **Step 4: Verify it compiles cleanly (headless)**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3`
Expected: `all checks passed` (no SCRIPT ERROR). The clip flow itself needs ffmpeg/footage and is not headless-runnable; Task 1's test covers the `_await_approval` behavior these call sites now rely on.

- [ ] **Step 5: Re-run the gate test (guards against regression)**

Run: `godot --headless --path . -s res://tools/test_approval_gate.gd`
Expected: `4 passed, 0 failed`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/pipeline.gd
git commit -m "feat: clip flows never auto-pass — honor the owner's subtitle Yes/No

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Studio — remove the 90s auto-burn, add a waiting hint, and make the window scroll

**Files:**
- Modify: `scripts/autoload/i18n.gd:98` (swap `studio_auto` → `studio_waiting`)
- Modify: `scripts/caption_studio.gd` (remove auto-burn: lines 26, 37, 218-221, 251, 270-276; add scroll: lines 66-67, 224-231)

**Interfaces:** none consumed by later tasks (Phase 1 ends here).

- [ ] **Step 1: Replace the countdown i18n string**

In `scripts/autoload/i18n.gd`, replace the `studio_auto` entry (line 98):
```gdscript
	"studio_auto": {"en": "No touch: burns the current look in %d s", "th": "ไม่กดอะไร จะ burn ตามที่ตั้งไว้ใน %d วิ"},
```
with:
```gdscript
	"studio_waiting": {"en": "Waiting for your review — press Burn when the subtitles look right", "th": "รอคุณตรวจซับอยู่ — กด Burn เมื่อซับพร้อมแล้ว"},
```

- [ ] **Step 2: Remove the auto-burn machinery in caption_studio.gd**

Make these deletions/edits in `scripts/caption_studio.gd`:

(a) Delete the `AUTO_SEC` constant (line 26):
```gdscript
const AUTO_SEC := 90.0
```

(b) Delete the `_auto_left` variable (line 37):
```gdscript
var _auto_left := AUTO_SEC
```

(c) Where `_auto_label` is created in `_ready` (lines 218-221), register a static waiting text. Change:
```gdscript
		_auto_label = Label.new()
		_auto_label.add_theme_font_size_override("font_size", 12)
		_auto_label.modulate = Color(0.75, 0.7, 0.6)
		right.add_child(_auto_label)
```
to:
```gdscript
		_auto_label = Label.new()
		_auto_label.add_theme_font_size_override("font_size", 12)
		_auto_label.modulate = Color(0.75, 0.7, 0.6)
		I18n.reg(_auto_label, "text", "studio_waiting")
		right.add_child(_auto_label)
```

(d) In `open_clip`, delete the reset line (line 251):
```gdscript
	_auto_left = AUTO_SEC
```

(e) In `_process`, delete the auto-burn block (lines 270-276):
```gdscript
	# walk-away: ambient mode survives — burns the CURRENT selections
	# (untouched = Anuphan/M/white, the skill-standard look)
	_auto_left -= delta
	if _auto_left <= 0.0:
		_resolve("custom")
		return
	_auto_label.text = I18n.f("studio_auto", [int(_auto_left)])
```
After this, `_process(delta)` still updates playback/time when `_playing`; `delta` may become unused — if Godot warns about an unused parameter, rename it to `_delta`.

- [ ] **Step 3: Wrap the studio content in a ScrollContainer capped to the viewport**

The cap must live on the **ScrollContainer**, not the panel: a ScrollContainer with a fixed height lets taller content scroll, whereas capping the PanelContainer risks it just growing to the content's ~1050px minimum (no scroll).

(a) Change the panel size (lines 66-67) from:
```gdscript
		position = Vector2(310, 60)
		custom_minimum_size = Vector2(1300, 860)
```
to:
```gdscript
		position = Vector2(310, 40)
		# width fixed; height is driven by the ScrollContainer's cap (Step 3b),
		# so the panel wraps the scroll viewport snugly instead of the ~1050px
		# content that used to overrun the screen
		custom_minimum_size = Vector2(1300, 0)
```

(b) At the end of `_ready`, wrap `root` in a `ScrollContainer` with a fixed viewport height instead of adding it directly. Change (lines 230-231):
```gdscript
		root.add_child(_timeline)
		add_child(root)
		_style_color_btns()
```
to:
```gdscript
		root.add_child(_timeline)
		# a fixed-height viewport: content taller than this scrolls, so the
		# Burn button stays reachable (content is ~1050px; screen may be less)
		var scroll_outer := ScrollContainer.new()
		scroll_outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var vh := DisplayServer.window_get_size().y
		scroll_outer.custom_minimum_size = Vector2(0, minf(920.0, vh - 120.0))
		scroll_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_outer.add_child(root)
		add_child(scroll_outer)
		_style_color_btns()
```

- [ ] **Step 4: Verify it compiles cleanly (headless)**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3`
Expected: `all checks passed`.

- [ ] **Step 5: Verify in the running app (studio dev hook)**

Create a tiny sample SRT and open the studio directly:
```bash
printf '1\n00:00:00,000 --> 00:00:02,000\nline one\n\n2\n00:00:02,000 --> 00:00:04,000\nline two\n' > /tmp/at_test.srt
mkdir -p /tmp/at_test_frames
AGENT_TOWN_STUDIO="/tmp/at_test.srt|/tmp/at_test_frames" godot --path . >/tmp/at_studio.log 2>&1 &
```
Confirm by observation (or screenshot) that:
- The studio opens ~2s after boot and shows the "Waiting for your review…" hint (NOT a countdown).
- It does NOT close/burn on its own after 90s (leave it >90s; it must stay open).
- The window scrolls vertically and the **Burn** button is reachable.
Then quit the app (Cmd+Q). If observation isn't possible in the environment, grep the log: `grep -c "studio" /tmp/at_studio.log` and confirm no `_resolve` auto-fire — but a visual check is preferred.

- [ ] **Step 6: Commit**

```bash
git add scripts/caption_studio.gd scripts/autoload/i18n.gd
git commit -m "feat: caption studio waits for you (no 90s auto-burn) and scrolls

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Clip output consolidation — one clip = one folder

**Files:**
- Modify: `scripts/autoload/output_writer.gd` (add `write_clip_extras`)
- Modify: `scripts/pipeline.gd:361-371` (the `_run_clip_reels` end block)
- Test: `tools/test_clip_extras.gd` (new)

**Interfaces:**
- Produces: `OutputWriter.write_clip_extras(dir_path: String, request: Dictionary, results: Dictionary) -> String` — writes the post caption + working papers INTO `dir_path`; does NOT write `1_สคริปต์.md`/`2_แคปชั่น.srt` (the batch's `-clean.srt` is the script/caption). Returns `dir_path`.

- [ ] **Step 1: Write the failing test**

Create `tools/test_clip_extras.gd`:

```gdscript
## Headless test for OutputWriter.write_clip_extras. Run:
##   godot --headless --path . -s res://tools/test_clip_extras.gd
## Verifies a clip's text deliverables land in ONE folder with NO duplicate
## script/caption files. Exits non-zero on any failure.
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var ow: Node = root.get_node("/root/OutputWriter")
	var abs := ProjectSettings.globalize_path("user://test_clip_extras_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(abs)
	var req := {"topic": "my clip", "_file": "x.json", "_batch": "/b"}
	var res := {
		"publish": "caption text #tag",
		"plan": "the plan",
		"review": "GO",
		"burn_note": "burned ep1.mp4",
		"script": "1\n00:00:00,000 --> 00:00:01,000\nhi",
		"edit": "1\n00:00:00,000 --> 00:00:01,000\nhi",
	}
	ow.write_clip_extras(abs, req, res)

	_check("post caption written (3_โพสต์.txt)", FileAccess.file_exists(abs.path_join("3_โพสต์.txt")))
	_check("NO duplicate script file (1_สคริปต์.md)", not FileAccess.file_exists(abs.path_join("1_สคริปต์.md")))
	_check("NO duplicate caption srt (2_แคปชั่น.srt)", not FileAccess.file_exists(abs.path_join("2_แคปชั่น.srt")))
	_check("request.json in _เบื้องหลัง", FileAccess.file_exists(abs.path_join("_เบื้องหลัง/request.json")))
	_check("plan paper written", FileAccess.file_exists(abs.path_join("_เบื้องหลัง/แผนงานผู้กำกับ.md")))

	_rmrf(abs)
	print("\n=== clip extras tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)


func _rmrf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_rmrf(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Run the test — expect failure (method missing)**

Run: `godot --headless --path . -s res://tools/test_clip_extras.gd`
Expected: runtime error — `write_clip_extras` does not exist on OutputWriter (e.g. "Invalid call. Nonexistent function 'write_clip_extras'"). RED state.

- [ ] **Step 3: Implement `write_clip_extras`**

In `scripts/autoload/output_writer.gd`, add this method (it reuses the existing `BEHIND` constant and `_write` helper):

```gdscript
## Write the town's text deliverables INTO an existing folder (a reels clip's
## 05_EXPORTS) so a clip lands as ONE folder: the real -clean.srt/.mp4 plus the
## post caption and working papers. Deliberately does NOT write a script.md or
## caption.srt — the batch's own -clean.srt IS the clip's script/caption, and
## duplicating it was the "caption and script in different folders" confusion.
func write_clip_extras(dir_path: String, request: Dictionary, results: Dictionary) -> String:
	var behind := dir_path.path_join("_เบื้องหลัง")
	DirAccess.make_dir_recursive_absolute(behind)
	var clean := request.duplicate()
	clean.erase("_file")
	clean.erase("_partial")
	clean.erase("_batch")
	_write(behind.path_join("request.json"), JSON.stringify(clean, "  "))
	var post: String = str(results.get("publish", ""))
	if not post.is_empty():
		_write(dir_path.path_join("3_โพสต์.txt"), post)
	var combined := "# Clip Package — %s\n" % str(request.get("topic", "clip"))
	for stage in BEHIND:
		var text: String = str(results.get(stage, ""))
		if text.is_empty():
			continue
		_write(behind.path_join(BEHIND[stage]), text)
		combined += "\n\n---\n\n## %s\n\n%s" % [str(stage).capitalize(), text]
	var burn: String = str(results.get("burn_note", ""))
	if not burn.is_empty():
		_write(behind.path_join("การเผา.md"), burn)
		combined += "\n\n---\n\n## Burn\n\n%s" % burn
	_write(behind.path_join("รวมทุกขั้น.md"), combined)
	return dir_path
```

- [ ] **Step 4: Run the test — expect all pass**

Run: `godot --headless --path . -s res://tools/test_clip_extras.gd`
Expected output ends with `=== clip extras tests: 5 passed, 0 failed ===`, exit 0.

- [ ] **Step 5: Wire the reels clip flow to write into the batch**

In `scripts/pipeline.gd`, `_run_clip_reels` end block (lines 361-371), the `exports` variable is already in scope (declared at `pipeline.gd:266`). Change:
```gdscript
	results["review"] = "EP%d files live in:\n%s" % [ep, batch]
	request["_batch"] = batch  # so a typed fix can revise the REAL files
	var out_dir: String = OutputWriter.write_package(request, results)
	var done_dest := clip.get_base_dir().path_join("done").path_join(clip.get_file())
	if FileAccess.file_exists(clip):
		DirAccess.rename_absolute(clip, done_dest)
	TaskQueue.finish(request)
	# deliver the REAL folder: the batch 05_EXPORTS, not the town package
	EventBus.request_completed.emit(request, out_dir)
	EventBus.log_line.emit("📦 EP%d -> %s" % [ep, batch.path_join("05_EXPORTS")])
	OS.shell_open(batch.path_join("05_EXPORTS"))
```
to:
```gdscript
	results["review"] = "EP%d files live in:\n%s" % [ep, batch]
	request["_batch"] = batch  # so a typed fix can revise the REAL files
	# one clip = one folder: text deliverables land IN the batch's 05_EXPORTS
	# beside the real -clean.srt and .mp4 (no separate town package copy)
	OutputWriter.write_clip_extras(exports, request, results)
	var done_dest := clip.get_base_dir().path_join("done").path_join(clip.get_file())
	if FileAccess.file_exists(clip):
		DirAccess.rename_absolute(clip, done_dest)
	TaskQueue.finish(request)
	# deliver the REAL folder: the batch 05_EXPORTS
	EventBus.request_completed.emit(request, exports)
	EventBus.log_line.emit("📦 EP%d -> %s" % [ep, exports])
	OS.shell_open(exports)
```

- [ ] **Step 6: Verify it compiles cleanly (headless)**

Run: `godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3`
Expected: `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/output_writer.gd scripts/pipeline.gd tools/test_clip_extras.gd
git commit -m "feat: clips land as one folder — text deliverables into the batch 05_EXPORTS

The reels clip flow wrote a duplicate text package to the git project's
output/ while the real .srt/.mp4 lived in the content-tree batch. Now the post
caption + working papers write into 05_EXPORTS beside them (no duplicate
script.md/caption.srt — the -clean.srt is the script/caption), and
request_completed points at the batch.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **The hard gate is the point:** after Tasks 1–3, verify by reasoning that there is no remaining path where a clip resolves the review without the owner: the studio only emits `clip_review_resolved` from the Burn button (`caption_studio.gd:215`), and both `_await_approval` clip call sites pass `allow_auto=false`.
- **Known limitation (out of scope, documented in the spec):** removing the studio auto-timer leaves the studio with only a Burn button (no cancel). Acceptable for Phase 1.
- **Scroll caveat:** the outer ScrollContainer fixes the 100%-zoom overflow (content ~1050px > screen). At the 140% resize option the whole panel still scales past the screen; a scale-aware cap can be a later refinement.
- **Idea/script approval untouched:** the main pipeline's `_await_approval(request, script)` call (`pipeline.gd:86`) keeps the default `allow_auto=true` — do not add the third argument there.
