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
var _approval_panel: PanelContainer
var _approval_text: Label
var _awaiting_approval := false
var _sun: DirectionalLight3D
var _env: Environment
var _day_t := 150.0  # start mid-morning
var _meter_needle: Node3D
var _meter_label: Label3D
var _tokens_est := 0
var _calls_inflight := 0
var _inspector: PanelContainer
var _inspector_text: Label
var _inspector_timer: Timer


func _ready() -> void:
	# --- low-res 3D viewport (pixelated upscale for the 16-bit look)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 1  # native res — crisp archviz look
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.gui_input.connect(_on_view_input)
	add_child(container)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.audio_listener_enable_3d = true
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
	_env = env

	# faint exterior fill only — the office is lit by its own luminaires
	# (per request: no sunlight through the office)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 205, 0)
	sun.light_color = Color(0.85, 0.90, 1.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.light_angular_distance = 3.0
	world.add_child(sun)
	_sun = sun

	# --- isometric camera with tilt-shift DoF (miniature faking: a
	# shallow focus band on the action plane sells the toy-office look)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 27.0
	_cam.far = 200.0
	_cam.rotation_degrees = Vector3(-30, 45, 0)
	world.add_child(_cam)
	_cam.position = office.center() + Vector3(0.3, 0, 0.8) + _cam.global_transform.basis.z * 48.0
	_cam.current = true
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 58.0
	attrs.dof_blur_far_transition = 14.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 34.0
	attrs.dof_blur_near_transition = 10.0
	attrs.dof_blur_amount = 0.06
	_cam.attributes = attrs

	Chronicle.attach_office(office)

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
		# the ONE loud moment (reserved juice): chime + confetti + a slow
		# 4-second push-in on the celebration, then ease back
		Sfx.play_ui("chime", -6.0)
		_confetti(office.grid_to_world(Vector2i(12, 9)) + Vector3(0, 2.2, 0))
		var base_fov := _cam.fov
		var tw := _cam.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cam, "fov", base_fov * 0.82, 2.2)
		tw.tween_interval(3.0)
		tw.tween_property(_cam, "fov", base_fov, 2.2)
		var agents := get_tree().get_nodes_in_group("agents")
		for i in agents.size():
			var spot: Vector2i = Office3D.TOWNHALL_SPOTS[i % Office3D.TOWNHALL_SPOTS.size()]
			(agents[i] as TownAgent3D).celebrate_at(spot))
	_append_log("Agent Town office is open.")

	# ambient bed: HVAC room tone + occasional courtyard birds
	Sfx.start_room_tone(world, -26.0)
	_start_chirps(world)

	# the approval desk gate + the diegetic cost meter
	_build_approval_panel()
	EventBus.approval_requested.connect(func(request: Dictionary, preview: String) -> void:
		_awaiting_approval = true
		_approval_text.text = "APPROVAL DESK — '%s'\n\n%s...\n\n[Y] approve · [N] request revision · auto-approve in 45 s" % [
			str(request.get("topic", "")).left(48),
			preview.strip_edges().left(280)]
		_approval_panel.visible = true
		Sfx.play_ui("paper", -6.0))
	EventBus.approval_resolved.connect(func(_a: bool) -> void:
		_awaiting_approval = false
		_approval_panel.visible = false)
	_build_cost_meter()
	EventBus.stage_started.connect(func(_s, _r, _q) -> void:
		_calls_inflight += 1)
	EventBus.stage_completed.connect(func(_s, _r, _q, out: String) -> void:
		_calls_inflight = maxi(_calls_inflight - 1, 0)
		_tokens_est += out.length() / 4
		if _meter_label:
			_meter_label.text = "≈%dk tok" % (_tokens_est / 1000) if _tokens_est >= 1000 else "≈%d tok" % _tokens_est)

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


## Courtyard birds on a lazy random timer (Tiny Glade: the world
## rewards you with unprompted small events).
func _start_chirps(world: Node) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.timeout.connect(func() -> void:
		var host := Node3D.new()
		host.position = office.grid_to_world(
			Vector2i(randi_range(10, 14), randi_range(8, 11)))
		host.position.y = randf_range(1.5, 2.4)
		world.add_child(host)
		Sfx.play_at(host, "chirp", -12.0, 0.15)
		get_tree().create_timer(2.0).timeout.connect(host.queue_free)
		t.start(randf_range(18.0, 45.0)))
	add_child(t)
	t.start(randf_range(6.0, 15.0))


