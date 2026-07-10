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
var _studio: CaptionStudio
var _build: BuildMode
var _awaiting_approval := false
var _approval_full := ""
var _sun: DirectionalLight3D
var _env: Environment
var _day_t := 150.0  # start mid-morning
var _meter_needle: Node3D
var _meter_label: Label3D
var _tokens_est := 0
var _calls_inflight := 0
var _pipeline: Pipeline
var _inspector: PanelContainer
var _inspector_text: Label
var _inspector_timer: Timer
var _inspected: TownAgent3D
var _input_panel: PanelContainer
var _input_label: Label
var _input_edit: LineEdit
var _input_cb: Callable = Callable()
var _asking := false


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

	_pipeline = Pipeline.new()
	add_child(_pipeline)

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
	EventBus.stage_started.connect(func(_stage: String, _role: String, _request: Dictionary) -> void:
		_update_now())
	EventBus.stage_completed.connect(func(stage: String, role: String, _request: Dictionary, _result: String) -> void:
		_append_log("%s finished %s" % [role, stage]))
	# delegation flow, narrated + shown (UX audit P1): a chat-feed line
	# and a document flying from the giver to the receiver
	EventBus.handoff.connect(func(from_role: String, to_role: String, stage: String, request: Dictionary) -> void:
		EventBus.chat_line.emit(from_role, I18n.f("handoff_line", [
			str(request.get("topic", "")).left(24),
			I18n.t("role_" + to_role), I18n.t("stg_" + stage)])
		)
		_fly_doc(from_role, to_role))
	EventBus.request_cancelled.connect(func(request: Dictionary) -> void:
		_append_log("✕ Cancelled: %s" % str(request.get("topic", "")).left(40))
		_update_now())
	EventBus.request_completed.connect(func(request: Dictionary, output_dir: String) -> void:
		_update_now()
		_append_log("Package saved: output/%s" % output_dir.get_file())
		_append_log("The crew gathers in the town hall!")
		_deliver(output_dir)
		# the team ASKS before closing the job: anything to fix?
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			_ask_feedback(request))
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

	# presence (Animal Crossing's law): the crew knows you arrived
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		EventBus.agent_say.emit("director", I18n.f("say_greet", [Config.owner_name])))

	# ambient bed: HVAC room tone + occasional courtyard birds
	Sfx.start_room_tone(world, -26.0)
	_start_chirps(world)

	# drop a video ANYWHERE on the window -> straight into the pipeline
	get_window().files_dropped.connect(_on_files_dropped)
	# ...and AirDrops are noticed automatically (Downloads watcher asks once)
	_start_downloads_watch()

	# leak guard v2: build the sleep timer HERE (a FOCUS_OUT can arrive
	# mid-scene-setup, when add_child would fail), and cover boots that
	# never receive focus (nohup launches — the overnight-Jetsam case)
	_display_sleep = Timer.new()
	_display_sleep.one_shot = true
	_display_sleep.timeout.connect(func() -> void:
		RenderingServer.render_loop_enabled = false
		print("[sleep] display off (window backgrounded) — logic keeps running"))
	add_child(_display_sleep)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if not DisplayServer.window_is_focused():
			_arm_display_sleep())

	# the approval desk gate + the diegetic cost meter
	_build_approval_panel()
	EventBus.approval_requested.connect(func(request: Dictionary, preview: String) -> void:
		_awaiting_approval = true
		_approval_full = preview
		_approval_text.text = "APPROVAL DESK — '%s'\n\n%s\n\n[Y] approve · [N] request revision · auto-approve in 45 s" % [
			str(request.get("topic", "")).left(48), _review_summary(preview)]
		_approval_panel.visible = true
		Sfx.play_ui("paper", -6.0))
	EventBus.approval_resolved.connect(func(_a: bool) -> void:
		_awaiting_approval = false
		_approval_panel.visible = false)
	# Sims-style build mode, phase 1: move/rotate the existing furniture
	_build = BuildMode.new()
	_build.cam = _cam
	_build.office = office
	add_child(_build)
	_build.apply_layout()
	if OS.get_environment("AGENT_TOWN_BUILD") != "":  # dev: shot with catalog open
		_build.toggle()

	# the Caption Review Studio: pre-burn gate for clips (CapCut moment)
	var studio_layer := CanvasLayer.new()
	studio_layer.layer = 7
	add_child(studio_layer)
	_studio = CaptionStudio.new()
	studio_layer.add_child(_studio)
	EventBus.clip_review_requested.connect(func(_req: Dictionary, srt: String, prev: String) -> void:
		_studio.open_clip(srt, prev))
	# dev hook: AGENT_TOWN_STUDIO="<srt>|<preview_dir>" opens it on boot
	var dev_studio := OS.get_environment("AGENT_TOWN_STUDIO")
	if not dev_studio.is_empty() and dev_studio.contains("|"):
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			_studio.open_clip(dev_studio.get_slice("|", 0), dev_studio.get_slice("|", 1)))
	_build_cost_meter()
	EventBus.stage_started.connect(func(_s, _r, _q) -> void:
		_calls_inflight += 1)
	EventBus.stage_completed.connect(func(_s, _r, _q, _out: String) -> void:
		_calls_inflight = maxi(_calls_inflight - 1, 0)
		if _meter_label:
			_meter_label.text = "≈%dk tok" % (TaskQueue.tokens_est / 1000) if TaskQueue.tokens_est >= 1000 else "≈%d tok" % TaskQueue.tokens_est)

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


