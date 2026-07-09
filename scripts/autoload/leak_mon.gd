## Leak monitor: prints object/node/memory counters to stdout every 30 s
## so a runaway allocation (like the 134 GB overnight footprint) can be
## attributed from the log instead of guessed at. Costs ~nothing.
extends Node


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 30.0
	t.timeout.connect(_report)
	add_child(t)
	t.start()
	_report()


func _report() -> void:
	print("[mon] t=%d nodes=%d orphans=%d objs=%d res=%d static=%.1fMB vram=%.1fMB" % [
		int(Time.get_unix_time_from_system()),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	])
