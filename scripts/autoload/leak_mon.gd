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
	_census()


## Attribute node growth: report which PARENT container gained children since
## the last tick ("[grew] [name:script]+N(=total)"). Walking ~5k nodes every
## 30 s costs <1 ms and turns "nodes went up" into the exact leak site — this
## is how the clip-options dialog spawn and chat-feed growth were attributed.
var _prev: Dictionary = {}

func _census() -> void:
	var counts: Dictionary = {}
	_walk(get_tree().root, counts)
	var grew := ""
	for k in counts:
		var d := int(counts[k]) - int(_prev.get(k, 0))
		if d >= 3 and not _prev.is_empty():   # only meaningful accumulators
			grew += " [%s]+%d(=%d)" % [k, d, int(counts[k])]
	_prev = counts
	print("[grew]" + grew)


func _walk(n: Node, counts: Dictionary) -> void:
	# key each node by its parent's identity (path tail + script/class), so a
	# container that keeps gaining children shows a steady positive delta.
	var p := n.get_parent()
	if p != null:
		var pk := str(p.name)
		var scr: Variant = p.get_script()
		if scr != null and (scr as Script).resource_path != "":
			pk += ":" + (scr as Script).resource_path.get_file()
		else:
			pk += ":" + p.get_class()
		counts[pk] = int(counts.get(pk, 0)) + 1
	for c in n.get_children():
		_walk(c, counts)
