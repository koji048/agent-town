## Boots the campus: town, agents, pipeline, camera and HUD.
## Pan with WASD/arrows, zoom with the mouse wheel.
extends Node2D

const ROLES := ["director", "researcher", "writer", "editor", "publisher"]
const MAX_LOG_LINES := 7

var town: Town
var _cam: Camera2D
var _status: Label
var _mode: Label
var _log: Label
var _log_lines: PackedStringArray = []


func _ready() -> void:
	town = Town.new()
	add_child(town)

	for role in ROLES:
		var agent := TownAgent.new()
		agent.role = role
		agent.town = town
		var ws := town.workstation(role)
		var spawn := Vector2i(ws.x, ws.y + 1)
		if town.is_blocked(spawn):
			spawn = ws
		agent.grid_pos = spawn
		agent.position = town.tile_center(spawn)
		town.world.add_child(agent)

	add_child(Pipeline.new())

	_cam = Camera2D.new()
	_cam.position = town.center()
	_cam.zoom = Vector2(0.9, 0.9)
	add_child(_cam)
	_cam.make_current()

	_build_hud()
	EventBus.log_line.connect(_append_log)
	EventBus.stage_started.connect(func(stage: String, role: String, request: Dictionary) -> void:
		_status.text = "NOW: %s -> %s  (%s)" % [role, stage, str(request.get("topic", "")).left(40)])
	EventBus.stage_completed.connect(func(stage: String, role: String, _request: Dictionary, _result: String) -> void:
		_append_log("%s finished %s" % [role, stage]))
	EventBus.request_completed.connect(func(_request: Dictionary, output_dir: String) -> void:
		_status.text = "IDLE — drop a .json into queue/pending/"
		_append_log("Package saved: output/%s" % output_dir.get_file()))
	_append_log("Agent Town is alive.")


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	pan.x = Input.get_axis(&"ui_left", &"ui_right")
	pan.y = Input.get_axis(&"ui_up", &"ui_down")
	if pan != Vector2.ZERO:
		_cam.position += pan * 420.0 * delta / _cam.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.zoom = (_cam.zoom * 1.1).clamp(Vector2(0.4, 0.4), Vector2(3, 3))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.zoom = (_cam.zoom / 1.1).clamp(Vector2(0.4, 0.4), Vector2(3, 3))


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.position = Vector2(12, 12)
	var vb := VBoxContainer.new()
	var title := Label.new()
	title.text = "AGENT TOWN — content studio"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)
	_mode = Label.new()
	_mode.text = ("MODE: DEMO (no API key — simulate)" if Config.simulate else "MODE: LIVE (%s)" % Config.model)
	_mode.add_theme_font_size_override("font_size", 11)
	_mode.modulate = Color(1, 0.85, 0.5) if Config.simulate else Color(0.6, 1, 0.7)
	vb.add_child(_mode)
	_status = Label.new()
	_status.text = "IDLE — drop a .json into queue/pending/"
	_status.add_theme_font_size_override("font_size", 12)
	vb.add_child(_status)
	top.add_child(vb)
	hud.add_child(top)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel_style())
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.position = Vector2(12, 720 - 140)
	var vb2 := VBoxContainer.new()
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 11)
	_log.custom_minimum_size = Vector2(560, 110)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vb2.add_child(_log)
	bottom.add_child(vb2)
	hud.add_child(bottom)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.82)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb


func _append_log(text: String) -> void:
	var t := Time.get_time_dict_from_system()
	_log_lines.append("[%02d:%02d:%02d] %s" % [t.hour, t.minute, t.second, text])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	if _log:
		_log.text = "\n".join(_log_lines)