const VIDEO_EXT := ["mov", "mp4", "m4v", "mkv", "webm"]


## Drag-and-drop onto the window: videos go straight into the inbox.
func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		if f.get_extension().to_lower() in VIDEO_EXT:
			_ask_clip_options(f)


func _ingest_dropped(path: String, opts: Dictionary = {}) -> void:
	var dest := ProjectSettings.globalize_path("res://inbox").path_join(path.get_file())
	if DirAccess.copy_absolute(path, dest) == OK:
		if not opts.is_empty():
			var f := FileAccess.open(dest + ".opts.json", FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(opts))
		_append_log(I18n.t("clip_received"))
		Sfx.play_ui("paper", -6.0)


## Follow-up questions before the team touches a clip (the owner picks
## the scope): subtitles always; burn and caption are opt-in toggles.
func _ask_clip_options(path: String) -> void:
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	sb.border_color = Color(0.55, 0.75, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(560, 210)
	panel.custom_minimum_size = Vector2(520, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = I18n.f("clip_opt_title", [path.get_file()])
	l.add_theme_font_size_override("font_size", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(490, 0)
	vb.add_child(l)
	var srt_row := Label.new()
	srt_row.text = "✓  " + I18n.t("clip_opt_srt")
	srt_row.add_theme_font_size_override("font_size", 14)
	srt_row.add_theme_color_override("font_color", Color(0.62, 0.78, 0.62))
	vb.add_child(srt_row)
	var burn_cb := CheckButton.new()
	I18n.reg(burn_cb, "text", "clip_opt_burn")
	burn_cb.button_pressed = true
	burn_cb.add_theme_font_size_override("font_size", 14)
	vb.add_child(burn_cb)
	var cap_cb := CheckButton.new()
	I18n.reg(cap_cb, "text", "clip_opt_caption")
	cap_cb.button_pressed = true
	cap_cb.add_theme_font_size_override("font_size", 14)
	vb.add_child(cap_cb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var go := Button.new()
	go.text = I18n.t("btn_send_team")
	go.pressed.connect(func() -> void:
		_ingest_dropped(path, {
			"burn": burn_cb.button_pressed,
			"caption": cap_cb.button_pressed,
		})
		hud.queue_free())
	hb.add_child(go)
	var no := Button.new()
	no.text = I18n.t("btn_not_work")
	no.pressed.connect(hud.queue_free)
	hb.add_child(no)
	vb.add_child(hb)
	panel.add_child(vb)
	hud.add_child(panel)


## Watch Downloads for videos that appear AFTER boot (AirDrop lands
## there) — ask once per file, never grab silently.
var _dl_seen: Dictionary = {}
var _boot_time := 0


func _start_downloads_watch() -> void:
	_boot_time = int(Time.get_unix_time_from_system())
	var dl := OS.get_environment("HOME") + "/Downloads"
	var t := Timer.new()
	t.wait_time = 6.0
	t.timeout.connect(func() -> void:
		var dir := DirAccess.open(dl)
		if dir == null:
			return
		for f in dir.get_files():
			if not (f.get_extension().to_lower() in VIDEO_EXT):
				continue
			if _dl_seen.has(f):
				continue
			var p := dl.path_join(f)
			if FileAccess.get_modified_time(p) < _boot_time:
				_dl_seen[f] = true
				continue
			_dl_seen[f] = true
			_ask_clip(p))
	add_child(t)
	t.start()


func _ask_clip(path: String) -> void:
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	sb.border_color = Color(0.55, 0.75, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(620, 90)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = I18n.t("clip_found") % path.get_file()
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var yes := Button.new()
	yes.text = I18n.t("btn_send_team")
	yes.pressed.connect(func() -> void:
		hud.queue_free()
		_ask_clip_options(path))
	hb.add_child(yes)
	var no := Button.new()
	no.text = I18n.t("btn_not_work")
	no.pressed.connect(hud.queue_free)
	hb.add_child(no)
	vb.add_child(hb)
	panel.add_child(vb)
	hud.add_child(panel)
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(hud):
			hud.queue_free())


## The team asks the owner before closing a job: anything to fix?
## "Good" = the crew remembers being appreciated; a typed fix becomes
## a real revision (clip: re-edit the actual SRT + re-burn).
func _ask_feedback(request: Dictionary) -> void:
	var topic := str(request.get("topic", "")).left(36)
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.96)
	sb.border_color = Color(1.0, 0.85, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(560, 150)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = I18n.t("ask_feedback") % topic
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	vb.add_child(l)
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(700, 0)
	vb.add_child(edit)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var send_fix := func() -> void:
		var text := edit.text.strip_edges()
		if not text.is_empty():
			_pipeline.revise(request, text)
		hud.queue_free()
	var fix_btn := Button.new()
	fix_btn.text = I18n.t("btn_send_fix")
	fix_btn.pressed.connect(send_fix)
	hb.add_child(fix_btn)
	edit.text_submitted.connect(func(_t: String) -> void: send_fix.call())
	var good := Button.new()
	good.text = I18n.t("btn_good")
	good.pressed.connect(func() -> void:
		Memory.remember_all(I18n.f("mem_feedback_good", [Config.owner_name, topic]), 7.0)
		for r in Memory.ROLES:
			Memory.nudge_affinity(r, "owner", 0.04)
		EventBus.agent_say.emit("director", I18n.f("say_feedback_good", [Config.owner_name]))
		Sfx.play_ui("chime", -12.0)
		hud.queue_free())
	hb.add_child(good)
	vb.add_child(hb)
	panel.add_child(vb)
	hud.add_child(panel)
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		if is_instance_valid(hud):
			hud.queue_free())


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
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(host):
				host.queue_free())
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


## LEAK GUARD v2 (godot#90017 + a Jetsam kill at 134 GB): on macOS a
## FULLY OCCLUDED window leaks Metal-side memory for every animated
## mesh frame — invisible to the engine's own counters. FPS caps only
## slow it. The real fix: after 60 s unfocused, stop the render loop
## entirely (game logic, queues and CLI calls keep running); the first
## click/focus wakes the display instantly.
var _display_sleep: Timer


func _arm_display_sleep() -> void:
	Engine.max_fps = 20
	# a FOCUS_OUT can arrive before _ready finished building the timer —
	# defer and try again on the next idle frame
	if _display_sleep == null or not _display_sleep.is_inside_tree():
		call_deferred("_arm_display_sleep")
		return
	_display_sleep.start(60.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("[sleep] app focus lost — arming 60 s display sleep")
		_arm_display_sleep()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _display_sleep:
			_display_sleep.stop()
		if not RenderingServer.render_loop_enabled:
			print("[sleep] display back on")
		RenderingServer.render_loop_enabled = true
		Engine.max_fps = 0


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
		if _build and _build.handle_key(event.keycode):
			return
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
				if _build and _build.handle_click(event.position):
					pass  # build mode consumed the click
				else:
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
	_inspected = agent
	var lines: Array[String] = []
	lines.append("%s  —  %s" % [agent.role.to_upper(),
		I18n.t(["state_idle", "state_walking", "state_working"][agent.state])])
	lines.append("")
	for need in ["energy", "social", "inspiration"]:
		var v: float = agent.needs[need]
		var bar := "▮".repeat(int(v * 5.0 + 0.5)) + "▯".repeat(5 - int(v * 5.0 + 0.5))
		lines.append("%-14s %s" % [I18n.t("need_" + need), bar])
	var mems := Memory.recall(agent.role, "", 3)
	if not mems.is_empty():
		lines.append("")
		lines.append(I18n.t("remembers"))
		for m in mems:
			var t := str(m["text"])
			lines.append("• " + (t if t.length() <= 160 else t.left(157) + "..."))
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
	I18n.reg(_status, "text", "status_idle")
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
	# ---- COMMAND DOCK — sim-game convention (Two Point / Skylines
	# research): ONE bottom-center bar, three groups with separators —
	# COMMAND (coral, the star) | VIEW panels | SETTINGS. Buttons show
	# an active state while their panel is open. No more corner sprawl.
	var board_panel := BoardPanel.new()
	board_panel.visible = false
	hud.add_child(board_panel)
	# mid-flight scope change: typed note reaches every remaining stage
	board_panel.scope_requested.connect(func(topic: String) -> void:
		_open_input(I18n.t("prompt_scope"), func(text: String) -> void:
			TaskQueue.set_scope(topic, text)
			EventBus.agent_say.emit("director", I18n.f("say_scope", [text.left(60)]))))
	var feed := ChatFeed.new()
	feed.visible = false
	hud.add_child(feed)

	var dock_holder := MarginContainer.new()
	dock_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock_holder.offset_top = -110
	dock_holder.add_theme_constant_override("margin_bottom", 14)
	dock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock_center := CenterContainer.new()
	dock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_holder.add_child(dock_center)
	var dock := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	dsb.border_color = Color(0.32, 0.32, 0.40)
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(14)
	dsb.set_content_margin_all(8)
	dock.add_theme_stylebox_override("panel", dsb)
	var dock_row := HBoxContainer.new()
	dock_row.add_theme_constant_override("separation", 6)
	dock.add_child(dock_row)
	dock_center.add_child(dock)
	hud.add_child(dock_holder)

	var coral := Color(0.95, 0.45, 0.33)
	var mk := func(key: String, tip: String) -> Button:
		var b := Button.new()
		I18n.reg(b, "text", key)
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 15)
		b.tooltip_text = tip
		dock_row.add_child(b)
		return b
	var sep := func() -> void:
		var s := VSeparator.new()
		s.modulate = Color(1, 1, 1, 0.25)
		dock_row.add_child(s)

	# 1) COMMAND — the one-click brief (was 3 clicks through the inspector)
	var cmd: Button = mk.call("dock_command", "Enter")
	cmd.add_theme_color_override("font_color", Color(1.0, 0.72, 0.55))
	cmd.pressed.connect(func() -> void:
		_open_input(I18n.t("prompt_command"), func(text: String) -> void:
			EventBus.chat_line.emit(Config.owner_name, text)
			EventBus.agent_say.emit("director", I18n.t("ack_thinking"))
			for a in get_tree().get_nodes_in_group("agents"):
				if a.role == "director":
					a.chat_reply(text)
					break))
	var idea: Button = mk.call("btn_idea", "")
	idea.pressed.connect(func() -> void:
		_open_input("Pin an idea on the board (a reel topic — Thai or English)",
			_submit_idea))
	# research: the dock holds ONLY act-now commands (3-5 max); every
	# manage/observe surface lives in the sidebar rail
	_build_sidebar(hud, board_panel, feed)
	# first-run coach marks (UX audit P5): three ways to command, shown
	# once, dismissed forever (UI-fade doctrine)
	if not FileAccess.file_exists("user://seen_hints.txt"):
		var hint := PanelContainer.new()
		var hsb := StyleBoxFlat.new()
		hsb.bg_color = Color(0.09, 0.09, 0.13, 0.96)
		hsb.border_color = Color(1.0, 0.78, 0.32)
		hsb.set_border_width_all(2)
		hsb.set_corner_radius_all(10)
		hsb.set_content_margin_all(16)
		hint.add_theme_stylebox_override("panel", hsb)
		hint.position = Vector2(660, 540)  # clear of the command dock
		hint.custom_minimum_size = Vector2(600, 0)
		var hvb := VBoxContainer.new()
		hvb.add_theme_constant_override("separation", 8)
		var ht := Label.new()
		I18n.reg(ht, "text", "hint_title")
		ht.add_theme_font_size_override("font_size", 18)
		ht.modulate = Color(1.0, 0.85, 0.4)
		hvb.add_child(ht)
		var hb := Label.new()
		I18n.reg(hb, "text", "hint_body")
		hb.add_theme_font_size_override("font_size", 14)
		hvb.add_child(hb)
		var ok := Button.new()
		I18n.reg(ok, "text", "btn_got_it")
		ok.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ok.pressed.connect(func() -> void:
			var hf := FileAccess.open("user://seen_hints.txt", FileAccess.WRITE)
			if hf:
				hf.store_string("1")
			hint.queue_free())
		hvb.add_child(ok)
		hint.add_child(hvb)
		hud.add_child(hint)
	# show the panel in dev screenshots
	if not OS.get_environment("AGENT_TOWN_SHOT").is_empty():
		_costume_panel.visible = true


## ---- SIDEBAR RAIL (IA research: sidebar = grouped manage/observe
## surfaces, shallow nesting; the dock keeps only act-now commands) ----
var _side_buttons: Dictionary = {}
var _side_panels: Dictionary = {}


func _build_sidebar(hud: CanvasLayer, board_panel: Control, feed: Control) -> void:
	_side_panels = {
		"side_board": board_panel,
		"side_chat": feed,
		"side_team": _build_team_panel(hud),
		"side_system": _build_system_panel(hud),
		"side_settings": _build_settings_panel(hud),
	}
	var rail := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.32, 0.32, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(6)
	rail.add_theme_stylebox_override("panel", sb)
	rail.position = Vector2(16, 200)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	for key in ["side_board", "side_chat", "side_team", "side_system", "side_build", "side_done", "side_settings"]:
		var b := Button.new()
		I18n.reg(b, "text", key)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(150, 40)
		b.add_theme_font_size_override("font_size", 14)
		b.flat = true
		var k: String = key
		b.pressed.connect(func() -> void: _side_toggle(k))
		vb.add_child(b)
		_side_buttons[key] = b
	rail.add_child(vb)
	hud.add_child(rail)


func _side_toggle(key: String) -> void:
	if key == "side_done":
		OS.shell_open(ProjectSettings.globalize_path("res://output"))
		return
	if key == "side_build":
		_build.toggle()
		var bb := _side_buttons[key] as Button
		if _build.active:
			bb.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
			EventBus.log_line.emit(I18n.t("build_hint"))
		else:
			bb.remove_theme_color_override("font_color")
		return
	var target: Control = _side_panels.get(key)
	if target == null:
		return
	var opening := not target.visible
	# one panel at a time (research: reduce simultaneous surfaces)
	for k in _side_panels:
		(_side_panels[k] as Control).visible = false
		(_side_buttons.get(k) as Button).remove_theme_color_override("font_color")
	if opening:
		target.visible = true
		(_side_buttons[key] as Button).add_theme_color_override(
			"font_color", Color(0.95, 0.45, 0.33))


## TEAM: each agent's experience, bond with you, and the levers that
## exist today to grow them (praise/coach = the current skill system).
func _build_team_panel(hud: CanvasLayer) -> PanelContainer:
	var p := _side_panel_shell(hud, Vector2(190, 200), Vector2(560, 0))
	var vb: VBoxContainer = p.get_child(0)
	var title := Label.new()
	I18n.reg(title, "text", "team_panel_title")
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.85, 0.4)
	vb.add_child(title)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	vb.add_child(rows)
	var note := Label.new()
	I18n.reg(note, "text", "team_note")
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(0.7, 0.7, 0.76)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)
	var refresh := func() -> void:
		for c in rows.get_children():
			c.queue_free()
		for a in get_tree().get_nodes_in_group("agents"):
			var who := a
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var chip := ColorRect.new()
			chip.custom_minimum_size = Vector2(10, 30)
			chip.color = BoardPanel.ROLE_COLOR.get(who.role, Color.GRAY)
			row.add_child(chip)
			var name_l := Label.new()
			name_l.text = I18n.t("role_" + who.role)
			name_l.custom_minimum_size = Vector2(110, 0)
			name_l.add_theme_font_size_override("font_size", 14)
			row.add_child(name_l)
			var xp := Label.new()
			var mems: int = (Memory.memories.get(who.role, []) as Array).size()
			xp.text = I18n.f("team_xp", [mems, int(Memory.get_affinity(who.role, "owner") * 100)])
			xp.add_theme_font_size_override("font_size", 12)
			xp.modulate = Color(0.75, 0.78, 0.75)
			xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(xp)
			var coach := Button.new()
			I18n.reg(coach, "text", "btn_coach")
			coach.pressed.connect(func() -> void:
				_open_input("Coach the %s (what should they do differently?)" % who.role,
					func(text: String) -> void: who.coached(text)))
			row.add_child(coach)
			var chat := Button.new()
			I18n.reg(chat, "text", "btn_chat")
			chat.pressed.connect(func() -> void:
				_open_input("Say something to the %s" % who.role,
					func(text: String) -> void:
						EventBus.chat_line.emit(Config.owner_name, text)
						EventBus.agent_say.emit(who.role, I18n.t("ack_thinking"))
						who.chat_reply(text)))
			row.add_child(chat)
			var dress := Button.new()
			I18n.reg(dress, "text", "btn_dress")
			dress.pressed.connect(func() -> void:
				_costume_panel._on_role_selected(who.role)
				_costume_panel.visible = true)
			row.add_child(dress)
			rows.add_child(row)
	p.visibility_changed.connect(func() -> void:
		if p.visible:
			refresh.call())
	return p


