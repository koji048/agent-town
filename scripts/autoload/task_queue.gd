## Ambient work intake. Polls queue/pending/ for *.json request files,
## moves them through queue/processing/ to queue/done/. One request is
## processed at a time.
extends Node

var busy: bool = false
var _timer: Timer


func _ready() -> void:
	for sub in ["pending", "processing", "done"]:
		DirAccess.make_dir_recursive_absolute(_qdir(sub))
	_timer = Timer.new()
	_timer.wait_time = maxf(Config.poll_interval, 1.0)
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	EventBus.log_line.emit("Watching queue/pending/ every %.0fs" % _timer.wait_time)


func finish(request: Dictionary) -> void:
	var fname: String = str(request.get("_file", ""))
	if not fname.is_empty():
		DirAccess.rename_absolute(_qdir("processing").path_join(fname), _qdir("done").path_join(fname))
	busy = false


func _qdir(sub: String) -> String:
	return Config.project_dir().path_join("queue").path_join(sub)


func _poll() -> void:
	if busy:
		return
	var dir := DirAccess.open(_qdir("pending"))
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.get_extension() == "json":
			dir.list_dir_end()
			_take(fname)
			return
		fname = dir.get_next()
	dir.list_dir_end()


func _take(fname: String) -> void:
	var src := _qdir("pending").path_join(fname)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(src))
	if not (data is Dictionary):
		EventBus.log_line.emit("Invalid request %s — skipped to done/" % fname)
		DirAccess.rename_absolute(src, _qdir("done").path_join(fname))
		return
	DirAccess.rename_absolute(src, _qdir("processing").path_join(fname))
	var request: Dictionary = data
	request["_file"] = fname
	busy = true
	EventBus.log_line.emit("Picked up request: %s" % fname)
	EventBus.request_received.emit(request)
