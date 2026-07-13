# Headless pipeline test suite — design

**Date:** 2026-07-12
**Status:** Approved (design), pending implementation plan

## Goal

Pin the orchestration pipeline's most valuable ("learned the hard way")
reliability behaviour with an automated, headless, fast test that runs
locally and in CI. This is the project's first real contract test over
`scripts/pipeline.gd` — today the only coverage is a 70-line load/validate
smoke check (`tools/ci_check.gd`) and a couple of boot-time 3D e2e harnesses
embedded in `main.gd`/`office_3d.gd`.

Round one covers the **reliability core** only. Triage subset selection,
the review/FIX round, and the clip workflow are explicitly deferred to a
later suite (YAGNI).

## Why this is cheap to build (existing seams)

- **EventBus decoupling.** `Pipeline` never touches a 3D node; it only
  emits/awaits signals on the `EventBus` autoload. So it can run in a
  headless `SceneTree` script with no rendering.
- **`simulate` provider.** `Claude.complete()` already returns deterministic
  `SIM_TEXT` per stage in simulate mode — the hard part of testing an LLM
  app (determinism) is already solved.
- **`ci_check.gd` pattern.** `extends SceneTree` + wait one frame in `_init`
  via `process_frame.connect(_run, CONNECT_ONE_SHOT)` so autoload singletons
  are registered before they're referenced. The test reuses this idiom.

## Architecture — the test as a "fake renderer"

A single standalone script `tools/test_pipeline.gd` that `extends SceneTree`,
run with:

```
godot --headless --path . -s res://tools/test_pipeline.gd
```

It never loads the 3D world. Instead it plays the role the office normally
plays, purely over EventBus — a faithful stand-in for the renderer:

- On `stage_started` and `meeting_called` → immediately emit
  `agent_arrived(role)`, so `_walk_stage` returns without hitting its 15s
  `ARRIVAL_TIMEOUT` (in the real game, agents emit this when they reach a
  desk; with no 3D world nobody would, so every stage would hang).
- On `approval_requested` → immediately emit `approval_resolved(true)`.
- On `agent_question` → immediately emit `guidance_given("")` (empty = "no
  guidance / a shrug"). This lets the pipeline's stuck-stage retry path run
  and then fail **honestly** into a park, instead of blocking 40s on
  `_ask_owner`.
- Set `Engine.time_scale = 100` so the 8s kickoff huddle and any remaining
  fixed `create_timer` waits collapse to milliseconds (SceneTreeTimer
  respects `time_scale` by default).
- Force `Config` into simulate mode so no real Claude/network call fires.

It instantiates `Pipeline` as a child, emits `request_received(request)`,
awaits the terminal signal (`request_completed` or `request_cancelled`),
then asserts. Each scenario resets shared autoload state (see Isolation).

**Deterministic stage set.** The Director's triage call is gated on
`Config.provider_resolved != "simulate"` (`pipeline.gd:46`). Because the
harness forces simulate mode, triage is skipped and `stages` stays the full
default `[plan, research, script, edit, publish]` for every scenario — no
triage JSON to mock, and "expected stages" always means those five (plus the
final `review`). `test_hook` still drives each stage because it is consulted
at the top of `complete()`, ahead of the simulate branch.

**Both failure scenarios park.** `_park_job` emits `request_cancelled`, so
B and C both terminate on that signal. They differ in *how* and in *what is
preserved*: B is not limited, so the stuck stage runs the ask-owner retry
(the fake renderer shrugs with `""`) and then fails honestly into a park
with only the stages before `script` preserved; C is limited, so `edit`
fast-fails straight to a park with plan/research/script preserved. B's
essential guarantee is "`request_completed` never fires and no package is
written"; C's is "the parked `_partial` preserved the finished stages".

## The one production change — the injection seam

`scripts/pipeline.gd`'s reliability paths only trigger when a stage comes
back empty or the provider is "limited". `simulate` mode always returns
*valid* text, so today there is no way to exercise them. Add a single
test-only field to the `Claude` autoload (`scripts/autoload/claude_client.gd`)
and consult it at the very top of `complete()`:

```gdscript
## Test-only override. When valid, complete() returns
## str(test_hook.call(sim_stage)) instead of the live/simulated result.
## Production never sets this — behaviour is unchanged when unset.
var test_hook: Callable = Callable()
```

```gdscript
func complete(system_prompt: String, user_prompt: String, sim_stage := "") -> String:
    if test_hook.is_valid():
        return str(test_hook.call(sim_stage))
    # ... existing simulate / live logic unchanged ...
```

- Returning a valid string per stage drives the happy path.
- Returning `""` for a chosen stage simulates a failed/empty result.
- To simulate a quota outage, the test *also* sets `Claude.limit_until` to a
  future unix time directly (it is already a plain field). That makes
  `Claude.limited()` return true, which is what tips the pipeline into
  **parking** the job rather than asking-and-retrying.

This is the only edit to production code. When `test_hook` is unset (always,
in the real game) there is zero behaviour change.

## The three scenarios (reliability core)

| # | Scenario | Setup | Assert |
|---|---|---|---|
| **A** | Happy path | `test_hook` returns valid `SIM_TEXT[stage]` for every stage; not limited | `request_completed` fires; an output dir is written; the expected stages ran (from captured `stage_completed` events) |
| **B** | Quality gate — never ship blank | `test_hook` returns `""` for `script`; **not** limited; fake renderer answers `agent_question` with `""` | Job does **not** complete/ship; no output package written; job ends parked (the `_valid` gate + honest-failure path rejected the empty stage, no placeholder) |
| **C** | Park & resume from checkpoint | `test_hook` returns valid text for `plan`/`research`/`script`, then `""` for `edit`, **with** `Claude.limit_until` set to the future | `request_cancelled` fires; the parked request carries `_partial` holding the already-finished stages (plan/research/script) so a later run resumes from checkpoint |

The harness collects one PASS/FAIL line per scenario, prints a summary, and
`quit(0)` on all-pass / `quit(1)` on any failure — so CI fails loudly on
regression.

## Isolation between scenarios

Because autoloads are process-global, the harness must reset shared state
between scenarios so one test can't leak into the next:

- Clear `Claude.test_hook` and reset `Claude.limit_until = 0`.
- Free the previous `Pipeline` instance and any per-run state.
- Disconnect/reconnect the fake-renderer signal handlers as needed.
- Use a unique `topic` per scenario and clean up any output dir a scenario
  writes (scenario A) so repeated local runs stay deterministic.

## Assertion strategy

The harness captures EventBus traffic during each run (an array of
`stage_completed` role/stage pairs, plus which terminal signal fired) and
asserts against that captured record — it does not reach into Pipeline
internals. Where a scenario's contract is "a file was / was not written",
it checks the output directory on disk.

## CI wiring

One new step in `.github/workflows/ci.yml`, after the existing validate
step, using the same headless Godot container:

```yaml
- name: Pipeline reliability tests
  run: godot --headless --path . -s res://tools/test_pipeline.gd
```

## Out of scope (deferred to a later suite)

- Director triage subset selection (e.g. caption-only → publisher alone).
- The bounded review / `FIX <stage>` round.
- The clip workflow (`_run_clip`, `reel.sh`, transcription, caption studio).
- Any test that needs the real 3D world / rendering.

## Files touched

- **New:** `tools/test_pipeline.gd` — the headless harness + 3 scenarios.
- **Edit:** `scripts/autoload/claude_client.gd` — add `test_hook` field + a
  guard clause in `complete()`.
- **Edit:** `.github/workflows/ci.yml` — one new CI step.
