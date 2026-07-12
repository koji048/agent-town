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