## One-shot confetti burst (GPUParticles3D), publish celebrations only.
func _confetti(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 140
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.95
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 65.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0, -4.5, 0)
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.45, 0.33))
	grad.add_point(0.34, Color(0.98, 0.74, 0.02))
	grad.add_point(0.67, Color(0.26, 0.52, 0.96))
	grad.set_color(1, Color(0.20, 0.66, 0.33))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_initial_ramp = gt
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.075)
	p.draw_pass_1 = quad
	office.add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


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
	# day/night: a 10-minute loop shifting ONLY the exterior (interior
	# luminaires stay constant — interior-safe per the craft research,
	# and the office itself gets no direct sun, per the owner's rule)
	_day_t = fmod(_day_t + delta, 600.0)
	var phase := _day_t / 600.0  # 0..1, 0 = dawn
	var daylight := clampf(sin(phase * TAU) * 0.5 + 0.55, 0.0, 1.0)
	if _sun:
		_sun.light_energy = lerpf(0.10, 0.45, daylight)
		_sun.light_color = Color(0.85, 0.90, 1.0).lerp(Color(1.0, 0.72, 0.5),
			clampf(1.0 - absf(daylight - 0.35) * 4.0, 0.0, 1.0) * 0.7)
	if _env:
		var day_bg := Color(0.80, 0.87, 0.88)
		var night_bg := Color(0.16, 0.18, 0.26)
		_env.background_color = night_bg.lerp(day_bg, daylight)
		_env.ambient_light_energy = lerpf(0.38, 0.5, daylight)
	# cost meter needle spins while calls are in flight
	if _meter_needle and _calls_inflight > 0:
		_meter_needle.rotation.z -= delta * 6.0

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
	# physical keycodes: layout-proof (works on Thai keyboards too)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			_costume_panel.visible = not _costume_panel.visible
		elif _awaiting_approval and (event.physical_keycode == KEY_Y or event.keycode == KEY_Y):
			EventBus.approval_resolved.emit(true)
			EventBus.log_line.emit("✔ Approved at the desk.")
		elif _awaiting_approval and (event.physical_keycode == KEY_N or event.keycode == KEY_N):
			EventBus.approval_resolved.emit(false)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov / 1.08, 12.0, 55.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov * 1.08, 12.0, 55.0)


