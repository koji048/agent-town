# Headless Pipeline Test Suite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the project's first automated contract test over `scripts/pipeline.gd`, pinning its "learned the hard way" reliability behaviour: the happy-path cascade, the quality gate (never ship a blank stage), and park-and-resume-from-checkpoint on a quota trip.

**Architecture:** One standalone headless `SceneTree` script (`tools/test_pipeline.gd`, run via `godot --headless -s`, mirroring `tools/ci_check.gd`). It never loads the 3D world; instead it acts as a **"fake renderer"** — responding to the world-facing EventBus signals the office normally fulfills (`agent_arrived`, `approval_resolved`, `guidance_given`) — and cranks `Engine.time_scale` so the pipeline's fixed wall-clock waits collapse. Three scenarios run sequentially against one reused `Pipeline` instance, in `simulate` mode. One tiny production seam (`Claude.test_hook`) lets tests force a stage to fail.

**Tech Stack:** Godot 4.3, GDScript, headless SceneTree scripts (no test framework, no new dependencies).

## Global Constraints

- Godot engine features floor: **4.3** (from `project.godot`); CI runs the `barichello/godot-ci:4.6.1` container.
- **No new dependencies** — no GUT or other test framework; mirror the existing `tools/ci_check.gd` convention.
- **Exactly one production-code change** — a test-only `Claude.test_hook: Callable` on `scripts/autoload/claude_client.gd`; behaviour must be unchanged when it is unset.
- The test must be **headless-runnable** (`godot --headless -s`) and **deterministic** — force `Config.provider_resolved = "simulate"`, which also skips the Director triage call so the stage set is always `[plan, research, script, edit, publish]` (+ final `review`).
- The harness must **clean up its own side effects** (output dirs it writes, `park_*.json` files it creates) so repeated local runs stay deterministic.
- Exit non-zero on any failure (`quit(1)`), print a `N passed, N failed` summary line.

---

## File Structure

- **`tools/test_pipeline.gd`** (new) — the entire test harness: fake renderer, three scenarios, assertion + cleanup helpers, PASS/FAIL reporting. Single-responsibility: exercise the pipeline headlessly and report.
- **`scripts/autoload/claude_client.gd`** (modify) — add the `test_hook` field + one guard clause at the top of `complete()`. Nothing else changes.
- **`.github/workflows/ci.yml`** (modify) — one new step to run the harness in CI.

---

### Task 1: Harness scaffold + Scenario A (happy path)

Builds the whole fake-renderer infrastructure and proves it can drive a full cascade to completion using pure `simulate` mode. No production change needed here — `simulate` already returns valid text, so the happy path completes without the seam.

**Files:**
- Create: `tools/test_pipeline.gd`

**Interfaces:**
- Consumes (existing, verified): `Pipeline` (global `class_name`, `scripts/pipeline.gd`); autoloads `Config.provider_resolved`, `Config.project_dir()`, `TaskQueue._timer` (Timer), `Claude.limit_until` (int); EventBus signals `request_received(Dictionary)`, `stage_started(String,String,Dictionary)`, `stage_completed(String,String,Dictionary,String)`, `request_completed(Dictionary,String)`, `request_cancelled(Dictionary)`, `agent_arrived(String)`, `approval_requested(Dictionary,String)`, `approval_resolved(bool)`, `agent_question(String,String)`, `guidance_given(String)`.
- Produces (for Tasks 2–3): the harness file with helpers `_check(name, cond, detail)`, `_run_request(request)`, `_valid_text(stage)`, `_has_all(seen, needed)`, `_clean_parks()`, `_rmrf(path)`, and the counters `_passes`/`_fails`; scenario functions `_scenario_a/b/c()`; the run entry `_run()` that calls all three then `quit()`.

- [ ] **Step 1: Write the harness with the fake renderer and Scenario A**

Create `tools/test_pipeline.gd` with exactly this content:

