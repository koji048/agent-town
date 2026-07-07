## Provider smoke test:
##   godot --headless --path . -s res://tools/provider_test.gd
## Prints the resolved provider and, when live, performs one real
## completion through the full Claude client (CLI or API).
extends SceneTree


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var config := root.get_node("/root/Config")
	var claude := root.get_node("/root/Claude")
	print("provider resolved: ", config.provider_resolved)
	var cli: String = config.cli_path
	print("cli path: ", cli if not cli.is_empty() else "(none)")
	if config.provider_resolved == "simulate":
		print("simulate mode — no live call to test")
		quit(0)
		return
	print("sending live test completion...")
	var t: String = await claude.complete("Reply with exactly the word PONG and nothing else.", "ping")
	print("result: ", t.left(80))
	if t.to_upper().contains("PONG"):
		print("provider test PASSED")
		quit(0)
	else:
		print("provider test FAILED")
		quit(1)
