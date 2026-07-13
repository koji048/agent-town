# Soak-Test Guardrail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A bounded headless stress run that fails on dangling-lambda-capture errors and node-leak growth, wrapped as a script and gated in CI — surfacing the current idle-error instance and blocking regressions.

**Architecture:** An `AGENT_TOWN_SOAK=<seconds>` boot hook in `main.gd` (mirroring the existing `_run_demo_capture` bounded-run pattern) drives the pipeline in simulate mode, cycles costumes (frees `_model`), toggles focus, prints an orphan census, and quits. `tools/soak_test.sh` runs it headless and turns the log into PASS/FAIL. A CI step runs the script.

**Tech Stack:** Godot 4 (installed 4.7; CI container `barichello/godot-ci:4.6.1`), GDScript, zsh/bash.

## Global Constraints

- The `AGENT_TOWN_SOAK` hook is dev/test-only: **inert unless the env var is set** — a normal launch and `ci_check` must be unchanged.
- Requests enter via `EventBus.request_received.emit({"topic": ...})`; simulate is forced with `Config.provider_resolved = "simulate"`.
- Costume reload (the node-free event) requires a **class change**: `apply_costume(c)` reloads the model only when `c["class"]` differs from the current one. Available classes: `Costumes.SETS[Costumes.current_set()]["classes"]`.
- Orphan census uses `Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)`. Markers: `[soak] start orphans=<n>` and `[soak] end orphans=<n>`.
- Failure conditions (any → non-zero): the `Lambda capture … was freed` error, a freed-object call, the soak not finishing (`[soak] end` missing), or `end - start > ORPHAN_GROWTH_MAX` (default 20).

## File Structure

- **`scripts/main.gd`** (modify) — `AGENT_TOWN_SOAK` check in `_ready` + a `_run_soak(seconds)` helper (Task 1).
- **`tools/soak_test.sh`** (new, executable) — the wrapper that runs the hook and reports PASS/FAIL (Task 2).
- **`.github/workflows/ci.yml`** (modify) — one soak step (Task 3).

---

### Task 1: `AGENT_TOWN_SOAK` boot hook + `_run_soak`

**Files:**
- Modify: `scripts/main.gd` (the env-hook block near `AGENT_TOWN_DEMO`, ~line 262; add `_run_soak` near `_run_demo_capture`, ~line 531)

**Interfaces:**
- Produces: an `AGENT_TOWN_SOAK=<seconds>` mode that boots the town, stresses it, prints `[soak] start/end orphans=…`, and quits.

- [ ] **Step 1: Add the env-hook dispatch**

In `scripts/main.gd`, find the `AGENT_TOWN_DEMO` block in `_ready`:
```gdscript
	var demo_dir := OS.get_environment("AGENT_TOWN_DEMO")
	if not demo_dir.is_empty():
		_run_demo_capture(demo_dir)
```
Add immediately after it:
```gdscript
	# Soak/guardrail: AGENT_TOWN_SOAK=<seconds> stresses the town headless
	# (pipeline + costume cycling + focus toggles), prints an orphan census,
	# and quits — tools/soak_test.sh fails on dangling captures or leak growth.
	var soak := OS.get_environment("AGENT_TOWN_SOAK")
	if not soak.is_empty():
		_run_soak(int(soak))
```

- [ ] **Step 2: Add the `_run_soak` helper**

Add near `_run_demo_capture` in `scripts/main.gd`:
```gdscript
## Bounded headless stress run (see tools/soak_test.sh). Drives the pipeline in
## simulate mode, cycles costumes (forces _model.queue_free + reload), and
## toggles focus (the display-sleep path) — surfacing dangling lambda captures
## and node leaks. Prints an orphan census and quits.
func _run_soak(seconds: int) -> void:
	Config.provider_resolved = "simulate"
	seconds = clampi(seconds, 5, 120)
	await get_tree().create_timer(3.0).timeout   # let boot settle
	var start_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("[soak] start orphans=%d" % start_orphans)
	var classes: Array = Costumes.SETS[Costumes.current_set()].get("classes", [])
	var deadline := Time.get_ticks_msec() + seconds * 1000
	var tick := 0
	EventBus.request_received.emit({"topic": "soak stress 0"})
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(1.5).timeout
		tick += 1
		# cycle costumes -> _model.queue_free() + reload (the node-free event)
		if not classes.is_empty():
			for a in get_tree().get_nodes_in_group("agents"):
				var ag := a as TownAgent3D
				var c: Dictionary = (ag.costume as Dictionary).duplicate(true)
				c["class"] = str(classes[(tick + abs(hash(ag.role))) % classes.size()])
				ag.apply_costume(c)
		# exercise the display-sleep / focus path the error correlated with
		notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await get_tree().create_timer(0.3).timeout
		notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		# keep the pipeline busy
		if tick % 4 == 0:
			EventBus.request_received.emit({"topic": "soak stress %d" % tick})
	var end_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("[soak] end orphans=%d" % end_orphans)
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
```

- [ ] **Step 3: Run it locally — the hook boots, stresses, and quits**

Run:
```bash
AGENT_TOWN_SOAK=15 godot --headless --path . 2>&1 | grep -E "\[soak\]|Lambda capture|SCRIPT ERROR" | head
```
Expected: prints `[soak] start orphans=N` then (after ~15s) `[soak] end orphans=M`, and the process exits on its own. If `[soak] end` never prints or the process hangs, the hook has a bug (e.g. `apply_costume`/`costume` access) — fix before proceeding. **If a `Lambda capture … was freed` line appears, that is the reproduction we wanted — note it for the follow-up root-cause fix; it does not block this task.**

