## Headless test: Pipeline.subs_prompt — the whisper initial_prompt must be
## real episode vocabulary, never an auto "clip: <filename>" topic (a UUID
## filename fed as prompt gets hallucinated into quiet segments). Run:
##   godot --headless --path . --quit-after 600 -s res://tools/test_subs_prompt.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var P = load("res://scripts/pipeline.gd")

	_check("human topic passes through",
		P.subs_prompt("สอนตั้งกล้องถ่าย Reels") == "สอนตั้งกล้องถ่าย Reels")
	_check("auto clip topic (UUID filename) is dropped",
		P.subs_prompt("clip: e94fa2a2-510b-41a5-bc63-1") == "")
	_check("auto clip topic (any filename) is dropped",
		P.subs_prompt("clip: IMG_4523") == "")
	_check("empty topic stays empty", P.subs_prompt("") == "")

	print("\n=== subs prompt tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
