## Boots the 3D office: low-res viewport for the 16-bit look, orthographic
## isometric camera, sunlight through the windows, agents, pipeline, HUD.
## Pan with WASD/arrows, zoom with the mouse wheel.
extends Node

const ROLES := ["director", "researcher", "writer", "editor", "publisher"]
const MAX_LOG_LINES := 7
const CAM_DIST := 30.0

var office: Office3D
var _cam: Camera3D
var _status: Label
var _log: Label
var _log_lines: PackedStringArray = []
var _costume_panel: CostumePanel


func _ready() -> void:
	# --- low-res 3D viewport (pixelated upscale for the 16-bit look)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 1  # native res — crisp archviz look
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)

	var world := Node3D.new()
	vp.add_child(world)

	office = Office3D.new()
	world.add_child(office)

	for role in ROLES:
		var agent := TownAgent3D.new()
		agent.role = role
		agent.office = office
		var ws := office.workstation(role)
		var spawn := Vector2i(ws.x, ws.y + 1)
		if office.is_blocked(spawn):
			spawn = ws
		agent.grid_pos = spawn
		agent.position = office.grid_to_world(spawn)
		world.add_child(agent)

	add_child(Pipeline.new())

	# --- environment & light
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80, 0.87, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.72, 0.76)
	env.ambient_light_energy = 0.5
	env.ssao_enabled = true
	env.ssao_intensity = 2.2
	env.ssao_radius = 1.5
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# faint exterior fill only — the office is lit by its own luminaires
	# (per request: no sunlight through the office)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 205, 0)
	sun.light_color = Color(0.85, 0.90, 1.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.light_angular_distance = 3.0
	world.add_child(sun)

	# --- isometric orthographic camera
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 27.0
	_cam.far = 200.0
	_cam.rotation_degrees = Vector3(-30, 45, 0)
	world.add_child(_cam)
	_cam.position = office.center() + Vector3(0.3, 0, 0.8) + _cam.global_transform.basis.z * 48.0
	_cam.current = true

	_build_hud()
	_build_costume_panel()
	EventBus.log_line.connect(_append_log)
	EventBus.stage_started.connect(func(stage: String, role: String, request: Dictionary) -> void:
		_status.text = "NOW: %s -> %s  (%s)" % [role, stage, str(request.get("topic", "")).left(40)])
	EventBus.stage_completed.connect(func(stage: String, role: String, _request: Dictionary, _result: String) -> void:
		_append_log("%s finished %s" % [role, stage]))
	EventBus.request_completed.connect(func(_request: Dictionary, output_dir: String) -> void:
		_status.text = "IDLE — drop a .json into queue/pending/"
		_append_log("Package saved: output/%s" % output_dir.get_file())
		_append_log("The crew gathers in the town hall!")
		var agents := get_tree().get_nodes_in_group("agents")
		for i in agents.size():
			var spot: Vector2i = Office3D.TOWNHALL_SPOTS[i % Office3D.TOWNHALL_SPOTS.size()]
			(agents[i] as TownAgent3D).celebrate_at(spot))
	_append_log("Agent Town office is open.")

	# Dev helper: AGENT_TOWN_SHOT=/path/out.png godot --path . -> renders a
	# few seconds, saves a screenshot, quits. Used for README captures.
	var shot_path := OS.get_environment("AGENT_TOWN_SHOT")
	if not shot_path.is_empty():
		_capture_and_quit(shot_path)
	# Demo mode: AGENT_TOWN_DEMO=/dir — snap every few seconds until the
	# queued request completes, then capture the town-hall celebration.
	var demo_dir := OS.get_environment("AGENT_TOWN_DEMO")
	if not demo_dir.is_empty():
		_run_demo_capture(demo_dir)


func _run_demo_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var done := [false]
	EventBus.request_completed.connect(func(_r: Dictionary, _o: String) -> void: done[0] = true)
	var i := 0
	await get_tree().create_timer(2.0).timeout
	while not done[0] and i < 80:
		_snap(dir.path_join("demo_%02d.png" % i))
		i += 1
		await get_tree().create_timer(6.0).timeout
	# celebration: crew walks to the town hall and cheers
	await get_tree().create_timer(7.0).timeout
	_snap(dir.path_join("demo_%02d.png" % i))
	await get_tree().create_timer(4.0).timeout
	_snap(dir.path_join("demo_%02d.png" % (i + 1)))
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("demo snap: ", path)


func _capture_and_quit(path: String) -> void:
	await get_tree().create_timer(3.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	pan.x = Input.get_axis(&"ui_left", &"ui_right")
	pan.y = Input.get_axis(&"ui_up", &"ui_down")
	if pan != Vector2.ZERO:
		var right := _cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var fwd := -_cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		_cam.position += (right * pan.x + fwd * -pan.y) * 8.0 * delta * (_cam.fov / 27.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_costume_panel.visible = not _costume_panel.visible
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov / 1.08, 12.0, 55.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov * 1.08, 12.0, 55.0)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.position = Vector2(12, 12)
	var vb := VBoxContainer.new()
	var title := Label.new()
	title.text = "AGENT TOWN — virtual office"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)
	var mode := Label.new()
	var mode_text := "MODE: DEMO (simulate)"
	if Config.provider_resolved == "claude-code":
		mode_text = "MODE: LIVE (Claude Code)"
	elif Config.provider_resolved == "api":
		mode_text = "MODE: LIVE (API %s)" % Config.model
	mode.text = mode_text
	mode.add_theme_font_size_override("font_size", 11)
	mode.modulate = Color(1, 0.85, 0.5) if Config.provider_resolved == "simulate" else Color(0.6, 1, 0.7)
	vb.add_child(mode)
	_status = Label.new()
	_status.text = "IDLE — drop a .json into queue/pending/"
	_status.add_theme_font_size_override("font_size", 12)
	vb.add_child(_status)
	top.add_child(vb)
	hud.add_child(top)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel_style())
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(12, 1080 - 160)
	var vb2 := VBoxContainer.new()
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 11)
	_log.custom_minimum_size = Vector2(560, 110)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vb2.add_child(_log)
	bottom.add_child(vb2)
	hud.add_child(bottom)


func _build_costume_panel() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	_costume_panel = CostumePanel.new()
	_costume_panel.position = Vector2(1410, 60)
	_costume_panel.visible = false
	_costume_panel.costume_changed.connect(func(role: String, c: Dictionary) -> void:
		for agent in get_tree().get_nodes_in_group("agents"):
			if agent.role == role:
				agent.apply_costume(c))
	hud.add_child(_costume_panel)
	var hint := Label.new()
	hint.text = "C — costumes"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.position = Vector2(1790, 20)
	hud.add_child(hint)
	# show the panel in dev screenshots
	if not OS.get_environment("AGENT_TOWN_SHOT").is_empty():
		_costume_panel.visible = true


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