## SYSTEM: the real flow — live jobs, token spend, engine health.
func _build_system_panel(hud: CanvasLayer) -> PanelContainer:
	var p := _side_panel_shell(hud, Vector2(190, 200), Vector2(560, 0))
	var vb: VBoxContainer = p.get_child(0)
	var title := Label.new()
	I18n.reg(title, "text", "sys_title")
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.85, 0.4)
	vb.add_child(title)
	var body := Label.new()
	body.add_theme_font_size_override("font_size", 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body)
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(func() -> void:
		if not p.visible:
			return
		var jobs := TaskQueue.status_text() if not TaskQueue.jobs.is_empty() else I18n.t("sys_none")
		body.text = "%s\n\n%s %s\n%s %d  ·  %s %d %s\n%s %s" % [
			jobs,
			I18n.t("sys_tokens"), ("≈%dk" % (TaskQueue.tokens_est / 1000)) if TaskQueue.tokens_est >= 1000 else ("≈%d" % TaskQueue.tokens_est),
			I18n.t("sys_fps"), int(Engine.get_frames_per_second()),
			I18n.t("sys_uptime"), int(Time.get_ticks_msec() / 60000.0), I18n.t("sys_min"),
			I18n.t("sys_display"), I18n.t("sys_on") if RenderingServer.render_loop_enabled else I18n.t("sys_off"),
		])
	p.add_child(t)
	t.start()
	return p


