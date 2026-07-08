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

## Live job registry, so anyone (chat, watchdog) can answer "ถึงไหนแล้ว".
## topic -> {stage, role, since (unix), warned}
var jobs: Dictionary = {}
const OVERDUE_SEC := 240.0


func _ready() -> void:
	for sub in ["pending", "processing", "done"]:
		DirAccess.make_dir_recursive_absolute(_qdir(sub))
	# crash recovery: requests orphaned mid-run (app killed/quit) go
	# back to pending so the crew picks them up again
	var proc := DirAccess.open(_qdir("processing"))
	if proc:
		for f in proc.get_files():
			if f.ends_with(".json"):
				DirAccess.rename_absolute(_qdir("processing").path_join(f),
					_qdir("pending").path_join(f))
				EventBus.log_line.emit("↩ Recovered orphaned request: %s" % f)
	DirAccess.make_dir_recursive_absolute(_inbox())
	DirAccess.make_dir_recursive_absolute(_inbox().path_join("done"))
	_timer = Timer.new()
	_timer.wait_time = maxf(Config.poll_interval, 1.0)
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	EventBus.log_line.emit("Watching queue/pending/ + inbox/ every %.0fs" % _timer.wait_time)

	# live registry + overdue watchdog (the PIC reports slowness
	# proactively — the human should never have to chase silence)
	EventBus.stage_started.connect(func(stage: String, role: String, request: Dictionary) -> void:
		jobs[str(request.get("topic", "untitled"))] = {
			"stage": stage, "role": role,
			"since": Time.get_unix_time_from_system(), "warned": false,
		})
	EventBus.request_completed.connect(func(request: Dictionary, _o: String) -> void:
		jobs.erase(str(request.get("topic", "untitled"))))
	var watchdog := Timer.new()
	watchdog.wait_time = 30.0
	watchdog.timeout.connect(_check_overdue)
	add_child(watchdog)
	watchdog.start()


func _check_overdue() -> void:
	var now := Time.get_unix_time_from_system()
	for topic in jobs:
		var j: Dictionary = jobs[topic]
		if not bool(j["warned"]) and now - float(j["since"]) > OVERDUE_SEC:
			j["warned"] = true
			EventBus.agent_say.emit(str(j["role"]),
				I18n.f("say_overdue", [str(topic).left(30)]))
			EventBus.log_line.emit("⚠ '%s' stuck at %s (%s) for %d min" % [
				str(topic).left(30), j["stage"], j["role"],
				int((now - float(j["since"])) / 60.0)])


## Human-readable live status for chat follow-ups ("ถึงไหนแล้ว").
func status_text() -> String:
	if jobs.is_empty():
		return "No jobs in flight right now."
	var now := Time.get_unix_time_from_system()
	var lines: Array[String] = []
	for topic in jobs:
		var j: Dictionary = jobs[topic]
		lines.append("'%s' — stage %s, PIC %s, %d min in%s" % [
			str(topic).left(36), j["stage"], j["role"],
			int((now - float(j["since"])) / 60.0),
			" (RUNNING LATE)" if bool(j["warned"]) else ""])
	return "\n".join(lines)


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