```gdscript
## Headless pipeline reliability tests. Run:
##   godot --headless --path . -s res://tools/test_pipeline.gd
## Acts as a "fake renderer" over EventBus — it answers the world-facing
## signals the 3D office normally fulfills (agent_arrived, approval_resolved,
## guidance_given) and cranks Engine.time_scale so the pipeline's fixed
## waits collapse. Drives three scenarios in simulate mode against one
## reused Pipeline. Exits non-zero on any failure.
extends SceneTree

var _passes: int = 0
var _fails: int = 0
var _stage_log: Array[String] = []   # "role:stage" per stage_completed, per run
var _completed: Array = []           # [request, out_dir] appended on request_completed
var _cancelled: Array = []           # request appended on request_cancelled


func _init() -> void:
	# wait one frame so autoloads (Config, EventBus, Claude, ...) register
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	# collapse the pipeline's fixed wall-clock waits (8s huddle, etc.)
	Engine.time_scale = 100.0
	# force deterministic simulate mode (also skips the Director triage call)
	Config.provider_resolved = "simulate"
	# stop the queue poller so it can't pick up park_*.json files mid-test
	if TaskQueue._timer:
		TaskQueue._timer.stop()

	# FAKE RENDERER: fulfill the exact EventBus contract the 3D office does
	EventBus.stage_started.connect(func(_s: String, role: String, _r: Dictionary) -> void:
		EventBus.agent_arrived.emit(role))
	EventBus.approval_requested.connect(func(_r: Dictionary, _p: String) -> void:
		EventBus.approval_resolved.emit(true))
	EventBus.agent_question.connect(func(_role: String, _q: String) -> void:
		EventBus.guidance_given.emit(""))   # a shrug: no guidance -> honest failure

	# capture what the pipeline produces
	EventBus.stage_completed.connect(func(stage: String, role: String, _r: Dictionary, _o: String) -> void:
		_stage_log.append("%s:%s" % [role, stage]))
	EventBus.request_completed.connect(func(req: Dictionary, out_dir: String) -> void:
		_completed.append([req, out_dir]))
	EventBus.request_cancelled.connect(func(req: Dictionary) -> void:
		_cancelled.append(req))

	var pipe := Pipeline.new()
	root.add_child(pipe)

	await _scenario_a()

	print("\n=== pipeline tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


# ---- scenarios -------------------------------------------------------------

func _scenario_a() -> void:
	print("\n[A] happy path — full cascade completes and ships")
	Claude.limit_until = 0
	var before := _completed.size()
	await _run_request({"topic": "test-a-happy"})
	_check("A: request_completed fired", _completed.size() == before + 1)
	_check("A: all five stages + review ran",
		_has_all(_stage_log, ["director:plan", "researcher:research", "writer:script",
			"editor:edit", "publisher:publish", "director:review"]),
		str(_stage_log))
	if _completed.size() > before:
		_rmrf(str(_completed[-1][1]))   # delete the output dir it wrote


# ---- helpers ---------------------------------------------------------------

func _run_request(request: Dictionary) -> void:
	_stage_log.clear()
	var c0 := _completed.size()
	var x0 := _cancelled.size()
	EventBus.request_received.emit(request)
	var frames := 0
	while _completed.size() == c0 and _cancelled.size() == x0 and frames < 200000:
		await process_frame
		frames += 1
	if frames >= 200000:
		_check("run terminated for '%s'" % request.get("topic", "?"), false, "TIMED OUT")


## A stage payload long enough to clear every STAGE_MIN gate (max is 150).
func _valid_text(stage: String) -> String:
	return "[test %s] " % stage + "lorem ipsum ".repeat(30)


func _has_all(seen: Array, needed: Array) -> bool:
	for n in needed:
		if not seen.has(n):
			return false
	return true


func _check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name, ("  " + detail) if detail != "" else "")


func _clean_parks() -> void:
	var d := DirAccess.open(Config.project_dir().path_join("queue").path_join("pending"))
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("park_"):
			d.remove(f)


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

- [ ] **Step 2: Run the harness and verify Scenario A passes**

Run:
```bash
godot --headless --path . -s res://tools/test_pipeline.gd
```
Expected output ends with:
```
[A] happy path — full cascade completes and ships
  PASS  A: request_completed fired
  PASS  A: all five stages + review ran

