# Soak-test guardrail for dangling lambda captures / node leaks — design

**Date:** 2026-07-13
**Status:** Approved (design), pending implementation plan

## Goal

Make the "leave it idle → Godot error" class of bug **self-sustaining to prevent**:
a bounded headless run that stresses the town, fails on the dangling-lambda-capture
error and on node-count growth, and gates every push in CI. It both **surfaces
the current instance** (which static analysis couldn't pin — Godot gives no
GDScript backtrace for `Lambda capture … was freed`) and **blocks regressions**.

## Background

Investigation (see session notes) found: the error is a lambda connected to a
long-lived signal/timer whose captured node is freed before it fires
(`gdscript_lambda_callable.cpp:110`). It is **non-fatal** but real. Most
fire-and-forget lambdas already guard with `is_instance_valid`; the offending
one couldn't be pinned statically. The main scene already runs headless with a
bounded auto-quit (`main.gd` `_capture_and_quit`, `_run_demo_capture` at
lines 531/556 — `_run_demo_capture` even drives the pipeline headless), so a soak
harness is feasible with the existing pattern.

## Design

### 1. `AGENT_TOWN_SOAK` boot hook (`main.gd`)

When `AGENT_TOWN_SOAK=<seconds>` is set, after `_ready`, run an **aggressive**
stress loop headless, then `get_tree().quit()`:
- Force simulate mode and enqueue a request so the pipeline runs (drives
  handoffs → `_fly_doc`, `stage_*` signals, pop-FX, agent break/gossip — all the
  create-then-free-a-node paths).
- On a short repeating timer (~1.5 s), **cycle agent costumes** across the crew
  via `get_tree().get_nodes_in_group("agents")` + `apply_costume(...)` with a
  class change (forces `_model.queue_free()` + rebuild — the concrete node-free
  event most likely to expose a dangling capture).
- Emit a focus-out/focus-in pair periodically (`notification(...)`) to exercise
  the display-sleep path the error correlated with.
- Print two census markers: `[soak] start orphans=<n>` right after boot settles
  and `[soak] end orphans=<n>` just before quit (reuse the `Performance`
  monitors `leak_mon` already uses).
- Quit after `<seconds>` (clamped, default 25).

This hook is dev/test-only and inert unless the env var is set.

### 2. `tools/soak_test.sh` wrapper

Runs the hook headless and turns its output into a pass/fail:
```
AGENT_TOWN_SOAK=25 godot --headless --path . > soak.log 2>&1
```
Then FAIL (exit 1) if any of:
- `grep -q "Lambda capture .* was freed" soak.log` — the target error. On a hit,
  print the surrounding lines so the offending run is visible.
- `grep -qiE "Cannot call method .* on a null|previously freed" soak.log` — sibling
  freed-object errors.
- **orphan growth** beyond a threshold: parse `[soak] start orphans=` and
  `[soak] end orphans=`; fail if `end - start > ORPHAN_GROWTH_MAX` (default 20).
- the run didn't finish (`grep -q "\[soak\] end"` missing) — timeout/crash.
PASS (exit 0) otherwise, printing the start/end orphan counts.

### 3. CI step (`.github/workflows/ci.yml`)

Add a step after the existing validation to run `tools/soak_test.sh` in the
`barichello/godot-ci` container so every push is gated.

### Follow-up (separate commits, once soak points at the instance)

- Fix the exact offending lambda (root cause).
- Harden the class per the convention: long-lived signals → connect a **method**
  of the owning node (Godot auto-disconnects on free) rather than a
  node-capturing lambda; timers touching a node → a **Timer child** (dies with
  parent) not `get_tree().create_timer`. Apply to the known-fragile spots
  (`agent_3d.gd:247,255` never-disconnect; `main.gd:534` demo-capture leak).

## Files touched

- **Modify:** `scripts/main.gd` — the `AGENT_TOWN_SOAK` hook (+ a `_run_soak`
  helper), following the `_run_demo_capture` pattern.
- **Create:** `tools/soak_test.sh` — the wrapper (executable).
- **Modify:** `.github/workflows/ci.yml` — one soak step.

## Testing

- Run `tools/soak_test.sh` locally (Godot is installed). Success criterion for
  THIS change: the script runs the town headless to completion and reports a
  clear PASS/FAIL with start/end orphan counts. If it catches the current error,
  the log shows the `Lambda capture` line (feeding the follow-up root-cause fix);
  if it doesn't reproduce in the window, the guardrail still stands for future
  regressions.
- The hook must be inert without the env var (verify a normal `ci_check` and a
  plain launch are unchanged).

## Out of scope (this change)

Fixing the offending lambda and the class-hardening pass — those are the
follow-up commits guided by what the soak surfaces.
