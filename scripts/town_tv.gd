## The courtyard's big screen becomes a LIVE edit-bay broadcast: while
## a clip is in the pipeline it shows the EP, the current reel.sh stage,
## a progress bar and the last few production log lines — the whole
## office (and the human) can watch the cut happen. Idle = ALL-HANDS.
class_name TownTV
extends Node3D

const W := 2.9
const LOG_KEEP := 3

var _active := false
var _topic := ""
var _ep := 0
var _title: Label3D
var _mode: Label3D
var _lines: Array = []
var _line_labels: Array = []
var _bar_fill: MeshInstance3D
var _rec: MeshInstance3D
var _done_until := 0.0
var _blink := 0.0


func _ready() -> void:
	# idle face: the classic ALL-HANDS
	_title = _label("ALL-HANDS", 96, Color(0.95, 0.94, 0.9), Vector3(0, 0, 0.05))
	# clip mode chrome (hidden until footage flows)
	_mode = _label("", 44, Color(1.0, 0.85, 0.4), Vector3(0, 0.58, 0.05))
	for i in LOG_KEEP:
		_line_labels.append(_label("", 26, Color(0.72, 0.82, 0.88),
			Vector3(0, 0.18 - i * 0.22, 0.05)))
	# progress bar: dark track + amber fill growing left-to-right
	var track := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(W * 0.82, 0.09, 0.02)
	track.mesh = tm
	track.material_override = _flat(Color(0.16, 0.18, 0.24))
	track.position = Vector3(0, -0.62, 0.05)
	track.visible = false
	add_child(track)
	_bar_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.0, 0.09, 0.022)
	_bar_fill.mesh = fm
	_bar_fill.material_override = _flat(Color(1.0, 0.62, 0.18), true)
	_bar_fill.visible = false
	add_child(_bar_fill)
	_bar_fill.set_meta("track", track)
	# blinking REC dot
	_rec = MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 0.05
	rm.height = 0.1
	_rec.mesh = rm
	_rec.material_override = _flat(Color(0.95, 0.25, 0.2), true)
	_rec.position = Vector3(-W * 0.42, 0.58, 0.05)
	_rec.visible = false
	add_child(_rec)

	EventBus.request_received.connect(func(request: Dictionary) -> void:
		if request.has("clip"):
			_active = true
			_topic = str(request.get("topic", ""))
			_ep = 0
			_lines.clear()
			_apply_mode())
	EventBus.log_line.connect(_on_log)
	EventBus.request_completed.connect(_on_finished)
	EventBus.request_cancelled.connect(_on_finished)
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_refresh)
	add_child(t)
	t.start()


func _process(delta: float) -> void:
	if _rec.visible:
		_blink += delta
		(_rec.material_override as StandardMaterial3D).emission_energy_multiplier = \
			1.2 if fmod(_blink, 1.0) < 0.55 else 0.15


func _on_log(line: String) -> void:
	if not _active:
		return
	var keep := false
	for tag in ["🎬", "🎙", "🔥", "🎞", "📦", "✏", "⏱"]:
		if line.begins_with(tag):
			keep = true
			break
	if not keep:
		return
	var re := RegEx.new()
	re.compile("EP(\\d+)")
	var m := re.search(line)
	if m:
		_ep = int(m.get_string(1))
	_lines.push_front(line.left(52))
	if _lines.size() > LOG_KEEP:
		_lines.resize(LOG_KEEP)
	_apply_mode()


func _on_finished(request: Dictionary, _extra: Variant = null) -> void:
	if not _active or not request.has("clip"):
		return
	_active = false
	_done_until = Time.get_unix_time_from_system() + 25.0
	_apply_mode()


func _refresh() -> void:
	if not _active and _done_until < Time.get_unix_time_from_system() \
			and not _title.visible:
		_apply_mode()  # done-card expired -> back to ALL-HANDS
	if not _active:
		return
	# live % from the job registry
	var pct := 0
	for topic in TaskQueue.jobs:
		if str(topic) == _topic:
			pct = int(TaskQueue.jobs[topic].get("pct", 0))
	var wfull := W * 0.82
	var wnow := maxf(wfull * pct / 100.0, 0.02)
	_bar_fill.scale = Vector3(wnow, 1, 1)
	_bar_fill.position = Vector3(-wfull / 2.0 + wnow / 2.0, -0.62, 0.052)


func _apply_mode() -> void:
	var done_showing := _done_until > Time.get_unix_time_from_system()
	_title.visible = not _active and not done_showing
	_mode.visible = _active or done_showing
	_rec.visible = _active
	_bar_fill.visible = _active
	(_bar_fill.get_meta("track") as MeshInstance3D).visible = _active
	if _active:
		_mode.text = I18n.f("tv_cutting", [_ep]) if _ep > 0 else I18n.t("tv_intake")
	elif done_showing:
		_mode.text = I18n.f("tv_done", [_ep]) if _ep > 0 else I18n.t("tv_done_plain")
	for i in _line_labels.size():
		var l := _line_labels[i] as Label3D
		l.visible = _active
		l.text = str(_lines[i]) if i < _lines.size() else ""


func _label(text: String, size: int, col: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = I18n.ui_font
	l.text = text
	l.font_size = size
	l.outline_size = size / 5
	l.pixel_size = 0.004
	l.modulate = col
	l.position = pos
	add_child(l)
	return l


func _flat(col: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.8
	return m
