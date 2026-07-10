## BUILD MODE (The Sims, phase 1): pick up any tagged furniture piece,
## carry it on the floor grid with snap, R to rotate 90°, click to set
## down, Esc to put back. Every move persists to user:// so the layout
## survives restarts (applied again on boot by apply_saved).
class_name BuildMode
extends Node

const SAVE_PATH := "user://furniture_layout.json"
const SNAP := 0.25

var cam: Camera3D
var active := false
var carrying: Node3D = null
var _orig: Transform3D
var _ring: MeshInstance3D

signal mode_changed(on: bool)


func toggle() -> void:
	if active and carrying:
		cancel_carry()
	active = not active
	mode_changed.emit(active)


## Returns true when the click was consumed by build mode.
func handle_click(mpos: Vector2) -> bool:
	if not active or cam == null:
		return false
	if carrying:
		_place()
		return true
	var p := _floor_point(mpos)
	var best: Node3D = null
	var bd := 0.9
	for f in get_tree().get_nodes_in_group("furniture"):
		var fp := (f as Node3D).global_position
		var d := Vector2(fp.x - p.x, fp.z - p.z).length()
		if d < bd:
			bd = d
			best = f
	if best:
		_pick(best)
	return true


func handle_key(keycode: int) -> bool:
	if not active or carrying == null:
		return false
	if keycode == KEY_R:
		carrying.rotation_degrees.y = fposmod(carrying.rotation_degrees.y + 90.0, 360.0)
		return true
	if keycode == KEY_ESCAPE:
		cancel_carry()
		return true
	return false


func _process(_delta: float) -> void:
	if not active or carrying == null or cam == null:
		return
	var p := _floor_point(get_viewport().get_mouse_position())
	carrying.position.x = snappedf(p.x, SNAP)
	carrying.position.z = snappedf(p.z, SNAP)


func _pick(piece: Node3D) -> void:
	carrying = piece
	_orig = piece.transform
	Sfx.play_ui("paper", -10.0)
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.34
	t.outer_radius = 0.42
	_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.32, 0.85)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = m
	_ring.position = Vector3(0, 0.05, 0)
	carrying.add_child(_ring)


func _place() -> void:
	_save_piece(carrying)
	_drop_ring()
	Sfx.play_ui("chair", -8.0)
	carrying = null


func cancel_carry() -> void:
	if carrying == null:
		return
	carrying.transform = _orig
	_drop_ring()
	carrying = null


func _drop_ring() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _floor_point(mpos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(mpos)
	var dir := cam.project_ray_normal(mpos)
	if absf(dir.y) < 0.0001:
		return from
	var t := -from.y / dir.y
	return from + dir * t


func _save_piece(piece: Node3D) -> void:
	var layout := _load_layout()
	layout[str(piece.get_meta("piece_id", ""))] = {
		"x": piece.position.x, "z": piece.position.z,
		"rot": piece.rotation_degrees.y,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(layout, "  "))


static func _load_layout() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			return d
	return {}


## Boot-time: put every previously moved piece back where the owner
## left it (called by main after the office finishes furnishing).
static func apply_saved(tree: SceneTree) -> void:
	var layout := _load_layout()
	if layout.is_empty():
		return
	for f in tree.get_nodes_in_group("furniture"):
		var id := str((f as Node).get_meta("piece_id", ""))
		if layout.has(id):
			var e: Dictionary = layout[id]
			(f as Node3D).position.x = float(e.get("x", (f as Node3D).position.x))
			(f as Node3D).position.z = float(e.get("z", (f as Node3D).position.z))
			(f as Node3D).rotation_degrees.y = float(e.get("rot", 0.0))
