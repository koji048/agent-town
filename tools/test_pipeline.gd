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

# Autoloads referenced via get_node(), not bare identifiers: a custom
# `extends SceneTree` script run with `-s` compiles BEFORE the engine
# registers autoload singletons as global constants, so `Config`/`EventBus`/
# `Claude`/`TaskQueue` fail to resolve at compile time here (this is why
# tools/provider_test.gd does the same lookup instead of a bare identifier).
var _config: Node
var _event_bus: Node
var _claude: Node
var _task_queue: Node


func _init() -> void:
	# wait one frame so autoloads (Config, EventBus, Claude, ...) register
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_config = root.get_node("/root/Config")
	_event_bus = root.get_node("/root/EventBus")
	_claude = root.get_node("/root/Claude")
	_task_queue = root.get_node("/root/TaskQueue")

	# collapse the pipeline's fixed wall-clock waits (8s huddle, etc.)
	Engine.time_scale = 100.0
	# force deterministic simulate mode (also skips the Director triage call)
	_config.provider_resolved = "simulate"
	# stop the queue poller so it can't pick up park_*.json files mid-test
	if _task_queue._timer:
		_task_queue._timer.stop()

	# FAKE RENDERER: fulfill the exact EventBus contract the 3D office does
	_event_bus.stage_started.connect(func(_s: String, role: String, _r: Dictionary) -> void:
		_event_bus.agent_arrived.emit(role))
	_event_bus.approval_requested.connect(func(_r: Dictionary, _p: String) -> void:
		_event_bus.approval_resolved.emit(true))
	_event_bus.agent_question.connect(func(_role: String, _q: String) -> void:
		_event_bus.guidance_given.emit(""))   # a shrug: no guidance -> honest failure

	# capture what the pipeline produces
	_event_bus.stage_completed.connect(func(stage: String, role: String, _r: Dictionary, _o: String) -> void:
		_stage_log.append("%s:%s" % [role, stage]))
	_event_bus.request_completed.connect(func(req: Dictionary, out_dir: String) -> void:
		_completed.append([req, out_dir]))
	_event_bus.request_cancelled.connect(func(req: Dictionary) -> void:
		_cancelled.append(req))

	# Instantiated via load(), not the bare `Pipeline` class_name identifier:
	# referencing the global class_name directly forces the compiler to
	# eagerly resolve scripts/pipeline.gd's full body (for `:=` type
	# inference on `.new()`) while compiling THIS entry script — i.e.
	# before autoloads are registered — which cascades the same
	# "identifier not found" failure into pipeline.gd's own EventBus
	# reference. load() defers that to runtime, after autoloads exist
	# (the same reason tools/ci_check.gd uses load() rather than a
	# bare class identifier).
	var pipe: Node = load("res://scripts/pipeline.gd").new()
	root.add_child(pipe)

	await _scenario_a()
	await _scenario_b()
	await _scenario_c()

	print("\n=== pipeline tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


# ---- scenarios -------------------------------------------------------------

func _scenario_a() -> void:
	print("\n[A] happy path — full cascade completes and ships")
	_claude.limit_until = 0
	var before := _completed.size()
	await _run_request({"topic": "test-a-happy"})
	_check("A: request_completed fired", _completed.size() == before + 1)
	_check("A: all five stages + review ran",
		_has_all(_stage_log, ["director:plan", "researcher:research", "writer:script",
			"editor:edit", "publisher:publish", "director:review"]),
		str(_stage_log))
	if _completed.size() > before:
		_rmrf(str(_completed[-1][1]))   # delete the output dir it wrote


func _scenario_b() -> void:
	print("\n[B] quality gate — an empty stage never ships a placeholder")
	_claude.limit_until = 0   # provider healthy: exercises the ask-retry-then-park path
	_claude.test_hook = func(stage: String) -> String:
		return "" if stage == "script" else _valid_text(stage)
	var c0 := _completed.size()
	var x0 := _cancelled.size()
	await _run_request({"topic": "test-b-gate"})
	_check("B: request_completed did NOT fire (nothing shipped)", _completed.size() == c0)
	_check("B: job was parked (request_cancelled fired)", _cancelled.size() == x0 + 1)
	_claude.test_hook = Callable()
	_clean_parks()


func _scenario_c() -> void:
	print("\n[C] park & resume — a quota trip preserves finished stages")
	_claude.limit_until = int(Time.get_unix_time_from_system()) + 3600   # provider "limited"
	_claude.test_hook = func(stage: String) -> String:
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
	_claude.test_hook = Callable()
	_claude.limit_until = 0
	_clean_parks()


# ---- helpers ---------------------------------------------------------------

func _run_request(request: Dictionary) -> void:
	_stage_log.clear()
	var c0 := _completed.size()
	var x0 := _cancelled.size()
	_event_bus.request_received.emit(request)
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
	var d := DirAccess.open(_config.project_dir().path_join("queue").path_join("pending"))
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
