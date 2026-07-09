## The TEAM board: one honest row per agent showing what they're doing
## RIGHT NOW (k9s / mission-control: many small true instruments).
## Live-by-default — reads real agent state once a second, never stale.
class_name TeamBoard
extends Node3D

const ROLES := ["director", "researcher", "writer", "editor", "publisher"]

var _rows: Dictionary = {}
var _dots: Dictionary = {}


func _ready() -> void:
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 1.05, 0.04)
	bg.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.30, 0.36)
	m.roughness = 0.75
	bg.material_override = m
	add_child(bg)
	var title := Label3D.new()
	title.font = I18n.ui_font
	I18n.reg(title, "text", "team_title")
	title.font_size = 34
	title.outline_size = 7
	title.pixel_size = 0.0032
	title.modulate = Color(0.9, 0.89, 0.85)
	title.position = Vector3(-0.78, 0.42, 0.03)
	add_child(title)
	for i in ROLES.size():
		var role: String = ROLES[i]
		var y := 0.24 - i * 0.16
		var chip := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.05, 0.11, 0.02)
		chip.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Office3D.ROLE_ACCENT.get(role, Color.GRAY)
		cmat.emission_enabled = true
		cmat.emission = cmat.albedo_color * 0.4
		chip.material_override = cmat
		chip.position = Vector3(-0.9, y, 0.03)
		add_child(chip)
		var name_l := Label3D.new()
		name_l.text = role.to_upper().left(5)
		name_l.font_size = 24
		name_l.outline_size = 5
		name_l.pixel_size = 0.0030
		name_l.modulate = Color(0.92, 0.91, 0.87)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.position = Vector3(-0.84, y, 0.03)
		add_child(name_l)
		var task_l := Label3D.new()
		task_l.font = I18n.ui_font
		task_l.text = "available"
		task_l.font_size = 22
		task_l.outline_size = 4
		task_l.pixel_size = 0.0030
		task_l.modulate = Color(0.72, 0.76, 0.72)
		task_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		task_l.position = Vector3(-0.50, y, 0.03)
		add_child(task_l)
		_rows[role] = task_l
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.022
		dm.height = 0.044
		dot.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.5, 0.55, 0.5)
		dmat.emission_enabled = true
		dot.material_override = dmat
		dot.position = Vector3(0.9, y, 0.035)
		add_child(dot)
		_dots[role] = dot
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_timer.start()


var _timer: Timer


## LEAK GUARD (godot#90017): while the window is hidden/occluded on
## macOS, every dynamic mesh update (Label3D.text set) leaks until the
## window is shown again. So: never write unchanged values, and slow
## the cadence right down whenever the app is not the focused window.
func _refresh() -> void:
	var focused := DisplayServer.window_is_focused()
	var want := 1.0 if focused else 10.0
	if not is_equal_approx(_timer.wait_time, want):
		_timer.wait_time = want
	for a in get_tree().get_nodes_in_group("agents"):
		var agent := a as TownAgent3D
		if agent == null or not _rows.has(agent.role):
			continue
		var task_l: Label3D = _rows[agent.role]
		var text: String = agent.current_task
		if agent.state == TownAgent3D.State.WALKING and agent._target_is_work:
			text = I18n.t("task_heading")
		elif text == "available":
			text = I18n.t("task_available")
		elif text.begins_with("break"):
			text = I18n.t("task_break") + text.trim_prefix("break")
		text = text.left(26)
		if task_l.text != text:
			task_l.text = text
		var col := Color(0.55, 0.75, 1.0)  # busy blue
		match agent.state:
			TownAgent3D.State.WORKING:
				col = Color(1.0, 0.72, 0.32)
			TownAgent3D.State.IDLE:
				col = Color(0.45, 0.85, 0.5) if text == I18n.t("task_available") \
					else Color(0.8, 0.75, 0.5)
		var dot: MeshInstance3D = _dots[agent.role]
		var dmat := dot.material_override as StandardMaterial3D
		if not dmat.albedo_color.is_equal_approx(col):
			dmat.albedo_color = col
			dmat.emission = col * 0.6
		var mod := Color(0.92, 0.91, 0.87) if agent.state != TownAgent3D.State.IDLE \
			else Color(0.72, 0.76, 0.72)
		if not task_l.modulate.is_equal_approx(mod):
			task_l.modulate = mod