=== pipeline tests: 2 passed, 0 failed ===
```
Exit code `0`. If instead the run hangs or reports a TIMED OUT / FAIL line, the fake renderer isn't satisfying `_walk_stage` — confirm the `stage_started → agent_arrived` handler is connected before `Pipeline.new()` is added.

- [ ] **Step 3: Commit**

```bash
git add tools/test_pipeline.gd
git commit -m "test: headless pipeline harness + happy-path scenario

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Production seam + Scenario B (quality gate) + Scenario C (park & resume)

Adds the two failure scenarios, which require forcing a stage to return empty — impossible today because `simulate` always returns valid text. The scenarios are written **first** (they error/fail without the seam), then the one-line `Claude.test_hook` seam makes them pass. This is the red→green step.

**Files:**
- Modify: `scripts/autoload/claude_client.gd` (add field near line 33; add guard at top of `complete()`, line 76)
- Modify: `tools/test_pipeline.gd` (add `_scenario_b`, `_scenario_c`, and their calls in `_run`)

**Interfaces:**
- Consumes: everything from Task 1, plus the new `Claude.test_hook: Callable`.
- Produces: `Claude.test_hook` — when `.is_valid()`, `complete()` returns `str(test_hook.call(sim_stage))` and does nothing else.

- [ ] **Step 1: Add Scenario B and C to the harness**

In `tools/test_pipeline.gd`, change the `_run()` body to call all three scenarios. Replace:
```gdscript
	await _scenario_a()

	print("\n=== pipeline tests: %d passed, %d failed ===" % [_passes, _fails])
```
with:
```gdscript
	await _scenario_a()
	await _scenario_b()
	await _scenario_c()

	print("\n=== pipeline tests: %d passed, %d failed ===" % [_passes, _fails])
```

Then add these two functions after `_scenario_a()`:
```gdscript
func _scenario_b() -> void:
	print("\n[B] quality gate — an empty stage never ships a placeholder")
	Claude.limit_until = 0   # provider healthy: exercises the ask-retry-then-park path
	Claude.test_hook = func(stage: String) -> String:
		return "" if stage == "script" else _valid_text(stage)
	var c0 := _completed.size()
	var x0 := _cancelled.size()
	await _run_request({"topic": "test-b-gate"})
	_check("B: request_completed did NOT fire (nothing shipped)", _completed.size() == c0)
	_check("B: job was parked (request_cancelled fired)", _cancelled.size() == x0 + 1)
	Claude.test_hook = Callable()
	_clean_parks()


func _scenario_c() -> void:
	print("\n[C] park & resume — a quota trip preserves finished stages")
	Claude.limit_until = int(Time.get_unix_time_from_system()) + 3600   # provider "limited"
	Claude.test_hook = func(stage: String) -> String:
		return "" if stage == "edit" else _valid_text(stage)
	var x0 := _cancelled.size()
	await _run_request({"topic": "test-c-park"})
	_check("C: job was parked (request_cancelled fired)", _cancelled.size() == x0 + 1,
		"cancelled delta=%d" % (_cancelled.size() - x0))
	var partial: Dictionary = {}
	if _cancelled.size() > x0:
		partial = _cancelled[-1].get("_partial", {})
	_check("C: checkpoint kept plan+research+script, dropped edit",
		partial.has("plan") and partial.has("research") and partial.has("script")
			and not partial.has("edit"),
		"partial keys=%s" % str(partial.keys()))
	Claude.test_hook = Callable()
	Claude.limit_until = 0
	_clean_parks()
```

- [ ] **Step 2: Run and verify B and C FAIL (seam absent)**

Run:
```bash
godot --headless --path . -s res://tools/test_pipeline.gd
```
Expected: a runtime error `Invalid set index 'test_hook' (on base: 'Node (claude_client.gd)')` when Scenario B assigns `Claude.test_hook`, OR (if Godot tolerates it) Scenario B/C FAIL because the empty stage is ignored and the job still completes. Either way the run does **not** reach `0 failed`. This is the expected red state.

- [ ] **Step 3: Add the `test_hook` field to the Claude autoload**