## SETTINGS: language, character set, office branches (future), notes.
func _build_settings_panel(hud: CanvasLayer) -> PanelContainer:
	var p := _side_panel_shell(hud, Vector2(190, 200), Vector2(520, 0))
	var vb: VBoxContainer = p.get_child(0)
	# effects volume: the whole foley layer on one slider (persisted)
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 10)
	var vlab := Label.new()
	I18n.reg(vlab, "text", "set_sfx")
	vlab.add_theme_font_size_override("font_size", 14)
	vrow.add_child(vlab)
	var vs := HSlider.new()
	vs.min_value = 0
	vs.max_value = 100
	vs.step = 5
	vs.value = Sfx.master_pct
	vs.custom_minimum_size = Vector2(220, 24)
	vs.value_changed.connect(func(v: float) -> void:
		Sfx.set_master(v)
		Sfx.play_ui("paper", -8.0))
	vrow.add_child(vs)
	vb.add_child(vrow)
	var title := Label.new()
	I18n.reg(title, "text", "set_title")
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.85, 0.4)
	vb.add_child(title)
	# language
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	var ll := Label.new()
	I18n.reg(ll, "text", "set_lang")
	ll.custom_minimum_size = Vector2(150, 0)
	lrow.add_child(ll)
	var lang_btn := Button.new()
	lang_btn.text = "  ไทย  " if I18n.lang == "en" else "  EN  "
	lang_btn.pressed.connect(func() -> void:
		I18n.toggle()
		lang_btn.text = "  ไทย  " if I18n.lang == "en" else "  EN  ")
	lrow.add_child(lang_btn)
	vb.add_child(lrow)
	# character set
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	var cl := Label.new()
	I18n.reg(cl, "text", "set_charset")
	cl.custom_minimum_size = Vector2(150, 0)
	crow.add_child(cl)
	for s in Costumes.SETS:
		var sbn := Button.new()
		sbn.text = " " + str(Costumes.SETS[s]["label"]) + " "
		var sk := str(s)
		sbn.pressed.connect(func() -> void:
			Costumes.save_set(sk)
			var preset: Dictionary = Costumes.set_preset(sk)
			var all: Dictionary = {}
			for a in get_tree().get_nodes_in_group("agents"):
				a.apply_costume((preset[a.role] as Dictionary).duplicate(true))
				all[a.role] = preset[a.role]
			Costumes.save_all(all))
		crow.add_child(sbn)
	vb.add_child(crow)
	# office branches (the future the owner sketched — honest placeholders)
	var orow := Label.new()
	I18n.reg(orow, "text", "set_office")
	orow.add_theme_font_size_override("font_size", 14)
	vb.add_child(orow)
	for key in ["office_current", "office_soon1", "office_soon2"]:
		var o := Label.new()
		I18n.reg(o, "text", key)
		o.add_theme_font_size_override("font_size", 13)
		o.modulate = Color(0.9, 0.9, 0.86) if key == "office_current" else Color(0.55, 0.55, 0.6)
		vb.add_child(o)
	return p