## Mouse events land on the SubViewportContainer — route them here.
## Click-first: left = inspect, wheel = zoom, right/middle drag = pan.
func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cam.fov = clampf(_cam.fov / 1.08, 12.0, 55.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam.fov = clampf(_cam.fov * 1.08, 12.0, 55.0)
			MOUSE_BUTTON_LEFT:
				_pick_agent(event.position)
	elif event is InputEventMouseMotion and \
			event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		var right := _cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		var fwd := -_cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var k := 0.011 * (_cam.fov / 27.0)
		_cam.position += right * -event.relative.x * k + fwd * event.relative.y * k


## No physics needed: ray-vs-agent distance picking. Click an agent to
## open their inspector card — the "why" panel (needs, memories, mood).
func _pick_agent(screen_pos: Vector2) -> void:
	var origin := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var best: TownAgent3D = null
	var best_d := 0.9
	for a in get_tree().get_nodes_in_group("agents"):
		var agent := a as TownAgent3D
		if agent == null:
			continue
		var p: Vector3 = agent.global_position + Vector3(0, 0.7, 0)
		var t := (p - origin).dot(dir)
		if t <= 0.0:
			continue
		var d := (p - (origin + dir * t)).length()
		if d < best_d:
			best_d = d
			best = agent
	if best:
		_show_inspector(best)
		Sfx.play_ui("paper", -14.0)
	elif _inspector:
		_inspector.visible = false


func _show_inspector(agent: TownAgent3D) -> void:
	var lines: Array[String] = []
	lines.append("%s  —  %s" % [agent.role.to_upper(),
		["IDLE", "WALKING", "WORKING"][agent.state]])
	lines.append("")
	for need in ["energy", "social", "inspiration"]:
		var v: float = agent.needs[need]
		var bar := "▮".repeat(int(v * 5.0 + 0.5)) + "▯".repeat(5 - int(v * 5.0 + 0.5))
		lines.append("%-12s %s" % [need.to_upper(), bar])
	var mems := Memory.recall(agent.role, "", 3)
	if not mems.is_empty():
		lines.append("")
		lines.append("Remembers:")
		for m in mems:
			lines.append("• " + str(m["text"]).left(64))
	var rels: Array[String] = []
	for other in Memory.ROLES:
		if other == agent.role:
			continue
		var v := Memory.get_affinity(agent.role, other)
		if v >= 0.7:
			rels.append("♥ " + other)
		elif v <= 0.32:
			rels.append("⚡ " + other)
	if not rels.is_empty():
		lines.append("")
		lines.append(" ".join(rels))
	_inspector_text.text = "\n".join(lines)
	_inspector.visible = true
	_inspector_timer.start(12.0)


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
	# click-first UX: a real button (C still works as a shortcut)
	var btn := Button.new()
	btn.text = "  Costumes  "
	btn.position = Vector2(1770, 16)
	btn.pressed.connect(func() -> void:
		_costume_panel.visible = not _costume_panel.visible)
	hud.add_child(btn)
	# show the panel in dev screenshots
	if not OS.get_environment("AGENT_TOWN_SHOT").is_empty():
		_costume_panel.visible = true


## The approval-desk HUD panel (hidden until the pipeline waits on you).
func _build_approval_panel() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	_approval_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.94)
	sb.border_color = Color(0.95, 0.45, 0.33)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_approval_panel.add_theme_stylebox_override("panel", sb)
	_approval_panel.position = Vector2(560, 320)
	_approval_panel.custom_minimum_size = Vector2(800, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_approval_text = Label.new()
	_approval_text.add_theme_font_size_override("font_size", 15)
	_approval_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_approval_text.custom_minimum_size = Vector2(770, 0)
	vb.add_child(_approval_text)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var ok := Button.new()
	ok.text = "  Approve [Y]  "
	ok.pressed.connect(func() -> void:
		EventBus.approval_resolved.emit(true)
		EventBus.log_line.emit("✔ Approved at the desk."))
	hb.add_child(ok)
	var no := Button.new()
	no.text = "  Request revision [N]  "
	no.pressed.connect(func() -> void:
		EventBus.approval_resolved.emit(false))
	hb.add_child(no)
	vb.add_child(hb)
	_approval_panel.add_child(vb)
	_approval_panel.visible = false
	hud.add_child(_approval_panel)

	# the agent inspector card (opens on click)
	_inspector = PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	isb.set_corner_radius_all(8)
	isb.set_content_margin_all(12)
	_inspector.add_theme_stylebox_override("panel", isb)
	_inspector.position = Vector2(12, 200)
	_inspector_text = Label.new()
	_inspector_text.add_theme_font_size_override("font_size", 13)
	_inspector_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_text.custom_minimum_size = Vector2(360, 0)
	_inspector.add_child(_inspector_text)
	_inspector.visible = false
	hud.add_child(_inspector)
	_inspector_timer = Timer.new()
	_inspector_timer.one_shot = true
	_inspector_timer.timeout.connect(func() -> void: _inspector.visible = false)
	add_child(_inspector_timer)


## A wall-mounted "electric meter" by the intake wall: the needle spins
## while Claude calls are in flight, the dial counts estimated tokens.
func _build_cost_meter() -> void:
	var base := Node3D.new()
	base.position = Vector3(16.9, 2.1, 0.24)
	office.add_child(base)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.5, 0.5, 0.05)
	plate.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.85, 0.84, 0.80)
	mm.roughness = 0.4
	plate.material_override = mm
	base.add_child(plate)
	var dial := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.16
	dm.bottom_radius = 0.16
	dm.height = 0.02
	dial.mesh = dm
	dial.rotation_degrees = Vector3(90, 0, 0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.94, 0.93, 0.9)
	dial.material_override = dmat
	dial.position = Vector3(0, 0.06, 0.03)
	base.add_child(dial)
	_meter_needle = Node3D.new()
	_meter_needle.position = Vector3(0, 0.06, 0.045)
	base.add_child(_meter_needle)
	var needle := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.02, 0.13, 0.01)
	needle.mesh = nm
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.95, 0.45, 0.33)
	needle.material_override = nmat
	needle.position = Vector3(0, 0.055, 0)
	_meter_needle.add_child(needle)
	_meter_label = Label3D.new()
	_meter_label.text = "≈0 tok"
	_meter_label.font_size = 30
	_meter_label.outline_size = 6
	_meter_label.pixel_size = 0.0032
	_meter_label.modulate = Color(0.25, 0.25, 0.3)
	_meter_label.position = Vector3(0, -0.17, 0.035)
	base.add_child(_meter_label)


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