In `scripts/autoload/claude_client.gd`, add the field just below the existing `var limit_until := 0` (around line 33):
```gdscript
## Test-only override. When valid, complete() returns
## str(test_hook.call(sim_stage)) and does nothing else — the sole seam
## the headless pipeline tests use to force a stage to fail. Production
## never sets this, so behaviour is unchanged when it is unset.
var test_hook: Callable = Callable()
```

- [ ] **Step 4: Add the guard clause at the top of `complete()`**

In `scripts/autoload/claude_client.gd`, `complete()` currently begins (line 76):
```gdscript
func complete(system_prompt: String, user_prompt: String, sim_stage: String = "") -> String:
	if Config.provider_resolved == "simulate":
```
Insert the guard as the first line of the body, before the simulate check:
```gdscript
func complete(system_prompt: String, user_prompt: String, sim_stage: String = "") -> String:
	if test_hook.is_valid():
		return str(test_hook.call(sim_stage))
	if Config.provider_resolved == "simulate":
```

- [ ] **Step 5: Run and verify all scenarios PASS**

Run:
```bash
godot --headless --path . -s res://tools/test_pipeline.gd
```
Expected output ends with:
```
[B] quality gate — an empty stage never ships a placeholder
  PASS  B: request_completed did NOT fire (nothing shipped)
  PASS  B: job was parked (request_cancelled fired)

[C] park & resume — a quota trip preserves finished stages
  PASS  C: job was parked (request_cancelled fired)
  PASS  C: checkpoint kept plan+research+script, dropped edit

=== pipeline tests: 6 passed, 0 failed ===
```
Exit code `0`.

- [ ] **Step 6: Verify the seam is inert in production (no behaviour change)**

Run the existing validation to confirm nothing regressed:
```bash
godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -3
```
Expected: `all checks passed`, exit code `0`.

- [ ] **Step 7: Commit**

```bash
git add tools/test_pipeline.gd scripts/autoload/claude_client.gd
git commit -m "test: pipeline quality-gate + park-and-resume scenarios

Adds the two failure scenarios and the one production seam they need:
a test-only Claude.test_hook consulted at the top of complete(). Inert
when unset — production behaviour unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Wire the harness into CI

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tools/test_pipeline.gd` and its `N passed, N failed` summary line.

- [ ] **Step 1: Add the CI step**

In `.github/workflows/ci.yml`, the last step is currently:
```yaml
      - name: Validate scripts, scenes and assets
        run: |
          godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tee /tmp/check.log
          ! grep -q "SCRIPT ERROR" /tmp/check.log
```
Add this step immediately after it (same indentation):
```yaml
      - name: Pipeline reliability tests
        run: |
          godot --headless --path . -s res://tools/test_pipeline.gd 2>&1 | tee /tmp/pipe.log
          grep -q ", 0 failed ===" /tmp/pipe.log
```
(The `grep` on the summary line is the pass/fail gate, mirroring how the existing step greps its log rather than trusting the piped exit code.)

- [ ] **Step 2: Sanity-check the workflow locally**

Confirm the file is valid YAML and the step reads correctly:
```bash
grep -n "Pipeline reliability tests" -A2 .github/workflows/ci.yml
```
Expected: shows the new step with the two-line `run:` block.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run pipeline reliability tests on every push

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **Why the fake renderer, not stubs:** the pipeline advances only when the world emits `agent_arrived` after `stage_started`. With no 3D scene, nobody emits it, so every stage would hang its 15s `ARRIVAL_TIMEOUT`. Answering those signals *is* the test faithfully standing in for the office — it validates the real EventBus contract.
- **Why both B and C end in `request_cancelled`:** `_park_job` (pipeline.gd) emits `request_cancelled` after setting `request["_partial"]`. B and C differ in setup (healthy vs limited) and in assertion (B: nothing shipped; C: checkpoints preserved), not in the terminal signal.
- **If a scenario hangs:** the `frames < 200000` cap in `_run_request` turns a hang into a TIMED OUT FAIL rather than an infinite loop. A hang most likely means a fake-renderer handler isn't connected or a signal name drifted.
- **State isolation:** every scenario resets `Claude.test_hook` / `Claude.limit_until` and calls `_clean_parks()`; Scenario A deletes its output dir. Do not remove these — repeated local runs depend on them.