func _side_panel_shell(hud: CanvasLayer, pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.96)
	sb.border_color = Color(0.32, 0.32, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.custom_minimum_size = min_size
	p.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	hud.add_child(p)
	return p


## The HUD NOW line: one chip per running job (UX audit P3) — never a
## single line hiding two of three parallel jobs.
func _update_now() -> void:
	if TaskQueue.jobs.is_empty():
		_status.text = I18n.t("status_idle")
		return
	var lines: Array[String] = []
	for topic in TaskQueue.jobs:
		var j: Dictionary = TaskQueue.jobs[topic]
		lines.append("⚙ %s %d%% · %s" % [
			I18n.t("stg_" + str(j.get("stage", ""))) if I18n.S.has("stg_" + str(j.get("stage", ""))) else str(j.get("stage", "")),
			int(j.get("pct", 0)), str(topic).left(34)])
	_status.text = "\n".join(lines)


## A work document flies from the giver to the receiver — the handoff
## the human can SEE (the org chart becomes something you watch).
func _fly_doc(from_role: String, to_role: String) -> void:
	var from_a: Node3D = null
	var to_a: Node3D = null
	for a in get_tree().get_nodes_in_group("agents"):
		if a.role == from_role:
			from_a = a
		elif a.role == to_role:
			to_a = a
	if from_a == null or to_a == null:
		return
	var doc := Label3D.new()
	doc.text = "📄"
	doc.font_size = 96
	doc.pixel_size = 0.005
	doc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	doc.no_depth_test = true
	office.add_child(doc)
	doc.global_position = from_a.global_position + Vector3(0, 1.5, 0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(doc, "global_position",
		to_a.global_position + Vector3(0, 1.5, 0), 1.1)
	tw.parallel().tween_property(doc, "modulate:a", 0.9, 1.1)
	tw.tween_property(doc, "modulate:a", 0.0, 0.3)
	tw.tween_callback(doc.queue_free)


func _open_input(prompt_text: String, cb: Callable) -> void:
	_input_label.text = prompt_text
	_input_edit.text = ""
	_input_cb = cb
	_input_panel.visible = true
	_input_edit.grab_focus()


func _submit_input() -> void:
	var text := _input_edit.text.strip_edges()
	_input_panel.visible = false
	var cb := _input_cb
	_input_cb = Callable()
	if text.is_empty():
		if _asking:
			_asking = false
			EventBus.guidance_given.emit("")
		return
	if cb.is_valid():
		cb.call(text)


## Majesty's law: pin an idea, don't issue a command. Writes a real
## request into queue/pending — the Director picks it up in character.
func _submit_idea(topic: String) -> void:
	var path := "res://queue/pending/idea_%d.json" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"topic": topic, "notes": "Pinned on the ideas board by %s." % Config.owner_name}, "  "))
		EventBus.log_line.emit("📌 Idea pinned: %s" % topic.left(48))
		Sfx.play_ui("paper", -8.0)
		# instant ack (UX audit P4): heard, before the queue even polls
		EventBus.agent_say.emit("director", I18n.t("ack_idea"))