- [ ] **Step 4: Confirm the hook is inert without the env var**

Run:
```bash
godot --headless --path . -s res://tools/ci_check.gd 2>&1 | tail -1     # all checks passed
```
Expected: `all checks passed` (the hook only affects a full scene run with the env var; `ci_check` is unaffected).

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: AGENT_TOWN_SOAK headless stress hook (pipeline + costume + focus)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `tools/soak_test.sh` wrapper

**Files:**
- Create: `tools/soak_test.sh` (executable)

**Interfaces:**
- Consumes: the `AGENT_TOWN_SOAK` hook and its `[soak] start/end orphans=` markers.
- Produces: exit 0 (`SOAK PASS`) / exit 1 (`SOAK FAIL`) with a reason.

- [ ] **Step 1: Write the wrapper**

Create `tools/soak_test.sh`:
```bash
#!/usr/bin/env bash
# Soak/leak guardrail: stress the town headless and fail on a dangling lambda
# capture, a freed-object call, a non-finishing run, or orphan-node growth.
#   tools/soak_test.sh [seconds]   (env: GODOT, ORPHAN_GROWTH_MAX)
set -u
DUR="${1:-25}"
GODOT="${GODOT:-godot}"
MAX="${ORPHAN_GROWTH_MAX:-20}"
cd "$(dirname "$0")/.."
LOG="$(mktemp -t at_soak.XXXX)"

AGENT_TOWN_SOAK="$DUR" "$GODOT" --headless --path . > "$LOG" 2>&1 || true

fail=0
if grep -qE "Lambda capture .* was freed" "$LOG"; then
	echo "FAIL: dangling lambda capture detected:"
	grep -nE -A1 "Lambda capture .* was freed" "$LOG" | head
	fail=1
fi
if grep -qiE "Cannot call method .* on a null|on a previously freed" "$LOG"; then
	echo "FAIL: freed-object call detected:"
	grep -niE "Cannot call method .* on a null|previously freed" "$LOG" | head
	fail=1
fi
if ! grep -q "\[soak\] end" "$LOG"; then
	echo "FAIL: soak did not finish (crash/timeout). Tail:"
	tail -15 "$LOG"
	fail=1
fi
start="$(grep "\[soak\] start orphans=" "$LOG" | tail -1 | sed -E 's/.*orphans=([0-9]+).*/\1/')"
end="$(grep "\[soak\] end orphans=" "$LOG" | tail -1 | sed -E 's/.*orphans=([0-9]+).*/\1/')"
if [[ -n "$start" && -n "$end" ]]; then
	growth=$(( end - start ))
	echo "orphans: start=$start end=$end growth=$growth (max $MAX)"
	if (( growth > MAX )); then
		echo "FAIL: orphan node growth $growth exceeds $MAX"
		fail=1
	fi
else
	echo "FAIL: could not read orphan census"
	fail=1
fi

if [[ "$fail" -eq 0 ]]; then echo "SOAK PASS"; else echo "SOAK FAIL (log: $LOG)"; fi
exit "$fail"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tools/soak_test.sh
```

- [ ] **Step 3: Run it locally and confirm a clear PASS/FAIL**

```bash
GODOT=godot ./tools/soak_test.sh 15
echo "exit=$?"
```
Expected: it runs the town, prints `orphans: start=… end=… growth=…`, then `SOAK PASS` (exit 0) or `SOAK FAIL` (exit 1) with the reason. Either verdict is a successful wrapper — a FAIL that names a `Lambda capture` line IS the reproduction and feeds the follow-up fix. A wrapper bug is only when the verdict/parse is wrong (e.g. it can't read the orphan census on a run that clearly printed it).

- [ ] **Step 4: Commit**

```bash
git add tools/soak_test.sh
git commit -m "feat: tools/soak_test.sh — run the soak hook, fail on captures/leaks

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: CI step

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add the soak step**

In `.github/workflows/ci.yml`, after the "Pipeline reliability tests" step (or the last validation step), add (same indentation):
```yaml
      - name: Soak test (dangling captures / node leaks)
        run: ./tools/soak_test.sh 25
```

- [ ] **Step 2: Sanity-check the YAML**

```bash
grep -n "Soak test" -A2 .github/workflows/ci.yml
```
Expected: shows the new step with its `run:` line.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run the soak/leak guardrail on every push

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **This is a guardrail, not the root-cause fix.** If Task 1/2's run surfaces the `Lambda capture` line, record it — the offending lambda + the class-hardening pass are a SEPARATE follow-up (do not bundle here).
- **Headless scene boot:** the main scene already runs headless (the `AGENT_TOWN_SHOT`/`DEMO` hooks prove it), so `_run_soak` boots the same way. If costume reload errors in headless (model load), that's itself a finding — report it rather than silencing it.
- **CI risk:** the soak instantiates and runs the full scene in the `barichello/godot-ci` container (after the existing "Import resources" step). If the container cannot boot the scene headless, the step will FAIL on "did not finish" — verify locally first (where it's known to work); if CI can't run a full scene, note it and we adjust the CI step (the local script remains the pre-merge gate).
- **Determinism:** the run is time-bounded and simulate-only (no network); the orphan threshold (20) has slack for normal churn. Tune `ORPHAN_GROWTH_MAX` if healthy runs report steady growth.
