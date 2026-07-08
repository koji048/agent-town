## Ambient work intake. Polls queue/pending/ for *.json request files,
## moves them through queue/processing/ to queue/done/. One request is
## processed at a time.
extends Node

## Assembly line (per the owner): agents never wait for each other, so
## up to MAX_PARALLEL requests run at once — a person only queues
## behind their own tasks (RoleLocks). Clips stay exclusive (whisper +
## the reels-pipeline batch scripts are single-flight by nature).
const MAX_PARALLEL := 3

var active: int = 0
var clip_active: bool = false
var _timer: Timer


func _ready() -> void:
	for sub in ["pending", "processing", "done"]:
		DirAccess.make_dir_recursive_absolute(_qdir(sub))
	DirAccess.make_dir_recursive_absolute(_inbox())
	DirAccess.make_dir_recursive_absolute(_inbox().path_join("done"))
	_timer = Timer.new()
	_timer.wait_time = maxf(Config.poll_interval, 1.0)
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	EventBus.log_line.emit("Watching queue/pending/ + inbox/ every %.0fs" % _timer.wait_time)


func _inbox() -> String:
	return Config.project_dir().path_join("inbox")


func finish(request: Dictionary) -> void:
	var fname: String = str(request.get("_file", ""))
	if not fname.is_empty():
		DirAccess.rename_absolute(_qdir("processing").path_join(fname), _qdir("done").path_join(fname))
	active = maxi(active - 1, 0)
	if request.has("clip"):
		clip_active = false


func _qdir(sub: String) -> String:
	return Config.project_dir().path_join("queue").path_join(sub)


func _poll() -> void:
	if active >= MAX_PARALLEL:
		return
	# footage first: AirDropped clips dropped into inbox/ become real
	# transcription jobs (exclusive: one clip pipeline at a time)
	if (Transcriber.available() or ReelRunner.available()) and not clip_active:
		var inbox := DirAccess.open(_inbox())
		if inbox:
			for f in inbox.get_files():
				var ext := f.get_extension().to_lower()
				if ext in ["mov", "mp4", "m4v", "mkv", "webm"]:
					active += 1
					clip_active = true
					var abs := _inbox().path_join(f)
					EventBus.log_line.emit("🎬 Footage arrived: %s" % f)
					EventBus.request_received.emit({
						"topic": "clip: %s" % f.get_basename().left(28),
						"clip": abs,
						"clip_file": f,
					})
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
	active += 1
	EventBus.log_line.emit("Picked up request: %s (%d running)" % [fname, active])
	EventBus.request_received.emit(request)