## Deliver the finished work into the human's real workflow: a toast
## with one-click access to the package, and — when exports_dir is set —
## the SRT copied EP-numbered into the real production folder.
func _deliver(output_dir: String) -> void:
	# EP-numbered SRT into the configured production folder
	if not Config.exports_dir.is_empty():
		var srt := output_dir.path_join("03_captions.srt")
		if FileAccess.file_exists(srt):
			var slug := output_dir.get_file().get_slice("_", 1)
			var dest := Config.exports_dir.path_join("EP%02d_%s.srt" % [Chronicle.episodes, slug])
			var data := FileAccess.get_file_as_string(srt)
			var f := FileAccess.open(dest, FileAccess.WRITE)
			if f:
				f.store_string(data)
				_append_log("📤 SRT exported: %s" % dest.get_file())
	# toast with one-click open
	var abs_dir := ProjectSettings.globalize_path(output_dir)
	_open_toast("📦 '%s' is ready — script, captions.srt, publish plan." % output_dir.get_file(), abs_dir)


func _open_toast(text: String, open_path: String) -> void:
	var hud := CanvasLayer.new()
	hud.layer = 6
	add_child(hud)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.11, 0.95)
	sb.border_color = Color(0.45, 1.0, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(620, 90)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var open_btn := Button.new()
	open_btn.text = I18n.t("btn_open_pkg")
	open_btn.pressed.connect(func() -> void:
		OS.shell_open(open_path)
		hud.queue_free())
	hb.add_child(open_btn)
	var dismiss := Button.new()
	dismiss.text = I18n.t("btn_later")
	dismiss.pressed.connect(hud.queue_free)
	hb.add_child(dismiss)
	vb.add_child(hb)
	panel.add_child(vb)
	hud.add_child(panel)
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if is_instance_valid(hud):
			hud.queue_free())


## Compact review: outline + lead line instead of a wall of markdown.
## The full text is one button away (opens in the default editor).
func _review_summary(preview: String) -> String:
	var heads: Array[String] = []
	var lead := ""
	for line in preview.split("\n"):
		var t := str(line).strip_edges()
		if t.begins_with("#"):
			if heads.size() < 6:
				heads.append("  • " + t.lstrip("# ").strip_edges().left(60))
		elif not t.is_empty() and lead.length() < 170:
			lead += I18n.strip_md(t) + " "
	var s := lead.strip_edges().left(180)
	if not heads.is_empty():
		s += "\n\n" + I18n.t("review_outline") + "\n" + "\n".join(heads)
	s += "\n\n" + I18n.f("review_stats", [preview.length()])
	return s


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
	var full := Button.new()
	I18n.reg(full, "text", "btn_open_full")
	full.pressed.connect(func() -> void:
		var fp := "user://review_full.md"
		var f := FileAccess.open(fp, FileAccess.WRITE)
		if f:
			f.store_string(_approval_full)
			f = null
			OS.shell_open(ProjectSettings.globalize_path(fp)))
	hb.add_child(full)
	var ok := Button.new()
	I18n.reg(ok, "text", "btn_approve")
	ok.pressed.connect(func() -> void:
		EventBus.approval_resolved.emit(true)
		EventBus.log_line.emit("✔ Approved at the desk."))
	hb.add_child(ok)
	var no := Button.new()
	I18n.reg(no, "text", "btn_revise")
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
	var ivb := VBoxContainer.new()
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func() -> void: _inspector.visible = false)
	ivb.add_child(close)
	_inspector_text = Label.new()
	_inspector_text.add_theme_font_size_override("font_size", 13)
	_inspector_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_text.custom_minimum_size = Vector2(360, 0)
	ivb.add_child(_inspector_text)
	# pillar 6: praise / coach / chat — the owner acts on THIS agent
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var praise := Button.new()
	I18n.reg(praise, "text", "btn_praise")
	praise.pressed.connect(func() -> void:
		if _inspected:
			_inspected.praised()
			_inspector.visible = false)
	actions.add_child(praise)
	var coach := Button.new()
	I18n.reg(coach, "text", "btn_coach")
	coach.pressed.connect(func() -> void:
		if _inspected:
			var who := _inspected
			_open_input("Coach the %s (what should they do differently?)" % who.role,
				func(text: String) -> void: who.coached(text)))
	actions.add_child(coach)
	var chat := Button.new()
	I18n.reg(chat, "text", "btn_chat")
	chat.pressed.connect(func() -> void:
		if _inspected:
			var who := _inspected
			_open_input("Say something to the %s" % who.role,
				func(text: String) -> void:
					EventBus.chat_line.emit(Config.owner_name, text)
					# instant ack (UX audit P4): the agent responds
					# within a beat, before the real reply arrives
					EventBus.agent_say.emit(who.role, I18n.t("ack_thinking"))
					who.chat_reply(text)))
	actions.add_child(chat)
	ivb.add_child(actions)
	_inspector.add_child(ivb)
	_inspector.visible = false
	hud.add_child(_inspector)

	# the shared typed-input dialog (the keyboard's ONE job)
	_input_panel = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.10, 0.14, 0.96)
	psb.border_color = Color(0.55, 0.75, 1.0)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(8)
	psb.set_content_margin_all(14)
	_input_panel.add_theme_stylebox_override("panel", psb)
	_input_panel.position = Vector2(560, 430)
	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 8)
	_input_label = Label.new()
	_input_label.add_theme_font_size_override("font_size", 15)
	_input_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_input_label.custom_minimum_size = Vector2(720, 0)
	pvb.add_child(_input_label)
	_input_edit = LineEdit.new()
	_input_edit.custom_minimum_size = Vector2(720, 0)
	_input_edit.text_submitted.connect(func(_t: String) -> void: _submit_input())
	pvb.add_child(_input_edit)
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 12)
	var send := Button.new()
	I18n.reg(send, "text", "btn_send")
	send.pressed.connect(_submit_input)
	phb.add_child(send)
	var cancel := Button.new()
	I18n.reg(cancel, "text", "btn_cancel")
	cancel.pressed.connect(func() -> void:
		_input_panel.visible = false
		_input_cb = Callable()
		if _asking:
			_asking = false
			EventBus.guidance_given.emit(""))
	phb.add_child(cancel)
	pvb.add_child(phb)
	_input_panel.add_child(pvb)
	_input_panel.visible = false
	hud.add_child(_input_panel)

	# agents asking back (mixed initiative): question -> typed guidance
	EventBus.agent_question.connect(func(role: String, question: String) -> void:
		EventBus.agent_say.emit(role, question)
		_asking = true
		_open_input("The %s asks: %s" % [role.to_upper(), question],
			func(text: String) -> void:
				_asking = false
				EventBus.guidance_given.emit(text)))
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
